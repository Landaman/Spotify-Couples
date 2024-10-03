import { redirectToSignIn } from '$lib/auth/auth.server';
import { getOrGeneratePairingCode, HasPartnerException } from '$lib/auth/pairing.server';
import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async (event) => {
	const { locals } = event;

	// Validate that we have a user
	if (!locals.user) {
		redirectToSignIn('/signup', event); // Redirect to sign-in to spotify if we have no user
	}

	// Try to get and return the users pairing code
	try {
		return await getOrGeneratePairingCode(locals.user);
	} catch (error) {
		if (error instanceof HasPartnerException) {
			throw redirect(303, '/'); // If they have a partner, that's fine, just redirect
		}

		throw error; // Otherwise, show the normal error handling
	}
};
