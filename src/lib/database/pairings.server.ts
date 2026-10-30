import { posthog } from '#lib/analytics/analytics.server.js';
import type { Database } from '#supabase/schema.js';
import { PostgrestError, type SupabaseClient } from '@supabase/supabase-js';

/** Raised when an unpair request is made by a user who has no partner */
export class NoPartnerException extends PostgrestError {
	static name = 'NoPartnerException';
	static errorCode = 'P0001';
}

/** Raised when the submitted partner is no longer the user's current partner */
export class InvalidPartnerException extends PostgrestError {
	static name = 'InvalidPartnerException';
	static errorCode = 'P0001';
}

/**
 * Ends the authenticated user's pairing with the supplied partner
 * @param supabase - Client identifying the user whose pairing should be removed
 * @param partnerId - Partner displayed when the user confirmed unpairing
 * @throws {NoPartnerException} If the user no longer has a partner
 * @throws {InvalidPartnerException} If the supplied partner is no longer current
 * @throws {PostgrestError} If an unexpected database error occurs
 */
export async function unpairPartner(supabase: SupabaseClient<Database>, partnerId: string) {
	await posthog.withSpan('supabase.rpc.unpair_partner', { kind: 'client' }, async () => {
		const { error } = await supabase.rpc('unpair_partner', { partner_id: partnerId });

		if (
			error &&
			error.code === NoPartnerException.errorCode &&
			error.message === NoPartnerException.name
		) {
			throw new NoPartnerException(error);
		} else if (
			error &&
			error.code === InvalidPartnerException.errorCode &&
			error.message === InvalidPartnerException.name
		) {
			throw new InvalidPartnerException(error);
		} else if (error) {
			throw error;
		}
	});
}
