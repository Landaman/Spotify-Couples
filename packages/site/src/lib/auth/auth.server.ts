import { redirect, type RequestEvent } from '@sveltejs/kit';
import { RedirectDestinationSearchParameter } from '../../routes/auth/callback/shared';

/**
 * Function meant to be run on the server that redirects the user to the Spotify signin page
 * @param finalRedirectDestination the URl to return to after signin, if successful
 * @param event the request event, used to set cookies, determine origin URL, etc.
 */
export async function redirectToSignIn(
	finalRedirectDestination: string,
	event: RequestEvent
): Promise<never> {
	const {
		locals: { supabase },
		url
	} = event;

	// Build a redirect URL, including setting the redirect URL parameter
	const redirectUrl = new URL('/auth/callback', url.origin);
	redirectUrl.searchParams.set(RedirectDestinationSearchParameter, finalRedirectDestination);

	const {
		error,
		data: { url: destination }
	} = await supabase.auth.signInWithOAuth({
		provider: 'spotify',
		options: {
			redirectTo: redirectUrl.toString()
		}
	});

	if (error || !destination) {
		throw error; // Something went catastrophically wrong, just 500
	}

	throw redirect(303, destination); // Otherwise, proceed
}
