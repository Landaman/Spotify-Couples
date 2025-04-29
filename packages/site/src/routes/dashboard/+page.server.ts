import { env } from '$env/dynamic/private';
import { redirectToSignIn } from '$lib/auth/auth.server';
import { USER_COLLECTION_NAME } from '@spotify-couples/core/lucia';
import { FirestorePlayConverter, PLAYS_SUBCOLLECTION_NAME } from '@spotify-couples/core/plays';
import { SpotifyApi } from '@spotify/web-api-ts-sdk';
import { redirect } from '@sveltejs/kit';
import { getFirestore } from 'firebase-admin/firestore';
import type { PageServerLoad } from './$types';

async function getMyAllTimeSongs(userId: string, limit: number) {
	const firestore = getFirestore();

	const songsForUser = firestore
		.collection(USER_COLLECTION_NAME)
		.doc(userId)
		.collection(PLAYS_SUBCOLLECTION_NAME)
		.withConverter(FirestorePlayConverter)
		.orderBy('spotifyId');

	const spotifyIdToCount: Record<string, number> = {};
	let lastSong: string | undefined;

	while (true) {
		const songQuery = lastSong ? songsForUser.startAfter(lastSong) : songsForUser;
		const thisSongId = (await songQuery.limit(1).get()).docs[0]?.data().spotifyId; // Ensure we actually got a doc

		if (!thisSongId) {
			break;
		}

		const thisSongCount = await songsForUser.where('spotifyId', '==', thisSongId).count().get();
		spotifyIdToCount[thisSongId] = thisSongCount.data().count;
		lastSong = thisSongId;
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

	for (const songId of Object.keys(spotifyIdToCount)
		.sort((a, b) => spotifyIdToCount[b] - spotifyIdToCount[a]) // sort by play count desc
		.slice(0, limit)) {
		const spotifyTrack = await spotifySdk.tracks.get(songId);

		topSongs.push({
			album: spotifyTrack.album.name,
			albumPicture: spotifyTrack.album.images[0].url,
			artist: spotifyTrack.artists.reduce(
				(accumulator, artist) =>
					accumulator.length > 0 ? accumulator + ', ' + artist.name : artist.name,
				''
			),
			plays: spotifyIdToCount[songId],
			trackName: spotifyTrack.name
		});
	}

	return topSongs;
}

export const load: PageServerLoad = async (event) => {
	const { locals, url } = event;

	// Validate we have a user
	if (!locals.user) {
		throw redirectToSignIn(url.toString(), event); // If not, sign them in and then come back
	}

	// Validate the user has a partner
	if (!locals.partner) {
		throw redirect(303, '/signup'); // If the user doesn't have a partner, redirect to signup to get them a partner
	}

	return {
		songs: await getMyAllTimeSongs(locals.user.id, 5)
	};
};
