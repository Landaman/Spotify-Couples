import type { PageLoad } from './$types';

export const load: PageLoad = ({ data: serverData }) => {
	return {
		...serverData,
		pageTitle: 'Dashboard'
	};
};
