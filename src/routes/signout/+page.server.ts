import { error, fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';

// This prevents 404 errors if you manually try to navigate here
export const load: PageServerLoad = () => {
	error(404);
};

export const actions = {
	/**
	 * Form action to log the user out entirely
	 */
	default: async ({ cookies, locals }) => {
		// If there is no session
		if (!locals.session) {
			return fail(401); // We can't sign out, so just error
		}

		// Otherwise, invalidate the session
		await locals.auth.invalidateSession(locals.session.id);

		// Assign a blank session cookie so we don't try to log them in by mistake next time
		const sessionCookie = locals.auth.createBlankSessionCookie();
		cookies.set(sessionCookie.name, sessionCookie.value, {
			path: '/',
			...sessionCookie.attributes
		});

		// And redirect to the homepage
		redirect(302, '/');
	}
} satisfies Actions;
