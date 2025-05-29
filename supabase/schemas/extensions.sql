-- HACK: this file does absolutely nothing, it is here for clarity.
-- Write any changes to this manually
CREATE EXTENSION pg_cron
WITH
  SCHEMA pg_catalog;

GRANT USAGE ON SCHEMA cron TO postgres;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA cron TO postgres;

CREATE EXTENSION http
WITH
  SCHEMA extensions;
