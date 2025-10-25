CREATE FUNCTION private.save_tracks_details (
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
BEGIN
  -- Make the query planner think parallel is free, since the bounds are networking in this function, this is basically true
  SET max_parallel_workers_per_gather = 50;
  SET parallel_setup_cost = 0;
  SET parallel_tuple_cost = 0;
  -- Get the artist IDs from each album. We will do tracks below once we have the whole album
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
  -- This gives the highest chance of stuff happening in parallel. Otherwise, the query planner says no
  EXECUTE (
    SELECT
      'SELECT array_agg(value) FROM (' || string_agg('SELECT private.get_album_tracks(''' || album_id ||
	''', ' || private.header_to_text (authorization_header)
	|| ')', ' UNION ALL ') || ') response(value)'
    FROM (
      -- You need a subqyery here or else psql gets mad :(
      SELECT
        album ->> 'id' AS album_id
      FROM
        unnest(albums) AS album) album) INTO tracks;
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
        jsonb_array_elements(track -> 'artists') AS artist) all_artist_ids (artist_id));
  -- Spotify allows you to get artists in chunks of 50, so do that concurrently
  EXECUTE (
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
        (row_number - 1) / 50) batch) INTO artists;
  -- Insert the artists, we should only have distinct ones already since the above checks that
  INSERT INTO public.artists (id, picture_url, genres, name)
  SELECT
    artist ->> 'id',
    artist -> 'images' -> 0 ->> 'url',
    ARRAY (
      SELECT
        genre
      FROM
        jsonb_array_elements(artist -> 'genres') AS genre),
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

CREATE FUNCTION private.get_album_tracks (
  album_id text,
  authorization_header extensions.http_header
) RETURNS SETOF jsonb LANGUAGE plpgsql PARALLEL SAFE
SET
  search_path = '' AS $$
DECLARE
  next_url text;
  response_content jsonb;
  response_status integer;
BEGIN
  next_url := 'https://api.spotify.com/v1/albums/' || (album_id) || '/tracks?limit=50';
  -- Loop because it may take more than one page to get all tracks
  LOOP
    SELECT
      status,
      content::jsonb INTO response_status,
      response_content
    FROM
      extensions.http (('GET', next_url, ARRAY[authorization_header],
	'', '')::extensions.http_request);
    -- Validate response
    IF response_status != 200 THEN
      RAISE EXCEPTION 'InvalidAlbumsResponse'
	USING detail = 'HTTP Response code: ' || response_status || ' body: ' ||
	  response_content;
      END IF;

      RETURN QUERY
      SELECT
	track || jsonb_build_object('album',
	  jsonb_build_object('id', album_id))
      FROM
        jsonb_array_elements(response_content -> 'items') AS track;
      -- Check if another page and exit if no next page
      next_url := response_content ->> 'next';
      EXIT
      WHEN next_url IS NULL;
    END LOOP;
END;
$$;

CREATE FUNCTION private.get_artists_batch (
  artist_ids text[],
  authorization_header extensions.http_header
) RETURNS SETOF jsonb LANGUAGE plpgsql PARALLEL SAFE
SET
  search_path = '' AS $$
DECLARE
  response_content jsonb;
  response_status integer;
BEGIN
  SELECT
    status,
    content::jsonb INTO response_status,
    response_content
  FROM
    extensions.http (('GET', 'https://api.spotify.com/v1/artists?ids=' ||
      array_to_string(artist_ids, ','),
      ARRAY[authorization_header], '', '')::extensions.http_request);
  -- Validate response
  IF response_status != 200 THEN
    RAISE EXCEPTION 'InvalidArtistsResponse'
      USING detail = 'HTTP Response code: ' || response_status || ' body: ' ||
	response_content;
    END IF;
    -- Verify we got the correct number of artists in the end
    IF jsonb_array_length(response_content -> 'artists') !=
      ARRAY_LENGTH(artist_ids, 1) THEN
      RAISE EXCEPTION 'InvalidArtistsResponse'
	USING detail = ('Expected % artists, only got % from Spotify', ARRAY_LENGTH(artist_ids, 1),
	  jsonb_array_length(response_content -> 'artists'));
      END IF;

      RETURN QUERY
      SELECT
        artist
      FROM
        jsonb_array_elements(response_content -> 'artists') AS artist;
      -- Go back to normal settings
      SET max_parallel_workers_per_gather TO DEFAULT;
      SET parallel_setup_cost TO DEFAULT;
      SET parallel_tuple_cost TO DEFAULT;
END;
$$;
