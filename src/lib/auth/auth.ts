import { validateProfile } from '$lib/database/profiles';
import type { Database } from '$supabase/schema';
import type { SupabaseClient, User } from '@supabase/supabase-js';

/**
 * Gets a validated session and profile data for a user.
 * @param supabase - the supabase client (server or browser) to get data with
 * @returns a session with user data, if the session is confirmed by Supabase to be valid.
 */
export async function safeGetSession(supabase: SupabaseClient<Database>) {
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
		return null;
	}
}
