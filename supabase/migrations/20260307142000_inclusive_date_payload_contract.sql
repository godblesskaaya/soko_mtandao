-- API date contract migration:
-- - Incoming/outgoing payload dates are inclusive (end_date = last night).
-- - Internal booking_items.end_date remains checkout-exclusive for stability.

CREATE OR REPLACE FUNCTION public.get_available_rooms(
  p_hotel_id uuid,
  p_offering_id uuid,
  p_start date,
  p_end date
)
RETURNS SETOF public.hotel_rooms
LANGUAGE sql
AS $$
  SELECT r.*
  FROM public.hotel_rooms r
  WHERE
    r.hotel_id = p_hotel_id
    AND r.offering_id = p_offering_id
    AND r.is_active = true
    AND p_start IS NOT NULL
    AND p_end IS NOT NULL
    AND p_end >= p_start
    AND NOT EXISTS (
      SELECT 1
      FROM public.room_statuses s
      JOIN generate_series(p_start, p_end, interval '1 day') g(day)
        ON s.date = g.day::date
      WHERE s.room_id = r.id
        AND s.status IN ('booked', 'pending', 'not_available')
    )
  ORDER BY r.room_number;
$$;


CREATE OR REPLACE FUNCTION public.search_hotels_advanced(
  search_query text DEFAULT ''::text,
  region_filter text DEFAULT ''::text,
  city_filter text DEFAULT ''::text,
  min_price numeric DEFAULT NULL::numeric,
  max_price numeric DEFAULT NULL::numeric,
  guests integer DEFAULT NULL::integer,
  start_date date DEFAULT NULL::date,
  end_date date DEFAULT NULL::date,
  sort_option text DEFAULT 'relevance'::text,
  limit_count integer DEFAULT 20,
  offset_count integer DEFAULT 0
)
RETURNS TABLE(
  hotel_id uuid,
  hotel_name text,
  hotel_address text,
  city text,
  region text,
  country text,
  rating numeric,
  images character varying,
  available_rooms integer,
  cheapest_price numeric,
  relevance numeric
)
LANGUAGE sql
AS $$
WITH matched_hotels AS (
    SELECT
        h.*,
        (
            0.8 * ts_rank(h.search_vector, plainto_tsquery('simple', search_query)) +
            0.1 * CASE WHEN h.name ILIKE '%' || search_query || '%' THEN 1 ELSE 0 END +
            0.1 * CASE WHEN h.address ILIKE '%' || search_query || '%' THEN 1 ELSE 0 END
        ) AS relevance
    FROM public.hotels h
    WHERE
        (
            search_query IS NULL OR search_query = '' OR
            h.search_vector @@ plainto_tsquery('simple', search_query) OR
            h.name ILIKE '%' || search_query || '%' OR
            h.address ILIKE '%' || search_query || '%'
        )
        AND (
            region_filter = '' OR region_filter IS NULL OR
            h.region ILIKE '%' || region_filter || '%'
        )
        AND (
            city_filter = '' OR city_filter IS NULL OR
            h.city ILIKE '%' || city_filter || '%'
        )
        AND (
            start_date IS NULL OR end_date IS NULL OR end_date >= start_date
        )
),

matched_offerings AS (
    SELECT o.*
    FROM public.offerings o
    WHERE (min_price IS NULL OR o.price >= min_price)
      AND (max_price IS NULL OR o.price <= max_price)
      AND (guests IS NULL OR o.max_guests >= guests)
),

available_rooms AS (
    SELECT
        hr.hotel_id,
        COUNT(*) AS available_count
    FROM public.hotel_rooms hr
    LEFT JOIN public.room_statuses rs
        ON rs.room_id = hr.id
        AND rs.status IN ('booked', 'pending', 'not_available')
        AND (start_date IS NOT NULL OR end_date IS NOT NULL)
        AND rs.date BETWEEN COALESCE(start_date, rs.date)
                        AND COALESCE(end_date, rs.date)
    WHERE rs.id IS NULL
    GROUP BY hr.hotel_id
),

cheapest_prices AS (
    SELECT
        o.hotel_id,
        MIN(o.price) AS cheapest_price
    FROM matched_offerings o
    GROUP BY o.hotel_id
),

base_result AS (
    SELECT
        mh.id AS hotel_id,
        mh.name AS hotel_name,
        mh.address AS hotel_address,
        mh.city AS city,
        mh.region AS region,
        mh.country AS country,
        mh.rating::numeric AS rating,
        mh.images AS images,
        COALESCE(ar.available_count, 0)::integer AS available_rooms,
        cp.cheapest_price AS cheapest_price,
        mh.relevance::numeric AS relevance
    FROM matched_hotels mh
    LEFT JOIN cheapest_prices cp ON cp.hotel_id = mh.id
    LEFT JOIN available_rooms ar ON ar.hotel_id = mh.id
    WHERE cp.cheapest_price IS NOT NULL
)

SELECT *
FROM base_result
ORDER BY
    CASE WHEN sort_option = 'price_asc' THEN cheapest_price END ASC,
    CASE WHEN sort_option = 'price_desc' THEN cheapest_price END DESC,
    CASE WHEN sort_option = 'rating_asc' THEN rating END ASC,
    CASE WHEN sort_option = 'rating_desc' THEN rating END DESC,
    CASE WHEN sort_option = 'rooms_asc' THEN available_rooms END ASC,
    CASE WHEN sort_option = 'rooms_desc' THEN available_rooms END DESC,
    CASE WHEN sort_option = 'name_asc' THEN hotel_name END ASC,
    CASE WHEN sort_option = 'name_desc' THEN hotel_name END DESC,
    CASE WHEN sort_option = 'relevance' THEN relevance END DESC,
    hotel_id ASC
LIMIT limit_count
OFFSET offset_count;
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
          'end_date', (bi.end_date - interval '1 day')::date,
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
