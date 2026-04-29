CREATE OR REPLACE FUNCTION public.get_current_user_access_profile()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
VOLATILE
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_profile public.account_profiles;
  v_roles text[];
  v_active text;
  v_staff_status text := 'none';
  v_manager_status text := 'none';
  v_kyc_status text := 'pending';
  v_managed_count integer := 0;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object(
      'active_persona', 'guest',
      'roles', jsonb_build_array(),
      'selected_onboarding_path', NULL,
      'onboarding_status', 'not_started',
      'onboarding_step', 'welcome',
      'has_seen_onboarding', false,
      'staff_association_status', 'none',
      'manager_application_status', 'none',
      'kyc_status', 'pending',
      'managed_hotel_count', 0
    );
  END IF;

  v_profile := public.ensure_account_profile(v_uid);

  SELECT COALESCE(array_agg(urv.role ORDER BY urv.role), ARRAY[]::text[])
  INTO v_roles
  FROM public.user_roles_view urv
  WHERE urv.user_id = v_uid;

  IF array_length(v_roles, 1) IS NULL THEN
    PERFORM public.grant_user_role(v_uid, 'customer');
    v_roles := ARRAY['customer'];
  END IF;

  v_active := public.resolve_active_persona(v_uid);

  SELECT COALESCE(kp.status, 'pending')
  INTO v_kyc_status
  FROM public.kyc_profiles kp
  WHERE kp.user_id = v_uid
  ORDER BY kp.updated_at DESC NULLS LAST
  LIMIT 1;

  SELECT COALESCE(oa.status, 'none')
  INTO v_manager_status
  FROM public.operator_applications oa
  WHERE oa.user_id = v_uid
  ORDER BY oa.updated_at DESC NULLS LAST
  LIMIT 1;

  IF EXISTS (
    SELECT 1
    FROM public.staff s
    WHERE s.user_id = v_uid
      AND s.hotel_id IS NOT NULL
      AND COALESCE(s.is_active, true) = true
  ) THEN
    v_staff_status := 'accepted';
  ELSE
    SELECT COALESCE(sjr.status, 'none')
    INTO v_staff_status
    FROM public.staff_join_requests sjr
    WHERE sjr.user_id = v_uid
    ORDER BY sjr.updated_at DESC NULLS LAST
    LIMIT 1;
  END IF;

  SELECT COUNT(*)
  INTO v_managed_count
  FROM public.hotels h
  WHERE h.manager_user_id = v_uid;

  UPDATE public.account_profiles ap
  SET active_persona = v_active
  WHERE ap.user_id = v_uid
    AND ap.active_persona IS DISTINCT FROM v_active;

  SELECT *
  INTO v_profile
  FROM public.account_profiles ap
  WHERE ap.user_id = v_uid;

  RETURN jsonb_build_object(
    'active_persona', v_active,
    'roles', to_jsonb(v_roles),
    'selected_onboarding_path', v_profile.selected_onboarding_path,
    'onboarding_status', v_profile.onboarding_status,
    'onboarding_step', v_profile.onboarding_step,
    'has_seen_onboarding', v_profile.has_seen_onboarding,
    'staff_association_status', v_staff_status,
    'manager_application_status', v_manager_status,
    'kyc_status', v_kyc_status,
    'managed_hotel_count', v_managed_count
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_current_user_role()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
VOLATILE
AS $$
DECLARE
  v_profile jsonb;
BEGIN
  v_profile := public.get_current_user_access_profile();
  RETURN COALESCE(v_profile ->> 'active_persona', 'guest');
END;
$$;
