import type { Enums } from '#supabase/schema.js';

export const ShowPartnerSearchParameter = 'showPartner';

/** Listener accepted by the Top Songs RPC */
export type TopSongsListener = Enums<'top_songs_listener'>;

/** Runtime enum values checked against the generated database enum */
export const TopSongsListener = {
	combined: 'combined',
	you: 'you',
	partner: 'partner'
} as const satisfies { [Listener in TopSongsListener]: Listener };

/** Values used to populate the listener selector */
export const TopSongsListeners = Object.values(TopSongsListener);

/**
 * Check whether a URL or selector value names a supported listener
 * @param value - Raw value from the URL or selector
 * @returns Whether the value belongs to the Top Songs listener enum
 */
export function isTopSongsListener(value: string | null): value is TopSongsListener {
	return TopSongsListeners.some((listener) => listener === value);
}

/**
 * Read a dashboard listener from its URL parameter
 * @param value - Raw listener from the URL
 * @returns The requested listener or Combined by default
 */
export function parseTopSongsListener(value: string | null): TopSongsListener {
	return isTopSongsListener(value) ? value : TopSongsListener.combined;
}

/** Date ranges for ranking recorded plays, with All time as the default */
export const TopSongsDateRanges = [
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
export function findTopSongsDateRange(value: string | null) {
	return TopSongsDateRanges.find(({ days }) => (days?.toString() ?? null) === value);
}
