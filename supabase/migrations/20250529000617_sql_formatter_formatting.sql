set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.process_spotify_refresh_token(refresh_token text)
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
$function$
;


