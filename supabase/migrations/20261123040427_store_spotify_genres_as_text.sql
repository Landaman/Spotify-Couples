CREATE OR REPLACE FUNCTION private.save_tracks_details (
  base_tracks jsonb[],
  authorization_header extensions.http_header
) RETURNS void LANGUAGE plpgsql
SET
  search_path = '' AS $$
DECLARE
  tracks jsonb[] := ARRAY[]::jsonb[];
  albums jsonb[];
  artists jsonb[] := ARRAY[]::jsonb[];
  artist_ids text[];
  album_tracks_dynamic_sql text;
  artist_ids_dynamic_sql text;
BEGIN
  -- Otherwise we will throw a big unhappy null when we go to exec below
  IF base_tracks IS NULL OR array_length(base_tracks, 1) = 0 THEN
    RETURN;
  END IF;
  -- Get the artist IDs from each album. We will do tracks below once we have the whole album, along with filtering out existing ones
  artist_ids := (
    SELECT
      array_agg(artist ->> 'id')
    FROM
      unnest(base_tracks) AS track,
      jsonb_array_elements(track -> 'album' -> 'artists') AS artist);
  -- Get album IDs to query spotify for all the songs in all the albums
  albums := (
    SELECT
      array_agg(DISTINCT track -> 'album')
    FROM
      unnest(base_tracks) AS track
    WHERE
      NOT EXISTS (
        SELECT
          1
        FROM
          public.albums
        WHERE
          id = (track -> 'album' ->> 'id')));
  album_tracks_dynamic_sql := (
    SELECT
      'SELECT array_agg(value) FROM (' || string_agg('SELECT private.get_album_tracks(''' || album_id ||
	''', ' || private.header_to_text (authorization_header)
	|| ')', ' UNION ALL ') || ') response(value)'
    FROM (
      -- You need a subqyery here or else psql gets mad :(
      SELECT
        album ->> 'id' AS album_id
      FROM
        unnest(albums) AS album) album);
  -- Only run the dynamic sql if there's actually something to do, since execute '' is illegal
  IF album_tracks_dynamic_sql != '' THEN
    PERFORM
      private.set_http_parallel_hints ();
    EXECUTE album_tracks_dynamic_sql INTO tracks;
    PERFORM
      private.unset_http_parallel_hints ();
  END IF;
  -- All artist IDs, distinct set before we chunk and query
  artist_ids := (
    SELECT
      array_agg(DISTINCT artist_id)
    FROM (
      SELECT
        unnest(artist_ids) AS artist_id
      UNION ALL
      SELECT
        artist ->> 'id'
      FROM
        unnest(tracks) AS track,
        jsonb_array_elements(track -> 'artists') AS artist) all_artist_ids (artist_id)
    WHERE
      NOT EXISTS (
        SELECT
          1
        FROM
          public.artists
        WHERE
          id = artist_id));
  artist_ids_dynamic_sql := (
    SELECT
      'SELECT array_agg(value) FROM (' || string_agg('SELECT private.get_artists_batch(''' || batch::text ||
	''', ' || private.header_to_text
	(authorization_header) || ')', ' UNION ALL ') ||
	') response(value)'
    FROM (
      SELECT
        array_agg(artist_id) AS batch
      FROM (
        SELECT
          artist_id,
          row_number() OVER () AS row_number
        FROM
          unnest(artist_ids) AS artist_id) id_with_info (artist_id, row_number)
      GROUP BY
        (row_number - 1) / 50) batch);
  -- Only run the dynamic sql if there's actually something to do, since execute '' is illegal
  IF artist_ids_dynamic_sql != '' THEN
    PERFORM
      private.set_http_parallel_hints ();
    -- Spotify allows you to get artists in chunks of 50, so do that concurrently
    EXECUTE artist_ids_dynamic_sql INTO artists;
    PERFORM
      private.unset_http_parallel_hints ();
  END IF;
  -- Insert the artists, we should only have distinct ones already since the above checks that
  INSERT INTO public.artists (id, picture_url, genres, name)
  SELECT
    artist ->> 'id',
    artist -> 'images' -> 0 ->> 'url',
    ARRAY (
      SELECT
        genre
      FROM
        jsonb_array_elements_text(artist -> 'genres') AS genre),
    artist ->> 'name'
  FROM
    unnest(artists) AS artist;
  -- Insert unique albums
  INSERT INTO public.albums (id, album_type, picture_url, name, release_date,
    release_date_precision, artist_ids)
  SELECT
    album ->> 'id',
    (album ->> 'album_type')::public.album_type,
    album -> 'images' -> 0 ->> 'url',
    album ->> 'name',
    -- Date precision is automatically handled
    TO_DATE(album ->> 'release_date', 'YYYY-MM-DD'),
    (album ->> 'release_date_precision')::public.album_release_date_precision,
    (
      SELECT
        ARRAY_AGG(artist ->> 'id')
      FROM
        jsonb_array_elements(album -> 'artists') AS artist)
  FROM
    unnest(albums) AS album;
  -- Finally, insert the tracks. We need a distinct check here since they come in as an array already
  INSERT INTO public.tracks (id, explicit, duration_ms, disc_number,
    track_number, name, artist_ids, album_id)
  SELECT DISTINCT
    track ->> 'id',
    (track ->> 'explicit')::boolean,
    (track ->> 'duration_ms')::integer,
    (track ->> 'disc_number')::integer,
    (track ->> 'track_number')::integer,
    track ->> 'name',
    (
      SELECT
        ARRAY_AGG(artist ->> 'id')
      FROM
        jsonb_array_elements(track -> 'artists') AS artist),
    track -> 'album' ->> 'id'
  FROM
    unnest(tracks) AS track;
END;
$$;

-- Decode one layer of JSON serialization while preserving genre order
WITH normalized AS (
  SELECT
    id,
    ARRAY (
      SELECT
        CASE
          WHEN genre NOT LIKE '"%"' OR NOT pg_input_is_valid(genre, 'jsonb') THEN genre
          WHEN genre = (genre::jsonb)::text THEN genre::jsonb #>> '{}'
          ELSE genre
        END
      FROM
        unnest(genres) WITH ORDINALITY AS tag (genre, position)
      ORDER BY
        position) AS genres
  FROM
    public.artists
)
UPDATE public.artists AS artist
SET
  genres = normalized.genres
FROM
  normalized
WHERE
  artist.id = normalized.id
  AND artist.genres IS DISTINCT FROM normalized.genres;
