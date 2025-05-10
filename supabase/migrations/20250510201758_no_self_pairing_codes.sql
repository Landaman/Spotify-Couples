set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.pair_with_code(pairing_code character varying)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
  code_expiry TIMESTAMPTZ;
  code_owner_id UUID;
BEGIN  
  IF (SELECT partner_id FROM profiles WHERE id = auth.uid()) IS NOT NULL 
  THEN
    RAISE EXCEPTION 'Unable to pair with a code when the user already has a partner';
  END IF;

  SELECT owner_id, expires_at INTO code_owner_id, code_expiry FROM pairing_codes WHERE code = pairing_code;

  IF code_owner_id = auth.uid()
  THEN
    RAISE EXCEPTION 'Unable to pair with a code the user owns';
  END IF;

  IF code_expiry IS NULL OR code_expiry < NOW()
  THEN
    RAISE EXCEPTION 'Invalid pairing code';
  END IF;

  IF (SELECT partner_id FROM profiles WHERE id = code_owner_id) IS NOT NULL
  THEN
    RAISE EXCEPTION 'Unable to pair with a code from a user that has a partner';
  END IF;

  UPDATE profiles SET partner_id = code_owner_id WHERE id = auth.uid();
  UPDATE profiles SET partner_id = auth.uid() WHERE id = code_owner_id;

  DELETE FROM pairing_codes WHERE code = pairing_code;
END;
$function$
;


