set check_function_bodies = off;

CREATE OR REPLACE FUNCTION private.refresh_access_token(refresh_token character varying)
 RETURNS character varying
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
        extensions.http (('POST', 'https://accounts.spotify.com/api/token?grant_type=refresh_token&refresh_token=' || refresh_token, array[
        extensions.http_header (
          'Authorization',
          'Basic ' || translate(
            encode(
              (
                (
                  select
                    decrypted_secret
                  from
                    vault.decrypted_secrets
                  where
                    name = 'SPOTIFY_CLIENT_ID'
                ) || ':' || (
                  select
                    decrypted_secret
                  from
                    vault.decrypted_secrets
                  where
                    name = 'SPOTIFY_CLIENT_SECRET'
                )
              )::bytea,
              'base64'
            ),
            E'\n',
            ''
          )
        ),
        extensions.http_header ('Accept', 'application/json')
      ],
      'application/x-www-form-urlencoded',
      '')::extensions.http_request);
    IF return_status != 200 THEN
        RETURN NULL;
    END IF;
    RETURN access_token;
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
$function$
;


