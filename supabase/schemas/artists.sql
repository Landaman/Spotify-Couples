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
