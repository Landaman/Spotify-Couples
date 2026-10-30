/**
 * Redacts invitation codes in URLs captured by analytics and session replay
 * @param url - URL to sanitize in place, including URLs from other routes or hosts
 */
export function sanitizeUrl(url: URL) {
	url.pathname = url.pathname.replace(
		/\/signup\/pairing-code\/[^/]+/,
		'/signup/pairing-code/[code]'
	);
}
