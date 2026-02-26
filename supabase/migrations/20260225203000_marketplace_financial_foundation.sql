-- Marketplace financial hardening foundation
-- Adds commission snapshots, atomic multi-owner settlements, wallet projections,
-- payout lifecycle tables/functions, webhook idempotency, and finance reporting views.

-- ---------------------------------
-- 1) Existing table upgrades
-- ---------------------------------
ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS currency text DEFAULT 'TZS',
  ADD COLUMN IF NOT EXISTS amount_paid numeric(10,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS payment_completed_at timestamp with time zone;

ALTER TABLE public.booking_items
  ADD COLUMN IF NOT EXISTS currency text DEFAULT 'TZS';

ALTER TABLE public.payments
  ADD COLUMN IF NOT EXISTS retry_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_retry_at timestamp with time zone,
  ADD COLUMN IF NOT EXISTS amount_received numeric(10,2),
  ADD COLUMN IF NOT EXISTS failed_reason text;

ALTER TABLE public.settlements
  ADD COLUMN IF NOT EXISTS settlement_type text DEFAULT 'hotel',
  ADD COLUMN IF NOT EXISTS available_at timestamp with time zone DEFAULT now(),
  ADD COLUMN IF NOT EXISTS payout_batch_id uuid,
  ADD COLUMN IF NOT EXISTS locked_at timestamp with time zone,
  ADD COLUMN IF NOT EXISTS paid_at timestamp with time zone,
  ADD COLUMN IF NOT EXISTS failure_reason text,
  ADD COLUMN IF NOT EXISTS currency text DEFAULT 'TZS';

UPDATE public.settlements
SET settlement_type = 'hotel'
WHERE settlement_type IS NULL;

UPDATE public.settlements
SET status = 'paid'
WHERE lower(coalesce(status, '')) IN ('settled', 'success', 'completed');

UPDATE public.settlements
SET status = 'pending'
WHERE lower(coalesce(status, '')) NOT IN ('pending', 'available', 'locked', 'paid', 'failed');

ALTER TABLE public.settlements
  DROP CONSTRAINT IF EXISTS settlements_status_check;

ALTER TABLE public.settlements
  ADD CONSTRAINT settlements_status_check
  CHECK (status IN ('pending', 'available', 'locked', 'paid', 'failed'));

ALTER TABLE public.settlements
  DROP CONSTRAINT IF EXISTS settlements_settlement_type_check;

ALTER TABLE public.settlements
  ADD CONSTRAINT settlements_settlement_type_check
  CHECK (settlement_type IN ('hotel', 'platform', 'tax'));

WITH ranked AS (
  SELECT
    id,
    row_number() OVER (
      PARTITION BY booking_item_id, settlement_type
      ORDER BY
        CASE status
          WHEN 'paid' THEN 5
          WHEN 'locked' THEN 4
          WHEN 'available' THEN 3
          WHEN 'pending' THEN 2
          WHEN 'failed' THEN 1
          ELSE 0
        END DESC,
        created_at DESC,
        id DESC
    ) AS rn
  FROM public.settlements
)
DELETE FROM public.settlements s
USING ranked r
WHERE s.id = r.id
  AND r.rn > 1;

DROP INDEX IF EXISTS public.ux_settlements_payment_item_type;
CREATE UNIQUE INDEX IF NOT EXISTS ux_settlements_item_type
  ON public.settlements (booking_item_id, settlement_type);

-- ---------------------------------
-- 2) Commission + booking-item finance snapshot
-- ---------------------------------
CREATE TABLE IF NOT EXISTS public.hotel_commission_policies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hotel_id uuid NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
  model text NOT NULL CHECK (model IN ('percentage', 'flat', 'hybrid')),
  percentage_rate numeric(7,4) NOT NULL DEFAULT 0 CHECK (percentage_rate >= 0 AND percentage_rate <= 100),
  flat_fee numeric(10,2) NOT NULL DEFAULT 0 CHECK (flat_fee >= 0),
  tax_rate numeric(7,4) NOT NULL DEFAULT 0 CHECK (tax_rate >= 0 AND tax_rate <= 100),
  currency text NOT NULL DEFAULT 'TZS' CHECK (char_length(currency) = 3),
  is_active boolean NOT NULL DEFAULT true,
  effective_from timestamp with time zone NOT NULL DEFAULT now(),
  effective_to timestamp with time zone,
  created_by uuid,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_hotel_commission_policy_active
  ON public.hotel_commission_policies (hotel_id)
  WHERE is_active;

CREATE TABLE IF NOT EXISTS public.booking_item_financials (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  booking_item_id uuid NOT NULL UNIQUE REFERENCES public.booking_items(id) ON DELETE CASCADE,
  hotel_id uuid NOT NULL REFERENCES public.hotels(id),
  currency text NOT NULL DEFAULT 'TZS' CHECK (char_length(currency) = 3),
  gross_amount numeric(12,2) NOT NULL,
  commission_model text NOT NULL CHECK (commission_model IN ('percentage', 'flat', 'hybrid')),
  commission_rate numeric(7,4) NOT NULL DEFAULT 0,
  commission_flat numeric(10,2) NOT NULL DEFAULT 0,
  commission_amount numeric(12,2) NOT NULL DEFAULT 0,
  tax_rate numeric(7,4) NOT NULL DEFAULT 0,
  tax_amount numeric(12,2) NOT NULL DEFAULT 0,
  platform_amount numeric(12,2) NOT NULL DEFAULT 0,
  hotel_net_amount numeric(12,2) NOT NULL DEFAULT 0,
  policy_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_booking_item_financials_booking
  ON public.booking_item_financials (booking_id);

CREATE INDEX IF NOT EXISTS idx_booking_item_financials_hotel
  ON public.booking_item_financials (hotel_id);
CREATE OR REPLACE FUNCTION public.compute_booking_item_financials(p_booking_item_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_item RECORD;
  v_policy RECORD;
  v_nights integer;
  v_gross numeric(12,2);
  v_commission numeric(12,2);
  v_tax numeric(12,2);
  v_platform numeric(12,2);
  v_hotel_net numeric(12,2);
  v_currency text;
BEGIN
  SELECT
    bi.id,
    bi.booking_id,
    bi.hotel_id,
    bi.price_per_night,
    bi.start_date,
    bi.end_date,
    coalesce(nullif(trim(bi.currency), ''), nullif(trim(b.currency), ''), 'TZS') AS currency
  INTO v_item
  FROM public.booking_items bi
  JOIN public.bookings b ON b.id = bi.booking_id
  WHERE bi.id = p_booking_item_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  v_nights := GREATEST(1, (v_item.end_date - v_item.start_date));
  v_gross := round(v_nights * coalesce(v_item.price_per_night, 0)::numeric, 2);
  v_currency := upper(v_item.currency);

  SELECT
    model,
    percentage_rate,
    flat_fee,
    tax_rate,
    currency
  INTO v_policy
  FROM public.hotel_commission_policies p
  WHERE p.hotel_id = v_item.hotel_id
    AND p.is_active = true
    AND p.effective_from <= now()
    AND (p.effective_to IS NULL OR p.effective_to > now())
  ORDER BY p.effective_from DESC
  LIMIT 1;

  IF NOT FOUND THEN
    v_policy.model := 'percentage';
    v_policy.percentage_rate := 15;
    v_policy.flat_fee := 0;
    v_policy.tax_rate := 0;
    v_policy.currency := v_currency;
  END IF;

  IF v_policy.model = 'percentage' THEN
    v_commission := round(v_gross * (coalesce(v_policy.percentage_rate, 0) / 100), 2);
  ELSIF v_policy.model = 'flat' THEN
    v_commission := round(coalesce(v_policy.flat_fee, 0), 2);
  ELSE
    v_commission := round((v_gross * (coalesce(v_policy.percentage_rate, 0) / 100)) + coalesce(v_policy.flat_fee, 0), 2);
  END IF;

  v_commission := LEAST(GREATEST(v_commission, 0), v_gross);
  v_tax := round(v_commission * (coalesce(v_policy.tax_rate, 0) / 100), 2);

  IF (v_commission + v_tax) > v_gross THEN
    v_tax := GREATEST(v_gross - v_commission, 0);
  END IF;

  v_platform := round(v_commission + v_tax, 2);
  v_hotel_net := round(v_gross - v_platform, 2);

  UPDATE public.booking_items
  SET currency = v_currency
  WHERE id = v_item.id
    AND currency IS DISTINCT FROM v_currency;

  INSERT INTO public.booking_item_financials (
    booking_id,
    booking_item_id,
    hotel_id,
    currency,
    gross_amount,
    commission_model,
    commission_rate,
    commission_flat,
    commission_amount,
    tax_rate,
    tax_amount,
    platform_amount,
    hotel_net_amount,
    policy_snapshot
  )
  VALUES (
    v_item.booking_id,
    v_item.id,
    v_item.hotel_id,
    v_currency,
    v_gross,
    v_policy.model,
    coalesce(v_policy.percentage_rate, 0),
    coalesce(v_policy.flat_fee, 0),
    v_commission,
    coalesce(v_policy.tax_rate, 0),
    v_tax,
    v_platform,
    v_hotel_net,
    jsonb_build_object(
      'model', v_policy.model,
      'percentage_rate', coalesce(v_policy.percentage_rate, 0),
      'flat_fee', coalesce(v_policy.flat_fee, 0),
      'tax_rate', coalesce(v_policy.tax_rate, 0),
      'currency', coalesce(v_policy.currency, v_currency)
    )
  )
  ON CONFLICT (booking_item_id)
  DO UPDATE SET
    currency = EXCLUDED.currency,
    gross_amount = EXCLUDED.gross_amount,
    commission_model = EXCLUDED.commission_model,
    commission_rate = EXCLUDED.commission_rate,
    commission_flat = EXCLUDED.commission_flat,
    commission_amount = EXCLUDED.commission_amount,
    tax_rate = EXCLUDED.tax_rate,
    tax_amount = EXCLUDED.tax_amount,
    platform_amount = EXCLUDED.platform_amount,
    hotel_net_amount = EXCLUDED.hotel_net_amount,
    policy_snapshot = EXCLUDED.policy_snapshot;
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_sync_booking_item_financials()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM public.compute_booking_item_financials(NEW.id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_booking_item_financials ON public.booking_items;

CREATE TRIGGER trg_sync_booking_item_financials
AFTER INSERT OR UPDATE OF start_date, end_date, price_per_night, currency
ON public.booking_items
FOR EACH ROW
EXECUTE FUNCTION public.trg_sync_booking_item_financials();

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN SELECT id FROM public.booking_items LOOP
    PERFORM public.compute_booking_item_financials(r.id);
  END LOOP;
END;
$$;

-- ---------------------------------
-- 3) Payout model + webhook idempotency + immutable ledger
-- ---------------------------------
CREATE TABLE IF NOT EXISTS public.payout_batches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hotel_id uuid NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
  status text NOT NULL CHECK (status IN ('created', 'locked', 'processing', 'completed', 'failed')),
  provider text NOT NULL,
  provider_batch_ref text,
  currency text NOT NULL DEFAULT 'TZS' CHECK (char_length(currency) = 3),
  total_amount numeric(12,2) NOT NULL DEFAULT 0,
  minimum_threshold numeric(12,2) NOT NULL DEFAULT 0,
  schedule_type text NOT NULL DEFAULT 'manual' CHECK (schedule_type IN ('manual', 'scheduled')),
  idempotency_key text NOT NULL UNIQUE,
  requested_by uuid,
  requested_at timestamp with time zone NOT NULL DEFAULT now(),
  scheduled_for timestamp with time zone,
  processed_at timestamp with time zone,
  completed_at timestamp with time zone,
  failed_reason text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payout_batches_hotel_status
  ON public.payout_batches (hotel_id, status, created_at DESC);

CREATE TABLE IF NOT EXISTS public.hotel_payout_accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hotel_id uuid NOT NULL UNIQUE REFERENCES public.hotels(id) ON DELETE CASCADE,
  provider_type text NOT NULL CHECK (provider_type IN ('bank', 'mobile_money')),
  provider_name text NOT NULL,
  account_name text,
  account_number text,
  mobile_number text,
  currency text NOT NULL DEFAULT 'TZS' CHECK (char_length(currency) = 3),
  is_active boolean NOT NULL DEFAULT true,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.payout_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  payout_batch_id uuid NOT NULL REFERENCES public.payout_batches(id) ON DELETE CASCADE,
  settlement_id uuid NOT NULL REFERENCES public.settlements(id) ON DELETE RESTRICT,
  hotel_id uuid NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
  amount numeric(12,2) NOT NULL,
  currency text NOT NULL DEFAULT 'TZS' CHECK (char_length(currency) = 3),
  status text NOT NULL CHECK (status IN ('locked', 'processing', 'paid', 'failed')),
  provider_item_ref text,
  failure_reason text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  UNIQUE (payout_batch_id, settlement_id),
  UNIQUE (settlement_id)
);
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'settlements_payout_batch_fkey'
  ) THEN
    ALTER TABLE public.settlements
      ADD CONSTRAINT settlements_payout_batch_fkey
      FOREIGN KEY (payout_batch_id)
      REFERENCES public.payout_batches(id)
      ON DELETE SET NULL;
  END IF;
END;
$$;

CREATE TABLE IF NOT EXISTS public.payment_webhook_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider text NOT NULL DEFAULT 'azampay',
  provider_event_id text NOT NULL,
  payment_id uuid REFERENCES public.payments(id) ON DELETE SET NULL,
  booking_id uuid REFERENCES public.bookings(id) ON DELETE SET NULL,
  webhook_status text NOT NULL,
  amount numeric(12,2),
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  processed_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  UNIQUE (provider, provider_event_id)
);

CREATE TABLE IF NOT EXISTS public.ledger_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  idempotency_key text NOT NULL UNIQUE,
  entry_type text NOT NULL CHECK (
    entry_type IN (
      'settlement_created',
      'settlement_available',
      'settlement_locked',
      'payout_paid',
      'refund',
      'adjustment'
    )
  ),
  owner_type text NOT NULL CHECK (owner_type IN ('hotel', 'platform', 'tax', 'customer')),
  owner_hotel_id uuid REFERENCES public.hotels(id) ON DELETE SET NULL,
  booking_id uuid REFERENCES public.bookings(id) ON DELETE SET NULL,
  booking_item_id uuid REFERENCES public.booking_items(id) ON DELETE SET NULL,
  payment_id uuid REFERENCES public.payments(id) ON DELETE SET NULL,
  settlement_id uuid REFERENCES public.settlements(id) ON DELETE SET NULL,
  payout_batch_id uuid REFERENCES public.payout_batches(id) ON DELETE SET NULL,
  direction text NOT NULL CHECK (direction IN ('credit', 'debit')),
  amount numeric(12,2) NOT NULL CHECK (amount <> 0),
  currency text NOT NULL DEFAULT 'TZS' CHECK (char_length(currency) = 3),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ledger_entries_owner
  ON public.ledger_entries (owner_type, owner_hotel_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_ledger_entries_booking
  ON public.ledger_entries (booking_id, booking_item_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.refunds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid REFERENCES public.bookings(id) ON DELETE SET NULL,
  payment_id uuid REFERENCES public.payments(id) ON DELETE SET NULL,
  amount numeric(12,2) NOT NULL CHECK (amount > 0),
  currency text NOT NULL DEFAULT 'TZS' CHECK (char_length(currency) = 3),
  reason text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processed', 'failed')),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  processed_at timestamp with time zone
);

-- ---------------------------------
-- 4) Financial workflow functions
-- ---------------------------------
CREATE OR REPLACE FUNCTION public.allocate_settlements_for_payment(
  p_payment_id uuid,
  p_booking_id uuid,
  p_hold_hours integer DEFAULT 24
)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  v_created_count integer := 0;
  r RECORD;
BEGIN
  FOR r IN
    SELECT id FROM public.booking_items WHERE booking_id = p_booking_id
  LOOP
    PERFORM public.compute_booking_item_financials(r.id);
  END LOOP;

  WITH inserted_rows AS (
    INSERT INTO public.settlements (
      payment_id,
      booking_item_id,
      hotel_id,
      amount_allocated,
      status,
      available_at,
      currency,
      settlement_type
    )
    SELECT
      p_payment_id,
      bi.id,
      bi.hotel_id,
      bif.hotel_net_amount,
      'pending',
      now() + make_interval(hours => GREATEST(coalesce(p_hold_hours, 24), 0)),
      bif.currency,
      'hotel'
    FROM public.booking_items bi
    JOIN public.booking_item_financials bif ON bif.booking_item_id = bi.id
    WHERE bi.booking_id = p_booking_id
      AND bif.hotel_net_amount > 0

    UNION ALL

    SELECT
      p_payment_id,
      bi.id,
      bi.hotel_id,
      bif.commission_amount,
      'available',
      now(),
      bif.currency,
      'platform'
    FROM public.booking_items bi
    JOIN public.booking_item_financials bif ON bif.booking_item_id = bi.id
    WHERE bi.booking_id = p_booking_id
      AND bif.commission_amount > 0

    UNION ALL

    SELECT
      p_payment_id,
      bi.id,
      bi.hotel_id,
      bif.tax_amount,
      'available',
      now(),
      bif.currency,
      'tax'
    FROM public.booking_items bi
    JOIN public.booking_item_financials bif ON bif.booking_item_id = bi.id
    WHERE bi.booking_id = p_booking_id
      AND bif.tax_amount > 0
    ON CONFLICT (booking_item_id, settlement_type)
    DO NOTHING
    RETURNING id
  )
  SELECT count(*) INTO v_created_count FROM inserted_rows;

  INSERT INTO public.ledger_entries (
    idempotency_key,
    entry_type,
    owner_type,
    owner_hotel_id,
    booking_id,
    booking_item_id,
    payment_id,
    settlement_id,
    direction,
    amount,
    currency,
    metadata
  )
  SELECT
    'settlement_created:' || s.id::text,
    'settlement_created',
    CASE
      WHEN s.settlement_type = 'hotel' THEN 'hotel'
      WHEN s.settlement_type = 'platform' THEN 'platform'
      ELSE 'tax'
    END,
    CASE WHEN s.settlement_type = 'hotel' THEN s.hotel_id ELSE NULL END,
    p_booking_id,
    s.booking_item_id,
    s.payment_id,
    s.id,
    'credit',
    s.amount_allocated,
    s.currency,
    jsonb_build_object('settlement_type', s.settlement_type, 'status', s.status)
  FROM public.settlements s
  WHERE s.payment_id = p_payment_id
    AND s.booking_item_id IN (
      SELECT id FROM public.booking_items WHERE booking_id = p_booking_id
    )
  ON CONFLICT (idempotency_key)
  DO NOTHING;

  RETURN v_created_count;
END;
$$;
CREATE OR REPLACE FUNCTION public.release_pending_settlements(p_limit integer DEFAULT 500)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  v_count integer := 0;
BEGIN
  WITH candidates AS (
    SELECT id
    FROM public.settlements
    WHERE status = 'pending'
      AND available_at <= now()
    ORDER BY available_at ASC, created_at ASC
    LIMIT GREATEST(coalesce(p_limit, 500), 1)
  ), updated AS (
    UPDATE public.settlements s
    SET status = 'available'
    FROM candidates c
    WHERE s.id = c.id
    RETURNING s.id, s.hotel_id, s.booking_item_id, s.payment_id, s.amount_allocated, s.currency
  )
  SELECT count(*) INTO v_count FROM updated;

  INSERT INTO public.ledger_entries (
    idempotency_key,
    entry_type,
    owner_type,
    owner_hotel_id,
    booking_item_id,
    payment_id,
    settlement_id,
    direction,
    amount,
    currency,
    metadata
  )
  SELECT
    'settlement_available:' || s.id::text,
    'settlement_available',
    'hotel',
    s.hotel_id,
    s.booking_item_id,
    s.payment_id,
    s.id,
    'credit',
    s.amount_allocated,
    s.currency,
    jsonb_build_object('released_at', now())
  FROM public.settlements s
  WHERE s.status = 'available'
    AND s.settlement_type = 'hotel'
  ON CONFLICT (idempotency_key)
  DO NOTHING;

  RETURN v_count;
END;
$$;

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
AS $$
DECLARE
  v_batch_id uuid;
  v_total numeric(12,2);
  v_currency text;
  v_key text;
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

  CREATE TEMP TABLE IF NOT EXISTS _selected_settlements (
    id uuid PRIMARY KEY,
    amount numeric(12,2),
    currency text
  ) ON COMMIT DROP;

  DELETE FROM _selected_settlements;

  INSERT INTO _selected_settlements (id, amount, currency)
  SELECT s.id, s.amount_allocated, s.currency
  FROM public.settlements s
  WHERE s.hotel_id = p_hotel_id
    AND s.settlement_type = 'hotel'
    AND s.status = 'available'
    AND s.payout_batch_id IS NULL
  ORDER BY s.created_at ASC
  FOR UPDATE SKIP LOCKED;

  SELECT coalesce(sum(amount), 0), max(currency)
  INTO v_total, v_currency
  FROM _selected_settlements;

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
    jsonb_build_object('selection_count', (SELECT count(*) FROM _selected_settlements))
  )
  RETURNING id INTO v_batch_id;

  UPDATE public.settlements s
  SET status = 'locked',
      locked_at = now(),
      payout_batch_id = v_batch_id
  WHERE s.id IN (SELECT id FROM _selected_settlements);

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
    ss.id,
    p_hotel_id,
    ss.amount,
    ss.currency,
    'locked'
  FROM _selected_settlements ss;

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
  WHERE s.payout_batch_id = v_batch_id
  ON CONFLICT (idempotency_key)
  DO NOTHING;

  RETURN v_batch_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_payout_batch_processing(
  p_batch_id uuid,
  p_provider_batch_ref text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.payout_batches
  SET status = 'processing',
      provider_batch_ref = coalesce(nullif(trim(p_provider_batch_ref), ''), provider_batch_ref),
      processed_at = now(),
      updated_at = now()
  WHERE id = p_batch_id
    AND status IN ('locked', 'created');

  UPDATE public.payout_items
  SET status = 'processing',
      updated_at = now()
  WHERE payout_batch_id = p_batch_id
    AND status = 'locked';
END;
$$;
CREATE OR REPLACE FUNCTION public.complete_payout_batch(
  p_batch_id uuid,
  p_provider_batch_ref text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.payout_batches
  SET status = 'completed',
      provider_batch_ref = coalesce(nullif(trim(p_provider_batch_ref), ''), provider_batch_ref),
      completed_at = now(),
      updated_at = now()
  WHERE id = p_batch_id
    AND status IN ('processing', 'locked', 'created');

  UPDATE public.payout_items
  SET status = 'paid',
      provider_item_ref = coalesce(nullif(trim(p_provider_batch_ref), ''), provider_item_ref),
      updated_at = now()
  WHERE payout_batch_id = p_batch_id
    AND status IN ('locked', 'processing');

  UPDATE public.settlements
  SET status = 'paid',
      paid_at = now(),
      failure_reason = NULL
  WHERE payout_batch_id = p_batch_id
    AND settlement_type = 'hotel'
    AND status IN ('locked', 'available');

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
  ON CONFLICT (idempotency_key)
  DO NOTHING;
END;
$$;

CREATE OR REPLACE FUNCTION public.fail_payout_batch(
  p_batch_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.payout_batches
  SET status = 'failed',
      failed_reason = coalesce(nullif(trim(p_reason), ''), 'Provider processing failed'),
      updated_at = now()
  WHERE id = p_batch_id
    AND status <> 'completed';

  UPDATE public.payout_items
  SET status = 'failed',
      failure_reason = coalesce(nullif(trim(p_reason), ''), 'Provider processing failed'),
      updated_at = now()
  WHERE payout_batch_id = p_batch_id
    AND status IN ('locked', 'processing');

  UPDATE public.settlements
  SET status = 'available',
      payout_batch_id = NULL,
      locked_at = NULL,
      failure_reason = coalesce(nullif(trim(p_reason), ''), 'Payout failed and returned to available')
  WHERE payout_batch_id = p_batch_id
    AND settlement_type = 'hotel'
    AND status IN ('locked', 'available');
END;
$$;

CREATE OR REPLACE FUNCTION public.request_hotel_payout(
  p_hotel_id uuid,
  p_provider text DEFAULT 'azampay_disburse',
  p_minimum_threshold numeric DEFAULT 0,
  p_idempotency_key text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN public.create_payout_batch(
    p_hotel_id => p_hotel_id,
    p_provider => p_provider,
    p_minimum_threshold => p_minimum_threshold,
    p_idempotency_key => p_idempotency_key,
    p_schedule_type => 'manual',
    p_requested_by => auth.uid()
  );
END;
$$;

-- ---------------------------------
-- 5) Reporting views
-- ---------------------------------
CREATE OR REPLACE VIEW public.hotel_wallet_balances_view AS
SELECT
  h.id AS hotel_id,
  coalesce(sum(CASE WHEN s.settlement_type = 'hotel' AND s.status = 'pending' THEN s.amount_allocated ELSE 0 END), 0)::numeric(12,2) AS pending_balance,
  coalesce(sum(CASE WHEN s.settlement_type = 'hotel' AND s.status = 'available' THEN s.amount_allocated ELSE 0 END), 0)::numeric(12,2) AS available_balance,
  coalesce(sum(CASE WHEN s.settlement_type = 'hotel' AND s.status = 'locked' THEN s.amount_allocated ELSE 0 END), 0)::numeric(12,2) AS locked_balance,
  coalesce(sum(CASE WHEN s.settlement_type = 'hotel' AND s.status = 'paid' THEN s.amount_allocated ELSE 0 END), 0)::numeric(12,2) AS paid_total,
  coalesce(sum(CASE WHEN s.settlement_type = 'hotel' AND s.status IN ('available', 'locked', 'paid') THEN s.amount_allocated ELSE 0 END), 0)::numeric(12,2) AS lifetime_earnings
FROM public.hotels h
LEFT JOIN public.settlements s ON s.hotel_id = h.id
GROUP BY h.id;

CREATE OR REPLACE VIEW public.hotel_booking_financial_breakdown_view AS
SELECT
  b.id AS booking_id,
  b.ticket_number,
  b.created_at AS booking_created_at,
  bi.id AS booking_item_id,
  bi.hotel_id,
  bi.start_date,
  bi.end_date,
  bif.currency,
  bif.gross_amount,
  bif.commission_amount,
  bif.tax_amount,
  bif.hotel_net_amount,
  s.status AS settlement_status,
  s.settlement_type,
  s.created_at AS settlement_created_at
FROM public.booking_items bi
JOIN public.bookings b ON b.id = bi.booking_id
JOIN public.booking_item_financials bif ON bif.booking_item_id = bi.id
LEFT JOIN public.settlements s
  ON s.booking_item_id = bi.id
 AND s.settlement_type = 'hotel';

CREATE OR REPLACE VIEW public.hotel_financial_summary_view AS
SELECT
  h.id AS hotel_id,
  coalesce(sum(bif.gross_amount), 0)::numeric(12,2) AS total_revenue,
  coalesce(sum(bif.commission_amount), 0)::numeric(12,2) AS total_commission_paid,
  coalesce(sum(bif.hotel_net_amount), 0)::numeric(12,2) AS net_earnings,
  wb.available_balance,
  wb.pending_balance,
  wb.locked_balance,
  wb.paid_total,
  wb.lifetime_earnings
FROM public.hotels h
LEFT JOIN public.booking_item_financials bif ON bif.hotel_id = h.id
LEFT JOIN public.hotel_wallet_balances_view wb ON wb.hotel_id = h.id
GROUP BY
  h.id,
  wb.available_balance,
  wb.pending_balance,
  wb.locked_balance,
  wb.paid_total,
  wb.lifetime_earnings;

CREATE OR REPLACE VIEW public.platform_financial_summary_view AS
SELECT
  (
    SELECT coalesce(sum(s.amount_allocated), 0)::numeric(12,2)
    FROM public.settlements s
    WHERE s.settlement_type = 'platform'
  ) AS commission_earned,
  (
    SELECT coalesce(sum(s.amount_allocated), 0)::numeric(12,2)
    FROM public.settlements s
    WHERE s.settlement_type = 'platform'
      AND s.status IN ('available', 'locked', 'paid')
  ) AS commission_settled,
  (
    SELECT coalesce(sum(r.amount), 0)::numeric(12,2)
    FROM public.refunds r
    WHERE r.status = 'processed'
  ) AS refund_deductions;

CREATE OR REPLACE VIEW public.hotel_wallet_transactions_view AS
SELECT
  s.id AS settlement_id,
  s.hotel_id,
  s.payment_id,
  s.booking_item_id,
  bi.booking_id,
  b.ticket_number,
  s.amount_allocated,
  s.currency,
  s.status,
  s.settlement_type,
  s.created_at,
  s.available_at,
  s.locked_at,
  s.paid_at,
  s.payout_batch_id,
  pb.status AS payout_status
FROM public.settlements s
JOIN public.booking_items bi ON bi.id = s.booking_item_id
JOIN public.bookings b ON b.id = bi.booking_id
LEFT JOIN public.payout_batches pb ON pb.id = s.payout_batch_id
WHERE s.settlement_type = 'hotel';

DROP VIEW IF EXISTS public.manager_hotel_payments_view;
CREATE VIEW public.manager_hotel_payments_view AS
SELECT
  s.id AS settlement_id,
  s.hotel_id,
  s.amount_allocated AS settled_amount,
  s.status AS settlement_status,
  s.created_at AS settled_at,
  s.currency,
  s.settlement_type,
  s.payout_batch_id,
  bif.gross_amount,
  bif.commission_amount,
  bif.tax_amount,
  bif.hotel_net_amount,
  bi.id AS booking_item_id,
  hr.room_number,
  bi.price_per_night,
  bi.start_date,
  bi.end_date,
  (bi.end_date - bi.start_date) AS total_nights,
  b.id AS booking_id,
  b.customer_name,
  b.customer_phone,
  b.customer_email,
  b.ticket_number,
  p.id AS payment_id,
  p.status AS payment_status,
  p.payment_gateway_ref,
  p.external_id,
  p.type AS payment_method
FROM public.settlements s
JOIN public.booking_items bi ON s.booking_item_id = bi.id
JOIN public.hotel_rooms hr ON bi.room_id = hr.id
JOIN public.bookings b ON bi.booking_id = b.id
JOIN public.payments p ON s.payment_id = p.id
LEFT JOIN public.booking_item_financials bif ON bif.booking_item_id = bi.id
WHERE s.settlement_type = 'hotel';

DROP VIEW IF EXISTS public.hotel_payment_report;
CREATE VIEW public.hotel_payment_report AS
SELECT
  h.id AS hotel_id,
  b.customer_name,
  b.customer_phone,
  bi.room_id,
  bi.start_date AS check_in,
  bi.end_date AS check_out,
  (bi.end_date - bi.start_date) AS nights,
  bif.gross_amount AS calculated_total,
  bif.commission_amount,
  bif.tax_amount,
  bif.hotel_net_amount,
  p.status AS payment_status,
  p.payment_gateway_ref,
  s.amount_allocated AS amount_settled,
  s.created_at AS settled_at
FROM public.settlements s
JOIN public.booking_items bi ON s.booking_item_id = bi.id
JOIN public.booking_item_financials bif ON bif.booking_item_id = bi.id
JOIN public.bookings b ON bi.booking_id = b.id
JOIN public.payments p ON s.payment_id = p.id
JOIN public.hotels h ON s.hotel_id = h.id
WHERE s.settlement_type = 'hotel';

-- ---------------------------------
-- 6) Grants (keep parity with existing project style)
-- ---------------------------------
GRANT ALL ON TABLE public.hotel_commission_policies TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.booking_item_financials TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.payout_batches TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.hotel_payout_accounts TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.payout_items TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.payment_webhook_events TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.ledger_entries TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.refunds TO anon, authenticated, service_role;

GRANT ALL ON TABLE public.hotel_wallet_balances_view TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.hotel_booking_financial_breakdown_view TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.hotel_financial_summary_view TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.platform_financial_summary_view TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.hotel_wallet_transactions_view TO anon, authenticated, service_role;

GRANT ALL ON FUNCTION public.compute_booking_item_financials(uuid) TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.trg_sync_booking_item_financials() TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.allocate_settlements_for_payment(uuid, uuid, integer) TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.release_pending_settlements(integer) TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.create_payout_batch(uuid, text, numeric, text, text, uuid) TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.mark_payout_batch_processing(uuid, text) TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.complete_payout_batch(uuid, text) TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.fail_payout_batch(uuid, text) TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.request_hotel_payout(uuid, text, numeric, text) TO anon, authenticated, service_role;
