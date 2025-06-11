import { env } from '$env/dynamic/private';
import { redirectToSignIn } from '$lib/auth/auth.server';
import { validateProfile } from '$lib/database/profiles';
import type { Database } from '$lib/database/schema';
import { SpotifyApi } from '@spotify/web-api-ts-sdk';
import type { SupabaseClient, User } from '@supabase/supabase-js';
import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

async function getMyAllTimeSongs(limit: number, supabase: SupabaseClient<Database>, user: User) {
	const { data, error } = await supabase
		.from('plays')
		.select('spotify_id, count()')
		.eq('user_id', user.id)
		.order('count', { ascending: false })
		.limit(limit);

	if (error) {
		throw error;
	}

	if (!data) {
		throw new Error('Failed to fetch top songs for user');
	}

	const topSongs: {
		albumPicture: string;
		trackName: string;
		artist: string;
		album: string;
		plays: number;
	}[] = [];

	const spotifySdk = SpotifyApi.withClientCredentials(
		env.SPOTIFY_CLIENT_ID,
		env.SPOTIFY_CLIENT_SECRET,
		[]
	);

	for (const song of data) {
		const spotifyTrack = await spotifySdk.tracks.get(song.spotify_id);

		topSongs.push({
			album: spotifyTrack.album.name,
			albumPicture: spotifyTrack.album.images[0].url,
			artist: spotifyTrack.artists.reduce(
				(accumulator, artist) =>
					accumulator.length > 0 ? accumulator + ', ' + artist.name : artist.name,
				''
			),
			plays: song.count,
			trackName: spotifyTrack.name
		});
	}

	return topSongs;
}

export const load: PageServerLoad = async (event) => {
	const {
		locals: { safeGetSession, supabase },
		url
	} = event;
	const session = await safeGetSession();

	// Validate we have a user
	if (!session) {
		throw await redirectToSignIn(url.pathname, event); // If not, sign them in and then come back
	}

	// Validate the user has a partner
	if (!session.user.partnerId) {
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
