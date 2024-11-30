import { pair } from '@spotify-couples/core/pairing';
import { createUser } from './helpers';

/**
 * Pairs a fake user with the provided pairing code
 * @param code the code to pair with
 */
export default async function pairWithCode(code: string) {
	const user = await createUser('partnerpartner');

	if (code) {
		console.log('Failed to pair with code - missing CLI pairing code');
	}

	await pair(code, user);

	console.log('Pairing complete');
}
