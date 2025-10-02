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

CREATE FUNCTION private.get_new_plays_for_user (requesting_user_id uuid) RETURNS void LANGUAGE plpgsql
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
          array_agg(DISTINCT play -> 'track' ->> 'id')
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
$$;

CREATE FUNCTION private.read_plays_for_all_users () RETURNS void LANGUAGE plpgsql
SET
  search_path = '' AS $$
DECLARE
  user_id uuid;
BEGIN
  FOR user_id IN
  SELECT
    id
  FROM
    auth.users LOOP
      -- This implicitly creates a subtransaction, so others can succeed when this fails
      BEGIN
        PERFORM
          private.get_new_plays_for_user (user_id);
      EXCEPTION
        WHEN OTHERS THEN
          RAISE NOTICE 'Failed to process user %: %', user_id, SQLERRM;
          -- This makes sure the errors comes up in the supabase logs
      END;
  END LOOP;
END;

$$;

-- HACK: This doesn't actually do anything, this needs to be edited manually as a part of a migration
SELECT
  cron.schedule (
    'Read plays every 15 minutes',
    '*/15 * * * *',
    'SELECT private.read_plays_for_all_users()'
  );
