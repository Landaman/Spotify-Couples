import type { LayoutServerLoad } from './$types';

/**
 * Server load, provides the session to all load functions
 */
export const load: LayoutServerLoad = async ({ locals: { safeGetSession }, cookies }) => {
	return {
		session: await safeGetSession(),
		cookies: cookies.getAll()
	};
};
