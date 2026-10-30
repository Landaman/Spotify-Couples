import { posthog } from '#lib/analytics/analytics.server.js';
import { redirect } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { CodeSearchParameter, RedirectDestinationSearchParameter } from './shared';

export const GET: RequestHandler = async ({ url, locals }) => {
	const code = url.searchParams.get(CodeSearchParameter) as string;
	const redirectDestination = url.searchParams.get(RedirectDestinationSearchParameter) ?? '/';

	if (!code) {
		console.trace('Missing code in auth callback');
		throw redirect(303, '/'); // Probably this isn't anything to worry about, maybe just a bad saved link or something
	}

	const newSession = await posthog.withSpan(
		'supabase.auth.exchangeCodeForSession',
		{ kind: 'client' },
		async () => {
			const {
				error: codeExchangeError,
				data: { session }
			} = await locals.supabase.auth.exchangeCodeForSession(code);
			if (codeExchangeError || !session) {
				const exchangeError =
					codeExchangeError ?? new Error('exchangeCodeForSession returned no session');
				throw exchangeError; // We can't just drop this error, they tried to sign in and something went wrong
			}
			return session;
		}
	);

	await locals.refreshSession();

	posthog.capture({
		event: 'spotify_sign_in_completed',
		properties: { has_spotify_refresh_token: Boolean(newSession.provider_refresh_token) }
	});

	// Let the server decide what to do with the refresh token if we get one
	const refreshToken = newSession.provider_refresh_token;
	if (refreshToken) {
		await posthog.withSpan(
			'supabase.rpc.process_spotify_refresh_token',
			{ kind: 'client' },
			async (span) => {
				const result = await locals.supabase.rpc('process_spotify_refresh_token', {
					refresh_token: refreshToken
				});
				if (result.error) {
					span.recordException(result.error);
					console.trace(result.error); // If it doesn't happen, just trace it but it's probably okay
					posthog.captureException(result.error);
				}
				return result;
			}
		);
	}

	throw redirect(303, `/${redirectDestination.slice(1)}`); // Ensure no external redirects
};
