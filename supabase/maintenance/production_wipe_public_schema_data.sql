-- Wipe all data from public schema base tables while preserving schema objects.
--
-- Preserves:
--   - table definitions, functions, views, policies, triggers
--   - auth schema data
--   - storage schema metadata and storage object files
--   - Supabase migration history
--
-- Destroys:
--   - every row in every ordinary and partitioned table in public
--
-- Blocked by default. Execute intentionally with:
--
--   psql "$PRODUCTION_DB_URL" -v ON_ERROR_STOP=1 -v execute_wipe=true -f supabase/maintenance/production_wipe_public_schema_data.sql

\if :{?execute_wipe}
\else
\set execute_wipe false
\endif

\if :execute_wipe
\echo 'Public schema data wipe enabled. Proceeding inside one transaction.'
\else
\echo 'Refusing to wipe public schema data. Re-run with -v execute_wipe=true after confirming intent.'
select 1 / 0 as wipe_guard_error;
\endif

begin;
set local role postgres;
set local session_replication_role = replica;
set local statement_timeout = '120s';
set local lock_timeout = '10s';

create temp table public_table_counts_before as
select
  format('%I.%I', schemaname, tablename) as table_name,
  (xpath('/row/c/text()', query_to_xml(format('select count(*) as c from %I.%I', schemaname, tablename), false, true, '')))[1]::text::bigint as row_count
from pg_tables
where schemaname = 'public'
order by tablename;

select 'before' as phase, table_name, row_count
from public_table_counts_before
order by table_name;

do $$
declare
  truncate_targets text;
begin
  select string_agg(format('%I.%I', schemaname, tablename), ', ' order by tablename)
  into truncate_targets
  from pg_tables
  where schemaname = 'public';

  if truncate_targets is null then
    raise notice 'No public tables found.';
  else
    execute 'truncate table ' || truncate_targets || ' restart identity cascade';
  end if;
end $$;

create temp table public_table_counts_after as
select
  format('%I.%I', schemaname, tablename) as table_name,
  (xpath('/row/c/text()', query_to_xml(format('select count(*) as c from %I.%I', schemaname, tablename), false, true, '')))[1]::text::bigint as row_count
from pg_tables
where schemaname = 'public'
order by tablename;

select 'after' as phase, table_name, row_count
from public_table_counts_after
order by table_name;

do $$
declare
  remaining_rows bigint;
begin
  select coalesce(sum(row_count), 0)
  into remaining_rows
  from public_table_counts_after;

  if remaining_rows <> 0 then
    raise exception 'Public schema wipe incomplete: % rows remain', remaining_rows;
  end if;
end $$;

commit;
