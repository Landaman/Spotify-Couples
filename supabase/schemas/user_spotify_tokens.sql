CREATE FUNCTION public.process_spotify_refresh_token (refresh_token text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET
  search_path = '' AS $$
DECLARE
    secret_name text;
    secret_id uuid;
BEGIN
    -- Before we insert into the vault, ensure the token is valid
    IF private.refresh_access_token (refresh_token) IS NULL THEN
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

CREATE FUNCTION private.refresh_access_token (refresh_token character varying) RETURNS character varying LANGUAGE plpgsql
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
        extensions.http (('POST', 'https://accounts.spotify.com/api/token?grant_type=refresh_token&refresh_token=' || refresh_token, array[
        private.get_basic_credentials_header (),
        extensions.http_header ('Accept', 'application/json')
      ],
      'application/x-www-form-urlencoded',
      '')::extensions.http_request);
    IF return_status != 200 THEN
        RETURN NULL;
    END IF;
    RETURN access_token;
END;
$$;
