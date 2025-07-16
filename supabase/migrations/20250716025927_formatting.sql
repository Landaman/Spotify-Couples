alter table "private"."play_metadata" alter column "last_read_time" drop default;

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION private.check_user_has_one_pairing()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  IF EXISTS (
    SELECT
      1
    FROM
      public.pairings
    WHERE
      one_uuid = NEW.one_uuid
      OR one_uuid = NEW.two_uuid) THEN
  RAISE EXCEPTION 'UUID % already has a pairing', NEW.one_uuid;
END IF;

  IF EXISTS (
    SELECT
      1
    FROM
      public.pairings
    WHERE
      two_uuid = NEW.one_uuid
      OR two_uuid = NEW.two_uuid) THEN
  RAISE EXCEPTION 'UUID % already has a pairing', NEW.one_uuid;
END IF;

  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION private.cleanup_pairing_codes()
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
  DELETE FROM public.pairing_codes
  WHERE expires_at <= NOW();
END;
$function$
;

CREATE OR REPLACE FUNCTION private.get_basic_credentials_header()
 RETURNS http_header
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
  RETURN extensions.http_header ('Authorization', 'Basic ' || translate(encode(((
        SELECT
          decrypted_secret
        FROM vault.decrypted_secrets
        WHERE
          name = 'SPOTIFY_CLIENT_ID') || ':' || (
        SELECT
          decrypted_secret
        FROM vault.decrypted_secrets
        WHERE
          name = 'SPOTIFY_CLIENT_SECRET'))::bytea, 'base64'), E'\n', ''));
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
  play jsonb;
  -- Required otherwise psql doesn't know the type below
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
    -- Now loop through play responses
    FOR play IN (
      SELECT
        *
      FROM
        -- Required, since what is passed into a for needs to be a set
        jsonb_array_elements(plays_response -> 'items'))
      LOOP
        -- Insert a play for each one
	INSERT INTO public.plays (user_id, played_date_time, spotify_id,
	  spotify_played_context_uri)
	  VALUES (requesting_user_id, (play ->> 'played_at')::timestamptz,
	    play -> 'track' ->> 'id', play ->
	    'context' ->> 'uri');
      END LOOP;
END;
$function$
;

CREATE OR REPLACE FUNCTION private.read_plays_for_all_users()
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
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

$function$
;


set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.get_or_create_pairing_code()
 RETURNS pairing_codes
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  result pairing_codes;
  done bool := FALSE;
BEGIN
  IF (
    SELECT
      public.get_partner_id ()) IS NOT NULL THEN
    RAISE EXCEPTION 'HasPartnerException'
      USING DETAIL = 'Unable to get a pairing code for a user that already has a partner';
    END IF;
    SELECT
      * INTO result
    FROM
      pairing_codes
    WHERE
      owner_id = auth.uid ();
    IF NOT FOUND OR result.expires_at < now() THEN
      DELETE FROM pairing_codes
      WHERE owner_id = auth.uid ();
      WHILE NOT done LOOP
        result.code := UPPER(SUBSTRING(MD5('' || now()::text || random()::text), 1, 6));
        done := NOT EXISTS (
          SELECT
            1
          FROM
            pairing_codes
          WHERE
            code = result.code);
      END LOOP;
      INSERT INTO pairing_codes (owner_id, code, expires_at)
        VALUES (auth.uid (), result.code, now() + interval '15 minutes')
      RETURNING
        * INTO result;
    END IF;
    RETURN result;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_partner_id()
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
  RETURN public.get_partner_id (auth.uid ());
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_partner_id(search_uuid uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN (
    SELECT
      one_uuid
    FROM
      pairings
    WHERE
      search_uuid = two_uuid
    UNION
    SELECT
      two_uuid
    FROM
      pairings
    WHERE
      one_uuid = search_uuid);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_partner_profile()
 RETURNS profile
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  result public.profile;
BEGIN
  SELECT
    id,
    raw_user_meta_data ->> 'name',
    raw_user_meta_data ->> 'provider_id',
    raw_user_meta_data ->> 'picture' INTO result
  FROM
    auth.users
  WHERE
    id = public.get_partner_id ();

  RETURN result;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.pair_with_code(pairing_code character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  code_expiry timestamptz;
  code_owner_id uuid;
BEGIN
  IF (
    SELECT
      public.get_partner_id ()) IS NOT NULL THEN
    RAISE EXCEPTION 'HasPartnerException'
      USING DETAIL = 'Unable to pair with a code when the user already has a partner';
    END IF;

    SELECT
      owner_id,
      expires_at INTO code_owner_id,
      code_expiry
    FROM
      pairing_codes
    WHERE
      code = pairing_code;
    -- This handles the case where the code DNE and the auth.uid() does due to the role restrictions below
    IF code_owner_id = auth.uid () THEN
      RAISE EXCEPTION 'InvalidPairingCodeException'
        USING DETAIL = 'Unable to pair with a code the user owns';
      END IF;

      IF NOT FOUND OR code_expiry < NOW() THEN
        RAISE EXCEPTION 'InvalidPairingCodeException'
          USING DETAIL = 'Unable to pair with a pairing code that does not exist or is expired';
        END IF;

        IF (
          SELECT
            public.get_partner_id (code_owner_id)) IS NOT NULL THEN
          RAISE EXCEPTION 'InvalidPairingCodeException'
            USING DETAIL = 'Unable to pair with a pairing code that does not exist or is expired';
          END IF;

          INSERT INTO public.pairings (one_uuid, two_uuid)
            VALUES (auth.uid (), code_owner_id);

          PERFORM
	    realtime.send (jsonb_build_object(), 'paired',
	      'pairing_codes:' || pairing_code, TRUE);
          -- this means private, i.e., RLS required for access
          DELETE FROM pairing_codes
          WHERE code = pairing_code;
END;
$function$
;


