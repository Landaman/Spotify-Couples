create type "public"."album_release_date_precision" as enum ('year', 'month', 'day');

create type "public"."album_type" as enum ('album', 'single', 'compilation');

create table "public"."albums" (
    "id" text not null,
    "album_type" album_type not null,
    "picture_url" text,
    "name" text not null,
    "release_date" date not null,
    "release_date_precision" album_release_date_precision not null,
    "artist_ids" text[] not null,
    "label" text not null,
    "popularity" integer not null
);


alter table "public"."albums" enable row level security;

create table "public"."artists" (
    "id" text not null,
    "picture_url" text,
    "genres" text[] not null,
    "popularity" integer not null,
    "followers" integer not null,
    "name" text not null
);


alter table "public"."artists" enable row level security;

create table "public"."tracks" (
    "id" text not null,
    "explicit" boolean not null,
    "duration_ms" integer not null,
    "disc_number" integer not null,
    "track_number" integer not null,
    "popularity" integer not null,
    "name" text not null,
    "artist_ids" text[] not null,
    "album_id" text not null
);


alter table "public"."tracks" enable row level security;

CREATE UNIQUE INDEX albums_pkey ON public.albums USING btree (id);

CREATE UNIQUE INDEX artists_pkey ON public.artists USING btree (id);

CREATE UNIQUE INDEX tracks_pkey ON public.tracks USING btree (id);

alter table "public"."albums" add constraint "albums_pkey" PRIMARY KEY using index "albums_pkey";

alter table "public"."artists" add constraint "artists_pkey" PRIMARY KEY using index "artists_pkey";

alter table "public"."tracks" add constraint "tracks_pkey" PRIMARY KEY using index "tracks_pkey";

alter table "public"."tracks" add constraint "tracks_album_id_fkey" FOREIGN KEY (album_id) REFERENCES albums(id) ON UPDATE CASCADE ON DELETE CASCADE not valid;

alter table "public"."tracks" validate constraint "tracks_album_id_fkey";

grant delete on table "public"."albums" to "anon";

grant insert on table "public"."albums" to "anon";

grant references on table "public"."albums" to "anon";

grant select on table "public"."albums" to "anon";

grant trigger on table "public"."albums" to "anon";

grant truncate on table "public"."albums" to "anon";

grant update on table "public"."albums" to "anon";

grant delete on table "public"."albums" to "authenticated";

grant insert on table "public"."albums" to "authenticated";

grant references on table "public"."albums" to "authenticated";

grant select on table "public"."albums" to "authenticated";

grant trigger on table "public"."albums" to "authenticated";

grant truncate on table "public"."albums" to "authenticated";

grant update on table "public"."albums" to "authenticated";

grant delete on table "public"."albums" to "service_role";

grant insert on table "public"."albums" to "service_role";

grant references on table "public"."albums" to "service_role";

grant select on table "public"."albums" to "service_role";

grant trigger on table "public"."albums" to "service_role";

grant truncate on table "public"."albums" to "service_role";

grant update on table "public"."albums" to "service_role";

grant delete on table "public"."artists" to "anon";

grant insert on table "public"."artists" to "anon";

grant references on table "public"."artists" to "anon";

grant select on table "public"."artists" to "anon";

grant trigger on table "public"."artists" to "anon";

grant truncate on table "public"."artists" to "anon";

grant update on table "public"."artists" to "anon";

grant delete on table "public"."artists" to "authenticated";

grant insert on table "public"."artists" to "authenticated";

grant references on table "public"."artists" to "authenticated";

grant select on table "public"."artists" to "authenticated";

grant trigger on table "public"."artists" to "authenticated";

grant truncate on table "public"."artists" to "authenticated";

grant update on table "public"."artists" to "authenticated";

grant delete on table "public"."artists" to "service_role";

grant insert on table "public"."artists" to "service_role";

grant references on table "public"."artists" to "service_role";

grant select on table "public"."artists" to "service_role";

grant trigger on table "public"."artists" to "service_role";

grant truncate on table "public"."artists" to "service_role";

grant update on table "public"."artists" to "service_role";

grant delete on table "public"."tracks" to "anon";

grant insert on table "public"."tracks" to "anon";

grant references on table "public"."tracks" to "anon";

grant select on table "public"."tracks" to "anon";

grant trigger on table "public"."tracks" to "anon";

grant truncate on table "public"."tracks" to "anon";

grant update on table "public"."tracks" to "anon";

grant delete on table "public"."tracks" to "authenticated";

grant insert on table "public"."tracks" to "authenticated";

grant references on table "public"."tracks" to "authenticated";

grant select on table "public"."tracks" to "authenticated";

grant trigger on table "public"."tracks" to "authenticated";

grant truncate on table "public"."tracks" to "authenticated";

grant update on table "public"."tracks" to "authenticated";

grant delete on table "public"."tracks" to "service_role";

grant insert on table "public"."tracks" to "service_role";

grant references on table "public"."tracks" to "service_role";

grant select on table "public"."tracks" to "service_role";

grant trigger on table "public"."tracks" to "service_role";

grant truncate on table "public"."tracks" to "service_role";

grant update on table "public"."tracks" to "service_role";

create policy "Enable authenticated users to view albums"
on "public"."albums"
as permissive
for select
to public
using ((( SELECT auth.uid() AS uid) IS NOT NULL));


create policy "Enable authenticated users to view artists"
on "public"."artists"
as permissive
for select
to public
using ((( SELECT auth.uid() AS uid) IS NOT NULL));


create policy "Enable authenticated users to view tracks"
on "public"."tracks"
as permissive
for select
to public
using ((( SELECT auth.uid() AS uid) IS NOT NULL));
set check_function_bodies = off;

CREATE OR REPLACE FUNCTION private.save_album_details(album_id text)
 RETURNS public.albums
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
	RAISE EXCEPTION 'InvalidAlbumResponse' USING detail = 'Received track ID (' || (track
	  ->> 'id') || ') that is not valid';
    END IF;
END IF;
END LOOP;
  RETURN RESULT;
END;
$function$
;

CREATE OR REPLACE FUNCTION private.save_artist_details(artist_id text)
 RETURNS artists
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
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

    INSERT INTO public.artists (id, picture_url, genres, popularity, followers, name)
      VALUES (artist_response ->> 'id', artist_response ->
	'images' -> 0 ->> 'url', ARRAY (
          SELECT
            genre
          FROM
            jsonb_array_elements(artist_response -> 'genres') AS genre),
          (artist_response ->> 'popularity')::integer,
          (artist_response -> 'followers' ->> 'total')::integer,
          artist_response ->> 'name')
    RETURNING
      * INTO result;
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
	USING detail = 'Received an album ID (' || (track_response -> 'album' ->>
	  'id') || ') that is not valid';
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
    'track_number')::integer, (track_response ->>
    'popularity')::integer, track_response ->> 'name', (
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





