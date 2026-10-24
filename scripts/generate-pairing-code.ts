import { createImpersonatingClient, getOrCreateUser } from './helpers';

/**
 * Generates a pairing code for a fake user, and prints it
 */
export default async function generatePairingCode(): Promise<void> {
	const email = 'partnerpartner@example.com';
	await getOrCreateUser('partnerpartner', email);

	// Now run the get/create
	const { data: pairingCode, error: pairingCodeError } = await (
		await createImpersonatingClient(email)
	).rpc('get_or_create_pairing_code');
	if (pairingCodeError || !pairingCode) {
		throw pairingCodeError;
	}

	console.log(`Code: ${pairingCode.code}, Expires: ${pairingCode.expires_at}`);
}
