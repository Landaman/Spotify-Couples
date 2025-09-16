CREATE TYPE public.album_type AS enum('album', 'single', 'compilation');

CREATE TYPE public.album_release_date_precision AS enum('year', 'month', 'day');

CREATE TABLE public.albums (
  id text NOT NULL PRIMARY KEY,
  album_type public.album_type NOT NULL,
  picture_url text,
  name text NOT NULL,
  release_date date NOT NULL,
  release_date_precision public.album_release_date_precision NOT NULL,
  artist_ids text[] NOT NULL
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
