import { expect, mock, test } from 'bun:test';

const browserCalls: string[] = [];
let browserUser: string | undefined;
mock.module('posthog-js', () => ({
	default: {
		get_property: () => browserUser,
		identify: (id: string) => {
			browserUser = id;
			browserCalls.push(`identify:${id}`);
		},
		reset: () => {
			browserUser = undefined;
			browserCalls.push('reset');
		}
	}
}));

const { sanitizeAnalyticsProperties, syncPostHogUser } = await import('./analytics');

test('resets a persisted account before switching or becoming anonymous', () => {
	syncPostHogUser({ id: 'user-a', email: 'a@example.test', user_metadata: { name: 'User A' } });
	syncPostHogUser({ id: 'user-b', email: 'b@example.test', user_metadata: { name: 'User B' } });
	syncPostHogUser(null);
	syncPostHogUser(null);
	expect(browserCalls).toEqual(['identify:user-a', 'reset', 'identify:user-b', 'reset']);
});

test('removes callback credentials and invitation codes from current and initial URLs', () => {
	const properties = {
		$current_url: 'https://couples.test/auth/callback?code=oauth-secret#token',
		$pathname: '/signup/pairing-code/invite-secret',
		$referrer: 'https://couples.test/signup/pairing-code/invite-secret?next=secret',
		$set_once: {
			$initial_current_url: 'https://couples.test/?code=oauth-secret',
			$initial_referrer: '$direct'
		}
	};
	sanitizeAnalyticsProperties(properties);
	expect(JSON.stringify(properties)).not.toContain('secret');
	expect(properties.$pathname).toBe('/signup/pairing-code/[code]');
	expect(properties.$current_url).toBe('https://couples.test/auth/callback');
	expect(properties.$set_once.$initial_referrer).toBe('$direct');
});
