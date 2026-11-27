import { redirectToSignIn } from '#lib/auth/auth.server.js';
import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';
import { findTopListensDateRange, parseTopListensListener } from './shared';

export const load: PageServerLoad = async (event) => {
	const {
		locals: { partner, session },
		url
	} = event;

	// Validate we have a user
	if (!session) {
		throw await redirectToSignIn(url.pathname, event); // If not, sign them in and then come back
	}

	// Validate the user has a partner
	if (!partner) {
		throw redirect(303, '/signup'); // If the user doesn't have a partner, redirect to signup to get them a partner
	}

	const listener = parseTopListensListener(url.searchParams.get('listener'));

	const dateRange = findTopListensDateRange(url.searchParams.get('range'));
	if (!dateRange) {
		const allTime = new URL(url.href);
		allTime.searchParams.delete('range');
		redirect(303, allTime);
	}

	return {
		listener,
		dateRange,
		session,
		partner
	};
};
