CREATE FUNCTION private.get_basic_credentials_header () RETURNS extensions.http_header LANGUAGE plpgsql
SET
  search_path = '' AS $$
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
$$;
