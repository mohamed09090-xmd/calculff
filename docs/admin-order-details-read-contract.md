# Admin order details and timeline read contract

## Scope

This contract adds two administrator-only, read-only RPCs:

- `public.admin_get_order_details(p_order_id uuid)`
- `public.admin_get_order_timeline(p_order_id uuid)`

Both functions are `STABLE`, `SECURITY INVOKER`, use an empty `search_path`, reject missing `auth.uid()`, and require the signed `app_metadata.role = admin` claim. They do not use `user_metadata`, dynamic SQL, or service-role access.

## Details projection

`admin_get_order_details` returns only the approved order snapshots, customer contact snapshots, player fields, sale price, reward quantity, payment/order states, public status message, lifecycle timestamps, and a derived `has_payment_proof` boolean.

It never returns:

- `user_id`
- `client_request_id`
- `payment_proof_path`
- `game_id`
- `offer_id`
- audit actor identifiers
- internal notes

A missing order returns an empty set. The RPC does not expose or download proof objects.

## Timeline projection

`admin_get_order_timeline` returns only:

- `event_type`
- `order_status`
- `payment_status`
- `public_message`
- `created_at`

Rows are ordered by `created_at ASC, id ASC`. The history row ID is used only as the deterministic tie-breaker and is not returned. The RPC never returns `order_id`, `changed_by`, an event ID, or internal notes. A missing order returns an empty set.

## Grants and authorization

`EXECUTE` is revoked from `PUBLIC` and `anon`, then granted only to `authenticated`. Each function independently verifies both authentication and the administrator claim before reading. Existing table grants and RLS remain unchanged and continue to apply because both functions use invoker rights.

## Migration and verification

Forward migration:

`20260718150000_admin_order_details_read_only.sql`

pgTAP suite:

`080_admin_order_details_read_only.test.sql`

The regression suite verifies exact projections, privacy exclusions, function security attributes, execution grants, authentication and administrator checks, rejection of `user_metadata`, nullable fields, missing-order behavior, deterministic timeline ordering, unchanged RLS policy counts, and absence of new mutation privileges.

The migration is repository-only. It must not be applied to a hosted Supabase project without a separate approved deployment task.
