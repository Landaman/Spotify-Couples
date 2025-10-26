drop function if exists "private"."get_new_plays_for_user"(requesting_user_id uuid);

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION private.get_new_plays_for_user_jsonb(requesting_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 PARALLEL SAFE
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
    RETURN NULL;
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
  -- Check that we got a valid response from Spotify, if not show that. Don't fail because that would mean that every user fails in the caller
  IF plays_response IS NULL OR plays_status != 200 THEN
    RAISE WARNING 'InvalidRecentlyPlayedResponseException'
    USING detail = 'HTTP Response code: ' || plays_status || ' body: ' || plays_response;
    RETURN NULL;
  END IF;
    -- Build + return a reasonable response
    RETURN jsonb_build_object(requesting_user_id::text, plays_response);
END;
$function$
;

CREATE OR REPLACE FUNCTION private.get_new_plays_for_users(requesting_user_ids uuid[])
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  user_data jsonb;
BEGIN
  PERFORM
    private.set_http_parallel_hints ();
  -- Get all user data in parallel. Using union all is the most reliable way to convince the query planner that parallel is a good idea
  EXECUTE (
    SELECT
      'SELECT jsonb_object_agg(key, value) FROM (' || string_agg('SELECT private.get_new_plays_for_user_jsonb(''' || user_id ||
	''')', ' UNION ALL ') || ') response(jsonb_object) CROSS JOIN LATERAL jsonb_each(jsonb_object) AS data (key, value)'
    FROM
      unnest(requesting_user_ids) AS user_id) INTO user_data;
  PERFORM
    private.unset_http_parallel_hints ();
  IF user_data IS NULL THEN
    -- This would happen if no users can get any data in
    RETURN;
  END IF;
  -- Re-insert the spotify after pointer, or create it if we haven't seen it
  INSERT INTO private.play_metadata (user_id, spotify_after_pointer, last_read_time)
  SELECT
    key::uuid,
    -- Determine what the next after pointer is
    CASE WHEN (value -> key ->> 'after_pointer') IS NOT NULL THEN
      -- Take what we have is necessary
      (value -> key ->> 'after_pointer')
    ELSE
      -- Convert seconds to milliseconds, since PG spits out seconds
      round(date_part('epoch', now()) * 1000)::text
    END,
    now()
  FROM
    jsonb_each(user_data) AS data (key,
    value)
ON CONFLICT (user_id)
  DO UPDATE SET
    spotify_after_pointer = excluded.spotify_after_pointer,
    last_read_time = NOW();
  -- Load data for each track we haven't seen yet, in a batch
  PERFORM
    private.save_tracks_details ((
      SELECT
        array_agg(DISTINCT play -> 'track')
      FROM jsonb_each(user_data) AS data (key, value),
	jsonb_array_elements(value -> 'items') AS play
      WHERE
        NOT EXISTS (
          SELECT
            1
          FROM public.tracks
          WHERE
	    id = (play -> 'track' ->> 'id'))),
	      private.get_client_credentials_header ());
  -- Insert each play
  INSERT INTO public.plays (user_id, played_date_time, track_id,
    spotify_played_context_uri)
  SELECT
    key::uuid,
    (play ->> 'played_at')::timestamptz,
    play -> 'track' ->> 'id',
    play -> 'context' ->> 'uri'
  FROM
    jsonb_each(user_data) AS data (key,
    value),
  jsonb_array_elements(value -> 'items') AS play;
END;
$function$
;

CREATE OR REPLACE FUNCTION private.set_http_parallel_hints()
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
  -- Make the query planner think parallel is free, since the bounds are networking in this function, this is basically true
  -- Local rolls it back after the transaction regardless of the outcome
  SET LOCAL max_parallel_workers_per_gather = 50;
  SET LOCAL parallel_setup_cost = 0;
  SET LOCAL parallel_tuple_cost = 0;
END;
$function$
;

CREATE OR REPLACE FUNCTION private.unset_http_parallel_hints()
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
  -- Reset to default values
  -- Local rolls it back after the transaction regardless of the outcome
  SET LOCAL max_parallel_workers_per_gather TO DEFAULT;
  SET LOCAL parallel_setup_cost TO DEFAULT;
  SET LOCAL parallel_tuple_cost TO DEFAULT;
END;
$function$
;

CREATE OR REPLACE FUNCTION private.get_artists_batch(artist_ids text[], authorization_header http_header)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 PARALLEL SAFE
 SET search_path TO ''
AS $function$
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
END;
$function$
;

CREATE OR REPLACE FUNCTION private.read_plays_for_all_users()
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
  PERFORM
    private.get_new_plays_for_users ((
      SELECT
        array_agg(id)
      FROM auth.users));
END;

$function$
;

CREATE OR REPLACE FUNCTION private.save_tracks_details(base_tracks jsonb[], authorization_header http_header)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
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
        jsonb_array_elements(track -> 'artists') AS artist) all_artist_ids (artist_id));
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
$function$
;


set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.process_spotify_refresh_token(refresh_token text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  secret_name text;
  secret_id uuid;
  users_last_read_time timestamptz;
BEGIN
  -- Before we insert into the vault, ensure the token is valid
  IF private.get_access_token_header (refresh_token) IS NULL THEN
    RAISE EXCEPTION 'InvalidRefreshTokenException'
      USING detail = 'The provided refresh token is invalid';
    END IF;

    secret_name := (
      SELECT
        auth.uid ()) || '_spotify_code';
    -- We need the ID if we're going to update
    SELECT
      id INTO secret_id
    FROM
      vault.secrets
    WHERE
      name = secret_name;
    -- Update or create the secret as necessary
    IF NOT FOUND THEN
      PERFORM
        vault.create_secret (refresh_token, secret_name);
    ELSE
      PERFORM
        vault.update_secret (secret_id, refresh_token, secret_name);
    END IF;

    SELECT
      last_read_time INTO users_last_read_time
    FROM
      private.play_metadata
    WHERE
      user_id = auth.uid ();

    IF NOT FOUND OR users_last_read_time + interval '15 minutes' < NOW() THEN
      PERFORM
        private.get_new_plays_for_users (ARRAY[auth.uid ()]);
    END IF;
END;
$function$
;


