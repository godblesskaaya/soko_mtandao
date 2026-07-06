# Supabase staging migration

Created on 2026-06-26.

## Projects

- Production/current: `wqmarlzyzukreiwibwjs` (`Soko Mtandao`)
- Staging clone: `umvmsdwjkntcyvdcjbso` (`Soko Mtandao Staging`)
- Staging dashboard: `https://supabase.com/dashboard/project/umvmsdwjkntcyvdcjbso`

The local repo was relinked back to production after staging setup.

## Backup

Backup folder:

```text
backups/supabase-current-20260626-085622
```

This folder is gitignored because it contains user, auth, payment, and storage metadata.

Included files:

- `roles.sql`
- `public_schema.sql`
- `public_auth_storage_schema_snapshot.sql`
- `public_auth_storage_data.sql`
- filtered restore files used for staging
- source/staging count checks
- staging secret gap report

Storage object metadata and file bytes were copied.

The repeatable migration utility is:

```text
tool/migrate_supabase_storage_bytes.mjs
```

Useful commands:

```powershell
node tool\migrate_supabase_storage_bytes.mjs --dry-run
node tool\migrate_supabase_storage_bytes.mjs
node tool\migrate_supabase_storage_bytes.mjs --verify-target
```

Verified storage byte copy:

```text
hotel-images: 42 objects, 5046319 bytes
Soko mtandao apk: 1 objects, 166704 bytes
total: 43 objects, 5213023 bytes
```

## Verification

Source and staging counts matched after restore:

```text
auth.users,26
storage.buckets,2
storage.objects,43
public.hotels,25
public.bookings,138
public.payments,170
```

## Edge Functions

Deployed to staging:

- `create_checkout` (`verify_jwt=true`)
- `create_checkout_native` (`verify_jwt=true`)
- `delete-user` (`verify_jwt=true`)
- `payout_dispatch` (`verify_jwt=true`)
- `payment_callback` (`verify_jwt=false`)
- `payout_callback` (`verify_jwt=false`)

## Missing Staging Secrets

Supabase automatically created staging `SUPABASE_*` function secrets, but custom secret values cannot be read back from production. Set these on staging before testing payments:

```text
AZAMPAY_APP_NAME
AZAMPAY_AUTH_URL
AZAMPAY_CALLBACK_SECRET
AZAMPAY_CHECKOUT_URL
AZAMPAY_CLIENT_ID
AZAMPAY_CLIENT_SECRET
AZAMPAY_VENDOR_ID
AZAMPAY_VENDOR_NAME
ORIGIN
```

Use sandbox AzamPay values for staging.

A tracked template exists at:

```text
supabase/functions/staging.env.example
```

Create the ignored real file `supabase/functions/staging.env`, fill in sandbox values, then run:

```powershell
npx --yes --cache .npx-cache-supabase supabase@latest secrets set --project-ref umvmsdwjkntcyvdcjbso --env-file supabase/functions/staging.env
```

## Local Staging App Config

The ignored file `env/supabase.staging.local.json` contains the staging project URL and API keys for local app configuration.

A tracked Flutter/app staging template exists at:

```text
env/app.env.staging.example.json
```

Copy it to an ignored local env file and fill in the real Mapbox public token before running the app against staging:

```powershell
flutter run --dart-define-from-file=env/app.env.staging.json
```

## Production Cleanup Gate

Production transactional/test data has been cleaned.

Production cleanup should be targeted SQL, not a remote reset.

Use this read-only planning script first:

```text
supabase/maintenance/production_cleanup_dry_run.sql
```

It creates temporary candidate tables, reports likely test/demo users, hotels, bookings, and payments, then rolls back. Review the IDs before writing any destructive cleanup script.

After reviewing the candidates, a guarded execution script exists at:

```text
supabase/maintenance/production_cleanup_execute_reviewed.sql
```

It refuses to run by default. The default guard was verified and exits with code `3`. To intentionally run it after review:

```powershell
psql "$PRODUCTION_DB_URL" -v ON_ERROR_STOP=1 -v execute_cleanup=true -f supabase/maintenance/production_cleanup_execute_reviewed.sql
```

Verified dry-run output was saved to:

```text
backups/supabase-current-20260626-085622/production_cleanup_dry_run.out
```

Review CSV exports were also saved to:

```text
backups/supabase-current-20260626-085622/cleanup_candidate_summary.csv
backups/supabase-current-20260626-085622/cleanup_candidate_bookings.csv
backups/supabase-current-20260626-085622/cleanup_candidate_payments.csv
```

Current candidate counts from that dry-run:

```text
candidate_users: 0
candidate_hotels: 0
candidate_bookings: 88
candidate_payments: 91
azampay_token_cache: 1
payment_logs: 135
payment_webhook_events: 17
payout_provider_events: 0
```

Before cleanup, a fresh production backup was created at:

```text
backups/supabase-pre-clean-20260626-101344
```

Cleanup execution outputs are in that folder:

```text
production_cleanup_execute_retry.out
production_cleanup_transactional_state.out
production_cleanup_dry_run_final.out
final_counts.csv
```

Initial transactional cleanup verification:

```text
auth.users,26
storage.buckets,2
storage.objects,43
public.hotels,25
public.offerings,63
public.hotel_rooms,99
public.staff,0
public.bookings,0
public.booking_items,0
public.payments,0
public.settlements,0
public.ledger_entries,0
public.payment_logs,0
public.payment_webhook_events,0
public.azampay_tokens,0
```

## Public Schema Data Wipe

After the transactional cleanup, the production `public` schema was also wiped to an empty data state while preserving schema objects.

Fresh pre-wipe backup:

```text
backups/supabase-pre-public-wipe-20260626-124221
```

Execution output:

```text
backups/supabase-pre-public-wipe-20260626-124221/production_wipe_public_schema_data.out
```

Reusable guarded wipe script:

```text
supabase/maintenance/production_wipe_public_schema_data.sql
```

Final verification:

```text
public_total_rows,0
public_tables_with_rows,0
auth.users,26
storage.buckets,2
storage.objects,43
```

This means all `public` schema table rows are gone. Auth users and Storage files remain; remove them separately via Auth Admin/Storage APIs if a literal whole-project wipe is later required.

## Required Seed Data

After reviewing the schema and app assumptions, a small idempotent seed file was added:

```text
supabase/seed.sql
```

It restores only reference/config data:

```text
roles: customer, staff, hotel_admin, system_admin
compliance_settings: audit_log_retention_days = 2555
payment_provider_fee_policies: azampay, 3% platform-owned fee
amenities: 8 generic hotel amenities
```

The seed was applied to production after the public data wipe. Verification:

```text
roles,4
compliance_settings,1
payment_provider_fee_policies,1
amenities,8
hotels,0
bookings,0
payments,0
```

The seed keeps business data empty while restoring the lookup/config rows needed for onboarding, administration, fee calculation, and hotel setup UX.

The current project remains linked as production:

```text
wqmarlzyzukreiwibwjs
```

Staging function secrets still need sandbox AzamPay values before payment flows can be tested there.
