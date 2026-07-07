# Manager Operations Audit

## Scope

This audit reviews the manager journey from property creation through inventory, bookings, payments, payouts, KYC, and staff operations. The goal is to identify what is functionally ready, what is partially wired, and what must be hardened before the manager workspace can be considered production-ready.

## Current Strengths

- Core manager surfaces exist for hotels, offerings, rooms, bookings, payments, KYC, payouts, and staff.
- Payments and callback processing have been smoke-tested through AzamPay sandbox, with booking confirmation, payment records, ledger entries, and webhook event persistence working end to end.
- Payout readiness is enforced server-side through `get_hotel_payout_readiness` and `request_hotel_payout`; requests require approved KYC and an approved active payout account.
- Staff invitation and join-review flows use RPCs for the main approval paths.
- Room status changes use an RPC rather than raw client writes.

## High-Risk Findings

### 1. Property creation and editing are non-atomic

`add_hotel_provider.dart` and `edit_hotel_provider.dart` directly upload images, mutate `hotels`, and then mutate `hotel_amenities`. A failure after image upload can leave orphaned storage files. A failure after hotel insert/update can leave a property without the selected amenities. Edit also deletes all amenities before reinserting, so a partial failure can erase previous amenity data.

Remediation: move property create/update into RPCs such as `upsert_managed_hotel`, passing hotel fields, amenity IDs, and committed image URLs together. Add cleanup for failed uploads and storage deletion for removed images.

### 2. Offering amenity sync can corrupt data on partial failure

`ManagerRemoteDataSource._syncOfferingAmenities` deletes all existing `offering_amenities` and inserts the new set afterward. `createOffering` and `updateOffering` can therefore leave an offering present but missing amenities.

Remediation: add `upsert_offering_with_amenities` as a transaction-safe RPC. Validate hotel ownership, offering state, amenity IDs, pricing, occupancy, and image URLs server-side.

### 3. Room add/edit/delete has incorrect failure UX

`RoomScreen._submit` and `_confirmDelete` pop the route after awaiting the notifier even when the notifier stores a `Left(Failure)` result. This can make a failed create/update/delete look successful. Room deletion is also a direct `hotel_rooms` delete without a business-rule RPC checking active bookings, future reservations, or settlement state.

Remediation: make room mutation methods return success/failure to the screen before navigation. Replace direct deletes with a safe deactivation/archive RPC that blocks rooms with active or future bookings.

### 4. Booking management is not operationally complete

The booking list is read-heavy and uses booking-item rows with follow-up loads for room and booking detail. The manager booking detail surface is thin and does not expose the full stay, room, payment, reconciliation, cancellation, or support context. `cancelBooking` directly updates `bookings` to cancelled and does not coordinate refunds, room-status release, settlement reversal, audit logging, or customer messaging.

Remediation: create a manager booking detail view/RPC that returns booking, items, room, customer, payment, ledger, webhook, and status history in one payload. Add `cancel_booking_for_manager` with refund-policy checks, inventory release, payment/ledger transitions, and audit logging.

### 5. Inventory status RPC is too permissive

`upsert_room_statuses` deletes statuses for selected dates and inserts the requested status. The implementation does not visibly enforce manager ownership, allowed status transitions, or protection against overwriting booked/pending dates created by the booking flow.

Remediation: replace or harden the RPC with ownership checks, date-range validation, transition rules, and conflict protection for statuses tied to active bookings.

## Medium-Risk Findings

### 6. Payout UX is wired but not fully transparent

The manager payment screen correctly checks payout readiness, shows ledger details, and can request payouts. However, `requestPayout` may return a batch even if dispatch fails later, and the UI message can imply the payout was fully submitted. Managers also lack a clear retry/history view for payout batches and provider failures.

Remediation: distinguish `batch_created`, `dispatch_pending`, `provider_pending`, `paid`, and `failed` in UI copy. Add payout batch history with retry/escalation states.

### 7. KYC collection is not compliance-grade

`manager_kyc_screen.dart` allows the manager to toggle `phoneVerified` manually and asks for a document URL rather than offering secure upload and verification. This weakens payout compliance even though backend readiness requires approved KYC.

Remediation: remove self-attested phone verification, add OTP or verified-contact evidence, and implement secure document upload with file metadata, review status, and audit events.

### 8. Staff management is partial

The team screen can create invites and review join requests, but active staff management is mostly read-only. Role changes and invite cancellation still have direct-table patterns in parts of the code. Join requests show raw IDs rather than useful identity details.

Remediation: add RPCs for cancel invite, change role, deactivate staff, and transfer/remove access. Use controlled role names and show staff identity, status, last activity, and audit history.

### 9. Multi-property operations need stronger context

Managers can select hotels, but the selected hotel appears to be volatile in app state. There is no consolidated property readiness checklist showing missing rooms, offerings, photos, KYC, payout account, or policy setup.

Remediation: persist selected property per manager and add a readiness dashboard for each property before it can be confidently listed.

### 10. Test coverage is too thin for manager workflows

Current management tests cover model serialization only. There are no workflow tests for property setup, offering amenity sync, room mutation failure handling, booking cancellation, payout readiness, or staff permissions.

Remediation: add repository/provider tests with mocked Supabase responses, widget tests for failure navigation, and SQL/RPC tests for manager ownership, inventory conflicts, payout gating, and cancellation transitions.

## Remediation Plan

1. Stabilize destructive mutations first: property upsert, offering upsert, room archive/delete, room status updates, and booking cancellation should move to transaction-safe RPCs with ownership and audit checks.
2. Fix misleading UI behavior: mutation screens should only navigate after confirmed success and should show actionable errors on failure.
3. Complete manager operational views: booking detail, payout history, property readiness, and staff administration need complete data, status history, and next actions.
4. Harden compliance paths: implement secure document upload, real phone verification evidence, payout account review visibility, and immutable audit events.
5. Add regression coverage around the critical flows before broad refactors: property setup, inventory conflicts, payment-to-booking confirmation, payout readiness/request, and staff access changes.

## Readiness Assessment

Manager operations are usable for a narrow happy path, especially after the payment and payout readiness work, but they are not yet robust enough for production-scale property management. The main blocker is not missing screens; it is that several manager actions still perform multi-step business changes from the client without atomic server-side guarantees. The next readiness milestone should be to make every manager action that changes inventory, money, access, or compliance state pass through a validated RPC or Edge function with audit logging and deterministic failure behavior.
