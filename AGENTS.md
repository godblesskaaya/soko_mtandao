# Repository Guidelines

## Project Structure & Module Organization

This is a Flutter application with Supabase backend assets. App code lives in `lib/`, with shared code in `lib/core/`, navigation in `lib/router/`, layout/theme helpers in `lib/layouts/` and `lib/theme/`, and user-facing features under `lib/features/<feature>/`. Feature folders generally split into `data/`, `domain/`, and `presentation/` layers when needed. Tests live in `test/` and mirror the area under test, such as `test/router/redirect_logic_test.dart`. Static assets are in `assets/`; web, Android, iOS, macOS, Linux, and Windows platform wrappers are in their standard Flutter directories. Supabase migrations, edge functions, and maintenance SQL are under `supabase/`.

## Build, Test, and Development Commands

- `flutter pub get` installs Dart and Flutter dependencies from `pubspec.yaml`.
- `flutter run --dart-define-from-file=env/app.env.json` runs locally with app configuration.
- `flutter analyze` runs the Dart analyzer and configured lints.
- `flutter test` runs all unit and widget tests in `test/`.
- `dart run build_runner build --delete-conflicting-outputs` regenerates generated Dart files when models or annotations change.

## Coding Style & Naming Conventions

Follow `analysis_options.yaml`, which includes Flutter lints. Use `dart format .` before submitting changes. Dart files use `snake_case.dart`; classes, widgets, providers, and notifiers use `UpperCamelCase`; variables and methods use `lowerCamelCase`. Keep feature-specific code inside its feature folder and reuse `lib/core/` utilities before adding new helpers. Prefer Riverpod providers for state already managed through Riverpod.

## Testing Guidelines

Use `flutter_test` for tests. Name test files with the `_test.dart` suffix and group tests around the public unit being verified, as in `group('AccessProfile', ...)`. Add regression tests for routing, access-profile, payment, or onboarding behavior before changing those flows. Run `flutter test` and `flutter analyze` before opening a pull request.

## Commit & Pull Request Guidelines

Recent history mostly uses concise imperative commits, often with Conventional Commit prefixes such as `feat:` or scoped forms like `feat(migrations):`. Keep commits focused and describe the observable change. Pull requests should include a short summary, test evidence, linked issue or task when available, and screenshots for UI changes. Call out database migrations, Supabase function changes, and required environment variable updates explicitly.

## Security & Configuration Tips

Do not commit real secrets. Copy `env/app.env.example.json` to a local ignored file for app values, and use `supabase/functions/.env.example` as the template for edge function secrets. Required keys include `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `MAPBOX_ACCESS_TOKEN`, and payment-related Supabase/Azampay secrets for backend flows.
