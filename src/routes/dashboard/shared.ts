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
