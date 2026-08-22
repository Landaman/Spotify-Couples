CREATE TABLE public.artists (
  id text NOT NULL PRIMARY KEY,
  picture_url text,
  genres text[] NOT NULL,
  name text NOT NULL
);

ALTER TABLE public.artists ENABLE ROW LEVEL SECURITY;

REVOKE
SELECT
  ON TABLE public.artists
FROM
  public,
  anon,
  authenticated;
