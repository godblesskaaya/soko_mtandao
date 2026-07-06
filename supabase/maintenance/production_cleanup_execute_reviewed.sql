-- Guarded production cleanup for reviewed test/demo records.
--
-- This script is intentionally blocked by default. Run the dry-run first:
--
--   psql "$PRODUCTION_DB_URL" -v ON_ERROR_STOP=1 -f supabase/maintenance/production_cleanup_dry_run.sql
--
-- After reviewing the candidate IDs, execute with:
--
--   psql "$PRODUCTION_DB_URL" -v ON_ERROR_STOP=1 -v execute_cleanup=true -f supabase/maintenance/production_cleanup_execute_reviewed.sql
--
-- Current candidate rules:
--   - bookings with example/test/demo/sandbox customer emails,
--   - payments attached to those bookings,
--   - payments whose provider payload/metadata mentions sandbox,
--   - dependent financial/log rows linked to those bookings/payments.
--
-- Users and hotels are not deleted by this script.

\if :{?execute_cleanup}
\else
\set execute_cleanup false
\endif

\if :execute_cleanup
\echo 'Cleanup execution enabled. Proceeding inside one transaction.'
\else
\echo 'Refusing to run destructive cleanup. Re-run with -v execute_cleanup=true after reviewing dry-run output.'
select 1 / 0 as cleanup_guard_error;
\endif

begin;
set local role postgres;
set local session_replication_role = replica;
set local statement_timeout = '60s';
set local lock_timeout = '10s';

create temp table cleanup_candidate_bookings as
select b.id
from public.bookings b
where
  b.customer_email ilike '%test%'
  or b.customer_email ilike '%demo%'
  or b.customer_email ilike '%sandbox%'
  or b.customer_email ilike '%example.%';

create temp table cleanup_candidate_payments as
select p.id
from public.payments p
where
  p.booking_id in (select id from cleanup_candidate_bookings)
  or coalesce(p.azampay_response::text, '') ilike '%sandbox%'
  or coalesce(p.metadata::text, '') ilike '%sandbox%'
  or coalesce(p.external_id, '') ilike '%test%'
  or coalesce(p.external_id, '') ilike '%demo%';

create temp table cleanup_candidate_booking_items as
select bi.id
from public.booking_items bi
where bi.booking_id in (select id from cleanup_candidate_bookings);

create temp table cleanup_candidate_settlements as
select s.id
from public.settlements s
where
  s.payment_id in (select id from cleanup_candidate_payments)
  or s.booking_item_id in (select id from cleanup_candidate_booking_items);

create temp table cleanup_candidate_payout_items as
select pi.id
from public.payout_items pi
where pi.settlement_id in (select id from cleanup_candidate_settlements);

select 'bookings_to_delete' as bucket, count(*) as rows from cleanup_candidate_bookings
union all select 'payments_to_delete', count(*) from cleanup_candidate_payments
union all select 'booking_items_to_delete', count(*) from cleanup_candidate_booking_items
union all select 'settlements_to_delete', count(*) from cleanup_candidate_settlements
union all select 'payout_items_to_delete', count(*) from cleanup_candidate_payout_items
order by bucket;

delete from public.payout_provider_events
where payout_item_id in (select id from cleanup_candidate_payout_items);

delete from public.financial_components
where
  booking_id in (select id from cleanup_candidate_bookings)
  or payment_id in (select id from cleanup_candidate_payments)
  or settlement_id in (select id from cleanup_candidate_settlements);

delete from public.ledger_entries
where
  booking_id in (select id from cleanup_candidate_bookings)
  or booking_item_id in (select id from cleanup_candidate_booking_items)
  or payment_id in (select id from cleanup_candidate_payments)
  or settlement_id in (select id from cleanup_candidate_settlements);

delete from public.payment_reconciliation_events
where
  booking_id in (select id from cleanup_candidate_bookings)
  or payment_id in (select id from cleanup_candidate_payments);

delete from public.payment_webhook_events
where
  booking_id in (select id from cleanup_candidate_bookings)
  or payment_id in (select id from cleanup_candidate_payments);

delete from public.payment_logs
where booking_id in (select id from cleanup_candidate_bookings);

delete from public.refunds
where
  booking_id in (select id from cleanup_candidate_bookings)
  or payment_id in (select id from cleanup_candidate_payments);

delete from public.disputes
where booking_id in (select id from cleanup_candidate_bookings);

delete from public.reviews
where booking_id in (select id from cleanup_candidate_bookings);

delete from public.room_statuses
where booking_id in (select id from cleanup_candidate_bookings);

delete from public.payout_items
where id in (select id from cleanup_candidate_payout_items);

delete from public.settlements
where id in (select id from cleanup_candidate_settlements);

delete from public.booking_item_financials
where
  booking_id in (select id from cleanup_candidate_bookings)
  or booking_item_id in (select id from cleanup_candidate_booking_items);

delete from public.booking_items
where id in (select id from cleanup_candidate_booking_items);

delete from public.payments
where id in (select id from cleanup_candidate_payments);

delete from public.bookings
where id in (select id from cleanup_candidate_bookings);

delete from public.azampay_tokens;

commit;
