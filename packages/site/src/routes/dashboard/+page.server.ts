import { redirectToSignIn } from '$lib/auth/auth.server';
import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async (event) => {
	const { locals, url } = event;

	// Validate we have a user
	if (!locals.user) {
		throw redirectToSignIn(url.toString(), event); // If not, sign them in and then come back
	}

	// Validate the user has a partner
	if (!locals.partner) {
		throw redirect(303, '/signup'); // If the user doesn't have a partner, redirect to signup to get them a partner
	}
};
