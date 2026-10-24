import { captureException, withSpan } from '#lib/analytics/analytics.shared.js';
import { validateProfile } from '#lib/database/profiles.js';
import type { Database } from '#supabase/schema.js';
import type { SupabaseClient, User } from '@supabase/supabase-js';

/**
 * Gets a validated session and profile data for a user.
 * @param supabase - the supabase client (server or browser) to get data with
 * @returns a session with user data, if the session is confirmed by Supabase to be valid.
 */
export async function safeGetSession(supabase: SupabaseClient<Database>) {
	const {
		data: { session }
	} = await withSpan('supabase.auth.getSession', { kind: 'client' }, async (span) => {
		const result = await supabase.auth.getSession();
		if (result.error) {
			span?.recordException(result.error);
			console.trace(result.error);
			await captureException(result.error);
		}
		return result;
	});
	if (!session) {
		return null;
	}

	try {
		const result = await withSpan('supabase.auth.getClaims', { kind: 'client' }, async (span) => {
			const claimsResult = await supabase.auth.getClaims(session.access_token);
			span?.setStatus(claimsResult.error || !claimsResult.data ? 'error' : 'ok');
			if (claimsResult.error) {
				span?.recordException(claimsResult.error);
				console.trace(claimsResult.error);
				await captureException(claimsResult.error);
			}
			return claimsResult;
		});
		if (result.error || !result.data) {
			return null;
		}

		const { data } = result;
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
		console.trace(error);
		await captureException(error);
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
