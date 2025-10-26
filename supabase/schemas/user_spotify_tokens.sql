CREATE FUNCTION public.process_spotify_refresh_token (refresh_token text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET
  search_path = '' AS $$
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
$$;

-- HACK: this doesn't do anything here. It is shown for clarity.
-- to edit this, manually create a migration
REVOKE
EXECUTE ON FUNCTION public.process_spotify_refresh_token
FROM
  public;

REVOKE
EXECUTE ON FUNCTION public.process_spotify_refresh_token
FROM
  anon;

CREATE FUNCTION private.get_access_token_header (refresh_token character varying) RETURNS extensions.http_header LANGUAGE plpgsql
SET
  search_path = '' AS $$
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
$$;
