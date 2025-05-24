set check_function_bodies = off;

CREATE OR REPLACE FUNCTION private.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  INSERT INTO public.profiles (id, name, spotify_id, picture_url)
  VALUES (new.id, new.raw_user_meta_data ->> 'name', new.raw_user_meta_data ->> 'provider_id', new.raw_user_meta_data ->> 'picture');
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT on auth.users
  FOR EACH ROW EXECUTE PROCEDURE private.handle_new_user();

drop function if exists "public"."handle_new_user"();


