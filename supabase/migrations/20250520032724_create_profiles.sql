alter table "public"."profiles" add column "name" text not null;

alter table "public"."profiles" add column "picture_url" text;

alter table "public"."profiles" add column "spotify_id" text not null;

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
  INSERT INTO public.profiles (id, name, spotify_id, picture_url)
  VALUES (new.id, new.raw_user_meta_data ->> 'name', new.raw_user_meta_data ->> 'provider_id', new.raw_user_meta_data ->> 'picture');
  RETURN NEW;
END;
$function$
;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT on auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
