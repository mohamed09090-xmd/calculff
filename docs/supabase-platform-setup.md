# CalculFF Supabase Platform setup

## Hosted project identity

The hosted Supabase project already exists. Do not create another project.

| Field | Required value |
| --- | --- |
| Organization | `gm0h1` |
| Project | `CalculFF Platform` |
| Region | `eu-west-1` |
| Expected status | `ACTIVE_HEALTHY` |
| Approved project reference | `zegjqwsvsaprnguvxuwk` |
| Forbidden legacy project reference | `txxokpovdbvsvnkpbrrp` |

Before any future link, migration push, configuration change, or smoke test, compare the project reference shown by the Supabase Dashboard with `zegjqwsvsaprnguvxuwk`. Stop immediately if the reference differs. The legacy project `txxokpovdbvsvnkpbrrp` must never be linked, modified, or used for tests.

This repository phase is local-only. The CI workflow must not use a Supabase access token, database password, hosted service-role key, secret key, JWT secret, or any production credential.

## Local prerequisites

- Docker Engine with enough memory for the local Supabase stack.
- Node.js supported by the pinned CLI package.
- Supabase CLI `2.109.1`.
- Python 3 for the Storage REST API integration suite.
- Run commands from the repository root containing `supabase/config.toml`.

Check the installed CLI and command flags instead of assuming syntax:

```bash
supabase --version
supabase start --help
supabase db reset --help
supabase migration list --help
supabase db lint --help
supabase test db --help
supabase stop --help
```

## Local verification sequence

The local stack is isolated from every hosted project. Do not run `supabase link` before or during these checks.

```bash
python3 scripts/validate_supabase_tests.py
python3 -m py_compile supabase/tests/storage/payment_proofs_storage_test.py
supabase start
supabase db reset --local
supabase migration list --local
supabase db lint --local --level error --fail-on error
supabase test db --local
python3 supabase/tests/storage/payment_proofs_storage_test.py
supabase stop --no-backup
```

`supabase db reset --local` recreates the local database, applies every migration from `supabase/migrations`, and then runs `supabase/seed.sql`. The committed database suite contains 443 pgTAP assertions. The Storage integration runner reports 25 real HTTP cases against the local Auth, PostgREST, and Storage services. It rejects non-loopback API URLs and redacts local keys and JWTs from failure output.

Use `supabase stop --no-backup` after tests so local Docker volumes are removed. Local keys are short-lived test credentials only; never write them to a file, log them, or upload them as artifacts.

## Auth configuration before production use

After explicit approval to configure the hosted project:

1. Enable Email/Password authentication.
2. Require email confirmation.
3. Keep custom SMTP deferred until the pre-production readiness phase. The default provider is suitable only for limited setup and smoke testing, not production delivery guarantees.
4. Do not enable anonymous sign-in unless a later security review explicitly requires it.

The order workflow requires a confirmed email and a complete profile before an order can be created.

## Create and promote the owner account

Apply migrations first, then create the owner through the normal Supabase Auth flow. Do not hard-code an owner email in SQL, seed data, migrations, tests, or documentation.

After the Auth user exists, obtain its UUID from the Dashboard and set it as `OWNER_UUID` in the administrator's local shell. Use a privileged, one-time SQL operation from the Dashboard SQL editor or another approved administrative channel:

```sql
update auth.users
set raw_app_meta_data =
  coalesce(raw_app_meta_data, '{}'::jsonb) || jsonb_build_object('role', 'admin')
where id = :'OWNER_UUID'::uuid;
```

If the SQL client does not support `:'OWNER_UUID'`, replace only that placeholder with the verified UUID for the intended owner. Never substitute a fixed email address as the authorization identity.

The application authorizes administrators from the signed JWT claim:

```text
raw_app_meta_data.role = admin
```

Do not use `raw_user_meta_data` or `user_metadata` for authorization because users can edit that metadata. After changing `raw_app_meta_data`, sign out and sign in again, or explicitly refresh the session, so the JWT contains the new claim. Existing access tokens can retain stale claims until renewed.

## Values allowed in a future Flutter client

Only these hosted values may later be embedded in Flutter configuration:

- Project URL.
- Publishable key.

A publishable key identifies the project; it is not authorization and is never a replacement for Row Level Security. Every exposed table, RPC, and Storage object remains protected by RLS, explicit grants, ownership checks, and server-side validation.

Never place any of the following in Flutter, this repository, GitHub Actions, build artifacts, screenshots, or logs:

- Supabase service-role key.
- Supabase secret key.
- JWT secret or JWT signing private key.
- Database password or connection string containing it.
- Supabase personal access token.
- SMTP credentials.
- Firebase credentials.
- Android keystore, signing password, or private key.

## Hosted linking and migration application — approval required

The commands in this section are documentation only. Do not run them during the backend CI phase.

After a new explicit approval, verify the Dashboard project reference is exactly `zegjqwsvsaprnguvxuwk`, then run:

```bash
supabase login
supabase link --project-ref zegjqwsvsaprnguvxuwk
supabase migration list
supabase db push
```

Before `supabase db push`, inspect the pending migration list and confirm that the linked reference is not `txxokpovdbvsvnkpbrrp`. Hosted commands require approved credentials entered interactively or through an approved secret channel; they must not be committed.

## Migration immutability and rollback

Before a migration is applied to any hosted environment, it may be corrected on its feature branch while CI verifies it from an empty local database. After the migration is applied to a hosted environment, do not edit, reorder, rename, squash, or delete that migration file.

Later corrections must use a new forward migration. Rollback also uses a reviewed forward migration that safely restores behavior or compatibility. It must not automatically drop customer tables, delete real orders, remove uploaded proofs, or erase Auth users. Destructive recovery requires a separate data-retention plan, verified backup, explicit approval, and a tested restore path.
