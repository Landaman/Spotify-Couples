-- Pair-scoped journal for the last 7 or 30 calendar days, including today
-- Inputs: day count and IANA timezone; output: bounded aggregate JSON, never raw history
-- Raises for unauthenticated/unpaired callers or invalid range/timezone
CREATE FUNCTION public.get_listening_journal (
  day_count integer DEFAULT 7,
  timezone_name text DEFAULT 'UTC'
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = '' AS $$
DECLARE
  v_viewer uuid := auth.uid();
  v_partner uuid;
  range_start timestamptz;
  range_end timestamptz := now();
  first_day date;
  result jsonb;
BEGIN
  IF v_viewer IS NULL THEN
    RAISE EXCEPTION 'AuthenticationRequired' USING ERRCODE = '42501';
  END IF;
  v_partner := private.get_partner_id();
  IF v_partner IS NULL THEN
    RAISE EXCEPTION 'NoPartnerException' USING ERRCODE = '42501';
  END IF;
  IF day_count IS NULL OR day_count NOT IN (7, 30) THEN
    RAISE EXCEPTION 'InvalidJournalRange' USING ERRCODE = '22023';
  END IF;
  IF timezone_name IS NULL OR NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_timezone_names WHERE name = timezone_name
  ) THEN
    RAISE EXCEPTION 'InvalidJournalTimezone' USING ERRCODE = '22023';
  END IF;
  first_day := (range_end AT TIME ZONE timezone_name)::date - (day_count - 1);
  range_start := first_day::timestamp AT TIME ZONE timezone_name;

  WITH history AS MATERIALIZED (
    -- Duplicate ingestion must not inflate counts or overlap; tied distinct songs remain recorded plays
    SELECT DISTINCT p.user_id, p.track_id, p.played_date_time AS played_at
    FROM public.plays p WHERE p.user_id IN (v_viewer, v_partner)
  ), selected AS MATERIALIZED (
    SELECT * FROM history WHERE played_at >= range_start AND played_at < range_end
  ), time_edges AS (
    SELECT user_id, played_at,
      lead(played_at) OVER (PARTITION BY user_id ORDER BY played_at) AS next_play
    FROM (SELECT DISTINCT user_id, played_at FROM history) timestamps
  ), candidate_windows AS (
    -- Spotify documents played_at as when the track was played, without measured listening duration
    -- Treat it as an estimated start, capped by the next distinct timestamp, track duration and now
    SELECT h.user_id, h.track_id, h.played_at,
      least(h.played_at + greatest(t.duration_ms, 0) * interval '1 millisecond',
        coalesce(e.next_play, range_end), range_end) AS estimated_end
    FROM history h JOIN time_edges e USING (user_id, played_at)
    JOIN public.tracks t ON t.id = h.track_id
    WHERE h.played_at < range_end
  ), windows AS MATERIALIZED (
    SELECT user_id, track_id,
      tstzrange(greatest(played_at, range_start), estimated_end, '[)') AS span
    FROM candidate_windows WHERE estimated_end > greatest(played_at, range_start)
  ), person_ranges AS (
    SELECT user_id, range_agg(span) AS spans
    FROM windows GROUP BY user_id
  ), totals AS (
    SELECT user_id, sum(extract(epoch FROM upper(s) - lower(s))) AS seconds
    FROM person_ranges CROSS JOIN LATERAL unnest(spans) s GROUP BY user_id
  ), shared_ranges AS MATERIALIZED (
    SELECT a.track_id, range_agg(a.span * b.span) AS spans
    FROM windows a JOIN windows b ON a.track_id = b.track_id AND a.span && b.span
    WHERE a.user_id = v_viewer AND b.user_id = v_partner GROUP BY a.track_id
  ), shared AS (
    SELECT track_id, sum(extract(epoch FROM upper(s) - lower(s))) AS seconds,
      max(lower(s)) AS latest
    FROM shared_ranges CROSS JOIN LATERAL unnest(spans) s GROUP BY track_id
  ), overlap_union AS (
    -- Union across tracks too, so conflicting tied timestamps cannot inflate the shared total
    SELECT range_agg(s) AS spans FROM shared_ranges CROSS JOIN LATERAL unnest(spans) s
  ), calendar AS (
    SELECT first_day + i AS day FROM generate_series(0, day_count - 1) i
  ), daily AS (
    -- Convert each local midnight independently, preserving 23/25-hour DST days
    SELECT c.day,
      coalesce(sum(extract(epoch FROM
        least(upper(s), (c.day + 1)::timestamp AT TIME ZONE timezone_name) -
        greatest(lower(s), c.day::timestamp AT TIME ZONE timezone_name)
      )) FILTER (WHERE r.user_id = v_viewer), 0) AS you,
      coalesce(sum(extract(epoch FROM
        least(upper(s), (c.day + 1)::timestamp AT TIME ZONE timezone_name) -
        greatest(lower(s), c.day::timestamp AT TIME ZONE timezone_name)
      )) FILTER (WHERE r.user_id = v_partner), 0) AS partner
    FROM calendar c LEFT JOIN (person_ranges r CROSS JOIN LATERAL unnest(r.spans) s)
      ON s && tstzrange(c.day::timestamp AT TIME ZONE timezone_name,
        (c.day + 1)::timestamp AT TIME ZONE timezone_name, '[)')
    GROUP BY c.day
  ), song_counts AS MATERIALIZED (
    SELECT track_id, count(*) FILTER (WHERE user_id = v_viewer) AS you,
      count(*) FILTER (WHERE user_id = v_partner) AS partner, max(played_at) AS latest
    FROM selected GROUP BY track_id
  ), first_plays AS MATERIALIZED (
    -- History context is independent of the active range and excludes future records
    SELECT h.track_id, h.user_id, min(h.played_at) AS first_play
    FROM history h JOIN song_counts c ON c.track_id = h.track_id
    WHERE h.played_at < range_end GROUP BY h.track_id, h.user_id
  ), songs AS MATERIALIZED (
    SELECT t.id, t.name, a.name AS album, coalesce(a.picture_url, '') AS picture,
      coalesce((SELECT string_agg(ar.name, ', ' ORDER BY ids.ordinality)
        FROM unnest(t.artist_ids) WITH ORDINALITY ids(id, ordinality)
        JOIN public.artists ar ON ar.id = ids.id), '') AS artist,
      coalesce(c.you, 0) AS you, coalesce(c.partner, 0) AS partner, c.latest,
      sh.seconds AS overlap_seconds, sh.latest AS overlap_latest,
      viewer_history.first_play AS you_first_play,
      partner_history.first_play AS partner_first_play
    FROM public.tracks t JOIN public.albums a ON a.id = t.album_id
    LEFT JOIN song_counts c ON c.track_id = t.id LEFT JOIN shared sh ON sh.track_id = t.id
    LEFT JOIN first_plays viewer_history ON viewer_history.track_id = t.id AND viewer_history.user_id = v_viewer
    LEFT JOIN first_plays partner_history ON partner_history.track_id = t.id AND partner_history.user_id = v_partner
    WHERE c.track_id IS NOT NULL OR sh.track_id IS NOT NULL
  ), ranking_items AS (
    SELECT 'songs' AS category, t.id, t.name, concat_ws(' · ', nullif(s.artist, ''), s.album) AS subtitle, s.picture, p.user_id
    FROM selected p JOIN public.tracks t ON t.id = p.track_id JOIN songs s ON s.id = t.id
    UNION ALL
    SELECT 'albums', a.id, a.name,
      coalesce((SELECT string_agg(ar.name, ', ' ORDER BY ids.ordinality)
        FROM unnest(a.artist_ids) WITH ORDINALITY ids(id, ordinality)
        JOIN public.artists ar ON ar.id = ids.id), ''),
      coalesce(a.picture_url, ''), p.user_id
    FROM selected p JOIN public.tracks t ON t.id = p.track_id
    JOIN public.albums a ON a.id = t.album_id
    UNION ALL
    SELECT 'artists', ar.id, ar.name, '', coalesce(ar.picture_url, ''), p.user_id
    FROM selected p JOIN public.tracks t ON t.id = p.track_id
    CROSS JOIN LATERAL (SELECT DISTINCT unnest(t.artist_ids) AS id) ids
    JOIN public.artists ar ON ar.id = ids.id
  ), rankings AS (
    SELECT category, listener, id, name, subtitle, picture, count(*) AS plays,
      row_number() OVER (
        PARTITION BY category, listener ORDER BY count(*) DESC, name, id
      ) AS rank
    FROM ranking_items CROSS JOIN (VALUES ('both'), ('you'), ('partner')) l(listener)
    WHERE listener = 'both' OR (listener = 'you' AND user_id = v_viewer)
      OR (listener = 'partner' AND user_id = v_partner)
    GROUP BY category, listener, id, name, subtitle, picture
  ), discoveries AS (
    -- First recorded is measured against all retained history, never just the selected period
    SELECT h.track_id, h.user_id, min(h.played_at) AS first_play
    FROM history h JOIN song_counts c ON c.track_id = h.track_id
    GROUP BY h.track_id, h.user_id
    HAVING min(h.played_at) >= range_start AND min(h.played_at) < range_end
  ), events AS (
    SELECT s.*, 'shared' AS kind, 'both' AS listener,
      s.overlap_latest AS occurred_at, NULL::timestamptz AS first_play
    FROM songs s WHERE overlap_seconds > 0
    UNION ALL
    SELECT s.*, 'unique', CASE WHEN you > 0 THEN 'you' ELSE 'partner' END, latest,
      (SELECT d.first_play FROM discoveries d WHERE d.track_id = s.id AND
        d.user_id = CASE WHEN s.you > 0 THEN v_viewer ELSE v_partner END)
    FROM songs s WHERE (you > 0 AND partner = 0) OR (partner > 0 AND you = 0)
    UNION ALL
    SELECT s.*, 'discovery', CASE WHEN d.user_id = v_viewer THEN 'you' ELSE 'partner' END,
      (SELECT max(p.played_at) FROM selected p
        WHERE p.track_id = s.id AND p.user_id = d.user_id), d.first_play
    FROM songs s JOIN discoveries d ON d.track_id = s.id WHERE s.you > 0 AND s.partner > 0
  ), bounded_events AS (
    SELECT *, row_number() OVER (
      PARTITION BY kind, listener ORDER BY occurred_at DESC, id
    ) AS rank FROM events
  )
  SELECT jsonb_build_object(
    'start', range_start, 'end', range_end, 'timezone', timezone_name,
    'you_seconds', coalesce((SELECT seconds FROM totals WHERE user_id = v_viewer), 0),
    'partner_seconds', coalesce((SELECT seconds FROM totals WHERE user_id = v_partner), 0),
    'overlap_seconds', coalesce((SELECT sum(extract(epoch FROM upper(s) - lower(s)))
      FROM overlap_union CROSS JOIN LATERAL unnest(spans) s), 0),
    'daily', (SELECT jsonb_agg(to_jsonb(daily) ORDER BY day) FROM daily),
    'rankings', coalesce((SELECT jsonb_agg(to_jsonb(rankings) ORDER BY category, listener, rank)
      FROM rankings WHERE rank <= 5), '[]'::jsonb),
    'timeline', coalesce((SELECT jsonb_agg(to_jsonb(bounded_events) ORDER BY occurred_at DESC, kind, id)
      FROM bounded_events WHERE rank <= 6), '[]'::jsonb)
  ) INTO result;
  RETURN result;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_listening_journal(integer, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.get_listening_journal(integer, text) TO authenticated;

-- Support pair-scoped journal history scans
CREATE INDEX plays_user_time_track_idx ON public.plays (user_id, played_date_time, track_id);
