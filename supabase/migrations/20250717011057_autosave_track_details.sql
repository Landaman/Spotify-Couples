alter table "public"."plays" add column "track_id" text not null DEFAULT '';

update "public"."plays" set "track_id" = "spotify_id";

alter table "public"."plays" drop column "spotify_id";

-- Ensure that the FK below is valid
DO $$
    DECLARE
        play public.plays;
    BEGIN
        FOR play in (SELECT * FROM public.plays)
        LOOP
            IF NOT EXISTS(SELECT 1 FROM public.tracks WHERE id = play.track_id) THEN
                PERFORM private.save_track_details(play.track_id);
            END IF;
        END LOOP;
    END;
$$;

alter table "public"."plays" add constraint "plays_track_id_fkey" FOREIGN KEY (track_id) REFERENCES tracks(id) ON UPDATE CASCADE ON DELETE RESTRICT not valid;

alter table "public"."plays" validate constraint "plays_track_id_fkey";


set check_function_bodies = off;

CREATE OR REPLACE FUNCTION private.get_new_plays_for_user(requesting_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  access_token_header extensions.http_header;
  plays_response jsonb;
  plays_status integer;
  after_pointer text;
  search_parameters text := '?limit=50';
  user_refresh_token text;
  play jsonb;
  -- Required otherwise psql doesn't know the type below
BEGIN
  SELECT
    decrypted_secret INTO user_refresh_token
  FROM
    vault.decrypted_secrets
  WHERE
    name = requesting_user_id || '_spotify_code';
  -- Get an access token
  access_token_header = private.get_access_token_header (user_refresh_token);
  IF access_token_header IS NULL THEN
    RETURN;
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
  -- Check that we got a valid response from Spotify, if not show that
  IF plays_response IS NULL OR plays_status != 200 THEN
    RAISE EXCEPTION 'InvalidRecentlyPlayedResponseException'
      USING detail = 'HTTP Response code: ' || plays_status || ' body: ' || plays_response;
    END IF;
    -- Determine what the next after pointer is
    IF plays_response -> 'cursors' ->> 'after' IS NOT NULL THEN
      -- Take what we have is necessary
      after_pointer = plays_response -> 'cursors' ->> 'after';
    ELSE
      -- Convert seconds to milliseconds, since PG spits out seconds
      after_pointer = round(date_part('epoch', now()) * 1000);
    END IF;
    -- Re-insert the spotify after pointer, or create it if we haven't seen it
    INSERT INTO private.play_metadata (user_id, spotify_after_pointer, last_read_time)
      VALUES (requesting_user_id, after_pointer, NOW())
    ON CONFLICT (user_id)
      DO UPDATE SET
        spotify_after_pointer = excluded.spotify_after_pointer,
        last_read_time = NOW();
    -- Now loop through play responses
    FOR play IN (
      SELECT
        *
      FROM
        -- Required, since what is passed into a for needs to be a set
        jsonb_array_elements(plays_response -> 'items'))
      LOOP
        -- Save track details if necessary. This also saves album, etc
        IF NOT EXISTS (
          SELECT
            1
          FROM
            public.tracks
          WHERE
            id = (play -> 'track' ->> 'id')) THEN
        PERFORM
          private.save_track_details (play -> 'track' ->> 'id');
      END IF;
    -- Insert a play for each one
    INSERT INTO public.plays (user_id, played_date_time, track_id,
      spotify_played_context_uri)
      VALUES (requesting_user_id, (play ->> 'played_at')::timestamptz, play
	-> 'track' ->> 'id', play -> 'context' ->>
	'uri');
  END LOOP;
END;
$function$
;

CREATE OR REPLACE FUNCTION private.save_album_details(album_id text)
 RETURNS albums
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION private.save_track_details(track_id text)
 RETURNS tracks
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
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
$function$
;


