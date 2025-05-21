set check_function_bodies = off;

CREATE OR REPLACE FUNCTION private.cleanup_pairing_codes()
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
  DELETE FROM public.pairing_codes WHERE expires_at <= NOW();
END;
$function$
;

SELECT cron.schedule('Nightly Pairing Code Cleanup', '0 0 * * *', 'SELECT private.cleanup_pairing_codes()');
