import { createClient } from '@supabase/supabase-js';
import jwt from 'jsonwebtoken';
import type { Database } from './schema';

export const client = createClient<Database>(
	process.env.PUBLIC_SUPABASE_URL ?? '',
	process.env.SUPABASE_SERVICE_ROLE_KEY ?? '',
	{
		auth: {
			persistSession: false,
			autoRefreshToken: false,
			detectSessionInUrl: false
		}
	}
);

/**
 * Creates a user in the database
 * @param spotifyId the users ID
 * @param displayName optional, the display name for the user (ID is used otherwise)
 * @param profilePictureUrl optional, a profile picture for the suer
 */
export async function createUser(
	spotifyId: string,
	email: string,
	displayName?: string,
	profilePictureUrl?: string
): Promise<Database['public']['Tables']['profiles']['Row']> {
	const {
		data: { user },
		error
	} = await client.auth.admin.createUser({
		email,
		password: 'never use this!',
		// Use the same metadata names that gotrue uses with Spotify
		user_metadata: {
			name: displayName ?? spotifyId,
			provider_id: spotifyId,
			picture: profilePictureUrl
		}
	});

	if (error || user == null) {
		throw error;
	}

	return {
		id: user.id,
		spotify_id: spotifyId,
		name: displayName ?? spotifyId,
		picture_url: profilePictureUrl ?? null,
		partner_id: null
	};
}

/**
 * Creates a Supabase client registered to the provided profile. This works by generating a jwt
 * that impersonates the provided usedr
 * @param profile the profile of the user to impersonate
 * @returns a Supabase client that impersonates that user
 */
export async function createImpersonatingClient(
	profile: Database['public']['Tables']['profiles']['Row']
) {
	return createClient<Database>(
		process.env.PUBLIC_SUPABASE_URL ?? '',
		process.env.PUBLIC_SUPABASE_ANON_KEY ?? '',
		{
			global: {
				headers: {
					// Create a token that impersonates the user
					Authorization: `Bearer ${jwt.sign(
						{
							sub: profile.id,
							role: 'authenticated',
							aud: 'authenticated'
						},
						process.env.SUPABASE_JWT_SECRET ?? '',
						{
							algorithm: 'HS256',
							expiresIn: '1m'
						}
					)}`
				}
			}
		}
	);
}
