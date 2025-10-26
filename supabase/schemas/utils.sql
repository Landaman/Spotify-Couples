CREATE FUNCTION private.set_http_parallel_hints () RETURNS void LANGUAGE plpgsql
SET
  search_path = '' AS $$
BEGIN
  -- Make the query planner think parallel is free, since the bounds are networking in this function, this is basically true
  -- Local rolls it back after the transaction regardless of the outcome
  SET LOCAL max_parallel_workers_per_gather = 50;
  SET LOCAL parallel_setup_cost = 0;
  SET LOCAL parallel_tuple_cost = 0;
END;
$$;

CREATE FUNCTION private.unset_http_parallel_hints () RETURNS void LANGUAGE plpgsql
SET
  search_path = '' AS $$
BEGIN
  -- Reset to default values
  -- Local rolls it back after the transaction regardless of the outcome
  SET LOCAL max_parallel_workers_per_gather TO DEFAULT;
  SET LOCAL parallel_setup_cost TO DEFAULT;
  SET LOCAL parallel_tuple_cost TO DEFAULT;
END;
$$;
