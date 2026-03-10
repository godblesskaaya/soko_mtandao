-- Tanzania compliance hardening: containment, KYC/AML controls, audit, disputes, retention.

BEGIN;

ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_bookings_user_id ON public.bookings(user_id);

CREATE TABLE IF NOT EXISTS public.kyc_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  legal_name text,
  national_id text,
  date_of_birth date,
  physical_address text,
  phone_verified boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'submitted', 'approved', 'rejected', 'suspended')),
  submitted_at timestamptz,
  approved_at timestamptz,
  rejected_at timestamptz,
  suspended_at timestamptz,
  reviewed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  review_notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.kyc_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kyc_profile_id uuid NOT NULL REFERENCES public.kyc_profiles(id) ON DELETE CASCADE,
  document_type text NOT NULL DEFAULT 'identity',
  document_url text NOT NULL,
  is_encrypted boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_kyc_profiles_status
  ON public.kyc_profiles(status, updated_at DESC);

CREATE TABLE IF NOT EXISTS public.account_freezes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  is_active boolean NOT NULL DEFAULT true,
  reason text,
  set_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  started_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_account_freezes_user_active
  ON public.account_freezes(user_id, is_active);

CREATE TABLE IF NOT EXISTS public.audit_log (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  actor_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  event_type text NOT NULL,
  entity_type text,
  entity_id text,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  ip_address text,
  user_agent text,
  correlation_id text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_log_event_time
  ON public.audit_log(event_type, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_log_created_at
  ON public.audit_log(created_at DESC);

CREATE TABLE IF NOT EXISTS public.compliance_settings (
  key text PRIMARY KEY,
  value_int integer,
  value_text text,
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid REFERENCES auth.users(id) ON DELETE SET NULL
);

INSERT INTO public.compliance_settings(key, value_int, value_text)
VALUES ('audit_log_retention_days', 2555, '7 years')
ON CONFLICT (key) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.disputes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  ticket_number text NOT NULL,
  submitted_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'submitted'
    CHECK (status IN ('submitted', 'under_review', 'resolved', 'rejected')),
  category text NOT NULL DEFAULT 'general',
  description text NOT NULL,
  admin_notes text,
  sla_due_at timestamptz NOT NULL DEFAULT (now() + interval '72 hours'),
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_disputes_status_created
  ON public.disputes(status, created_at DESC);

ALTER TABLE public.refunds
  ADD COLUMN IF NOT EXISTS requested_by uuid REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.refunds
  ADD COLUMN IF NOT EXISTS sla_due_at timestamptz;

UPDATE public.refunds
SET sla_due_at = COALESCE(sla_due_at, created_at + interval '14 days');

CREATE OR REPLACE VIEW public.refund_sla_tracker_view AS
SELECT
  r.id,
  r.booking_id,
  r.payment_id,
  r.amount,
  r.currency,
  r.status,
  r.created_at,
  r.processed_at,
  r.sla_due_at,
  (r.status <> 'processed' AND now() > r.sla_due_at) AS is_breached
FROM public.refunds r;

CREATE OR REPLACE VIEW public.admin_investigation_queue_view AS
SELECT
  a.id,
  a.event_type,
  a.entity_type,
  a.entity_id,
  a.actor_user_id,
  a.payload,
  a.created_at
FROM public.audit_log a
WHERE a.event_type IN (
  'login_failed',
  'payment_state_changed',
  'payout_dispatch',
  'kyc_status_changed',
  'account_freeze_changed',
  'dispute_submitted'
)
ORDER BY a.created_at DESC;

CREATE OR REPLACE FUNCTION public.prevent_audit_log_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'audit_log is append-only';
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_audit_log_update ON public.audit_log;
CREATE TRIGGER trg_prevent_audit_log_update
BEFORE UPDATE OR DELETE ON public.audit_log
FOR EACH ROW
EXECUTE FUNCTION public.prevent_audit_log_mutation();

CREATE OR REPLACE FUNCTION public.is_system_admin(p_user_id uuid DEFAULT auth.uid())
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
  IF p_user_id IS NULL THEN
    RETURN false;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM public.user_roles_view urv
    WHERE urv.user_id = p_user_id
      AND lower(urv.role) IN ('systemadmin', 'system_admin')
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.is_account_frozen(p_user_id uuid DEFAULT auth.uid())
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
  IF p_user_id IS NULL THEN
    RETURN false;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM public.account_freezes af
    WHERE af.user_id = p_user_id
      AND af.is_active = true
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_current_user_role()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_role text;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN 'guest';
  END IF;

  SELECT urv.role
  INTO v_role
  FROM public.user_roles_view urv
  WHERE urv.user_id = auth.uid()
  LIMIT 1;

  RETURN COALESCE(v_role, 'guest');
END;
$$;

CREATE OR REPLACE FUNCTION public.log_audit_event(
  p_event_type text,
  p_entity_type text DEFAULT NULL,
  p_entity_id text DEFAULT NULL,
  p_payload jsonb DEFAULT '{}'::jsonb,
  p_actor_user_id uuid DEFAULT auth.uid()
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_headers jsonb;
  v_ip text;
  v_user_agent text;
  v_id bigint;
BEGIN
  BEGIN
    v_headers := nullif(current_setting('request.headers', true), '')::jsonb;
  EXCEPTION WHEN OTHERS THEN
    v_headers := '{}'::jsonb;
  END;

  v_ip := NULLIF(split_part(COALESCE(v_headers->>'x-forwarded-for', ''), ',', 1), '');
  v_user_agent := NULLIF(v_headers->>'user-agent', '');

  INSERT INTO public.audit_log(
    actor_user_id,
    event_type,
    entity_type,
    entity_id,
    payload,
    ip_address,
    user_agent
  )
  VALUES (
    p_actor_user_id,
    p_event_type,
    p_entity_type,
    p_entity_id,
    COALESCE(p_payload, '{}'::jsonb),
    v_ip,
    v_user_agent
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;
CREATE OR REPLACE FUNCTION public.submit_kyc_profile(
  p_legal_name text,
  p_national_id text,
  p_date_of_birth date,
  p_physical_address text,
  p_phone_verified boolean DEFAULT false,
  p_document_url text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_profile_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  INSERT INTO public.kyc_profiles(
    user_id,
    legal_name,
    national_id,
    date_of_birth,
    physical_address,
    phone_verified,
    status,
    submitted_at,
    reviewed_by,
    review_notes,
    updated_at
  )
  VALUES (
    v_user_id,
    nullif(trim(p_legal_name), ''),
    nullif(trim(p_national_id), ''),
    p_date_of_birth,
    nullif(trim(p_physical_address), ''),
    COALESCE(p_phone_verified, false),
    'submitted',
    now(),
    NULL,
    NULL,
    now()
  )
  ON CONFLICT (user_id)
  DO UPDATE SET
    legal_name = EXCLUDED.legal_name,
    national_id = EXCLUDED.national_id,
    date_of_birth = EXCLUDED.date_of_birth,
    physical_address = EXCLUDED.physical_address,
    phone_verified = EXCLUDED.phone_verified,
    status = 'submitted',
    submitted_at = now(),
    reviewed_by = NULL,
    review_notes = NULL,
    updated_at = now()
  RETURNING id INTO v_profile_id;

  IF p_document_url IS NOT NULL AND trim(p_document_url) <> '' THEN
    INSERT INTO public.kyc_documents(kyc_profile_id, document_type, document_url, is_encrypted)
    VALUES (v_profile_id, 'identity', trim(p_document_url), true);
  END IF;

  PERFORM public.log_audit_event(
    p_event_type => 'kyc_update',
    p_entity_type => 'kyc_profile',
    p_entity_id => v_profile_id::text,
    p_payload => jsonb_build_object('status', 'submitted')
  );

  RETURN v_profile_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_kyc_status(
  p_user_id uuid,
  p_status text,
  p_notes text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NOT public.is_system_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Only compliance/system admin can set KYC status';
  END IF;

  IF p_status NOT IN ('pending', 'submitted', 'approved', 'rejected', 'suspended') THEN
    RAISE EXCEPTION 'Invalid KYC status: %', p_status;
  END IF;

  UPDATE public.kyc_profiles kp
  SET
    status = p_status,
    reviewed_by = auth.uid(),
    review_notes = NULLIF(trim(p_notes), ''),
    approved_at = CASE WHEN p_status = 'approved' THEN now() ELSE kp.approved_at END,
    rejected_at = CASE WHEN p_status = 'rejected' THEN now() ELSE kp.rejected_at END,
    suspended_at = CASE WHEN p_status = 'suspended' THEN now() ELSE kp.suspended_at END,
    updated_at = now()
  WHERE kp.user_id = p_user_id;

  PERFORM public.log_audit_event(
    p_event_type => 'kyc_status_changed',
    p_entity_type => 'user',
    p_entity_id => p_user_id::text,
    p_payload => jsonb_build_object('status', p_status, 'notes', p_notes)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.set_account_freeze(
  p_user_id uuid,
  p_is_frozen boolean,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NOT public.is_system_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Only compliance/system admin can freeze accounts';
  END IF;

  IF p_is_frozen THEN
    INSERT INTO public.account_freezes(user_id, is_active, reason, set_by, started_at, ended_at, updated_at)
    VALUES (p_user_id, true, NULLIF(trim(p_reason), ''), auth.uid(), now(), NULL, now());
  ELSE
    UPDATE public.account_freezes
    SET
      is_active = false,
      ended_at = now(),
      updated_at = now(),
      set_by = auth.uid(),
      reason = COALESCE(NULLIF(trim(p_reason), ''), reason)
    WHERE user_id = p_user_id
      AND is_active = true;
  END IF;

  PERFORM public.log_audit_event(
    p_event_type => 'account_freeze_changed',
    p_entity_type => 'user',
    p_entity_id => p_user_id::text,
    p_payload => jsonb_build_object('is_frozen', p_is_frozen, 'reason', p_reason)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.set_retention_policy_days(p_days integer)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NOT public.is_system_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Only compliance/system admin can update retention policy';
  END IF;

  IF p_days IS NULL OR p_days < 30 THEN
    RAISE EXCEPTION 'Retention days must be >= 30';
  END IF;

  INSERT INTO public.compliance_settings(key, value_int, value_text, updated_at, updated_by)
  VALUES ('audit_log_retention_days', p_days, (p_days::text || ' days'), now(), auth.uid())
  ON CONFLICT (key)
  DO UPDATE SET
    value_int = EXCLUDED.value_int,
    value_text = EXCLUDED.value_text,
    updated_at = now(),
    updated_by = auth.uid();

  PERFORM public.log_audit_event(
    p_event_type => 'retention_policy_updated',
    p_entity_type => 'compliance_settings',
    p_entity_id => 'audit_log_retention_days',
    p_payload => jsonb_build_object('days', p_days)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_retention_policy_days()
RETURNS integer
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT COALESCE(
    (SELECT value_int FROM public.compliance_settings WHERE key = 'audit_log_retention_days'),
    2555
  );
$$;

CREATE OR REPLACE FUNCTION public.purge_audit_log(
  p_override_days integer DEFAULT NULL,
  p_limit integer DEFAULT 5000
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_days integer;
  v_deleted integer;
BEGIN
  IF NOT public.is_system_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Only compliance/system admin can purge audit logs';
  END IF;

  v_days := COALESCE(p_override_days, public.get_retention_policy_days());

  WITH doomed AS (
    SELECT id
    FROM public.audit_log
    WHERE created_at < (now() - make_interval(days => v_days))
    ORDER BY created_at ASC
    LIMIT GREATEST(COALESCE(p_limit, 5000), 1)
  )
  DELETE FROM public.audit_log a
  USING doomed d
  WHERE a.id = d.id;

  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN COALESCE(v_deleted, 0);
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_dispute(
  p_ticket_number text,
  p_category text,
  p_description text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_dispute_id uuid;
  v_user_id uuid := auth.uid();
BEGIN
  SELECT *
  INTO v_booking
  FROM public.bookings b
  WHERE upper(trim(b.ticket_number)) = upper(trim(p_ticket_number))
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking ticket not found';
  END IF;

  IF v_user_id IS NOT NULL AND v_booking.user_id IS NOT NULL AND v_booking.user_id <> v_user_id THEN
    RAISE EXCEPTION 'Unauthorized dispute submission';
  END IF;

  INSERT INTO public.disputes(
    booking_id,
    ticket_number,
    submitted_by,
    status,
    category,
    description,
    sla_due_at,
    created_at,
    updated_at
  )
  VALUES (
    v_booking.id,
    v_booking.ticket_number,
    v_user_id,
    'submitted',
    COALESCE(NULLIF(trim(p_category), ''), 'general'),
    COALESCE(NULLIF(trim(p_description), ''), 'Dispute submitted'),
    now() + interval '72 hours',
    now(),
    now()
  )
  RETURNING id INTO v_dispute_id;

  PERFORM public.log_audit_event(
    p_event_type => 'dispute_submitted',
    p_entity_type => 'dispute',
    p_entity_id => v_dispute_id::text,
    p_payload => jsonb_build_object('ticket_number', v_booking.ticket_number)
  );

  RETURN v_dispute_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_dispute_status(
  p_dispute_id uuid,
  p_status text,
  p_admin_notes text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NOT public.is_system_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Only compliance/system admin can update disputes';
  END IF;

  IF p_status NOT IN ('submitted', 'under_review', 'resolved', 'rejected') THEN
    RAISE EXCEPTION 'Invalid dispute status: %', p_status;
  END IF;

  UPDATE public.disputes d
  SET
    status = p_status,
    admin_notes = COALESCE(NULLIF(trim(p_admin_notes), ''), d.admin_notes),
    resolved_at = CASE WHEN p_status IN ('resolved', 'rejected') THEN now() ELSE d.resolved_at END,
    updated_at = now()
  WHERE d.id = p_dispute_id;

  PERFORM public.log_audit_event(
    p_event_type => 'dispute_status_changed',
    p_entity_type => 'dispute',
    p_entity_id => p_dispute_id::text,
    p_payload => jsonb_build_object('status', p_status, 'notes', p_admin_notes)
  );
END;
$$;
CREATE OR REPLACE FUNCTION public.create_booking(
  cart jsonb,
  user_data jsonb,
  p_session_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
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
  v_end date;
  v_hotel_id uuid;
  v_booking_hotel_id uuid := NULL;
  v_offering_id uuid;
  v_price_per_night numeric;
  v_ticket_number text := 'BK-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(floor(random() * 999999)::text, 6, '0');
  v_json jsonb;
  v_previous_booking_ids uuid[];
  v_actor_user_id uuid := auth.uid();
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
    v_end := (v_cart_item ->> 'end_date')::date;

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

      FOR v_day IN SELECT generate_series(v_start, v_end - interval '1 day', interval '1 day')
      LOOP
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

      v_total_price := v_total_price + v_price_per_night * (v_end - v_start);
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
    user_id
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
    v_actor_user_id
  );

  FOR v_cart_item IN SELECT * FROM jsonb_array_elements(cart)
  LOOP
    v_hotel_id := (v_cart_item ->> 'hotel_id')::uuid;
    v_start := (v_cart_item ->> 'start_date')::date;
    v_end := (v_cart_item ->> 'end_date')::date;

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
        v_end
      );

      FOR v_day IN SELECT generate_series(v_start, v_end - interval '1 day', interval '1 day')
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
    'expires_at', (SELECT created_at + interval '15 minutes' FROM public.bookings WHERE id = v_booking_id::uuid)
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

CREATE OR REPLACE FUNCTION public.get_booking_details_secure(
  p_booking_id uuid,
  p_ticket_number text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_booking record;
  v_json jsonb;
  v_uid uuid := auth.uid();
  v_is_authorized boolean := false;
BEGIN
  SELECT *
  INTO v_booking
  FROM public.bookings
  WHERE id = p_booking_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Booking not found');
  END IF;

  IF public.is_system_admin(v_uid) THEN
    v_is_authorized := true;
  ELSIF v_uid IS NOT NULL AND v_booking.user_id = v_uid THEN
    v_is_authorized := true;
  ELSIF v_uid IS NOT NULL AND EXISTS (
    SELECT 1
    FROM public.hotels h
    WHERE h.id = v_booking.hotel_id
      AND h.manager_user_id = v_uid
  ) THEN
    v_is_authorized := true;
  ELSIF p_ticket_number IS NOT NULL
     AND trim(p_ticket_number) <> ''
     AND upper(trim(p_ticket_number)) = upper(trim(v_booking.ticket_number)) THEN
    v_is_authorized := true;
  END IF;

  IF NOT v_is_authorized THEN
    RETURN jsonb_build_object('success', false, 'message', 'Unauthorized booking access');
  END IF;

  v_json := jsonb_build_object(
    'id', v_booking.id,
    'user_data', jsonb_build_object(
      'name', v_booking.customer_name,
      'email', v_booking.customer_email,
      'phone', v_booking.customer_phone
    ),
    'cart', (
      SELECT jsonb_agg(
        jsonb_build_object(
          'hotel', (
            SELECT row_to_json(h)
            FROM (
              SELECT id, name, description, address, rating, images
              FROM public.hotels
              WHERE id = bi.hotel_id
            ) h
          ),
          'start_date', bi.start_date,
          'end_date', bi.end_date,
          'items', (
            SELECT jsonb_agg(
              jsonb_build_object(
                'offering', (
                  SELECT row_to_json(o)
                  FROM (
                    SELECT id, title, price, description, max_guests
                    FROM public.offerings
                    WHERE id = bi2.offering_id
                  ) o
                ),
                'room', (
                  SELECT row_to_json(r)
                  FROM (
                    SELECT id, room_number, description, capacity, is_active, offering_id, hotel_id
                    FROM public.hotel_rooms
                    WHERE id = bi2.room_id
                  ) r
                ),
                'price_per_night', bi2.price_per_night
              )
            )
            FROM public.booking_items bi2
            WHERE bi2.booking_id = v_booking.id
              AND bi2.hotel_id = bi.hotel_id
              AND bi2.start_date = bi.start_date
              AND bi2.end_date = bi.end_date
          )
        )
      )
      FROM public.booking_items bi
      WHERE bi.booking_id = v_booking.id
      GROUP BY bi.hotel_id, bi.start_date, bi.end_date
    ),
    'ticket_number', v_booking.ticket_number,
    'total_price', v_booking.total_price,
    'status', v_booking.status,
    'payment_status', v_booking.payment_status,
    'created_at', v_booking.created_at,
    'expires_at', v_booking.created_at + interval '15 minutes'
  );

  RETURN jsonb_build_object('success', true, 'booking', v_json);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_booking_details_by_ticket(p_ticket_number text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_booking_id uuid;
BEGIN
  SELECT b.id
  INTO v_booking_id
  FROM public.bookings b
  WHERE upper(trim(b.ticket_number)) = upper(trim(p_ticket_number))
  LIMIT 1;

  IF v_booking_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Booking not found');
  END IF;

  RETURN public.get_booking_details_secure(v_booking_id, p_ticket_number);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_booking_details(p_booking_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN public.get_booking_details_secure(p_booking_id, NULL);
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
DECLARE
  v_requester uuid := auth.uid();
  v_manager_user_id uuid;
  v_kyc_status text;
  v_batch_id uuid;
BEGIN
  IF v_requester IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF public.is_account_frozen(v_requester) THEN
    RAISE EXCEPTION 'Account is frozen and cannot request payouts';
  END IF;

  SELECT h.manager_user_id
  INTO v_manager_user_id
  FROM public.hotels h
  WHERE h.id = p_hotel_id;

  IF v_manager_user_id IS NULL THEN
    RAISE EXCEPTION 'Hotel not found';
  END IF;

  IF NOT public.is_system_admin(v_requester) AND v_manager_user_id <> v_requester THEN
    RAISE EXCEPTION 'Not permitted to request payout for this hotel';
  END IF;

  SELECT kp.status
  INTO v_kyc_status
  FROM public.kyc_profiles kp
  WHERE kp.user_id = v_manager_user_id
  LIMIT 1;

  IF COALESCE(v_kyc_status, 'pending') <> 'approved' THEN
    RAISE EXCEPTION 'Payout blocked: manager KYC must be approved';
  END IF;

  v_batch_id := public.create_payout_batch(
    p_hotel_id => p_hotel_id,
    p_provider => p_provider,
    p_minimum_threshold => p_minimum_threshold,
    p_idempotency_key => p_idempotency_key,
    p_schedule_type => 'manual',
    p_requested_by => v_requester
  );

  PERFORM public.log_audit_event(
    p_event_type => 'payout_dispatch_requested',
    p_entity_type => 'payout_batch',
    p_entity_id => COALESCE(v_batch_id::text, ''),
    p_payload => jsonb_build_object('hotel_id', p_hotel_id, 'provider', p_provider, 'minimum_threshold', p_minimum_threshold),
    p_actor_user_id => v_requester
  );

  RETURN v_batch_id;
END;
$$;
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT tablename
    FROM pg_tables
    WHERE schemaname = 'public'
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', r.tablename);
  END LOOP;
END;
$$;

DROP POLICY IF EXISTS amenities_select_public ON public.amenities;
CREATE POLICY amenities_select_public ON public.amenities FOR SELECT USING (true);

DROP POLICY IF EXISTS hotels_select_public_or_owner ON public.hotels;
CREATE POLICY hotels_select_public_or_owner ON public.hotels
FOR SELECT
USING (
  true
);

DROP POLICY IF EXISTS hotels_manage_own ON public.hotels;
CREATE POLICY hotels_manage_own ON public.hotels
FOR ALL
USING (manager_user_id = auth.uid() OR public.is_system_admin(auth.uid()))
WITH CHECK (manager_user_id = auth.uid() OR public.is_system_admin(auth.uid()));

DROP POLICY IF EXISTS offerings_select_public_or_owner ON public.offerings;
CREATE POLICY offerings_select_public_or_owner ON public.offerings
FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM public.hotels h
    WHERE h.id = offerings.hotel_id
  )
);

DROP POLICY IF EXISTS offerings_manage_own ON public.offerings;
CREATE POLICY offerings_manage_own ON public.offerings
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM public.hotels h
    WHERE h.id = offerings.hotel_id
      AND (h.manager_user_id = auth.uid() OR public.is_system_admin(auth.uid()))
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.hotels h
    WHERE h.id = offerings.hotel_id
      AND (h.manager_user_id = auth.uid() OR public.is_system_admin(auth.uid()))
  )
);

DROP POLICY IF EXISTS hotel_rooms_select_public_or_owner ON public.hotel_rooms;
CREATE POLICY hotel_rooms_select_public_or_owner ON public.hotel_rooms
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.hotels h
    WHERE h.id = hotel_rooms.hotel_id
  )
);

DROP POLICY IF EXISTS hotel_rooms_manage_own ON public.hotel_rooms;
CREATE POLICY hotel_rooms_manage_own ON public.hotel_rooms
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM public.hotels h
    WHERE h.id = hotel_rooms.hotel_id
      AND (h.manager_user_id = auth.uid() OR public.is_system_admin(auth.uid()))
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.hotels h
    WHERE h.id = hotel_rooms.hotel_id
      AND (h.manager_user_id = auth.uid() OR public.is_system_admin(auth.uid()))
  )
);

DROP POLICY IF EXISTS hotel_amenities_select_public_or_owner ON public.hotel_amenities;
CREATE POLICY hotel_amenities_select_public_or_owner ON public.hotel_amenities
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.hotels h
    WHERE h.id = hotel_amenities.hotel_id
  )
);

DROP POLICY IF EXISTS hotel_amenities_manage_own ON public.hotel_amenities;
CREATE POLICY hotel_amenities_manage_own ON public.hotel_amenities
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM public.hotels h
    WHERE h.id = hotel_amenities.hotel_id
      AND (h.manager_user_id = auth.uid() OR public.is_system_admin(auth.uid()))
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.hotels h
    WHERE h.id = hotel_amenities.hotel_id
      AND (h.manager_user_id = auth.uid() OR public.is_system_admin(auth.uid()))
  )
);

DROP POLICY IF EXISTS room_statuses_select_public_or_owner ON public.room_statuses;
CREATE POLICY room_statuses_select_public_or_owner ON public.room_statuses
FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM public.hotel_rooms hr
    JOIN public.hotels h ON h.id = hr.hotel_id
    WHERE hr.id = room_statuses.room_id
  )
);

DROP POLICY IF EXISTS room_statuses_manage_own ON public.room_statuses;
CREATE POLICY room_statuses_manage_own ON public.room_statuses
FOR ALL
USING (
  EXISTS (
    SELECT 1
    FROM public.hotel_rooms hr
    JOIN public.hotels h ON h.id = hr.hotel_id
    WHERE hr.id = room_statuses.room_id
      AND (h.manager_user_id = auth.uid() OR public.is_system_admin(auth.uid()))
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.hotel_rooms hr
    JOIN public.hotels h ON h.id = hr.hotel_id
    WHERE hr.id = room_statuses.room_id
      AND (h.manager_user_id = auth.uid() OR public.is_system_admin(auth.uid()))
  )
);

DROP POLICY IF EXISTS bookings_select_owner_or_manager ON public.bookings;
CREATE POLICY bookings_select_owner_or_manager ON public.bookings
FOR SELECT
USING (
  public.is_system_admin(auth.uid())
  OR user_id = auth.uid()
  OR EXISTS (
    SELECT 1 FROM public.hotels h
    WHERE h.id = bookings.hotel_id
      AND h.manager_user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS bookings_update_owner_or_manager ON public.bookings;
CREATE POLICY bookings_update_owner_or_manager ON public.bookings
FOR UPDATE
USING (
  public.is_system_admin(auth.uid())
  OR user_id = auth.uid()
  OR EXISTS (
    SELECT 1 FROM public.hotels h
    WHERE h.id = bookings.hotel_id
      AND h.manager_user_id = auth.uid()
  )
)
WITH CHECK (
  public.is_system_admin(auth.uid())
  OR user_id = auth.uid()
  OR EXISTS (
    SELECT 1 FROM public.hotels h
    WHERE h.id = bookings.hotel_id
      AND h.manager_user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS booking_items_select_owner_or_manager ON public.booking_items;
CREATE POLICY booking_items_select_owner_or_manager ON public.booking_items
FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM public.bookings b
    LEFT JOIN public.hotels h ON h.id = b.hotel_id
    WHERE b.id = booking_items.booking_id
      AND (public.is_system_admin(auth.uid()) OR b.user_id = auth.uid() OR h.manager_user_id = auth.uid())
  )
);

DROP POLICY IF EXISTS staff_select_self_or_manager ON public.staff;
CREATE POLICY staff_select_self_or_manager ON public.staff
FOR SELECT
USING (
  public.is_system_admin(auth.uid())
  OR user_id = auth.uid()
  OR EXISTS (
    SELECT 1 FROM public.hotels h
    WHERE h.id = staff.hotel_id
      AND h.manager_user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS staff_manage_manager_or_admin ON public.staff;
CREATE POLICY staff_manage_manager_or_admin ON public.staff
FOR ALL
USING (
  public.is_system_admin(auth.uid())
  OR EXISTS (
    SELECT 1 FROM public.hotels h
    WHERE h.id = staff.hotel_id
      AND h.manager_user_id = auth.uid()
  )
)
WITH CHECK (
  public.is_system_admin(auth.uid())
  OR EXISTS (
    SELECT 1 FROM public.hotels h
    WHERE h.id = staff.hotel_id
      AND h.manager_user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS kyc_profiles_select_self_or_admin ON public.kyc_profiles;
CREATE POLICY kyc_profiles_select_self_or_admin ON public.kyc_profiles
FOR SELECT
USING (user_id = auth.uid() OR public.is_system_admin(auth.uid()));

DROP POLICY IF EXISTS kyc_profiles_insert_self ON public.kyc_profiles;
CREATE POLICY kyc_profiles_insert_self ON public.kyc_profiles
FOR INSERT
WITH CHECK (user_id = auth.uid() OR public.is_system_admin(auth.uid()));

DROP POLICY IF EXISTS kyc_profiles_update_self_or_admin ON public.kyc_profiles;
CREATE POLICY kyc_profiles_update_self_or_admin ON public.kyc_profiles
FOR UPDATE
USING (user_id = auth.uid() OR public.is_system_admin(auth.uid()))
WITH CHECK (user_id = auth.uid() OR public.is_system_admin(auth.uid()));
DROP POLICY IF EXISTS kyc_documents_select_self_or_admin ON public.kyc_documents;
CREATE POLICY kyc_documents_select_self_or_admin ON public.kyc_documents
FOR SELECT
USING (
  public.is_system_admin(auth.uid())
  OR EXISTS (
    SELECT 1
    FROM public.kyc_profiles kp
    WHERE kp.id = kyc_documents.kyc_profile_id
      AND kp.user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS kyc_documents_insert_self_or_admin ON public.kyc_documents;
CREATE POLICY kyc_documents_insert_self_or_admin ON public.kyc_documents
FOR INSERT
WITH CHECK (
  public.is_system_admin(auth.uid())
  OR EXISTS (
    SELECT 1
    FROM public.kyc_profiles kp
    WHERE kp.id = kyc_documents.kyc_profile_id
      AND kp.user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS account_freezes_select_self_or_admin ON public.account_freezes;
CREATE POLICY account_freezes_select_self_or_admin ON public.account_freezes
FOR SELECT
USING (user_id = auth.uid() OR public.is_system_admin(auth.uid()));

DROP POLICY IF EXISTS disputes_select_owner_manager_admin ON public.disputes;
CREATE POLICY disputes_select_owner_manager_admin ON public.disputes
FOR SELECT
USING (
  public.is_system_admin(auth.uid())
  OR submitted_by = auth.uid()
  OR EXISTS (
    SELECT 1
    FROM public.bookings b
    JOIN public.hotels h ON h.id = b.hotel_id
    WHERE b.id = disputes.booking_id
      AND h.manager_user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS disputes_insert_self ON public.disputes;
CREATE POLICY disputes_insert_self ON public.disputes
FOR INSERT
WITH CHECK (submitted_by = auth.uid() OR public.is_system_admin(auth.uid()));

DROP POLICY IF EXISTS disputes_update_admin ON public.disputes;
CREATE POLICY disputes_update_admin ON public.disputes
FOR UPDATE
USING (public.is_system_admin(auth.uid()))
WITH CHECK (public.is_system_admin(auth.uid()));

DROP POLICY IF EXISTS compliance_settings_admin_only ON public.compliance_settings;
CREATE POLICY compliance_settings_admin_only ON public.compliance_settings
FOR ALL
USING (public.is_system_admin(auth.uid()))
WITH CHECK (public.is_system_admin(auth.uid()));

DROP POLICY IF EXISTS audit_log_admin_select ON public.audit_log;
CREATE POLICY audit_log_admin_select ON public.audit_log
FOR SELECT
USING (public.is_system_admin(auth.uid()));

DROP POLICY IF EXISTS payments_select_owner_or_manager ON public.payments;
CREATE POLICY payments_select_owner_or_manager ON public.payments
FOR SELECT
USING (
  public.is_system_admin(auth.uid())
  OR EXISTS (
    SELECT 1
    FROM public.bookings b
    LEFT JOIN public.hotels h ON h.id = b.hotel_id
    WHERE b.id = payments.booking_id
      AND (b.user_id = auth.uid() OR h.manager_user_id = auth.uid())
  )
);

DROP POLICY IF EXISTS payout_batches_select_manager_or_admin ON public.payout_batches;
CREATE POLICY payout_batches_select_manager_or_admin ON public.payout_batches
FOR SELECT
USING (
  public.is_system_admin(auth.uid())
  OR EXISTS (
    SELECT 1
    FROM public.hotels h
    WHERE h.id = payout_batches.hotel_id
      AND h.manager_user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS payouts_items_select_manager_or_admin ON public.payout_items;
CREATE POLICY payouts_items_select_manager_or_admin ON public.payout_items
FOR SELECT
USING (
  public.is_system_admin(auth.uid())
  OR EXISTS (
    SELECT 1
    FROM public.payout_batches pb
    JOIN public.hotels h ON h.id = pb.hotel_id
    WHERE pb.id = payout_items.payout_batch_id
      AND h.manager_user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS settlements_select_manager_or_admin ON public.settlements;
CREATE POLICY settlements_select_manager_or_admin ON public.settlements
FOR SELECT
USING (
  public.is_system_admin(auth.uid())
  OR EXISTS (
    SELECT 1 FROM public.hotels h
    WHERE h.id = settlements.hotel_id
      AND h.manager_user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS ledger_entries_select_manager_or_admin ON public.ledger_entries;
CREATE POLICY ledger_entries_select_manager_or_admin ON public.ledger_entries
FOR SELECT
USING (
  public.is_system_admin(auth.uid())
  OR owner_hotel_id IN (
    SELECT h.id FROM public.hotels h WHERE h.manager_user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS hotel_payout_accounts_rw_manager_or_admin ON public.hotel_payout_accounts;
CREATE POLICY hotel_payout_accounts_rw_manager_or_admin ON public.hotel_payout_accounts
FOR ALL
USING (
  public.is_system_admin(auth.uid())
  OR hotel_id IN (SELECT h.id FROM public.hotels h WHERE h.manager_user_id = auth.uid())
)
WITH CHECK (
  public.is_system_admin(auth.uid())
  OR hotel_id IN (SELECT h.id FROM public.hotels h WHERE h.manager_user_id = auth.uid())
);

DROP POLICY IF EXISTS booking_item_financials_select_manager_or_admin ON public.booking_item_financials;
CREATE POLICY booking_item_financials_select_manager_or_admin ON public.booking_item_financials
FOR SELECT
USING (
  public.is_system_admin(auth.uid())
  OR hotel_id IN (SELECT h.id FROM public.hotels h WHERE h.manager_user_id = auth.uid())
);

DROP POLICY IF EXISTS refunds_select_manager_owner_admin ON public.refunds;
CREATE POLICY refunds_select_manager_owner_admin ON public.refunds
FOR SELECT
USING (
  public.is_system_admin(auth.uid())
  OR requested_by = auth.uid()
  OR EXISTS (
    SELECT 1
    FROM public.bookings b
    JOIN public.hotels h ON h.id = b.hotel_id
    WHERE b.id = refunds.booking_id
      AND (b.user_id = auth.uid() OR h.manager_user_id = auth.uid())
  )
);

DROP POLICY IF EXISTS payment_webhook_events_admin_only ON public.payment_webhook_events;
CREATE POLICY payment_webhook_events_admin_only ON public.payment_webhook_events
FOR SELECT
USING (public.is_system_admin(auth.uid()));

DROP POLICY IF EXISTS payment_logs_admin_only ON public.payment_logs;
CREATE POLICY payment_logs_admin_only ON public.payment_logs
FOR SELECT
USING (public.is_system_admin(auth.uid()));

REVOKE ALL PRIVILEGES ON TABLE
  public.bookings,
  public.booking_items,
  public.payments,
  public.payment_logs,
  public.settlements,
  public.payout_batches,
  public.payout_items,
  public.ledger_entries,
  public.payment_webhook_events,
  public.hotel_payout_accounts,
  public.booking_item_financials,
  public.refunds,
  public.kyc_profiles,
  public.kyc_documents,
  public.account_freezes,
  public.audit_log,
  public.disputes
FROM anon;

REVOKE ALL PRIVILEGES ON TABLE public.user_roles FROM anon, authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public.get_booking_details(uuid) FROM anon, authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION public.create_payout_batch(uuid, text, numeric, text, text, uuid) FROM anon, authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION public.mark_payout_batch_processing(uuid, text) FROM anon, authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION public.complete_payout_batch(uuid, text) FROM anon, authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION public.fail_payout_batch(uuid, text) FROM anon, authenticated;

GRANT EXECUTE ON FUNCTION public.get_current_user_role() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.log_audit_event(text, text, text, jsonb, uuid) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.submit_kyc_profile(text, text, date, text, boolean, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.set_kyc_status(uuid, text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.set_account_freeze(uuid, boolean, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.set_retention_policy_days(integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_retention_policy_days() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.purge_audit_log(integer, integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.submit_dispute(text, text, text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.set_dispute_status(uuid, text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_booking_details_secure(uuid, text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_booking_details_by_ticket(text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.request_hotel_payout(uuid, text, numeric, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.create_booking(jsonb, jsonb, uuid) TO anon, authenticated, service_role;

COMMIT;
