import type { PageLoad } from './$types';

export const load: PageLoad = async ({ data }) => {
	return {
		pairingCode: data.code,
		pairingCodeExpiry: data.expiry,
		pageTitle: 'Sign Up'
	};
};
