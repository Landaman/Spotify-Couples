import { beforeAll, test } from 'bun:test';
import { initializeApp } from 'firebase-admin/app';

beforeAll(async () => {
	// Setup the firebase project and emulators
	process.env.GCLOUD_PROJECT = 'demo-spotify-couples';
	process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';
	process.env.FIREBASE_AUTH_EMULATOR_HOST = 'localhost:9099';

	initializeApp();
});

test('script', async () => {
	const scriptTask = prompt('Enter the task to run:');
	switch (scriptTask) {
		case 'auto-pair':
			await (await import('./auto-pair')).default();
			break;
		case 'generate-pairing-code':
			await (await import('./generate-pairing-code')).default();
			break;
		case 'pair-with-code':
			await (
				await import('./pair-with-code')
			).default(prompt('Input the code to pair with:') ?? '');
			break;
		default:
			console.error('Invalid script task ' + scriptTask);
	}
});
