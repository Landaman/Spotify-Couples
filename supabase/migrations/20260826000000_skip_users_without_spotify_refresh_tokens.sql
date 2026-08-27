CREATE OR REPLACE FUNCTION private.get_new_plays_for_user_jsonb (requesting_user_id uuid) RETURNS jsonb LANGUAGE plpgsql PARALLEL SAFE
SET
  search_path = '' AS $$
DECLARE
  access_token_header extensions.http_header;
  plays_response jsonb;
  plays_status integer;
  after_pointer text;
  search_parameters text := '?limit=50';
  user_refresh_token text;
BEGIN
  SELECT
    decrypted_secret INTO user_refresh_token
  FROM
    vault.decrypted_secrets
  WHERE
    name = requesting_user_id || '_spotify_code';
  IF user_refresh_token IS NULL THEN
    RETURN NULL;
  END IF;
  -- Get an access token
  access_token_header = private.get_access_token_header (user_refresh_token);
  IF access_token_header IS NULL THEN
    RETURN NULL;
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
  -- Check that we got a valid response from Spotify, if not show that. Don't fail because that would mean that every user fails in the caller
  IF plays_response IS NULL OR plays_status != 200 THEN
    RAISE WARNING 'InvalidRecentlyPlayedResponseException'
    USING detail = 'HTTP Response code: ' || plays_status || ' body: ' || plays_response;
    RETURN NULL;
  END IF;
    -- Build + return a reasonable response
    RETURN jsonb_build_object(requesting_user_id::text, plays_response);
END;
$$;
