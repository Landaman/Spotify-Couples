import {
	Timestamp,
	type FirestoreDataConverter,
	type QueryDocumentSnapshot
} from 'firebase-admin/firestore';

export const PLAYS_SUBCOLLECTION_NAME = 'plays';

/**
 * Interface representing a play of a song at a given time
 */
export interface Play {
	/**
	 * Time the song was played at
	 */
	playedTime: Date;
	/**
	 * Spotify URI for the context the track was played in
	 */
	playedContextURI: string | null;
	/**
	 * The ID of the song according to Spotify
	 */
	spotifyId: string;
}

/**
 * Interface representing a play of a song in Firestore
 */
interface FirestorePlay {
	/**
	 * Time the song was played at
	 */
	playedTime: Timestamp;
	/**
	 * ID of the song according to Spotify
	 */
	spotifyId: string;
	/**
	 * Spotify URI for the context the track was played in
	 */
	playedContextURI: string | null;
}

/**
 * Converter for Firestore plays to plays
 */
export const FirestorePlayConverter: FirestoreDataConverter<Play, FirestorePlay> = {
	toFirestore(play: Play): FirestorePlay {
		return {
			playedTime: Timestamp.fromDate(play.playedTime),
			spotifyId: play.spotifyId,
			playedContextURI: play.playedContextURI
		};
	},

	fromFirestore(firestorePlay: QueryDocumentSnapshot<FirestorePlay, FirestorePlay>): Play {
		const data = firestorePlay.data();
		return {
			spotifyId: data.spotifyId,
			playedContextURI: data.playedContextURI,
			playedTime: data.playedTime.toDate()
		};
	}
};
