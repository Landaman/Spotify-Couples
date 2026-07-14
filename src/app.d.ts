// See https://kit.svelte.dev/docs/types#app

import type { Profile } from '$lib/database/profiles';
import type { Database } from '$supabase/schema';
import type { Session, SupabaseClient, User } from '@supabase/supabase-js';

type UserWithData = User & {
	profile: Profile;
};
type SessionWithUserWithData = Session & {
	user: UserWithData;
};

// for information about these interfaces
declare global {
	namespace App {
		// interface Error {}
		interface Locals {
			/**
			 * The supabase client to use with all SSR
			 */
			supabase: SupabaseClient<Database>;
			/**
			 * The user's current supabase session, if valid.
			 */
			session: SessionWithUserWithData | null;
			/**
			 * The user's current partner id, if they have one.
			 */
			partnerId: string | null;
			/**
			 * Refreshes the request-local session and partner id after an auth mutation.
			 */
			refreshSession: () => Promise<SessionWithUserWithData | null>;
			/**
			 * Refreshes the request-local partner id after a partner-only mutation.
			 */
			refreshPartnerId: () => Promise<string | null>;
			/**
			 * Promise that resolves when any necessary data refresh is complete.
			 */
			dataRefreshPromise: Promise<boolean> | undefined;
		}
		interface PageData {
			pageInformation?: {
				/**
				 * Name to add onto the pre-existing site name set in the root layout
				 */
				pageTitle?: string;
				/**
				 * Whether this page needs data before loading. This won't actually affect
				 * anything other than a toast showing while data is being loaded.
				 * Pages should look at dataRefreshPromise to actually determine the loading state
				 */
				needsData?: boolean;
			};
			/**
			 * The supabase client to use with all SSR
			 */
			supabase: SupabaseClient<Database>;
			/**
			 * The user's current supabase session, if valid
			 */
			session: SessionWithUserWithData | null;
			/**
			 * Promise that resolves when any necessary data refresh is complete
			 */
			dataRefreshPromise: Promise<boolean> | undefined;
		}

		// interface PageState {}
		// interface Platform {}
	}
}

// This indicates to the compiler that this is a module, which
// is important to augment global
export {};
