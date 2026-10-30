import { sanitizeAnalyticsProperties, sanitizeAnalyticsUrl } from '#lib/analytics/analytics.js';
import { PUBLIC_POSTHOG_HOST, PUBLIC_POSTHOG_KEY } from '$app/env/public';
import type { HandleClientError } from '@sveltejs/kit/hooks';
import posthog from 'posthog-js';

/**
 * Starts browser analytics and replay once using the required project configuration
 */
export function init() {
	if (posthog.__loaded) return;
	posthog.init(PUBLIC_POSTHOG_KEY, {
		api_host: PUBLIC_POSTHOG_HOST,
		defaults: '2026-08-30',
		session_recording: {
			maskAllInputs: true,
			recordBody: false,
			recordHeaders: false,
			/**
			 * Removes credentials and invitation codes from replay network URLs
			 * @param request - Captured network request to sanitize
			 * @returns A copy of the request with its URL redacted
			 */
			maskCapturedNetworkRequestFn: (request) => ({
				...request,
				name: sanitizeAnalyticsUrl(request.name)
			})
		},
		disable_capture_url_hashes: true,
		capture_exceptions: true,
		tracing_headers: [window.location.hostname],
		/**
		 * Redacts URL properties before an analytics event is sent
		 * @param event - Captured event, or null when capture was already canceled
		 * @returns The sanitized event, or null to preserve canceled capture
		 */
		before_send: (event) => {
			if (event) sanitizeAnalyticsProperties(event.properties);
			return event;
		}
	});
}

/**
 * Reports errors caught by SvelteKit in addition to the SDK's global error listeners
 * @param input - SvelteKit client error details
 * @param input.error - Error to log and report
 * @param input.kind - Classification used to report only unexpected errors
 */
export const handleError: HandleClientError = ({ error, kind }) => {
	if (kind !== 'unknown') return;
	console.error(error);
	posthog.captureException(error);
};
