CREATE TABLE public.pairing_codes (
  code character varying NOT NULL PRIMARY KEY,
  expires_at timestamp with time zone NOT NULL,
  owner_id uuid NOT NULL UNIQUE REFERENCES auth.users (id) ON UPDATE CASCADE ON DELETE CASCADE
);

ALTER TABLE public.pairing_codes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable select for users to their own pairing codes" ON public.pairing_codes FOR
SELECT
  TO authenticated USING (
    (
      (
        SELECT
          auth.uid ()
      ) = owner_id
    )
  );

CREATE FUNCTION public.pair_with_code (pairing_code character varying) RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET
  search_path = 'public' AS $$
DECLARE
  code_expiry timestamptz;
  code_owner_id uuid;
BEGIN
  IF (
    SELECT
      public.get_partner_id ()) IS NOT NULL THEN
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
    -- This handles the case where the code DNE and the auth.uid() does due to the role restrictions below
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
            public.get_partner_id (code_owner_id)) IS NOT NULL THEN
          RAISE EXCEPTION 'InvalidPairingCodeException'
            USING DETAIL = 'Unable to pair with a pairing code that does not exist or is expired';
          END IF;

          INSERT INTO public.pairings (one_uuid, two_uuid)
            VALUES (auth.uid (), code_owner_id);

          PERFORM
	    realtime.send (jsonb_build_object(), 'paired',
	      'pairing_codes:' || pairing_code, TRUE);
          -- this means private, i.e., RLS required for access
          DELETE FROM pairing_codes
          WHERE code = pairing_code;
END;
$$;

-- HACK: this doesn't do anything here. It is shown for clarity.
-- to edit this, manually create a migration
REVOKE
EXECUTE ON FUNCTION public.pair_with_code
FROM
  public;

REVOKE
EXECUTE ON FUNCTION public.pair_with_code
FROM
  anon;

CREATE FUNCTION public.get_or_create_pairing_code () RETURNS pairing_codes LANGUAGE plpgsql SECURITY DEFINER
SET
  search_path = 'public' AS $$
DECLARE
  result pairing_codes;
  done bool := FALSE;
BEGIN
  IF (
    SELECT
      public.get_partner_id ()) IS NOT NULL THEN
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

-- HACK: this doesn't do anything here. It is shown for clarity.
-- to edit this, manually create a migration
REVOKE
EXECUTE ON FUNCTION public.get_or_create_pairing_code
FROM
  public;

REVOKE
EXECUTE ON FUNCTION public.get_or_create_pairing_code
FROM
  anon;

-- HACK: this also doesn't do anything, since the realtime schema is not
-- included in the versioning done by Postgres. Again, shown for clarity
CREATE POLICY "Users can listen to messages about their own pairing codes" ON realtime.messages FOR
SELECT
  TO AUTHENTICATED USING (
    EXISTS (
      SELECT
        owner_id
      FROM
        public.pairing_codes
      WHERE
        owner_id = (
          SELECT
            auth.uid ()
        )
        AND 'pairing_codes:' || CODE = (
          SELECT
            realtime.topic ()
        )
        AND expires_at > NOW()
        AND realtime.messages.extension IN ('broadcast')
    )
  );

CREATE FUNCTION private.cleanup_pairing_codes () RETURNS VOID LANGUAGE plpgsql
SET
  search_path = '' AS $$
BEGIN
  DELETE FROM public.pairing_codes
  WHERE expires_at <= NOW();
END;
$$;

-- HACK: this doesn't do anything here, it is for clarity. Which is just as well, since if you delete it,
-- it won't actually cleanup anything
SELECT
  cron.schedule (
    'Nightly Pairing Code Cleanup',
    '0 0 * * *',
    'SELECT private.cleanup_pairing_codes()'
  );
