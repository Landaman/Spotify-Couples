CREATE TYPE public.album_type AS enum('album', 'single', 'compilation');

CREATE TYPE public.album_release_date_precision AS enum('year', 'month', 'day');

CREATE TABLE public.albums (
  id text NOT NULL PRIMARY KEY,
  album_type public.album_type NOT NULL,
  picture_url text,
  name text NOT NULL,
  release_date date NOT NULL,
  release_date_precision public.album_release_date_precision NOT NULL,
  artist_ids text[] NOT NULL,
  label text NOT NULL,
  popularity integer NOT NULL
);

ALTER TABLE public.albums ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable authenticated users to view albums" ON public.albums FOR
SELECT
  USING (
    (
      (
        SELECT
          auth.uid ()
      ) IS NOT NULL
    )
  );

CREATE FUNCTION private.save_album_details (album_id text) RETURNS public.albums LANGUAGE plpgsql
SET
  search_path = '' AS $$
DECLARE
  album_status integer;
  album_response jsonb;
  result public.albums;
  artist jsonb;
  track jsonb;
BEGIN
  SELECT
    status,
    content::jsonb INTO album_status,
    album_response
  FROM
    extensions.http (('GET', 'https://api.spotify.com/v1/albums/' || album_id,
      ARRAY[private.get_client_credentials_header ()],
      '', '')::extensions.http_request);

  IF album_status = 404 THEN
    RETURN NULL;
  END IF;

  IF album_status != 200 THEN
    RAISE EXCEPTION 'InvalidAlbumResponse'
      USING detail = 'HTTP Response code: ' || album_status || ' body: ' || album_response;
    END IF;
    -- Ensure we have a record for each artist
    FOR artist IN (
      SELECT
        *
      FROM
        jsonb_array_elements(album_response -> 'artists'))
      LOOP
        -- Save the network call if it already exists
        IF NOT EXISTS (
          SELECT
            1
          FROM
            public.artists
          WHERE
            id = (artist ->> 'id')) THEN
        -- This creates the artist by side-effect, just check the result
        IF private.save_artist_details (artist ->> 'id') IS NULL THEN
	  RAISE EXCEPTION 'InvalidAlbumResponse' USING detail = 'Received an artist ID (' ||
	    (artist ->> 'id') || ') that is not valid';
      END IF;
  END IF;
END LOOP;

INSERT INTO public.albums (id, album_type, picture_url, name, release_date,
  release_date_precision, artist_ids, label, popularity)
  VALUES (album_response ->> 'id', (album_response ->>
    'album_type')::public.album_type, album_response -> 'images' -> 0
    ->> 'url', album_response ->> 'name',
    -- Date precision is automatically handled
    TO_DATE(album_response ->> 'release_date', 'YYYY-MM-DD'),
    (album_response ->> 'release_date_precision')::public.album_release_date_precision, (
      SELECT
        ARRAY_AGG(artists ->> 'id')
      FROM
        jsonb_array_elements(album_response -> 'artists') AS artists),
      album_response ->> 'label',
      (album_response ->> 'popularity')::integer)
RETURNING
  * INTO result;
  -- Do this after we create the album, otherwise we will try to create it with the first track (creating a loop)
  FOR track IN (
    SELECT
      *
    FROM
      jsonb_array_elements(album_response -> 'tracks' -> 'items'))
    LOOP
      -- Don't double-create the track if we can avoid it
      IF NOT EXISTS (
        SELECT
          1
        FROM
          public.tracks
        WHERE
          id = (track ->> 'id')) THEN
      -- This creates the track by side effect. Just check the result to be sure
      IF private.save_track_details (track ->> 'id') IS NULL THEN
	RAISE EXCEPTION 'InvalidAlbumResponse' USING detail = 'Received track ID (' ||
	  (track ->> 'id') || ') that is not valid';
    END IF;
END IF;
END LOOP;
  RETURN RESULT;
END;
$$;
