import { posthog } from '#lib/analytics/analytics.server.js';
import { getRequestEvent, query } from '$app/server';
import { error } from '@sveltejs/kit';
import { isTopListensListener, TopListensDateRanges, type RankingFilters } from './shared';

/** RPCs that accept the dashboard’s listener and date filters */
type RankingRpc = 'get_top_songs' | 'get_top_artists' | 'get_top_albums' | 'get_top_genres';

/**
 * Validate filters and fetch a ranking for the authenticated couple
 * @param rpc - Category-specific Supabase RPC
 * @param filters - Listener and date filters from the client
 * @returns Typed ranking rows, or null if the RPC failed
 */
async function loadRanking<Rpc extends RankingRpc>(rpc: Rpc, filters: RankingFilters) {
	const { locals } = getRequestEvent();
	if (!locals.session) error(401);
	if (!locals.partner) error(403);

	if (
		!filters ||
		!isTopListensListener(filters.listener) ||
		!TopListensDateRanges.some(({ days }) => (days ?? null) === filters.rangeDays)
	) {
		error(400, 'Invalid Top Listens filters');
	}

	try {
		await locals.dataRefreshPromise;
		return await posthog.withSpan(`supabase.rpc.${rpc}`, { kind: 'client' }, async () => {
			const { data, error: rpcError } = await locals.supabase.rpc(rpc, {
				listener: filters.listener,
				// The required SQL argument accepts NULL for all time
				range_days: filters.rangeDays as number
			});
			if (rpcError) throw rpcError;
			return data;
		});
	} catch (cause) {
		posthog.captureException(cause);
		return null;
	}
}

/** Fetch the highest-ranked songs and their track metadata */
export const getTopSongs = query('unchecked', (filters: RankingFilters) =>
	loadRanking('get_top_songs', filters)
);

/** Fetch the highest-ranked artists */
export const getTopArtists = query('unchecked', (filters: RankingFilters) =>
	loadRanking('get_top_artists', filters)
);

/** Fetch the highest-ranked albums */
export const getTopAlbums = query('unchecked', (filters: RankingFilters) =>
	loadRanking('get_top_albums', filters)
);

/** Fetch the highest-ranked genres */
export const getTopGenres = query('unchecked', (filters: RankingFilters) =>
	loadRanking('get_top_genres', filters)
);
