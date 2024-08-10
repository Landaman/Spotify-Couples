import { SvelteKitAuth } from '@auth/sveltekit';
import Spotify from '@auth/sveltekit/providers/spotify';
import { redirect } from '@sveltejs/kit';
import { REDIRECT_TO_PARAM_NAME as REDIRECT_TO_QUERY_PARAM_NAME } from './constants';

// Name of the only cookie firebase will pass to functions :(
const FIREBASE_SESSION_COOKIE_NAME = '__session';

/**
 * Primary authentication handle setup by Auth.js
 */
export const {
	handle,
	signIn: signInAction,
	signOut: signOutAction
} = SvelteKitAuth({
	providers: [Spotify],
	pages: {
		signIn: '/signin'
	},
	trustHost: true,
	cookies: {
		sessionToken: {
			name: FIREBASE_SESSION_COOKIE_NAME
		},
		pkceCodeVerifier: {
			name: FIREBASE_SESSION_COOKIE_NAME
		}
	}
});

/**
 * Redirects the user to sign in directly to Spotify
 * @param redirectTo optional, path to redirect to after sign-in
 */
export function redirectToSignIn(redirectTo?: string): never {
	const redirectUrl = new URL('/signin', window.location.origin);
	if (redirectTo) {
		redirectUrl.searchParams.set(REDIRECT_TO_QUERY_PARAM_NAME, redirectTo);
	}
	throw redirect(303, redirectUrl);
}
