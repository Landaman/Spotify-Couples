set
  check_function_bodies = off;

CREATE OR REPLACE FUNCTION private.check_user_has_one_pairing () RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET
  search_path TO '' AS $function$
BEGIN
  IF EXISTS (SELECT 1 FROM public.pairings WHERE one_uuid = NEW.one_uuid OR one_uuid = NEW.two_uuid) THEN
    RAISE EXCEPTION 'UUID % already has a pairing', NEW.one_uuid;
  END IF;

  IF EXISTS (SELECT 1 FROM public.pairings WHERE two_uuid = NEW.one_uuid OR two_uuid = NEW.two_uuid) THEN
    RAISE EXCEPTION 'UUID % already has a pairing', NEW.one_uuid;
  END IF;

  RETURN NEW;
END;
$function$;

drop policy "Enable users to view their own and their partners plays" on "public"."plays";

drop policy "Enable users to view their own data and their partners data" on "public"."profiles";

alter table "public"."profiles"
drop constraint "profiles_partner_id_fkey";

alter table "public"."profiles"
drop constraint "profiles_partner_id_key";

drop index if exists "public"."profiles_partner_id_key";

create table "public"."pairings" (
  "one_uuid" uuid not null,
  "two_uuid" uuid not null
);

alter table "public"."pairings" enable row level security;

DO $$
    DECLARE
        profile public.profiles;
    BEGIN
        FOR profile in (SELECT * FROM public.profiles)
        LOOP
            IF NOT EXISTS(SELECT 1 FROM public.pairings WHERE one_uuid = profile.id OR two_uuid = profile.id) AND profile.partner_id IS NOT NULL THEN
                INSERT INTO public.pairings(one_uuid, two_uuid) VALUES (profile.id, profile.partner_id);
            END IF;
        END LOOP;
    END;
$$;

alter table "public"."profiles"
drop column "partner_id";

CREATE UNIQUE INDEX pairings_one_uuid_key ON public.pairings USING btree (one_uuid);

CREATE UNIQUE INDEX pairings_pkey ON public.pairings USING btree (one_uuid, two_uuid);

CREATE UNIQUE INDEX pairings_two_uuid_key ON public.pairings USING btree (two_uuid);

alter table "public"."pairings"
add constraint "pairings_pkey" PRIMARY KEY using index "pairings_pkey";

alter table "public"."pairings"
add constraint "pairings_one_uuid_fkey" FOREIGN KEY (one_uuid) REFERENCES auth.users (id) ON UPDATE CASCADE ON DELETE CASCADE not valid;

alter table "public"."pairings" validate constraint "pairings_one_uuid_fkey";

alter table "public"."pairings"
add constraint "pairings_one_uuid_key" UNIQUE using index "pairings_one_uuid_key";

alter table "public"."pairings"
add constraint "pairings_two_uuid_fkey" FOREIGN KEY (two_uuid) REFERENCES auth.users (id) ON UPDATE CASCADE ON DELETE CASCADE not valid;

alter table "public"."pairings" validate constraint "pairings_two_uuid_fkey";

alter table "public"."pairings"
add constraint "pairings_two_uuid_key" UNIQUE using index "pairings_two_uuid_key";

set
  check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.get_partner_id () RETURNS uuid LANGUAGE plpgsql
SET
  search_path TO '' AS $function$
BEGIN
  RETURN public.get_partner_id(auth.uid());
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_partner_id (search_uuid uuid) RETURNS uuid LANGUAGE plpgsql
SET
  search_path TO 'public' AS $function$
BEGIN
  RETURN (select one_uuid from pairings where search_uuid = two_uuid UNION select two_uuid from pairings where one_uuid = search_uuid);
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_or_create_pairing_code () RETURNS pairing_codes LANGUAGE plpgsql SECURITY DEFINER
SET
  search_path TO 'public' AS $function$
DECLARE
    result pairing_codes;
    done bool := FALSE;
BEGIN
    IF (SELECT public.get_partner_id()) IS NOT NULL THEN
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
$function$;

CREATE OR REPLACE FUNCTION public.pair_with_code (pairing_code character varying) RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET
  search_path TO 'public' AS $function$
DECLARE
    code_expiry timestamptz;
    code_owner_id uuid;
BEGIN
    IF (SELECT public.get_partner_id()) IS NOT NULL THEN
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

        -- This handles the case where the code DNE and the auth.uid() does due to the role restrictions below
        IF code_owner_id = auth.uid () THEN
            RAISE EXCEPTION 'InvalidPairingCodeException'
                USING DETAIL = 'Unable to pair with a code the user owns';
            END IF;

            IF NOT FOUND OR code_expiry < NOW() THEN
                RAISE EXCEPTION 'InvalidPairingCodeException'
                    USING DETAIL = 'Unable to pair with a pairing code that does not exist or is expired';
                END IF;

                IF (SELECT public.get_partner_id(code_owner_id)) IS NOT NULL THEN
                    RAISE EXCEPTION 'InvalidPairingCodeException'
                        USING DETAIL = 'Unable to pair with a pairing code that does not exist or is expired';
                    END IF;

                    INSERT INTO public.pairings (one_uuid, two_uuid) VALUES (auth.uid(), code_owner_id);

                    PERFORM
                        realtime.send (jsonb_build_object(), 'paired', 'pairing_codes:' || pairing_code, TRUE); -- this means private, i.e., RLS required for access

                    DELETE FROM pairing_codes
                    WHERE code = pairing_code;
END;
$function$;

grant delete on table "public"."pairings" to "anon";

grant insert on table "public"."pairings" to "anon";

grant references on table "public"."pairings" to "anon";

grant
select
  on table "public"."pairings" to "anon";

grant trigger on table "public"."pairings" to "anon";

grant
truncate on table "public"."pairings" to "anon";

grant
update on table "public"."pairings" to "anon";

grant delete on table "public"."pairings" to "authenticated";

grant insert on table "public"."pairings" to "authenticated";

grant references on table "public"."pairings" to "authenticated";

grant
select
  on table "public"."pairings" to "authenticated";

grant trigger on table "public"."pairings" to "authenticated";

grant
truncate on table "public"."pairings" to "authenticated";

grant
update on table "public"."pairings" to "authenticated";

grant delete on table "public"."pairings" to "service_role";

grant insert on table "public"."pairings" to "service_role";

grant references on table "public"."pairings" to "service_role";

grant
select
  on table "public"."pairings" to "service_role";

grant trigger on table "public"."pairings" to "service_role";

grant
truncate on table "public"."pairings" to "service_role";

grant
update on table "public"."pairings" to "service_role";

create policy "Enable users to view their pairing" on "public"."pairings" as permissive for
select
  to authenticated using (
    (
      (
        (
          SELECT
            auth.uid () AS uid
        ) = one_uuid
      )
      OR (
        (
          SELECT
            auth.uid () AS uid
        ) = two_uuid
      )
    )
  );

create policy "Enable users to view their own and their partners plays" on "public"."plays" as permissive for
select
  to public using (
    (
      (
        (
          SELECT
            auth.uid () AS uid
        ) = user_id
      )
      OR (
        (
          SELECT
            get_partner_id () AS get_partner_id
        ) = user_id
      )
    )
  );

create policy "Enable users to view their own data and their partners data" on "public"."profiles" as permissive for
select
  to authenticated using (
    (
      (
        (
          SELECT
            auth.uid () AS uid
        ) = id
      )
      OR (
        (
          SELECT
            get_partner_id () AS get_partner_id
        ) = id
      )
    )
  );

CREATE TRIGGER validate_user_has_one_pairing BEFORE INSERT
OR
UPDATE ON public.pairings FOR EACH ROW
EXECUTE FUNCTION private.check_user_has_one_pairing ();

REVOKE
EXECUTE ON FUNCTION public.get_partner_id ()
FROM
  public;

REVOKE
EXECUTE ON FUNCTION public.get_partner_id ()
FROM
  anon;

REVOKE
EXECUTE ON FUNCTION public.get_partner_id (uuid)
FROM
  public;

REVOKE
EXECUTE ON FUNCTION public.get_partner_id (uuid)
FROM
  anon;
