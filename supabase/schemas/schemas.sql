CREATE SCHEMA IF NOT EXISTS public;

-- This must be if not exists since this is the default schema
CREATE SCHEMA private;

ALTER DEFAULT privileges IN SCHEMA private REVOKE EXECUTE ON functions FROM public;

ALTER DEFAULT privileges IN SCHEMA private REVOKE EXECUTE ON functions FROM anon, authenticated;

