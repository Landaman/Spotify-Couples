drop trigger on_auth_user_created ON auth.users;

drop function if exists "private"."handle_new_user"();


drop policy "Enable users to view their own data and their partners data" on "public"."profiles";

revoke delete on table "public"."profiles" from "anon";

revoke insert on table "public"."profiles" from "anon";

revoke references on table "public"."profiles" from "anon";

revoke select on table "public"."profiles" from "anon";

revoke trigger on table "public"."profiles" from "anon";

revoke truncate on table "public"."profiles" from "anon";

revoke update on table "public"."profiles" from "anon";

revoke delete on table "public"."profiles" from "authenticated";

revoke insert on table "public"."profiles" from "authenticated";

revoke references on table "public"."profiles" from "authenticated";

revoke select on table "public"."profiles" from "authenticated";

revoke trigger on table "public"."profiles" from "authenticated";

revoke truncate on table "public"."profiles" from "authenticated";

revoke update on table "public"."profiles" from "authenticated";

revoke delete on table "public"."profiles" from "service_role";

revoke insert on table "public"."profiles" from "service_role";

revoke references on table "public"."profiles" from "service_role";

revoke select on table "public"."profiles" from "service_role";

revoke trigger on table "public"."profiles" from "service_role";

revoke truncate on table "public"."profiles" from "service_role";

revoke update on table "public"."profiles" from "service_role";

alter table "public"."profiles" drop constraint "profiles_id_fkey";

alter table "public"."profiles" drop constraint "profiles_pkey";

drop index if exists "public"."profiles_pkey";

drop table "public"."profiles";

set check_function_bodies = off;

create type "public"."profile" as ("id" uuid, "name" text, "spotify_id" text, "picture_url" text);

CREATE OR REPLACE FUNCTION public.get_partner_profile()
 RETURNS profile
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  result public.profile;
BEGIN
  SELECT 
    id, 
    raw_user_meta_data->>'name', 
    raw_user_meta_data->>'provider_id', 
    raw_user_meta_data->>'picture'
  INTO result
  FROM auth.users 
  WHERE id = public.get_partner_id();

  RETURN result;
END;
$function$
;

REVOKE
EXECUTE ON FUNCTION public.get_partner_profile ()
FROM
  public;

REVOKE
EXECUTE ON FUNCTION public.get_partner_profile ()
FROM
  anon;
