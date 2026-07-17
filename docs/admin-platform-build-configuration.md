# Admin platform build configuration

This document describes how the optional CalculFF customer platform receives its Supabase client configuration during signed Android release builds.

## GitHub Repository Variables

The signed release workflow reads exactly these repository variables:

- `CALCULFF_SUPABASE_URL`
- `CALCULFF_SUPABASE_PUBLISHABLE_KEY`

The real values are configured in GitHub Repository Variables outside the repository. They must not be committed to source files, generated configuration files, logs, or artifacts.

These variables are consumed only by the signed APK and AAB build steps. Pull-request verification, `flutter analyze`, and `flutter test` do not require Supabase configuration.

## Client-visible values and security boundary

A Supabase Project URL and Publishable Key are client configuration values. They can be present inside a mobile application and are not administrative secrets.

They do not grant unrestricted database access. Platform security must continue to depend on:

- Supabase Auth for user identity and sessions.
- Row Level Security policies for table access.
- RPC permissions for server-side operations.

Never use or expose any of the following in the application or workflow:

- `service_role` keys.
- `sb_secret_` keys or other secret keys.
- the database password.
- Supabase access tokens.
- JWT signing secrets.

## Signed GitHub Actions builds

On a non-pull-request run, the workflow validates that both variables are present, that the URL uses HTTPS, and that the publishable key does not resemble an administrative key or an obvious placeholder.

The runner then passes the values from environment variables to both release commands:

```text
--dart-define=SUPABASE_URL=...
--dart-define=SUPABASE_PUBLISHABLE_KEY=...
```

The values exist only in the temporary runner environment for the relevant validation and build steps. The workflow does not echo them, write them to `.env`, generate a configuration JSON or YAML file, or upload an environment dump.

## Local release build example

Use placeholders while documenting or preparing a local command. Replace them only in your local shell and never commit the resulting command or values:

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY

flutter build appbundle --release \
  --dart-define=SUPABASE_URL=https://PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

The application performs its own project-host validation before enabling the platform client.

## Behavior without configuration

Missing or invalid Supabase configuration does not block the local SQLite application. Local calculations, inventory, reports, settings, backups, and other offline features remain available.

Only the customer platform is unavailable until valid configuration is supplied.

## Coverage output

Pull-request verification generates Flutter coverage without enforcing a percentage threshold. The LCOV file is written under `build/coverage/lcov.info`; the existing `build/` ignore rule keeps it outside version control. Coverage is not uploaded through an additional external action in this phase.
