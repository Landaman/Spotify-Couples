DROP POLICY "Enable users to view their own and their partners plays" ON public.plays;
DROP POLICY "Enable authenticated users to view tracks" ON public.tracks;
DROP POLICY "Enable authenticated users to view albums" ON public.albums;
DROP POLICY "Enable authenticated users to view artists" ON public.artists;

CREATE FUNCTION public.get_dashboard () RETURNS TABLE (
  album text,
  album_picture text,
  artist text,
  plays bigint,
  track_name text
) LANGUAGE plpgsql SECURITY DEFINER
SET
  search_path = '' AS $$
BEGIN
  IF private.get_partner_id () IS NULL THEN
    RAISE EXCEPTION 'NoPartnerException';
  END IF;

  RETURN QUERY
  SELECT
    albums.name,
    coalesce(albums.picture_url, ''),
    artists.names,
    count(plays.id),
    tracks.name
  FROM
    public.plays AS plays
    INNER JOIN public.tracks AS tracks ON tracks.id = plays.track_id
    INNER JOIN public.albums AS albums ON albums.id = tracks.album_id
    CROSS JOIN LATERAL (
      SELECT
        string_agg(artists.name, ', ' ORDER BY track_artists.ordinality) AS names
      FROM
        unnest(tracks.artist_ids) WITH ORDINALITY AS track_artists (id, ordinality)
        INNER JOIN public.artists AS artists ON artists.id = track_artists.id) AS artists
  WHERE
    plays.user_id = auth.uid ()
  GROUP BY
    tracks.id,
    tracks.name,
    albums.id,
    albums.name,
    albums.picture_url,
    artists.names
  ORDER BY
    count(plays.id) DESC
  LIMIT 5;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_dashboard () FROM public;
REVOKE EXECUTE ON FUNCTION public.get_dashboard () FROM anon;
GRANT EXECUTE ON FUNCTION public.get_dashboard () TO authenticated;
