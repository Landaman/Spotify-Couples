import type { PageLoad } from './$types';

export const load: PageLoad = async ({ data }) => {
	return {
		pairingCode: data.pairingCode.code,
		pairingCodeExpiry: data.pairingCode.expires_at,
		pageTitle: 'Sign Up'
	};
};
