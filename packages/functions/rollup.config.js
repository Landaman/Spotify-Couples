import commonjs from '@rollup/plugin-commonjs';
import { nodeResolve } from '@rollup/plugin-node-resolve';

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
		nodeResolve({
			resolveOnly: () => false, // This indicates that we are only resolving, not bundling
			preferBuiltins: true // We don't need to bundle these, so don't
		}),
		commonjs()
	]
};
export default config;
