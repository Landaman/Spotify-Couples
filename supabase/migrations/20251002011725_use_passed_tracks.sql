drop function if exists "private"."save_tracks_details"(track_ids text[], authorization_header http_header);

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION private.save_tracks_details(base_tracks jsonb[], authorization_header http_header)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  tracks jsonb[] := ARRAY[]::jsonb[];
  artist_ids_chunk text[];
  artists_status integer;
  artists_response jsonb;
  artist_ids text[];
  loop_album jsonb;
  albums jsonb[];
  albums_status integer;
  albums_response jsonb;
  more_url text;
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
  -- Loop through all tracks, add their album to the list
  FOREACH loop_album IN ARRAY albums LOOP
    more_url := 'https://api.spotify.com/v1/albums/' || (loop_album ->> 'id') || '/tracks?limit=50';
    LOOP
      SELECT
        status,
        content::jsonb INTO albums_status,
        albums_response
      FROM
	extensions.http (('GET', more_url,
	  ARRAY[authorization_header], '', '')::extensions.http_request);

      IF albums_status != 200 THEN
        RAISE EXCEPTION 'InvalidAlbumsResponse'
          USING detail = 'HTTP Response code: ' || albums_status || ' body: ' || albums_response;
        END IF;

        tracks := tracks || (
          SELECT
	    array_agg(track || jsonb_build_object('album',
	      jsonb_build_object('id', loop_album ->>
	      'id')))
          FROM
            jsonb_array_elements(albums_response -> 'items') AS track);

        artist_ids := artist_ids || (
          SELECT
            array_agg(artist ->> 'id')
          FROM
            jsonb_array_elements(albums_response -> 'items') AS track,
            jsonb_array_elements(track -> 'artists') AS artist);

        more_url := albums_response ->> 'next';
        EXIT
        WHEN more_url IS NULL;
      END LOOP;
    END LOOP;
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
              jsonb_array_elements(album -> 'artists') AS artist)
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

CREATE OR REPLACE FUNCTION private.get_new_plays_for_user(requesting_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  access_token_header extensions.http_header;
  plays_response jsonb;
  plays_status integer;
  after_pointer text;
  search_parameters text := '?limit=50';
  user_refresh_token text;
BEGIN
  SELECT
    decrypted_secret INTO user_refresh_token
  FROM
    vault.decrypted_secrets
  WHERE
    name = requesting_user_id || '_spotify_code';
  -- Get an access token
  access_token_header = private.get_access_token_header (user_refresh_token);
  IF access_token_header IS NULL THEN
    RETURN;
    -- We can't just delete the token because then we'd end up with WAY too many keys lying around
  END IF;
  -- Attempt to get the after pointer
  SELECT
    spotify_after_pointer INTO after_pointer
  FROM
    private.play_metadata
  WHERE
    user_id = requesting_user_id;
  IF after_pointer IS NOT NULL THEN
    search_parameters = search_parameters || '&after=' || after_pointer;
    -- If we have an after pointer, we want to use it
  END IF;
  -- Query the recently played track for the user
  SELECT
    status,
    content::jsonb INTO plays_status,
    plays_response
  FROM
    extensions.http (('GET', 'https://api.spotify.com/v1/me/player/recently-played' || search_parameters,
      ARRAY[access_token_header], '', '')::extensions.http_request);
  -- Check that we got a valid response from Spotify, if not show that
  IF plays_response IS NULL OR plays_status != 200 THEN
    RAISE EXCEPTION 'InvalidRecentlyPlayedResponseException'
      USING detail = 'HTTP Response code: ' || plays_status || ' body: ' || plays_response;
    END IF;
    -- Determine what the next after pointer is
    IF plays_response -> 'cursors' ->> 'after' IS NOT NULL THEN
      -- Take what we have is necessary
      after_pointer = plays_response -> 'cursors' ->> 'after';
    ELSE
      -- Convert seconds to milliseconds, since PG spits out seconds
      after_pointer = round(date_part('epoch', now()) * 1000);
    END IF;
    -- Re-insert the spotify after pointer, or create it if we haven't seen it
    INSERT INTO private.play_metadata (user_id, spotify_after_pointer, last_read_time)
      VALUES (requesting_user_id, after_pointer, NOW())
    ON CONFLICT (user_id)
      DO UPDATE SET
        spotify_after_pointer = excluded.spotify_after_pointer,
        last_read_time = NOW();
    -- Load data for each track we haven't seen yet, in a batch
    PERFORM
      private.save_tracks_details ((
        SELECT
          array_agg(DISTINCT play -> 'track')
        FROM jsonb_array_elements(plays_response -> 'items') AS play
        WHERE
          NOT EXISTS (
            SELECT
              1
            FROM public.tracks
            WHERE
              id = (play -> 'track' ->> 'id'))), access_token_header);
    -- Insert each play
    INSERT INTO public.plays (user_id, played_date_time, track_id,
      spotify_played_context_uri)
    SELECT
      requesting_user_id,
      (play ->> 'played_at')::timestamptz,
      play -> 'track' ->> 'id',
      play -> 'context' ->> 'uri'
    FROM
      jsonb_array_elements(plays_response -> 'items') AS play;
END;
$function$
;


