import { isLocalSupabaseUrl } from '#lib/auth/auth.js';

if (!isLocalSupabaseUrl(new URL(process.env.PUBLIC_SUPABASE_URL ?? ''))) {
	throw new Error('Scripts require PUBLIC_SUPABASE_URL to point to local Supabase on port 54321');
}

const args = process.argv.slice(2);

/**
 * Read the next positional argument, prompting when it was not supplied
 * @param message the prompt to show when no argument remains
 * @returns the argument or prompt response, or an empty string when canceled
 */
function readInput(message: string): string {
	return args.shift() ?? prompt(message) ?? '';
}

const scriptTask = readInput('Enter the task to run:');
switch (scriptTask) {
	case 'generate-login-link':
		await (
			await import('./generate-login-link')
		).default(readInput('Input the email address to sign in with:'));
		break;
	case 'auto-pair':
		await (await import('./auto-pair')).default();
		break;
	case 'generate-pairing-code':
		await (await import('./generate-pairing-code')).default();
		break;
	case 'pair-with-code':
		await (await import('./pair-with-code')).default(readInput('Input the code to pair with:'));
		break;
	case 'reset-plays':
		await (await import('./reset-plays')).default();
		break;
	case 'seed-plays': {
		const days = Number(readInput('Input the number of days to seed plays within:'));
		const upperBound = new Date(readInput('Input the upper date bound (ISO date or timestamp):'));
		const playCount = Number(readInput('Input the number of plays to seed per user:'));
		const selectionKind = readInput('Seed by distinct tracks, albums, or artists:') as
			'albums' | 'artists' | 'tracks';
		await (
			await import('./seed-plays')
		).default(
			days,
			playCount,
			selectionKind,
			Number(readInput(`Input the number of distinct ${selectionKind} per user:`)),
			Number(readInput(`Input the common ${selectionKind} percentage:`)),
			upperBound
		);
		break;
	}
	default:
		console.error('Invalid script task ' + scriptTask);
}

process.exit(0);
