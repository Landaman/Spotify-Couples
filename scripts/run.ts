import { isLocalSupabaseUrl } from '#lib/auth/auth.js';

if (!isLocalSupabaseUrl(new URL(process.env.PUBLIC_SUPABASE_URL ?? ''))) {
	throw new Error('Scripts require PUBLIC_SUPABASE_URL to point to local Supabase on port 54321');
}

const scriptTask = prompt('Enter the task to run:');
switch (scriptTask) {
	case 'generate-login-link':
		await (
			await import('./generate-login-link')
		).default(prompt('Input the email address to sign in with:') ?? '');
		break;
	case 'auto-pair':
		await (await import('./auto-pair')).default();
		break;
	case 'generate-pairing-code':
		await (await import('./generate-pairing-code')).default();
		break;
	case 'pair-with-code':
		await (await import('./pair-with-code')).default(prompt('Input the code to pair with:') ?? '');
		break;
	case 'reset-plays':
		await (await import('./reset-plays')).default();
		break;
	case 'seed-plays': {
		const days = Number(prompt('Input the number of days to seed plays within:'));
		const upperBound = new Date(
			prompt('Input the upper date bound (ISO date or timestamp):') ?? ''
		);
		const playCount = Number(prompt('Input the number of plays to seed per user:'));
		const selectionKind = prompt('Seed by distinct tracks, albums, or artists:') as
			'albums' | 'artists' | 'tracks';
		await (
			await import('./seed-plays')
		).default(
			days,
			playCount,
			selectionKind,
			Number(prompt(`Input the number of distinct ${selectionKind} per user:`)),
			Number(prompt(`Input the common ${selectionKind} percentage:`)),
			upperBound
		);
		break;
	}
	default:
		console.error('Invalid script task ' + scriptTask);
}

process.exit(0);
