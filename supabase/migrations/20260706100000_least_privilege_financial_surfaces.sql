-- Tighten financial lifecycle grants that were left broad during earlier hardening.

BEGIN;

REVOKE ALL PRIVILEGES ON TABLE
  public.payment_reconciliation_events,
  public.payout_provider_events,
  public.financial_components,
  public.payment_provider_fee_policies,
  public.hotel_commission_policies,
  public.booking_item_financials,
  public.payout_batches,
  public.hotel_payout_accounts,
  public.payout_items,
  public.payment_webhook_events,
  public.ledger_entries,
  public.refunds
FROM anon, authenticated;

GRANT ALL ON TABLE
  public.payment_reconciliation_events,
  public.payout_provider_events,
  public.financial_components,
  public.payment_provider_fee_policies,
  public.hotel_commission_policies,
  public.booking_item_financials,
  public.payout_batches,
  public.hotel_payout_accounts,
  public.payout_items,
  public.payment_webhook_events,
  public.ledger_entries,
  public.refunds
TO service_role;

REVOKE ALL PRIVILEGES ON TABLE
  public.hotel_wallet_balances_view,
  public.hotel_booking_financial_breakdown_view,
  public.hotel_financial_summary_view,
  public.platform_financial_summary_view,
  public.hotel_wallet_transactions_view,
  public.manager_hotel_payments_view
FROM anon;

GRANT SELECT ON TABLE
  public.hotel_wallet_balances_view,
  public.hotel_booking_financial_breakdown_view,
  public.hotel_financial_summary_view,
  public.hotel_wallet_transactions_view,
  public.manager_hotel_payments_view
TO authenticated;

GRANT SELECT ON TABLE public.platform_financial_summary_view TO authenticated;

REVOKE ALL ON FUNCTION public.mark_booking_payment_initiated(uuid, uuid, integer)
FROM anon, authenticated;
REVOKE ALL ON FUNCTION public.finalize_paid_booking(uuid, uuid, numeric)
FROM anon, authenticated;
REVOKE ALL ON FUNCTION public.mark_payout_batch_processing(uuid, text)
FROM anon, authenticated;
REVOKE ALL ON FUNCTION public.mark_payout_batch_submitted(uuid, text, text, jsonb)
FROM anon, authenticated;
REVOKE ALL ON FUNCTION public.complete_payout_batch(uuid, text)
FROM anon, authenticated;
REVOKE ALL ON FUNCTION public.fail_payout_batch(uuid, text)
FROM anon, authenticated;
REVOKE ALL ON FUNCTION public.allocate_settlements_for_payment(uuid, uuid, integer)
FROM anon, authenticated;
REVOKE ALL ON FUNCTION public.create_payout_batch(uuid, text, numeric, text, text, uuid)
FROM anon, authenticated;

GRANT EXECUTE ON FUNCTION public.mark_booking_payment_initiated(uuid, uuid, integer)
TO service_role;
GRANT EXECUTE ON FUNCTION public.finalize_paid_booking(uuid, uuid, numeric)
TO service_role;
GRANT EXECUTE ON FUNCTION public.mark_payout_batch_processing(uuid, text)
TO service_role;
GRANT EXECUTE ON FUNCTION public.mark_payout_batch_submitted(uuid, text, text, jsonb)
TO service_role;
GRANT EXECUTE ON FUNCTION public.complete_payout_batch(uuid, text)
TO service_role;
GRANT EXECUTE ON FUNCTION public.fail_payout_batch(uuid, text)
TO service_role;
GRANT EXECUTE ON FUNCTION public.allocate_settlements_for_payment(uuid, uuid, integer)
TO service_role;
GRANT EXECUTE ON FUNCTION public.create_payout_batch(uuid, text, numeric, text, text, uuid)
TO service_role;

-- Keep public booking/search surfaces explicit.
GRANT EXECUTE ON FUNCTION public.create_booking(jsonb, jsonb, uuid)
TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_booking_details_secure(uuid, text)
TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_booking_details_by_ticket(text)
TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.request_hotel_payout(uuid, text, numeric, text)
TO authenticated, service_role;

COMMIT;
