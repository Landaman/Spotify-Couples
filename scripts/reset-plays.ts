import { client, getSeedUserIds } from './helpers';

/**
 * Deletes local plays for the supplied user and partnerpartner
 */
export default async function resetPlays(): Promise<void> {
	const userIds = await getSeedUserIds();

	const { error } = await client.from('plays').delete().in('user_id', userIds);
	if (error) {
		throw error;
	}

	console.log(`Reset plays for ${process.env.SPOTIFY_USER_ID} and partnerpartner`);
}
