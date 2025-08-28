CREATE TABLE public.artists (
  id text NOT NULL PRIMARY KEY,
  picture_url text,
  genres text[] NOT NULL,
  name text NOT NULL
);

ALTER TABLE public.artists ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable authenticated users to view artists" ON public.artists FOR
SELECT
  USING (
    (
      (
        SELECT
          auth.uid ()
      ) IS NOT NULL
    )
  );

CREATE FUNCTION private.save_artist_details (artist_id text) RETURNS public.artists LANGUAGE plpgsql
SET
  search_path = '' AS $$
DECLARE
  artist_status integer;
  artist_response jsonb;
  result public.artists;
BEGIN
  SELECT
    status,
    content::jsonb INTO artist_status,
    artist_response
  FROM
    extensions.http (('GET', 'https://api.spotify.com/v1/artists/' || artist_id,
      ARRAY[private.get_client_credentials_header ()],
      '', '')::extensions.http_request);

  IF artist_status = 404 THEN
    RETURN NULL;
  END IF;

  IF artist_status != 200 THEN
    RAISE EXCEPTION 'InvalidArtistResponse'
      USING detail = 'HTTP Response code: ' || artist_status || ' body: ' || artist_response;
    END IF;

    INSERT INTO public.artists (id, picture_url, genres, name)
      VALUES (artist_response ->> 'id', artist_response ->
	'images' -> 0 ->> 'url', ARRAY (
          SELECT
            genre
          FROM
            jsonb_array_elements(artist_response -> 'genres') AS genre),
          artist_response ->> 'name')
    RETURNING
      * INTO result;
    RETURN RESULT;
END;
$$;
