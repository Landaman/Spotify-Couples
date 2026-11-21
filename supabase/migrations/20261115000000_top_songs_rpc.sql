DROP FUNCTION public.get_dashboard ();

CREATE TYPE public.top_songs_listener AS enum('combined', 'you', 'partner');

CREATE TYPE public.top_songs_artist AS (id text, name text);

CREATE TYPE public.top_songs_album AS (id text, name text, picture_url text);

CREATE TYPE public.top_songs_track AS (
  id text,
  name text,
  album public.top_songs_album,
  artists public.top_songs_artist[]
);

CREATE FUNCTION public.get_top_songs (
  listener public.top_songs_listener DEFAULT 'combined'
) RETURNS TABLE (
  track public.top_songs_track,
  plays bigint,
  user_plays bigint,
  partner_plays bigint
) LANGUAGE plpgsql SECURITY DEFINER
SET
  search_path = '' AS $$
DECLARE
  partner_id uuid := private.get_partner_id ();
BEGIN
  IF partner_id IS NULL THEN
    RAISE EXCEPTION 'NoPartnerException';
  END IF;

  IF listener IS NULL THEN
    RAISE EXCEPTION 'InvalidListenerException';
  END IF;

  RETURN QUERY WITH track_counts AS (
    SELECT
      plays.track_id,
      count(*) FILTER (WHERE plays.user_id = auth.uid ()) AS user_plays,
      count(*) FILTER (WHERE plays.user_id = partner_id) AS partner_plays
    FROM
      public.plays AS plays
    WHERE
      plays.user_id IN (auth.uid (), partner_id)
    GROUP BY
      plays.track_id
),
ranked_tracks AS (
  SELECT
    track_counts.*,
    CASE listener
    WHEN 'you' THEN
      track_counts.user_plays
    WHEN 'partner' THEN
      track_counts.partner_plays
    ELSE
      track_counts.user_plays + track_counts.partner_plays
    END AS ranking_plays
  FROM
    track_counts
),
top_tracks AS (
  SELECT
    ranked_tracks.*
  FROM
    ranked_tracks
  WHERE
    ranked_tracks.ranking_plays > 0
  ORDER BY
    ranked_tracks.ranking_plays DESC,
    ranked_tracks.track_id
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
        WITH ORDINALITY AS track_artists (id, ORDINALITY)
        JOIN public.artists AS artists ON artists.id = track_artists.id
      ORDER BY
        track_artists.ordinality))::public.top_songs_track,
  top_tracks.ranking_plays,
  top_tracks.user_plays,
  top_tracks.partner_plays
FROM
  top_tracks
  INNER JOIN public.tracks AS tracks ON tracks.id = top_tracks.track_id
  INNER JOIN public.albums AS albums ON albums.id = tracks.album_id
ORDER BY
  top_tracks.ranking_plays DESC,
  top_tracks.track_id;
END;
$$;

REVOKE
EXECUTE ON FUNCTION public.get_top_songs (public.top_songs_listener)
FROM
  public;

REVOKE
EXECUTE ON FUNCTION public.get_top_songs (public.top_songs_listener)
FROM
  anon;

GRANT
EXECUTE ON FUNCTION public.get_top_songs (public.top_songs_listener) TO authenticated;
