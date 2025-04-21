import { dev } from '$app/environment';
import { initializeApp } from 'firebase/app';
import {
	connectAuthEmulator,
	getAuth,
	inMemoryPersistence,
	signInWithCustomToken
} from 'firebase/auth';
import { connectFirestoreEmulator, getFirestore } from 'firebase/firestore';
import type { LayoutLoadEvent } from '../../routes/$types';
import { FIREBASE_DEFAULTS } from './firebase-config';

/**
 * Initializes the firebase client objects and stores, meant to be run only on the client
 * @param event the event being a part of the hook
 */
export const handle = async (event: LayoutLoadEvent) => {
	initializeApp(FIREBASE_DEFAULTS.config);
	const auth = getAuth();
	const firestore = getFirestore();

	// If we're in development, connect the emulators
	if (dev) {
		// Connect to the auth emulator
		connectAuthEmulator(auth, `http://${FIREBASE_DEFAULTS.emulatorHosts.auth ?? ''}`, {
			disableWarnings: true
		});

		// Now parse out and connect the firestore emulator
		const firestoreSegments = FIREBASE_DEFAULTS.emulatorHosts.firestore?.split(':') ?? [];
		connectFirestoreEmulator(firestore, firestoreSegments[0], Number(firestoreSegments[1]));
	}

	// If we have a user, sign them in with the custom token sent from the server
	if (event.data.user) {
		auth.setPersistence(inMemoryPersistence); // Do not persist at all, since we assign a new token on every page load
		signInWithCustomToken(auth, event.data.user.firebaseToken);
	}
};
