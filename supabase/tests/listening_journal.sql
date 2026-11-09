-- Transactional local fixtures exercise the authenticated RPC without touching stored user data
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET search_path = public, extensions;
SELECT plan(38);

INSERT INTO auth.users (id) VALUES
('10000000-0000-0000-0000-000000000001'),
('10000000-0000-0000-0000-000000000002'),
('10000000-0000-0000-0000-000000000003');
INSERT INTO public.pairings (one_uuid, two_uuid) VALUES
('10000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002');
INSERT INTO public.artists (id, genres, name) VALUES ('journal-test-artist', '{}', 'Test artist');
INSERT INTO public.albums (id, album_type, name, release_date, release_date_precision, artist_ids)
VALUES ('journal-test-album', 'album', 'Test album', '2026-01-01', 'day', ARRAY['journal-test-artist']);
INSERT INTO public.tracks (id, explicit, duration_ms, disc_number, track_number, name, artist_ids, album_id)
SELECT id, false, 180000, 1, 1, id, ARRAY['journal-test-artist'], 'journal-test-album'
FROM unnest(ARRAY['journal-shared', 'journal-unique', 'journal-other', 'journal-boundary', 'journal-midnight']) id;

SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
CREATE TEMP TABLE journal_empty AS SELECT public.get_listening_journal(7, 'Asia/Kolkata') AS value;
SELECT is((SELECT (value->>'you_seconds')::numeric FROM journal_empty), 0::numeric, 'Empty period has zero listening');
SELECT is((SELECT jsonb_array_length(value->'daily') FROM journal_empty), 7, 'Empty period has seven daily buckets');
SELECT is((SELECT value->'timeline' FROM journal_empty), '[]'::jsonb, 'Empty period has no events');
SELECT is((SELECT value->'rankings' FROM journal_empty), '[]'::jsonb, 'Empty period has no rankings');

-- Anchor every fixture to the RPC's timezone-aware start; now() is fixed within this transaction
CREATE TEMP TABLE journal_anchor AS SELECT (value->>'start')::timestamptz AS start_at FROM journal_empty;
GRANT SELECT ON journal_anchor TO authenticated;
INSERT INTO public.plays (user_id, track_id, played_date_time)
SELECT '10000000-0000-0000-0000-000000000001', track_id, start_at + offset_time
FROM journal_anchor CROSS JOIN (VALUES
 ('journal-other', interval '-2 minutes'), -- capped before range start; must not create inverted window
 ('journal-boundary', interval '-1 minute'), -- carries two minutes into the range
 ('journal-shared', interval '1 hour'),
 ('journal-shared', interval '1 hour'), -- duplicate ingestion
 ('journal-other', interval '1 hour 1 minute'), -- caps preceding play at one minute
 ('journal-unique', interval '2 hours'),
 ('journal-unique', interval '3 hours'),
 ('journal-unique', interval '-2 days'), -- unique but not a new discovery
 ('journal-midnight', interval '23 hours 59 minutes'),
 ('journal-other', interval '0'), -- included exactly at start, truncates carry-in
 ('journal-other', interval '20 days') -- excluded future record
) fixture(track_id, offset_time);
INSERT INTO public.plays (user_id, track_id, played_date_time)
SELECT '10000000-0000-0000-0000-000000000002', track_id, start_at + offset_time
FROM journal_anchor CROSS JOIN (VALUES
 ('journal-shared', interval '1 hour 30 seconds'),
 ('journal-shared', interval '1 hour 30 seconds'),
 ('journal-boundary', interval '-1 minute')
) fixture(track_id, offset_time);
-- A play timestamped exactly at the exclusive end must not enter rankings or duration
INSERT INTO public.plays (user_id, track_id, played_date_time)
VALUES ('10000000-0000-0000-0000-000000000001', 'journal-other', now());

-- An unrelated user's history must never enter the pair's results
INSERT INTO public.plays (user_id, track_id, played_date_time)
SELECT '10000000-0000-0000-0000-000000000003', 'journal-unique', start_at + interval '4 hours' FROM journal_anchor;

SET LOCAL ROLE authenticated;
CREATE TEMP TABLE journal_actual AS SELECT public.get_listening_journal(7, 'Asia/Kolkata') AS value;
SELECT is((SELECT (value->>'overlap_seconds')::numeric FROM journal_actual), 30::numeric, 'Only 30 seconds of same-song overlap after skip cap; duplicates do not inflate it');
SELECT is((SELECT (value->>'you_seconds')::numeric FROM journal_actual), 960::numeric, 'Listening is capped at next play and exact range start');
SELECT is((SELECT (value->>'partner_seconds')::numeric FROM journal_actual), 300::numeric, 'Carry-in listening is clipped to range start');
SELECT is((SELECT sum((d->>'you')::numeric) FROM journal_actual, jsonb_array_elements(value->'daily') d), 960::numeric, 'Daily durations sum to summary across midnight');
SELECT is((SELECT (d->>'you')::numeric FROM journal_actual, jsonb_array_elements(value->'daily') d WHERE d->>'day' = ((journal_actual.value->>'start')::timestamptz AT TIME ZONE 'Asia/Kolkata')::date::text), 840::numeric, 'Midnight bucket includes only first minute');
SELECT is((SELECT (r->>'plays')::integer FROM journal_actual, jsonb_array_elements(value->'rankings') r WHERE r->>'category' = 'songs' AND r->>'listener' = 'both' AND r->>'id' = 'journal-shared'), 2, 'Duplicate rows count once per listener');
SELECT ok((SELECT EXISTS(SELECT 1 FROM jsonb_array_elements(value->'timeline') e WHERE e->>'id' = 'journal-unique' AND e->>'kind' = 'unique' AND (e->>'you')::int = 2 AND (e->>'partner')::int = 0 AND e->>'first_play' IS NULL) FROM journal_actual), 'Unique counts are pair-scoped and old history prevents false discovery');
SELECT ok((SELECT EXISTS(SELECT 1 FROM jsonb_array_elements(value->'timeline') e WHERE e->>'id' = 'journal-shared' AND e->>'kind' = 'discovery' AND e->>'first_play' IS NOT NULL) FROM journal_actual), 'Discoveries use first recorded history');
SELECT is((SELECT (r->>'plays')::integer FROM journal_actual, jsonb_array_elements(value->'rankings') r WHERE r->>'category' = 'songs' AND r->>'listener' = 'you' AND r->>'id' = 'journal-other'), 2, 'Exact start included and future record excluded');
SELECT throws_ok($$SELECT public.get_listening_journal(8, 'UTC')$$, '22023', 'InvalidJournalRange', 'Reject unsupported range');
SELECT throws_ok($$SELECT public.get_listening_journal(7, 'bad/timezone')$$, '22023', 'InvalidJournalTimezone', 'Reject invalid timezone');
SELECT throws_ok($$SELECT public.get_listening_journal(NULL, 'UTC')$$, '22023', 'InvalidJournalRange', 'Reject null range');
SELECT is(jsonb_array_length(public.get_listening_journal(30, 'UTC')->'daily'), 30, 'Thirty-day range has thirty daily buckets');
SELECT ok(NOT has_table_privilege('authenticated', 'public.plays', 'SELECT'), 'No direct history access');
SELECT ok(NOT has_function_privilege('anon', 'public.get_listening_journal(integer,text)', 'EXECUTE'), 'Anonymous role cannot execute journal');
SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000003', true);
SELECT throws_ok($$SELECT public.get_listening_journal()$$, '42501', 'NoPartnerException', 'Unpaired user cannot query journal');
SELECT set_config('request.jwt.claim.sub', '', true);
SELECT throws_ok($$SELECT public.get_listening_journal()$$, '42501', 'AuthenticationRequired', 'Missing auth is rejected even with authenticated role');
RESET ROLE;

-- Repeat with a deliberately different database session timezone; range and buckets must not change
SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
SET LOCAL timezone = 'Pacific/Auckland';
SELECT is((public.get_listening_journal(7, 'Asia/Kolkata')->>'start')::timestamptz, (SELECT start_at FROM journal_anchor), 'Boundaries ignore database session timezone');
SELECT is(public.get_listening_journal(7, 'Asia/Kolkata')->'daily', (SELECT value->'daily' FROM journal_actual), 'Daily bucketing ignores database session timezone');
SELECT is((public.get_listening_journal(7, 'Asia/Kolkata')->>'overlap_seconds')::numeric, 30::numeric, 'Overlap ignores database session timezone');
SELECT ok((SELECT count(*) <= 30 FROM journal_actual, jsonb_array_elements(value->'timeline')), 'Timeline payload is bounded');
-- Two songs tied at the same timestamp test unioning within a person and across shared tracks
INSERT INTO public.plays (user_id, track_id, played_date_time)
SELECT u.id::uuid, t.id, start_at + interval '5 hours'
FROM journal_anchor CROSS JOIN (VALUES
 ('10000000-0000-0000-0000-000000000001'),
 ('10000000-0000-0000-0000-000000000002')
) u(id) CROSS JOIN (VALUES ('journal-shared'), ('journal-other')) t(id);
SET LOCAL ROLE authenticated;
SELECT is((public.get_listening_journal(7, 'Asia/Kolkata')->>'overlap_seconds')::numeric,
  210::numeric, 'Overlapping same-song matches across tied tracks are unioned globally');
SELECT is((public.get_listening_journal(7, 'Asia/Kolkata')->>'you_seconds')::numeric,
  1140::numeric, 'Tied track windows count once for viewer');
SELECT is((public.get_listening_journal(7, 'Asia/Kolkata')->>'partner_seconds')::numeric,
  480::numeric, 'Tied track windows count once for partner');
SELECT is((SELECT (e->>'overlap_seconds')::numeric
  FROM jsonb_array_elements(public.get_listening_journal(7, 'Asia/Kolkata')->'timeline') e
  WHERE e->>'kind' = 'shared' AND e->>'id' = 'journal-shared'),
  210::numeric, 'Per-song shared evidence unions separate episodes without duplicates');
-- Context uses retained history even when the active range has no plays for that person
SELECT is((SELECT (e->>'you_first_play')::timestamptz FROM journal_actual, jsonb_array_elements(value->'timeline') e WHERE e->>'id' = 'journal-unique' AND e->>'kind' = 'unique'), (SELECT start_at - interval '2 days' FROM journal_anchor), 'First viewer listen predates both selected ranges');
SELECT ok((SELECT e->>'partner_first_play' IS NULL FROM journal_actual, jsonb_array_elements(value->'timeline') e WHERE e->>'id' = 'journal-unique' AND e->>'kind' = 'unique'), 'Unrelated user history does not imply the partner listened');
RESET ROLE;
INSERT INTO public.plays (user_id, track_id, played_date_time)
SELECT '10000000-0000-0000-0000-000000000002', 'journal-unique', start_at - interval '40 days' FROM journal_anchor;
INSERT INTO public.plays (user_id, track_id, played_date_time) VALUES
('10000000-0000-0000-0000-000000000002', 'journal-midnight', now() + interval '1 day');
SET LOCAL ROLE authenticated;
CREATE TEMP TABLE journal_history AS SELECT public.get_listening_journal(7, 'Asia/Kolkata') AS value;
SELECT is((SELECT (e->>'partner_first_play')::timestamptz FROM journal_history, jsonb_array_elements(value->'timeline') e WHERE e->>'id' = 'journal-unique' AND e->>'kind' = 'unique'), (SELECT start_at - interval '40 days' FROM journal_anchor), 'Partner first listen is retained beyond 30 days');
SELECT is((SELECT (e->>'partner')::integer FROM journal_history, jsonb_array_elements(value->'timeline') e WHERE e->>'id' = 'journal-unique' AND e->>'kind' = 'unique'), 0, 'Historical context never changes selected-period play counts');
SELECT is((SELECT (e->>'you_first_play')::timestamptz FROM journal_history, jsonb_array_elements(value->'timeline') e WHERE e->>'id' = 'journal-unique' AND e->>'kind' = 'unique'), (SELECT (e->>'you_first_play')::timestamptz FROM jsonb_array_elements(public.get_listening_journal(30, 'Asia/Kolkata')->'timeline') e WHERE e->>'id' = 'journal-unique' AND e->>'kind' = 'unique'), 'First-listen context is identical for seven-day and thirty-day ranges');
SELECT ok((SELECT e->>'partner_first_play' IS NULL FROM journal_history, jsonb_array_elements(value->'timeline') e WHERE e->>'id' = 'journal-midnight' AND e->>'kind' = 'unique'), 'Future history does not imply a prior listen');
SELECT is((SELECT r->>'subtitle' FROM journal_actual, jsonb_array_elements(value->'rankings') r WHERE r->>'category' = 'artists' AND r->>'listener' = 'both' AND r->>'id' = 'journal-test-artist'), '', 'Artist rankings omit subtext');
SELECT is((SELECT r->>'subtitle' FROM journal_actual, jsonb_array_elements(value->'rankings') r WHERE r->>'category' = 'albums' AND r->>'listener' = 'both' AND r->>'id' = 'journal-test-album'), 'Test artist', 'Album rankings show the album artist');
SELECT is((SELECT r->>'subtitle' FROM journal_actual, jsonb_array_elements(value->'rankings') r WHERE r->>'category' = 'songs' AND r->>'listener' = 'both' AND r->>'id' = 'journal-shared'), 'Test artist · Test album', 'Song rankings show artist and album');
SELECT * FROM finish();
ROLLBACK;
