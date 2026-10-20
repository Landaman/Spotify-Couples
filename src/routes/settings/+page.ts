import type { PageLoad } from './$types';

/** Adds the Settings page title to the data loaded by the server */
export const load: PageLoad = ({ data }) => ({
	...data,
	pageInformation: { pageTitle: 'Settings' }
});
