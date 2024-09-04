import { REDIRECT_URL_FORM_FIELD } from '$lib/auth/auth';
import { redirectToSignIn } from '$lib/auth/auth.server';
import { error } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';

// This prevents 404 errors if you manually try to navigate here
export const load: PageServerLoad = () => {
	error(404);
};

export const actions = {
	/**
	 * Form action to redirect the user to spotify
	 */
	default: async (event) => {
		// Get the form data to get the redirect url
		const formData = await event.request.formData();
		const redirectUrl = formData.get(REDIRECT_URL_FORM_FIELD)?.toString() || '/'; // Redirect to / if no redirect provided

		redirectToSignIn(redirectUrl, event);
	}
} satisfies Actions;
