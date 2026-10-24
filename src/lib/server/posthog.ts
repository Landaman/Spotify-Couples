import { PUBLIC_POSTHOG_HOST, PUBLIC_POSTHOG_KEY } from '$app/env/public';
import { waitUntil } from '@vercel/functions';
import { PostHog } from 'posthog-node';

/** Shares the server SDK and lets it deliver queued telemetry through Vercel */
export const posthog = new PostHog(PUBLIC_POSTHOG_KEY, {
	host: PUBLIC_POSTHOG_HOST,
	waitUntil,
	flushInterval: 0
});
