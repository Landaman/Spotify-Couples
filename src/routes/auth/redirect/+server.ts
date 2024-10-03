import { env } from '$env/dynamic/private';
import { COOKIE_FIELD_DELIMITER, COOKIE_REDIRECT_INDEX, COOKIE_STATE_INDEX } from '$lib/auth/auth';
import { getOrCreateUser } from '$lib/auth/user.server';
import { SESSION_COOKIE_KEY } from '$lib/firebase/firebase-config';
import { fail, redirect } from '@sveltejs/kit';
import { OAuth2RequestError, type OAuth2Tokens, Spotify } from 'arctic';
import type { RequestHandler } from './$types';

/**
 * Endpoint that handles redirect from Spotify's auth provider
 */
export const GET: RequestHandler = async ({ cookies, url, locals }) => {
	/**
	 * Handles an auth error, redirecting to the root page
	 */
	function handleAuthError(): never {
		// Never return type fixes errors below
		cookies.delete(SESSION_COOKIE_KEY, { path: '/' });
		throw fail(401); // The client did something wrong, fail out
	}

	// Get the session cookie
	const authStateCookie = cookies.get(SESSION_COOKIE_KEY);
	if (!authStateCookie) {
		handleAuthError();
	}

	// Decode the cookie
	const parsedSessionCookie = decodeURI(authStateCookie).split(COOKIE_FIELD_DELIMITER);
	if (parsedSessionCookie.length !== 2) {
		handleAuthError();
	}

	// Parse the cookie
	const expectedState = parsedSessionCookie[COOKIE_STATE_INDEX];
	const redirectUrl = parsedSessionCookie[COOKIE_REDIRECT_INDEX];

	// Now parse the URL
	const state = url.searchParams.get('state');
	const code = url.searchParams.get('code');

	// Now validate the state
	if (state !== expectedState || !code) {
		handleAuthError();
	}

	// Validate the code
	const spotify = new Spotify(
		env.SPOTIFY_CLIENT_ID,
		env.SPOTIFY_CLIENT_SECRET,
		new URL('/auth/redirect', url.origin).toString()
	);
	let codeValidationResult: OAuth2Tokens;
	try {
		codeValidationResult = await spotify.validateAuthorizationCode(code);
	} catch (error) {
		if (error instanceof OAuth2RequestError) {
			handleAuthError(); // This happens when the code/redirect URL/etc is bad
		}
		throw error; // This shouldn't happen, this is e.g., fetch a error
	}

	// Set the users session cookie
	const user = await getOrCreateUser(codeValidationResult); // Get/create the user
	const session = await locals.auth.createSession(user.id, {}); // Create a session for them
	const sessionCookie = locals.auth.createSessionCookie(session.id); // Create a cookie for the session
	cookies.set(sessionCookie.name, sessionCookie.value, { ...sessionCookie.attributes, path: '/' }); // Bind the cookie

	throw redirect(303, redirectUrl); // Redirect to the auth destination
};
