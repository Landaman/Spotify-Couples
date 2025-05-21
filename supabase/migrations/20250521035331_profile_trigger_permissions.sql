-- HACK: this doesn't do anything here. It is shown for clarity.
-- to edit this, manually create a migration
REVOKE EXECUTE ON FUNCTION public.handle_new_user FROM public;
REVOKE EXECUTE ON FUNCTION public.handle_new_user FROM anon;
