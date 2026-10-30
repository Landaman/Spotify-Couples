import { posthog } from '#lib/analytics/analytics.server.js';
import { redirectToSignIn } from '#lib/auth/auth.server.js';
import {
	InvalidPartnerException,
	NoPartnerException,
	unpairPartner
} from '#lib/database/pairings.server.js';
import { fail } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';

/** Requires sign-in and loads the current partner for the settings page */
export const load: PageServerLoad = async (event) => {
	if (!event.locals.session) {
		throw await redirectToSignIn(event.url.pathname, event);
	}

	return { partner: event.locals.partner };
};

export const actions = {
	/**
	 * Unpairs the authenticated user and refreshes their cached partner.
	 * Returns form errors for invalid requests and expected pairing conflicts;
	 * unexpected errors propagate to SvelteKit's normal error handling.
	 */
	unpair: async ({ locals, request }) => {
		if (!locals.session) {
			return fail(401);
		}

		const partnerId = (await request.formData()).get('partnerId');
		if (typeof partnerId !== 'string') {
			return fail(400);
		}

		try {
			await unpairPartner(locals.supabase, partnerId);
			await locals.refreshPartner();

			posthog.capture({ event: 'partner_unpaired' });
		} catch (error) {
			if (error instanceof NoPartnerException) {
				return fail(409, {
					message: 'You no longer have a partner. Refresh the page and try again.'
				});
			}
			if (error instanceof InvalidPartnerException) {
				return fail(409, { message: 'Your partner has changed. Refresh the page and try again.' });
			}

			throw error;
		}
	}
} satisfies Actions;
