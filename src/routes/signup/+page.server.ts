import { redirectToSignIn } from '$lib/auth/auth.server';
import {
	getOrGeneratePairingCode,
	HasPartnerException,
	InvalidPairingCodeException,
	pair
} from '$lib/auth/pairing.server';
import { fail, redirect } from '@sveltejs/kit';
import { ShowPartnerSearchParameter } from '../dashboard/shared';
import type { Actions, PageServerLoad } from './$types';
import { PairingCodeFieldName } from './shared';

export const load: PageServerLoad = async (event) => {
	const { locals, url } = event;

	// Validate that we have a user
	if (!locals.user) {
		redirectToSignIn(url.toString(), event); // Redirect to sign-in to spotify if we have no user
	}

	// Try to get and return the users pairing code
	try {
		return await getOrGeneratePairingCode(locals.user);
	} catch (error) {
		if (error instanceof HasPartnerException) {
			throw redirect(303, '/dashboard'); // If they have a partner, that's fine, just redirect
		}

		throw error; // Otherwise, show the normal error handling
	}
};

export const actions = {
	default: async (event) => {
		// Get the form data to get the redirect url
		const formData = await event.request.formData();
		const pairingCode = formData.get(PairingCodeFieldName);

		// Check user auth
		if (!event.locals.user) {
			return fail(401);
		}

		// Check the pairing code
		if (!pairingCode) {
			return fail(400, {
				message: 'Missing pairing code'
			});
		}

		try {
			await pair(pairingCode.toString(), event.locals.user);
			return redirect(301, `/dashboard?${ShowPartnerSearchParameter}=true`); // Pair and then redirect to pairing complete
		} catch (error) {
			// Return a redirect if they are already paired
			if (error instanceof HasPartnerException) {
				return redirect(301, `/dashboard?${ShowPartnerSearchParameter}=true`);
			}

			// If the code is bad, return that
			if (error instanceof InvalidPairingCodeException) {
				return fail(400, {
					message: 'Invalid pairing code'
				});
			}

			throw error;
		}
	}
} satisfies Actions;
