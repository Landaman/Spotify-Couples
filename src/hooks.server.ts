import { posthog } from '#lib/analytics/analytics.server.js';
import { isLocalSupabaseUrl, safeGetSession } from '#lib/auth/auth.js';
import { validateProfile } from '#lib/database/profiles.js';
import type { Database } from '#supabase/schema.js';
import { dev } from '$app/env';
import { PUBLIC_SUPABASE_PUBLISHABLE_KEY, PUBLIC_SUPABASE_URL } from '$app/env/public';
import { createServerClient } from '@supabase/ssr';
import { sequence, type Handle, type HandleServerError } from '@sveltejs/kit/hooks';

/** Opens an isolated replay context and parent span for the entire request */
const traceRequest: Handle = ({ event, resolve }) =>
	posthog.withContext(
		{ sessionId: event.request.headers.get('x-posthog-session-id') ?? undefined },
		() =>
			posthog.withSpan(
				`${event.request.method} ${event.route.id ?? '<unmatched>'}`,
				{
					kind: 'server',
					parent: event.request.headers.get('traceparent') ?? undefined
				},
				async (span) => {
					event.locals.analytics = { span, sessionId: posthog.getContext()?.sessionId };
					const response = await resolve(event);
					span.setAttribute('http.response.status_code', response.status);
					span.setStatus(response.status >= 500 ? 'error' : 'ok');
					return response;
				}
			),
		{ fresh: true }
	);

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

		const partnerProfile = await posthog.withSpan(
			'supabase.rpc.get_partner_profile',
			{ kind: 'client' },
			async () => {
				const { data, error } = await event.locals.supabase.rpc('get_partner_profile');
				if (error) {
					throw error;
				}
				return data;
			}
		);

		// Data is not actually null ever since Supabase just conforms the shape
		event.locals.partner =
			partnerProfile && partnerProfile.id ? validateProfile(partnerProfile) : null;
		return event.locals.partner;
	};

	/** Refreshes and returns the session and partner, propagating auth or database errors */
	event.locals.refreshSession = async () => {
		event.locals.session = await safeGetSession(event.locals.supabase);
		// Mutate the shared request context so callers also see login and logout changes
		if (context) context.distinctId = event.locals.session?.user.id;
		event.locals.analytics?.span.setAttribute('posthogDistinctId', event.locals.session?.user.id);
		await event.locals.refreshPartner();
		return event.locals.session;
	};

	event.locals.session = await safeGetSession(event.locals.supabase);
	if (context) context.distinctId = event.locals.session?.user.id;
	event.locals.analytics?.span.setAttribute('posthogDistinctId', event.locals.session?.user.id);
	event.locals.dataRefreshPromise = undefined;
	event.locals.partner = null;

	if (event.locals.session) {
		const routeContext = await posthog.withSpan(
			'supabase.rpc.get_server_route_context',
			{ kind: 'client' },
			async () => {
				const { data, error } = await event.locals.supabase.rpc('get_server_route_context');
				if (error || !data) {
					throw error ?? new Error('get_server_route_context returned no data');
				}
				return data;
			}
		);

		event.locals.partner = routeContext.partner_profile?.id
			? validateProfile(routeContext.partner_profile)
			: null;

		// Auto-generated/email-only local users have no Spotify tokens of course
		// so don't try to let them refresh
		const providers = event.locals.session.user.app_metadata.providers;
		const isLocalEmailUser =
			dev &&
			isLocalSupabaseUrl(new URL(PUBLIC_SUPABASE_URL)) &&
			providers?.length === 1 &&
			providers[0] === 'email';

		if (routeContext.play_refresh_needed && !isLocalEmailUser) {
			event.locals.dataRefreshPromise = posthog.withSpan(
				'supabase.rpc.read_plays_for_user_if_needed',
				{ kind: 'client' },
				async (span) => {
					const { data: refreshSucceeded, error: playRefreshError } =
						await event.locals.supabase.rpc('read_plays_for_user_if_needed');
					if (playRefreshError || refreshSucceeded === null) {
						const refreshError =
							playRefreshError ?? new Error('read_plays_for_user_if_needed returned no data');
						span.recordException(refreshError);
						console.trace(refreshError);
						posthog.captureException(refreshError);
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

export const handle: Handle = sequence(traceRequest, supabase);

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
	// Framework error handling can run after the request's active context has unwound
	const [, traceId, spanId] =
		(posthog.getActiveSpan() ?? event.locals.analytics?.span)?.traceparent()?.split('-') ?? [];
	posthog.captureException(error, event.locals.session?.user.id, {
		...(traceId && spanId ? { $trace_id: traceId, $span_id: spanId } : {}),
		$session_id: event.locals.analytics?.sessionId
	});
};
