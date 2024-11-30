import commonjs from '@rollup/plugin-commonjs';
import { nodeResolve } from '@rollup/plugin-node-resolve';
import typescript from '@rollup/plugin-typescript';

/**
 * @type {import('rollup').RollupOptions}
 */
const config = {
	input: './src/index.ts',
	external: ['/node_modules/'], // All node modules are external
	output: {
		file: 'dist/index.js',
		sourcemap: true,
		format: 'es'
	},
	plugins: [
		typescript({ rootDir: '../..' }), // Ensures that other stuff (core) is bundled when necessary
		commonjs(),
		nodeResolve({
			resolveOnly: (name) => name.startsWith('@spotify-couples'), // This indicates that we are only resolving, not bundling
			preferBuiltins: true // We don't need to bundle these, so don't
		})
	]
};
export default config;
