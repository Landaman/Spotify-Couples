import { redirectToSignIn } from '#lib/auth/auth.server.js';
import { isLocalSupabaseUrl, isUrlHostedLocally } from '#lib/auth/auth.ts';
import { dev } from '$app/env';
import { PUBLIC_SUPABASE_URL } from '$app/env/public';
import { error, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import { RedirectUrlFormField } from './shared';

/**
 * Accept local test magic links while keeping other GET requests unavailable
 * @param event the request event containing the URL, auth client, and response header setter
 * @returns never returns normally; redirects after login or throws an HTTP error
 */
export const load: PageServerLoad = async ({ url, locals, setHeaders }) => {
	// We allow magic links in dev to enable easy sign-in as test users
	if (dev && isLocalSupabaseUrl(new URL(PUBLIC_SUPABASE_URL)) && isUrlHostedLocally(url)) {
		const tokenHash = url.searchParams.get('token_hash');
		if (tokenHash) {
			setHeaders({ 'cache-control': 'no-store', 'referrer-policy': 'no-referrer' });
			const { error: authError } = await locals.supabase.auth.verifyOtp({
				token_hash: tokenHash,
				type: 'magiclink'
			});
			if (authError) {
				error(400, 'This login link expired or was already used. Generate a fresh link');
			}
			redirect(303, '/dashboard');
		}
	}
	return error(404);
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
