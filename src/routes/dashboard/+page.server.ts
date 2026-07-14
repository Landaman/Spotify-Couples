import { redirectToSignIn } from '$lib/auth/auth.server';
import { validateProfile } from '$lib/database/profiles';
import type { Database } from '$supabase/schema';
import type { SupabaseClient, User } from '@supabase/supabase-js';
import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

async function getMyAllTimeSongs(limit: number, supabase: SupabaseClient<Database>, user: User) {
	const { data, error } = await supabase
		.from('plays')
		.select(
			`
				track_id,
				count(),
				track:tracks!inner(
					name,
					artist_ids,
					album:albums!inner(
						name,
						picture_url
					)
				)
			`
		)
		.eq('user_id', user.id)
		.order('count', { ascending: false })
		.limit(limit);

	if (error || !data) {
		throw error;
	}

	const artistIds = [...new Set(data.flatMap((song) => song.track.artist_ids))];
	const artistNamesById = new Map<string, string>();

	if (artistIds.length > 0) {
		const { data: artists, error: artistsError } = await supabase
			.from('artists')
			.select('id, name')
			.in('id', artistIds);

		if (artistsError || !artists) {
			throw artistsError;
		}

		artists.forEach((artist) => {
			artistNamesById.set(artist.id, artist.name);
		});
	}

	return data.map((song) => ({
		album: song.track.album.name,
		albumPicture: song.track.album.picture_url ?? '',
		artist: song.track.artist_ids
			.map((artistId) => artistNamesById.get(artistId))
			.filter((artistName) => artistName !== undefined)
			.join(', '),
		plays: song.count,
		trackName: song.track.name
	}));
}

export const load: PageServerLoad = async (event) => {
	const {
		locals: { partnerId, session, supabase },
		url
	} = event;

	// Validate we have a user
	if (!session) {
		throw await redirectToSignIn(url.pathname, event); // If not, sign them in and then come back
	}

	// Validate the user has a partner
	if (!partnerId) {
		throw redirect(303, '/signup'); // If the user doesn't have a partner, redirect to signup to get them a partner
	}

	// Fetch the users partners profile
	const { data: partnersProfile, error } = await supabase.rpc('get_partner_profile');
	if (error) {
		throw error;
	}

	return {
		session,
		partnersProfile: validateProfile(partnersProfile),
		songs: await getMyAllTimeSongs(5, supabase, session.user)
	};
};
