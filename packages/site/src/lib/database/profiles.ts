import type { Database } from './schema';

// Helper type
type AllNonNullable<T> = { [P in keyof T]: NonNullable<T[P]> };

// Type for a user, and a profile attached to them. You can't express "non-nullable" in psql composite types
export type Profile = Omit<
	AllNonNullable<Database['public']['CompositeTypes']['profile']>,
	'picture_url'
> & {
	picture_url: string | null;
};

/**
 * Helper to determine if a profile is valid (i.e., has the right non-null attributes)
 * @param profile - the profile to check
 * @returns true if the profile is valid, false otherwise. Used as a typegaurd
 */
function isCompleteProfile(
	profile: Partial<Database['public']['CompositeTypes']['profile']>
): profile is Profile {
	return !!profile.id && !!profile.name && !!profile.spotify_id;
}

/**
 * Converts a profile to a profile with the correct non-nullable attributes. Throws otherwise
 * @param profile - the profile
 * @returns the validated profile
 * @throws { Error } if the profile is missing required attributes
 */
export function validateProfile(
	profile: Partial<Database['public']['CompositeTypes']['profile']>
): Profile {
	if (!isCompleteProfile(profile)) {
		throw new Error('Found a profile with missing required attributes');
	}
	return profile;
}
