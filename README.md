# Spotify Couples

A simple app to let you and your partner compare your shared music listening history.

Not endorsed by or related to Spotify. Spotify logo and all Spotify content is copyright and owned by Spotify. 

This is just a hobby project.

## Tech Stack

Frontend: [Svelte(Kit)](https://svelte.dev), [TailwindCSS](https://tailwindcss.com), and [shadcn-svelte](https://shadcn-svelte.com)

Backend: [Supabase](https://supabase.com) Postgres (yes this probably adds a ton of extra complexity by writing most of the business logic in PLpgsql- but wanted to learn :))

Analytics: [PostHog](https://posthog.com) for fun and learning :)

## Architecture

The SvelteKit backend is mostly just an SSR layer. All of the interesting backend logic lives in Supabase RPCs written in
PLpgsql.

### Spotify Listening History Reads

Spotify reads are done through a Supabase cron, which uses a saved per-user auth token in the Supabase Vault. Spotify
only lets you read so much play history (maybe 100 songs or something like that?) so we run this cron for every user
every 15 minutes. Spotify tokens do eventually expire, so there's some logic in Supabase and on the client to determine
if the Spotify auth token is outdated for the user, and we show a popup prompting them to re-authenticate when that's the
case.

This is probably the single most brittle part of the app, since we have to do JSON response building/parsing in SQL
which is quite messy. Also because of the weirdness with the tokens above.

## Hosting

I host the frontend on Vercel, but that's pretty easy to swap in/out with whatever you want. The backend of Supabase
will be harder to replace. 

### Production

Frontend environment variables:
- `PUBLIC_POSTHOG_HOST` (if you want to use PostHog)
- `PUBLIC_POSTHOG_KEY` (if you want to use PostHog)
- `PUBLIC_SUPABASE_PUBLISHABLE_KEY`
- `PUBLIC_SUPABASE_URL`

Supabase environment variables (really these just need to be in your vault):
- `SPOTIFY_CLIENT_ID` (your Spotify Developer App Client ID)
- `SPOTIFY_CLIENT_SECRET` (your Spotify Developer App Client Secret)

### Scripts

There are several debugging scripts to make it easier for you and your Agents to debug the app during development.

These need some more environment variables:
- `SUPABASE_SECRET_KEY` the secret key for your Supabase development instance
