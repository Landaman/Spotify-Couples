import adapter from '@sveltejs/adapter-vercel';
import { enhancedImages } from '@sveltejs/enhanced-img';
import { sveltekit } from '@sveltejs/kit/vite';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';
import tailwindcss from '@tailwindcss/vite';
import { defineConfig, type Plugin as VitePlugin } from 'vite';

function errorPageStyles(): VitePlugin {
	return {
		name: 'error-page-styles',
		transform(code, id) {
			// SvelteKit stringifies error.html instead of passing it through Vite's
			// HTML pipeline. Import the CSS URL in its shared template module so
			// Vite resolves it in dev and emits the hashed stylesheet in builds.
			if (!id.endsWith('/shared/error-template.js') || !code.includes('%app.styles%')) return;
			return {
				code:
					`import appStyles from '/src/app.css?url';\n` +
					code.replaceAll('%app.styles%', '" + appStyles + "'),
				map: null
			};
		}
	};
}

export default defineConfig({
	plugins: [
		enhancedImages(),
		tailwindcss(),
		errorPageStyles(),
		sveltekit({
			// Consult https://kit.svelte.dev/docs/integrations#preprocessors
			// for more information about preprocessors
			preprocess: vitePreprocess(),

			adapter: adapter(),
			paths: { relative: false }
		})
	]
});
