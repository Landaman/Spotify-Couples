import { posthog } from '#lib/analytics/analytics.server.js';
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
		// withContext({}) copies inherited identity into a separate context object
		// PostHog prepares exception events asynchronously, so captures keep that identity
		// even if refreshSession clears the parent context before preparation finishes
		await posthog.withContext({}, () =>
			posthog.withSpan('supabase.auth.signOut', { kind: 'client' }, async (span) => {
				const result = await locals.supabase.auth.signOut();
				if (result.error) {
					span.recordException(result.error);
					console.trace(result.error);
					posthog.captureException(result.error);
				}
				return result;
			})
		);

		await locals.refreshSession();

		// Send the user back to the homepage
		throw redirect(303, '/');
	}
} satisfies Actions;
