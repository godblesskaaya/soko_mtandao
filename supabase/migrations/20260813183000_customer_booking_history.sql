-- Provide a server-backed customer booking history and make booking detail
-- cart aggregation safe for bookings with multiple grouped stays.

CREATE OR REPLACE FUNCTION public.get_booking_details_secure(
  p_booking_id uuid,
  p_ticket_number text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
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
    'cart', COALESCE((
      SELECT jsonb_agg(grouped.payload ORDER BY grouped.start_date, grouped.end_date, grouped.hotel_id)
      FROM (
        SELECT
          bi.hotel_id,
          bi.start_date,
          bi.end_date,
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
            'items', COALESCE((
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
                ORDER BY bi2.id
              )
              FROM public.booking_items bi2
              WHERE bi2.booking_id = v_booking.id
                AND bi2.hotel_id = bi.hotel_id
                AND bi2.start_date = bi.start_date
                AND bi2.end_date = bi.end_date
            ), '[]'::jsonb)
          ) AS payload
        FROM public.booking_items bi
        WHERE bi.booking_id = v_booking.id
        GROUP BY bi.hotel_id, bi.start_date, bi.end_date
      ) grouped
    ), '[]'::jsonb),
    'ticket_number', v_booking.ticket_number,
    'total_price', v_booking.total_price,
    'amount_paid', v_booking.amount_paid,
    'status', v_booking.status,
    'payment_status', v_booking.payment_status,
    'reconciliation_status', COALESCE(v_booking.reconciliation_status, 'none'),
    'payment_initiated_at', v_booking.payment_initiated_at,
    'provider_grace_expires_at', v_booking.provider_grace_expires_at,
    'payment_completed_at', v_booking.payment_completed_at,
    'created_at', v_booking.created_at,
    'expires_at', COALESCE(v_booking.expires_at, v_booking.created_at::timestamp with time zone + interval '15 minutes'),
    'latest_payment', (
      SELECT jsonb_build_object(
        'id', p.id,
        'status', p.status,
        'provider_status', p.provider_status,
        'reconciliation_status', p.reconciliation_status,
        'amount', p.amount,
        'amount_received', p.amount_received,
        'currency', p.currency,
        'payment_gateway_ref', p.payment_gateway_ref,
        'provider_reference', p.provider_reference,
        'external_id', p.external_id,
        'type', p.type,
        'created_at', p.created_at,
        'provider_finalized_at', p.provider_finalized_at
      )
      FROM public.payments p
      WHERE p.booking_id = v_booking.id
      ORDER BY p.created_at DESC
      LIMIT 1
    )
  );

  RETURN jsonb_build_object('success', true, 'booking', v_json);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_my_bookings(
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_limit integer := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 100);
  v_offset integer := GREATEST(COALESCE(p_offset, 0), 0);
  v_bookings jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Authentication required',
      'bookings', '[]'::jsonb
    );
  END IF;

  SELECT COALESCE(jsonb_agg(detail.response -> 'booking' ORDER BY detail.created_at DESC), '[]'::jsonb)
  INTO v_bookings
  FROM (
    SELECT
      b.id,
      b.created_at,
      public.get_booking_details_secure(b.id, NULL) AS response
    FROM public.bookings b
    WHERE b.user_id = v_uid
    ORDER BY b.created_at DESC
    LIMIT v_limit
    OFFSET v_offset
  ) detail
  WHERE detail.response ->> 'success' = 'true';

  RETURN jsonb_build_object(
    'success', true,
    'bookings', COALESCE(v_bookings, '[]'::jsonb)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_my_bookings(integer, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_my_bookings(integer, integer) TO authenticated, service_role;
