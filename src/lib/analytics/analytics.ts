import type { User } from '@supabase/supabase-js';
import posthog from 'posthog-js';

/** Route-owned URL sanitizers resolved before this module's consumers run */
const urlSanitizers = await Promise.all(
	Object.values(
		import.meta.glob<(url: URL) => void>('/src/routes/**/analytics.ts', {
			import: 'sanitizeUrl'
		})
	).map((load) => load())
);

/**
 * Resets a previous account and identifies the current user with their profile properties
 * @param user - Current authenticated user, or no user after sign-out
 */
export function syncPostHogUser(
	user: Pick<User, 'id' | 'email' | 'user_metadata'> | null | undefined
) {
	const previousUserId = posthog.get_property('$user_id');
	if (previousUserId && previousUserId !== user?.id) posthog.reset();
	if (user) {
		posthog.identify(user.id, {
			email: user.email,
			name: typeof user.user_metadata.name === 'string' ? user.user_metadata.name : undefined
		});
	}
}

/**
 * Applies route-owned sanitizers to analytics URL properties
 * @param value - Absolute or relative URL to sanitize
 * @returns The redacted URL, or an empty string for invalid input
 */
export function sanitizeAnalyticsUrl(value: string) {
	if (value === '$direct') return value;
	try {
		const url = new URL(value, 'https://analytics.invalid');
		for (const sanitizeUrl of urlSanitizers) sanitizeUrl(url);
		return value.startsWith('/') ? `${url.pathname}${url.search}${url.hash}` : url.toString();
	} catch {
		return '';
	}
}

/**
 * Sanitizes URL fields, including nested initial person properties
 * @param properties - Event properties to update in place
 */
export function sanitizeAnalyticsProperties(properties: Record<string, unknown>) {
	for (const [key, value] of Object.entries(properties)) {
		if (typeof value === 'string' && /(?:url|referrer|pathname|href)$/.test(key)) {
			properties[key] = sanitizeAnalyticsUrl(value);
		} else if (value && typeof value === 'object' && !Array.isArray(value)) {
			sanitizeAnalyticsProperties(value as Record<string, unknown>);
		}
	}
}
