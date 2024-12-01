import {
	FirestoreUserConverter,
	getPublicUserAttributes,
	USER_COLLECTION_NAME
} from '@spotify-couples/core/lucia';
import { FirestorePlayConverter, PLAYS_SUBCOLLECTION_NAME } from '@spotify-couples/core/plays';
import { SpotifyApi, type AccessToken } from '@spotify/web-api-ts-sdk';
import { OAuth2RequestError, Spotify, type OAuth2Tokens } from 'arctic';
import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { defineSecret } from 'firebase-functions/params';
import { onSchedule } from 'firebase-functions/scheduler';

// Spotify secrets
const spotifyClientId = defineSecret('SPOTIFY_CLIENT_ID');
const spotifyClientSecret = defineSecret('SPOTIFY_CLIENT_SECRET');

/**
 * Gets the token for the provided user. Clears the users tokekn if it was insuffient for scopes or expired/invalid
 * @param userId - the ID of the user to get the token for
 * @param scopes - the scopes to validate the users token contains
 * @returns the token, or null if the user has no token or access code
 */
async function getTokenForUser(userId: string, scopes: string[]): Promise<AccessToken | null> {
	const firestore = getFirestore();

	const userDocument = firestore // Raw firestore user
		.collection(USER_COLLECTION_NAME)
		.withConverter(FirestoreUserConverter)
		.doc(userId);

	// TX to update and get the token
	return await firestore.runTransaction(async (tx) => {
		const transactionUserData = (await tx.get(userDocument)).data();
		if (!transactionUserData) {
			throw new Error('Invalid transaction user'); // This should never happen
		}
		const transactionUser = {
			// Process the user to get their attributes properly
			id: transactionUserData.id,
			spotifyRefreshToken: transactionUserData.attributes.spotifyRefreshToken,
			...getPublicUserAttributes(transactionUserData.attributes)
		};

		// Perform the refresh for teh spotify user
		const spotifyAuth = new Spotify(spotifyClientId.value(), spotifyClientSecret.value(), '');
		if (!transactionUser.spotifyRefreshToken) {
			return null; // If the user has no token, just move on
		}

		// Otherwise, try to refresh
		let token: OAuth2Tokens;
		try {
			token = await spotifyAuth.refreshAccessToken(transactionUser.spotifyRefreshToken);
		} catch (error) {
			if (error instanceof OAuth2RequestError) {
				tx.update(userDocument, { 'attributes.spotifyRefreshToken': null }); // This will update the token on next login
				return null; // This implies the users refresh token was invalid
			}

			throw error;
		}

		// If the token has insuffient scopes
		if (!scopes.every((scope) => token.scopes().includes(scope))) {
			tx.update(userDocument, { 'attributes.spotifyRefreshToken': null }); // Reset
			return null;
		}

		// Update the refresh token, if applicable
		if (token.hasRefreshToken()) {
			tx.update(userDocument, { 'attributes.spotifyRefreshToken': token.refreshToken() });
		}

		// Return the access token
		return {
			access_token: token.accessToken(),
			expires_in: token.accessTokenExpiresInSeconds(),
			refresh_token: token.hasRefreshToken()
				? token.refreshToken()
				: transactionUser.spotifyRefreshToken,
			token_type: token.tokenType()
		} satisfies AccessToken; // Return the access token
	});
}

export const readSpotifyAccountsScheduled = onSchedule(
	{
		schedule: '*/15 * * * *',
		region: 'us-east1',
		secrets: [spotifyClientId, spotifyClientSecret]
	},
	async () => {
		// If there is no default app
		if (getApps().length == 0) {
			initializeApp(); // Initialize it
		}
		const firestore = getFirestore(); // Get the firestore instance to use

		// Users
		const users = await firestore
			.collection(USER_COLLECTION_NAME)
			.withConverter(FirestoreUserConverter)
			.get();

		// For each user
		for (const user of users.docs) {
			// Do a Transaction per-user to ensure the token remains consistent without blocking all users
			const token = await getTokenForUser(user.id, ['user-read-recently-played']);

			// If we couldn't get a token for the user, do nothing
			if (!token) {
				continue;
			}

			// Use the token to authenticate with Spotify
			const sdk = SpotifyApi.withAccessToken(spotifyClientId.value(), token);
			const recentTracks = await sdk.player.getRecentlyPlayedTracks(50);

			// Run a TX to set all of the plays for the user
			await firestore.runTransaction(async (tx) => {
				for (const track of recentTracks.items) {
					const playDocument = firestore
						.collection(USER_COLLECTION_NAME)
						.doc(user.id)
						.collection(PLAYS_SUBCOLLECTION_NAME)
						.withConverter(FirestorePlayConverter)
						.doc(track.played_at);

					// Set the play, if it's a duplicate this shouldn't matter
					tx.set(playDocument, {
						playedContextURI: track.context?.uri ?? null,
						playedTime: new Date(track.played_at),
						spotifyId: track.track.id
					});
				}
			});

			sdk.logOut(); // Log out from Spotify
		}
	}
);
