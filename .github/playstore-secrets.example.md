# Play Store GitHub Secrets Example

Add these as repository or environment secrets in GitHub:
`Settings -> Secrets and variables -> Actions -> New repository secret`.

For safer production publishing, create a GitHub environment named `playstore`,
add the same secrets there, and require manual approval before deployment.

## Required Secrets

| Secret | Example value | Notes |
| --- | --- | --- |
| `APP_ENV_JSON_BASE64` | `ewogICJTVVBBQkFTRV9VUkw...` | Base64 of the app config JSON used by `--dart-define-from-file`. |
| `ANDROID_KEYSTORE_BASE64` | `MIIK...` | Base64 of the Android upload keystore `.jks` file. |
| `ANDROID_KEYSTORE_PASSWORD` | `replace-with-keystore-password` | Keystore store password. |
| `ANDROID_KEY_PASSWORD` | `replace-with-key-password` | Password for the key alias. |
| `ANDROID_KEY_ALIAS` | `upload` | Key alias inside the keystore. |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | `{ "type": "service_account", ... }` | Plain JSON from a Google Cloud service account with Play Console app permissions. |

## Generate Encoded Values

```bash
base64 -w 0 env/app.env.json
base64 -w 0 android/app/upload-keystore.jks
```

`APP_ENV_JSON_BASE64` should decode to a JSON file shaped like:

```json
{
  "SUPABASE_URL": "https://your-project-ref.supabase.co",
  "SUPABASE_ANON_KEY": "your-supabase-anon-key",
  "MAPBOX_ACCESS_TOKEN": "pk.your-mapbox-public-token",
  "APP_BASE_URL": "soko_mtandao://",
  "SUPPORT_EMAIL": "support@example.com",
  "SUPPORT_PHONE": "+255 000 000 000",
  "SUPPORT_ADDRESS": "Arusha, Tanzania",
  "PRIVACY_POLICY_URL": "https://example.com/privacy",
  "PASSWORD_RESET_REDIRECT_URL": "soko-mtandao://reset-password"
}
```

The Play Console app must already exist with package
`com.soko_mtandao.soko_mtandao`, and the first release may need to be uploaded
manually before API uploads are accepted.

## Version Codes

Google Play rejects any Android `versionCode` that has already been uploaded.
The committed Flutter version in `pubspec.yaml` is the default source. The next
Play Store deployment is `1.0.6+13`, which means `versionName=1.0.6` and
`versionCode=13`.

For one-off reruns, the workflow also accepts optional `build_name` and
`build_number` inputs. Use `build_number` only with a value higher than the
latest Play Console version code.
