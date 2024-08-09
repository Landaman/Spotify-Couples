// See https://kit.svelte.dev/docs/types#app
// for information about these interfaces
declare global {
	namespace App {
		// interface Error {}
		// interface Locals {}
		interface PageData {
			/**
			 * Name to add onto the pre-existing site name set in the root layout
			 */
			pageTitle?: string;
		}
		// interface PageState {}
		// interface Platform {}
	}
}

export {};
