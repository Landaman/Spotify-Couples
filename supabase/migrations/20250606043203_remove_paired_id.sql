set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.pair_with_code(pairing_code character varying)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    code_expiry timestamptz;
    code_owner_id uuid;
BEGIN
    IF (
        SELECT
            partner_id
        FROM
            profiles
        WHERE
            id = auth.uid ()) IS NOT NULL THEN
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
                        partner_id
                    FROM
                        profiles
                    WHERE
                        id = code_owner_id) IS NOT NULL THEN
                    RAISE EXCEPTION 'InvalidPairingCodeException'
                        USING DETAIL = 'Unable to pair with a pairing code that does not exist or is expired';
                    END IF;
                    UPDATE
                        profiles
                    SET
                        partner_id = code_owner_id
                    WHERE
                        id = auth.uid ();
                    UPDATE
                        profiles
                    SET
                        partner_id = auth.uid ()
                    WHERE
                        id = code_owner_id;
                    PERFORM
                        realtime.send (jsonb_build_object(), 'paired', 'pairing_codes:' || pairing_code, TRUE -- this means private, i.e., RLS required for access
);
                    DELETE FROM pairing_codes
                    WHERE code = pairing_code;
END;
$function$
;


