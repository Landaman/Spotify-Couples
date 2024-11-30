import { getAuth } from 'firebase-admin/auth';
import type { LayoutServerLoad } from './$types';

/**
 * Server load, provides the user to all load functions
 */
export const load: LayoutServerLoad = async ({ locals }) => {
	const user = locals.user;

	// If there is no user, no need to generate an auth token so we can just return null
	if (!user) {
		return { user: null };
	}

	// Otherwise, generate a Firebase auth token
	const firebaseAuth = getAuth();
	const firebaseToken = await firebaseAuth.createCustomToken(user.id);

	// Return the user and their token
	return {
		user: { ...user, firebaseToken },
		partner: locals.partner
	};
};
