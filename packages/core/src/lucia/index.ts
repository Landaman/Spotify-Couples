import { getFirestore } from 'firebase-admin/firestore';
import { Lucia, type RegisteredDatabaseUserAttributes } from 'lucia';
import { FirestoreAdapter } from './lucia-adapter-firestore';

export * from './lucia-adapter-firestore';
export const USER_COLLECTION_NAME = 'users';
export const SESSION_SUB_COLLECTION_NAME = 'sessions';

/**
 * Gets the public (e.g., sent to client) attributes for the provided database user attributes
 * @param attributes the database user attributes for the provided user
 * @returns the application-level user attributes for the provided user
 */
export function getPublicUserAttributes(attributes: RegisteredDatabaseUserAttributes) {
	return {
		displayName: attributes.displayName,
		profilePictureUrl: attributes.profilePictureUrl,
		partnerId: attributes.partnerId,
		hasValidSpotifyAuthToken: attributes.spotifyRefreshToken != null
	};
}

/**
 * Function to create the Lucia instance. This is used to defer creating Lucia until
 * Firebase is actually connected, so that the getFirestore() call will succeed
 * @returns the created Lucia instance
 */
export function createLucia(sessionCookieKey: string, dev: boolean) {
	return new Lucia(
		new FirestoreAdapter({
			firestore: getFirestore(),
			sessionSubCollectionName: SESSION_SUB_COLLECTION_NAME,
			userCollectionName: USER_COLLECTION_NAME
		}),
		{
			sessionCookie: {
				name: sessionCookieKey, // This is required with firebase
				attributes: {
					secure: !dev // This doesn't automatically happen :(
				}
			},
			getUserAttributes: getPublicUserAttributes
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
			 * The users's Spotify refresh token, may be null in case the user is not authenticated
			 */
			spotifyRefreshToken: string | null;
		};
	}
}
