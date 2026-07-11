import { spawnSync } from 'node:child_process';
import { existsSync, readdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { format as formatSql } from 'sql-formatter';

const roots = ['supabase/schemas'];
const pgFormat = 'node_modules/pg-formatter/dist/pg-formatter/pg_format';
const sqlFormatterConfig = existsSync('.sql-formatter.json')
	? JSON.parse(readFileSync('.sql-formatter.json', 'utf8'))
	: { language: 'postgresql' };

function findSqlFiles(directory: string): string[] {
	return readdirSync(directory)
		.flatMap((entry) => {
			const path = join(directory, entry);
			const stat = statSync(path);

			if (stat.isDirectory()) {
				return findSqlFiles(path);
			}

			return stat.isFile() && path.endsWith('.sql') ? [path] : [];
		})
		.sort();
}

function formatPg(file: string): string {
	const result = spawnSync(pgFormat, [file], {
		encoding: 'utf8'
	});

	if (result.status === 0) {
		return result.stdout;
	}

	const stderr = result.stderr.trim();
	const stdout = result.stdout.trim();
	const output = [stderr, stdout].filter(Boolean).join('\n');

	throw new Error(`Failed to format ${file} with ${pgFormat}${output ? `\n${output}` : ''}`);
}

const files = (
	process.argv.slice(2).length > 0
		? process.argv.slice(2)
		: roots.flatMap((root) => findSqlFiles(root))
).sort();

for (const file of files) {
	try {
		const formattedPg = formatPg(file);
		const formatted = formatSql(formattedPg, sqlFormatterConfig);
		writeFileSync(file, formatted.endsWith('\n') ? formatted : `${formatted}\n`);
	} catch (error) {
		throw new Error(`Failed to format ${file}`, { cause: error });
	}
}

console.log(`Formatted ${files.length} SQL files in ./supabase`);
