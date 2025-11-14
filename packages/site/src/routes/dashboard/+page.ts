import type { PageLoad } from './$types';

export const load: PageLoad = ({ data: serverData }) => {
	return {
		...serverData,
		pageInformation: {
			needsData: true,
			pageTitle: 'Dashboard'
		}
	};
};
