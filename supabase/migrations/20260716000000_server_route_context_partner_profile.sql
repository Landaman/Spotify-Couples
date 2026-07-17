DROP FUNCTION public.get_server_route_context ();

DROP TYPE public.server_route_context;

CREATE TYPE public.server_route_context AS (
  partner_profile public.profile,
  play_refresh_needed boolean
);

CREATE FUNCTION public.get_server_route_context () RETURNS public.server_route_context LANGUAGE plpgsql SECURITY INVOKER
SET
  search_path = '' AS $$
DECLARE
  result public.server_route_context;
  requesting_user_id uuid := auth.uid ();
BEGIN
  IF requesting_user_id IS NULL THEN
    RETURN result;
  END IF;

  result.partner_profile := public.get_partner_profile ();
  result.play_refresh_needed := public.user_needs_play_refresh ();

  RETURN result;
END;
$$;

REVOKE
EXECUTE ON FUNCTION public.get_server_route_context ()
FROM
  public;

REVOKE
EXECUTE ON FUNCTION public.get_server_route_context ()
FROM
  anon;

GRANT
EXECUTE ON FUNCTION public.get_server_route_context () TO authenticated;
