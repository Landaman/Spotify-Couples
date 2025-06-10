CREATE TABLE public.profiles (
  id uuid NOT NULL PRIMARY KEY REFERENCES auth.users (id) ON UPDATE CASCADE ON DELETE CASCADE,
  name text NOT NULL,
  spotify_id text NOT NULL,
  picture_url text
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable users to view their own data and their partners data" ON public.profiles FOR
SELECT
  TO authenticated USING (
    (
      (
        (
          SELECT
            auth.uid ()
        ) = id
      )
      OR (
        (
          SELECT
            public.get_partner_id ()
        ) = id
      )
    )
  );

-- Ensure that each created user has a profile
CREATE FUNCTION private.handle_new_user () RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET
  search_path = '' AS $$
BEGIN
    INSERT INTO public.profiles (id, name, spotify_id, picture_url)
        VALUES (NEW.id, NEW.raw_user_meta_data ->> 'name', NEW.raw_user_meta_data ->> 'provider_id', NEW.raw_user_meta_data ->> 'picture');
    RETURN NEW;
END;
$$;

-- HACK: this doesn't actually do anything, since this is on the auth
-- table. It is shown here for clarity
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users FOR EACH ROW
EXECUTE PROCEDURE private.handle_new_user ();
