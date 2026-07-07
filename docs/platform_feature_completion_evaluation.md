# Platform Feature Completion and Edge-Case Evaluation

Date: 2026-07-06

## Platform Objectives

Soko Mtandao is a multi-role property marketplace. The core objective is to let many property managers list and fully operate their properties on the platform, while customers can book either anonymously or while signed in, manage their stay, and leave ratings after eligible stays. The platform also needs to support payments, manager payouts, retained platform commission, and compliance controls.

The product objectives are:

- Guests/customers discovering properties, selecting rooms/offerings, booking anonymously or as logged-in users, paying, tracking stays, managing booking issues, and rating completed stays.
- Property managers onboarding, passing KYC, listing one or more properties, managing property details, offerings, rooms, availability, staff, bookings, payments, and payouts.
- Staff joining a hotel team and handling daily operational booking tasks.
- System admins reviewing KYC/operator access, handling disputes/compliance, overseeing financial risk, and controlling account risk.
- Supabase-backed security, anonymous booking recovery, payment state transitions, inventory locks, commission accounting, settlements, auditability, and regulatory controls.

## Executive Readiness Summary

The platform is past prototype stage for the customer booking/payment and manager workspace foundations, but it is not production-complete against the clarified objectives. Core user journeys exist in UI and backend primitives, especially discovery, anonymous ticket-based booking lookup, booking initiation, payment evidence, manager onboarding, manager property operations, staff invites, KYC/admin review, commission/settlement tables, and payout data surfaces. The current readiness pass also adds media bucket policies and one-time staff invite token handling. The main gaps are full manager operating completeness, customer stay-management depth, review/rating UI, end-to-end verification, edge-case coverage, deployment of the latest Supabase repairs, transactional integrity for multi-step manager flows, staff operations depth, and test coverage.

Overall readiness estimate:

- Customer marketplace: 70%
- Booking and payment lifecycle: 65%
- Manager operations: 62%
- Staff operations: 32%
- System admin/compliance: 55%
- Financial settlement and payout: 55%
- Commission accounting: 60%
- Ratings and post-stay experience: 45%
- Anonymous booking support: 65%
- Security and authorization: 65% locally, lower until migrations are deployed
- Automated test coverage: 15%

## Completion Matrix

| Area | Current Coverage | Gaps Blocking Completion |
| --- | --- | --- |
| Auth and persona routing | Login/signup/reset flows exist; route guard handles customer, staff, hotel admin, system admin, pending access, and profile-loading states. | Missing full auth service tests, email-confirmation behavior tests, frozen-account UX tests, and deep-link reset tests. |
| Customer discovery | Property search, map/explore, detail, offerings, amenities, date-based room availability RPC integration. | Search/filter edge cases need coverage: empty dates, invalid ranges, zero guests, unavailable properties, pagination, malformed images. |
| Anonymous and logged-in booking | `create_booking` RPC integration, ticket numbers, local ticket cache/history, secure ticket-based lookup, review and confirmation screens. | Anonymous recovery needs stronger UX and adversarial tests: lost ticket, wrong ticket, shared device, duplicate local cache, and signed-in conversion after anonymous booking. |
| Booking creation | Conflict exception handling and booking review/confirmation flows exist. | Needs tests for concurrent holds, expired holds, inclusive/exclusive dates, multi-property carts, cart tampering, anonymous vs signed-in access. |
| Payment | Hosted and native AzamPay flows, polling/realtime monitor, evidence card, dispute escalation, callback idempotency tables. | Edge functions need automated tests for forged callbacks, duplicate callbacks, amount mismatch, currency mismatch, provider timeout, late callback after expiry. Latest callback fixes must be deployed. |
| Property manager onboarding | Path selection, draft save, KYC prompt, property application submit, admin approval RPC. | Property draft has minimal validation, no image upload in onboarding, no geocoding/coordinate validation, no negative tests for rejected/duplicate applications. |
| Manager property operations | Screens for property list/detail/add/edit, offerings, rooms, room status, bookings, payments, team, KYC, settings. Remote datasource now implements common methods. | Multi-step writes are still client-side in places; need transaction-safe RPCs for property+amenities+images, offering+amenities, room availability changes. Needs stronger multi-property switching and manager portfolio views. |
| Staff operations | Staff onboarding via invite token or join request; simple staff home links to booking lookup/profile. | Staff workspace is mostly a shell. Missing assigned hotel context, check-in/check-out workflow, room status workflow, staff permissions by title, audit trails. |
| System admin | Dashboard reads KYC, manager apps, freezes, disputes, refund SLA, investigation queue; can update KYC/app/dispute/freeze/retention. | Client reads sensitive tables directly. Needs RPC-backed admin dashboard, pagination/search, reviewer notes, bulk workflows, negative authorization tests. |
| Team access | Manager creates invites, reviews join requests, sees staff and invites. Staff can accept token or request join. Invite tokens are copied only when created, later invite lists omit the token, the latest migration stores invite-token hashes for acceptance, and managers can cancel pending invites. | Still needs resend flow and tests for one-time-use, expired, wrong-email, and replay attempts. |
| Stay management | Booking history, booking status polling, payment evidence, dispute escalation, and manager booking detail exist. | Customer stay lifecycle is incomplete: pre-arrival details, check-in/check-out status, cancellation/refund path, support history, and post-stay prompts are not fully represented. |
| Reviews/ratings | SQL support exists for verified guest reviews and rating recomputation. A basic rating dialog exists from booking lookup. | Rating is not yet a complete post-stay experience: no automatic post-stay prompt, no review history, no moderation/reporting flow, no manager response rules, and no tests for one review per booking. |
| Disputes/refunds | Dispute RPCs and admin dashboard surface exist; payment screen can submit payment reconciliation disputes. | No customer support center/history, no refund initiation UI, no refund state machine tests, no notification path. |
| Commission accounting | Financial migrations include booking-item financials, provider fees, hotel net, platform commission, ledger entries, wallet views. | Needs deployed migrations, SQL assertions for commission math, visible admin commission reports, and tests for policy changes over time. |
| Settlements/payouts | Financial views, payout request, payout dispatch/callback functions, wallet summary, manager payment evidence. | Latest financial migrations are not deployed; payout account management UI is not clear; provider callback tests are missing; ledger correctness needs SQL regression tests. |
| Account deletion | Manager deletion invokes a JWT-protected edge function; guest/customer data controls clear local booking history and direct users to support for permanent deletion. | Needs data retention/anonymization policy, cascade verification, manager/staff account edge cases, signed-in customer deletion path, and legal/compliance confirmation UX. |
| Storage/media | Hotel image upload exists in manager flow. Latest app code uploads under the manager user folder, and the latest migration creates the `hotel-images` bucket with public reads, MIME/size limits, and manager/admin write policies. | Client-side MIME/size validation and cleanup on DB write failure are still missing. |
| Observability | Local debug logging, payment logs/audit events in migrations/functions. | No production error sink, no structured user journey analytics beyond debug output, no alerting for failed callbacks/payouts. |

## Edge-Case Coverage Assessment

### Covered or Partially Covered

- Duplicate payment callbacks: provider event tables and duplicate handling exist.
- Payment amount mismatch: local callback logic now quarantines mismatches into reconciliation.
- Booking conflicts: booking RPC returns conflict payloads and app maps them to `BookingConflictException`.
- Expired booking holds: payment screen blocks payment if local booking expiry has passed; cleanup RPCs exist in migrations.
- Persona access: router blocks hotel/admin/staff routes when profile state does not permit them.
- Pending operator access: users can remain customers while manager/staff onboarding is pending.
- Frozen accounts: payment and payout functions check `is_account_frozen`.
- Payout idempotency: payout batch creation and dispatch have idempotency/reference handling.
- Commission retention: schema and views model gross, provider fee, platform commission, tax, and hotel net amounts.
- Verified ratings: SQL constrains reviews to completed paid bookings owned by the authenticated user and recomputes property rating; the booking lookup screen has a basic rating dialog.

### Missing or Weak

- Anonymous booking recovery depends on ticket cache/token behavior and needs adversarial tests.
- Anonymous-to-account conversion is not clearly handled; a customer who books anonymously then signs up should be able to claim/manage the stay safely.
- Callback authentication now supports the documented AzamPay callback credentials and optional RSA signature verification for checkout callbacks; URL/header shared secret remains available as an additional hardening layer.
- Currency mismatch behavior is inconsistent: checkout may update booking currency, but callback validation needs full tests.
- Booking cancellation is not fully tied to refund/settlement reversal workflows.
- Stay management lacks a complete state model for upcoming, checked-in, checked-out, no-show, cancelled, disputed, refunded, and review-eligible states.
- Ratings exist at the SQL layer and in a basic lookup dialog, but lack product completion: post-stay prompts, review history, review window, edit policy, moderation, and manager response rules.
- Staff role permissions are not enforced by granular capability in the UI.
- Admin dashboard assumes RLS/RPC protections but still pulls broad sensitive data into the client.
- Commission and payout math needs regression coverage for policy changes, provider fees, partial refunds, failed payouts, and settlement replays.
- Network failure and offline behavior are mostly not modeled beyond error states.
- Image upload rollback and client-side validation are incomplete, although bucket-level MIME/size and folder policies now exist locally.
- Local and remote database schemas are currently out of sync until migrations deploy.

## Test Coverage Gap

Current count:

- `lib/`: 253 Dart files
- `test/`: 3 Dart test files
- `supabase/migrations/`: 18 SQL files
- `supabase/functions/`: 10 files

Coverage is not proportional to risk. The minimum next test suite should include:

1. Auth/persona redirect matrix for customer, staff, manager, system admin, pending, rejected, frozen, and profile-loading states.
2. Booking RPC regression tests for anonymous and logged-in bookings, ticket lookup, availability conflicts, expiry cleanup, duplicate booking attempts, and account-claiming behavior.
3. Edge-function tests for `create_checkout`, `create_checkout_native`, `payment_callback`, `payout_dispatch`, and `payout_callback`.
4. SQL tests for RLS grants, manager ownership, staff permissions, financial table privileges, commission math, payout transitions, refund reversal, ratings eligibility, and ledger entries.
5. Widget/provider tests for booking payment/stay states, anonymous booking recovery, manager payment actions, staff invite flow, rating submission, and system admin actions.

## Validation Evidence

This evaluation was checked against the repository on 2026-07-06:

- Routes and role guards: `lib/router/route_names.dart`, `lib/router/router.dart`, `lib/router/redirect_logic.dart`.
- Customer booking: `lib/features/booking/`, `lib/features/find_booking/`, `lib/features/hotel_detail/`, and booking RPC migrations.
- Anonymous recovery: local booking history, ticket-number lookup, `get_booking_details_secure`, and `get_booking_details_by_ticket`.
- Ratings: `submit_hotel_review` migration and the booking lookup rating dialog.
- Manager operations: `lib/features/management/` screens, providers, datasource, and repository.
- Staff operations: `lib/features/staff/` plus staff onboarding and invite/join-request RPCs.
- System admin/compliance: `system_admin_dashboard_screen.dart`, regulatory migrations, and admin RPCs.
- Payments/payouts: `create_checkout`, `create_checkout_native`, `payment_callback`, `payout_dispatch`, `payout_callback`, financial migrations, and manager payment UI.
- Storage/media: manager upload providers and the absence of storage bucket/policy migrations.
- Readiness hardening: `20260706103000_media_and_staff_invite_readiness.sql`, manager image upload providers, and `manager_team_screen.dart`.
- Observability: local `AnalyticsService`, `ErrorReporter`, `payment_logs`, webhook event tables, and audit RPCs.
- Tests: current test files under `test/`.

Corrections from validation:

- Ratings were upgraded from “SQL only” to “basic UI plus SQL,” because `FindBookingScreen` exposes a rating dialog for confirmed paid bookings.
- Account deletion was clarified as manager edge-function deletion plus local guest/customer data clearing, not a complete account lifecycle for every persona.
- Stay management was confirmed as intentionally low because booking states currently collapse to `pending`, `confirmed`, and `cancelled` in the app model.

## Priority Completion Plan

### P0: Make Current Backend Safe and Deployable

- Deploy the local Supabase repair/least-privilege migrations.
- Re-run remote `supabase db lint` until public schema has zero errors.
- Set AzamPay callback credential/signature secrets, hosted-checkout vendor fields, and disbursement source-account secrets in deployed function secrets.
- Add edge-function tests for callback forgery, replay, amount mismatch, and duplicate success.
- Done on 2026-07-07: added AzamPay payout readiness RPCs, expanded manager KYC fields, payout account submission/review gates, and dispatch-time destination validation.

### P1: Complete Money and Inventory State Machines

- Add SQL regression tests for booking finalization, room locks, cancellation, refund, settlement allocation, payout request, payout dispatch, payout callback success/failure.
- Define whether partial payments, deposits, and refunds are supported; if not, reject them everywhere.
- Add commission-policy regression tests covering platform commission, provider fees, hotel net, tax, refunds, and payout eligibility.
- Add admin review UI for payout account approval; manager submission and backend validation now exist.

### P2: Finish Role Workflows

- Add a manager portfolio view for operators with multiple properties, including active property switching, property health, pending tasks, and payout readiness.
- Expand staff workspace into operational tasks: assigned hotel, booking verification, check-in/check-out, room status updates, and limited permissions by staff title.
- Move system admin dashboard reads behind audited RPCs.
- Add resend flow and expiry/replay tests for staff invites.

### P3: Harden Marketplace UX

- Add anonymous booking recovery and optional claim-to-account flow.
- Add customer stay management for upcoming/current/past stays, cancellation/refund requests, check-in status, support cases, and payment evidence.
- Add post-stay review UI with review eligibility, edit policy, moderation/reporting, and manager response rules.
- Add dispute/refund history for customers and managers.
- Add client-side image validation and rollback cleanup for failed multi-step property writes.
- Add user-facing empty/offline/error states for search, booking, payment, and manager flows.

### P4: Establish CI Coverage

- Install and enforce Flutter format/analyze/test.
- Add Supabase local reset/lint to CI.
- Add Deno or Supabase function tests.
- Add secret scanning and migration/grant assertions.

## Recommended Next Implementation Slice

The highest-value next slice is backend verification and deployment readiness:

1. Get remote DB credentials working.
2. Push the two new migrations.
3. Re-run remote lint.
4. Add callback and SQL regression tests.
5. Only then continue UI expansion, because the current biggest risk is money/inventory correctness rather than missing screens.
