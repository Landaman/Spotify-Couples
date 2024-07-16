// See https://kit.svelte.dev/docs/types#app
// for information about these interfaces
declare global {
	namespace App {
		// interface Error {}
		// interface Locals {}
		// interface PageData {}
		// interface PageState {}
		// interface Platform {}
	}
}

/**
 * Typings for process.env
 */
declare namespace NodeJS {
	interface ProcessEnv {
		/**
		 * Randomly generated authentication secret used by Auth.js
		 */
		AUTH_SECRET: string;

		/**
		 * OAuth Client ID for the Spotify API OAuth flow
		 */
		AUTH_SPOTIFY_ID: string;

		/**
		 * OAuth Client Secret for the Spotify API OAuth flow
		 */
		AUTH_SPOTIFY_SECRET: string;
	}
}

export {};
