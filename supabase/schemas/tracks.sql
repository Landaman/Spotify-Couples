CREATE TABLE public.tracks (
  id text NOT NULL PRIMARY KEY,
  explicit boolean NOT NULL,
  duration_ms integer NOT NULL,
  disc_number integer NOT NULL,
  track_number integer NOT NULL,
  popularity integer NOT NULL,
  name text NOT NULL,
  artist_ids text[] NOT NULL,
  album_id text NOT NULL REFERENCES public.albums (id) ON UPDATE CASCADE ON DELETE CASCADE
);

ALTER TABLE public.tracks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable authenticated users to view tracks" ON public.tracks FOR
SELECT
  USING (
    (
      (
        SELECT
          auth.uid ()
      ) IS NOT NULL
    )
  );

CREATE FUNCTION private.save_track_details (track_id text) RETURNS public.tracks LANGUAGE plpgsql
SET
  search_path = '' AS $$
DECLARE
  track_status integer;
  track_response jsonb;
  result public.tracks;
  artist jsonb;
BEGIN
  SELECT
    status,
    content::jsonb INTO track_status,
    track_response
  FROM
    extensions.http (('GET', 'https://api.spotify.com/v1/tracks/' || track_id,
      ARRAY[private.get_client_credentials_header ()],
      '', '')::extensions.http_request);

  IF track_status = 404 THEN
    RETURN NULL;
  END IF;

  IF track_status != 200 THEN
    RAISE EXCEPTION 'InvalidTrackResponse'
      USING detail = 'HTTP Response code: ' || track_status || ' body: ' || track_response;
    END IF;

    IF NOT EXISTS (
      SELECT
        1
      FROM
        public.albums
      WHERE
        id = track_response -> 'album' ->> 'id') THEN
    -- This creates the album (and all tracks including this one) by side-effect
    IF private.save_album_details (track_response -> 'album' ->>
      'id') IS NULL THEN
      RAISE EXCEPTION 'InvalidTrackResponse'
	USING detail = 'Received an album ID (' || (track_response -> 'album'
	  ->> 'id') || ') that is not valid';
      END IF;
      -- No need to process this, as the album would've implicitly created this track
      SELECT
        * INTO result
      FROM
        public.tracks
      WHERE
        id = track_id;
      RETURN result;
    END IF;
    -- Ensure all artists are created first. Checking the album isn't enough because tracks
    -- can have artists the album doesn't
    FOR artist IN (
      SELECT
        *
      FROM
        jsonb_array_elements(track_response -> 'artists'))
      LOOP
        -- Save the artist if it doesn't already exist
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

INSERT INTO public.tracks (id, explicit, duration_ms, disc_number,
  track_number, popularity, name, artist_ids, album_id)
  VALUES (track_response ->> 'id', (track_response ->>
    'explicit')::boolean, (track_response ->> 'duration_ms')::integer,
    (track_response ->> 'disc_number')::integer, (track_response ->>
    'track_number')::integer, (track_response ->> 'popularity')::integer,
    track_response ->> 'name', (
      SELECT
        ARRAY_AGG(artists ->> 'id')
      FROM
        jsonb_array_elements(track_response -> 'artists') AS artists),
      track_response -> 'album' ->> 'id')
RETURNING
  * INTO result;
  RETURN RESULT;
END;
$$;
