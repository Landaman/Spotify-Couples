import { AUTH_SECRET, AUTH_SPOTIFY_ID, AUTH_SPOTIFY_SECRET } from '$env/static/private';
import { SvelteKitAuth } from '@auth/sveltekit';
import Spotify from '@auth/sveltekit/providers/spotify';
import { redirect } from '@sveltejs/kit';

/**
 * Primary authentication handle setup by Auth.js
 */
export const {
	handle,
	signIn: signInAction,
	signOut: signOutAction
} = SvelteKitAuth({
	secret: AUTH_SECRET,
	providers: [Spotify({ clientId: AUTH_SPOTIFY_ID, clientSecret: AUTH_SPOTIFY_SECRET })],
	pages: {
		signIn: '/signin'
	},
	trustHost: true
});

// Param name for redirecting, used here and in the signin component
export const redirectToParamName = 'redirectTo';

/**
 * Redirects the user to sign in directly to Spotify
 * @param redirectTo optional, path to redirect to after sign-in
 */
export function redirectToSignIn(redirectTo?: string): never {
	const redirectUrl = new URL('/signin', window.location.origin);
	if (redirectTo) {
		redirectUrl.searchParams.set(redirectToParamName, redirectTo);
	}
	throw redirect(303, redirectUrl);
}
