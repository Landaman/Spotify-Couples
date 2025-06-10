import { client, createUser } from './helpers';

/**
 * Automatically creates and pairs this user with a fake user
 */
export default async function autoPair(): Promise<void> {
	// Validate the user has an ID
	if (!process.env.SPOTIFY_USER_ID) {
		throw new Error('Error: Cannot auto-pair: missing SPOTIFY_USER_ID environment variable');
	}

	// Create the two users
	const thisUser = await createUser(
		process.env.SPOTIFY_USER_ID,
		'irswright13@gmail.com',
		'Ian Wright'
	);
	const otherUser = await createUser('partnerpartner', 'partnerpartner@example.com');

	// Create the pairing
	const { error } = await client
		.from('pairings')
		.insert({ one_uuid: thisUser.id, two_uuid: otherUser.id });
	if (error) {
		throw error;
	}

	console.log('Auto-pair complete');
}
