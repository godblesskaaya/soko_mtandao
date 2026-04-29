# soko_mtandao

A new Flutter project.

## Environment and secret management

This project now reads sensitive values from environment variables instead of hardcoded source values.

### Flutter app variables

Copy `env/app.env.example.json` to a local file (for example `env/app.env.json`) and fill in real values.

Run with:

```bash
flutter run --dart-define-from-file=env/app.env.json
```

Required keys:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `MAPBOX_ACCESS_TOKEN`

Optional keys:

- `APP_BASE_URL`
- `SUPPORT_EMAIL`
- `SUPPORT_PHONE`
- `SUPPORT_ADDRESS`
- `PRIVACY_POLICY_URL`

### Android Mapbox token

The Android manifest token is no longer hardcoded. It is injected through `MAPBOX_ACCESS_TOKEN` using:

- `--dart-define MAPBOX_ACCESS_TOKEN=...` or `--dart-define-from-file=...`
- or a Gradle/property environment variable named `MAPBOX_ACCESS_TOKEN`

### Supabase Edge Functions secrets

Copy `supabase/functions/.env.example` to `supabase/functions/.env.local` for local serving, or set these using Supabase secrets in deployed environments:

```bash
supabase secrets set --env-file supabase/functions/.env.local
```

Required for payment flows:

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `AZAMPAY_APP_NAME`
- `AZAMPAY_CLIENT_ID`
- `AZAMPAY_CLIENT_SECRET`

Optional keys are documented in `supabase/functions/.env.example`.
