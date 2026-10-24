import type { RequestEvent } from '@sveltejs/kit';
import { traceServerOperation } from './posthog.js';

/**
 * Measures outgoing HTTP requests without changing fetch behavior
 * @param event - Request supplying the user and replay context
 * @param fetcher - Underlying fetch implementation
 * @returns A fetch function that creates HTTP client spans
 */
export function createTracedFetch(event: RequestEvent, fetcher = globalThis.fetch) {
	const tracedFetch = async (input: RequestInfo | URL, init?: RequestInit): Promise<Response> => {
		const url = new URL(input instanceof Request ? input.url : input.toString());
		const method = (
			init?.method ?? (input instanceof Request ? input.method : 'GET')
		).toUpperCase();

		return traceServerOperation(
			event,
			`HTTP ${method}`,
			async (span) => {
				const response = await fetcher(input, init);
				span.setAttribute('http.response.status_code', response.status);
				span.setStatus(response.status >= 400 ? 'error' : 'ok');
				return response;
			},
			{
				kind: 'client',
				attributes: {
					'http.request.method': method,
					'server.address': url.hostname,
					'url.path': url.pathname
				}
			}
		);
	};
	return Object.assign(tracedFetch, { preconnect: fetcher.preconnect });
}
