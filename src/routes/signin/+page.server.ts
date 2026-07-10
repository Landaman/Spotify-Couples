import { redirectToSignIn } from '$lib/auth/auth.server';
import { error } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import { RedirectUrlFormField } from './shared';

// This prevents 404 errors if you manually try to navigate here
export const load: PageServerLoad = () => {
	error(404);
};

export const actions = {
	/**
	 * Form action to redirect the user to spotify
	 */
	default: async (event) => {
		// Get the redirect URL from the form data
		const formData = await event.request.formData();
		const redirectUrl = formData.get(RedirectUrlFormField)?.toString() || '/'; // Redirect to / if no redirect provided

		throw await redirectToSignIn(redirectUrl, event);
	}
} satisfies Actions;
