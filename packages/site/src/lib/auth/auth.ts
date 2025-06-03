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
		error
	} = await supabase.auth.getUser();
	if (error || !user) {
		// JWT validation has failed - this is what makes this safe
		return null;
	}

	// Get the users profile
	const { data: profile } = await supabase.from('profiles').select('*').eq('id', user.id).single();
	if (!profile) {
		// This should never happen
		throw new Error(`Found a user (${user.id}) with no profile`);
	}

	return {
		...session,
		user: {
			...user,
			profile
		}
	};
}
