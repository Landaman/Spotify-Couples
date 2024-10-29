import { dev } from '$app/environment';
import { env } from '$env/dynamic/private';
import { COOKIE_FIELD_DELIMITER } from '$lib/auth/auth';
import { SESSION_COOKIE_KEY } from '$lib/firebase/firebase-config';
import {
	FirestoreAdapter,
	FirestoreUserConverter
} from '$lib/firebase/lucia-adapter-firestore.server';
import { redirect, type RequestEvent } from '@sveltejs/kit';
import { generateState, Spotify } from 'arctic';
import { getFirestore } from 'firebase-admin/firestore';
import { Lucia, type RegisteredDatabaseUserAttributes } from 'lucia';

// Firestore collection names
export const USER_COLLECTION_NAME = 'users';
export const SESSION_SUB_COLLECTION_NAME = 'sessions';

/**
 * Function meant to be run on the server that redirects the user to the Spotify signin page
 * @param redirectUrl the URl to return to after signin
 * @param event the request event, used to set cookies, determine origin URL, etc.
 */
export function redirectToSignIn(redirectUrl: string, event: RequestEvent): never {
	// Generate auth information
	const state = generateState();
	const scopes = ['user-read-email'];
	const spotify = new Spotify(
		env.SPOTIFY_CLIENT_ID,
		env.SPOTIFY_CLIENT_SECRET,
		new URL('/auth/redirect', event.url.origin).toString()
	);

	// HTTP Only and Secure are automatically set by sveltekit and are smart enough
	// to handle localhost
	const attemptExpiryMinutes = 10;
	const secondsInMinute = 60;
	event.cookies.set(
		SESSION_COOKIE_KEY,
		encodeURI(`${state}${COOKIE_FIELD_DELIMITER}${redirectUrl}`),
		{
			path: '/',
			maxAge: attemptExpiryMinutes * secondsInMinute // 10 minutes
		}
	);

	// Redirect to the login page
	throw redirect(303, spotify.createAuthorizationURL(state, scopes));
}

/**
 * Handle to attach Lucia to the system. Should be run after the Firebase setup
 * @param event the event passed into the server hook
 */
export const handle = async (event: RequestEvent) => {
	event.locals.auth = createLucia(); // Attach Lucia itself

	// If we have no session cookie, we can assume no user
	const sessionId = event.cookies.get(event.locals.auth.sessionCookieName);
	if (!sessionId) {
		event.locals.user = null;
		event.locals.partner = null;
		event.locals.session = null;
		return;
	}

	// If the decoded session ID has the cookie delimter or includes a /, we're not interested in it
	// for auth (as firebase will get mad)
	// If we do have the cookie field delimiter, the cookie is being used for a current redirect, so don't replace it so we don't break that
	if (decodeURI(sessionId).includes(COOKIE_FIELD_DELIMITER) || sessionId.includes('/')) {
		event.locals.user = null;
		event.locals.partner = null;
		event.locals.session = null;
		return;
	}

	// Otherwise, see if the cookie represents a valid session
	const { session, user } = await event.locals.auth.validateSession(sessionId);
	if (session && session.fresh) {
		// If it is, make sure we update the session cookie so it is still valid next time
		const sessionCookie = event.locals.auth.createSessionCookie(session.id);
		event.cookies.set(sessionCookie.name, sessionCookie.value, {
			path: '/',
			...sessionCookie.attributes
		});
	}

	// At this point, we know the cookie is garbage (no session or delimeter)
	if (!session) {
		// Just get rid of it
		const sessionCookie = event.locals.auth.createBlankSessionCookie();
		event.cookies.set(sessionCookie.name, sessionCookie.value, {
			path: '/',
			...sessionCookie.attributes
		});
	}

	// In either case this works
	event.locals.user = user;
	event.locals.session = session;

	// Done if the user is null or there is no partner
	if (event.locals.user == null || event.locals.user.partnerId == null) {
		event.locals.partner = null;
		return;
	}

	// Get the user's partner and associated document
	const firestore = getFirestore();
	const partnerDocument = await firestore
		.collection(USER_COLLECTION_NAME)
		.withConverter(FirestoreUserConverter)
		.doc(event.locals.user.partnerId)
		.get();
	const partnerData = partnerDocument.data();
	if (!partnerData) {
		throw new Error(
			`User ${event.locals.user.id} has partner ${event.locals.user.partnerId} who has no document`
		);
	}
	event.locals.partner = {
		id: partnerData.id,
		...getUserAttributes(partnerData.attributes)
	};
};

/**
 * Gets the attributes for the provided database user attributes
 * @param attributes the database user attributes for the provided user
 * @returns the application-level user attributes for the provided user
 */
function getUserAttributes(attributes: RegisteredDatabaseUserAttributes) {
	return {
		displayName: attributes.displayName,
		profilePictureUrl: attributes.profilePictureUrl,
		partnerId: attributes.partnerId
	};
}

/**
 * Function to create the Lucia instance. This is used to defer creating Lucia until
 * Firebase is actually connected, so that the getFirestore() call will succeed
 * @returns the created Lucia instance
 */
function createLucia() {
	return new Lucia(
		new FirestoreAdapter({
			firestore: getFirestore(),
			sessionSubCollectionName: SESSION_SUB_COLLECTION_NAME,
			userCollectionName: USER_COLLECTION_NAME
		}),
		{
			sessionCookie: {
				name: SESSION_COOKIE_KEY, // This is required with firebase
				attributes: {
					secure: !dev // This doesn't automatically happen :(
				}
			},
			getUserAttributes: getUserAttributes
		}
	);
}

// This is required by Lucia for typesafety
declare module 'lucia' {
	interface Register {
		Lucia: ReturnType<typeof createLucia>;
		DatabaseUserAttributes: {
			/**
			 * The display name of the user
			 */
			displayName: string;
			/**
			 * The profile picture of the user.
			 * This is optional (the user does not necessarily need one)
			 */
			profilePictureUrl: string | null;
			/**
			 * The ID of the users partner. This will be null if they have no relationship
			 */
			partnerId: string | null;
			/**
			 * The users pairing code
			 */
			pairingCode: string | null;
			/**
			 * The users's Spotify refresh token
			 */
			spotifyRefreshToken: string;
		};
	}
}
