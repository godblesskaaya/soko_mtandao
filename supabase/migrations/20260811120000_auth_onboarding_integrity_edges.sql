-- Tighten server-side onboarding values that were previously plain text.
-- NOT VALID preserves deployability if legacy rows contain older step names,
-- while still blocking new writes that drift from the app contract.

ALTER TABLE public.account_profiles
  DROP CONSTRAINT IF EXISTS account_profiles_onboarding_step_check;

ALTER TABLE public.account_profiles
  ADD CONSTRAINT account_profiles_onboarding_step_check
  CHECK (
    onboarding_step IN (
      'welcome',
      'manager_profile',
      'manager_application',
      'manager_review',
      'staff_access',
      'staff_review',
      'association',
      'kyc',
      'review',
      'done'
    )
  ) NOT VALID;

ALTER TABLE public.staff
  DROP CONSTRAINT IF EXISTS staff_role_check;

ALTER TABLE public.staff
  ADD CONSTRAINT staff_role_check
  CHECK (
    role IS NULL OR role IN (
      'front_desk',
      'housekeeping',
      'accounting',
      'maintenance',
      'manager'
    )
  ) NOT VALID;

ALTER TABLE public.staff_invites
  DROP CONSTRAINT IF EXISTS staff_invites_staff_title_check;

ALTER TABLE public.staff_invites
  ADD CONSTRAINT staff_invites_staff_title_check
  CHECK (
    staff_title IN (
      'front_desk',
      'housekeeping',
      'accounting',
      'maintenance',
      'manager'
    )
  ) NOT VALID;

ALTER TABLE public.staff_join_requests
  DROP CONSTRAINT IF EXISTS staff_join_requests_staff_title_check;

ALTER TABLE public.staff_join_requests
  ADD CONSTRAINT staff_join_requests_staff_title_check
  CHECK (
    staff_title IN (
      'front_desk',
      'housekeeping',
      'accounting',
      'maintenance',
      'manager'
    )
  ) NOT VALID;
