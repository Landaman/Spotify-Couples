CREATE TABLE public.profiles (
    id UUID NOT NULL PRIMARY KEY 
	    REFERENCES auth.users(id) ON UPDATE CASCADE ON DELETE CASCADE,
    partner_id UUID UNIQUE
		REFERENCES auth.users(id) ON UPDATE CASCADE ON DELETE CASCADE,
    name TEXT NOT NULL,
    spotify_id TEXT NOT NULL,
    picture_url TEXT
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable users to view their own data and their partners data" 
ON public.profiles 
FOR SELECT 
TO authenticated 
USING (
	    ((( SELECT auth.uid() ) = id) OR ((( SELECT auth.uid() ) IS NOT NULL) AND (( SELECT auth.uid() ) = partner_id)))
);

-- Ensure that each created user has a profile
CREATE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY definer 
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.profiles (id, name, spotify_id, picture_url)
  VALUES (new.id, new.raw_user_meta_data ->> 'name', new.raw_user_meta_data ->> 'provider_id', new.raw_user_meta_data ->> 'picture');
  RETURN NEW;
END;
$$;

-- HACK: this doesn't do anything here. It is shown for clarity.
-- to edit this, manually create a migration
REVOKE EXECUTE ON FUNCTION public.handle_new_user FROM public;
REVOKE EXECUTE ON FUNCTION public.handle_new_user FROM anon;

-- HACK: this doesn't actually do anything, since this is on the auth
-- table. It is shown here for clarity
CREATE TRIGGER on_auth_user_created
  AFTER INSERT on auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
