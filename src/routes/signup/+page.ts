import type { PageLoad } from './$types';

export const load: PageLoad = async ({ data }) => {
	return {
		pairingCode: data.pairingCode,
		pairingCodeSecondsToExpiry: data.pairingCodeSecondsToExpiry,
		pageTitle: 'Sign Up'
	};
};
