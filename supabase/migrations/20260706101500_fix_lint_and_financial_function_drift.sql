-- Repair function drift found by Supabase database lint.
-- Keep this append-only: older migrations document the drift, this migration
-- restores functions to the current table shape.

BEGIN;

ALTER FUNCTION public.get_hotels_in_bounding_box(double precision, double precision, double precision, double precision)
  SET search_path TO public, extensions;

ALTER FUNCTION public.bookings_initiate(jsonb, jsonb, numeric)
  SET search_path TO public, extensions;

ALTER FUNCTION public.review_manager_application(uuid, text, text)
  SET search_path TO public, extensions;

ALTER TABLE public.settlements
  ADD COLUMN IF NOT EXISTS updated_at timestamp with time zone NOT NULL DEFAULT now();

DROP TRIGGER IF EXISTS update_settlements_updated_at ON public.settlements;
CREATE TRIGGER update_settlements_updated_at
BEFORE UPDATE ON public.settlements
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE OR REPLACE FUNCTION public.create_payout_batch(
  p_hotel_id uuid,
  p_provider text,
  p_minimum_threshold numeric DEFAULT 0,
  p_idempotency_key text DEFAULT NULL,
  p_schedule_type text DEFAULT 'manual',
  p_requested_by uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, extensions
AS $$
DECLARE
  v_batch_id uuid;
  v_total numeric(12,2);
  v_currency text;
  v_key text;
  v_selected_settlement_ids uuid[];
BEGIN
  IF p_schedule_type NOT IN ('manual', 'scheduled') THEN
    RAISE EXCEPTION 'Invalid schedule type: %', p_schedule_type;
  END IF;

  v_key := coalesce(nullif(trim(p_idempotency_key), ''), gen_random_uuid()::text);

  SELECT id
  INTO v_batch_id
  FROM public.payout_batches
  WHERE idempotency_key = v_key
  LIMIT 1;

  IF v_batch_id IS NOT NULL THEN
    RETURN v_batch_id;
  END IF;

  WITH selected AS (
    SELECT s.id, s.amount_allocated, s.currency
    FROM public.settlements s
    WHERE s.hotel_id = p_hotel_id
      AND s.settlement_type = 'hotel'
      AND s.status = 'available'
      AND s.payout_batch_id IS NULL
    ORDER BY s.created_at ASC
    FOR UPDATE SKIP LOCKED
  )
  SELECT
    array_agg(id),
    coalesce(sum(amount_allocated), 0),
    max(currency)
  INTO v_selected_settlement_ids, v_total, v_currency
  FROM selected;

  IF v_total <= 0 OR v_total < GREATEST(coalesce(p_minimum_threshold, 0), 0) THEN
    RETURN NULL;
  END IF;

  INSERT INTO public.payout_batches (
    hotel_id,
    status,
    provider,
    currency,
    total_amount,
    minimum_threshold,
    schedule_type,
    idempotency_key,
    requested_by,
    metadata
  )
  VALUES (
    p_hotel_id,
    'created',
    coalesce(nullif(trim(p_provider), ''), 'azampay_disburse'),
    coalesce(v_currency, 'TZS'),
    v_total,
    GREATEST(coalesce(p_minimum_threshold, 0), 0),
    p_schedule_type,
    v_key,
    p_requested_by,
    jsonb_build_object('selection_count', cardinality(v_selected_settlement_ids))
  )
  RETURNING id INTO v_batch_id;

  UPDATE public.settlements s
  SET
    status = 'locked',
    locked_at = now(),
    payout_batch_id = v_batch_id,
    updated_at = now()
  WHERE s.id = ANY(v_selected_settlement_ids);

  INSERT INTO public.payout_items (
    payout_batch_id,
    settlement_id,
    hotel_id,
    amount,
    currency,
    status
  )
  SELECT
    v_batch_id,
    s.id,
    p_hotel_id,
    s.amount_allocated,
    s.currency,
    'locked'
  FROM public.settlements s
  WHERE s.id = ANY(v_selected_settlement_ids);

  UPDATE public.payout_batches
  SET status = 'locked',
      updated_at = now()
  WHERE id = v_batch_id;

  INSERT INTO public.ledger_entries (
    idempotency_key,
    entry_type,
    owner_type,
    owner_hotel_id,
    settlement_id,
    payout_batch_id,
    direction,
    amount,
    currency,
    metadata
  )
  SELECT
    'settlement_locked:' || s.id::text,
    'settlement_locked',
    'hotel',
    s.hotel_id,
    s.id,
    v_batch_id,
    'debit',
    s.amount_allocated,
    s.currency,
    jsonb_build_object('batch_id', v_batch_id)
  FROM public.settlements s
  WHERE s.id = ANY(v_selected_settlement_ids)
  ON CONFLICT (idempotency_key) DO NOTHING;

  RETURN v_batch_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.finalize_paid_booking(
  p_booking_id uuid,
  p_payment_id uuid DEFAULT NULL,
  p_amount_paid numeric DEFAULT NULL
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, extensions
AS $$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_item record;
  v_day date;
  v_amount numeric;
BEGIN
  SELECT *
  INTO v_booking
  FROM public.bookings
  WHERE id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN 'booking_not_found';
  END IF;

  IF v_booking.status = 'confirmed' AND v_booking.payment_status = 'completed' THEN
    RETURN 'already_confirmed';
  END IF;

  FOR v_item IN
    SELECT bi.room_id, bi.start_date, bi.end_date
    FROM public.booking_items bi
    WHERE bi.booking_id = p_booking_id
      AND bi.room_id IS NOT NULL
      AND bi.start_date IS NOT NULL
      AND bi.end_date IS NOT NULL
  LOOP
    FOR v_day IN
      SELECT gs::date
      FROM generate_series(v_item.start_date, v_item.end_date - interval '1 day', interval '1 day') AS gs
    LOOP
      PERFORM pg_advisory_xact_lock(hashtext(v_item.room_id::text || ':' || v_day::text));

      IF EXISTS (
        SELECT 1
        FROM public.room_statuses rs
        WHERE rs.room_id = v_item.room_id
          AND rs.date = v_day
          AND rs.status IN ('booked', 'pending', 'not_available')
          AND rs.booking_id IS DISTINCT FROM p_booking_id
      ) THEN
        UPDATE public.bookings
        SET
          payment_status = 'completed',
          status = 'payment_reconciliation',
          amount_paid = COALESCE(p_amount_paid, amount_paid, total_price),
          payment_completed_at = COALESCE(payment_completed_at, now()),
          reconciliation_status = 'needs_reassignment'
        WHERE id = p_booking_id;

        IF p_payment_id IS NOT NULL THEN
          UPDATE public.payments
          SET
            reconciliation_status = 'needs_reassignment',
            provider_finalized_at = COALESCE(provider_finalized_at, now())
          WHERE id = p_payment_id;
        END IF;

        RETURN 'needs_reassignment';
      END IF;

      INSERT INTO public.room_statuses(room_id, date, status, booking_id, note)
      VALUES (v_item.room_id, v_day, 'booked', p_booking_id, 'Confirmed paid booking')
      ON CONFLICT (room_id, date) WHERE status IN ('booked', 'pending', 'not_available')
      DO UPDATE SET
        status = 'booked',
        booking_id = p_booking_id,
        note = 'Confirmed paid booking',
        updated_at = now()
      WHERE public.room_statuses.booking_id = p_booking_id
         OR public.room_statuses.booking_id IS NULL;
    END LOOP;
  END LOOP;

  v_amount := COALESCE(p_amount_paid, v_booking.total_price);

  UPDATE public.bookings
  SET
    payment_status = 'completed',
    status = 'confirmed',
    amount_paid = v_amount,
    payment_completed_at = COALESCE(payment_completed_at, now()),
    reconciliation_status = 'none'
  WHERE id = p_booking_id;

  IF p_payment_id IS NOT NULL THEN
    UPDATE public.payments
    SET
      reconciliation_status = 'none',
      provider_finalized_at = COALESCE(provider_finalized_at, now())
    WHERE id = p_payment_id;
  END IF;

  RETURN 'confirmed';
END;
$$;

CREATE OR REPLACE FUNCTION public.complete_payout_batch(
  p_batch_id uuid,
  p_provider_batch_ref text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, extensions
AS $$
BEGIN
  UPDATE public.payout_batches
  SET
    status = 'completed',
    provider_batch_ref = COALESCE(p_provider_batch_ref, provider_batch_ref),
    provider_reference = COALESCE(p_provider_batch_ref, provider_reference),
    provider_status = 'completed',
    reconciliation_status = 'none',
    completed_at = COALESCE(completed_at, now()),
    processed_at = COALESCE(processed_at, now()),
    updated_at = now()
  WHERE id = p_batch_id
    AND status IN ('processing', 'provider_pending', 'locked', 'created');

  UPDATE public.payout_items
  SET
    status = 'completed',
    provider_reference = COALESCE(p_provider_batch_ref, provider_reference),
    provider_status = 'completed',
    reconciliation_status = 'none',
    updated_at = now()
  WHERE payout_batch_id = p_batch_id
    AND status IN ('processing', 'provider_pending', 'locked');

  UPDATE public.settlements s
  SET
    status = 'paid',
    paid_at = now(),
    payout_batch_id = p_batch_id,
    updated_at = now()
  FROM public.payout_items pi
  WHERE pi.payout_batch_id = p_batch_id
    AND pi.settlement_id = s.id
    AND s.status IN ('locked', 'available');

  INSERT INTO public.ledger_entries (
    idempotency_key,
    entry_type,
    owner_type,
    owner_hotel_id,
    settlement_id,
    payout_batch_id,
    direction,
    amount,
    currency,
    metadata
  )
  SELECT
    'payout_paid:' || s.id::text,
    'payout_paid',
    'hotel',
    s.hotel_id,
    s.id,
    p_batch_id,
    'debit',
    s.amount_allocated,
    s.currency,
    jsonb_build_object('payout_batch_id', p_batch_id, 'paid_at', now())
  FROM public.settlements s
  WHERE s.payout_batch_id = p_batch_id
    AND s.status = 'paid'
  ON CONFLICT (idempotency_key) DO NOTHING;
END;
$$;

REVOKE ALL ON FUNCTION public.create_payout_batch(uuid, text, numeric, text, text, uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.finalize_paid_booking(uuid, uuid, numeric)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.complete_payout_batch(uuid, text)
  FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.create_payout_batch(uuid, text, numeric, text, text, uuid)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.finalize_paid_booking(uuid, uuid, numeric)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.complete_payout_batch(uuid, text)
  TO service_role;

COMMIT;
