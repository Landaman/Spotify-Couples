import { getOrGeneratePairingCode } from '$lib/auth/pairing.server';
import { createUser } from './helpers';

/**
 * Generates a pairing code for a fake user, and prints it
 */
export default async function generatePairingCode(): Promise<void> {
	const user = await createUser('partnerpartner');

	const pairingCode = await getOrGeneratePairingCode(user);

	console.log(`Code: ${pairingCode.code}, Expires: ${pairingCode.expiry.toLocaleTimeString()}`);
}
