-- Harden auth/onboarding lifecycle boundaries.
-- Client apps may read their allowed rows through RLS, but state transitions
-- must go through RPCs so status, role, and audit side effects stay consistent.

BEGIN;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_user();

REVOKE INSERT, UPDATE, DELETE ON public.account_profiles
FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.operator_applications
FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.hotel_onboarding_drafts
FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.staff_invites
FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.staff_join_requests
FROM anon, authenticated;

GRANT SELECT ON public.account_profiles TO authenticated;
GRANT SELECT ON public.operator_applications TO authenticated;
GRANT SELECT ON public.hotel_onboarding_drafts TO authenticated;
GRANT SELECT ON public.staff_join_requests TO authenticated;

REVOKE ALL PRIVILEGES ON TABLE public.user_roles_view FROM anon, authenticated;

GRANT EXECUTE ON FUNCTION public.get_current_user_access_profile()
TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_current_user_role()
TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.choose_onboarding_path(text)
TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.save_manager_application_draft(jsonb)
TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.submit_manager_application(jsonb)
TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.create_staff_invite(uuid, text, text, timestamp with time zone)
TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.submit_staff_join_request(uuid, text, text)
TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.accept_staff_invite(text)
TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.review_staff_join_request(uuid, text)
TO authenticated, service_role;

COMMIT;
