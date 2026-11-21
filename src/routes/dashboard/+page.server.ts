import { posthog } from '#lib/analytics/analytics.server.js';
import { redirectToSignIn } from '#lib/auth/auth.server.js';
import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';
import { TopSongsListener, isTopSongsListener } from './shared';

/**
 * Loads ranked tracks and their play counts
 * @param supabase - Client identifying the authenticated user
 * @param listener - Whose plays to rank
 * @returns Dashboard songs ready for display
 * @throws If the Top Songs RPC fails
 */
async function getTopSongs(supabase: App.Locals['supabase'], listener: TopSongsListener) {
	return posthog.withSpan('supabase.rpc.get_top_songs', { kind: 'client' }, async () => {
		const { data, error } = await supabase.rpc('get_top_songs', { listener });
		if (error) {
			throw error;
		}
		return data;
	});
}

export const load: PageServerLoad = async (event) => {
	const {
		locals: { dataRefreshPromise, partner, session, supabase },
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

	const requestedListener = url.searchParams.get('listener');
	const listener = isTopSongsListener(requestedListener)
		? requestedListener
		: TopSongsListener.combined;

	const songs = (dataRefreshPromise ?? Promise.resolve())
		.then(() => getTopSongs(supabase, listener))
		.catch((error: unknown) => {
			posthog.captureException(error);
			return null;
		});

	return {
		listener,
		session,
		partner: partner,
		songs
	};
};
