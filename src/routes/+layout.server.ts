import type { LayoutServerLoad } from './$types';

/**
 * Server load, provides the session to all load functions
 */
export const load: LayoutServerLoad = async ({
	locals: { dataRefreshPromise, session },
	cookies
}) => {
	return {
		dataRefreshPromise,
		session,
		cookies: cookies.getAll()
	};
};
