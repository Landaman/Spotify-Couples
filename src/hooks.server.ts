import { PUBLIC_SUPABASE_ANON_KEY, PUBLIC_SUPABASE_URL } from '$env/static/public';
import { safeGetSession } from '$lib/auth/auth';
import { validateProfile } from '$lib/database/profiles';
import type { Database } from '$supabase/schema';
import { createServerClient } from '@supabase/ssr';
import { type Handle } from '@sveltejs/kit';
import { sequence } from '@sveltejs/kit/hooks';

const supabase: Handle = async ({ event, resolve }) => {
	/**
	 * Creates a Supabase client specific to this server request.
	 *
	 * The Supabase client gets the Auth token from the request cookies.
	 */
	event.locals.supabase = createServerClient<Database>(
		PUBLIC_SUPABASE_URL,
		PUBLIC_SUPABASE_ANON_KEY,
		{
			// Do not pass globals -> fetch since we aren't doing SSR directly on this
			cookies: {
				// Pass both of these, as the server client can actually play with cookies
				// for auth
				getAll: () => event.cookies.getAll(),
				/**
				 * SvelteKit's cookies API requires `path` to be explicitly set in
				 * the cookie options. Setting `path` to `/` replicates previous/
				 * standard behavior.
				 */
				setAll: (cookiesToSet) => {
					cookiesToSet.forEach(({ name, value, options }) => {
						event.cookies.set(name, value, { ...options, path: '/' });
					});
				}
			}
		}
	);

	event.locals.refreshPartner = async () => {
		if (!event.locals.session) {
			event.locals.partner = null;
			return event.locals.partner;
		}

		const { data, error } = await event.locals.supabase.rpc('get_partner_profile');
		if (error) {
			throw error;
		}

		event.locals.partner = data ? validateProfile(data) : null;
		return event.locals.partner;
	};

	event.locals.refreshSession = async () => {
		event.locals.session = await safeGetSession(event.locals.supabase);
		await event.locals.refreshPartner();
		return event.locals.session;
	};

	event.locals.session = await safeGetSession(event.locals.supabase);
	event.locals.dataRefreshPromise = undefined;
	event.locals.partner = null;

	if (event.locals.session) {
		const { data, error } = await event.locals.supabase.rpc('get_server_route_context');
		if (error) {
			throw error;
		}
		if (data === null) {
			throw new Error('get_server_route_context returned no data');
		}

		event.locals.partner = data.partner_profile?.id ? validateProfile(data.partner_profile) : null;

		if (data.play_refresh_needed) {
			event.locals.dataRefreshPromise = (async function () {
				const { data: refreshSucceeded, error: playRefreshError } = await event.locals.supabase.rpc(
					'read_plays_for_user_if_needed'
				);
				if (playRefreshError || refreshSucceeded === null) {
					console.trace(playRefreshError);
					return false;
				}

				return refreshSucceeded;
			})();
		}
	}

	return resolve(event, {
		filterSerializedResponseHeaders(name) {
			/**
			 * Supabase libraries use the `content-range` and `x-supabase-api-version`
			 * headers, so we need to tell SvelteKit to pass it through.
			 */
			return name === 'content-range' || name === 'x-supabase-api-version';
		}
	});
};

export const handle: Handle = sequence(supabase);
