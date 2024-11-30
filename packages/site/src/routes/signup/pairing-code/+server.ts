import { getOrGeneratePairingCode, HasPartnerException } from '@spotify-couples/core/pairing';
import { error, json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async ({ locals }) => {
	// Validate that we have a user
	if (!locals.user) {
		throw error(401);
	}

	// Try to get and return the users pairing code
	try {
		return json(await getOrGeneratePairingCode(locals.user));
	} catch (exception) {
		if (exception instanceof HasPartnerException) {
			throw error(400, {
				message: 'Cannot get a pairing code for a user that already has a partner'
			});
		}

		throw exception; // Otherwise, show the normal error handling
	}
};
