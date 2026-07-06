-- Harden booking inventory, payment lifecycle, payout dispatch, and ledger invariants.

ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS expires_at timestamp with time zone,
  ADD COLUMN IF NOT EXISTS payment_initiated_at timestamp with time zone,
  ADD COLUMN IF NOT EXISTS provider_grace_expires_at timestamp with time zone,
  ADD COLUMN IF NOT EXISTS reconciliation_status text NOT NULL DEFAULT 'none';

UPDATE public.bookings
SET expires_at = COALESCE(expires_at, created_at::timestamp with time zone + interval '15 minutes')
WHERE expires_at IS NULL;

ALTER TABLE public.payments
  ADD COLUMN IF NOT EXISTS provider_status text,
  ADD COLUMN IF NOT EXISTS provider_reference text,
  ADD COLUMN IF NOT EXISTS provider_status_checked_at timestamp with time zone,
  ADD COLUMN IF NOT EXISTS provider_finalized_at timestamp with time zone,
  ADD COLUMN IF NOT EXISTS reconciliation_status text NOT NULL DEFAULT 'none';

CREATE TABLE IF NOT EXISTS public.payment_reconciliation_events (
  id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  provider text NOT NULL,
  event_type text NOT NULL,
  provider_event_id text NOT NULL,
  booking_id uuid REFERENCES public.bookings(id) ON DELETE SET NULL,
  payment_id uuid REFERENCES public.payments(id) ON DELETE SET NULL,
  external_reference text,
  provider_reference text,
  status text,
  amount numeric,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  processed_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  UNIQUE (provider, event_type, provider_event_id)
);

ALTER TABLE public.payment_webhook_events
  ADD COLUMN IF NOT EXISTS processed_outcome text;

WITH ranked AS (
  SELECT
    id,
    row_number() OVER (
      PARTITION BY room_id, date
      ORDER BY
        CASE status
          WHEN 'booked' THEN 4
          WHEN 'not_available' THEN 3
          WHEN 'pending' THEN 2
          ELSE 1
        END DESC,
        updated_at DESC NULLS LAST,
        created_at DESC NULLS LAST,
        id
    ) AS rn
  FROM public.room_statuses
  WHERE room_id IS NOT NULL
    AND date IS NOT NULL
    AND status IN ('booked', 'pending', 'not_available')
)
UPDATE public.room_statuses rs
SET
  status = 'released_duplicate',
  note = concat_ws(' ', NULLIF(rs.note, ''), '[released by lifecycle hardening duplicate-room-date cleanup]'),
  updated_at = now()
FROM ranked r
WHERE rs.id = r.id
  AND r.rn > 1;

CREATE UNIQUE INDEX IF NOT EXISTS ux_room_statuses_blocking_room_date
ON public.room_statuses(room_id, date)
WHERE status IN ('booked', 'pending', 'not_available');

CREATE OR REPLACE FUNCTION public.mark_booking_payment_initiated(
  p_booking_id uuid,
  p_payment_id uuid DEFAULT NULL,
  p_grace_minutes integer DEFAULT 15
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
BEGIN
  UPDATE public.bookings
  SET
    payment_status = 'pending_provider',
    payment_initiated_at = COALESCE(payment_initiated_at, now()),
    provider_grace_expires_at = GREATEST(
      COALESCE(provider_grace_expires_at, now()),
      now() + make_interval(mins => GREATEST(COALESCE(p_grace_minutes, 15), 1))
    ),
    reconciliation_status = 'pending'
  WHERE id = p_booking_id
    AND status <> 'confirmed'
    AND payment_status <> 'completed';

  IF p_payment_id IS NOT NULL THEN
    UPDATE public.payments
    SET
      provider_status = COALESCE(provider_status, 'initiated'),
      reconciliation_status = 'pending'
    WHERE id = p_payment_id;
  END IF;
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
SET search_path TO 'public', 'extensions'
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
    SELECT bi.room_id, bi.check_in_date, bi.check_out_date
    FROM public.booking_items bi
    WHERE bi.booking_id = p_booking_id
  LOOP
    FOR v_day IN
      SELECT gs::date
      FROM generate_series(v_item.check_in_date, v_item.check_out_date - interval '1 day', interval '1 day') AS gs
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

CREATE OR REPLACE FUNCTION public.cleanup_old_unconfirmed_bookings()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_now timestamp with time zone := now();
BEGIN
  DELETE FROM public.room_statuses rs
  USING public.bookings b
  WHERE rs.booking_id = b.id
    AND rs.status = 'pending'
    AND b.status <> 'confirmed'
    AND COALESCE(b.provider_grace_expires_at, b.expires_at, b.created_at::timestamp with time zone + interval '15 minutes') < v_now;

  UPDATE public.bookings b
  SET
    status = 'payment_reconciliation',
    reconciliation_status = 'pending'
  WHERE b.status NOT IN ('confirmed', 'cancelled', 'expired')
    AND COALESCE(b.provider_grace_expires_at, b.expires_at, b.created_at::timestamp with time zone + interval '15 minutes') < v_now
    AND (
      b.payment_status IN ('pending_provider', 'initiated', 'pending')
      OR EXISTS (
        SELECT 1
        FROM public.payments p
        WHERE p.booking_id = b.id
          AND p.status IN ('pending', 'success', 'completed')
      )
    );

  UPDATE public.bookings b
  SET
    status = 'expired',
    reconciliation_status = 'none'
  WHERE b.status NOT IN ('confirmed', 'cancelled', 'expired', 'payment_reconciliation')
    AND COALESCE(b.expires_at, b.created_at::timestamp with time zone + interval '15 minutes') < v_now
    AND COALESCE(b.payment_status, 'unpaid') NOT IN ('pending_provider', 'initiated', 'pending', 'completed')
    AND NOT EXISTS (
      SELECT 1
      FROM public.payments p
      WHERE p.booking_id = b.id
        AND p.status IN ('pending', 'success', 'completed')
    );
END;
$$;

ALTER TABLE public.payout_batches
  ADD COLUMN IF NOT EXISTS provider_status text,
  ADD COLUMN IF NOT EXISTS provider_reference text,
  ADD COLUMN IF NOT EXISTS provider_external_reference text,
  ADD COLUMN IF NOT EXISTS provider_response jsonb,
  ADD COLUMN IF NOT EXISTS submitted_at timestamp with time zone,
  ADD COLUMN IF NOT EXISTS last_checked_at timestamp with time zone,
  ADD COLUMN IF NOT EXISTS reconciliation_status text NOT NULL DEFAULT 'none';

ALTER TABLE public.payout_items
  ADD COLUMN IF NOT EXISTS provider_status text,
  ADD COLUMN IF NOT EXISTS provider_reference text,
  ADD COLUMN IF NOT EXISTS provider_response jsonb,
  ADD COLUMN IF NOT EXISTS submitted_at timestamp with time zone,
  ADD COLUMN IF NOT EXISTS reconciliation_status text NOT NULL DEFAULT 'none';

ALTER TABLE public.payout_batches DROP CONSTRAINT IF EXISTS payout_batches_status_check;
ALTER TABLE public.payout_batches
  ADD CONSTRAINT payout_batches_status_check
  CHECK (status IN ('created', 'locked', 'processing', 'provider_pending', 'completed', 'failed', 'needs_reconciliation'));

ALTER TABLE public.payout_items DROP CONSTRAINT IF EXISTS payout_items_status_check;
ALTER TABLE public.payout_items
  ADD CONSTRAINT payout_items_status_check
  CHECK (status IN ('locked', 'processing', 'provider_pending', 'completed', 'failed', 'needs_reconciliation'));

CREATE TABLE IF NOT EXISTS public.payout_provider_events (
  id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  provider text NOT NULL,
  provider_event_id text NOT NULL,
  payout_batch_id uuid REFERENCES public.payout_batches(id) ON DELETE SET NULL,
  payout_item_id uuid REFERENCES public.payout_items(id) ON DELETE SET NULL,
  status text,
  amount numeric,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  processed_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  UNIQUE (provider, provider_event_id)
);

DROP FUNCTION IF EXISTS public.mark_payout_batch_processing(uuid, text);

CREATE OR REPLACE FUNCTION public.mark_payout_batch_processing(
  p_batch_id uuid,
  p_provider_batch_ref text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
BEGIN
  UPDATE public.payout_batches
  SET
    status = 'processing',
    provider_batch_ref = COALESCE(p_provider_batch_ref, provider_batch_ref),
    provider_status = 'processing',
    processed_at = now(),
    updated_at = now()
  WHERE id = p_batch_id
    AND status IN ('created', 'locked');

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  UPDATE public.payout_items
  SET
    status = 'processing',
    provider_status = 'processing',
    updated_at = now()
  WHERE payout_batch_id = p_batch_id
    AND status = 'locked';

  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_payout_batch_submitted(
  p_batch_id uuid,
  p_provider_batch_ref text DEFAULT NULL,
  p_provider_external_reference text DEFAULT NULL,
  p_provider_response jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
BEGIN
  UPDATE public.payout_batches
  SET
    status = 'provider_pending',
    provider_batch_ref = COALESCE(p_provider_batch_ref, provider_batch_ref),
    provider_reference = COALESCE(p_provider_batch_ref, provider_reference),
    provider_external_reference = COALESCE(p_provider_external_reference, provider_external_reference),
    provider_response = COALESCE(p_provider_response, provider_response),
    provider_status = 'submitted',
    submitted_at = COALESCE(submitted_at, now()),
    reconciliation_status = 'pending',
    updated_at = now()
  WHERE id = p_batch_id
    AND status = 'processing';

  UPDATE public.payout_items
  SET
    status = 'provider_pending',
    provider_reference = COALESCE(p_provider_batch_ref, provider_reference),
    provider_response = COALESCE(p_provider_response, provider_response),
    provider_status = 'submitted',
    submitted_at = COALESCE(submitted_at, now()),
    reconciliation_status = 'pending',
    updated_at = now()
  WHERE payout_batch_id = p_batch_id
    AND status = 'processing';
END;
$$;

CREATE OR REPLACE FUNCTION public.complete_payout_batch(
  p_batch_id uuid,
  p_provider_batch_ref text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
BEGIN
  UPDATE public.payout_batches
  SET
    status = 'completed',
    provider_batch_ref = COALESCE(p_provider_batch_ref, provider_batch_ref),
    provider_reference = COALESCE(p_provider_batch_ref, provider_reference),
    provider_status = 'completed',
    reconciliation_status = 'none',
    processed_at = COALESCE(processed_at, now()),
    updated_at = now()
  WHERE id = p_batch_id
    AND status IN ('processing', 'provider_pending');

  UPDATE public.payout_items
  SET
    status = 'completed',
    provider_reference = COALESCE(p_provider_batch_ref, provider_reference),
    provider_status = 'completed',
    reconciliation_status = 'none',
    updated_at = now()
  WHERE payout_batch_id = p_batch_id
    AND status IN ('processing', 'provider_pending');

  UPDATE public.settlements s
  SET
    status = 'paid',
    paid_at = now(),
    payout_batch_id = p_batch_id,
    updated_at = now()
  FROM public.payout_items pi
  WHERE pi.payout_batch_id = p_batch_id
    AND pi.settlement_id = s.id
    AND s.status = 'locked';

  INSERT INTO public.ledger_entries (
    hotel_id,
    entry_type,
    source_table,
    source_id,
    direction,
    amount,
    currency,
    memo
  )
  SELECT
    pb.hotel_id,
    'payout_completed',
    'payout_batches',
    pb.id,
    'debit',
    pb.total_amount,
    pb.currency,
    concat('Payout completed: ', pb.id)
  FROM public.payout_batches pb
  WHERE pb.id = p_batch_id
  ON CONFLICT DO NOTHING;
END;
$$;

CREATE OR REPLACE FUNCTION public.prevent_ledger_entries_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'ledger_entries are append-only; create a correcting entry instead';
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_ledger_entries_mutation ON public.ledger_entries;
CREATE TRIGGER trg_prevent_ledger_entries_mutation
BEFORE UPDATE OR DELETE ON public.ledger_entries
FOR EACH ROW EXECUTE FUNCTION public.prevent_ledger_entries_mutation();

CREATE TABLE IF NOT EXISTS public.financial_components (
  id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  booking_id uuid REFERENCES public.bookings(id) ON DELETE SET NULL,
  payment_id uuid REFERENCES public.payments(id) ON DELETE SET NULL,
  settlement_id uuid REFERENCES public.settlements(id) ON DELETE SET NULL,
  payout_batch_id uuid REFERENCES public.payout_batches(id) ON DELETE SET NULL,
  provider text,
  component_type text NOT NULL,
  owner_type text NOT NULL,
  direction text NOT NULL CHECK (direction IN ('debit', 'credit')),
  amount numeric(12,2) NOT NULL CHECK (amount >= 0),
  currency text NOT NULL DEFAULT 'TZS',
  rate numeric(8,6),
  basis_amount numeric(12,2),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_financial_components_booking
ON public.financial_components(booking_id);

CREATE INDEX IF NOT EXISTS idx_financial_components_payment
ON public.financial_components(payment_id);

CREATE INDEX IF NOT EXISTS idx_financial_components_settlement
ON public.financial_components(settlement_id);

CREATE TABLE IF NOT EXISTS public.payment_provider_fee_policies (
  id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  provider text NOT NULL,
  fee_rate numeric(8,6) NOT NULL DEFAULT 0,
  flat_fee numeric(12,2) NOT NULL DEFAULT 0,
  fee_owner_type text NOT NULL DEFAULT 'platform',
  applies_from timestamp with time zone DEFAULT now() NOT NULL,
  is_active boolean DEFAULT true NOT NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_payment_provider_fee_policies_active
ON public.payment_provider_fee_policies(provider, is_active, applies_from DESC);

GRANT ALL ON TABLE public.payment_reconciliation_events TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.payout_provider_events TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.financial_components TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.payment_provider_fee_policies TO anon, authenticated, service_role;

GRANT ALL ON FUNCTION public.mark_booking_payment_initiated(uuid, uuid, integer) TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.finalize_paid_booking(uuid, uuid, numeric) TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.mark_payout_batch_processing(uuid, text) TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.mark_payout_batch_submitted(uuid, text, text, jsonb) TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.complete_payout_batch(uuid, text) TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.create_booking(
  cart jsonb,
  user_data jsonb,
  p_session_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_booking_id uuid := gen_random_uuid();
  v_total_price numeric := 0;
  v_conflicts jsonb := '[]'::jsonb;
  v_cart_item jsonb;
  v_item jsonb;
  v_room_id uuid;
  v_day date;
  v_start date;
  v_last_night date;
  v_checkout date;
  v_hotel_id uuid;
  v_booking_hotel_id uuid := NULL;
  v_offering_id uuid;
  v_price_per_night numeric;
  v_ticket_number text := 'BK-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(floor(random() * 999999)::text, 6, '0');
  v_json jsonb;
  v_previous_booking_ids uuid[];
  v_actor_user_id uuid := auth.uid();
  v_expires_at timestamp with time zone := now() + interval '15 minutes';
BEGIN
  IF v_actor_user_id IS NOT NULL AND public.is_account_frozen(v_actor_user_id) THEN
    RETURN jsonb_build_object('success', false, 'message', 'Account is suspended. Please contact support.');
  END IF;

  SELECT array_agg(id) INTO v_previous_booking_ids
  FROM public.bookings
  WHERE session_id = p_session_id
    AND status = 'pending';

  IF v_previous_booking_ids IS NOT NULL THEN
    DELETE FROM public.room_statuses
    WHERE booking_id = ANY(v_previous_booking_ids);

    UPDATE public.bookings
    SET status = 'abandoned'
    WHERE id = ANY(v_previous_booking_ids);
  END IF;

  FOR v_cart_item IN SELECT * FROM jsonb_array_elements(cart)
  LOOP
    v_hotel_id := (v_cart_item ->> 'hotel_id')::uuid;

    IF v_booking_hotel_id IS NULL THEN
      v_booking_hotel_id := v_hotel_id;
    ELSIF v_hotel_id <> v_booking_hotel_id THEN
      RETURN jsonb_build_object('success', false, 'message', 'All rooms in one booking must belong to the same hotel.');
    END IF;

    v_start := (v_cart_item ->> 'start_date')::date;
    v_last_night := (v_cart_item ->> 'end_date')::date;

    IF v_start IS NULL OR v_last_night IS NULL THEN
      RETURN jsonb_build_object('success', false, 'message', 'start_date and end_date are required.');
    END IF;

    IF v_last_night < v_start THEN
      RETURN jsonb_build_object('success', false, 'message', 'end_date cannot be before start_date.');
    END IF;

    v_checkout := (v_last_night + interval '1 day')::date;

    FOR v_item IN SELECT * FROM jsonb_array_elements(v_cart_item -> 'items')
    LOOP
      v_room_id := (v_item ->> 'room_id')::uuid;
      v_offering_id := (v_item ->> 'offering_id')::uuid;

      SELECT price INTO v_price_per_night
      FROM public.offerings
      WHERE id = v_offering_id;

      IF v_price_per_night IS NULL THEN
        RAISE EXCEPTION 'Invalid offering ID: %', v_offering_id;
      END IF;

      FOR v_day IN SELECT generate_series(v_start, v_checkout - interval '1 day', interval '1 day')
      LOOP
        PERFORM pg_advisory_xact_lock(hashtext(v_room_id::text || ':' || v_day::text));

        IF EXISTS (
          SELECT 1
          FROM public.room_statuses
          WHERE room_id = v_room_id
            AND status IN ('booked', 'pending', 'not_available')
            AND date = v_day::date
        ) THEN
          v_conflicts := v_conflicts || jsonb_build_object(
            'room_id', v_room_id,
            'room_number', (SELECT room_number FROM public.hotel_rooms WHERE id = v_room_id),
            'date', v_day::date
          );
        END IF;
      END LOOP;

      v_total_price := v_total_price + v_price_per_night * (v_checkout - v_start);
    END LOOP;
  END LOOP;

  IF jsonb_array_length(v_conflicts) > 0 THEN
    RETURN jsonb_build_object('success', false, 'message', 'Some rooms are already booked for the selected dates.', 'conflicts', v_conflicts);
  END IF;

  INSERT INTO public.bookings (
    id,
    hotel_id,
    customer_name,
    customer_email,
    customer_phone,
    total_price,
    ticket_number,
    status,
    payment_status,
    session_id,
    user_id,
    expires_at
  )
  VALUES (
    v_booking_id,
    v_booking_hotel_id,
    user_data ->> 'name',
    user_data ->> 'email',
    user_data ->> 'phone',
    v_total_price,
    v_ticket_number,
    'pending',
    'unpaid',
    p_session_id,
    v_actor_user_id,
    v_expires_at
  );

  FOR v_cart_item IN SELECT * FROM jsonb_array_elements(cart)
  LOOP
    v_hotel_id := (v_cart_item ->> 'hotel_id')::uuid;
    v_start := (v_cart_item ->> 'start_date')::date;
    v_last_night := (v_cart_item ->> 'end_date')::date;
    v_checkout := (v_last_night + interval '1 day')::date;

    FOR v_item IN SELECT * FROM jsonb_array_elements(v_cart_item -> 'items')
    LOOP
      v_room_id := (v_item ->> 'room_id')::uuid;
      v_offering_id := (v_item ->> 'offering_id')::uuid;

      SELECT price INTO v_price_per_night
      FROM public.offerings
      WHERE id = v_offering_id;

      INSERT INTO public.booking_items (
        booking_id,
        hotel_id,
        room_id,
        offering_id,
        price_per_night,
        start_date,
        end_date
      )
      VALUES (
        v_booking_id,
        v_hotel_id,
        v_room_id,
        v_offering_id,
        v_price_per_night,
        v_start,
        v_checkout
      );

      FOR v_day IN SELECT generate_series(v_start, v_checkout - interval '1 day', interval '1 day')
      LOOP
        INSERT INTO public.room_statuses (room_id, date, status, booking_id)
        VALUES (v_room_id, v_day::date, 'pending', v_booking_id);
      END LOOP;
    END LOOP;
  END LOOP;

  v_json := jsonb_build_object(
    'id', v_booking_id,
    'user_data', user_data,
    'cart', (
      SELECT jsonb_agg(
        jsonb_build_object(
          'hotel', (
            SELECT row_to_json(h) FROM (
              SELECT id, name, description, address, rating, images
              FROM public.hotels
              WHERE id = (cart_item ->> 'hotel_id')::uuid
            ) h
          ),
          'start_date', cart_item ->> 'start_date',
          'end_date', cart_item ->> 'end_date',
          'items', (
            SELECT jsonb_agg(
              jsonb_build_object(
                'offering', (
                  SELECT row_to_json(o) FROM (
                    SELECT id, title, price, description, max_guests
                    FROM public.offerings
                    WHERE id = (item ->> 'offering_id')::uuid
                  ) o
                ),
                'room', (
                  SELECT row_to_json(r) FROM (
                    SELECT id, room_number, description, capacity, is_active, offering_id, hotel_id
                    FROM public.hotel_rooms
                    WHERE id = (item ->> 'room_id')::uuid
                  ) r
                ),
                'price_per_night', (
                  SELECT price FROM public.offerings WHERE id = (item ->> 'offering_id')::uuid
                )
              )
            )
            FROM jsonb_array_elements(cart_item -> 'items') AS item
          )
        )
      )
      FROM jsonb_array_elements(cart) AS cart_item
    ),
    'ticket_number', v_ticket_number,
    'total_price', v_total_price,
    'status', (SELECT status FROM public.bookings WHERE id = v_booking_id::uuid),
    'payment_status', (SELECT payment_status FROM public.bookings WHERE id = v_booking_id::uuid),
    'created_at', (SELECT created_at FROM public.bookings WHERE id = v_booking_id::uuid),
    'expires_at', (SELECT expires_at FROM public.bookings WHERE id = v_booking_id::uuid)
  );

  PERFORM public.log_audit_event(
    p_event_type => 'booking_created',
    p_entity_type => 'booking',
    p_entity_id => v_booking_id::text,
    p_payload => jsonb_build_object(
      'ticket_number', v_ticket_number,
      'hotel_id', v_booking_hotel_id,
      'total_price', v_total_price
    ),
    p_actor_user_id => v_actor_user_id
  );

  RETURN jsonb_build_object('success', true, 'booking', v_json);
END;
$$;
