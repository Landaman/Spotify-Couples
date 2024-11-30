import { handle as authHandle } from '$lib/auth/auth.server';
import { handle as firebaseHandle } from '$lib/firebase/firebase.server';
import type { Handle } from '@sveltejs/kit';
/**
 * Server hook, runs before everything else before any SvelteKit requests are made
 */
export const handle: Handle = async ({ event, resolve }) => {
	await firebaseHandle(); // Setup firebase stuff
	await authHandle(event); // Setup auth stuff (after Firebase)

	return resolve(event);
};
