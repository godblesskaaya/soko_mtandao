# Technical Debt Review and Remediation Plan

Date: 2026-07-06

## Scope and Verification

Reviewed the Flutter app, Supabase edge functions, migrations, configuration, and tests. The remote Supabase project is linked and migration history matches local migrations.

Commands run:

- `npx supabase migration list --profile soko_mtandao`
- `npx supabase db lint --linked --profile soko_mtandao --schema public --level warning --fail-on none`
- Static scans across `lib/`, `supabase/functions/`, and `supabase/migrations/`

Could not run `flutter analyze` or `flutter test` because `flutter` is not installed on PATH in this environment.

## Progress Applied on 2026-07-06

Completed in this remediation pass:

- Removed stale generated source dumps/scripts from `lib/` and expanded `.gitignore` for local token/dump files.
- Added router gating for auth initialization and access-profile resolution, with redirect regression tests.
- Centralized signup, forgot-password, and reset-password UI paths through auth providers/services.
- Added configurable `PASSWORD_RESET_REDIRECT_URL` examples.
- Hardened Supabase auth config defaults for password length, password requirements, email confirmation, secure password change, and email rate limiting.
- Added AzamPay callback authentication support using documented callback credentials/signature where available.
- Required native checkout amount to equal booking total and quarantined callback amount mismatches into reconciliation.
- Added migrations for financial least-privilege grants and broken financial/database function drift.
- Finished common `ManagerRemoteDataSource` methods that previously threw at runtime and fixed manager model database key serialization.
- Added a media/staff-invite readiness migration for the `hotel-images` bucket, scoped storage policies, hashed staff invite tokens, and one-time copy-on-create invite handling in the manager UI.

Verification status:

- `git diff --check` passed.
- Secret-shaped JWT scan returned no tracked matches.
- Remote Supabase lint still reports the old deployed errors because the corrective migrations are local and were not pushed.
- Remote schema dump and migration-list attempts failed with PostgreSQL password authentication for `cli_login_postgres`.
- Local Supabase lint could not run because the local database container is not running.
- Flutter/Dart/Deno/psql are not installed on PATH, so app tests, analysis, formatting, and edge-function type checks were not executable here.

## Executive Summary

The highest-risk debt is in authentication/authorization boundaries and payment state transitions. This pass added local router gating, AzamPay callback authentication checks, amount-mismatch handling, least-privilege migrations, and targeted tests. Production risk remains until the new migrations/functions are deployed and verified against the remote database; the currently deployed public schema still fails Supabase lint.

## Critical Issues

### 1. Payment and payout callbacks are not visibly authenticated

Evidence:

- `supabase/functions/payment_callback/index.ts` parses arbitrary JSON and updates payments/bookings using the service role.
- `supabase/functions/payout_callback/index.ts` parses arbitrary JSON and completes or fails payout batches.
- No HMAC, shared-secret header, mTLS, allowlist, or provider signature check is visible before state mutation.
- `payment_callback` can recover a payment from `bookingIdFromPayload` and later mark related booking state.

Risk: A forged request could mark bookings paid or payouts completed/failed if callback URLs are exposed.

Remediation:

1. Require provider signature verification or a secret callback token before parsing business state.
2. Reject callbacks missing verified provider references; do not create recovery payments from unverified booking IDs.
3. Validate amount, currency, provider reference, and expected pending payment before changing booking state.
4. Add replay protection using provider event IDs plus timestamp windows.
5. Add integration tests for forged, replayed, partial, duplicate, and valid callbacks.

### 2. Remote database lint reports broken public functions

Evidence from `supabase db lint --linked --schema public`:

- `public.get_hotels_in_bounding_box`: `st_makeenvelope(...) does not exist`
- `public.bookings_initiate`: `gen_random_bytes(integer) does not exist`
- `public.review_manager_application`: `type "geography" does not exist`
- `public.create_payout_batch`: relation `_selected_settlements` does not exist
- `public.finalize_paid_booking`: column `booking_items.check_in_date` does not exist
- `public.complete_payout_batch`: column `settlements.updated_at` does not exist

Risk: core discovery, onboarding approval, booking finalization, and payout completion can fail at runtime.

Remediation:

1. Add a repair migration that sets `search_path` to `public, extensions` for PostGIS/crypto usage or schema-qualifies extension calls.
2. Update lifecycle functions to use current column names, such as `start_date`/`end_date` if those replaced check-in/check-out names.
3. Replace `_selected_settlements` temp-table assumptions with a real temp table declaration or CTE.
4. Re-run `npx supabase db lint --linked --schema public` until public-schema errors are zero.
5. Add SQL regression tests for booking finalization and payout completion.

### 3. Over-broad financial grants remain in later migrations

Evidence:

- `supabase/migrations/20260615143000_money_inventory_lifecycle_hardening.sql` grants `ALL` on reconciliation, payout provider, financial component, and fee policy tables to `anon` and `authenticated`.
- The same migration grants `ALL` on financial lifecycle functions to `anon` and `authenticated`.
- `supabase/migrations/20260615154000_financial_evidence_surfaces.sql` grants `ALL` on financial views to `anon`.

Risk: RLS may block some access, but broad grants make the blast radius larger and complicate audits.

Remediation:

1. Revoke `ALL` from `anon` and `authenticated` on internal financial tables.
2. Grant only required `SELECT` on explicitly public-safe views.
3. Keep mutation functions service-role only unless they perform strict `auth.uid()` and role checks.
4. Add migration tests that assert expected grants for sensitive tables.

## High Issues

### 4. Auth routing races against access-profile loading

Evidence:

- `AuthNotifier._updateFromSession()` sets `_isRoleResolved = false` and calls `_fetchAccessProfile()` without awaiting it.
- `router.dart` calls `globalRedirect(...)` using the current cached `accessProfile`.
- `globalRedirect()` does not receive or check `isInitialized` / `isRoleResolved`.

Risk: a signed-in user can be temporarily treated as a guest/customer, causing wrong redirects, onboarding loops, or confusing access denials.

Remediation:

1. Replace scattered booleans with a single auth state model: `initializing`, `signedOut`, `resolvingProfile`, `signedIn`, `passwordRecovery`, `error`.
2. Make the router return `null` or a loading route until auth initialization and profile resolution finish.
3. Add tests for manager/admin/staff deep links during profile loading.

### 5. Auth flows bypass one another

Evidence:

- Login uses `authNotifierProvider`.
- Signup creates `final authService = AuthService()` directly.
- Forgot/reset password screens call `Supabase.instance.client.auth` directly.
- Reset redirect is hardcoded to `soko-mtandao://reset-password`.

Risk: inconsistent audit logging, refresh behavior, error mapping, and redirect handling.

Remediation:

1. Introduce a single `AuthRepository` or expand `AuthNotifier` so all auth UI uses the same path.
2. Move password-reset redirect URL to `EnvConfig`.
3. Add tests for signup, login, signout, password recovery, frozen account, and profile fetch failure.

### 6. Supabase auth configuration is weak for production

Evidence:

- `minimum_password_length = 6`
- `password_requirements = ""`
- `enable_confirmations = false`
- `secure_password_change = false`
- reset email frequency is `1s`

Risk: low-friction account takeover and noisy auth abuse.

Remediation:

1. Require 8-12+ character passwords with mixed requirements or a breached-password check.
2. Enable email confirmation before sensitive roles can be used.
3. Enable secure password change and tune email rate limits.
4. Verify deep-link redirect allowlists for Android, iOS, and web.

### 7. Native checkout permits partial payment without a product rule

Evidence:

- `create_checkout_native` accepts `amount` less than booking total and records `is_partial`.
- Payment finalization only completes once total paid reaches booking total.

Risk: users can initiate arbitrary partial payments unless deposits/installments are explicitly supported.

Remediation:

1. Either require `amount == booking.total_price` or define a deposit/installment domain model.
2. Surface partial-payment status clearly in UI and admin tools.
3. Add tests for underpay, overpay, exact pay, duplicate success, and failed payment.

### 8. Privileged admin surfaces are client-heavy

Evidence:

- `SystemAdminDashboardScreen` reads compliance, KYC, dispute, and investigation tables directly.
- It calls admin RPCs from the client, relying on RLS/function checks.

Risk: mistakes in grants/RLS expose sensitive admin data or actions.

Remediation:

1. Keep UI route checks, but treat them as cosmetic only.
2. Move admin dashboard reads into RPCs that enforce `is_system_admin(auth.uid())`.
3. Verify every admin RPC rejects non-admin authenticated users.
4. Add negative tests for customer, staff, hotel admin, and anonymous callers.

## Medium Issues

### 9. Manager data operations are incomplete and partially non-atomic

Evidence:

- `ManagerRemoteDataSource` still throws `UnimplementedError` for update hotel, cancel booking, deactivate hotel, fetch bookings, room availability, rooms by offering, and update booking.
- Add/edit hotel flows upload images, write hotels, then write amenities as separate client operations.
- `deleteRoom` is `void async`, so callers cannot await or catch failures.

Risk: runtime crashes and partial records when a later step fails.

Remediation:

1. Replace unimplemented methods with working RPC-backed implementations or remove unreachable UI.
2. Move multi-step mutations into transaction-safe RPCs.
3. Return `Future<void>` from async mutation methods.
4. Add manager workflow tests for create/edit/delete hotel, offering, room, staff, and booking flows.

### 10. Staff invite token exposure is partially remediated

Evidence:

- The original team screen selected `invite_token` and displayed `Token: ...` in recent invites.
- The latest local patch removes token selection/display, copies a newly created invite token once, stores token hashes for acceptance, rotates stored token values, and adds pending-invite cancellation.

Risk: tokens can leak through screenshots, shared devices, or logs.

Remediation:

1. Deploy `20260706103000_media_and_staff_invite_readiness.sql`.
2. Add expiry, revocation, wrong-email, replay, and one-time-use tests.
3. Add resend actions to the manager team UI.

### 11. Storage policy is partially remediated; validation and rollback remain

Evidence:

- Hotel image uploads use `storage.from('hotel-images').upload(...)`.
- The latest local patch uploads under `<managerUserId>/<filename>` and adds a `hotel-images` bucket/policy migration.
- File names use timestamp plus original filename; no MIME/type/size validation is visible in app code.

Risk: uploads may fail in fresh environments or allow unexpected files if bucket policies are permissive.

Remediation:

1. Deploy `20260706103000_media_and_staff_invite_readiness.sql`.
2. Validate image MIME, size, and extension before upload.
3. Clean up uploaded objects if database writes fail.
4. Prefer transaction-safe RPCs for hotel plus amenity writes.

### 12. Dead/generated files and stale source snapshots are in `lib/`

Evidence:

- `lib/file_contents.py` scans and dumps source files.
- `lib/output.txt` contains stale source snapshots, including a hardcoded Supabase anon key and obsolete mock config.
- `lib/features/management/domain/usecases/generate_usecases.py` remains in app source.

Risk: secret-scanning noise, stale guidance, larger review surface, and accidental leakage.

Remediation:

1. Delete generated dumps/scripts from `lib/`.
2. Add `lib/output.txt`, `output.txt`, and local dump patterns to `.gitignore`.
3. Run a secret scan and rotate any exposed credentials if they were ever committed publicly.

### 13. Test coverage is too narrow

Evidence:

- 253 Dart files.
- 2 test files.
- No visible edge-function tests or SQL regression tests.

Risk: auth, payment, onboarding, and manager workflows can regress silently.

Remediation:

1. Lock auth redirect behavior with unit tests before refactoring.
2. Add repository/service tests using mocked Supabase clients.
3. Add SQL tests or migration smoke tests for RLS and critical RPCs.
4. Add edge-function tests for payment and payout callbacks.

### 14. Duplicate domain boundaries create inconsistent behavior

Evidence:

- Hotel concepts appear separately in `explore`, `find_hotels`, `hotel_detail`, and `management`.
- Several features use direct Supabase clients instead of shared repositories.

Risk: fixes in one flow do not automatically apply to other hotel/search/detail flows.

Remediation:

1. Define canonical hotel, offering, room, booking, and payment contracts.
2. Keep feature-specific view models, but centralize Supabase access per domain.
3. Replace raw `Supabase.instance.client` usage in widgets/screens with injected services.

### 15. Runtime observability is local-only

Evidence:

- `ErrorReporter` and `AnalyticsService` rely on `debugPrint`.
- Several catch blocks swallow errors.

Risk: production failures will be difficult to diagnose.

Remediation:

1. Add a production error sink with redaction.
2. Standardize error taxonomy and user-safe messages.
3. Replace silent catches with structured logs and recovery paths.

## Staged Remediation Plan

### Phase 0: Stop leakage and add guardrails

- Remove `lib/output.txt`, `lib/file_contents.py`, and generation scripts from app source.
- Add secret scanning to CI.
- Keep `access_token.txt` ignored and out of commits.
- Document required local tools: Flutter SDK, Supabase CLI via `npx`, and env files.

### Phase 1: Stabilize Supabase production behavior

- Fix all public-schema Supabase lint errors.
- Revoke broad financial grants and add least-privilege grants.
- Add SQL tests for role access, booking finalization, payout transitions, and manager onboarding approval.
- Verify storage bucket policies.

### Phase 2: Secure payment and payout flows

- Add verified callback authentication.
- Remove unverified payment recovery.
- Add idempotent state-machine tests.
- Define exact payment/deposit rules and enforce them server-side.
- Completed slice: AzamPay payout readiness now requires approved KYC, verified phone, accepted payout terms, and an approved active hotel payout account before locking settlements or dispatching disbursement.

### Phase 3: Rebuild auth state flow

- Centralize auth UI through one service/notifier.
- Gate routing on initialized/resolved auth state.
- Harden Supabase auth config.
- Add auth redirect tests for each persona and loading state.

### Phase 4: Repair manager/admin workflows

- Replace direct multi-step client writes with RPC-backed transactions.
- Finish or remove unimplemented manager datasource methods.
- Move admin reads/actions behind audited RPCs.
- Mask and hash staff invite tokens.

### Phase 5: Consolidate architecture and coverage

- Consolidate duplicated hotel/search/detail data access.
- Standardize repositories and dependency injection.
- Build a minimum CI gate: format, analyze, test, Supabase lint, secret scan.
- Add end-to-end smoke tests for signup, onboarding, booking, payment, payout, and account deletion.

## Suggested Priority Backlog

1. Add tests for auth redirects, payment callbacks, payout readiness, and payout dispatch failures.
2. Build admin review UI for KYC and payout account approval.
3. Finish manager datasource methods or hide incomplete UI.
4. Centralize signup/reset/login.
5. Move remaining admin and manager mutations to audited RPCs.
6. Add storage validation and rollback cleanup for failed multi-step property writes.
7. Consolidate duplicated hotel data access.
