import { createImpersonatingClient, createUser } from './helpers';

/**
 * Pairs a fake user with the provided pairing code
 * @param code the code to pair with
 */
export default async function pairWithCode(code: string) {
	const user = await createUser('partnerpartner', 'partnerpartner@example.com');

	// Pair with the code, throw if necessary
	const { error } = await (
		await createImpersonatingClient(user)
	).rpc('pair_with_code', { pairing_code: code });
	if (error) {
		throw error;
	}

	console.log('Pairing complete');
}
