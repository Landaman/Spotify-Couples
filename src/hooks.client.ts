import { sanitizeAnalyticsProperties, sanitizeAnalyticsUrl } from '#lib/analytics.js';
import { PUBLIC_POSTHOG_HOST, PUBLIC_POSTHOG_KEY } from '$app/env/public';
import type { HandleClientError } from '@sveltejs/kit/hooks';
import posthog from 'posthog-js';

/** Starts browser analytics and replay using the required project configuration */
export function init() {
	if (posthog.__loaded) return;
	posthog.init(PUBLIC_POSTHOG_KEY, {
		api_host: PUBLIC_POSTHOG_HOST,
		defaults: '2026-05-30',
		session_recording: {
			maskAllInputs: true,
			recordBody: false,
			recordHeaders: false,
			maskCapturedNetworkRequestFn: (request) => ({
				...request,
				name: sanitizeAnalyticsUrl(request.name)
			})
		},
		disable_capture_url_hashes: true,
		capture_exceptions: true,
		tracing_headers: [window.location.hostname],
		before_send: (event) => {
			if (event) sanitizeAnalyticsProperties(event.properties);
			return event;
		}
	});
}

/**
 * Reports errors caught by SvelteKit in addition to the SDK's global error listeners
 * @param input - Error and SvelteKit error classification
 */
export const handleError: HandleClientError = ({ error, kind }) => {
	if (kind !== 'unknown') return;
	console.error(error);
	posthog.captureException(error);
};
