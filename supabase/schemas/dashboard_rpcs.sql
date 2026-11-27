CREATE TYPE public.top_listens_listener AS enum('combined', 'you', 'partner');

CREATE TYPE public.top_songs_artist AS (id text, name text);

CREATE TYPE public.top_songs_album AS (id text, name text, picture_url text);

CREATE TYPE public.top_songs_track AS (
  id text,
  name text,
  album public.top_songs_album,
  artists public.top_songs_artist[]
);

CREATE FUNCTION private.get_track_play_counts (
  listener public.top_listens_listener,
  range_days integer
) RETURNS TABLE (
  track_id text,
  plays bigint,
  user_plays bigint,
  partner_plays bigint
) LANGUAGE plpgsql
SET
  search_path = ''
  -- Let PostgreSQL plan all-time and date-filtered scans using the actual parameters
SET
  plan_cache_mode = force_custom_plan AS $$
DECLARE
  requesting_user_id uuid := auth.uid ();
  partner_id uuid := private.get_partner_id ();
  range_end timestamp with time zone := statement_timestamp();
  range_start timestamp with time zone;
BEGIN
  IF partner_id IS NULL THEN
    RAISE EXCEPTION 'NoPartnerException';
  END IF;

  IF listener IS NULL THEN
    RAISE EXCEPTION 'InvalidListenerException';
  END IF;
  IF range_days <= 0 THEN
    RAISE EXCEPTION 'InvalidDateRangeException';
  END IF;

  range_start := date_subtract (range_end, make_interval(days => range_days),
    'UTC');
  -- Keep both listeners’ counts even when only one listener determines the ranking
  RETURN QUERY
  SELECT
    p.track_id,
    count(*) FILTER (WHERE CASE listener
      WHEN 'you' THEN
        p.user_id = requesting_user_id
      WHEN 'partner' THEN
        p.user_id = partner_id
      ELSE
        TRUE
      END) plays,
    count(*) FILTER (WHERE p.user_id = requesting_user_id) AS user_plays,
    count(*) FILTER (WHERE p.user_id = partner_id) AS partner_plays
  FROM
    public.plays AS p
  WHERE
    p.user_id IN (requesting_user_id, partner_id)
    AND (range_start IS NULL
      OR (p.played_date_time >= range_start
        AND p.played_date_time < range_end))
  GROUP BY
    p.track_id;
END;
$$;

REVOKE
EXECUTE ON FUNCTION private.get_track_play_counts (public.top_listens_listener, integer)
FROM
  public,
  anon,
  authenticated;

CREATE FUNCTION public.get_top_songs (
  listener public.top_listens_listener,
  range_days integer
) RETURNS TABLE (
  track public.top_songs_track,
  plays bigint,
  user_plays bigint,
  partner_plays bigint
) LANGUAGE plpgsql SECURITY DEFINER
SET
  search_path = '' AS $$
BEGIN
  -- Select the winners before fetching track, album, and artist details
  RETURN QUERY WITH top_tracks AS (
    SELECT
      counts.*
    FROM
      private.get_track_play_counts (listener, range_days) AS counts
    WHERE
      counts.plays > 0
    ORDER BY
      counts.plays DESC,
      counts.track_id
    LIMIT 5
)
SELECT
  ROW (tracks.id,
    tracks.name,
    ROW (albums.id,
      albums.name,
      albums.picture_url)::public.top_songs_album,
    ARRAY (
      SELECT
        ROW (artists.id,
          artists.name)::public.top_songs_artist
      FROM
        unnest(tracks.artist_ids)
        WITH ORDINALITY AS track_artists (id,
        ORDINALITY)
        JOIN public.artists AS artists ON artists.id = track_artists.id
      ORDER BY
        track_artists.ordinality))::public.top_songs_track,
  top_tracks.plays,
  top_tracks.user_plays,
  top_tracks.partner_plays
FROM
  top_tracks
    INNER JOIN public.tracks AS tracks ON tracks.id = top_tracks.track_id
    INNER JOIN public.albums AS albums ON albums.id = tracks.album_id
  ORDER BY
    top_tracks.plays DESC,
    top_tracks.track_id;
END;
$$;

REVOKE
EXECUTE ON FUNCTION public.get_top_songs (public.top_listens_listener, integer)
FROM
  public;

REVOKE
EXECUTE ON FUNCTION public.get_top_songs (public.top_listens_listener, integer)
FROM
  anon;

GRANT
EXECUTE ON FUNCTION public.get_top_songs (public.top_listens_listener, integer) TO authenticated;

CREATE FUNCTION public.get_top_albums (
  listener public.top_listens_listener,
  range_days integer
) RETURNS TABLE (
  id text,
  name text,
  picture_url text,
  plays bigint,
  user_plays bigint,
  partner_plays bigint
) LANGUAGE plpgsql SECURITY DEFINER
SET
  search_path = '' AS $$
BEGIN
  RETURN QUERY WITH ranked AS (
    SELECT
      track.album_id AS id,
      sum(counts.plays)::bigint AS plays,
      sum(counts.user_plays)::bigint AS user_plays,
      sum(counts.partner_plays)::bigint AS partner_plays
    FROM
      private.get_track_play_counts (listener, range_days) AS counts
      JOIN public.tracks AS track ON track.id = counts.track_id
    GROUP BY
      track.album_id
    HAVING
      sum(counts.plays) > 0
    ORDER BY
      plays DESC,
      track.album_id
    LIMIT 5
)
SELECT
  album.id,
  album.name,
  album.picture_url,
  ranked.plays,
  ranked.user_plays,
  ranked.partner_plays
FROM
  ranked
  JOIN public.albums AS album ON album.id = ranked.id
ORDER BY
  ranked.plays DESC,
  ranked.id;
END;
$$;

REVOKE
EXECUTE ON FUNCTION public.get_top_albums (public.top_listens_listener, integer)
FROM
  public,
  anon;

GRANT
EXECUTE ON FUNCTION public.get_top_albums (public.top_listens_listener, integer) TO authenticated;

CREATE FUNCTION public.get_top_artists (
  listener public.top_listens_listener DEFAULT 'combined',
  range_days integer DEFAULT NULL
) RETURNS TABLE (
  id text,
  name text,
  picture_url text,
  plays bigint,
  user_plays bigint,
  partner_plays bigint
) LANGUAGE plpgsql SECURITY DEFINER
SET
  search_path = '' AS $$
BEGIN
  RETURN QUERY WITH ranked AS (
    SELECT
      credit.id AS id,
      sum(counts.plays)::bigint AS plays,
      sum(counts.user_plays)::bigint AS user_plays,
      sum(counts.partner_plays)::bigint AS partner_plays
    FROM
      private.get_track_play_counts (listener, range_days) AS counts
      JOIN public.tracks AS track ON track.id = counts.track_id
      JOIN public.artists AS credit ON credit.id = ANY (track.artist_ids)
    GROUP BY
      credit.id
    HAVING
      sum(counts.plays) > 0
    ORDER BY
      plays DESC,
      credit.id
    LIMIT 5
)
SELECT
  artist.id,
  artist.name,
  artist.picture_url,
  ranked.plays,
  ranked.user_plays,
  ranked.partner_plays
FROM
  ranked
  JOIN public.artists AS artist ON artist.id = ranked.id
ORDER BY
  ranked.plays DESC,
  ranked.id;
END;
$$;

REVOKE
EXECUTE ON FUNCTION public.get_top_artists (public.top_listens_listener, integer)
FROM
  public,
  anon;

GRANT
EXECUTE ON FUNCTION public.get_top_artists (public.top_listens_listener, integer) TO authenticated;

CREATE FUNCTION public.get_top_genres (
  listener public.top_listens_listener DEFAULT 'combined',
  range_days integer DEFAULT NULL
) RETURNS TABLE (
  name text,
  plays bigint,
  user_plays bigint,
  partner_plays bigint
) LANGUAGE plpgsql SECURITY DEFINER
SET
  search_path = '' AS $$
BEGIN
  RETURN QUERY WITH ranked AS (
    SELECT
      credit.name AS id,
      sum(counts.plays)::bigint AS plays,
      sum(counts.user_plays)::bigint AS user_plays,
      sum(counts.partner_plays)::bigint AS partner_plays
    FROM
      private.get_track_play_counts (listener, range_days) AS counts
      JOIN public.tracks AS track ON track.id = counts.track_id
      CROSS JOIN LATERAL (
        -- A play counts once per genre even when it comes from multiple credited artists
        SELECT DISTINCT
          genre.name
        FROM
          public.artists AS artist
          CROSS JOIN LATERAL unnest(artist.genres) AS genre (name)
        WHERE
          artist.id = ANY (track.artist_ids)
          AND btrim(genre.name) <> '') AS credit
      GROUP BY
        credit.name
      HAVING
        sum(counts.plays) > 0
      ORDER BY
        plays DESC,
        credit.name
      LIMIT 5
)
  SELECT
    ranked.id,
    ranked.plays,
    ranked.user_plays,
    ranked.partner_plays
  FROM
    ranked
  ORDER BY
    ranked.plays DESC,
    ranked.id;
END;
$$;

REVOKE
EXECUTE ON FUNCTION public.get_top_genres (public.top_listens_listener, integer)
FROM
  public,
  anon;

GRANT
EXECUTE ON FUNCTION public.get_top_genres (public.top_listens_listener, integer) TO authenticated;
