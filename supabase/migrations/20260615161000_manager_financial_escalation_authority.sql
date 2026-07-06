-- Allow hotel managers to escalate financial reconciliation issues for their own bookings.

CREATE OR REPLACE FUNCTION public.submit_dispute(
  p_ticket_number text,
  p_category text,
  p_description text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_dispute_id uuid;
  v_user_id uuid := auth.uid();
  v_is_authorized boolean := false;
BEGIN
  SELECT *
  INTO v_booking
  FROM public.bookings b
  WHERE upper(trim(b.ticket_number)) = upper(trim(p_ticket_number))
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking ticket not found';
  END IF;

  IF v_user_id IS NULL THEN
    v_is_authorized := true;
  ELSIF v_booking.user_id IS NOT NULL AND v_booking.user_id = v_user_id THEN
    v_is_authorized := true;
  ELSIF public.is_system_admin(v_user_id) THEN
    v_is_authorized := true;
  ELSIF EXISTS (
    SELECT 1
    FROM public.hotels h
    WHERE h.id = v_booking.hotel_id
      AND h.manager_user_id = v_user_id
  ) THEN
    v_is_authorized := true;
  END IF;

  IF NOT v_is_authorized THEN
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
    p_payload => jsonb_build_object(
      'ticket_number', v_booking.ticket_number,
      'category', COALESCE(NULLIF(trim(p_category), ''), 'general')
    ),
    p_actor_user_id => v_user_id
  );

  RETURN v_dispute_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_dispute(text, text, text) TO anon, authenticated, service_role;
