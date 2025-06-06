CREATE SCHEMA IF NOT EXISTS public;

-- This must be if not exists since this is the default schema
CREATE SCHEMA private;

ALTER DEFAULT privileges IN SCHEMA private
REVOKE
EXECUTE ON functions
FROM
  public;

-- Allow aggregates BUT enforce a query upper limit, as recommended by the PG docs
-- HACK: the next two statements do nothing, create a real migration to edit them
ALTER ROLE authenticator
SET
  pgrst.db_aggregates_enabled = 'true';

ALTER USER authenticator
SET
  plan_filter.statement_cost_limit = 1e7;

ALTER DEFAULT privileges IN SCHEMA private
REVOKE
EXECUTE ON functions
FROM
  anon,
  authenticated;
