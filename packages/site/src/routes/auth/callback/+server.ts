import { redirect } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { CodeSearchParameter, RedirectDestinationSearchParameter } from './shared';

export const GET: RequestHandler = async ({ url, locals: { supabase } }) => {
	const code = url.searchParams.get(CodeSearchParameter) as string;
	const redirectDestination = url.searchParams.get(RedirectDestinationSearchParameter) ?? '/';

	if (code) {
		const {
			error,
			data: { session }
		} = await supabase.auth.exchangeCodeForSession(code);

		if (!error && session) {
			// Save the Spotify Refresh token if needed and necessary
			if (session.provider_refresh_token) {
				const { error: rpcError } = await supabase.rpc('process_spotify_refresh_token', {
					refresh_token: session.provider_refresh_token
				});

				if (rpcError) {
					console.error(rpcError);
				}
			}

			throw redirect(303, `/${redirectDestination.slice(1)}`); // Ensure no external redirects
		}

		// Ensure we don't drop errors for no reason
		console.error(error);
	}

	// Redirect home (and try again) if needed
	throw redirect(303, '/');
};
