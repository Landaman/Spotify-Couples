import { redirectToSignIn } from '$lib/auth/auth.server';
import {
	getOrCreatePairingCode,
	HasPartnerException,
	InvalidPairingCodeException,
	pairWithCode
} from '$lib/database/pairing-codes.server';
import { fail, redirect } from '@sveltejs/kit';
import { ShowPartnerSearchParameter } from '../dashboard/shared';
import type { Actions, PageServerLoad } from './$types';
import { PairingCodeDependency, PairingCodeFieldName } from './shared';

export const load: PageServerLoad = async (event) => {
	const { locals, url, depends } = event;

	// Validate that we have a session
	if (!(await locals.safeGetSession())) {
		throw await redirectToSignIn(url.pathname, event); // Redirect to sign-in to spotify if we have no user
	}

	// This is how we handle reloading pairing codes
	depends(PairingCodeDependency);

	// Try to get and return the users pairing code
	try {
		return { pairingCode: await getOrCreatePairingCode(locals.supabase) };
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
		if (!(await event.locals.safeGetSession())) {
			return fail(401);
		}

		// Check the pairing code
		if (!pairingCode) {
			return fail(400, {
				message: 'Missing pairing code'
			});
		}

		try {
			await pairWithCode(event.locals.supabase, pairingCode.toString());
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
