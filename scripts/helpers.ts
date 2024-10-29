import { USER_COLLECTION_NAME } from '$lib/auth/auth.server';
import { FirestoreUserConverter } from '$lib/firebase/lucia-adapter-firestore.server';
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
		.create({
			id,
			attributes: {
				partnerId: null,
				profilePictureUrl: profilePictureUrl ?? null,
				displayName: displayName ?? id,
				pairingCode: null,
				spotifyRefreshToken: null as unknown as string // This is fine since it gets replaced on login if it is null. In practice in prod, will never be null
			}
		});

	return {
		id,
		displayName: displayName ?? id,
		profilePictureUrl: profilePictureUrl ?? null,
		partnerId: null
	};
}
