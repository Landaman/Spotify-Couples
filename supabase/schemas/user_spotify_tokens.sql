CREATE FUNCTION public.process_spotify_refresh_token(refresh_token TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY definer
SET search_path = ''
AS $$
DECLARE
  secret_name TEXT;
BEGIN
  secret_name := (SELECT auth.uid()) || '_spotify_code';

  -- This ensures the token is updated, since the processor should
  -- clear this secret if needed
  IF NOT EXISTS(SELECT * FROM vault.secrets WHERE name = secret_name)
  THEN
    PERFORM vault.create_secret(refresh_token, secret_name);
  END IF;
END;
$$;

-- HACK: this doesn't do anything here. It is shown for clarity.
-- to edit this, manually create a migration
REVOKE EXECUTE ON FUNCTION public.process_spotify_refresh_token FROM public;
REVOKE EXECUTE ON FUNCTION public.process_spotify_refresh_token FROM anon;
