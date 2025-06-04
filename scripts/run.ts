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

// Required or else this is marked as not a module
export {};
