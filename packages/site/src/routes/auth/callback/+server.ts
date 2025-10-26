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
			// Save the Spotify Refresh token if needed and necessary
			if (session.provider_refresh_token) {
				const { data, error: tokenSaveError } = await supabase.rpc(
					'process_spotify_refresh_token',
					{
						refresh_token: session.provider_refresh_token
					}
				);

				if (tokenSaveError || data == null) {
					console.error(tokenSaveError);
				}

				if (data) {
					const { error: getPlaysError } = await supabase.rpc('read_plays_for_user_if_needed');
					if (getPlaysError) {
						console.error(getPlaysError);
					}
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
