CREATE FUNCTION private.get_basic_credentials_header () RETURNS extensions.http_header LANGUAGE plpgsql
SET
  search_path = '' AS $$
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
$$;

CREATE FUNCTION private.get_client_credentials_header () RETURNS extensions.http_header LANGUAGE plpgsql
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
$$;
