BEGIN;

INSERT INTO public.roles(name)
VALUES ('system_admin')
ON CONFLICT (name) DO NOTHING;

DO $$
DECLARE
  v_canonical_role_id uuid;
  v_legacy_role_ids uuid[];
BEGIN
  SELECT id
  INTO v_canonical_role_id
  FROM public.roles
  WHERE name = 'system_admin';

  SELECT COALESCE(array_agg(id), ARRAY[]::uuid[])
  INTO v_legacy_role_ids
  FROM public.roles
  WHERE lower(replace(name, '_', '')) = 'systemadmin'
    AND name <> 'system_admin';

  IF array_length(v_legacy_role_ids, 1) IS NOT NULL THEN
    INSERT INTO public.user_roles(user_id, role_id)
    SELECT DISTINCT ur.user_id, v_canonical_role_id
    FROM public.user_roles ur
    WHERE ur.role_id = ANY(v_legacy_role_ids)
    ON CONFLICT (user_id, role_id) DO NOTHING;

    DELETE FROM public.user_roles
    WHERE role_id = ANY(v_legacy_role_ids);

    DELETE FROM public.roles
    WHERE id = ANY(v_legacy_role_ids);
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.user_has_role(
  p_user_id uuid,
  p_role text
)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_roles_view urv
    WHERE urv.user_id = p_user_id
      AND lower(replace(urv.role, '_', '')) =
          lower(replace(COALESCE(p_role, ''), '_', ''))
  );
$$;

CREATE OR REPLACE FUNCTION public.grant_user_role(
  p_user_id uuid,
  p_role text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_role_id uuid;
  v_role text := CASE
    WHEN lower(replace(COALESCE(p_role, ''), '_', '')) = 'systemadmin'
      THEN 'system_admin'
    WHEN lower(replace(COALESCE(p_role, ''), '_', '')) = 'hoteladmin'
      THEN 'hotel_admin'
    ELSE lower(COALESCE(p_role, ''))
  END;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'User ID is required';
  END IF;

  IF v_role = '' THEN
    RAISE EXCEPTION 'Role is required';
  END IF;

  INSERT INTO public.roles(name)
  VALUES (v_role)
  ON CONFLICT (name) DO NOTHING;

  SELECT id
  INTO v_role_id
  FROM public.roles
  WHERE name = v_role
  LIMIT 1;

  IF v_role_id IS NULL THEN
    RAISE EXCEPTION 'Role % was not found', v_role;
  END IF;

  INSERT INTO public.user_roles(user_id, role_id)
  VALUES (p_user_id, v_role_id)
  ON CONFLICT (user_id, role_id) DO NOTHING;
END;
$$;

CREATE OR REPLACE FUNCTION public.resolve_active_persona(
  p_user_id uuid
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_active text;
  v_roles text[];
BEGIN
  IF p_user_id IS NULL THEN
    RETURN 'guest';
  END IF;

  SELECT ap.active_persona
  INTO v_active
  FROM public.account_profiles ap
  WHERE ap.user_id = p_user_id;

  SELECT COALESCE(array_agg(urv.role ORDER BY urv.role), ARRAY[]::text[])
  INTO v_roles
  FROM public.user_roles_view urv
  WHERE urv.user_id = p_user_id;

  IF EXISTS (
    SELECT 1
    FROM unnest(v_roles) AS role_name
    WHERE lower(replace(role_name, '_', '')) = 'systemadmin'
  ) THEN
    RETURN 'system_admin';
  END IF;

  IF v_active IS NOT NULL AND v_active = ANY(v_roles) THEN
    RETURN v_active;
  END IF;

  IF 'hotel_admin' = ANY(v_roles) THEN
    RETURN 'hotel_admin';
  END IF;
  IF 'staff' = ANY(v_roles) THEN
    RETURN 'staff';
  END IF;
  IF 'customer' = ANY(v_roles) THEN
    RETURN 'customer';
  END IF;

  RETURN 'guest';
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

  SELECT COALESCE(array_agg(role_name ORDER BY role_name), ARRAY[]::text[])
  INTO v_roles
  FROM (
    SELECT DISTINCT CASE
      WHEN lower(replace(urv.role, '_', '')) = 'systemadmin' THEN 'system_admin'
      WHEN lower(replace(urv.role, '_', '')) = 'hoteladmin' THEN 'hotel_admin'
      ELSE lower(urv.role)
    END AS role_name
    FROM public.user_roles_view urv
    WHERE urv.user_id = v_uid
  ) normalized_roles;

  IF array_length(v_roles, 1) IS NULL THEN
    PERFORM public.grant_user_role(v_uid, 'customer');
    v_roles := ARRAY['customer'];
  END IF;

  v_active := public.resolve_active_persona(v_uid);

  IF v_active = 'system_admin' THEN
    UPDATE public.account_profiles ap
    SET active_persona = 'system_admin',
        has_seen_onboarding = true,
        onboarding_status = 'completed',
        onboarding_step = 'done',
        updated_at = now()
    WHERE ap.user_id = v_uid;

    SELECT *
    INTO v_profile
    FROM public.account_profiles ap
    WHERE ap.user_id = v_uid;
  ELSE
    UPDATE public.account_profiles ap
    SET active_persona = v_active
    WHERE ap.user_id = v_uid
      AND ap.active_persona IS DISTINCT FROM v_active;
  END IF;

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

UPDATE public.account_profiles ap
SET active_persona = 'system_admin',
    has_seen_onboarding = true,
    onboarding_status = 'completed',
    onboarding_step = 'done',
    updated_at = now()
WHERE EXISTS (
  SELECT 1
  FROM public.user_roles_view urv
  WHERE urv.user_id = ap.user_id
    AND lower(replace(urv.role, '_', '')) = 'systemadmin'
);

REVOKE ALL ON FUNCTION public.user_has_role(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.user_has_role(uuid, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.grant_user_role(uuid, text) FROM PUBLIC;

REVOKE ALL ON FUNCTION public.resolve_active_persona(uuid) FROM PUBLIC;

REVOKE ALL ON FUNCTION public.get_current_user_access_profile() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_current_user_access_profile() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.get_current_user_role() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_current_user_role() TO anon, authenticated, service_role;

COMMIT;
