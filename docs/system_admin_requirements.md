# System Admin Requirements

## Purpose

The system admin area is the operations console for Soko Mtandao. It must let authorized platform administrators monitor operational risk, review user and operator submissions, manage compliance controls, resolve disputes, and take account-safety actions without mixing unrelated workflows into one overloaded screen.

## Roles And Access

- Only users with the `system_admin` role may open `/system-admin/*` routes.
- System admins bypass user onboarding and land on the admin dashboard after authentication.
- Non-admin users attempting system-admin routes are redirected to customer home.
- Admin screens must avoid exposing customer/operator onboarding actions as primary admin workflows.

## Core Workflows

1. Dashboard
   - Show platform operations health at a glance.
   - Surface counts for pending KYC, manager applications, active disputes, frozen accounts, breached refund SLAs, and flagged investigation events.
   - Link to focused operational areas.

2. KYC Review
   - List profiles requiring review.
   - Open one profile on a dedicated review page.
   - Show identity details, submission timestamps, review status, notes, and document references.
   - Allow approve, reject, and suspend actions with admin notes.

3. Manager Application Review
   - List manager/hotel applications by status and recency.
   - Open one application on a dedicated review page.
   - Show applicant id, hotel payload, review notes, and operational readiness details.
   - Allow mark under review, approve, and reject actions with review notes.

4. Dispute Operations
   - List active customer disputes.
   - Open one dispute on a dedicated review page.
   - Show ticket, booking id, category, SLA due time, description, admin notes, and status.
   - Allow mark under review, resolve, and reject actions with admin notes.

5. Account Controls
   - Allow admins to freeze or unfreeze a user by user id.
   - Require clear reason text for operational traceability.
   - Show currently active freezes.

6. Compliance And Risk
   - Update audit retention policy.
   - Review refund SLA breaches and pending refund SLA items.
   - Review flagged audit/investigation events.

## Non-Functional Requirements

- Screens must be scannable on mobile and desktop.
- Actions that mutate backend state must be on review/detail pages or explicit control pages, not dashboard cards.
- Loading, empty, and error states must be visible and actionable.
- Data should be refreshed after every successful admin action.
- The implementation must reuse existing Supabase tables and RPCs unless a backend gap is explicitly identified.
- The dashboard must remain informational and navigational, not an action dumping ground.

## Existing Backend Contracts

- Tables/views:
  - `kyc_profiles`
  - `kyc_documents`
  - `operator_applications`
  - `account_freezes`
  - `disputes`
  - `refund_sla_tracker_view`
  - `admin_investigation_queue_view`
  - `compliance_settings`
- RPCs:
  - `set_kyc_status(uuid, text, text)`
  - `review_manager_application(uuid, text, text)`
  - `set_dispute_status(uuid, text, text)`
  - `set_account_freeze(uuid, boolean, text)`
  - `set_retention_policy_days(integer)`
