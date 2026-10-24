import { validateProfile } from '#lib/database/profiles.js';
import type { Database } from '#supabase/schema.js';
import type { SupabaseClient, User } from '@supabase/supabase-js';

/**
 * Gets a validated session and profile data for a user.
 * @param supabase - the supabase client (server or browser) to get data with
 * @returns a session with user data, if the session is confirmed by Supabase to be valid.
 */
export async function safeGetSession(supabase: SupabaseClient<Database>) {
	// Vite removes the server-only import before SvelteKit checks the browser bundle
	const posthog = import.meta.env.SSR
		? (await import('#lib/analytics/analytics.server.js')).posthog
		: undefined;
	const {
		data: { session }
	} = await supabase.auth.getSession();
	if (!session) {
		return null;
	}

	try {
		const { data, error } = await supabase.auth.getClaims(session.access_token);
		if (error || !data) {
			return null;
		}

		const { claims } = data;
		const userMetadata = claims.user_metadata ?? {};
		const user = {
			app_metadata: claims.app_metadata ?? {},
			aud: 'authenticated',
			created_at: session.user.created_at,
			id: claims.sub,
			email: claims.email,
			phone: claims.phone,
			user_metadata: userMetadata,
			is_anonymous: claims.is_anonymous
		} satisfies User;

		return {
			...session,
			expires_at: claims.exp,
			expires_in: claims.exp - Math.round(Date.now() / 1000),
			user: {
				...user,
				profile: validateProfile({
					id: user.id,
					name: userMetadata.name,
					spotify_id: userMetadata.sub,
					picture_url: userMetadata.picture
				})
			}
		};
	} catch (error) {
		console.error(error);
		if (posthog) {
			posthog.captureException(error);
		} else {
			(await import('posthog-js')).default.captureException(error);
		}
		return null;
	}
}

/**
 * Whether a URL is the repository's local Supabase API
 * @param url - the URL to check
 * @returns true if the URL is a local Supabase URL, false otherwise
 */
export function isLocalSupabaseUrl(url: URL): boolean {
	return ['http://127.0.0.1:54321', 'http://localhost:54321'].includes(
		url.protocol + '//' + url.host
	);
}

/**
 * Whether a URL (meant to be the deployment URL) represent a local deployment of the app
 * @param appUrl - the URL to check
 * @returns true if the URL is a local deployment URL, false otherwise
 */
export function isUrlHostedLocally(appUrl: URL): boolean {
	return (
		appUrl.protocol === 'http:' && ['localhost', '127.0.0.1', '[::1]'].includes(appUrl.hostname)
	);
}
