import { redirectToSignIn } from '$lib/auth/auth.server';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async (event) => {
	const { locals } = event;

	// Validate that we have a user
	if (!locals.user) {
		redirectToSignIn('/signup', event); // Redirect to signup if we have no user
	}

	return {
		pairingCode: (123456).toString(),
		pairingCodeSecondsToExpiry: 15 * 60
	};
};
