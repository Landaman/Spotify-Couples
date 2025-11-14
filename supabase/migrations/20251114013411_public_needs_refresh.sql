set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.user_needs_play_refresh()
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  RETURN private.user_needs_play_refresh (auth.uid ());
END;
$function$
;


