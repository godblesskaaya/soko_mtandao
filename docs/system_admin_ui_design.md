# System Admin UI Design

## Information Architecture

The admin area is split into focused pages:

- `/system-admin/home` - dashboard
- `/system-admin/kyc` - KYC queue
- `/system-admin/kyc/:userId` - KYC review
- `/system-admin/manager-applications` - manager application queue
- `/system-admin/manager-applications/:applicationId` - manager application review
- `/system-admin/disputes` - dispute queue
- `/system-admin/disputes/:disputeId` - dispute review
- `/system-admin/accounts` - account freeze controls
- `/system-admin/compliance` - retention, refund SLA, and investigation monitoring

## Layout Principles

- Use the dashboard only for summary metrics and navigation.
- Use queue pages for scanning and triage.
- Use review pages for mutation actions.
- Keep destructive or compliance-sensitive actions close to their supporting context.
- Keep cards compact with 8px radius or less where locally practical.
- Prefer readable operational density over marketing-style layout.

## Dashboard

The dashboard contains:

- Header with refresh and persona switcher.
- Metric cards for operational queues.
- Workstream cards linking to KYC, manager applications, disputes, account controls, and compliance.
- No approve/reject/freeze actions.

## Queue Pages

Queue pages contain:

- List of rows ordered by most recent operational activity.
- Status chips.
- Primary row title.
- Key metadata such as user id, ticket number, submitted time, SLA due date.
- A clear `Open review` action.

## Review Pages

Review pages contain:

- Summary card with status and primary identifiers.
- Detail cards for submitted data.
- Notes field for admin decision notes.
- Action buttons grouped by workflow state.
- Refresh after every action.

## Error And Empty States

- Empty queues state the queue is clear.
- Failed loads show the error and a retry action.
- Successful actions show a snackbar and refresh the current page.

## Guarding

All admin routes live under `/system-admin` and rely on the shared redirect guard. The dashboard is the only bottom-navigation admin entry. Child pages are reached from dashboard/workflow links.
