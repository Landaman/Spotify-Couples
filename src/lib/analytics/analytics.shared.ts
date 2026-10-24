import type { Span, StartSpanOptions } from 'posthog-node';

/**
 * Runs an operation in a server span, or directly in the browser
 * @param name - Server span name
 * @param options - Span options passed to the server SDK
 * @param fn - Operation receiving the server span, or undefined in the browser
 * @returns The operation's result
 * @throws Any error thrown by the operation
 */
export async function withSpan<T>(
	name: string,
	options: StartSpanOptions,
	fn: (span?: Span) => T | Promise<T>
): Promise<T> {
	if (import.meta.env.SSR) {
		return (await import('./analytics.server.js')).posthog.withSpan(name, options, fn);
	}
	return fn();
}

/**
 * Reports an exception through the SDK for the current environment
 * @param error - Exception to capture
 */
export async function captureException(error: unknown): Promise<void> {
	const posthog = import.meta.env.SSR
		? (await import('./analytics.server.js')).posthog
		: (await import('posthog-js')).default;
	posthog.captureException(error);
}
