-- Validate manager onboarding property payloads before review/approval.

CREATE OR REPLACE FUNCTION public.validate_manager_hotel_payload(
  p_payload jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_lat double precision;
  v_lng double precision;
  v_total_rooms integer;
BEGIN
  IF p_payload IS NULL OR p_payload = '{}'::jsonb THEN
    RAISE EXCEPTION 'Property details are required before submitting';
  END IF;

  IF COALESCE(trim(p_payload ->> 'name'), '') = '' OR
     COALESCE(trim(p_payload ->> 'address'), '') = '' OR
     COALESCE(trim(p_payload ->> 'region'), '') = '' OR
     COALESCE(trim(p_payload ->> 'country'), '') = '' OR
     COALESCE(trim(p_payload ->> 'city'), '') = '' OR
     COALESCE(trim(p_payload ->> 'phoneNumber'), '') = '' OR
     COALESCE(trim(p_payload ->> 'email'), '') = '' THEN
    RAISE EXCEPTION 'Complete the required property details before submitting';
  END IF;

  IF COALESCE(p_payload ->> 'lat', '') !~ '^-?[0-9]+(\.[0-9]+)?$'
    OR COALESCE(p_payload ->> 'lng', '') !~ '^-?[0-9]+(\.[0-9]+)?$' THEN
    RAISE EXCEPTION 'Choose the hotel location on the map before submitting';
  END IF;

  v_lat := (p_payload ->> 'lat')::double precision;
  v_lng := (p_payload ->> 'lng')::double precision;

  IF v_lat < -90 OR v_lat > 90 OR v_lng < -180 OR v_lng > 180 THEN
    RAISE EXCEPTION 'Choose a valid hotel location on the map';
  END IF;

  IF COALESCE(p_payload ->> 'totalRooms', '') !~ '^[0-9]+$' THEN
    RAISE EXCEPTION 'Total rooms must be at least 1';
  END IF;

  v_total_rooms := (p_payload ->> 'totalRooms')::integer;
  IF v_total_rooms < 1 THEN
    RAISE EXCEPTION 'Total rooms must be at least 1';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_manager_application(
  p_hotel_payload jsonb DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, auth
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_payload jsonb;
  v_first_name text;
  v_last_name text;
  v_phone text;
  v_kyc_status text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  PERFORM public.ensure_account_profile(v_uid);

  SELECT
    COALESCE((u.raw_user_meta_data ->> 'firstName')::text, ''),
    COALESCE((u.raw_user_meta_data ->> 'lastName')::text, ''),
    COALESCE((u.raw_user_meta_data ->> 'phone')::text, COALESCE(u.phone, ''))
  INTO v_first_name, v_last_name, v_phone
  FROM auth.users u
  WHERE u.id = v_uid;

  IF trim(v_first_name) = '' OR trim(v_last_name) = '' OR trim(v_phone) = '' THEN
    RAISE EXCEPTION 'Complete your manager profile before submitting';
  END IF;

  SELECT COALESCE(kp.status, 'pending')
  INTO v_kyc_status
  FROM public.kyc_profiles kp
  WHERE kp.user_id = v_uid
  ORDER BY kp.updated_at DESC NULLS LAST
  LIMIT 1;

  IF v_kyc_status NOT IN ('submitted', 'approved') THEN
    RAISE EXCEPTION 'Submit KYC before sending a hotel manager application';
  END IF;

  IF p_hotel_payload IS NOT NULL THEN
    PERFORM public.save_manager_application_draft(p_hotel_payload);
  END IF;

  SELECT hod.hotel_payload
  INTO v_payload
  FROM public.hotel_onboarding_drafts hod
  WHERE hod.user_id = v_uid
  LIMIT 1;

  PERFORM public.validate_manager_hotel_payload(v_payload);

  UPDATE public.operator_applications
  SET status = 'submitted',
      application_payload = v_payload,
      submitted_at = now()
  WHERE user_id = v_uid;

  UPDATE public.account_profiles
  SET selected_onboarding_path = 'manage_hotel',
      has_seen_onboarding = true,
      onboarding_status = 'in_progress',
      onboarding_step = 'manager_review'
  WHERE user_id = v_uid;

  RETURN public.get_current_user_access_profile();
END;
$$;

CREATE OR REPLACE FUNCTION public.review_manager_application(
  p_application_id uuid,
  p_status text,
  p_review_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, auth, extensions
AS $$
DECLARE
  v_admin uuid := auth.uid();
  v_application public.operator_applications;
  v_payload jsonb;
  v_hotel_id uuid;
  v_images text := '[]';
BEGIN
  IF NOT public.is_system_admin(v_admin) THEN
    RAISE EXCEPTION 'Only system admin can review manager applications';
  END IF;

  IF p_status NOT IN ('under_review', 'approved', 'rejected') THEN
    RAISE EXCEPTION 'Invalid manager application status: %', p_status;
  END IF;

  SELECT *
  INTO v_application
  FROM public.operator_applications oa
  WHERE oa.id = p_application_id
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Manager application not found';
  END IF;

  UPDATE public.operator_applications
  SET status = p_status,
      review_notes = COALESCE(p_review_notes, review_notes),
      reviewed_at = now(),
      reviewed_by = v_admin
  WHERE id = p_application_id;

  IF p_status = 'approved' THEN
    SELECT hod.hotel_payload
    INTO v_payload
    FROM public.hotel_onboarding_drafts hod
    WHERE hod.application_id = p_application_id
    LIMIT 1;

    PERFORM public.validate_manager_hotel_payload(v_payload);

    IF (v_payload -> 'images') IS NOT NULL THEN
      v_images := (v_payload -> 'images')::text;
    END IF;

    SELECT h.id
    INTO v_hotel_id
    FROM public.hotels h
    WHERE h.manager_user_id = v_application.user_id
    ORDER BY h.created_at DESC
    LIMIT 1;

    IF v_hotel_id IS NULL THEN
      INSERT INTO public.hotels (
        name,
        description,
        manager_user_id,
        location,
        address,
        images,
        rating,
        total_rooms,
        region,
        city,
        country,
        phone_number,
        email,
        website
      )
      VALUES (
        v_payload ->> 'name',
        v_payload ->> 'description',
        v_application.user_id,
        ST_SetSRID(
          ST_MakePoint(
            (v_payload ->> 'lng')::double precision,
            (v_payload ->> 'lat')::double precision
          ),
          4326
        )::geography,
        v_payload ->> 'address',
        v_images,
        0,
        (v_payload ->> 'totalRooms')::integer,
        v_payload ->> 'region',
        v_payload ->> 'city',
        v_payload ->> 'country',
        v_payload ->> 'phoneNumber',
        v_payload ->> 'email',
        NULLIF(v_payload ->> 'website', '')
      )
      RETURNING id INTO v_hotel_id;
    END IF;

    PERFORM public.grant_user_role(v_application.user_id, 'hotel_admin');

    UPDATE public.account_profiles
    SET selected_onboarding_path = 'manage_hotel',
        onboarding_status = 'completed',
        onboarding_step = 'done'
    WHERE user_id = v_application.user_id;
  ELSIF p_status = 'rejected' THEN
    UPDATE public.account_profiles
    SET selected_onboarding_path = 'manage_hotel',
        onboarding_status = 'in_progress',
        onboarding_step = 'manager_application'
    WHERE user_id = v_application.user_id;
  END IF;

  RETURN jsonb_build_object(
    'application_id', p_application_id,
    'status', p_status,
    'hotel_id', v_hotel_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.validate_manager_hotel_payload(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.validate_manager_hotel_payload(jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.submit_manager_application(jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.review_manager_application(uuid, text, text) TO authenticated, service_role;
