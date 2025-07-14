set check_function_bodies = off;

CREATE OR REPLACE FUNCTION private.get_basic_credentials_header()
 RETURNS http_header
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
RETURN extensions.http_header ('Authorization', 'Basic ' || translate(
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
  ));
END;
$function$
;

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
$function$
;


