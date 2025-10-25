CREATE TABLE public.tracks (
  id text NOT NULL PRIMARY KEY,
  explicit boolean NOT NULL,
  duration_ms integer NOT NULL,
  disc_number integer NOT NULL,
  track_number integer NOT NULL,
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
