export default {
	'*': () => [
		'prettier --write .',
		'eslint --fix .',
		'svelte-kit sync',
		'svelte-check --tsconfig ./tsconfig.json'
	]
};
