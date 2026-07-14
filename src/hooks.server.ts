import { PUBLIC_SUPABASE_ANON_KEY, PUBLIC_SUPABASE_URL } from '$env/static/public';
import { safeGetSession } from '$lib/auth/auth';
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

	event.locals.refreshPartnerId = async () => {
		if (!event.locals.session) {
			event.locals.partnerId = null;
			return event.locals.partnerId;
		}

		const { data: partnerId, error } = await event.locals.supabase.rpc('get_partner_id');
		if (error) {
			throw error;
		}

		event.locals.partnerId = partnerId;
		return event.locals.partnerId;
	};

	event.locals.refreshSession = async () => {
		event.locals.session = await safeGetSession(event.locals.supabase);
		await event.locals.refreshPartnerId();
		return event.locals.session;
	};

	await event.locals.refreshSession();

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
