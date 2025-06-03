set
  check_function_bodies = off;

CREATE OR REPLACE FUNCTION private.read_plays_for_all_users () RETURNS void LANGUAGE plpgsql
SET
  search_path TO '' AS $procedure$
DECLARE
    user_id uuid;
BEGIN
    FOR user_id IN SELECT id FROM auth.users
    LOOP
        -- This implicitly creates a subtransaction, so others can succeed when this fails
        BEGIN
            PERFORM private.get_new_plays_for_user(user_id);
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE 'Failed to process user %: %', user_id, SQLERRM; -- This makes sure the errors comes up in the supabase logs
        END;
    END LOOP;
END;
$procedure$;

SELECT
  cron.schedule (
    'Read plays every 15 minutes',
    '*/15 * * * *',
    'SELECT private.read_plays_for_all_users()'
  );
