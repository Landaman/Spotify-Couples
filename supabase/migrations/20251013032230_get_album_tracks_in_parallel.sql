set check_function_bodies = off;

CREATE OR REPLACE FUNCTION private.save_tracks_details(base_tracks jsonb[], authorization_header http_header)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  tracks jsonb[] := ARRAY[]::jsonb[];
  albums_to_process jsonb;
  artist_ids_chunk text[];
  artists_status integer;
  artists_response jsonb;
  artist_ids text[];
  albums jsonb[];
  albums_error_status integer;
  albums_error_content text;
BEGIN
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
  -- Albums we will process in batches
  albums_to_process := (
    SELECT
      jsonb_object_agg('https://api.spotify.com/v1/albums/' || (album ->> 'id') ||
	'/tracks?limit=50', album ->> 'id')
    FROM
      unnest(albums) AS album);
  LOOP
    WITH album_responses AS (
      SELECT
	extensions.http (('GET', album.key,
	  ARRAY[authorization_header], '', '')::extensions.http_request) AS
	  http_response,
        album.value AS album_id
      FROM
        jsonb_each(albums_to_process) AS album
),
first_failed_info AS (
  SELECT
    (album_responses.http_response).status AS failed_status,
    (album_responses.http_response).content AS failed_response
  FROM
    album_responses
  WHERE (album_responses.http_response).status != 200
LIMIT 1
),
new_info AS (
  SELECT
    array_agg(track || jsonb_build_object('album',
      jsonb_build_object('id', album_id))) AS new_tracks,
  array_agg(artist ->> 'id') AS new_artist_ids,
  jsonb_object_agg(((album_responses.http_response).content::jsonb ->>
    'next'), album_id) FILTER (WHERE
    ((album_responses.http_response).content::jsonb ->> 'next') IS NOT
    NULL) AS new_albums_to_process
FROM
  album_responses,
  jsonb_array_elements(((album_responses.http_response).content::jsonb) ->
    'items') AS track,
  jsonb_array_elements(track -> 'artists') AS artist
  WHERE (album_responses.http_response).status = 200
)
SELECT
  tracks || new_tracks,
  artist_ids || new_artist_ids,
  new_albums_to_process,
  failed_status,
  failed_response INTO tracks,
  artist_ids,
  albums_to_process,
  albums_error_status,
  albums_error_content
FROM
  new_info
  LEFT JOIN first_failed_info ON TRUE;
  -- Quit if any albums failed to process
  IF albums_error_status IS NOT NULL THEN
    RAISE EXCEPTION 'InvalidAlbumsResponse'
      USING detail = 'HTTP Response code: ' || albums_error_status || ' body: '
	|| albums_error_content;
    END IF;

    EXIT
    WHEN albums_to_process IS NULL;
  END LOOP;
  -- Filter artist IDs down to only the distinct, new set before we do the chunked requests
  artist_ids := (
    SELECT
      array_agg(DISTINCT artist_id)
    FROM
      unnest(artist_ids) AS artist_id
    WHERE
      NOT EXISTS (
        SELECT
          1
        FROM
          public.artists
        WHERE
          id = artist_id));
  -- Spotify allows you to get artists in chunks of 50, so do that
  FOR artist_chunk IN 1..ceil(array_length(artist_ids, 1) / 50)
  LOOP
    artist_ids_chunk := artist_ids[((artist_chunk - 1) * 50 + 1) : (artist_chunk * 50)];
    SELECT
      status,
      content::jsonb INTO artists_status,
      artists_response
    FROM
      extensions.http (('GET', 'https://api.spotify.com/v1/artists?ids=' ||
	array_to_string(artist_ids_chunk, ','),
	ARRAY[authorization_header], '', '')::extensions.http_request);

    IF artists_status != 200 THEN
      RAISE EXCEPTION 'InvalidArtistsResponse'
        USING detail = 'HTTP Response code: ' || artists_status || ' body: ' || artists_response;
      END IF;
      -- Double check to make sure we have the right length
      IF jsonb_array_length(artists_response -> 'artists') !=
	ARRAY_LENGTH(artist_ids_chunk, 1) THEN
        RAISE EXCEPTION 'InvalidArtistsResponse'
	  USING detail = ('Expected % artists, only got % from Spotify', ARRAY_LENGTH(artist_ids_chunk, 1),
	    jsonb_array_length(artists_response -> 'artists'));
        END IF;
        -- Insert all artists from this response group
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
          jsonb_array_elements(artists_response -> 'artists') AS artist;
      END LOOP;
      -- Insert unique albums
      INSERT INTO public.albums (id, album_type, picture_url, name,
	release_date, release_date_precision, artist_ids)
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
            jsonb_array_elements(artists_response -> 'artists') AS artist)
      FROM
        unnest(albums) AS album;
      -- Finally, insert the tracks
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
$function$
;


