import { isLocalSupabaseUrl, safeGetSession } from '#lib/auth/auth.js';
import { validateProfile } from '#lib/database/profiles.js';
import { createTracedFetch } from '#lib/server/fetch-performance.js';
import { posthog, traceServerOperation } from '#lib/server/posthog.js';
import type { Database } from '#supabase/schema.js';
import { dev } from '$app/env';
import { PUBLIC_SUPABASE_PUBLISHABLE_KEY, PUBLIC_SUPABASE_URL } from '$app/env/public';
import { createServerClient } from '@supabase/ssr';
import { sequence, type Handle, type HandleServerError } from '@sveltejs/kit/hooks';

/**
 * Measures each request using its route template rather than its token-bearing URL
 * @param input - Request event and SvelteKit response resolver
 * @returns The response produced by SvelteKit
 */
const observability: Handle = ({ event, resolve }) =>
	traceServerOperation(
		event,
		`${event.request.method} ${event.route.id ?? '<unmatched>'}`,
		async (span) => {
			const response = await resolve(event);
			span.setAttribute('http.response.status_code', response.status);
			span.setAttribute('posthogDistinctId', event.locals.session?.user.id);
			span.setStatus(response.status >= 500 ? 'error' : 'ok');
			return response;
		},
		{
			kind: 'server',
			parent: event.request.headers.get('traceparent') ?? undefined
		}
	);

/**
 * Initializes request-local auth, partner data, and refresh helpers
 * @param input - Request event and SvelteKit response resolver
 * @returns The response with Supabase response headers preserved
 */
const supabase: Handle = async ({ event, resolve }) => {
	/**
	 * Creates a Supabase client specific to this server request.
	 *
	 * The Supabase client gets the Auth token from the request cookies.
	 */
	event.locals.supabase = createServerClient<Database>(
		PUBLIC_SUPABASE_URL,
		PUBLIC_SUPABASE_PUBLISHABLE_KEY,
		{
			// Wrap the native transport rather than SvelteKit's SSR fetch
			global: { fetch: createTracedFetch(event) },
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

	/**
	 * Refreshes partner state after a pairing mutation
	 * @returns The current partner profile, or null when unpaired
	 */
	event.locals.refreshPartner = () =>
		traceServerOperation(event, 'hooks.server.refreshPartner', async () => {
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
		});

	/**
	 * Refreshes auth and partner state after a session mutation
	 * @returns The verified session, or null when signed out
	 */
	event.locals.refreshSession = () =>
		traceServerOperation(event, 'hooks.server.refreshSession', async () => {
			event.locals.session = await safeGetSession(event.locals.supabase);
			await event.locals.refreshPartner();
			return event.locals.session;
		});

	event.locals.session = await traceServerOperation(event, 'hooks.server.getSession', () =>
		safeGetSession(event.locals.supabase)
	);
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
			event.locals.dataRefreshPromise = traceServerOperation(
				event,
				'hooks.server.refreshPlays',
				async (span) => {
					const { data: refreshSucceeded, error: playRefreshError } =
						await event.locals.supabase.rpc('read_plays_for_user_if_needed');
					if (playRefreshError || refreshSucceeded === null) {
						span.setStatus('error');
						console.trace(playRefreshError);
						return false;
					}

					span.setStatus(refreshSucceeded ? 'ok' : 'error');
					return refreshSucceeded;
				}
			);
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

/**
 * Nests Supabase and hook spans beneath the request span
 * @param input - Request event and SvelteKit response resolver
 * @returns The response produced by the request hooks
 */
export const handle: Handle = sequence(observability, supabase);

/**
 * Reports unexpected server errors without replacing SvelteKit's error response
 * @param input - Error, request event, and SvelteKit error classification
 */
export const handleError: HandleServerError = ({ error, event, kind }) => {
	if (kind !== 'unknown') return;
	console.error(error);
	posthog.captureException(error, event.locals.session?.user.id);
};
