CREATE TABLE public.pairings (
  one_uuid uuid NOT NULL UNIQUE REFERENCES auth.users (id) ON UPDATE CASCADE ON DELETE CASCADE,
  two_uuid uuid NOT NULL UNIQUE REFERENCES auth.users (id) ON UPDATE CASCADE ON DELETE CASCADE,
  PRIMARY KEY (one_uuid, two_uuid)
);

ALTER TABLE public.pairings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable users to view their pairing" ON public.pairings FOR
SELECT
  TO authenticated USING (
    (
      (
        SELECT
          auth.uid ()
      ) = one_uuid
    )
    OR (
      (
        SELECT
          auth.uid ()
      ) = two_uuid
    )
  );

CREATE FUNCTION private.check_user_has_one_pairing () RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET
  search_path = '' AS $$
BEGIN
  IF EXISTS (
    SELECT
      1
    FROM
      public.pairings
    WHERE
      one_uuid = NEW.one_uuid
      OR one_uuid = NEW.two_uuid) THEN
  RAISE EXCEPTION 'UUID % already has a pairing', NEW.one_uuid;
END IF;

  IF EXISTS (
    SELECT
      1
    FROM
      public.pairings
    WHERE
      two_uuid = NEW.one_uuid
      OR two_uuid = NEW.two_uuid) THEN
  RAISE EXCEPTION 'UUID % already has a pairing', NEW.one_uuid;
END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER validate_user_has_one_pairing BEFORE INSERT
OR
UPDATE ON public.pairings FOR EACH ROW
EXECUTE FUNCTION private.check_user_has_one_pairing ();

CREATE FUNCTION public.get_partner_id () RETURNS uuid LANGUAGE plpgsql SECURITY INVOKER
SET
  search_path = '' AS $$
BEGIN
  RETURN public.get_partner_id (auth.uid ());
END;
$$;

-- HACK: this doesn't do anything here. It is shown for clarity.
-- to edit this, manually create a migration
REVOKE
EXECUTE ON FUNCTION public.get_partner_id ()
FROM
  public;

REVOKE
EXECUTE ON FUNCTION public.get_partner_id ()
FROM
  anon;

-- This is secure because security invoker. Therefore, we fall back on RLS and you can't get any data you couldn't already get
CREATE FUNCTION public.get_partner_id (search_uuid uuid) RETURNS uuid LANGUAGE plpgsql SECURITY INVOKER
SET
  search_path = 'public' AS $$
BEGIN
  RETURN (
    SELECT
      one_uuid
    FROM
      pairings
    WHERE
      search_uuid = two_uuid
    UNION
    SELECT
      two_uuid
    FROM
      pairings
    WHERE
      one_uuid = search_uuid);
END;
$$;

-- HACK: this doesn't do anything here. It is shown for clarity.
-- to edit this, manually create a migration
REVOKE
EXECUTE ON FUNCTION public.get_partner_id (uuid)
FROM
  public;

REVOKE
EXECUTE ON FUNCTION public.get_partner_id (uuid)
FROM
  anon;
