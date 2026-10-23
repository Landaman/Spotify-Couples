import type { Database } from '#supabase/schema.js';
import { createClient, type User } from '@supabase/supabase-js';

const supabaseUrl = process.env.PUBLIC_SUPABASE_URL ?? '';

/** Shared local admin client for development scripts */
export const client = createClient<Database>(supabaseUrl, process.env.SUPABASE_SECRET_KEY ?? '', {
	auth: {
		persistSession: false,
		autoRefreshToken: false,
		detectSessionInUrl: false
	}
});

/**
 * Find local users in one shared pass through the Supabase admin user list
 * @param predicates filters for each requested user
 * @returns the first match for each predicate, in order, or undefined when not found
 */
export async function findUsers(
	...predicates: ((user: User) => boolean)[]
): Promise<(User | undefined)[]> {
	const matches: (User | undefined)[] = predicates.map(() => undefined);
	let page = 1;
	while (matches.some((user) => user === undefined)) {
		const { data, error } = await client.auth.admin.listUsers({ page, perPage: 1000 });
		if (error) throw error;
		predicates.forEach((predicate, index) => {
			matches[index] ??= data.users.find(predicate);
		});
		if (data.users.length < 1000) break;
		page += 1;
	}
	return matches;
}

/**
 * Gets the local supplied user and partnerpartner user IDs
 * @returns a tuple of the supplied user ID and the partnerpartner user ID
 */
export async function getSeedUserIds(): Promise<[string, string]> {
	const spotifyUserId = process.env.SPOTIFY_USER_ID;

	const [suppliedUser, partnerUser] = await findUsers(
		(user) => user.user_metadata.provider_id === spotifyUserId,
		(user) => user.email === 'partnerpartner@example.com'
	);
	if (!suppliedUser || !partnerUser) {
		throw new Error(
			`Both ${spotifyUserId} and partnerpartner@example.com must exist locally. Run auto-pair first`
		);
	}
	return [suppliedUser.id, partnerUser.id];
}

/**
 * Gets or creates a local user with the profile metadata needed for browser sessions
 * @param spotifyId the users ID
 * @param email the email address to find or create
 * @param displayName optional, the display name for the user (ID is used otherwise)
 * @param profilePictureUrl optional, a profile picture for the suer
 * @returns the existing or newly created user's profile
 */
export async function getOrCreateUser(
	spotifyId: string,
	email: string,
	displayName?: string,
	profilePictureUrl?: string
): Promise<Database['public']['CompositeTypes']['profile']> {
	const [existing] = await findUsers((user) => user.email === email);
	if (existing) {
		const name = existing.user_metadata.name ?? displayName ?? spotifyId;
		const providerId = existing.user_metadata.provider_id ?? spotifyId;
		return {
			id: existing.id,
			spotify_id: providerId,
			name,
			picture_url: existing.user_metadata.picture ?? profilePictureUrl ?? null
		};
	}

	const {
		data: { user },
		error
	} = await client.auth.admin.createUser({
		email,
		email_confirm: true,
		password: 'never use this!',
		// Use the same metadata names that gotrue uses with Spotify
		user_metadata: {
			name: displayName ?? spotifyId,
			provider_id: spotifyId,
			sub: spotifyId,
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
