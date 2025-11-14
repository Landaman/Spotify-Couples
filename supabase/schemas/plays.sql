CREATE TABLE public.plays (
  id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  played_date_time timestamp with time zone NOT NULL,
  spotify_played_context_uri text,
  track_id text NOT NULL REFERENCES public.tracks (id) ON UPDATE CASCADE ON DELETE RESTRICT,
  user_id uuid NOT NULL REFERENCES auth.users (id) ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE INDEX plays_user_id_idx ON public.plays (user_id);

ALTER TABLE public.plays ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable users to view their own and their partners plays" ON public.plays FOR
SELECT
  USING (
    (
      (
        (
          SELECT
            auth.uid ()
        ) = user_id
      )
      OR (
        (
          SELECT
            public.get_partner_id ()
        ) = user_id
      )
    )
  );

CREATE TABLE private.play_metadata (
  user_id uuid NOT NULL PRIMARY KEY REFERENCES auth.users (id) ON UPDATE CASCADE ON DELETE CASCADE,
  spotify_after_pointer text NOT NULL,
  last_read_time timestamptz NOT NULL
);

CREATE FUNCTION private.get_new_plays_for_user_jsonb (requesting_user_id uuid) RETURNS jsonb LANGUAGE plpgsql PARALLEL SAFE
SET
  search_path = '' AS $$
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
$$;

CREATE FUNCTION private.get_new_plays_for_users (requesting_user_ids uuid[]) RETURNS SETOF uuid LANGUAGE plpgsql
SET
  search_path = '' AS $$
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
$$;

CREATE FUNCTION private.read_plays_for_all_users () RETURNS void LANGUAGE plpgsql
SET
  search_path = '' AS $$
BEGIN
  PERFORM
    private.get_new_plays_for_users ((
      SELECT
        array_agg(id)
      FROM auth.users));
END;
$$;

CREATE FUNCTION private.user_needs_play_refresh (requesting_user_id uuid) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER
SET
  search_path = '' AS $$
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
$$;

CREATE FUNCTION public.user_needs_play_refresh () RETURNS boolean LANGUAGE plpgsql
SET
  search_path = '' AS $$
BEGIN
  RETURN private.user_needs_play_refresh (auth.uid ());
END;
$$;

-- HACK: this doesn't do anything here. It is shown for clarity.
-- to edit this, manually create a migration
REVOKE
EXECUTE ON FUNCTION public.user_needs_play_refresh
FROM
  public;

REVOKE
EXECUTE ON FUNCTION public.user_needs_play_refresh
FROM
  anon;

CREATE FUNCTION public.read_plays_for_user_if_needed () RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER
SET
  search_path = '' AS $$
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
$$;

-- HACK: this doesn't do anything here. It is shown for clarity.
-- to edit this, manually create a migration
REVOKE
EXECUTE ON FUNCTION public.read_plays_for_user_if_needed
FROM
  public;

REVOKE
EXECUTE ON FUNCTION public.read_plays_for_user_if_needed
FROM
  anon;

-- HACK: This doesn't actually do anything, this needs to be edited manually as a part of a migration
SELECT
  cron.schedule (
    'Read plays every 15 minutes',
    '*/15 * * * *',
    'SELECT private.read_plays_for_all_users()'
  );
