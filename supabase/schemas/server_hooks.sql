CREATE TYPE public.server_route_context AS (partner_id uuid, play_refresh_needed boolean);

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

  result.partner_id := public.get_partner_id ();
  result.play_refresh_needed := public.user_needs_play_refresh ();

  RETURN result;
END;
$$;

-- HACK: This doesn't do anything, create a migration manually to edit these
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
