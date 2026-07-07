-- Align AzamPay payout readiness with the raw Tanzania OpenAPI disbursement schema.
-- The schema's disbursement source/destination bankName field is enum-limited
-- to mobile money rails: tigo, airtel, azampesa.

BEGIN;

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
  v_provider_name text;
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
    v_provider_name := lower(trim(COALESCE(v_account.provider_name, '')));

    IF COALESCE(v_account.verification_status, 'pending') <> 'approved' THEN
      v_missing := array_append(v_missing, 'Payout account must be approved');
    END IF;
    IF COALESCE(v_account.provider_type, '') <> 'mobile_money' THEN
      v_missing := array_append(v_missing, 'AzamPay payouts require a mobile money account');
    END IF;
    IF v_provider_name NOT IN ('tigo', 'airtel', 'azampesa') THEN
      v_missing := array_append(v_missing, 'Payout provider must be Tigo, Airtel, or Azampesa');
    END IF;
    IF nullif(trim(COALESCE(v_account.account_name, '')), '') IS NULL THEN
      v_missing := array_append(v_missing, 'Payout account holder name');
    END IF;
    IF nullif(trim(COALESCE(v_account.mobile_number, '')), '') IS NULL THEN
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

COMMIT;
