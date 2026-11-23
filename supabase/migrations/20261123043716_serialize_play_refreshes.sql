CREATE FUNCTION private.play_refresh_lock_key (requesting_user_id uuid) RETURNS bigint LANGUAGE sql IMMUTABLE STRICT
SET
  search_path = '' AS $$
  SELECT
    hashtextextended('spotify-play-refresh:' || requesting_user_id::text, 0);
$$;

CREATE OR REPLACE FUNCTION private.read_plays_for_all_users () RETURNS void LANGUAGE plpgsql
SET
  search_path = '' AS $$
DECLARE
  requesting_user_ids uuid[];
BEGIN
  -- Skip busy users so the rest of the batch can keep its scheduled refresh
  SELECT
    array_agg(id)
  INTO
    requesting_user_ids
  FROM
    auth.users
  WHERE
    pg_try_advisory_xact_lock(private.play_refresh_lock_key (id));
  IF requesting_user_ids IS NOT NULL THEN
    PERFORM
      private.get_new_plays_for_users (requesting_user_ids);
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.read_plays_for_user_if_needed () RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER
SET
  search_path = '' AS $$
DECLARE
  requesting_user_id uuid := auth.uid ();
BEGIN
  IF requesting_user_id IS NULL THEN
    RETURN FALSE;
  END IF;
  -- Wait for any current import before rechecking freshness or reading the cursor
  PERFORM
    pg_advisory_xact_lock(private.play_refresh_lock_key (requesting_user_id));
  IF NOT private.user_needs_play_refresh (requesting_user_id) THEN
    -- If no need to refresh, that means they recently refreshed successfully so they're good
    RETURN TRUE;
  END IF;
  -- Now try to refresh
  RETURN EXISTS (
    SELECT
      1
    FROM
      private.get_new_plays_for_users (ARRAY[requesting_user_id]) AS refreshed_users
    WHERE
      -- This happens when they refreshed successfully, so if they're not in the array, they didn't
      refreshed_users = requesting_user_id);
END;
$$;
