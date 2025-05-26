set check_function_bodies = off;

CREATE OR REPLACE FUNCTION private.cleanup_pairing_codes()
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
    DELETE FROM public.pairing_codes
    WHERE expires_at <= NOW();
END;
$function$
;

CREATE OR REPLACE FUNCTION private.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
    INSERT INTO public.profiles (id, name, spotify_id, picture_url)
        VALUES (NEW.id, NEW.raw_user_meta_data ->> 'name', NEW.raw_user_meta_data ->> 'provider_id', NEW.raw_user_meta_data ->> 'picture');
    RETURN NEW;
END;
$function$
;


set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.get_or_create_pairing_code()
 RETURNS pairing_codes
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    result pairing_codes;
    done bool := FALSE;
BEGIN
    IF (
        SELECT
            partner_id
        FROM
            profiles
        WHERE
            id = auth.uid ()) IS NOT NULL THEN
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
$function$
;

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
                        realtime.send (jsonb_build_object('partner', auth.uid ()), 'paired', 'pairing_codes:' || pairing_code, TRUE -- this means private, i.e., RLS required for access
);
                    DELETE FROM pairing_codes
                    WHERE code = pairing_code;
END;
$function$
;


