import { posthog } from '#lib/analytics/analytics.server.js';
import { redirectToSignIn } from '#lib/auth/auth.server.js';
import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';
import {
	findTopListensDateRange,
	parseTopListensCategory,
	parseTopListensListener,
	type TopListen,
	type TopListensCategory,
	type TopListensListener,
	TopListensRpcs
} from './shared';

/**
 * Load ranked entries and their play counts for a dashboard category
 * @param supabase - Client identifying the authenticated user
 * @param category - What kind of entry to rank
 * @param listener - Whose plays to rank
 * @param rangeDays - Requested number of days, or undefined for all time
 * @returns Ranked entries ready for display
 * @throws If the ranking RPC fails
 */
async function getTopListens(
	supabase: App.Locals['supabase'],
	category: TopListensCategory,
	listener: TopListensListener,
	rangeDays: number | undefined
): Promise<TopListen[]> {
	const rpc = TopListensRpcs[category];
	return posthog.withSpan(`supabase.rpc.${rpc}`, { kind: 'client' }, async () => {
		const { data, error } = await supabase.rpc(rpc, {
			listener,
			// The required SQL argument accepts NULL for all time
			range_days: (rangeDays ?? null) as number
		});
		if (error) throw error;

		return data;
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

	const listener = parseTopListensListener(url.searchParams.get('listener'));

	const category = parseTopListensCategory(url.searchParams.get('category'));

	const dateRange = findTopListensDateRange(url.searchParams.get('range'));
	if (!dateRange) {
		const allTime = new URL(url.href);
		allTime.searchParams.delete('range');
		redirect(303, allTime);
	}

	const listens = (dataRefreshPromise ?? Promise.resolve())
		.then(() => getTopListens(supabase, category, listener, dateRange.days))
		.catch((error: unknown) => {
			posthog.captureException(error);
			return null;
		});

	return {
		category,
		listener,
		dateRange,
		session,
		partner: partner,
		listens
	};
};
