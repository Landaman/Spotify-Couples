import type { LayoutServerLoad } from './$types';

/**
 * Server load, provides the session to all load functions
 */
export const load: LayoutServerLoad = async ({ locals: { safeGetSession, supabase }, cookies }) => {
	// Stream in the loading state if that's required
	let dataRefreshPromise: Promise<boolean> | undefined;
	const { data: needsDataRefresh } = await supabase.rpc('user_needs_play_refresh');
	if (needsDataRefresh) {
		// DON'T await so that it is streamed
		dataRefreshPromise = (async function () {
			const { data, error } = await supabase.rpc('read_plays_for_user_if_needed');
			if (error || data === null) {
				console.error(error);
				return false;
			}

			return data;
		})();
	}

	return {
		dataRefreshPromise,
		session: await safeGetSession(),
		cookies: cookies.getAll()
	};
};
