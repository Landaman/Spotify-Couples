/**
 * Removes magic-link credentials from sign-in URLs captured by analytics and replay
 * @param url - URL to sanitize in place when it belongs to the sign-in route
 */
export function sanitizeUrl(url: URL) {
	if (!/^\/signin(?:\/|$)/.test(url.pathname)) return;
	url.search = '';
	url.hash = '';
}
