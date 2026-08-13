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
  'kyc-documents',
  'kyc-documents',
  false,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
ON CONFLICT (id) DO UPDATE
SET public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS kyc_documents_storage_select_own_or_admin
ON storage.objects;
CREATE POLICY kyc_documents_storage_select_own_or_admin
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'kyc-documents'
  AND (
    (storage.foldername(name))[1] = auth.uid()::text
    OR public.is_system_admin(auth.uid())
  )
);

DROP POLICY IF EXISTS kyc_documents_storage_insert_own_folder
ON storage.objects;
CREATE POLICY kyc_documents_storage_insert_own_folder
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'kyc-documents'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS kyc_documents_storage_delete_own_or_admin
ON storage.objects;
CREATE POLICY kyc_documents_storage_delete_own_or_admin
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'kyc-documents'
  AND (
    (storage.foldername(name))[1] = auth.uid()::text
    OR public.is_system_admin(auth.uid())
  )
);

DO $$
DECLARE
  v_admin_email text := 'admin@soko-mtandao.com';
  v_admin_id uuid;
  v_role_id uuid;
BEGIN
  INSERT INTO public.roles(name)
  VALUES ('system_admin')
  ON CONFLICT (name) DO NOTHING;

  SELECT id
  INTO v_role_id
  FROM public.roles
  WHERE name = 'system_admin';

  SELECT id
  INTO v_admin_id
  FROM auth.users
  WHERE lower(email) = v_admin_email
  LIMIT 1;

  IF v_admin_id IS NULL THEN
    v_admin_id := gen_random_uuid();

    INSERT INTO auth.users (
      id,
      aud,
      role,
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      is_super_admin,
      created_at,
      updated_at,
      is_sso_user,
      is_anonymous
    )
    VALUES (
      v_admin_id,
      'authenticated',
      'authenticated',
      v_admin_email,
      extensions.crypt(gen_random_uuid()::text, extensions.gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"fullName":"Soko Mtandao Admin","role":"system_admin"}'::jsonb,
      false,
      now(),
      now(),
      false,
      false
    );

  ELSE
    UPDATE auth.users
    SET email_confirmed_at = COALESCE(email_confirmed_at, now()),
        raw_app_meta_data = COALESCE(raw_app_meta_data, '{}'::jsonb)
          || '{"provider":"email","providers":["email"]}'::jsonb,
        updated_at = now()
    WHERE id = v_admin_id;
  END IF;

  INSERT INTO auth.identities (
    provider_id,
    user_id,
    identity_data,
    provider,
    last_sign_in_at,
    created_at,
    updated_at
  )
  VALUES (
    v_admin_id::text,
    v_admin_id,
    jsonb_build_object(
      'sub',
      v_admin_id::text,
      'email',
      v_admin_email,
      'email_verified',
      true
    ),
    'email',
    now(),
    now(),
    now()
  )
  ON CONFLICT (provider_id, provider) DO NOTHING;

  INSERT INTO public.user_roles(user_id, role_id)
  VALUES (v_admin_id, v_role_id)
  ON CONFLICT (user_id, role_id) DO NOTHING;

  INSERT INTO public.account_profiles (
    user_id,
    active_persona,
    selected_onboarding_path,
    onboarding_status,
    onboarding_step,
    has_seen_onboarding
  )
  VALUES (
    v_admin_id,
    'system_admin',
    'customer',
    'completed',
    'done',
    true
  )
  ON CONFLICT (user_id) DO UPDATE
  SET active_persona = 'system_admin',
      has_seen_onboarding = true,
      onboarding_status = 'completed',
      onboarding_step = 'done',
      updated_at = now();
END $$;

COMMIT;
