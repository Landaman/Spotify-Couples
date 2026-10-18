DROP FUNCTION IF EXISTS public.unpair_partner (uuid);

-- Removes the authenticated user's pairing with the supplied partner.
-- Raises NoPartnerException if unpaired, or InvalidPartnerException if the
-- supplied partner is no longer current. Individual listening history is kept.
CREATE FUNCTION public.unpair_partner (partner_id uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET
  search_path = '' AS $$
BEGIN
  IF private.get_partner_id () IS NULL THEN
    RAISE EXCEPTION 'NoPartnerException'
      USING DETAIL = 'Unable to unpair when the user has no partner';
    END IF;

    DELETE FROM public.pairings
    WHERE (one_uuid = auth.uid ()
        AND two_uuid = partner_id)
      OR (two_uuid = auth.uid ()
        AND one_uuid = partner_id);

    IF NOT FOUND THEN
      RAISE EXCEPTION 'InvalidPartnerException'
        USING DETAIL = 'Unable to unpair from a partner that is not the current partner';
      END IF;
END;
$$;

REVOKE
EXECUTE ON FUNCTION public.unpair_partner (uuid)
FROM
  public;

REVOKE
EXECUTE ON FUNCTION public.unpair_partner (uuid)
FROM
  anon;

GRANT
EXECUTE ON FUNCTION public.unpair_partner (uuid) TO authenticated;
