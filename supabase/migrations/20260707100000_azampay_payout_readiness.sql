-- AzamPay payout readiness: destination account validation and expanded KYC.

BEGIN;

ALTER TABLE public.kyc_profiles
  ADD COLUMN IF NOT EXISTS business_registration_number text,
  ADD COLUMN IF NOT EXISTS tax_identification_number text,
  ADD COLUMN IF NOT EXISTS business_type text,
  ADD COLUMN IF NOT EXISTS beneficial_owner_name text,
  ADD COLUMN IF NOT EXISTS beneficial_owner_national_id text,
  ADD COLUMN IF NOT EXISTS compliance_contact_phone text,
  ADD COLUMN IF NOT EXISTS compliance_contact_email text,
  ADD COLUMN IF NOT EXISTS payout_terms_accepted_at timestamptz,
  ADD COLUMN IF NOT EXISTS payout_terms_version text;

ALTER TABLE public.hotel_payout_accounts
  ADD COLUMN IF NOT EXISTS country_code text NOT NULL DEFAULT 'TZ',
  ADD COLUMN IF NOT EXISTS verification_status text NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS verified_at timestamptz,
  ADD COLUMN IF NOT EXISTS verified_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS verification_notes text,
  ADD COLUMN IF NOT EXISTS provider_reference text;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'hotel_payout_accounts_country_code_check'
  ) THEN
    ALTER TABLE public.hotel_payout_accounts
      ADD CONSTRAINT hotel_payout_accounts_country_code_check
      CHECK (country_code ~ '^[A-Z]{2}$') NOT VALID;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'hotel_payout_accounts_verification_status_check'
  ) THEN
    ALTER TABLE public.hotel_payout_accounts
      ADD CONSTRAINT hotel_payout_accounts_verification_status_check
      CHECK (verification_status IN ('pending', 'approved', 'rejected', 'suspended')) NOT VALID;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'hotel_payout_accounts_destination_required_check'
  ) THEN
    ALTER TABLE public.hotel_payout_accounts
      ADD CONSTRAINT hotel_payout_accounts_destination_required_check
      CHECK (
        is_active IS NOT TRUE
        OR (
          nullif(trim(account_name), '') IS NOT NULL
          AND nullif(trim(provider_name), '') IS NOT NULL
          AND (
            (provider_type = 'bank' AND nullif(trim(account_number), '') IS NOT NULL)
            OR (provider_type = 'mobile_money' AND nullif(trim(mobile_number), '') IS NOT NULL)
          )
        )
      ) NOT VALID;
  END IF;
END $$;

DROP FUNCTION IF EXISTS public.submit_kyc_profile(text, text, date, text, boolean, text);
CREATE OR REPLACE FUNCTION public.submit_kyc_profile(
  p_legal_name text,
  p_national_id text,
  p_date_of_birth date,
  p_physical_address text,
  p_phone_verified boolean DEFAULT false,
  p_document_url text DEFAULT NULL,
  p_business_registration_number text DEFAULT NULL,
  p_tax_identification_number text DEFAULT NULL,
  p_business_type text DEFAULT NULL,
  p_beneficial_owner_name text DEFAULT NULL,
  p_beneficial_owner_national_id text DEFAULT NULL,
  p_compliance_contact_phone text DEFAULT NULL,
  p_compliance_contact_email text DEFAULT NULL,
  p_payout_terms_accepted boolean DEFAULT false,
  p_payout_terms_version text DEFAULT 'azampay-payouts-v1'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_profile_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF nullif(trim(p_legal_name), '') IS NULL
    OR nullif(trim(p_national_id), '') IS NULL
    OR p_date_of_birth IS NULL
    OR nullif(trim(p_physical_address), '') IS NULL
    OR nullif(trim(p_business_type), '') IS NULL
    OR nullif(trim(p_beneficial_owner_name), '') IS NULL
    OR nullif(trim(p_beneficial_owner_national_id), '') IS NULL
    OR nullif(trim(p_compliance_contact_phone), '') IS NULL
    OR nullif(trim(p_compliance_contact_email), '') IS NULL THEN
    RAISE EXCEPTION 'KYC submission is incomplete';
  END IF;

  IF COALESCE(p_payout_terms_accepted, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'Payout compliance terms must be accepted';
  END IF;

  INSERT INTO public.kyc_profiles(
    user_id,
    legal_name,
    national_id,
    date_of_birth,
    physical_address,
    phone_verified,
    business_registration_number,
    tax_identification_number,
    business_type,
    beneficial_owner_name,
    beneficial_owner_national_id,
    compliance_contact_phone,
    compliance_contact_email,
    payout_terms_accepted_at,
    payout_terms_version,
    status,
    submitted_at,
    reviewed_by,
    review_notes,
    updated_at
  )
  VALUES (
    v_user_id,
    nullif(trim(p_legal_name), ''),
    nullif(trim(p_national_id), ''),
    p_date_of_birth,
    nullif(trim(p_physical_address), ''),
    COALESCE(p_phone_verified, false),
    nullif(trim(p_business_registration_number), ''),
    nullif(trim(p_tax_identification_number), ''),
    nullif(trim(p_business_type), ''),
    nullif(trim(p_beneficial_owner_name), ''),
    nullif(trim(p_beneficial_owner_national_id), ''),
    nullif(trim(p_compliance_contact_phone), ''),
    lower(nullif(trim(p_compliance_contact_email), '')),
    now(),
    nullif(trim(p_payout_terms_version), ''),
    'submitted',
    now(),
    NULL,
    NULL,
    now()
  )
  ON CONFLICT (user_id)
  DO UPDATE SET
    legal_name = EXCLUDED.legal_name,
    national_id = EXCLUDED.national_id,
    date_of_birth = EXCLUDED.date_of_birth,
    physical_address = EXCLUDED.physical_address,
    phone_verified = EXCLUDED.phone_verified,
    business_registration_number = EXCLUDED.business_registration_number,
    tax_identification_number = EXCLUDED.tax_identification_number,
    business_type = EXCLUDED.business_type,
    beneficial_owner_name = EXCLUDED.beneficial_owner_name,
    beneficial_owner_national_id = EXCLUDED.beneficial_owner_national_id,
    compliance_contact_phone = EXCLUDED.compliance_contact_phone,
    compliance_contact_email = EXCLUDED.compliance_contact_email,
    payout_terms_accepted_at = EXCLUDED.payout_terms_accepted_at,
    payout_terms_version = EXCLUDED.payout_terms_version,
    status = 'submitted',
    submitted_at = now(),
    reviewed_by = NULL,
    review_notes = NULL,
    updated_at = now()
  RETURNING id INTO v_profile_id;

  IF p_document_url IS NOT NULL AND trim(p_document_url) <> '' THEN
    INSERT INTO public.kyc_documents(kyc_profile_id, document_type, document_url, is_encrypted)
    VALUES (v_profile_id, 'identity', trim(p_document_url), true);
  END IF;

  PERFORM public.log_audit_event(
    p_event_type => 'kyc_update',
    p_entity_type => 'kyc_profile',
    p_entity_id => v_profile_id::text,
    p_payload => jsonb_build_object('status', 'submitted', 'payout_terms_version', p_payout_terms_version),
    p_actor_user_id => v_user_id
  );

  RETURN v_profile_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.upsert_hotel_payout_account(
  p_hotel_id uuid,
  p_provider_type text,
  p_provider_name text,
  p_account_name text,
  p_account_number text DEFAULT NULL,
  p_mobile_number text DEFAULT NULL,
  p_currency text DEFAULT 'TZS',
  p_country_code text DEFAULT 'TZ',
  p_provider_reference text DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_requester uuid := auth.uid();
  v_manager_user_id uuid;
  v_account_id uuid;
  v_provider_type text := lower(trim(p_provider_type));
  v_currency text := upper(trim(COALESCE(p_currency, 'TZS')));
  v_country_code text := upper(trim(COALESCE(p_country_code, 'TZ')));
BEGIN
  IF v_requester IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT manager_user_id
  INTO v_manager_user_id
  FROM public.hotels
  WHERE id = p_hotel_id;

  IF v_manager_user_id IS NULL THEN
    RAISE EXCEPTION 'Hotel not found';
  END IF;

  IF NOT public.is_system_admin(v_requester) AND v_manager_user_id <> v_requester THEN
    RAISE EXCEPTION 'Not permitted to configure payout account for this hotel';
  END IF;

  IF v_provider_type IS NULL OR v_provider_type NOT IN ('bank', 'mobile_money') THEN
    RAISE EXCEPTION 'Provider type must be bank or mobile_money';
  END IF;

  IF nullif(trim(p_provider_name), '') IS NULL OR nullif(trim(p_account_name), '') IS NULL THEN
    RAISE EXCEPTION 'Provider name and account holder name are required';
  END IF;

  IF v_provider_type = 'bank' AND nullif(trim(COALESCE(p_account_number, '')), '') IS NULL THEN
    RAISE EXCEPTION 'Bank account number is required';
  END IF;

  IF v_provider_type = 'mobile_money' AND nullif(trim(COALESCE(p_mobile_number, '')), '') IS NULL THEN
    RAISE EXCEPTION 'Mobile wallet number is required';
  END IF;

  IF v_currency !~ '^[A-Z]{3}$' THEN
    RAISE EXCEPTION 'Currency must be a 3-letter ISO code';
  END IF;

  IF v_country_code !~ '^[A-Z]{2}$' THEN
    RAISE EXCEPTION 'Country code must be a 2-letter ISO code';
  END IF;

  INSERT INTO public.hotel_payout_accounts (
    hotel_id,
    provider_type,
    provider_name,
    account_name,
    account_number,
    mobile_number,
    currency,
    country_code,
    provider_reference,
    is_active,
    verification_status,
    verified_at,
    verified_by,
    verification_notes,
    metadata,
    updated_at
  )
  VALUES (
    p_hotel_id,
    v_provider_type,
    trim(p_provider_name),
    trim(p_account_name),
    nullif(trim(COALESCE(p_account_number, '')), ''),
    nullif(trim(COALESCE(p_mobile_number, '')), ''),
    v_currency,
    v_country_code,
    nullif(trim(COALESCE(p_provider_reference, '')), ''),
    true,
    'pending',
    NULL,
    NULL,
    NULL,
    COALESCE(p_metadata, '{}'::jsonb),
    now()
  )
  ON CONFLICT (hotel_id)
  DO UPDATE SET
    provider_type = EXCLUDED.provider_type,
    provider_name = EXCLUDED.provider_name,
    account_name = EXCLUDED.account_name,
    account_number = EXCLUDED.account_number,
    mobile_number = EXCLUDED.mobile_number,
    currency = EXCLUDED.currency,
    country_code = EXCLUDED.country_code,
    provider_reference = EXCLUDED.provider_reference,
    is_active = true,
    verification_status = 'pending',
    verified_at = NULL,
    verified_by = NULL,
    verification_notes = NULL,
    metadata = EXCLUDED.metadata,
    updated_at = now()
  RETURNING id INTO v_account_id;

  PERFORM public.log_audit_event(
    p_event_type => 'payout_account_update',
    p_entity_type => 'hotel_payout_account',
    p_entity_id => v_account_id::text,
    p_payload => jsonb_build_object('hotel_id', p_hotel_id, 'provider_type', v_provider_type),
    p_actor_user_id => v_requester
  );

  RETURN v_account_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.review_hotel_payout_account(
  p_account_id uuid,
  p_status text,
  p_notes text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_requester uuid := auth.uid();
  v_status text := lower(trim(p_status));
BEGIN
  IF v_requester IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF NOT public.is_system_admin(v_requester) THEN
    RAISE EXCEPTION 'Only system admins can review payout accounts';
  END IF;

  IF v_status NOT IN ('approved', 'rejected', 'suspended') THEN
    RAISE EXCEPTION 'Invalid payout account review status';
  END IF;

  UPDATE public.hotel_payout_accounts
  SET verification_status = v_status,
      verified_at = CASE WHEN v_status = 'approved' THEN now() ELSE NULL END,
      verified_by = v_requester,
      verification_notes = nullif(trim(COALESCE(p_notes, '')), ''),
      updated_at = now()
  WHERE id = p_account_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Payout account not found';
  END IF;

  PERFORM public.log_audit_event(
    p_event_type => 'payout_account_review',
    p_entity_type => 'hotel_payout_account',
    p_entity_id => p_account_id::text,
    p_payload => jsonb_build_object('status', v_status),
    p_actor_user_id => v_requester
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_hotel_payout_readiness(p_hotel_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_requester uuid := auth.uid();
  v_manager_user_id uuid;
  v_kyc public.kyc_profiles%ROWTYPE;
  v_account public.hotel_payout_accounts%ROWTYPE;
  v_missing text[] := ARRAY[]::text[];
  v_ready boolean;
BEGIN
  IF v_requester IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT manager_user_id
  INTO v_manager_user_id
  FROM public.hotels
  WHERE id = p_hotel_id;

  IF v_manager_user_id IS NULL THEN
    RAISE EXCEPTION 'Hotel not found';
  END IF;

  IF NOT public.is_system_admin(v_requester) AND v_manager_user_id <> v_requester THEN
    RAISE EXCEPTION 'Not permitted to view payout readiness for this hotel';
  END IF;

  SELECT *
  INTO v_kyc
  FROM public.kyc_profiles
  WHERE user_id = v_manager_user_id
  LIMIT 1;

  IF v_kyc.id IS NULL THEN
    v_missing := array_append(v_missing, 'Submit manager KYC');
  ELSE
    IF COALESCE(v_kyc.status, 'pending') <> 'approved' THEN
      v_missing := array_append(v_missing, 'Manager KYC must be approved');
    END IF;
    IF nullif(trim(COALESCE(v_kyc.legal_name, '')), '') IS NULL THEN
      v_missing := array_append(v_missing, 'Legal name');
    END IF;
    IF nullif(trim(COALESCE(v_kyc.national_id, '')), '') IS NULL THEN
      v_missing := array_append(v_missing, 'National ID');
    END IF;
    IF v_kyc.date_of_birth IS NULL THEN
      v_missing := array_append(v_missing, 'Date of birth');
    END IF;
    IF COALESCE(v_kyc.phone_verified, false) IS NOT TRUE THEN
      v_missing := array_append(v_missing, 'Verified phone number');
    END IF;
    IF nullif(trim(COALESCE(v_kyc.physical_address, '')), '') IS NULL THEN
      v_missing := array_append(v_missing, 'Physical address');
    END IF;
    IF nullif(trim(COALESCE(v_kyc.business_type, '')), '') IS NULL THEN
      v_missing := array_append(v_missing, 'Business type');
    END IF;
    IF nullif(trim(COALESCE(v_kyc.beneficial_owner_name, '')), '') IS NULL THEN
      v_missing := array_append(v_missing, 'Beneficial owner name');
    END IF;
    IF nullif(trim(COALESCE(v_kyc.beneficial_owner_national_id, '')), '') IS NULL THEN
      v_missing := array_append(v_missing, 'Beneficial owner national ID');
    END IF;
    IF nullif(trim(COALESCE(v_kyc.compliance_contact_phone, '')), '') IS NULL THEN
      v_missing := array_append(v_missing, 'Compliance contact phone');
    END IF;
    IF nullif(trim(COALESCE(v_kyc.compliance_contact_email, '')), '') IS NULL THEN
      v_missing := array_append(v_missing, 'Compliance contact email');
    END IF;
    IF v_kyc.payout_terms_accepted_at IS NULL THEN
      v_missing := array_append(v_missing, 'Payout compliance terms');
    END IF;
  END IF;

  SELECT *
  INTO v_account
  FROM public.hotel_payout_accounts
  WHERE hotel_id = p_hotel_id
    AND is_active = true
  LIMIT 1;

  IF v_account.id IS NULL THEN
    v_missing := array_append(v_missing, 'Configure payout account');
  ELSE
    IF COALESCE(v_account.verification_status, 'pending') <> 'approved' THEN
      v_missing := array_append(v_missing, 'Payout account must be approved');
    END IF;
    IF nullif(trim(COALESCE(v_account.account_name, '')), '') IS NULL THEN
      v_missing := array_append(v_missing, 'Payout account holder name');
    END IF;
    IF nullif(trim(COALESCE(v_account.provider_name, '')), '') IS NULL THEN
      v_missing := array_append(v_missing, 'Payout provider name');
    END IF;
    IF COALESCE(v_account.provider_type, '') = 'bank'
      AND nullif(trim(COALESCE(v_account.account_number, '')), '') IS NULL THEN
      v_missing := array_append(v_missing, 'Bank account number');
    END IF;
    IF COALESCE(v_account.provider_type, '') = 'mobile_money'
      AND nullif(trim(COALESCE(v_account.mobile_number, '')), '') IS NULL THEN
      v_missing := array_append(v_missing, 'Mobile wallet number');
    END IF;
    IF COALESCE(v_account.country_code, '') !~ '^[A-Z]{2}$' THEN
      v_missing := array_append(v_missing, 'Payout country code');
    END IF;
    IF COALESCE(v_account.currency, '') !~ '^[A-Z]{3}$' THEN
      v_missing := array_append(v_missing, 'Payout currency');
    END IF;
  END IF;

  v_ready := cardinality(v_missing) = 0;

  RETURN jsonb_build_object(
    'ready', v_ready,
    'kyc_status', COALESCE(v_kyc.status, 'missing'),
    'payout_account_status', COALESCE(v_account.verification_status, 'missing'),
    'missing', to_jsonb(v_missing),
    'account', CASE
      WHEN v_account.id IS NULL THEN NULL
      ELSE jsonb_build_object(
        'id', v_account.id,
        'provider_type', v_account.provider_type,
        'provider_name', v_account.provider_name,
        'account_name', v_account.account_name,
        'currency', v_account.currency,
        'country_code', v_account.country_code,
        'verification_status', v_account.verification_status,
        'updated_at', v_account.updated_at
      )
    END
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.request_hotel_payout(
  p_hotel_id uuid,
  p_provider text DEFAULT 'azampay_disburse',
  p_minimum_threshold numeric DEFAULT 0,
  p_idempotency_key text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_requester uuid := auth.uid();
  v_manager_user_id uuid;
  v_readiness jsonb;
  v_batch_id uuid;
BEGIN
  IF v_requester IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF public.is_account_frozen(v_requester) THEN
    RAISE EXCEPTION 'Account is frozen and cannot request payouts';
  END IF;

  SELECT h.manager_user_id
  INTO v_manager_user_id
  FROM public.hotels h
  WHERE h.id = p_hotel_id;

  IF v_manager_user_id IS NULL THEN
    RAISE EXCEPTION 'Hotel not found';
  END IF;

  IF NOT public.is_system_admin(v_requester) AND v_manager_user_id <> v_requester THEN
    RAISE EXCEPTION 'Not permitted to request payout for this hotel';
  END IF;

  v_readiness := public.get_hotel_payout_readiness(p_hotel_id);
  IF COALESCE((v_readiness->>'ready')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'Payout blocked: %', array_to_string(
      ARRAY(SELECT jsonb_array_elements_text(v_readiness->'missing')),
      ', '
    );
  END IF;

  v_batch_id := public.create_payout_batch(
    p_hotel_id => p_hotel_id,
    p_provider => p_provider,
    p_minimum_threshold => p_minimum_threshold,
    p_idempotency_key => p_idempotency_key,
    p_schedule_type => 'manual',
    p_requested_by => v_requester
  );

  PERFORM public.log_audit_event(
    p_event_type => 'payout_dispatch_requested',
    p_entity_type => 'payout_batch',
    p_entity_id => COALESCE(v_batch_id::text, ''),
    p_payload => jsonb_build_object('hotel_id', p_hotel_id, 'provider', p_provider, 'minimum_threshold', p_minimum_threshold),
    p_actor_user_id => v_requester
  );

  RETURN v_batch_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_kyc_profile(text, text, date, text, boolean, text, text, text, text, text, text, text, text, boolean, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.upsert_hotel_payout_account(uuid, text, text, text, text, text, text, text, text, jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.review_hotel_payout_account(uuid, text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_hotel_payout_readiness(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.request_hotel_payout(uuid, text, numeric, text) TO authenticated, service_role;

COMMIT;
