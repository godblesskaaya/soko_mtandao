-- Redesign onboarding and multi-role access to separate:
-- - basic account creation
-- - onboarding progress
-- - granted permissions

INSERT INTO public.roles (name)
VALUES
  ('customer'),
  ('staff'),
  ('hotel_admin'),
  ('system_admin')
ON CONFLICT (name) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.account_profiles (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  active_persona text NOT NULL DEFAULT 'customer',
  selected_onboarding_path text,
  onboarding_status text NOT NULL DEFAULT 'not_started',
  onboarding_step text NOT NULL DEFAULT 'welcome',
  has_seen_onboarding boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT account_profiles_active_persona_check
    CHECK (active_persona IN ('customer', 'staff', 'hotel_admin', 'system_admin')),
  CONSTRAINT account_profiles_selected_path_check
    CHECK (
      selected_onboarding_path IS NULL OR
      selected_onboarding_path IN ('customer', 'manage_hotel', 'join_team')
    ),
  CONSTRAINT account_profiles_onboarding_status_check
    CHECK (onboarding_status IN ('not_started', 'in_progress', 'completed'))
);

CREATE TABLE IF NOT EXISTS public.operator_applications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'draft',
  review_notes text,
  application_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  submitted_at timestamp with time zone,
  reviewed_at timestamp with time zone,
  reviewed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT operator_applications_status_check
    CHECK (status IN ('draft', 'submitted', 'under_review', 'approved', 'rejected'))
);

CREATE TABLE IF NOT EXISTS public.hotel_onboarding_drafts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id uuid NOT NULL UNIQUE REFERENCES public.operator_applications(id) ON DELETE CASCADE,
  user_id uuid NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  hotel_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.staff_invites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hotel_id uuid NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
  email text NOT NULL,
  staff_title text NOT NULL DEFAULT 'front_desk',
  invite_token uuid NOT NULL DEFAULT gen_random_uuid(),
  status text NOT NULL DEFAULT 'pending',
  expires_at timestamp with time zone,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  accepted_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT staff_invites_status_check
    CHECK (status IN ('pending', 'accepted', 'cancelled', 'expired'))
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_staff_invites_token
  ON public.staff_invites(invite_token);

CREATE TABLE IF NOT EXISTS public.staff_join_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  hotel_id uuid NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
  staff_title text NOT NULL DEFAULT 'front_desk',
  note text,
  status text NOT NULL DEFAULT 'pending',
  reviewed_at timestamp with time zone,
  reviewed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT staff_join_requests_status_check
    CHECK (status IN ('pending', 'approved', 'rejected'))
);

DROP TRIGGER IF EXISTS update_account_profiles_updated_at ON public.account_profiles;
CREATE TRIGGER update_account_profiles_updated_at
BEFORE UPDATE ON public.account_profiles
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_operator_applications_updated_at ON public.operator_applications;
CREATE TRIGGER update_operator_applications_updated_at
BEFORE UPDATE ON public.operator_applications
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_hotel_onboarding_drafts_updated_at ON public.hotel_onboarding_drafts;
CREATE TRIGGER update_hotel_onboarding_drafts_updated_at
BEFORE UPDATE ON public.hotel_onboarding_drafts
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_staff_invites_updated_at ON public.staff_invites;
CREATE TRIGGER update_staff_invites_updated_at
BEFORE UPDATE ON public.staff_invites
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_staff_join_requests_updated_at ON public.staff_join_requests;
CREATE TRIGGER update_staff_join_requests_updated_at
BEFORE UPDATE ON public.staff_join_requests
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

ALTER TABLE public.account_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.operator_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hotel_onboarding_drafts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_join_requests ENABLE ROW LEVEL SECURITY;

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
      AND lower(urv.role) = lower(p_role)
  );
$$;

CREATE OR REPLACE FUNCTION public.ensure_account_profile(
  p_user_id uuid
)
RETURNS public.account_profiles
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_profile public.account_profiles;
BEGIN
  INSERT INTO public.account_profiles (
    user_id,
    active_persona,
    selected_onboarding_path,
    onboarding_status,
    onboarding_step,
    has_seen_onboarding
  )
  VALUES (
    p_user_id,
    'customer',
    NULL,
    'not_started',
    'welcome',
    false
  )
  ON CONFLICT (user_id) DO NOTHING;

  SELECT *
  INTO v_profile
  FROM public.account_profiles ap
  WHERE ap.user_id = p_user_id;

  RETURN v_profile;
END;
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
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'User ID is required';
  END IF;

  INSERT INTO public.roles(name)
  VALUES (p_role)
  ON CONFLICT (name) DO NOTHING;

  SELECT id
  INTO v_role_id
  FROM public.roles
  WHERE lower(name) = lower(p_role)
  LIMIT 1;

  IF v_role_id IS NULL THEN
    RAISE EXCEPTION 'Role % was not found', p_role;
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

  IF v_active IS NOT NULL AND v_active = ANY(v_roles) THEN
    RETURN v_active;
  END IF;

  IF 'customer' = ANY(v_roles) THEN
    RETURN 'customer';
  END IF;
  IF 'staff' = ANY(v_roles) THEN
    RETURN 'staff';
  END IF;
  IF 'hotel_admin' = ANY(v_roles) THEN
    RETURN 'hotel_admin';
  END IF;
  IF 'system_admin' = ANY(v_roles) THEN
    RETURN 'system_admin';
  END IF;

  RETURN 'guest';
END;
$$;

CREATE OR REPLACE FUNCTION public.get_current_user_access_profile()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
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
STABLE
AS $$
DECLARE
  v_profile jsonb;
BEGIN
  v_profile := public.get_current_user_access_profile();
  RETURN COALESCE(v_profile ->> 'active_persona', 'guest');
END;
$$;

CREATE OR REPLACE FUNCTION public.set_active_persona(
  p_persona text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF NOT public.user_has_role(v_uid, p_persona) THEN
    RAISE EXCEPTION 'Persona % is not available for this account', p_persona;
  END IF;

  PERFORM public.ensure_account_profile(v_uid);

  UPDATE public.account_profiles
  SET active_persona = lower(p_persona)
  WHERE user_id = v_uid;

  RETURN public.get_current_user_access_profile();
END;
$$;

CREATE OR REPLACE FUNCTION public.choose_onboarding_path(
  p_path text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF p_path NOT IN ('customer', 'manage_hotel', 'join_team') THEN
    RAISE EXCEPTION 'Invalid onboarding path: %', p_path;
  END IF;

  PERFORM public.ensure_account_profile(v_uid);

  UPDATE public.account_profiles
  SET selected_onboarding_path = p_path,
      has_seen_onboarding = true,
      onboarding_status = CASE
        WHEN p_path = 'customer' THEN 'completed'
        ELSE 'in_progress'
      END,
      onboarding_step = CASE
        WHEN p_path = 'customer' THEN 'done'
        WHEN p_path = 'manage_hotel' THEN 'manager_profile'
        ELSE 'staff_access'
      END
  WHERE user_id = v_uid;

  RETURN public.get_current_user_access_profile();
END;
$$;

CREATE OR REPLACE FUNCTION public.save_manager_application_draft(
  p_hotel_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_application_id uuid;
  v_payload jsonb := COALESCE(p_hotel_payload, '{}'::jsonb);
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  PERFORM public.ensure_account_profile(v_uid);

  INSERT INTO public.operator_applications (
    user_id,
    status,
    application_payload
  )
  VALUES (
    v_uid,
    'draft',
    v_payload
  )
  ON CONFLICT (user_id) DO UPDATE
  SET status = CASE
        WHEN public.operator_applications.status = 'approved' THEN public.operator_applications.status
        ELSE 'draft'
      END,
      application_payload = EXCLUDED.application_payload
  RETURNING id INTO v_application_id;

  INSERT INTO public.hotel_onboarding_drafts (
    application_id,
    user_id,
    hotel_payload
  )
  VALUES (
    v_application_id,
    v_uid,
    v_payload
  )
  ON CONFLICT (user_id) DO UPDATE
  SET application_id = EXCLUDED.application_id,
      hotel_payload = EXCLUDED.hotel_payload;

  UPDATE public.account_profiles
  SET selected_onboarding_path = 'manage_hotel',
      has_seen_onboarding = true,
      onboarding_status = 'in_progress',
      onboarding_step = 'manager_application'
  WHERE user_id = v_uid;

  RETURN public.get_current_user_access_profile();
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_manager_application(
  p_hotel_payload jsonb DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
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

  IF v_payload IS NULL THEN
    RAISE EXCEPTION 'Property details are required before submitting';
  END IF;

  IF COALESCE(trim(v_payload ->> 'name'), '') = '' OR
     COALESCE(trim(v_payload ->> 'address'), '') = '' OR
     COALESCE(trim(v_payload ->> 'region'), '') = '' OR
     COALESCE(trim(v_payload ->> 'country'), '') = '' OR
     COALESCE(trim(v_payload ->> 'city'), '') = '' OR
     COALESCE(trim(v_payload ->> 'phoneNumber'), '') = '' OR
     COALESCE(trim(v_payload ->> 'email'), '') = '' OR
     (v_payload ->> 'lat') IS NULL OR
     (v_payload ->> 'lng') IS NULL THEN
    RAISE EXCEPTION 'Complete the required property details before submitting';
  END IF;

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

    IF v_payload IS NULL THEN
      RAISE EXCEPTION 'Application draft is missing property details';
    END IF;

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
            COALESCE((v_payload ->> 'lng')::double precision, 0),
            COALESCE((v_payload ->> 'lat')::double precision, 0)
          ),
          4326
        )::geography,
        v_payload ->> 'address',
        v_images,
        0,
        COALESCE((v_payload ->> 'totalRooms')::integer, 0),
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

CREATE OR REPLACE FUNCTION public.create_staff_invite(
  p_hotel_id uuid,
  p_email text,
  p_staff_title text DEFAULT 'front_desk',
  p_expires_at timestamp with time zone DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_requester uuid := auth.uid();
  v_invite public.staff_invites;
BEGIN
  IF v_requester IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF NOT public.is_system_admin(v_requester) AND NOT EXISTS (
    SELECT 1
    FROM public.hotels h
    WHERE h.id = p_hotel_id
      AND h.manager_user_id = v_requester
      AND public.user_has_role(v_requester, 'hotel_admin')
  ) THEN
    RAISE EXCEPTION 'Not permitted to invite staff for this hotel';
  END IF;

  INSERT INTO public.staff_invites (
    hotel_id,
    email,
    staff_title,
    expires_at,
    created_by
  )
  VALUES (
    p_hotel_id,
    lower(trim(p_email)),
    COALESCE(NULLIF(trim(p_staff_title), ''), 'front_desk'),
    p_expires_at,
    v_requester
  )
  RETURNING *
  INTO v_invite;

  RETURN jsonb_build_object(
    'invite_id', v_invite.id,
    'invite_token', v_invite.invite_token,
    'status', v_invite.status
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_staff_join_request(
  p_hotel_id uuid,
  p_note text DEFAULT NULL,
  p_staff_title text DEFAULT 'front_desk'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  PERFORM public.ensure_account_profile(v_uid);

  INSERT INTO public.staff_join_requests (
    user_id,
    hotel_id,
    staff_title,
    note,
    status
  )
  VALUES (
    v_uid,
    p_hotel_id,
    COALESCE(NULLIF(trim(p_staff_title), ''), 'front_desk'),
    NULLIF(trim(COALESCE(p_note, '')), ''),
    'pending'
  )
  ON CONFLICT (user_id) DO UPDATE
  SET hotel_id = EXCLUDED.hotel_id,
      staff_title = EXCLUDED.staff_title,
      note = EXCLUDED.note,
      status = 'pending',
      reviewed_at = NULL,
      reviewed_by = NULL;

  UPDATE public.account_profiles
  SET selected_onboarding_path = 'join_team',
      has_seen_onboarding = true,
      onboarding_status = 'in_progress',
      onboarding_step = 'staff_review'
  WHERE user_id = v_uid;

  RETURN public.get_current_user_access_profile();
END;
$$;

CREATE OR REPLACE FUNCTION public.accept_staff_invite(
  p_token text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_email text;
  v_invite public.staff_invites;
  v_full_name text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT lower(email)
  INTO v_email
  FROM auth.users
  WHERE id = v_uid;

  SELECT *
  INTO v_invite
  FROM public.staff_invites si
  WHERE si.invite_token = p_token::uuid
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invite not found';
  END IF;

  IF v_invite.status <> 'pending' THEN
    RAISE EXCEPTION 'Invite is no longer available';
  END IF;

  IF v_invite.expires_at IS NOT NULL AND v_invite.expires_at < now() THEN
    UPDATE public.staff_invites
    SET status = 'expired'
    WHERE id = v_invite.id;
    RAISE EXCEPTION 'Invite has expired';
  END IF;

  IF lower(trim(v_invite.email)) <> lower(trim(COALESCE(v_email, ''))) THEN
    RAISE EXCEPTION 'This invite was created for a different email address';
  END IF;

  SELECT COALESCE(NULLIF(trim(raw_user_meta_data ->> 'fullName'), ''), trim(
    concat_ws(' ', raw_user_meta_data ->> 'firstName', raw_user_meta_data ->> 'lastName')
  ))
  INTO v_full_name
  FROM auth.users
  WHERE id = v_uid;

  INSERT INTO public.staff (
    hotel_id,
    name,
    email,
    role,
    is_active,
    user_id
  )
  VALUES (
    v_invite.hotel_id,
    COALESCE(NULLIF(v_full_name, ''), 'Staff Member'),
    v_email,
    v_invite.staff_title,
    true,
    v_uid
  )
  ON CONFLICT (user_id) DO UPDATE
  SET hotel_id = EXCLUDED.hotel_id,
      email = EXCLUDED.email,
      role = EXCLUDED.role,
      is_active = true;

  PERFORM public.grant_user_role(v_uid, 'staff');

  UPDATE public.staff_invites
  SET status = 'accepted',
      accepted_by = v_uid
  WHERE id = v_invite.id;

  UPDATE public.account_profiles
  SET selected_onboarding_path = 'join_team',
      onboarding_status = 'completed',
      onboarding_step = 'done'
  WHERE user_id = v_uid;

  RETURN public.get_current_user_access_profile();
END;
$$;

CREATE OR REPLACE FUNCTION public.review_staff_join_request(
  p_request_id uuid,
  p_status text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_requester uuid := auth.uid();
  v_request public.staff_join_requests;
  v_full_name text;
  v_email text;
BEGIN
  IF p_status NOT IN ('approved', 'rejected') THEN
    RAISE EXCEPTION 'Invalid staff join request status: %', p_status;
  END IF;

  SELECT *
  INTO v_request
  FROM public.staff_join_requests sjr
  WHERE sjr.id = p_request_id
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Staff join request not found';
  END IF;

  IF NOT public.is_system_admin(v_requester) AND NOT EXISTS (
    SELECT 1
    FROM public.hotels h
    WHERE h.id = v_request.hotel_id
      AND h.manager_user_id = v_requester
      AND public.user_has_role(v_requester, 'hotel_admin')
  ) THEN
    RAISE EXCEPTION 'Not permitted to review this staff request';
  END IF;

  UPDATE public.staff_join_requests
  SET status = p_status,
      reviewed_at = now(),
      reviewed_by = v_requester
  WHERE id = p_request_id;

  IF p_status = 'approved' THEN
    SELECT
      COALESCE(NULLIF(trim(raw_user_meta_data ->> 'fullName'), ''), trim(
        concat_ws(' ', raw_user_meta_data ->> 'firstName', raw_user_meta_data ->> 'lastName')
      )),
      lower(email)
    INTO v_full_name, v_email
    FROM auth.users
    WHERE id = v_request.user_id;

    INSERT INTO public.staff (
      hotel_id,
      name,
      email,
      role,
      is_active,
      user_id
    )
    VALUES (
      v_request.hotel_id,
      COALESCE(NULLIF(v_full_name, ''), 'Staff Member'),
      v_email,
      v_request.staff_title,
      true,
      v_request.user_id
    )
    ON CONFLICT (user_id) DO UPDATE
    SET hotel_id = EXCLUDED.hotel_id,
        email = EXCLUDED.email,
        role = EXCLUDED.role,
        is_active = true;

    PERFORM public.grant_user_role(v_request.user_id, 'staff');

    UPDATE public.account_profiles
    SET selected_onboarding_path = 'join_team',
        onboarding_status = 'completed',
        onboarding_step = 'done'
    WHERE user_id = v_request.user_id;
  ELSE
    UPDATE public.account_profiles
    SET selected_onboarding_path = 'join_team',
        onboarding_status = 'in_progress',
        onboarding_step = 'staff_access'
    WHERE user_id = v_request.user_id;
  END IF;

  RETURN jsonb_build_object(
    'request_id', p_request_id,
    'status', p_status
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM public.grant_user_role(new.id, 'customer');
  PERFORM public.ensure_account_profile(new.id);
  RETURN new;
END;
$$;

DROP POLICY IF EXISTS account_profiles_select_self_or_admin ON public.account_profiles;
CREATE POLICY account_profiles_select_self_or_admin
ON public.account_profiles
FOR SELECT
USING (user_id = auth.uid() OR public.is_system_admin(auth.uid()));

DROP POLICY IF EXISTS account_profiles_insert_self_or_admin ON public.account_profiles;
CREATE POLICY account_profiles_insert_self_or_admin
ON public.account_profiles
FOR INSERT
WITH CHECK (user_id = auth.uid() OR public.is_system_admin(auth.uid()));

DROP POLICY IF EXISTS account_profiles_update_self_or_admin ON public.account_profiles;
CREATE POLICY account_profiles_update_self_or_admin
ON public.account_profiles
FOR UPDATE
USING (user_id = auth.uid() OR public.is_system_admin(auth.uid()))
WITH CHECK (user_id = auth.uid() OR public.is_system_admin(auth.uid()));

DROP POLICY IF EXISTS operator_applications_select_owner_or_admin ON public.operator_applications;
CREATE POLICY operator_applications_select_owner_or_admin
ON public.operator_applications
FOR SELECT
USING (user_id = auth.uid() OR public.is_system_admin(auth.uid()));

DROP POLICY IF EXISTS operator_applications_insert_owner ON public.operator_applications;
CREATE POLICY operator_applications_insert_owner
ON public.operator_applications
FOR INSERT
WITH CHECK (user_id = auth.uid() OR public.is_system_admin(auth.uid()));

DROP POLICY IF EXISTS operator_applications_update_owner_or_admin ON public.operator_applications;
CREATE POLICY operator_applications_update_owner_or_admin
ON public.operator_applications
FOR UPDATE
USING (user_id = auth.uid() OR public.is_system_admin(auth.uid()))
WITH CHECK (user_id = auth.uid() OR public.is_system_admin(auth.uid()));

DROP POLICY IF EXISTS hotel_onboarding_drafts_select_owner_or_admin ON public.hotel_onboarding_drafts;
CREATE POLICY hotel_onboarding_drafts_select_owner_or_admin
ON public.hotel_onboarding_drafts
FOR SELECT
USING (user_id = auth.uid() OR public.is_system_admin(auth.uid()));

DROP POLICY IF EXISTS hotel_onboarding_drafts_insert_owner ON public.hotel_onboarding_drafts;
CREATE POLICY hotel_onboarding_drafts_insert_owner
ON public.hotel_onboarding_drafts
FOR INSERT
WITH CHECK (user_id = auth.uid() OR public.is_system_admin(auth.uid()));

DROP POLICY IF EXISTS hotel_onboarding_drafts_update_owner_or_admin ON public.hotel_onboarding_drafts;
CREATE POLICY hotel_onboarding_drafts_update_owner_or_admin
ON public.hotel_onboarding_drafts
FOR UPDATE
USING (user_id = auth.uid() OR public.is_system_admin(auth.uid()))
WITH CHECK (user_id = auth.uid() OR public.is_system_admin(auth.uid()));

DROP POLICY IF EXISTS staff_invites_select_manager_or_admin ON public.staff_invites;
CREATE POLICY staff_invites_select_manager_or_admin
ON public.staff_invites
FOR SELECT
USING (
  public.is_system_admin(auth.uid())
  OR EXISTS (
    SELECT 1
    FROM public.hotels h
    WHERE h.id = staff_invites.hotel_id
      AND h.manager_user_id = auth.uid()
      AND public.user_has_role(auth.uid(), 'hotel_admin')
  )
);

DROP POLICY IF EXISTS staff_invites_insert_manager_or_admin ON public.staff_invites;
CREATE POLICY staff_invites_insert_manager_or_admin
ON public.staff_invites
FOR INSERT
WITH CHECK (
  public.is_system_admin(auth.uid())
  OR EXISTS (
    SELECT 1
    FROM public.hotels h
    WHERE h.id = staff_invites.hotel_id
      AND h.manager_user_id = auth.uid()
      AND public.user_has_role(auth.uid(), 'hotel_admin')
  )
);

DROP POLICY IF EXISTS staff_invites_update_manager_or_admin ON public.staff_invites;
CREATE POLICY staff_invites_update_manager_or_admin
ON public.staff_invites
FOR UPDATE
USING (
  public.is_system_admin(auth.uid())
  OR EXISTS (
    SELECT 1
    FROM public.hotels h
    WHERE h.id = staff_invites.hotel_id
      AND h.manager_user_id = auth.uid()
      AND public.user_has_role(auth.uid(), 'hotel_admin')
  )
)
WITH CHECK (
  public.is_system_admin(auth.uid())
  OR EXISTS (
    SELECT 1
    FROM public.hotels h
    WHERE h.id = staff_invites.hotel_id
      AND h.manager_user_id = auth.uid()
      AND public.user_has_role(auth.uid(), 'hotel_admin')
  )
);

DROP POLICY IF EXISTS staff_join_requests_select_owner_manager_or_admin ON public.staff_join_requests;
CREATE POLICY staff_join_requests_select_owner_manager_or_admin
ON public.staff_join_requests
FOR SELECT
USING (
  user_id = auth.uid()
  OR public.is_system_admin(auth.uid())
  OR EXISTS (
    SELECT 1
    FROM public.hotels h
    WHERE h.id = staff_join_requests.hotel_id
      AND h.manager_user_id = auth.uid()
      AND public.user_has_role(auth.uid(), 'hotel_admin')
  )
);

DROP POLICY IF EXISTS staff_join_requests_insert_owner ON public.staff_join_requests;
CREATE POLICY staff_join_requests_insert_owner
ON public.staff_join_requests
FOR INSERT
WITH CHECK (user_id = auth.uid() OR public.is_system_admin(auth.uid()));

DROP POLICY IF EXISTS staff_join_requests_update_owner_manager_or_admin ON public.staff_join_requests;
CREATE POLICY staff_join_requests_update_owner_manager_or_admin
ON public.staff_join_requests
FOR UPDATE
USING (
  user_id = auth.uid()
  OR public.is_system_admin(auth.uid())
  OR EXISTS (
    SELECT 1
    FROM public.hotels h
    WHERE h.id = staff_join_requests.hotel_id
      AND h.manager_user_id = auth.uid()
      AND public.user_has_role(auth.uid(), 'hotel_admin')
  )
)
WITH CHECK (
  user_id = auth.uid()
  OR public.is_system_admin(auth.uid())
  OR EXISTS (
    SELECT 1
    FROM public.hotels h
    WHERE h.id = staff_join_requests.hotel_id
      AND h.manager_user_id = auth.uid()
      AND public.user_has_role(auth.uid(), 'hotel_admin')
  )
);

DROP POLICY IF EXISTS hotels_manage_own ON public.hotels;
CREATE POLICY hotels_manage_own ON public.hotels
FOR ALL
USING (
  public.is_system_admin(auth.uid())
  OR (
    public.user_has_role(auth.uid(), 'hotel_admin')
    AND manager_user_id = auth.uid()
  )
)
WITH CHECK (
  public.is_system_admin(auth.uid())
  OR (
    public.user_has_role(auth.uid(), 'hotel_admin')
    AND manager_user_id = auth.uid()
  )
);

DO $$
DECLARE
  v_user record;
  v_active text;
  v_path text;
BEGIN
  FOR v_user IN
    SELECT u.id
    FROM auth.users u
  LOOP
    PERFORM public.grant_user_role(v_user.id, 'customer');

    IF EXISTS (
      SELECT 1 FROM public.hotels h WHERE h.manager_user_id = v_user.id
    ) THEN
      PERFORM public.grant_user_role(v_user.id, 'hotel_admin');
    END IF;

    IF EXISTS (
      SELECT 1 FROM public.staff s WHERE s.user_id = v_user.id
    ) THEN
      PERFORM public.grant_user_role(v_user.id, 'staff');
    END IF;

    IF public.user_has_role(v_user.id, 'system_admin') THEN
      v_active := 'system_admin';
      v_path := 'manage_hotel';
    ELSIF public.user_has_role(v_user.id, 'hotel_admin') THEN
      v_active := 'hotel_admin';
      v_path := 'manage_hotel';
    ELSIF public.user_has_role(v_user.id, 'staff') THEN
      v_active := 'staff';
      v_path := 'join_team';
    ELSE
      v_active := 'customer';
      v_path := 'customer';
    END IF;

    INSERT INTO public.account_profiles (
      user_id,
      active_persona,
      selected_onboarding_path,
      onboarding_status,
      onboarding_step,
      has_seen_onboarding
    )
    VALUES (
      v_user.id,
      v_active,
      v_path,
      'completed',
      'done',
      true
    )
    ON CONFLICT (user_id) DO UPDATE
    SET active_persona = EXCLUDED.active_persona,
        selected_onboarding_path = EXCLUDED.selected_onboarding_path,
        onboarding_status = EXCLUDED.onboarding_status,
        onboarding_step = EXCLUDED.onboarding_step,
        has_seen_onboarding = EXCLUDED.has_seen_onboarding;
  END LOOP;
END;
$$;

GRANT SELECT, INSERT, UPDATE ON public.account_profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.operator_applications TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.hotel_onboarding_drafts TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.staff_invites TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.staff_join_requests TO authenticated;

REVOKE ALL ON FUNCTION public.user_has_role(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.user_has_role(uuid, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.ensure_account_profile(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.grant_user_role(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.resolve_active_persona(uuid) FROM PUBLIC;

REVOKE ALL ON FUNCTION public.get_current_user_access_profile() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_current_user_access_profile() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.get_current_user_role() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_current_user_role() TO anon, authenticated, service_role;

REVOKE ALL ON FUNCTION public.set_active_persona(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_active_persona(text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.choose_onboarding_path(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.choose_onboarding_path(text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.save_manager_application_draft(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.save_manager_application_draft(jsonb) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.submit_manager_application(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_manager_application(jsonb) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.review_manager_application(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.review_manager_application(uuid, text, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.create_staff_invite(uuid, text, text, timestamp with time zone) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_staff_invite(uuid, text, text, timestamp with time zone) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.submit_staff_join_request(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_staff_join_request(uuid, text, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.accept_staff_invite(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.accept_staff_invite(text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.review_staff_join_request(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.review_staff_join_request(uuid, text) TO authenticated, service_role;
