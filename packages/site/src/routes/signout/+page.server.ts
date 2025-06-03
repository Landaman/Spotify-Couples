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
	default: async ({ locals: { supabase } }) => {
		// Signout
		const { error: authError } = await supabase.auth.signOut();
		if (authError) {
			// So we don't forget about these...
			console.error(authError);
		}

		// Send the user back to the homepage
		throw redirect(303, '/');
	}
} satisfies Actions;
