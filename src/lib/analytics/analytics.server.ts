import { PUBLIC_POSTHOG_HOST, PUBLIC_POSTHOG_KEY } from '$app/env/public';
import { waitUntil } from '@vercel/functions';
import { PostHog } from 'posthog-node';

/** Shares the server SDK and lets it deliver queued telemetry through Vercel */
export const posthog = new PostHog(PUBLIC_POSTHOG_KEY, {
	host: PUBLIC_POSTHOG_HOST,
	waitUntil,
	flushInterval: 0,
	traces: { serviceName: 'spotify-couples', flushIntervalMs: 0 },
	before_send: (event) => {
		// The SDK correlates exceptions with OpenTelemetry, but its native spans use a separate context
		if (event.event === '$exception') {
			const [, traceId, spanId] = posthog.getActiveSpan()?.traceparent()?.split('-') ?? [];
			if (traceId && spanId) {
				event.properties = { $trace_id: traceId, $span_id: spanId, ...event.properties };
			}
		}
		return event;
	}
});
