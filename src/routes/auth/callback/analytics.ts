/**
 * Removes auth codes and redirect destinations that may contain invitation codes
 * @param url - URL to sanitize in place when it belongs to the auth callback route
 */
export function sanitizeUrl(url: URL) {
	if (!/^\/auth\/callback(?:\/|$)/.test(url.pathname)) return;
	url.search = '';
	url.hash = '';
}
