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

	// Pair this user with the other
	const { error: thisUserError } = await client
		.from('profiles')
		.update({ partner_id: otherUser.id })
		.eq('id', thisUser.id);
	if (thisUserError) {
		throw thisUserError;
	}

	// And vice versa
	const { error: otherUserError } = await client
		.from('profiles')
		.update({ partner_id: thisUser.id })
		.eq('id', otherUser.id);
	if (otherUserError) {
		throw otherUserError;
	}

	console.log('Auto-pair complete');
}
