import { USER_COLLECTION_NAME } from '@spotify-couples/core/lucia';
import { onSchedule } from 'firebase-functions/scheduler';

export const readSpotifyAccountsScheduled = onSchedule('*/15 * * * *', async () => {
	console.error('hello world from read spotify accounts: ' + USER_COLLECTION_NAME);
});
