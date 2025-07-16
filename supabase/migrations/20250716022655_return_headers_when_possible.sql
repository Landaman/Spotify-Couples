drop function if exists "private"."get_client_credentials_access_token"();

drop function if exists "private"."refresh_access_token"(refresh_token character varying);

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION private.get_access_token_header(refresh_token character varying)
 RETURNS http_header
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  return_status int;
  access_token character varying;
BEGIN
  SELECT
    "status",
    "content"::jsonb ->> 'access_token' INTO return_status,
    access_token
  FROM
    extensions.http (('POST', 'https://accounts.spotify.com/api/token?grant_type=refresh_token&refresh_token=' || refresh_token,
      ARRAY[private.get_basic_credentials_header (), extensions.http_header
      ('Accept', 'application/json')], 'application/x-www-form-urlencoded',
      '')::extensions.http_request);
  IF return_status != 200 THEN
    RETURN NULL;
  END IF;
  RETURN extensions.http_header ('Authorization', 'Bearer ' || access_token);
END;
$function$
;

CREATE OR REPLACE FUNCTION private.get_client_credentials_header()
 RETURNS http_header
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  return_status int;
  access_token character varying;
BEGIN
  SELECT
    "status",
    "content"::jsonb ->> 'access_token' INTO return_status,
    access_token
  FROM
    extensions.http (('POST', 'https://accounts.spotify.com/api/token?grant_type=client_credentials',
      ARRAY[private.get_basic_credentials_header (), extensions.http_header
      ('Accept', 'application/json')], 'application/x-www-form-urlencoded',
      '')::extensions.http_request);
  IF return_status != 200 THEN
    RAISE EXCEPTION 'InvalidClientCredentials'
      USING DETAIL = 'The provided client credentials are invalid or missing';
    END IF;
    RETURN extensions.http_header ('Authorization', 'Bearer ' || access_token);
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
    play jsonb; -- Required otherwise psql doesn't know the type below
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
        extensions.http (('GET', 'https://api.spotify.com/v1/me/player/recently-played' || search_parameters, ARRAY[access_token_header], '', '')::extensions.http_request);

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
        INSERT INTO private.play_metadata (user_id, spotify_after_pointer)
            VALUES (requesting_user_id, after_pointer)
        ON CONFLICT (user_id)
            DO UPDATE SET
                spotify_after_pointer = excluded.spotify_after_pointer;
        -- Now loop through play responses
        FOR play IN (
            SELECT
                *
            FROM
                -- Required, since what is passed into a for needs to be a set
                jsonb_array_elements(plays_response -> 'items'))
            LOOP
                -- Insert a play for each one
                INSERT INTO public.plays (user_id, played_date_time, spotify_id, spotify_played_context_uri)
                    VALUES (requesting_user_id, (play ->> 'played_at')::timestamptz, play -> 'track' ->> 'id', play -> 'context' ->> 'uri');
            END LOOP;
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
END;
$function$
;


