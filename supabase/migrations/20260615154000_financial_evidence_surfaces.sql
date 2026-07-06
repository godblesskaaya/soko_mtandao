-- Expose financial lifecycle evidence to customer and hotel-manager app surfaces.

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

DROP VIEW IF EXISTS public.manager_hotel_payments_view;
CREATE VIEW public.manager_hotel_payments_view AS
SELECT
  s.id AS settlement_id,
  s.hotel_id,
  s.amount_allocated AS settled_amount,
  s.status AS settlement_status,
  s.created_at AS settled_at,
  s.available_at,
  s.locked_at,
  s.paid_at,
  s.currency,
  s.settlement_type,
  s.payout_batch_id,
  pb.status AS payout_status,
  pb.provider AS payout_provider,
  pb.provider_batch_ref AS payout_provider_batch_ref,
  pb.provider_reference AS payout_provider_reference,
  pb.provider_external_reference AS payout_provider_external_reference,
  pb.provider_status AS payout_provider_status,
  pb.submitted_at AS payout_submitted_at,
  bif.gross_amount,
  bif.commission_amount,
  bif.tax_amount,
  bif.hotel_net_amount,
  COALESCE(fees.provider_fee_amount, 0)::numeric(12,2) AS provider_fee_amount,
  bi.id AS booking_item_id,
  hr.room_number,
  bi.price_per_night,
  bi.start_date,
  bi.end_date,
  (bi.end_date - bi.start_date) AS total_nights,
  b.id AS booking_id,
  b.status AS booking_status,
  b.payment_status AS booking_payment_status,
  b.reconciliation_status AS booking_reconciliation_status,
  b.customer_name,
  b.customer_phone,
  b.customer_email,
  b.ticket_number,
  p.id AS payment_id,
  p.status AS payment_status,
  p.provider_status AS payment_provider_status,
  p.reconciliation_status AS payment_reconciliation_status,
  p.amount AS payment_amount,
  p.amount_received AS payment_amount_received,
  p.payment_gateway_ref,
  p.provider_reference AS payment_provider_reference,
  p.external_id,
  p.type AS payment_method
FROM public.settlements s
JOIN public.booking_items bi ON s.booking_item_id = bi.id
JOIN public.hotel_rooms hr ON bi.room_id = hr.id
JOIN public.bookings b ON bi.booking_id = b.id
JOIN public.payments p ON s.payment_id = p.id
LEFT JOIN public.booking_item_financials bif ON bif.booking_item_id = bi.id
LEFT JOIN public.payout_batches pb ON pb.id = s.payout_batch_id
LEFT JOIN LATERAL (
  SELECT sum(fc.amount) AS provider_fee_amount
  FROM public.financial_components fc
  WHERE fc.payment_id = p.id
    AND fc.component_type = 'provider_collection_fee'
) fees ON true
WHERE s.settlement_type = 'hotel';

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
  pb.status AS payout_status,
  pb.provider AS payout_provider,
  pb.provider_reference AS payout_provider_reference,
  pb.provider_external_reference AS payout_provider_external_reference
FROM public.settlements s
JOIN public.booking_items bi ON bi.id = s.booking_item_id
JOIN public.bookings b ON b.id = bi.booking_id
LEFT JOIN public.payout_batches pb ON pb.id = s.payout_batch_id
WHERE s.settlement_type = 'hotel';

GRANT EXECUTE ON FUNCTION public.get_booking_details_secure(uuid, text) TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.manager_hotel_payments_view TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.hotel_wallet_transactions_view TO anon, authenticated, service_role;
