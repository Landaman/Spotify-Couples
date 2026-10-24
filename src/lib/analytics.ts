import type { User } from '@supabase/supabase-js';
import posthog from 'posthog-js';

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
 * Removes credentials and invitation codes from analytics URL properties
 * @param value - Absolute or relative URL to sanitize
 * @returns The redacted URL, or an empty string for invalid input
 */
export function sanitizeAnalyticsUrl(value: string) {
	if (value === '$direct') return value;
	try {
		const url = new URL(value, 'https://analytics.invalid');
		url.search = '';
		url.hash = '';
		url.pathname = url.pathname.replace(
			/\/signup\/pairing-code\/[^/]+/,
			'/signup/pairing-code/[code]'
		);
		return value.startsWith('/') ? url.pathname : url.toString();
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
