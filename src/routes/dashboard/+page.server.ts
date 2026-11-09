import { posthog } from '#lib/analytics/analytics.server.js';
import { redirectToSignIn } from '#lib/auth/auth.server.js';
import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

import type { Journal } from './journal';

/**
 * Reads pair-scoped aggregates after ingestion completes
 * @param supabase - Authenticated database client
 * @param days - Validated rolling day or 7/30 calendar days
 * @param timezone - Validated IANA timezone
 * @returns Journal aggregates or a recoverable page error
 */
async function getJournal(supabase: App.Locals['supabase'], days: number, timezone: string) {
	return posthog.withSpan('supabase.rpc.get_listening_journal', { kind: 'client' }, async () => {
		const { data, error } = await supabase.rpc('get_listening_journal', {
			day_count: days,
			timezone_name: timezone
		});
		if (error) {
			posthog.captureException(error);
			return { journal: null, error: 'Could not load your dashboard. Please try again.' };
		}
		return { journal: data as unknown as Journal, error: null };
	});
}

export const load: PageServerLoad = async (event) => {
	const {
		locals: { dataRefreshPromise, partner, session, supabase },
		url
	} = event;

	// Validate we have a user
	if (!session) {
		throw await redirectToSignIn(url.pathname, event); // If not, sign them in and then come back
	}

	// Validate the user has a partner
	if (!partner) {
		throw redirect(303, '/signup'); // If the user doesn't have a partner, redirect to signup to get them a partner
	}

	const requestedDays = Number(url.searchParams.get('days'));
	const days = [1, 7, 30].includes(requestedDays) ? requestedDays : 7;
	let timezone = url.searchParams.get('tz') ?? 'UTC';
	try {
		new Intl.DateTimeFormat('en', { timeZone: timezone }).format();
	} catch {
		timezone = 'UTC';
	}

	return {
		session,
		partner,
		days,
		timezone,
		pageInformation: { pageTitle: 'Dashboard', needsData: true },
		journalResult: (async () => {
			try {
				await dataRefreshPromise;
				return await getJournal(supabase, days, timezone);
			} catch (error) {
				posthog.captureException(error);
				return {
					journal: null,
					error: 'Could not refresh your dashboard. Please try again.'
				};
			}
		})()
	};
};
