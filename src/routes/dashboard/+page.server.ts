import { redirectToSignIn } from '$lib/auth/auth.server';
import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

async function getDashboard(supabase: App.Locals['supabase']) {
	const { data, error } = await supabase.rpc('get_dashboard');

	if (error) throw error;

	return data.map((song) => ({
		album: song.album,
		albumPicture: song.album_picture,
		artist: song.artist,
		plays: song.plays,
		trackName: song.track_name
	}));
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

	return {
		session,
		partner: partner,
		songs: dataRefreshPromise
			? dataRefreshPromise.then(() => getDashboard(supabase))
			: await getDashboard(supabase)
	};
};
