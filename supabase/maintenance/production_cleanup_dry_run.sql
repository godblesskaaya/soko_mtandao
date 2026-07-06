-- Production cleanup dry run for Soko Mtandao.
--
-- Purpose:
--   Surface likely test/demo data before converting the current Supabase
--   project into the long-lived production project.
--
-- Safety:
--   This script only creates temporary tables and SELECTs counts/details.
--   It does not DELETE or UPDATE anything.
--
-- Usage:
--   psql "$PRODUCTION_DB_URL" -v ON_ERROR_STOP=1 -f supabase/maintenance/production_cleanup_dry_run.sql
--
-- Next step after review:
--   Copy the reviewed IDs into a separate, explicit cleanup script and run it
--   inside a transaction with a backup taken immediately beforehand.

begin;
set local role postgres;
set local statement_timeout = '30s';

create temp table cleanup_candidate_users as
select
  u.id,
  u.email,
  u.created_at,
  u.last_sign_in_at,
  case
    when u.email ilike '%test%' then 'email contains test'
    when u.email ilike '%demo%' then 'email contains demo'
    when u.email ilike '%sandbox%' then 'email contains sandbox'
    when u.email ilike '%example.%' then 'email contains example domain'
    when u.email ilike '%@mailinator.%' then 'mailinator domain'
    when u.email ilike '%@example.%' then 'example domain'
    else 'manual review'
  end as candidate_reason
from auth.users u
where
  u.email ilike '%test%'
  or u.email ilike '%demo%'
  or u.email ilike '%sandbox%'
  or u.email ilike '%example.%'
  or u.email ilike '%@mailinator.%'
  or u.email ilike '%@example.%';

create temp table cleanup_candidate_hotels as
select
  h.id,
  h.name,
  h.manager_user_id,
  h.created_at,
  case
    when h.name ilike '%test%' then 'name contains test'
    when h.name ilike '%demo%' then 'name contains demo'
    when h.name ilike '%sandbox%' then 'name contains sandbox'
    when h.name ilike '%sample%' then 'name contains sample'
    when h.manager_user_id in (select id from cleanup_candidate_users) then 'manager is candidate user'
    else 'manual review'
  end as candidate_reason
from public.hotels h
where
  h.name ilike '%test%'
  or h.name ilike '%demo%'
  or h.name ilike '%sandbox%'
  or h.name ilike '%sample%'
  or h.manager_user_id in (select id from cleanup_candidate_users);

create temp table cleanup_candidate_bookings as
select
  b.id,
  b.ticket_number,
  b.hotel_id,
  b.user_id,
  b.customer_email,
  b.customer_phone,
  b.status,
  b.payment_status,
  b.created_at,
  case
    when b.user_id in (select id from cleanup_candidate_users) then 'booking user is candidate user'
    when b.hotel_id in (select id from cleanup_candidate_hotels) then 'booking hotel is candidate hotel'
    when b.customer_email ilike '%test%' then 'customer email contains test'
    when b.customer_email ilike '%demo%' then 'customer email contains demo'
    when b.customer_email ilike '%sandbox%' then 'customer email contains sandbox'
    when b.customer_email ilike '%example.%' then 'customer email contains example domain'
    else 'manual review'
  end as candidate_reason
from public.bookings b
where
  b.user_id in (select id from cleanup_candidate_users)
  or b.hotel_id in (select id from cleanup_candidate_hotels)
  or b.customer_email ilike '%test%'
  or b.customer_email ilike '%demo%'
  or b.customer_email ilike '%sandbox%'
  or b.customer_email ilike '%example.%';

create temp table cleanup_candidate_payments as
select
  p.id,
  p.booking_id,
  p.external_id,
  p.payment_gateway_ref,
  p.status,
  p.provider_status,
  p.amount,
  p.currency,
  p.created_at,
  case
    when p.booking_id in (select id from cleanup_candidate_bookings) then 'payment booking is candidate booking'
    when coalesce(p.azampay_response::text, '') ilike '%sandbox%' then 'provider payload mentions sandbox'
    when coalesce(p.metadata::text, '') ilike '%sandbox%' then 'metadata mentions sandbox'
    when coalesce(p.external_id, '') ilike '%test%' then 'external id contains test'
    when coalesce(p.external_id, '') ilike '%demo%' then 'external id contains demo'
    else 'manual review'
  end as candidate_reason
from public.payments p
where
  p.booking_id in (select id from cleanup_candidate_bookings)
  or coalesce(p.azampay_response::text, '') ilike '%sandbox%'
  or coalesce(p.metadata::text, '') ilike '%sandbox%'
  or coalesce(p.external_id, '') ilike '%test%'
  or coalesce(p.external_id, '') ilike '%demo%';

select 'candidate_users' as bucket, count(*) as rows from cleanup_candidate_users
union all select 'candidate_hotels', count(*) from cleanup_candidate_hotels
union all select 'candidate_bookings', count(*) from cleanup_candidate_bookings
union all select 'candidate_payments', count(*) from cleanup_candidate_payments
union all select 'azampay_token_cache', count(*) from public.azampay_tokens
union all select 'payment_logs', count(*) from public.payment_logs
union all select 'payment_webhook_events', count(*) from public.payment_webhook_events
union all select 'payout_provider_events', count(*) from public.payout_provider_events
order by bucket;

select * from cleanup_candidate_users order by created_at limit 100;
select * from cleanup_candidate_hotels order by created_at limit 100;
select * from cleanup_candidate_bookings order by created_at limit 100;
select * from cleanup_candidate_payments order by created_at limit 100;

rollback;
