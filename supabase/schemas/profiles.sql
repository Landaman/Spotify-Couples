CREATE TYPE public.profile AS (
  id uuid,
  name text,
  spotify_id text,
  picture_url text
);

CREATE FUNCTION public.get_partner_profile () RETURNS public.profile LANGUAGE plpgsql SECURITY DEFINER
SET
  search_path = '' AS $$
DECLARE
  result public.profile;
BEGIN
  SELECT
    id,
    raw_user_meta_data ->> 'name',
    raw_user_meta_data ->> 'provider_id',
    raw_user_meta_data ->> 'picture' INTO result
  FROM
    auth.users
  WHERE
    id = public.get_partner_id ();

  RETURN result;
END;
$$;

-- HACK: This doesn't do anything, create a migration manually to edit these
REVOKE
EXECUTE ON FUNCTION public.get_partner_profile ()
FROM
  public;

REVOKE
EXECUTE ON FUNCTION public.get_partner_profile ()
FROM
  anon;
