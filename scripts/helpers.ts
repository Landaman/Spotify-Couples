import type { Database } from '#supabase/schema.js';
import { createClient } from '@supabase/supabase-js';

/** Supabase admin client for seed tooling */
export const client = createClient<Database>(
	process.env.PUBLIC_SUPABASE_URL ?? '',
	process.env.SUPABASE_SECRET_KEY ?? '',
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
 * Creates a Supabase client with a real Auth session for the provided email
 * @param email the email of the user to impersonate
 * @returns a Supabase client authenticated as that user
 */
export async function createImpersonatingClient(email: string) {
	const { data: linkData, error: linkError } = await client.auth.admin.generateLink({
		type: 'magiclink',
		email
	});
	if (linkError) {
		throw linkError;
	}

	const userClient = createClient<Database>(
		process.env.PUBLIC_SUPABASE_URL ?? '',
		process.env.PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? '',
		{
			auth: {
				persistSession: false,
				autoRefreshToken: false,
				detectSessionInUrl: false
			}
		}
	);
	const { error } = await userClient.auth.verifyOtp({
		type: 'magiclink',
		token_hash: linkData.properties.hashed_token
	});
	if (error) {
		throw error;
	}

	return userClient;
}
