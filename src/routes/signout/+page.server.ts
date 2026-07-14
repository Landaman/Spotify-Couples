import { error, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';

// This prevents 404 errors if you manually try to navigate here
export const load: PageServerLoad = () => {
	error(404);
};

export const actions = {
	/**
	 * Form action to log the user out entirely
	 */
	default: async ({ locals }) => {
		// Signout
		const { error: authError } = await locals.supabase.auth.signOut();
		if (authError) {
			// So we don't forget about these...
			console.trace(authError);
		}

		await locals.refreshSession();

		// Send the user back to the homepage
		throw redirect(303, '/');
	}
} satisfies Actions;
