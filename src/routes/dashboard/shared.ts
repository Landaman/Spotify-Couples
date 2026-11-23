import type { Database, Enums } from '#supabase/schema.js';

export const ShowPartnerSearchParameter = 'showPartner';

/** Listener accepted by the Top Listens RPC */
export type TopListensListener = Enums<'top_listens_listener'>;

/** Runtime enum values checked against the generated database enum */
export const TopListensListener = {
	combined: 'combined',
	you: 'you',
	partner: 'partner'
} as const satisfies { [Listener in TopListensListener]: Listener };

/** Values used to populate the listener selector */
export const TopListensListeners = Object.values(TopListensListener);

/**
 * Check whether a URL or selector value names a supported listener
 * @param value - Raw value from the URL or selector
 * @returns Whether the value belongs to the Top Listens listener enum
 */
export function isTopListensListener(value: string | null): value is TopListensListener {
	return TopListensListeners.some((listener) => listener === value);
}

/**
 * Read a dashboard listener from its URL parameter
 * @param value - Raw listener from the URL
 * @returns The requested listener or Combined by default
 */
export function parseTopListensListener(value: string | null): TopListensListener {
	return isTopListensListener(value) ? value : TopListensListener.combined;
}

/** Date ranges for ranking recorded plays, with All time as the default */
export const TopListensDateRanges = [
	{ label: 'All time', days: undefined },
	{ label: 'Last 7 days', days: 7 },
	{ label: 'Last 30 days', days: 30 },
	{ label: 'Last 90 days', days: 90 }
] as const;

/**
 * Look up a dashboard date range from its URL parameter
 * @param value - Raw value from the URL, or null for all time
 * @returns The matching range, or undefined for an unsupported value
 */
export function findTopListensDateRange(value: string | null) {
	return TopListensDateRanges.find(({ days }) => (days?.toString() ?? null) === value);
}

/** RPC for each category in the Top Listens card */
export const TopListensRpcs = {
	song: 'get_top_songs',
	artist: 'get_top_artists',
	album: 'get_top_albums',
	genre: 'get_top_genres'
} as const satisfies Record<string, keyof Database['public']['Functions']>;

/** Categories available in the Top Listens card */
export type TopListensCategory = keyof typeof TopListensRpcs;

/** Display labels for the category selector and empty states */
export const TopListensCategories = {
	song: 'Songs',
	artist: 'Artists',
	album: 'Albums',
	genre: 'Genres'
} as const satisfies Record<TopListensCategory, string>;

/**
 * Check whether a URL or selector value names a supported category
 * @param value - Raw value from the URL or selector
 * @returns Whether the value is a Top Listens category
 */
export function isTopListensCategory(value: string | null): value is TopListensCategory {
	return value !== null && Object.hasOwn(TopListensCategories, value);
}

/**
 * Read a dashboard category from its URL parameter
 * @param value - Raw category from the URL
 * @returns The requested category or Songs by default
 */
export function parseTopListensCategory(value: string | null): TopListensCategory {
	return isTopListensCategory(value) ? value : 'song';
}

/** The category RPCs each supply their own ranking row */
export type TopListen =
	Database['public']['Functions'][(typeof TopListensRpcs)[TopListensCategory]]['Returns'][number];
