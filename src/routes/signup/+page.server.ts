import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ locals, url }) => {
	const session = await locals.auth();

	if (!session) {
		const redirectUrl = new URL('/signin', url);
		redirectUrl.searchParams.set('redirectTo', '/signup');
		throw redirect(303, redirectUrl);
	}

	return {
		pairingCode: (123456).toString(),
		pairingCodeSecondsToExpiry: 15 * 60
	};
};
