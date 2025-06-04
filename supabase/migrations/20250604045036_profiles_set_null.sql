alter table "public"."profiles" drop constraint "profiles_partner_id_fkey";

alter table "public"."profiles" add constraint "profiles_partner_id_fkey" FOREIGN KEY (partner_id) REFERENCES auth.users(id) ON UPDATE CASCADE ON DELETE SET NULL not valid;

alter table "public"."profiles" validate constraint "profiles_partner_id_fkey";


