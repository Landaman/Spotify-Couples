import type { Database } from '$supabase/schema';
import { SQL } from 'bun';
import { client, getSeedUserIds } from './helpers';

type Track = Pick<Database['public']['Tables']['tracks']['Row'], 'album_id' | 'id'>;
type SelectionKind = 'albums' | 'artists' | 'tracks';
interface SelectionTracks {
	tracks: Track[];
}

/**
 * Re-arranges a list randomly. Keeps the contents the same
 * @param values the values to shuffle
 * @returns the shuffled values
 */
function shuffle<T>(values: readonly T[]): T[] {
	const shuffled = [...values];
	for (let index = shuffled.length - 1; index > 0; index -= 1) {
		const replacementIndex = Math.floor(Math.random() * (index + 1));
		[shuffled[index], shuffled[replacementIndex]] = [shuffled[replacementIndex], shuffled[index]];
	}
	return shuffled;
}

/**
 * Randomly selects one item from the provided array
 * @param values array of values to select one item from
 * @returns one value from the passed array
 */
function randomItem<T>(values: readonly T[]): T {
	return values[Math.floor(Math.random() * values.length)] as T;
}

/**
 * Gets all the tracks associated with count number of random kind entities
 * @param kind the type of entity to select (track, artist, album)
 * @param count the number of entities to select tracks for
 */
async function getSelectionTracks(kind: SelectionKind, count: number): Promise<SelectionTracks[]> {
	const sql = new SQL('postgresql://postgres:postgres@127.0.0.1:54322/postgres');
	try {
		switch (kind) {
			case 'tracks':
				return await sql<SelectionTracks[]>`
					SELECT jsonb_build_array(jsonb_build_object('id', id, 'album_id', album_id)) AS tracks
					FROM public.tracks
					ORDER BY random()
					LIMIT ${count}
				`;
			case 'albums':
				return await sql<SelectionTracks[]>`
					WITH selected AS (
						SELECT album_id FROM public.tracks
						GROUP BY album_id 
						ORDER BY random()
						LIMIT ${count}
					)
					SELECT jsonb_agg(jsonb_build_object('id', t.id, 'album_id', t.album_id)) AS tracks
					FROM selected
						JOIN public.tracks t USING (album_id)
					GROUP BY selected.album_id
					ORDER BY random()
				`;
			case 'artists':
				// Solo tracks keep the observed artist union exactly equal to the requested count, even when the catalog
				// also contains collaborations with artists outside the randomly selected set.
				return await sql<SelectionTracks[]>`
					WITH selected AS (
						SELECT artist_ids[1] AS artist_id FROM public.tracks
						WHERE cardinality(artist_ids) = 1
						GROUP BY artist_ids[1]
						ORDER BY random()
						LIMIT ${count}
					)
					SELECT jsonb_agg(jsonb_build_object('id', t.id, 'album_id', t.album_id)) AS tracks
					FROM selected JOIN public.tracks t
						ON t.artist_ids = ARRAY[selected.artist_id]
					GROUP BY selected.artist_id
					ORDER BY random()
				`;
		}
	} finally {
		await sql.close();
	}
}

/**
 * Takes the provided entities, and divides them up into sets for the partner user and the supplied user
 * @param entities the entities to divide up
 * @param selectionCount the number of distinct entities to select for each user
 * @param commonalityPercentage the percentage of entities that should be shared between the two users
 * @returns the actual number of common entities, along with the entities for each user
 */
function selectEntitiesPerUser(
	entities: SelectionTracks[],
	selectionCount: number,
	commonalityPercentage: number
): { commonCount: number; partner: SelectionTracks[]; supplied: SelectionTracks[] } {
	const commonCount = Math.round((selectionCount * commonalityPercentage) / 100);
	const common = entities.slice(0, commonCount);

	const supplied = [...common, ...entities.slice(commonCount, selectionCount)];
	const partner = [...common, ...entities.slice(selectionCount, selectionCount * 2 - commonCount)];

	return { commonCount, partner, supplied };
}

/**
 * Selects the selected number of tracks from the provided entities, attempting
 * to keep the distribution of tracks as even as possible between the entities
 */
function selectPlayTracks(entities: SelectionTracks[], playCount: number): Track[] {
	const playTracks = entities.map((entity) => randomItem(entity.tracks));
	while (playTracks.length < playCount) {
		playTracks.push(randomItem(randomItem(entities).tracks));
	}
	return shuffle(playTracks);
}

/**
 * Creates plays for each of the provided tracks for the provided user.
 * Keeps the date random but between the provided bounds
 * @param userId the user who the play should be for
 * @param entities the entities containing the plays that should be assigned to the user
 * @param playCount the number of tracks from the entities to take
 * @param lowerBound the lower date range (epoch)
 * @param upperBound the upper bound (epoch)
 */
function createPlays(
	userId: string,
	entities: SelectionTracks[],
	playCount: number,
	lowerBound: number,
	upperBound: number
): Database['public']['Tables']['plays']['Insert'][] {
	return selectPlayTracks(entities, playCount).map((track) => ({
		played_date_time: new Date(
			lowerBound + Math.random() * (upperBound - lowerBound)
		).toISOString(),
		spotify_played_context_uri: `spotify:album:${track.album_id}`,
		track_id: track.id,
		user_id: userId
	}));
}

/**
 * Adds randomized local plays for the supplied user and partnerpartner
 * @param days duration of the play window ending at upperBound
 * @param playCount number of play rows to create per user
 * @param selectionKind metadata type whose distinct count should be constrained
 * @param selectionCount exact number of distinct tracks, albums, or artists per user
 * @param commonalityPercentage requested percentage of selected entities shared by both users
 * @param upperBound latest time at which a play may occur
 */
export default async function seedPlays(
	days: number,
	playCount: number,
	selectionKind: SelectionKind,
	selectionCount: number,
	commonalityPercentage: number,
	upperBound: Date
): Promise<void> {
	if (commonalityPercentage < 0 || commonalityPercentage > 100) {
		throw new Error('Common percentage must be between 0 and 100');
	}
	const upperBoundTime = upperBound.getTime();
	const lowerBoundTime = upperBoundTime - days * 24 * 60 * 60 * 1000;
	if (!Number.isFinite(upperBoundTime) || !Number.isFinite(new Date(lowerBoundTime).getTime())) {
		throw new Error('The play window must have valid date bounds');
	}

	const [suppliedUserId, partnerUserId] = await getSeedUserIds();

	const requiredCount =
		selectionCount * 2 - Math.round((selectionCount * commonalityPercentage) / 100);
	const entities = await getSelectionTracks(selectionKind, requiredCount);
	if (entities.length < requiredCount) {
		throw new Error(
			`Need ${requiredCount} distinct ${selectionKind}, but only ${entities.length} are available`
		);
	}

	const selections = selectEntitiesPerUser(entities, selectionCount, commonalityPercentage);
	const plays = [
		...createPlays(suppliedUserId, selections.supplied, playCount, lowerBoundTime, upperBoundTime),
		...createPlays(partnerUserId, selections.partner, playCount, lowerBoundTime, upperBoundTime)
	];

	const actualCommonalityPercentage = (selections.commonCount / selectionCount) * 100;
	console.log(
		`Selected ${selectionCount} distinct ${selectionKind} per user with ${selections.commonCount} common (${actualCommonalityPercentage.toFixed(1)}%; requested ${commonalityPercentage}%)`
	);

	console.log(
		`Adding ${playCount} plays per user from ${new Date(lowerBoundTime).toISOString()} through ${upperBound.toISOString()}`
	);

	// Insert in batches
	for (let start = 0; start < plays.length; start += 500) {
		const { error } = await client.from('plays').insert(plays.slice(start, start + 500));
		if (error) {
			throw error;
		}
	}

	console.log(`Seeded ${plays.length} plays`);
}
