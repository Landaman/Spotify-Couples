create schema if not exists "private";

alter default privileges in schema private revoke execute on functions from public;
alter default privileges in schema private revoke execute on functions from anon, authenticated;


