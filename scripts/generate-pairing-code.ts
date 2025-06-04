import { createImpersonatingClient, createUser } from './helpers';

/**
 * Generates a pairing code for a fake user, and prints it
 */
export default async function generatePairingCode(): Promise<void> {
	const userProfile = await createUser('partnerpartner', 'partnerpartner@example.com');

	// Now run the get/create
	const { data: pairingCode, error: pairingCodeError } = await (
		await createImpersonatingClient(userProfile)
	).rpc('get_or_create_pairing_code');
	if (pairingCodeError || !pairingCode) {
		throw pairingCodeError;
	}

	console.log(`Code: ${pairingCode.code}, Expires: ${pairingCode.expires_at}`);
}
