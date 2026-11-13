/** Daily estimated listening seconds in the selected timezone */
export interface JournalDay {
	/** Local bucket label: YYYY-MM-DD or YYYY-MM-DDTHH:mm for hourly ranges */
	day: string;
	/** Viewer's estimated seconds */
	you: number;
	/** Partner's estimated seconds */
	partner: number;
}

/** Bounded ranking returned by the authenticated journal RPC */
export interface JournalRanking {
	/** Spotify entity ID */
	id: string;
	/** Entity title */
	name: string;
	/** Artist/album context, empty for artist rankings */
	subtitle: string;
	/** Available album artwork URL */
	picture: string;
	/** Ranking entity type */
	category: 'songs' | 'artists' | 'albums';
	/** People included in the count */
	listener: 'both' | 'you' | 'partner';
	/** Deduplicated recorded plays */
	plays: number;
}

/** Song evidence aggregated within the selected period */
export interface JournalEvent {
	/** Spotify track ID */
	id: string;
	/** Track title */
	name: string;
	/** Album title */
	album: string;
	/** Artist names */
	artist: string;
	/** Album artwork URL */
	picture: string;
	/** Reason for inclusion */
	kind: 'shared' | 'unique' | 'discovery';
	/** Listener responsible for the event */
	listener: 'both' | 'you' | 'partner';
	/** Viewer's plays in selected period */
	you: number;
	/** Partner's plays in selected period */
	partner: number;
	/** Latest overlap start or latest relevant recorded play */
	occurred_at: string;
	/** First recorded play in all stored history, when within this period */
	first_play: string | null;
	/** Viewer's first recorded play across all retained history, independent of range */
	you_first_play: string | null;
	/** Partner's first recorded play across all retained history, independent of range */
	partner_first_play: string | null;
	/** Unioned same-song overlap seconds */
	overlap_seconds: number | null;
}

/** Pair-scoped journal payload produced by the database */
export interface Journal {
	/** Inclusive range boundary */
	start: string;
	/** Exclusive range boundary, fixed at query time */
	end: string;
	/** IANA timezone for boundaries and daily buckets */
	timezone: string;
	/** Unioned estimated listening seconds for viewer */
	you_seconds: number;
	/** Unioned estimated listening seconds for partner */
	partner_seconds: number;
	/** Unioned same-song estimated overlap seconds */
	overlap_seconds: number;
	/** Zero-filled calendar-day or rolling hourly buckets */
	daily: JournalDay[];
	/** At most five entities per category and listener */
	rankings: JournalRanking[];
	/** At most six entries per reason and listener */
	timeline: JournalEvent[];
}

/**
 * Formats estimated seconds with enough precision for short overlaps
 * @param seconds - Nonnegative estimated duration
 * @returns Readable hours/minutes or seconds
 */
export function duration(seconds: number): string {
	if (seconds < 60) return `${Math.round(seconds)}s`;
	const minutes = Math.floor(seconds / 60);
	return minutes >= 60 ? `${Math.floor(minutes / 60)}h ${minutes % 60}m` : `${minutes}m`;
}
