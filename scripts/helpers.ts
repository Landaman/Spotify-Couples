import { FirestoreUserConverter, USER_COLLECTION_NAME } from '@spotify-couples/core/lucia';
import { getFirestore } from 'firebase-admin/firestore';
import type { User } from 'lucia';

/**
 * Creates a user in the Firestore database
 * @param id the users ID
 * @param displayName optional, the display name for the user (ID is used otherwise)
 * @param profilePictureUrl optional, a profile picture for the suer
 */
export async function createUser(
	id: string,
	displayName?: string,
	profilePictureUrl?: string
): Promise<User> {
	const firestore = getFirestore();

	await firestore
		.collection(USER_COLLECTION_NAME)
		.withConverter(FirestoreUserConverter)
		.doc(id)
		.set({
			id,
			attributes: {
				partnerId: null,
				profilePictureUrl: profilePictureUrl ?? null,
				displayName: displayName ?? id,
				pairingCode: null,
				spotifyRefreshToken: null
			}
		});

	return {
		id,
		displayName: displayName ?? id,
		profilePictureUrl: profilePictureUrl ?? null,
		hasValidSpotifyAuthToken: false,
		partnerId: null
	};
}
