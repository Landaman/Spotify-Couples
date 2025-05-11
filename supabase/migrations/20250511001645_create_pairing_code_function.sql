drop policy "Enable delete for users to their own pairing code" on "public"."pairing_codes";

drop policy "Enable users to create pairing codes for themselves" on "public"."pairing_codes";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.get_or_create_pairing_code()
 RETURNS pairing_codes
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
  result pairing_codes;
  done bool := false;
BEGIN
  SELECT * INTO result
  FROM pairing_codes
  WHERE owner_id = auth.uid();

  IF NOT FOUND OR result.expires_at < now() THEN
    DELETE FROM pairing_codes WHERE owner_id = auth.uid();

    WHILE NOT done LOOP
      result.code := md5('' || now()::text || random()::text);
      done := NOT EXISTS (
        SELECT 1 FROM pairing_codes WHERE code = result.code
      );
    END LOOP;

    INSERT INTO pairing_codes(owner_id, code, expires_at)
    VALUES (auth.uid(), result.code, now() + interval '15 minutes')
    RETURNING * INTO result;
  END IF;

  RETURN result;
END;
$function$
;


