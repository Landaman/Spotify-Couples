set check_function_bodies = off;

CREATE OR REPLACE FUNCTION private.user_needs_play_refresh(requesting_user_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
  RETURN NOT EXISTS (
    SELECT
      1
    FROM
      private.play_metadata
    WHERE
      user_id = requesting_user_id
      AND last_read_time + interval '15 minutes' >= NOW());
END;
$function$
;

DROP FUNCTION IF EXISTS private.get_new_plays_for_users(uuid[]);

CREATE OR REPLACE FUNCTION private.get_new_plays_for_users(requesting_user_ids uuid[])
 RETURNS SETOF uuid
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  user_data jsonb;
BEGIN
  IF array_length(requesting_user_ids, 1) = 0 THEN
    RETURN;
  END IF;
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
  -- If they're in the list it means they were successfully processed (even if that means nothing new), so return that set
  RETURN QUERY
  SELECT
    user_id::uuid
  FROM
    jsonb_object_keys(user_data) AS user_id;
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


set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.read_plays_for_user_if_needed()
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  IF NOT private.user_needs_play_refresh (auth.uid ()) THEN
    -- If no need to refresh, that means they recently refreshed successfully so they're good
    RETURN TRUE;
  END IF;
  -- Now try to refresh
  RETURN EXISTS (
    SELECT
      1
    FROM
      private.get_new_plays_for_users (ARRAY[auth.uid ()]) AS refreshed_users
    WHERE
      -- This happens when they refreshed successfully, so if they're not in the array, they didn't
      refreshed_users = auth.uid ());
END;
$function$
;

REVOKE
EXECUTE ON FUNCTION public.read_plays_for_user_if_needed
FROM
  public;

REVOKE
EXECUTE ON FUNCTION public.read_plays_for_user_if_needed
FROM
  anon;

drop function if exists public.process_spotify_refresh_token(text);

CREATE OR REPLACE FUNCTION public.process_spotify_refresh_token(refresh_token text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  secret_name text;
  secret_id uuid;
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
    -- Signal back to the client whether the user needs a refresh
    RETURN private.user_needs_play_refresh (auth.uid ());
END;
$function$
;


