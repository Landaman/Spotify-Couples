import { env } from '$env/dynamic/private';
import { SpotifyApi } from '@spotify/web-api-ts-sdk';
import type { OAuth2Tokens } from 'arctic';
import { getFirestore } from 'firebase-admin/firestore';
import type { User } from 'lucia';
import { FirestoreUserConverter } from '../firebase/lucia-adapter-firestore.server';
import { USER_COLLECTION_NAME } from './auth.server';

/**
 * Gets or creates the user associated with the provided OAuth tokens
 * @param oAuthTokens the OAuth tokens returned by an authentication attempt
 * @returns the created/fetched user
 */
export async function getOrCreateUser(oAuthTokens: OAuth2Tokens): Promise<User> {
	// Authenticate with the Spotify SDK to get the users information. Doing it this way
	// authenticates as the user identified by the token
	const sdk = SpotifyApi.withAccessToken(env.SPOTIFY_CLIENT_ID, {
		access_token: oAuthTokens.accessToken(),
		expires_in: oAuthTokens.accessTokenExpiresInSeconds(),
		refresh_token: oAuthTokens.refreshToken(),
		token_type: oAuthTokens.tokenType()
	});

	// Get the current user
	const user = await sdk.currentUser.profile();

	// Get Firestore
	const firestore = getFirestore();

	// Get the document associated with the user we are trying to log in
	const userDocument = firestore
		.collection(USER_COLLECTION_NAME)
		.withConverter(FirestoreUserConverter)
		.doc(user.id);

	// Get the existing partner ID, or null if we don't have this document
	const userDocumentData = (await userDocument.get()).data();
	const partnerId = userDocumentData?.attributes.partnerId ?? null;
	const pairingCode = userDocumentData?.attributes.pairingCode ?? null;

	// Update the display name/PFP, so what we have is the latest
	await userDocument.set({
		id: user.id,
		attributes: {
			displayName: user.display_name,
			profilePictureUrl: user.images[0]?.url ?? null, // It has to be null or slse we get a Firebase error
			partnerId,
			pairingCode
		}
	});

	// Return the latest user attributes either way
	return {
		displayName: user.display_name,
		profilePictureUrl: user.images[0]?.url ?? null,
		id: user.id,
		partnerId
	};
}
