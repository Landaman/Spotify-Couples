import { redirectToParamName, signInAction } from '$lib/auth';
import { redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
export const actions: Actions = { default: signInAction };

export const load: PageServerLoad = async ({ locals }) => {
	const session = await locals.auth();

	if (session) {
		throw redirect(303, '/');
	}

	// This can't be directly imported on the client because of security
	return {
		redirectToParamName: redirectToParamName
	};
};
