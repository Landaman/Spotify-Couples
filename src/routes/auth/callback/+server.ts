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

	const {
		error: codeExchangeError,
		data: { session }
	} = await locals.supabase.auth.exchangeCodeForSession(code);

	if (codeExchangeError || !session) {
		throw codeExchangeError; // We can't just drop this error, they tried to sign in and something went wrong
	}

	await locals.refreshSession();

	posthog.capture({
		event: 'spotify_sign_in_completed',
		properties: { has_spotify_refresh_token: Boolean(session.provider_refresh_token) }
	});

	// Let the server decide what to do with the refresh token if we get one
	const refreshToken = session.provider_refresh_token;
	if (refreshToken) {
		const { error: tokenSaveError } = await locals.supabase.rpc('process_spotify_refresh_token', {
			refresh_token: refreshToken
		});

		if (tokenSaveError) {
			posthog.captureException(tokenSaveError);
			console.trace(tokenSaveError); // If it doesn't happen, just trace it but it's probably okay
		}
	}

	throw redirect(303, `/${redirectDestination.slice(1)}`); // Ensure no external redirects
};
