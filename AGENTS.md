# Spotify Couples

Fun app designed to show two people (probably a couple) how closely their Spotify
listening lines up with each other

This is an application that uses Supabase as its backend and SvelteKit as a
front/middleware layer. Most of the business logic should live in Supabase RPCs

## Supabase

When you make changes to the Supabase schema (`Supabase/schemas`), you should do
the following:

1. Create a migrations file in the `Supabase/migrations` directory.
   This file should contain the SQL statements needed to apply your schema changes.
   For things like permissions, list them both in the appropriate schema file an
   d in the migration file
2. Apply the migration using the `bun supabase` cli
3. Run `bun gen:supabase` to generate the `supabase/schema.d.ts` file. Do not edit
   this file manually. You must do this after updating the db
4. Lint the database using `bun check:supabase`

Keep in mind that subsequent changes in the same commit can alter the migration
file you generated in #1, you just need to make sure to apply the rest of the steps

## SvelteKit

After you make a change to a file in the SvelteKit system (i.e., TypeScript
page/hook/routing files or interfaces), you should run `bun gen:svelte` before
running `bun check:svelte` or `bun lint`

## Local Testing Tools

### Using Scripts

There are many scripts in `scripts/` that may aid you in testing the app.
These include login, pairing, generating test data, and more. Run
the launcher with `bun scripts/run.ts`, or use the launcher with a
task name and any needed arguments, such as
`bun scripts/run.ts generate-login-link tester@example.test`. Arguments follow
the prompt order; missing values are prompted for. Read the task implementation
for its inputs and functionality.

### Adding New Scripts

Match the style of existing scripts. Be sure to read through some other
scripts and at least `scripts/run.ts` and `scripts/helpers.ts` to understand
the patterns before starting your work
