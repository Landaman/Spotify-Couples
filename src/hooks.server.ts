import { posthog } from '#lib/analytics/analytics.server.js';
import { isLocalSupabaseUrl, safeGetSession } from '#lib/auth/auth.js';
import { validateProfile } from '#lib/database/profiles.js';
import type { Database } from '#supabase/schema.js';
import { dev } from '$app/env';
import { PUBLIC_SUPABASE_PUBLISHABLE_KEY, PUBLIC_SUPABASE_URL } from '$app/env/public';
import { createServerClient } from '@supabase/ssr';
import { type Handle, type HandleServerError } from '@sveltejs/kit/hooks';

/** Sets up request authentication and keeps the shared tracing identity current */
const supabase: Handle = async ({ event, resolve }) => {
	const context = posthog.getContext();
	/**
	 * Creates a Supabase client specific to this server request.
	 *
	 * The Supabase client gets the Auth token from the request cookies.
	 */
	event.locals.supabase = createServerClient<Database>(
		PUBLIC_SUPABASE_URL,
		PUBLIC_SUPABASE_PUBLISHABLE_KEY,
		{
			// Do not pass globals -> fetch since we aren't doing SSR directly on this
			cookies: {
				// Pass both of these, as the server client can actually play with cookies
				// for auth
				getAll: () => event.cookies.getAll(),
				/**
				 * Setting `path` to `/` makes auth cookies available across the site.
				 */
				setAll: (cookiesToSet) => {
					cookiesToSet.forEach(({ name, value, options }) => {
						event.cookies.set(name, value, { ...options, path: '/' });
					});
				}
			}
		}
	);

	/** Refreshes and returns the partner profile, propagating database errors */
	event.locals.refreshPartner = async () => {
		if (!event.locals.session) {
			event.locals.partner = null;
			return event.locals.partner;
		}

		const { data, error } = await event.locals.supabase.rpc('get_partner_profile');
		if (error) {
			throw error;
		}

		// Data is not actually null ever since Supabase just conforms the shape
		event.locals.partner = data && data.id ? validateProfile(data) : null;
		return event.locals.partner;
	};

	/** Refreshes and returns the session and partner, propagating auth or database errors */
	event.locals.refreshSession = async () => {
		event.locals.session = await safeGetSession(event.locals.supabase);
		// Mutate the shared request context so callers also see login and logout changes
		if (context) context.distinctId = event.locals.session?.user.id;
		await event.locals.refreshPartner();
		return event.locals.session;
	};

	event.locals.session = await safeGetSession(event.locals.supabase);
	if (context) context.distinctId = event.locals.session?.user.id;
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

		// Auto-generated/email-only local users have no Spotify tokens of course
		// so don't try to let them refresh
		const providers = event.locals.session.user.app_metadata.providers;
		const isLocalEmailUser =
			dev &&
			isLocalSupabaseUrl(new URL(PUBLIC_SUPABASE_URL)) &&
			providers?.length === 1 &&
			providers[0] === 'email';

		if (data.play_refresh_needed && !isLocalEmailUser) {
			event.locals.dataRefreshPromise = (async function () {
				const { data: refreshSucceeded, error: playRefreshError } = await event.locals.supabase.rpc(
					'read_plays_for_user_if_needed'
				);
				if (playRefreshError || refreshSucceeded === null) {
					console.trace(playRefreshError);
					posthog.captureException(
						playRefreshError ?? new Error('read_plays_for_user_if_needed returned no data')
					);
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

/** Isolates analytics identity and replay correlation for each request */
export const handle: Handle = (input) =>
	posthog.withContext(
		{ sessionId: input.event.request.headers.get('x-posthog-session-id') ?? undefined },
		() => supabase(input),
		{ fresh: true }
	);

/**
 * Reports unexpected server errors without replacing SvelteKit's error response
 * @param input - SvelteKit server error details
 * @param input.error - Error to log and report
 * @param input.event - Request supplying the authenticated user, if available
 * @param input.kind - Classification used to report only unexpected errors
 */
export const handleError: HandleServerError = ({ error, event, kind }) => {
	if (kind !== 'unknown') return;
	console.error(error);
	posthog.captureException(error, event.locals.session?.user.id);
};
