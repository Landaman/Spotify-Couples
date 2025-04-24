// Setup the firebase project and emulators
process.env.GCLOUD_PROJECT = 'spotify-couples'; // This MUST be the GCP project ID actually used, or the script doesn't work?
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080'; // Use the firestore emulator

(await import('firebase-admin/app')).initializeApp();

const scriptTask = prompt('Enter the task to run:');
switch (scriptTask) {
	case 'auto-pair':
		await (await import('./auto-pair')).default();
		break;
	case 'generate-pairing-code':
		await (await import('./generate-pairing-code')).default();
		break;
	case 'pair-with-code':
		await (await import('./pair-with-code')).default(prompt('Input the code to pair with:') ?? '');
		break;
	default:
		console.error('Invalid script task ' + scriptTask);
}

process.exit(0);

export {};
