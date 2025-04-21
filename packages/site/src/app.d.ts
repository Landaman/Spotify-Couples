// See https://kit.svelte.dev/docs/types#app

import type { Lucia, Session, User } from 'lucia';

// for information about these interfaces
declare global {
	namespace App {
		// interface Error {}
		interface Locals {
			/**
			 * Lucia auth, used for authentication
			 */
			auth: Lucia;
			/**
			 * Lucia user, when they are signed in and valid
			 */
			user: User | null;
			/**
			 * The users partner, when they are signed in and have a partner
			 */
			partner: User | null;
			/**
			 * Lucia session, when it is valid
			 */
			session: Session | null;
		}
		interface PageData {
			/**
			 * Name to add onto the pre-existing site name set in the root layout
			 */
			pageTitle?: string;
			/**
			 * The user if they are currently authenticated. Null if they are not
			 */
			user: (User & { firebaseToken: string }) | null;
			/**
			 * The user's partner if they are currently authenticated. Null if they are not or if they don't have a partner
			 */
			partner: User | null;
		}
		// interface PageState {}
		// interface Platform {}
	}

	// This is injected by Vite at build time
	declare const __FIREBASE_DEFAULTS__: {
		emulatorHosts: {
			auth?: string;
			firestore?: string;
		};
		config: FirebaseOptions;
	};
}

// This indicates to the compiler that this is a module, which
// is important to augment global
export {};
