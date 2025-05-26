SET check_function_bodies = OFF;

CREATE OR REPLACE FUNCTION private.refresh_access_token (refresh_token character varying)
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
        extensions.http (('POST', 'https://accounts.spotify.com/api/token?grant_type=refresh_token&refresh_token=' || refresh_token, ARRAY[extensions.http_header ('Authoriztion', 'Basic ' || encode(((
                    SELECT
                        decrypted_secret
                    FROM vault.decrypted_secrets
                    WHERE
                        name = 'SPOTIFY_CLIENT_ID') || ':' || (
                    SELECT
                        decrypted_secret
                    FROM vault.decrypted_secrets
                    WHERE
                        name = 'SPOTIFY_CLIENT_SECRET'))::bytea, 'base64'))], 'application/x-www-form-urlencoded', NULL)::extensions.http_request);
    IF return_status != 200 THEN
        RETURN NULL;
    END IF;
    RETURN access_token;
END;
$function$;

SET check_function_bodies = OFF;

CREATE OR REPLACE FUNCTION public.process_spotify_refresh_token (refresh_token text)
    RETURNS void
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO ''
    AS $function$
DECLARE
    secret_name text;
BEGIN
    secret_name := (
        SELECT
            auth.uid ()) || '_spotify_code';
    -- This ensures the token is updated, since the processor should
    -- clear this secret if needed
    IF NOT EXISTS (
        SELECT
            *
        FROM
            vault.secrets
        WHERE
            name = secret_name) THEN
    PERFORM
        vault.create_secret (refresh_token, secret_name);
END IF;
END;
$function$;

