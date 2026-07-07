BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

INSERT INTO storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
VALUES (
  'hotel-images',
  'hotel-images',
  true,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE
SET public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS hotel_images_public_read ON storage.objects;
CREATE POLICY hotel_images_public_read
ON storage.objects
FOR SELECT
USING (bucket_id = 'hotel-images');

DROP POLICY IF EXISTS hotel_images_manager_insert_own_folder ON storage.objects;
CREATE POLICY hotel_images_manager_insert_own_folder
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'hotel-images'
  AND (storage.foldername(name))[1] = auth.uid()::text
  AND (
    public.user_has_role(auth.uid(), 'hotel_admin')
    OR public.is_system_admin(auth.uid())
  )
);

DROP POLICY IF EXISTS hotel_images_manager_update_own_folder ON storage.objects;
CREATE POLICY hotel_images_manager_update_own_folder
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'hotel-images'
  AND (storage.foldername(name))[1] = auth.uid()::text
  AND (
    public.user_has_role(auth.uid(), 'hotel_admin')
    OR public.is_system_admin(auth.uid())
  )
)
WITH CHECK (
  bucket_id = 'hotel-images'
  AND (storage.foldername(name))[1] = auth.uid()::text
  AND (
    public.user_has_role(auth.uid(), 'hotel_admin')
    OR public.is_system_admin(auth.uid())
  )
);

DROP POLICY IF EXISTS hotel_images_manager_delete_own_folder ON storage.objects;
CREATE POLICY hotel_images_manager_delete_own_folder
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'hotel-images'
  AND (storage.foldername(name))[1] = auth.uid()::text
  AND (
    public.user_has_role(auth.uid(), 'hotel_admin')
    OR public.is_system_admin(auth.uid())
  )
);

ALTER TABLE public.staff_invites
  ADD COLUMN IF NOT EXISTS invite_token_hash text;

UPDATE public.staff_invites
SET invite_token_hash = encode(extensions.digest(invite_token::text, 'sha256'), 'hex')
WHERE status = 'pending'
  AND invite_token_hash IS NULL;

UPDATE public.staff_invites
SET invite_token = gen_random_uuid()
WHERE status = 'pending';

UPDATE public.staff_invites
SET invite_token_hash = NULL,
    invite_token = gen_random_uuid()
WHERE status <> 'pending';

CREATE UNIQUE INDEX IF NOT EXISTS idx_staff_invites_token_hash
  ON public.staff_invites(invite_token_hash)
  WHERE invite_token_hash IS NOT NULL;

CREATE OR REPLACE FUNCTION public.create_staff_invite(
  p_hotel_id uuid,
  p_email text,
  p_staff_title text DEFAULT 'front_desk',
  p_expires_at timestamp with time zone DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_requester uuid := auth.uid();
  v_invite public.staff_invites;
  v_invite_token uuid := gen_random_uuid();
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
    created_by,
    invite_token_hash
  )
  VALUES (
    p_hotel_id,
    lower(trim(p_email)),
    COALESCE(NULLIF(trim(p_staff_title), ''), 'front_desk'),
    p_expires_at,
    v_requester,
    encode(extensions.digest(v_invite_token::text, 'sha256'), 'hex')
  )
  RETURNING *
  INTO v_invite;

  RETURN jsonb_build_object(
    'invite_id', v_invite.id,
    'invite_token', v_invite_token,
    'status', v_invite.status
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.accept_staff_invite(
  p_token text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_email text;
  v_invite public.staff_invites;
  v_full_name text;
  v_token uuid;
  v_token_hash text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  BEGIN
    v_token := p_token::uuid;
  EXCEPTION
    WHEN invalid_text_representation THEN
      RAISE EXCEPTION 'Invalid invite token';
  END;

  v_token_hash := encode(extensions.digest(v_token::text, 'sha256'), 'hex');

  SELECT lower(email)
  INTO v_email
  FROM auth.users
  WHERE id = v_uid;

  SELECT *
  INTO v_invite
  FROM public.staff_invites si
  WHERE si.invite_token_hash = v_token_hash
     OR (si.invite_token_hash IS NULL AND si.invite_token = v_token)
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invite not found';
  END IF;

  IF v_invite.status <> 'pending' THEN
    RAISE EXCEPTION 'Invite is no longer available';
  END IF;

  IF v_invite.expires_at IS NOT NULL AND v_invite.expires_at < now() THEN
    UPDATE public.staff_invites
    SET status = 'expired',
        invite_token_hash = NULL,
        invite_token = gen_random_uuid()
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
      accepted_by = v_uid,
      invite_token_hash = NULL,
      invite_token = gen_random_uuid()
  WHERE id = v_invite.id;

  UPDATE public.account_profiles
  SET selected_onboarding_path = 'join_team',
      onboarding_status = 'completed',
      onboarding_step = 'done'
  WHERE user_id = v_uid;

  RETURN public.get_current_user_access_profile();
END;
$$;

REVOKE SELECT ON public.staff_invites FROM anon, authenticated;
GRANT SELECT (
  id,
  hotel_id,
  email,
  staff_title,
  status,
  expires_at,
  created_by,
  accepted_by,
  created_at,
  updated_at
) ON public.staff_invites TO authenticated;

REVOKE ALL ON FUNCTION public.create_staff_invite(uuid, text, text, timestamp with time zone) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_staff_invite(uuid, text, text, timestamp with time zone) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.accept_staff_invite(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.accept_staff_invite(text) TO authenticated, service_role;

COMMIT;
