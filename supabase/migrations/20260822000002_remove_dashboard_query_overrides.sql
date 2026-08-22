ALTER ROLE authenticator RESET pgrst.db_aggregates_enabled;
ALTER ROLE authenticator RESET plan_filter.statement_cost_limit;

NOTIFY pgrst, 'reload config';
