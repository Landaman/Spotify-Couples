import { browser } from '$app/environment';
import { handle as firebaseHandle } from '$lib/firebase/firebase.client';
import type { LayoutLoad } from './$types';

/**
 * Layout loader, initializes the firebase client data
 * @param event the event to handle loading data from
 */
export const load: LayoutLoad = async (event) => {
	// If we're running on the server, the app information will
	// already be handled
	if (browser) {
		await firebaseHandle(event);
	}

	return {
		...event.data
	};
};
