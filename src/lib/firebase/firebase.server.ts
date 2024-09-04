import { getApps, initializeApp } from 'firebase-admin/app';
import { DEFAULT_APP_NAME } from './firebase-config';

/**
 * Handles auth, adding Firebase primitives to the event
 * @param event the SvelteKit request object
 */
export const handle = async () => {
	// Setup the admin SDK
	if (!getApps().some((app) => app.name === DEFAULT_APP_NAME)) {
		// Doing it this way is required because:
		// - getApp() before init will throw
		// - getApps() will return a hosting backend app in prod even before initializeApp is called
		initializeApp(); // This automatically pulls from env
	}
};
