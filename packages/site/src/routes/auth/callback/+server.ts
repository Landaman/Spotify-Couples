import { redirect } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { CodeSearchParameter, RedirectDestinationSearchParameter } from './shared';

export const GET: RequestHandler = async ({ url, locals: { supabase } }) => {
	const code = url.searchParams.get(CodeSearchParameter) as string;
	const redirectDestination = url.searchParams.get(RedirectDestinationSearchParameter) ?? '/';

	if (code) {
		const {
			error: codeExchangeError,
			data: { session }
		} = await supabase.auth.exchangeCodeForSession(code);

		if (!codeExchangeError && session) {
			// Let the server decide what to do with the refresh token if we get one
			if (session.provider_refresh_token) {
				const { error: tokenSaveError } = await supabase.rpc('process_spotify_refresh_token', {
					refresh_token: session.provider_refresh_token
				});

				if (tokenSaveError) {
					console.error(tokenSaveError);
				}
			}

			throw redirect(303, `/${redirectDestination.slice(1)}`); // Ensure no external redirects
		}

		// Ensure we don't drop errors for no reason
		console.error(codeExchangeError);
	}

	// Redirect home (and try again) if needed
	throw redirect(303, '/');
};
