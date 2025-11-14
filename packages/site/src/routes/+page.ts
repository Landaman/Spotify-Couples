import type { PageLoad } from './$types';

export const load: PageLoad = () => {
	return {
		pageInformation: { pageTitle: 'Home' }
	};
};
