

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgjwt" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."pair_with_code"("pairing_code" character varying) RETURNS "void"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$DECLARE
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
END;$$;


ALTER FUNCTION "public"."pair_with_code"("pairing_code" character varying) OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."pairing_codes" (
    "code" character varying NOT NULL,
    "expires_at" timestamp with time zone NOT NULL,
    "owner_id" "uuid" NOT NULL
);


ALTER TABLE "public"."pairing_codes" OWNER TO "postgres";


COMMENT ON TABLE "public"."pairing_codes" IS 'Pairing codes that are currently live on the site';



CREATE TABLE IF NOT EXISTS "public"."plays" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "played_date_time" timestamp with time zone NOT NULL,
    "spotify_played_context_uri" "text",
    "spotify_id" "text" NOT NULL,
    "user_id" "uuid" NOT NULL
);


ALTER TABLE "public"."plays" OWNER TO "postgres";


COMMENT ON TABLE "public"."plays" IS 'Plays that come from users Spotify accounts';



CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "display_name" "text" NOT NULL,
    "profile_picture_url" "text",
    "id" "uuid" NOT NULL,
    "partner_id" "uuid"
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


COMMENT ON TABLE "public"."profiles" IS 'Frontend facing profiles of users on the site';



ALTER TABLE ONLY "public"."pairing_codes"
    ADD CONSTRAINT "pairing_codes_owner_id_key" UNIQUE ("owner_id");



ALTER TABLE ONLY "public"."pairing_codes"
    ADD CONSTRAINT "pairing_codes_pkey" PRIMARY KEY ("code");



ALTER TABLE ONLY "public"."plays"
    ADD CONSTRAINT "plays_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "users_partner_id_key" UNIQUE ("partner_id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");



CREATE INDEX "plays_user_id_idx" ON "public"."plays" USING "btree" ("user_id");



ALTER TABLE ONLY "public"."pairing_codes"
    ADD CONSTRAINT "pairing_codes_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "auth"."users"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."plays"
    ADD CONSTRAINT "plays_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "users_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "users_partner_id_fkey" FOREIGN KEY ("partner_id") REFERENCES "auth"."users"("id") ON UPDATE CASCADE ON DELETE CASCADE;



CREATE POLICY "Enable delete for users to their own pairing code" ON "public"."pairing_codes" FOR DELETE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "owner_id"));



CREATE POLICY "Enable select for users to their own pairing codes" ON "public"."pairing_codes" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "owner_id"));



CREATE POLICY "Enable users to create pairing codes for themselves" ON "public"."pairing_codes" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "owner_id"));



CREATE POLICY "Enable users to view their own and their partners plays" ON "public"."plays" FOR SELECT USING (((( SELECT "auth"."uid"() AS "uid") = "user_id") OR (( SELECT "profiles"."partner_id"
   FROM "public"."profiles"
  WHERE ("profiles"."id" = ( SELECT "auth"."uid"() AS "uid"))) = "user_id")));



CREATE POLICY "Enable users to view their own data and their partners data" ON "public"."profiles" FOR SELECT TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "id") OR ((( SELECT "auth"."uid"() AS "uid") IS NOT NULL) AND (( SELECT "auth"."uid"() AS "uid") = "partner_id"))));



ALTER TABLE "public"."pairing_codes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."plays" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."pairing_codes";



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";











































































































































































GRANT ALL ON FUNCTION "public"."pair_with_code"("pairing_code" character varying) TO "anon";
GRANT ALL ON FUNCTION "public"."pair_with_code"("pairing_code" character varying) TO "authenticated";
GRANT ALL ON FUNCTION "public"."pair_with_code"("pairing_code" character varying) TO "service_role";


















GRANT ALL ON TABLE "public"."pairing_codes" TO "anon";
GRANT ALL ON TABLE "public"."pairing_codes" TO "authenticated";
GRANT ALL ON TABLE "public"."pairing_codes" TO "service_role";



GRANT ALL ON TABLE "public"."plays" TO "anon";
GRANT ALL ON TABLE "public"."plays" TO "authenticated";
GRANT ALL ON TABLE "public"."plays" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "service_role";






























RESET ALL;
