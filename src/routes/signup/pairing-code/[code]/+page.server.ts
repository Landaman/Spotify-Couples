import { redirectToSignIn } from '$lib/auth/auth.server';
import { HasPartnerException, InvalidPairingCodeException, pair } from '$lib/auth/pairing.server';
import { redirect } from '@sveltejs/kit';
import { ShowPartnerSearchParameter } from '../../../dashboard/shared';
import { InvalidCodeSearchParameter } from '../../shared';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async (event) => {
	const { locals, url, params } = event;

	// Validate that we have a user
	if (!locals.user) {
		redirectToSignIn(url.pathname, event); // Redirect to sign-in to spotify if we have no user
	}

	// Try to get and return the users pairing code
	try {
		await pair(params.code, locals.user);
		throw redirect(303, `/dashboard?${ShowPartnerSearchParameter}=true`); // Redirect to show the pairing
	} catch (error) {
		if (error instanceof HasPartnerException) {
			throw redirect(303, `/dashboard?${ShowPartnerSearchParameter}=true`); // If they have a partner, that's fine, just redirect
		} else if (error instanceof InvalidPairingCodeException) {
			throw redirect(303, `/signup?${InvalidCodeSearchParameter}=true`); // If the code was bad, display that
		}

		throw error; // Otherwise, show the normal error handling
	}
};
