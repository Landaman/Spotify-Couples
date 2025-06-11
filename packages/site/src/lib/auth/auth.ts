import { validateProfile } from '$lib/database/profiles';
import type { SupabaseClient } from '@supabase/supabase-js';
import type { Database } from '../database/schema';

/**
 * Gets a validated session and profile data for a user
 * @param supabase - the supabase client (server or browser) to get data with
 * @returns a session with user data, if the session is confirmed by Supabase to be valid. Unlike
 * calling getSession() on the client, this is guaranteed to be safe
 */
export async function safeGetSession(supabase: SupabaseClient<Database>) {
	const {
		data: { session }
	} = await supabase.auth.getSession();
	if (!session) {
		return null;
	}

	const {
		data: { user },
		error: authError
	} = await supabase.auth.getUser();
	if (authError || !user) {
		// JWT validation has failed - this is what makes this safe
		return null;
	}

	const { data: partnerId, error: partnerError } = await supabase.rpc('get_partner_id');
	if (partnerError) {
		throw partnerError;
	}

	return {
		...session,
		user: {
			...user,
			profile: validateProfile({
				id: user.id,
				name: user.user_metadata.name,
				spotify_id: user.user_metadata.sub,
				picture_url: user.user_metadata.picture
			}),
			partnerId
		}
	};
}
