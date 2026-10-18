import type { Database } from '#supabase/schema.js';
import { createClient } from '@supabase/supabase-js';
import jwt from 'jsonwebtoken';

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
 * Gets the local supplied user and partnerpartner user IDs
 * @returns a tuple of the supplied user ID and the partnerpartner user ID
 */
export async function getSeedUserIds(): Promise<[string, string]> {
	const spotifyUserId = process.env.SPOTIFY_USER_ID;

	const { data, error } = await client.auth.admin.listUsers({ page: 1, perPage: 1000 });
	if (error) {
		throw error;
	}

	const suppliedUser = data.users.find((user) => user.user_metadata.provider_id === spotifyUserId);
	const partnerUser = data.users.find((user) => user.email === 'partnerpartner@example.com');
	if (!suppliedUser || !partnerUser) {
		throw new Error(
			`Both ${spotifyUserId} and partnerpartner@example.com must exist locally. Run auto-pair first`
		);
	}

	return [suppliedUser.id, partnerUser.id];
}

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
): Promise<Database['public']['CompositeTypes']['profile']> {
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
		picture_url: profilePictureUrl ?? null
	};
}

/**
 * Creates a Supabase client registered to the provided profile. This works by generating a jwt
 * that impersonates the provided usedr
 * @param profile the profile of the user to impersonate
 * @returns a Supabase client that impersonates that user
 */
export async function createImpersonatingClient(
	profile: Database['public']['CompositeTypes']['profile']
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
