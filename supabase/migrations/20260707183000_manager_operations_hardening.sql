-- Harden manager operations that were previously split across client-side writes.

WITH ranked AS (
  SELECT
    id,
    row_number() OVER (
      PARTITION BY hotel_id, amenity_id
      ORDER BY created_at DESC NULLS LAST, id
    ) AS rn
  FROM public.hotel_amenities
)
DELETE FROM public.hotel_amenities ha
USING ranked r
WHERE ha.id = r.id
  AND r.rn > 1;

WITH ranked AS (
  SELECT
    id,
    row_number() OVER (
      PARTITION BY offering_id, amenity_id
      ORDER BY created_at DESC NULLS LAST, id
    ) AS rn
  FROM public.offering_amenities
)
DELETE FROM public.offering_amenities oa
USING ranked r
WHERE oa.id = r.id
  AND r.rn > 1;

CREATE UNIQUE INDEX IF NOT EXISTS ux_hotel_amenities_hotel_amenity
  ON public.hotel_amenities(hotel_id, amenity_id);

CREATE UNIQUE INDEX IF NOT EXISTS ux_offering_amenities_offering_amenity
  ON public.offering_amenities(offering_id, amenity_id);

CREATE OR REPLACE FUNCTION public.manager_can_manage_hotel(
  p_hotel_id uuid,
  p_user_id uuid DEFAULT auth.uid()
)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path TO public, auth
AS $$
  SELECT COALESCE(public.is_system_admin(p_user_id), false)
    OR EXISTS (
      SELECT 1
      FROM public.hotels h
      WHERE h.id = p_hotel_id
        AND h.manager_user_id = p_user_id
    );
$$;

CREATE OR REPLACE FUNCTION public.upsert_managed_hotel(
  p_hotel_id uuid DEFAULT NULL,
  p_name text DEFAULT NULL,
  p_address text DEFAULT NULL,
  p_description text DEFAULT NULL,
  p_images text[] DEFAULT '{}'::text[],
  p_amenity_ids uuid[] DEFAULT '{}'::uuid[],
  p_lat double precision DEFAULT NULL,
  p_lng double precision DEFAULT NULL,
  p_total_rooms integer DEFAULT 1,
  p_region text DEFAULT NULL,
  p_country text DEFAULT NULL,
  p_city text DEFAULT NULL,
  p_phone_number text DEFAULT NULL,
  p_email text DEFAULT NULL,
  p_website text DEFAULT NULL,
  p_check_in_from text DEFAULT NULL,
  p_check_in_until text DEFAULT NULL,
  p_check_out_until text DEFAULT NULL,
  p_stay_rules text[] DEFAULT '{}'::text[],
  p_check_in_requirements text[] DEFAULT '{}'::text[],
  p_is_active boolean DEFAULT true
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, extensions, auth
AS $$
DECLARE
  v_requester uuid := auth.uid();
  v_hotel_id uuid;
  v_images text := COALESCE(to_jsonb(p_images), '[]'::jsonb)::text;
BEGIN
  IF v_requester IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF nullif(trim(COALESCE(p_name, '')), '') IS NULL THEN
    RAISE EXCEPTION 'Hotel name is required';
  END IF;

  IF nullif(trim(COALESCE(p_address, '')), '') IS NULL THEN
    RAISE EXCEPTION 'Hotel address is required';
  END IF;

  IF nullif(trim(COALESCE(p_city, '')), '') IS NULL
    OR nullif(trim(COALESCE(p_region, '')), '') IS NULL
    OR nullif(trim(COALESCE(p_country, '')), '') IS NULL THEN
    RAISE EXCEPTION 'City, region, and country are required';
  END IF;

  IF p_lat IS NULL OR p_lng IS NULL
    OR p_lat < -90 OR p_lat > 90
    OR p_lng < -180 OR p_lng > 180 THEN
    RAISE EXCEPTION 'Valid latitude and longitude are required';
  END IF;

  IF COALESCE(p_total_rooms, 0) < 1 THEN
    RAISE EXCEPTION 'Total rooms must be at least 1';
  END IF;

  IF p_hotel_id IS NULL THEN
    INSERT INTO public.hotels (
      name,
      address,
      description,
      images,
      location,
      rating,
      total_rooms,
      region,
      country,
      city,
      phone_number,
      email,
      website,
      is_active,
      check_in_from,
      check_in_until,
      check_out_until,
      stay_rules,
      check_in_requirements,
      manager_user_id
    )
    VALUES (
      trim(p_name),
      trim(p_address),
      COALESCE(p_description, ''),
      v_images,
      ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
      0,
      p_total_rooms,
      trim(p_region),
      trim(p_country),
      trim(p_city),
      nullif(trim(COALESCE(p_phone_number, '')), ''),
      nullif(trim(COALESCE(p_email, '')), ''),
      nullif(trim(COALESCE(p_website, '')), ''),
      COALESCE(p_is_active, true),
      nullif(trim(COALESCE(p_check_in_from, '')), ''),
      nullif(trim(COALESCE(p_check_in_until, '')), ''),
      nullif(trim(COALESCE(p_check_out_until, '')), ''),
      COALESCE(p_stay_rules, '{}'::text[]),
      COALESCE(p_check_in_requirements, '{}'::text[]),
      v_requester
    )
    RETURNING id INTO v_hotel_id;
  ELSE
    IF NOT public.manager_can_manage_hotel(p_hotel_id, v_requester) THEN
      RAISE EXCEPTION 'Not permitted to update this hotel';
    END IF;

    UPDATE public.hotels
    SET
      name = trim(p_name),
      address = trim(p_address),
      description = COALESCE(p_description, ''),
      images = v_images,
      location = ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
      total_rooms = p_total_rooms,
      region = trim(p_region),
      country = trim(p_country),
      city = trim(p_city),
      phone_number = nullif(trim(COALESCE(p_phone_number, '')), ''),
      email = nullif(trim(COALESCE(p_email, '')), ''),
      website = nullif(trim(COALESCE(p_website, '')), ''),
      is_active = COALESCE(p_is_active, is_active),
      check_in_from = nullif(trim(COALESCE(p_check_in_from, '')), ''),
      check_in_until = nullif(trim(COALESCE(p_check_in_until, '')), ''),
      check_out_until = nullif(trim(COALESCE(p_check_out_until, '')), ''),
      stay_rules = COALESCE(p_stay_rules, '{}'::text[]),
      check_in_requirements = COALESCE(p_check_in_requirements, '{}'::text[])
    WHERE id = p_hotel_id
    RETURNING id INTO v_hotel_id;

    IF v_hotel_id IS NULL THEN
      RAISE EXCEPTION 'Hotel not found';
    END IF;
  END IF;

  DELETE FROM public.hotel_amenities
  WHERE hotel_id = v_hotel_id
    AND amenity_id <> ALL(COALESCE(p_amenity_ids, '{}'::uuid[]));

  INSERT INTO public.hotel_amenities(hotel_id, amenity_id)
  SELECT v_hotel_id, amenity_id
  FROM unnest(COALESCE(p_amenity_ids, '{}'::uuid[])) amenity_id
  ON CONFLICT (hotel_id, amenity_id) DO NOTHING;

  PERFORM public.log_audit_event(
    p_event_type => CASE WHEN p_hotel_id IS NULL THEN 'manager_hotel_created' ELSE 'manager_hotel_updated' END,
    p_entity_type => 'hotel',
    p_entity_id => v_hotel_id::text,
    p_payload => jsonb_build_object('amenity_count', cardinality(COALESCE(p_amenity_ids, '{}'::uuid[]))),
    p_actor_user_id => v_requester
  );

  RETURN v_hotel_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.upsert_offering_with_amenities(
  p_offering_id uuid DEFAULT NULL,
  p_hotel_id uuid DEFAULT NULL,
  p_title text DEFAULT NULL,
  p_description text DEFAULT NULL,
  p_price numeric DEFAULT NULL,
  p_max_guests integer DEFAULT 1,
  p_is_available boolean DEFAULT true,
  p_amenity_ids uuid[] DEFAULT '{}'::uuid[],
  p_images text[] DEFAULT '{}'::text[]
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, auth
AS $$
DECLARE
  v_requester uuid := auth.uid();
  v_offering_id uuid;
  v_hotel_id uuid;
BEGIN
  IF v_requester IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  v_hotel_id := p_hotel_id;
  IF p_offering_id IS NOT NULL THEN
    SELECT hotel_id INTO v_hotel_id
    FROM public.offerings
    WHERE id = p_offering_id;
  END IF;

  IF v_hotel_id IS NULL THEN
    RAISE EXCEPTION 'Hotel is required';
  END IF;

  IF NOT public.manager_can_manage_hotel(v_hotel_id, v_requester) THEN
    RAISE EXCEPTION 'Not permitted to manage offerings for this hotel';
  END IF;

  IF nullif(trim(COALESCE(p_title, '')), '') IS NULL THEN
    RAISE EXCEPTION 'Offering title is required';
  END IF;

  IF COALESCE(p_price, 0) <= 0 THEN
    RAISE EXCEPTION 'Offering price must be greater than zero';
  END IF;

  IF COALESCE(p_max_guests, 0) < 1 THEN
    RAISE EXCEPTION 'Maximum guests must be at least 1';
  END IF;

  IF p_offering_id IS NULL THEN
    INSERT INTO public.offerings (
      hotel_id,
      title,
      description,
      price,
      max_guests,
      is_available,
      images
    )
    VALUES (
      v_hotel_id,
      trim(p_title),
      COALESCE(p_description, ''),
      p_price,
      p_max_guests,
      COALESCE(p_is_available, true),
      COALESCE(p_images, '{}'::text[])
    )
    RETURNING id INTO v_offering_id;
  ELSE
    UPDATE public.offerings
    SET
      title = trim(p_title),
      description = COALESCE(p_description, ''),
      price = p_price,
      max_guests = p_max_guests,
      is_available = COALESCE(p_is_available, is_available),
      images = COALESCE(p_images, '{}'::text[])
    WHERE id = p_offering_id
    RETURNING id INTO v_offering_id;

    IF v_offering_id IS NULL THEN
      RAISE EXCEPTION 'Offering not found';
    END IF;
  END IF;

  DELETE FROM public.offering_amenities
  WHERE offering_id = v_offering_id
    AND amenity_id <> ALL(COALESCE(p_amenity_ids, '{}'::uuid[]));

  INSERT INTO public.offering_amenities(offering_id, amenity_id)
  SELECT v_offering_id, amenity_id
  FROM unnest(COALESCE(p_amenity_ids, '{}'::uuid[])) amenity_id
  ON CONFLICT (offering_id, amenity_id) DO NOTHING;

  PERFORM public.log_audit_event(
    p_event_type => CASE WHEN p_offering_id IS NULL THEN 'manager_offering_created' ELSE 'manager_offering_updated' END,
    p_entity_type => 'offering',
    p_entity_id => v_offering_id::text,
    p_payload => jsonb_build_object('hotel_id', v_hotel_id, 'amenity_count', cardinality(COALESCE(p_amenity_ids, '{}'::uuid[]))),
    p_actor_user_id => v_requester
  );

  RETURN v_offering_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.upsert_room_for_manager(
  p_room_id uuid DEFAULT NULL,
  p_hotel_id uuid DEFAULT NULL,
  p_offering_id uuid DEFAULT NULL,
  p_room_number text DEFAULT NULL,
  p_capacity integer DEFAULT 1,
  p_is_active boolean DEFAULT true
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, auth
AS $$
DECLARE
  v_requester uuid := auth.uid();
  v_room_id uuid;
  v_hotel_id uuid;
BEGIN
  IF v_requester IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  v_hotel_id := p_hotel_id;
  IF p_room_id IS NOT NULL THEN
    SELECT hotel_id INTO v_hotel_id
    FROM public.hotel_rooms
    WHERE id = p_room_id;
  END IF;

  IF v_hotel_id IS NULL THEN
    RAISE EXCEPTION 'Hotel is required';
  END IF;

  IF NOT public.manager_can_manage_hotel(v_hotel_id, v_requester) THEN
    RAISE EXCEPTION 'Not permitted to manage rooms for this hotel';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.offerings o
    WHERE o.id = p_offering_id
      AND o.hotel_id = v_hotel_id
  ) THEN
    RAISE EXCEPTION 'Offering must belong to this hotel';
  END IF;

  IF nullif(trim(COALESCE(p_room_number, '')), '') IS NULL THEN
    RAISE EXCEPTION 'Room number is required';
  END IF;

  IF COALESCE(p_capacity, 0) < 1 THEN
    RAISE EXCEPTION 'Room capacity must be at least 1';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.hotel_rooms r
    WHERE r.hotel_id = v_hotel_id
      AND lower(trim(r.room_number)) = lower(trim(p_room_number))
      AND r.is_active = true
      AND (p_room_id IS NULL OR r.id <> p_room_id)
  ) THEN
    RAISE EXCEPTION 'An active room with this number already exists';
  END IF;

  IF p_room_id IS NULL THEN
    INSERT INTO public.hotel_rooms (
      hotel_id,
      offering_id,
      room_number,
      capacity,
      is_active
    )
    VALUES (
      v_hotel_id,
      p_offering_id,
      trim(p_room_number),
      p_capacity,
      COALESCE(p_is_active, true)
    )
    RETURNING id INTO v_room_id;
  ELSE
    UPDATE public.hotel_rooms
    SET
      offering_id = p_offering_id,
      room_number = trim(p_room_number),
      capacity = p_capacity,
      is_active = COALESCE(p_is_active, is_active)
    WHERE id = p_room_id
    RETURNING id INTO v_room_id;

    IF v_room_id IS NULL THEN
      RAISE EXCEPTION 'Room not found';
    END IF;
  END IF;

  PERFORM public.log_audit_event(
    p_event_type => CASE WHEN p_room_id IS NULL THEN 'manager_room_created' ELSE 'manager_room_updated' END,
    p_entity_type => 'room',
    p_entity_id => v_room_id::text,
    p_payload => jsonb_build_object('hotel_id', v_hotel_id, 'offering_id', p_offering_id),
    p_actor_user_id => v_requester
  );

  RETURN v_room_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.archive_room_for_manager(
  p_room_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, auth
AS $$
DECLARE
  v_requester uuid := auth.uid();
  v_hotel_id uuid;
BEGIN
  IF v_requester IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT hotel_id INTO v_hotel_id
  FROM public.hotel_rooms
  WHERE id = p_room_id;

  IF v_hotel_id IS NULL THEN
    RAISE EXCEPTION 'Room not found';
  END IF;

  IF NOT public.manager_can_manage_hotel(v_hotel_id, v_requester) THEN
    RAISE EXCEPTION 'Not permitted to archive this room';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.room_statuses rs
    JOIN public.bookings b ON b.id = rs.booking_id
    WHERE rs.room_id = p_room_id
      AND rs.date >= current_date
      AND rs.status IN ('booked', 'pending')
      AND b.status NOT IN ('cancelled', 'expired')
  ) THEN
    RAISE EXCEPTION 'Cannot archive a room with active or future bookings';
  END IF;

  UPDATE public.hotel_rooms
  SET is_active = false
  WHERE id = p_room_id;

  PERFORM public.log_audit_event(
    p_event_type => 'manager_room_archived',
    p_entity_type => 'room',
    p_entity_id => p_room_id::text,
    p_payload => jsonb_build_object('hotel_id', v_hotel_id, 'reason', nullif(trim(COALESCE(p_reason, '')), '')),
    p_actor_user_id => v_requester
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.archive_offering_for_manager(
  p_offering_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, auth
AS $$
DECLARE
  v_requester uuid := auth.uid();
  v_hotel_id uuid;
BEGIN
  IF v_requester IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT hotel_id INTO v_hotel_id
  FROM public.offerings
  WHERE id = p_offering_id;

  IF v_hotel_id IS NULL THEN
    RAISE EXCEPTION 'Offering not found';
  END IF;

  IF NOT public.manager_can_manage_hotel(v_hotel_id, v_requester) THEN
    RAISE EXCEPTION 'Not permitted to archive this offering';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.booking_items bi
    JOIN public.bookings b ON b.id = bi.booking_id
    WHERE bi.offering_id = p_offering_id
      AND bi.end_date >= current_date
      AND b.status NOT IN ('cancelled', 'expired')
  ) THEN
    RAISE EXCEPTION 'Cannot archive an offering with active or future bookings';
  END IF;

  UPDATE public.offerings
  SET is_available = false
  WHERE id = p_offering_id;

  UPDATE public.hotel_rooms
  SET is_active = false
  WHERE offering_id = p_offering_id
    AND NOT EXISTS (
      SELECT 1
      FROM public.room_statuses rs
      JOIN public.bookings b ON b.id = rs.booking_id
      WHERE rs.room_id = hotel_rooms.id
        AND rs.date >= current_date
        AND rs.status IN ('booked', 'pending')
        AND b.status NOT IN ('cancelled', 'expired')
    );

  PERFORM public.log_audit_event(
    p_event_type => 'manager_offering_archived',
    p_entity_type => 'offering',
    p_entity_id => p_offering_id::text,
    p_payload => jsonb_build_object('hotel_id', v_hotel_id, 'reason', nullif(trim(COALESCE(p_reason, '')), '')),
    p_actor_user_id => v_requester
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.upsert_room_statuses(
  p_room_id uuid,
  p_status text,
  p_note text DEFAULT NULL,
  p_start_date date DEFAULT NULL,
  p_end_date date DEFAULT NULL,
  p_dates date[] DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, auth
AS $$
DECLARE
  v_requester uuid := auth.uid();
  v_hotel_id uuid;
  v_dates date[];
  v_status text := lower(trim(COALESCE(p_status, '')));
BEGIN
  IF v_requester IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT hotel_id INTO v_hotel_id
  FROM public.hotel_rooms
  WHERE id = p_room_id
    AND is_active = true;

  IF v_hotel_id IS NULL THEN
    RAISE EXCEPTION 'Active room not found';
  END IF;

  IF NOT public.manager_can_manage_hotel(v_hotel_id, v_requester) THEN
    RAISE EXCEPTION 'Not permitted to manage this room status';
  END IF;

  IF v_status = 'vacant' THEN
    v_status := 'available';
  ELSIF v_status = 'outofservice' OR v_status = 'out_of_service' THEN
    v_status := 'not_available';
  END IF;

  IF v_status NOT IN ('available', 'not_available') THEN
    RAISE EXCEPTION 'Managers may only set rooms available or not available';
  END IF;

  IF p_dates IS NOT NULL AND cardinality(p_dates) > 0 THEN
    SELECT array_agg(DISTINCT d ORDER BY d)
    INTO v_dates
    FROM unnest(p_dates) d;
  ELSIF p_start_date IS NOT NULL AND p_end_date IS NOT NULL THEN
    IF p_end_date < p_start_date THEN
      RAISE EXCEPTION 'End date must be after start date';
    END IF;

    SELECT array_agg(d::date ORDER BY d::date)
    INTO v_dates
    FROM generate_series(p_start_date, p_end_date, interval '1 day') AS d;
  ELSIF p_start_date IS NOT NULL THEN
    v_dates := ARRAY[p_start_date];
  ELSE
    RAISE EXCEPTION 'No valid date(s) provided';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM unnest(v_dates) d
    WHERE d < current_date
  ) THEN
    RAISE EXCEPTION 'Cannot update inventory dates in the past';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.room_statuses rs
    JOIN public.bookings b ON b.id = rs.booking_id
    WHERE rs.room_id = p_room_id
      AND rs.date = ANY(v_dates)
      AND rs.status IN ('booked', 'pending')
      AND b.status NOT IN ('cancelled', 'expired')
  ) THEN
    RAISE EXCEPTION 'Cannot overwrite dates held by active bookings';
  END IF;

  DELETE FROM public.room_statuses
  WHERE room_id = p_room_id
    AND date = ANY(v_dates)
    AND booking_id IS NULL;

  IF v_status = 'not_available' THEN
    INSERT INTO public.room_statuses (room_id, status, note, date)
    SELECT p_room_id, 'not_available', nullif(trim(COALESCE(p_note, '')), ''), unnest(v_dates)
    ON CONFLICT (room_id, date) WHERE status IN ('booked', 'pending', 'not_available')
    DO UPDATE SET
      status = EXCLUDED.status,
      note = EXCLUDED.note,
      updated_at = now()
    WHERE public.room_statuses.booking_id IS NULL;
  END IF;

  PERFORM public.log_audit_event(
    p_event_type => 'manager_room_status_updated',
    p_entity_type => 'room',
    p_entity_id => p_room_id::text,
    p_payload => jsonb_build_object('hotel_id', v_hotel_id, 'status', v_status, 'dates', to_jsonb(v_dates)),
    p_actor_user_id => v_requester
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.cancel_booking_for_manager(
  p_booking_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, auth
AS $$
DECLARE
  v_requester uuid := auth.uid();
  v_booking public.bookings%ROWTYPE;
  v_outcome text;
BEGIN
  IF v_requester IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT *
  INTO v_booking
  FROM public.bookings
  WHERE id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking not found';
  END IF;

  IF NOT public.manager_can_manage_hotel(v_booking.hotel_id, v_requester) THEN
    RAISE EXCEPTION 'Not permitted to cancel this booking';
  END IF;

  IF v_booking.status IN ('cancelled', 'expired') THEN
    RETURN jsonb_build_object('outcome', 'already_cancelled', 'booking_id', p_booking_id);
  END IF;

  IF COALESCE(v_booking.amount_paid, 0) > 0
    OR v_booking.payment_status IN ('completed', 'paid', 'success') THEN
    UPDATE public.bookings
    SET
      status = 'cancellation_requested',
      reconciliation_status = 'refund_required'
    WHERE id = p_booking_id;

    v_outcome := 'refund_required';
  ELSE
    UPDATE public.bookings
    SET
      status = 'cancelled',
      payment_status = 'cancelled',
      reconciliation_status = 'none'
    WHERE id = p_booking_id;

    DELETE FROM public.room_statuses
    WHERE booking_id = p_booking_id
      AND status = 'pending';

    v_outcome := 'cancelled';
  END IF;

  PERFORM public.log_audit_event(
    p_event_type => 'manager_booking_cancelled',
    p_entity_type => 'booking',
    p_entity_id => p_booking_id::text,
    p_payload => jsonb_build_object('hotel_id', v_booking.hotel_id, 'outcome', v_outcome, 'reason', nullif(trim(COALESCE(p_reason, '')), '')),
    p_actor_user_id => v_requester
  );

  RETURN jsonb_build_object('outcome', v_outcome, 'booking_id', p_booking_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.cancel_staff_invite(
  p_invite_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, auth
AS $$
DECLARE
  v_requester uuid := auth.uid();
  v_hotel_id uuid;
BEGIN
  IF v_requester IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT hotel_id INTO v_hotel_id
  FROM public.staff_invites
  WHERE id = p_invite_id;

  IF v_hotel_id IS NULL THEN
    RAISE EXCEPTION 'Invite not found';
  END IF;

  IF NOT public.manager_can_manage_hotel(v_hotel_id, v_requester) THEN
    RAISE EXCEPTION 'Not permitted to cancel this invite';
  END IF;

  UPDATE public.staff_invites
  SET status = 'cancelled'
  WHERE id = p_invite_id
    AND status = 'pending';

  PERFORM public.log_audit_event(
    p_event_type => 'manager_staff_invite_cancelled',
    p_entity_type => 'staff_invite',
    p_entity_id => p_invite_id::text,
    p_payload => jsonb_build_object('hotel_id', v_hotel_id),
    p_actor_user_id => v_requester
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.update_staff_assignment(
  p_staff_id uuid,
  p_role text DEFAULT NULL,
  p_is_active boolean DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, auth
AS $$
DECLARE
  v_requester uuid := auth.uid();
  v_staff public.staff%ROWTYPE;
  v_role text := lower(trim(COALESCE(p_role, '')));
BEGIN
  IF v_requester IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT *
  INTO v_staff
  FROM public.staff
  WHERE id = p_staff_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Staff member not found';
  END IF;

  IF NOT public.manager_can_manage_hotel(v_staff.hotel_id, v_requester) THEN
    RAISE EXCEPTION 'Not permitted to update this staff member';
  END IF;

  IF p_role IS NOT NULL
    AND v_role NOT IN ('front_desk', 'housekeeping', 'accounting', 'maintenance', 'manager') THEN
    RAISE EXCEPTION 'Invalid staff role';
  END IF;

  UPDATE public.staff
  SET
    role = COALESCE(NULLIF(v_role, ''), role),
    is_active = COALESCE(p_is_active, is_active)
  WHERE id = p_staff_id;

  PERFORM public.log_audit_event(
    p_event_type => 'manager_staff_assignment_updated',
    p_entity_type => 'staff',
    p_entity_id => p_staff_id::text,
    p_payload => jsonb_build_object('hotel_id', v_staff.hotel_id, 'role', COALESCE(NULLIF(v_role, ''), v_staff.role), 'is_active', COALESCE(p_is_active, v_staff.is_active)),
    p_actor_user_id => v_requester
  );
END;
$$;

REVOKE ALL ON FUNCTION public.manager_can_manage_hotel(uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.upsert_managed_hotel(uuid, text, text, text, text[], uuid[], double precision, double precision, integer, text, text, text, text, text, text, text, text, text, text[], text[], boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.upsert_offering_with_amenities(uuid, uuid, text, text, numeric, integer, boolean, uuid[], text[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.upsert_room_for_manager(uuid, uuid, uuid, text, integer, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.archive_room_for_manager(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.archive_offering_for_manager(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.upsert_room_statuses(uuid, text, text, date, date, date[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.cancel_booking_for_manager(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.cancel_staff_invite(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.update_staff_assignment(uuid, text, boolean) FROM PUBLIC;

REVOKE ALL ON FUNCTION public.manager_can_manage_hotel(uuid, uuid) FROM anon;
REVOKE ALL ON FUNCTION public.upsert_managed_hotel(uuid, text, text, text, text[], uuid[], double precision, double precision, integer, text, text, text, text, text, text, text, text, text, text[], text[], boolean) FROM anon;
REVOKE ALL ON FUNCTION public.upsert_offering_with_amenities(uuid, uuid, text, text, numeric, integer, boolean, uuid[], text[]) FROM anon;
REVOKE ALL ON FUNCTION public.upsert_room_for_manager(uuid, uuid, uuid, text, integer, boolean) FROM anon;
REVOKE ALL ON FUNCTION public.archive_room_for_manager(uuid, text) FROM anon;
REVOKE ALL ON FUNCTION public.archive_offering_for_manager(uuid, text) FROM anon;
REVOKE ALL ON FUNCTION public.upsert_room_statuses(uuid, text, text, date, date, date[]) FROM anon;
REVOKE ALL ON FUNCTION public.cancel_booking_for_manager(uuid, text) FROM anon;
REVOKE ALL ON FUNCTION public.cancel_staff_invite(uuid) FROM anon;
REVOKE ALL ON FUNCTION public.update_staff_assignment(uuid, text, boolean) FROM anon;

GRANT EXECUTE ON FUNCTION public.manager_can_manage_hotel(uuid, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.upsert_managed_hotel(uuid, text, text, text, text[], uuid[], double precision, double precision, integer, text, text, text, text, text, text, text, text, text, text[], text[], boolean) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.upsert_offering_with_amenities(uuid, uuid, text, text, numeric, integer, boolean, uuid[], text[]) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.upsert_room_for_manager(uuid, uuid, uuid, text, integer, boolean) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.archive_room_for_manager(uuid, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.archive_offering_for_manager(uuid, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.upsert_room_statuses(uuid, text, text, date, date, date[]) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.cancel_booking_for_manager(uuid, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.cancel_staff_invite(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.update_staff_assignment(uuid, text, boolean) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.submit_kyc_profile(
  p_legal_name text,
  p_national_id text,
  p_date_of_birth date,
  p_physical_address text,
  p_phone_verified boolean DEFAULT false,
  p_document_url text DEFAULT NULL,
  p_business_registration_number text DEFAULT NULL,
  p_tax_identification_number text DEFAULT NULL,
  p_business_type text DEFAULT NULL,
  p_beneficial_owner_name text DEFAULT NULL,
  p_beneficial_owner_national_id text DEFAULT NULL,
  p_compliance_contact_phone text DEFAULT NULL,
  p_compliance_contact_email text DEFAULT NULL,
  p_payout_terms_accepted boolean DEFAULT false,
  p_payout_terms_version text DEFAULT 'azampay-payouts-v1'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_profile_id uuid;
  v_phone_verified boolean := false;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  v_phone_verified := CASE
    WHEN public.is_system_admin(v_user_id) THEN COALESCE(p_phone_verified, false)
    ELSE false
  END;

  IF nullif(trim(p_legal_name), '') IS NULL
    OR nullif(trim(p_national_id), '') IS NULL
    OR p_date_of_birth IS NULL
    OR nullif(trim(p_physical_address), '') IS NULL
    OR nullif(trim(p_business_type), '') IS NULL
    OR nullif(trim(p_beneficial_owner_name), '') IS NULL
    OR nullif(trim(p_beneficial_owner_national_id), '') IS NULL
    OR nullif(trim(p_compliance_contact_phone), '') IS NULL
    OR nullif(trim(p_compliance_contact_email), '') IS NULL THEN
    RAISE EXCEPTION 'KYC submission is incomplete';
  END IF;

  IF COALESCE(p_payout_terms_accepted, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'Payout compliance terms must be accepted';
  END IF;

  INSERT INTO public.kyc_profiles(
    user_id,
    legal_name,
    national_id,
    date_of_birth,
    physical_address,
    phone_verified,
    business_registration_number,
    tax_identification_number,
    business_type,
    beneficial_owner_name,
    beneficial_owner_national_id,
    compliance_contact_phone,
    compliance_contact_email,
    payout_terms_accepted_at,
    payout_terms_version,
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
    v_phone_verified,
    nullif(trim(p_business_registration_number), ''),
    nullif(trim(p_tax_identification_number), ''),
    nullif(trim(p_business_type), ''),
    nullif(trim(p_beneficial_owner_name), ''),
    nullif(trim(p_beneficial_owner_national_id), ''),
    nullif(trim(p_compliance_contact_phone), ''),
    lower(nullif(trim(p_compliance_contact_email), '')),
    now(),
    nullif(trim(p_payout_terms_version), ''),
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
    business_registration_number = EXCLUDED.business_registration_number,
    tax_identification_number = EXCLUDED.tax_identification_number,
    business_type = EXCLUDED.business_type,
    beneficial_owner_name = EXCLUDED.beneficial_owner_name,
    beneficial_owner_national_id = EXCLUDED.beneficial_owner_national_id,
    compliance_contact_phone = EXCLUDED.compliance_contact_phone,
    compliance_contact_email = EXCLUDED.compliance_contact_email,
    payout_terms_accepted_at = EXCLUDED.payout_terms_accepted_at,
    payout_terms_version = EXCLUDED.payout_terms_version,
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
    p_payload => jsonb_build_object(
      'status', 'submitted',
      'payout_terms_version', p_payout_terms_version,
      'phone_verified_accepted', v_phone_verified
    ),
    p_actor_user_id => v_user_id
  );

  RETURN v_profile_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_kyc_profile(text, text, date, text, boolean, text, text, text, text, text, text, text, text, boolean, text) TO authenticated, service_role;
