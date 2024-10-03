import { getOrGeneratePairingCode, HasPartnerException } from '$lib/auth/pairing.server';
import { fail, json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async ({ locals }) => {
	// Validate that we have a user
	if (!locals.user) {
		throw fail(401);
	}

	// Try to get and return the users pairing code
	try {
		return json(await getOrGeneratePairingCode(locals.user));
	} catch (error) {
		if (error instanceof HasPartnerException) {
			throw fail(400, {
				message: 'Cannot get a pairing code for a user that already has a partner'
			});
		}

		throw error; // Otherwise, show the normal error handling
	}
};
