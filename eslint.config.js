// @ts-check

import eslint from '@eslint/js';
import eslintConfigPrettier from 'eslint-config-prettier';
import eslintPluginSvelte from 'eslint-plugin-svelte';
import eslintPluginTailwindcss from 'eslint-plugin-tailwindcss';
import eslintPluginSvelteParser from 'svelte-eslint-parser';
import tseslint, { parser as tseslintParser } from 'typescript-eslint';

export default tseslint.config(
	eslint.configs.recommended,
	...tseslint.configs.strict,
	...tseslint.configs.stylistic,
	...eslintPluginSvelte.configs['flat/recommended'],
	...eslintPluginSvelte.configs['flat/prettier'],
	eslintPluginTailwindcss.configs.recommended,
	eslintConfigPrettier,
	{ ignores: ['.svelte-kit'] },
	{
		settings: {
			tailwindcss: {
				cssConfigPath: './src/app.css'
			}
		}
	},
	{
		rules: {
			semi: 'error',
			'no-empty': 'warn',
			'@typescript-eslint/no-empty-function': 'warn',
			'prefer-const': 'warn',
			'no-undef': 'off',
			'@typescript-eslint/no-unused-vars': 'warn',
			'@typescript-eslint/no-empty-interface': 'warn',
			'@typescript-eslint/no-shadow': ['warn', { builtinGlobals: true, hoist: 'functions' }]
		},
		languageOptions: {
			parser: tseslintParser,
			parserOptions: {
				project: ['./tsconfig.json'],
				tsconfigRootDir: import.meta.dirname,
				extraFileExtensions: ['.svelte']
			}
		}
	},
	{
		files: ['**/*.svelte'],
		languageOptions: {
			parser: eslintPluginSvelteParser,
			parserOptions: {
				parser: tseslintParser
			}
		},
		rules: {
			'@typescript-eslint/no-unused-vars': [
				'warn',
				{
					argsIgnorePattern: '^_',
					varsIgnorePattern: '^\\$\\$(Props|Events|Slots|Generic)$'
				}
			],
			'prefer-const': 'off',
			'svelte/prefer-const': 'warn'
		}
	},
	{
		files: ['./src/lib/components/ui/**/*'],
		rules: {
			'@typescript-eslint/no-shadow': 'off',
			'svelte/no-navigation-without-resolve': 'off'
		}
	}
);
