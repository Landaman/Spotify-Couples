import { PostgrestError, type SupabaseClient } from '@supabase/supabase-js';
import type { Database } from './schema';

/**
 * Exception for when a user already has a partner and thus should not be allowed to
 * generate/get a pairing code
 */
export class HasPartnerException extends PostgrestError {
	// The name expected by PostgREST
	static name = 'HasPartnerException';
	static errorCode = 'P0001';
}

/**
 * Exception for when a user has a pairing code, but that code is invalid
 */
export class InvalidPairingCodeException extends PostgrestError {
	static name = 'InvalidPairingCodeException';
	static errorCode = 'P0001';
}

/**
 * Attempts to pair with the provided pairing code. The user is provided by the supabase client instance
 * @param supabase - the supabase client to get the pairing code with
 * @param pairingCode - the pairing code to pair with
 * @throws {InvalidPairingCodeException} if the provided pairing code is not valid (does not exist or is expired)
 * @throws {HasPartnerException} if the user attempting to pair already has a partner
 */
export async function pairWithCode(supabase: SupabaseClient<Database>, pairingCode: string) {
	const { error } = await supabase.rpc('pair_with_code', { pairing_code: pairingCode });

	if (
		error &&
		error.code === HasPartnerException.errorCode &&
		error.message === HasPartnerException.name
	) {
		throw new HasPartnerException(error);
	} else if (
		error &&
		error.code === InvalidPairingCodeException.errorCode &&
		error.message === InvalidPairingCodeException.name
	) {
		throw new InvalidPairingCodeException(error);
	} else if (error) {
		throw error;
	}
}

/**
 * Attempts to get or generate a pairing code for the user. The user is provided
 * by the supabase client
 * @param supabase - the supabase client to get the pairing code with
 * @returns the created pairing code
 * @throws {HasPartnerException} when the provided user already has a partner
 */
export async function getOrCreatePairingCode(supabase: SupabaseClient<Database>) {
	const { data: code, error } = await supabase.rpc('get_or_create_pairing_code');

	// Ensure that we have no issues
	if (
		error &&
		error.code === HasPartnerException.errorCode &&
		error.message === HasPartnerException.name
	) {
		// If we match the HasPartnerException, just throw that
		throw new HasPartnerException(error);
	} else if (error) {
		// Otherwise, just throw a generic error
		throw error;
	}

	// Otherwise, happy path, return the code and ensure the expires at is parsed
	return { ...code, expires_at: new Date(code.expires_at) };
}
