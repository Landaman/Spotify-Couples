import { PUBLIC_POSTHOG_HOST, PUBLIC_POSTHOG_KEY } from '$app/env/public';
import type { RequestEvent } from '@sveltejs/kit';
import { waitUntil } from '@vercel/functions';
import { PostHog, type Span, type StartSpanOptions } from 'posthog-node';

/** Shares the server SDK and lets it deliver queued telemetry through Vercel */
export const posthog = new PostHog(PUBLIC_POSTHOG_KEY, {
	host: PUBLIC_POSTHOG_HOST,
	waitUntil,
	flushInterval: 0,
	traces: { serviceName: 'spotify-couples', flushIntervalMs: 0 }
});

/**
 * Links performance spans to the verified user and optional browser replay
 * @param event - Request supplying the verified user and replay header
 * @param name - Operation name shown in the trace
 * @param operation - Work to run within the active span
 * @param options - Span metadata forwarded to PostHog
 * @returns The operation's result, preserving its errors
 */
export function traceServerOperation<T>(
	event: RequestEvent,
	name: string,
	operation: (span: Span) => Promise<T>,
	options: StartSpanOptions = {}
): Promise<T> {
	return posthog.withContext(
		{
			distinctId: event.locals.session?.user.id,
			sessionId: event.request.headers.get('x-posthog-session-id') ?? undefined
		},
		() => posthog.withSpan(name, options, operation)
	);
}
