import type { PageLoad } from './$types';

export const load: PageLoad = async ({ data }) => {
	return {
		pairingCode: data.code,
		pairingCodeExpiry: data.expires_at,
		pageTitle: 'Sign Up'
	};
};
