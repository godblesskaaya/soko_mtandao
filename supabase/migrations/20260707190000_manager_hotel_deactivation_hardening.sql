-- Route hotel deactivation through ownership, booking-safety, and audit checks.

CREATE OR REPLACE FUNCTION public.deactivate_hotel_for_manager(
  p_hotel_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, auth
AS $$
DECLARE
  v_requester uuid := auth.uid();
BEGIN
  IF v_requester IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF NOT public.manager_can_manage_hotel(p_hotel_id, v_requester) THEN
    RAISE EXCEPTION 'Not permitted to deactivate this hotel';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.booking_items bi
    JOIN public.bookings b ON b.id = bi.booking_id
    WHERE bi.hotel_id = p_hotel_id
      AND bi.end_date >= current_date
      AND b.status NOT IN ('cancelled', 'expired')
  ) THEN
    RAISE EXCEPTION 'Cannot deactivate a hotel with active or future bookings';
  END IF;

  UPDATE public.hotels
  SET is_active = false
  WHERE id = p_hotel_id;

  UPDATE public.offerings
  SET is_available = false
  WHERE hotel_id = p_hotel_id;

  UPDATE public.hotel_rooms
  SET is_active = false
  WHERE hotel_id = p_hotel_id;

  PERFORM public.log_audit_event(
    p_event_type => 'manager_hotel_deactivated',
    p_entity_type => 'hotel',
    p_entity_id => p_hotel_id::text,
    p_payload => jsonb_build_object('reason', nullif(trim(COALESCE(p_reason, '')), '')),
    p_actor_user_id => v_requester
  );
END;
$$;

REVOKE ALL ON FUNCTION public.deactivate_hotel_for_manager(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.deactivate_hotel_for_manager(uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.deactivate_hotel_for_manager(uuid, text) TO authenticated, service_role;
