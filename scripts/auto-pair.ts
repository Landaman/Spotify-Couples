import { FirestoreUserConverter, USER_COLLECTION_NAME } from '@spotify-couples/core/lucia';
import { getFirestore } from 'firebase-admin/firestore';
import { createUser } from './helpers';

/**
 * Automatically creates and pairs this user with a fake user
 */
export default async function autoPair(): Promise<void> {
	// Validate the user has an ID
	if (!process.env.SPOTIFY_USER_ID) {
		throw new Error('Error: Cannot auto-pair: missing SPOTIFY_USER_ID environment variable');
	}

	// Create the standard user
	const thisUser = await createUser(process.env.SPOTIFY_USER_ID, 'Ian Wright');
	const otherUser = await createUser('partnerpartner');

	const firestore = getFirestore();

	await firestore
		.collection(USER_COLLECTION_NAME)
		.withConverter(FirestoreUserConverter)
		.doc(thisUser.id)
		.update({ 'attributes.partnerId': otherUser.id });

	await firestore
		.collection(USER_COLLECTION_NAME)
		.withConverter(FirestoreUserConverter)
		.doc(otherUser.id)
		.update({ 'attributes.partnerId': thisUser.id });

	console.log('Auto-pair complete');
}
