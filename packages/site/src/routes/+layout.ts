import { PUBLIC_SUPABASE_ANON_KEY, PUBLIC_SUPABASE_URL } from '$env/static/public';
import { safeGetSession } from '$lib/auth/auth';
import type { Database } from '$lib/database/schema';
import { createBrowserClient, createServerClient, isBrowser } from '@supabase/ssr';
import type { LayoutLoad } from './$types';
import { SupabaseAuthDependency } from './shared';

/**
 * Layout loader, initializes the supabase client data
 * @param event the event to handle loading data from
 */
export const load: LayoutLoad = async ({ data, depends, fetch }) => {
	depends(SupabaseAuthDependency);

	const supabase = isBrowser()
		? createBrowserClient<Database>(PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY, {
				global: {
					fetch
				}
			})
		: // Why not pass this from the server loader? Serializing cookies is WAY easier
			// than serializing a supabase client (which would be done otherwise)
			// this assumes that all cookies are safe to publish to the client,
			// which should be a safe assumption with Supabase
			createServerClient<Database>(PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY, {
				global: {
					fetch
				},
				// Do not pass setAll, since we shouldn't be setting cookies in
				// the SSR "shallow" version of the client. Only the client in
				// "hooks" can do that
				cookies: {
					getAll() {
						return data.cookies;
					}
				}
			});
	// Why not just safeGetSession(supabase)? This supabase session is ONLY for SSR
	// purposes and therefore it does not get to be the global holder of auth state
	// across the client/server - that is the one setup in the hook
	const session = isBrowser() ? await safeGetSession(supabase) : data.session;

	return {
		session,
		supabase
	};
};
