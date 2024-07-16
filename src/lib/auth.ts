import { SvelteKitAuth } from '@auth/sveltekit';
import Spotify from '@auth/sveltekit/providers/spotify';

/**
 * Primary authentication handle setup by Auth.js
 */
export const { handle, signIn, signOut } = SvelteKitAuth({
	providers: [Spotify]
});
