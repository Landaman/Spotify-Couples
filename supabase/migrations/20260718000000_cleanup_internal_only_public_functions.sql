CREATE FUNCTION private.get_partner_id () RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER
SET
  search_path = '' AS $$
BEGIN
  RETURN private.get_partner_id (auth.uid ());
END;
$$;

CREATE FUNCTION private.get_partner_id (search_uuid uuid) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER
SET
  search_path = '' AS $$
BEGIN
  RETURN (
    SELECT
      one_uuid
    FROM
      public.pairings
    WHERE
      search_uuid = two_uuid
    UNION
    SELECT
      two_uuid
    FROM
      public.pairings
    WHERE
      one_uuid = search_uuid);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_partner_profile () RETURNS public.profile LANGUAGE plpgsql SECURITY DEFINER
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
    id = private.get_partner_id ();

  RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_server_route_context () RETURNS public.server_route_context LANGUAGE plpgsql SECURITY DEFINER
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
  result.play_refresh_needed := private.user_needs_play_refresh (requesting_user_id);

  RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION public.pair_with_code (pairing_code character varying) RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET
  search_path = 'public' AS $$
DECLARE
  code_expiry timestamptz;
  code_owner_id uuid;
BEGIN
  IF (
    SELECT
      private.get_partner_id ()) IS NOT NULL THEN
    RAISE EXCEPTION 'HasPartnerException'
      USING DETAIL = 'Unable to pair with a code when the user already has a partner';
    END IF;

    SELECT
      owner_id,
      expires_at INTO code_owner_id,
      code_expiry
    FROM
      pairing_codes
    WHERE
      code = pairing_code;
    IF code_owner_id = auth.uid () THEN
      RAISE EXCEPTION 'InvalidPairingCodeException'
        USING DETAIL = 'Unable to pair with a code the user owns';
      END IF;

      IF NOT FOUND OR code_expiry < NOW() THEN
        RAISE EXCEPTION 'InvalidPairingCodeException'
          USING DETAIL = 'Unable to pair with a pairing code that does not exist or is expired';
        END IF;

        IF (
          SELECT
            private.get_partner_id (code_owner_id)) IS NOT NULL THEN
          RAISE EXCEPTION 'InvalidPairingCodeException'
            USING DETAIL = 'Unable to pair with a pairing code that does not exist or is expired';
          END IF;

          INSERT INTO public.pairings (one_uuid, two_uuid)
            VALUES (auth.uid (), code_owner_id);

          PERFORM
	    realtime.send (jsonb_build_object(), 'paired',
	      'pairing_codes:' || pairing_code, TRUE);
          DELETE FROM pairing_codes
          WHERE code = pairing_code;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_or_create_pairing_code () RETURNS pairing_codes LANGUAGE plpgsql SECURITY DEFINER
SET
  search_path = 'public' AS $$
DECLARE
  result pairing_codes;
  done bool := FALSE;
BEGIN
  IF (
    SELECT
      private.get_partner_id ()) IS NOT NULL THEN
    RAISE EXCEPTION 'HasPartnerException'
      USING DETAIL = 'Unable to get a pairing code for a user that already has a partner';
    END IF;
    SELECT
      * INTO result
    FROM
      pairing_codes
    WHERE
      owner_id = auth.uid ();
    IF NOT FOUND OR result.expires_at < now() THEN
      DELETE FROM pairing_codes
      WHERE owner_id = auth.uid ();
      WHILE NOT done LOOP
        result.code := UPPER(SUBSTRING(MD5('' || now()::text || random()::text), 1, 6));
        done := NOT EXISTS (
          SELECT
            1
          FROM
            pairing_codes
          WHERE
            code = result.code);
      END LOOP;
      INSERT INTO pairing_codes (owner_id, code, expires_at)
        VALUES (auth.uid (), result.code, now() + interval '15 minutes')
      RETURNING
        * INTO result;
    END IF;
    RETURN result;
END;
$$;

DROP POLICY "Enable users to view their own and their partners plays" ON public.plays;

CREATE POLICY "Enable users to view their own and their partners plays" ON public.plays FOR
SELECT
  USING (
    (
      (
        (
          SELECT
            auth.uid ()
        ) = user_id
      )
      OR (
        (
          SELECT
            private.get_partner_id ()
        ) = user_id
      )
    )
  );

DROP FUNCTION public.user_needs_play_refresh ();
DROP FUNCTION public.get_partner_id ();
DROP FUNCTION public.get_partner_id (uuid);
