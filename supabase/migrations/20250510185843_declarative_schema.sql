create table "public"."pairing_codes" (
    "code" character varying not null,
    "expires_at" timestamp with time zone not null,
    "owner_id" uuid not null
);


alter table "public"."pairing_codes" enable row level security;

create table "public"."plays" (
    "id" uuid not null default gen_random_uuid(),
    "played_date_time" timestamp with time zone not null,
    "spotify_played_context_uri" text,
    "spotify_id" text not null,
    "user_id" uuid not null
);


alter table "public"."plays" enable row level security;

create table "public"."profiles" (
    "id" uuid not null,
    "display_name" text not null,
    "profile_picture_url" text,
    "partner_id" uuid
);


alter table "public"."profiles" enable row level security;

CREATE UNIQUE INDEX pairing_codes_owner_id_key ON public.pairing_codes USING btree (owner_id);

CREATE UNIQUE INDEX pairing_codes_pkey ON public.pairing_codes USING btree (code);

CREATE UNIQUE INDEX plays_pkey ON public.plays USING btree (id);

CREATE INDEX plays_user_id_idx ON public.plays USING btree (user_id);

CREATE UNIQUE INDEX profiles_partner_id_key ON public.profiles USING btree (partner_id);

CREATE UNIQUE INDEX profiles_pkey ON public.profiles USING btree (id);

alter table "public"."pairing_codes" add constraint "pairing_codes_pkey" PRIMARY KEY using index "pairing_codes_pkey";

alter table "public"."plays" add constraint "plays_pkey" PRIMARY KEY using index "plays_pkey";

alter table "public"."profiles" add constraint "profiles_pkey" PRIMARY KEY using index "profiles_pkey";

alter table "public"."pairing_codes" add constraint "pairing_codes_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON UPDATE CASCADE ON DELETE CASCADE not valid;

alter table "public"."pairing_codes" validate constraint "pairing_codes_owner_id_fkey";

alter table "public"."pairing_codes" add constraint "pairing_codes_owner_id_key" UNIQUE using index "pairing_codes_owner_id_key";

alter table "public"."plays" add constraint "plays_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON UPDATE CASCADE ON DELETE CASCADE not valid;

alter table "public"."plays" validate constraint "plays_user_id_fkey";

alter table "public"."profiles" add constraint "profiles_id_fkey" FOREIGN KEY (id) REFERENCES auth.users(id) ON UPDATE CASCADE ON DELETE CASCADE not valid;

alter table "public"."profiles" validate constraint "profiles_id_fkey";

alter table "public"."profiles" add constraint "profiles_partner_id_fkey" FOREIGN KEY (partner_id) REFERENCES auth.users(id) ON UPDATE CASCADE ON DELETE CASCADE not valid;

alter table "public"."profiles" validate constraint "profiles_partner_id_fkey";

alter table "public"."profiles" add constraint "profiles_partner_id_key" UNIQUE using index "profiles_partner_id_key";

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

  DELETE FROM pairing_codes WHERE id = pairing_code;
END;
$function$
;

grant delete on table "public"."pairing_codes" to "anon";

grant insert on table "public"."pairing_codes" to "anon";

grant references on table "public"."pairing_codes" to "anon";

grant select on table "public"."pairing_codes" to "anon";

grant trigger on table "public"."pairing_codes" to "anon";

grant truncate on table "public"."pairing_codes" to "anon";

grant update on table "public"."pairing_codes" to "anon";

grant delete on table "public"."pairing_codes" to "authenticated";

grant insert on table "public"."pairing_codes" to "authenticated";

grant references on table "public"."pairing_codes" to "authenticated";

grant select on table "public"."pairing_codes" to "authenticated";

grant trigger on table "public"."pairing_codes" to "authenticated";

grant truncate on table "public"."pairing_codes" to "authenticated";

grant update on table "public"."pairing_codes" to "authenticated";

grant delete on table "public"."pairing_codes" to "service_role";

grant insert on table "public"."pairing_codes" to "service_role";

grant references on table "public"."pairing_codes" to "service_role";

grant select on table "public"."pairing_codes" to "service_role";

grant trigger on table "public"."pairing_codes" to "service_role";

grant truncate on table "public"."pairing_codes" to "service_role";

grant update on table "public"."pairing_codes" to "service_role";

grant delete on table "public"."plays" to "anon";

grant insert on table "public"."plays" to "anon";

grant references on table "public"."plays" to "anon";

grant select on table "public"."plays" to "anon";

grant trigger on table "public"."plays" to "anon";

grant truncate on table "public"."plays" to "anon";

grant update on table "public"."plays" to "anon";

grant delete on table "public"."plays" to "authenticated";

grant insert on table "public"."plays" to "authenticated";

grant references on table "public"."plays" to "authenticated";

grant select on table "public"."plays" to "authenticated";

grant trigger on table "public"."plays" to "authenticated";

grant truncate on table "public"."plays" to "authenticated";

grant update on table "public"."plays" to "authenticated";

grant delete on table "public"."plays" to "service_role";

grant insert on table "public"."plays" to "service_role";

grant references on table "public"."plays" to "service_role";

grant select on table "public"."plays" to "service_role";

grant trigger on table "public"."plays" to "service_role";

grant truncate on table "public"."plays" to "service_role";

grant update on table "public"."plays" to "service_role";

grant delete on table "public"."profiles" to "anon";

grant insert on table "public"."profiles" to "anon";

grant references on table "public"."profiles" to "anon";

grant select on table "public"."profiles" to "anon";

grant trigger on table "public"."profiles" to "anon";

grant truncate on table "public"."profiles" to "anon";

grant update on table "public"."profiles" to "anon";

grant delete on table "public"."profiles" to "authenticated";

grant insert on table "public"."profiles" to "authenticated";

grant references on table "public"."profiles" to "authenticated";

grant select on table "public"."profiles" to "authenticated";

grant trigger on table "public"."profiles" to "authenticated";

grant truncate on table "public"."profiles" to "authenticated";

grant update on table "public"."profiles" to "authenticated";

grant delete on table "public"."profiles" to "service_role";

grant insert on table "public"."profiles" to "service_role";

grant references on table "public"."profiles" to "service_role";

grant select on table "public"."profiles" to "service_role";

grant trigger on table "public"."profiles" to "service_role";

grant truncate on table "public"."profiles" to "service_role";

grant update on table "public"."profiles" to "service_role";

create policy "Enable delete for users to their own pairing code"
on "public"."pairing_codes"
as permissive
for delete
to authenticated
using ((( SELECT auth.uid() AS uid) = owner_id));


create policy "Enable select for users to their own pairing codes"
on "public"."pairing_codes"
as permissive
for select
to authenticated
using ((( SELECT auth.uid() AS uid) = owner_id));


create policy "Enable users to create pairing codes for themselves"
on "public"."pairing_codes"
as permissive
for insert
to authenticated
with check ((( SELECT auth.uid() AS uid) = owner_id));


create policy "Enable users to view their own and their partners plays"
on "public"."plays"
as permissive
for select
to public
using (((( SELECT auth.uid() AS uid) = user_id) OR (( SELECT profiles.partner_id
   FROM profiles
  WHERE (profiles.id = ( SELECT auth.uid() AS uid))) = user_id)));


create policy "Enable users to view their own data and their partners data"
on "public"."profiles"
as permissive
for select
to authenticated
using (((( SELECT auth.uid() AS uid) = id) OR ((( SELECT auth.uid() AS uid) IS NOT NULL) AND (( SELECT auth.uid() AS uid) = partner_id))));



