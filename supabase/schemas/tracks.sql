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

-- Support album foreign key cascades without scanning every track
CREATE INDEX tracks_album_id_idx ON public.tracks (album_id);

ALTER TABLE public.tracks ENABLE ROW LEVEL SECURITY;

REVOKE
SELECT
  ON TABLE public.tracks
FROM
  public,
  anon,
  authenticated;
