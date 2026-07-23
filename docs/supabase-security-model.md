# CalculFF Supabase security model

## Scope and threat model

This backend receives authenticated customer orders, public catalog data, private payment proofs, and administrator workflow updates. The primary threats are broken object-level authorization, privilege escalation through mutable JWT metadata, direct table writes that bypass workflow invariants, duplicate orders caused by retries, tampering with commercial snapshots, exposure of internal notes or actor identifiers, Storage path abuse, MIME or size bypass, and accidental credential publication.

The design assumes the publishable key and project URL are public. Security depends on PostgreSQL grants, Row Level Security, narrow RPCs, server-side state machines, trusted `app_metadata`, private Storage, and local integration tests. No service-role credential belongs in Flutter or the repository.

## Data separation

Customer-visible data and internal operational data are separated structurally:

- `public.profiles`: the authenticated user's profile and authoritative Auth email mirror.
- `public.games`: public game metadata and reward-unit definitions.
- `public.public_offers`: customer-facing offer names, quantities, and sale prices. It contains no cost, profit, stock, or inventory columns.
- `public.orders`: customer orders, immutable commercial/customer snapshots, workflow states, and the attached proof path.
- `public.order_status_history`: public-safe timeline events plus an internal `changed_by` column that is never returned to customers.
- `private.order_internal_notes`: administrator-only notes in a non-exposed schema with no direct client grants.
- `storage.objects` in bucket `payment-proofs`: private proof objects owned by the authenticated uploader.

`device_tokens` is intentionally absent. Push notification tokens and Firebase/FCM integration are deferred to the dedicated notification phase.

## Domain types and state machines

| Type | Values |
| --- | --- |
| `order_status_type` | `new`, `accepted`, `processing`, `completed`, `rejected`, `cancelled` |
| `payment_status_type` | `awaiting_payment`, `under_review`, `paid`, `proof_rejected`, `refund_pending`, `refunded` |
| `payment_method_type` | `cash`, `transfer` |
| `status_event_type` | `created`, `order_changed`, `payment_changed`, `proof_attached`, `refund_started`, `refunded` |

Order and payment transitions are enforced inside administrator RPCs. Direct `UPDATE` on `orders` is not granted. Completion requires `paid`. Rejecting or cancelling a paid order atomically moves payment to `refund_pending`; only `admin_mark_refunded` can finish that refund. Transfer payments require an attached, validated proof before review or payment approval. Cash payments cannot enter proof review.

## Reward unit model

A game defines one reward-unit code plus Arabic and French names, for example `diamonds`, `جواهر`, and `Diamants`. Each public offer references one game and supplies a positive reward quantity and positive DZD sale price. The order does not depend on mutable catalog rows after creation because it stores the game, offer, reward-unit, quantity, sale-price, and customer snapshots used at the transaction boundary.

## Snapshots and audit integrity

`create_order` reads the active game, published offer, confirmed Auth email, and complete profile inside the database. It writes authoritative snapshots rather than accepting price, quantity, customer identity, or localized catalog text from the client. Later edits to games, offers, profiles, or Auth email do not rewrite historical orders.

The customer timeline is read through `get_my_order_timeline`. Its projection excludes `changed_by` and every internal note. Administrators access internal notes only through dedicated RPCs.

## Idempotency

Customers provide a UUID `client_request_id`. The database enforces `UNIQUE (user_id, client_request_id)`. A retry with the same normalized payload returns the existing order; reuse with a different offer, player, in-game name, or payment method fails. The first history row is written exactly once.

## Administrator order-list RPC

`public.admin_list_orders` is a read-only, `STABLE`, `SECURITY INVOKER` function. It requires an authenticated user and the signed `app_metadata.role = admin` claim before reading through the existing `orders_select_own_or_admin` RLS policy. Invoker mode is intentional: the caller already has the existing table `SELECT` grant and the function does not require privilege escalation or access to a private schema.

The function uses an empty `search_path`, schema-qualified relations, typed enum and UUID filters, and no dynamic SQL. Search text is bounded to 100 characters, rejects control characters, and escapes `LIKE` metacharacters before matching the compact eight-character order number, customer name, Player ID, or in-game name.

Pagination is keyset-based and ordered by `created_at DESC, id DESC`. The composite cursor requires both values, so UUID ordering remains the deterministic tie-breaker when several orders share the same timestamp. Page size is restricted to 1 through 25, and one extra candidate is inspected only to calculate `has_more`.

The list projection contains only the fields required by the administrator list. It never returns customer email, customer phone, `user_id`, `client_request_id`, `payment_proof_path`, or `changed_by`. Proof presence is converted inside PostgreSQL to the boolean `has_payment_proof`; the Storage path never leaves the database through this RPC. The function does not access or alter Storage objects or policies.

The migration adds `orders_created_at_id_desc_idx (created_at DESC, id DESC)` for deterministic cursor scans. It does not modify RLS policies, table grants, enums, Storage, or order rows.

## RLS matrix

All five platform tables in the exposed `public` schema have RLS enabled. `private.order_internal_notes` also has RLS enabled as defense in depth even though client roles have neither schema usage nor table grants.

| Object | Anonymous | Authenticated customer | Authenticated admin |
| --- | --- | --- | --- |
| `profiles` | No access | Select own row; update only own `full_name`, `phone`, `locale` | Select all rows; no unrestricted direct profile write |
| `games` | No access | Select active games | Select all; insert/update/delete through admin RLS policies and column grants |
| `public_offers` | No access | Select published offers whose game is active | Select all; insert/update/delete through admin RLS policies and column grants |
| `orders` | No access | Select own orders | Select all orders |
| `order_status_history` | No access | No direct rows; use owner-safe timeline RPC | Select full history rows |
| `private.order_internal_notes` | No access | No access | No direct access; use admin RPCs |
| `storage.objects` in `payment-proofs` | No access | Insert into an owned eligible order path; select only an object already attached to an owned order | Select proof objects; no direct insert/update/delete privilege added by this migration |

The administrator check reads only `auth.jwt() -> 'app_metadata' ->> 'role'`. `user_metadata` is not trusted. Because JWT claims can remain stale, a role change requires sign-out/sign-in or token refresh.

## Grants matrix

The migration first revokes broad defaults and then grants only the required capabilities.

| Object | `anon` | `authenticated` |
| --- | --- | --- |
| Enum types | None | `USAGE` |
| `profiles` | None | `SELECT`; `UPDATE (full_name, phone, locale)` |
| `games` | None | `SELECT`, `DELETE`; column-scoped `INSERT` and `UPDATE` excluding IDs/timestamps |
| `public_offers` | None | `SELECT`, `DELETE`; column-scoped `INSERT` and `UPDATE` excluding IDs/timestamps |
| `orders` | None | `SELECT` only |
| `order_status_history` | None | `SELECT` only, filtered by admin RLS |
| `private.order_internal_notes` and its sequence | None | None |
| `public.create_order` | None | `EXECUTE` |
| `public.get_my_order_timeline` | None | `EXECUTE` |
| `public.admin_list_orders` | None | `EXECUTE`, followed by in-function admin authorization and existing RLS |
| `public.admin_add_order_internal_note` | None | `EXECUTE`, followed by in-function admin authorization |
| `public.admin_list_order_internal_notes` | None | `EXECUTE`, followed by in-function admin authorization |
| `public.admin_get_order_payment_proof_path` | None | `EXECUTE`, followed by in-function admin authorization and existing RLS |
| `public.admin_set_order_status` | None | `EXECUTE`, followed by in-function admin authorization |
| `public.admin_set_payment_status` | None | `EXECUTE`, followed by in-function admin authorization |
| `public.admin_mark_refunded` | None | `EXECUTE`, followed by in-function admin authorization |
| `public.attach_payment_proof` | None | `EXECUTE`, followed by ownership and object validation |
| Every function in `private` | None | None |

No public `EXECUTE` is intentionally retained for privileged functions. The pgTAP suite verifies grants, RLS policies, function security mode, and absence of broad direct order mutation privileges.

## Storage ownership and path contract

The `payment-proofs` bucket is private. Its limit is exactly 5 MiB and its MIME allowlist is exactly:

- `image/jpeg`
- `image/png`
- `application/pdf`

The object path must be:

```text
<auth.uid()>/<order_uuid>/<random_file_name>.(jpg|jpeg|png|pdf)
```

The insert policy requires the object's `owner_id` and first path segment to equal `auth.uid()`. The second segment must be an owned transfer order that is non-final and currently accepts a new proof. The filename requires a randomized, restricted character set. Traversal sequences are rejected.

The migration defines no Storage `UPDATE` or `DELETE` policy. Therefore client upsert, replacement, rename, and deletion are denied. Upload is insert-only. Selection is allowed to the owner only after the object path is bound to that owner's order, or to an authenticated administrator. `attach_payment_proof` independently validates bucket membership, path shape, object ownership, MIME metadata, size metadata, order ownership, payment method, and workflow state before writing the proof path to the order.

## Public timeline and private notes

`order_status_history.changed_by` exists for administrative audit but is not exposed by the customer timeline RPC. `get_my_order_timeline` returns only event type, order status, payment status, public message, and timestamp after an ownership check.

Internal notes are stored only in `private.order_internal_notes`. They never share the public message column, never appear in customer timeline results, and have no direct `anon` or `authenticated` table grant. Administrator note RPCs require the signed `app_metadata.role = admin` claim. The private table has defensive RLS enabled without customer policies; the administrator RPCs continue to operate under their audited definer rights.

## SECURITY DEFINER inventory

The platform schema creates the following ten application `SECURITY DEFINER` functions. This list must stay synchronized with `pg_proc`; the pgTAP suites protect the inventory and execution grants.

| Function | Why definer rights are required | Primary regression protection |
| --- | --- | --- |
| `private.handle_auth_user_created` | Trusted `auth.users` trigger creates the matching profile while clients have no profile `INSERT`. It verifies trigger operation, schema, and table. | `010_schema.test.sql`, `020_grants_rls.test.sql`, and Auth-user setup exercised by order tests |
| `private.handle_auth_user_email_changed` | Trusted Auth trigger synchronizes the authoritative email while customer updates cannot change `profiles.email`. It verifies trigger context. | `010_schema.test.sql`, `020_grants_rls.test.sql`, and profile/Auth behavior in `030_orders.test.sql` |
| `public.create_order` | Reads trusted Auth data and atomically inserts an order plus initial history without direct customer `INSERT` grants. | `030_orders.test.sql` covers authentication, confirmation, completeness, snapshots, idempotency, ownership, and input rejection |
| `public.get_my_order_timeline` | Reads history through an owner-checked, public-safe projection without granting customers direct history access. | `030_orders.test.sql` and `040_admin_transitions.test.sql` cover anonymous/foreign rejection and safe projection |
| `public.admin_add_order_internal_note` | Performs a controlled write to the private notes table after admin authorization. | `040_admin_transitions.test.sql` and `060_security_hardening.test.sql` cover non-admin rejection, defensive RLS, and admin-only note creation |
| `public.admin_list_order_internal_notes` | Performs a controlled read from the private schema after admin authorization. | `040_admin_transitions.test.sql` and `060_security_hardening.test.sql` cover visibility separation and admin-only reads |
| `public.admin_set_order_status` | Enforces finite order transitions, history writes, optional note creation, and atomic refund-pending conversion without direct order update grants. | `040_admin_transitions.test.sql` covers valid/invalid transitions, final states, history, notes, and refund initiation |
| `public.admin_set_payment_status` | Enforces finite payment transitions and proof requirements while writing order state and history atomically. | `040_admin_transitions.test.sql` covers cash/transfer rules, proof checks, valid/invalid transitions, and final-state protection |
| `public.admin_mark_refunded` | Finalizes only `refund_pending` orders and writes public/internal audit records atomically. | `040_admin_transitions.test.sql` covers unauthorized calls, invalid source states, refund completion, timestamps, and history |
| `public.attach_payment_proof` | Binds an existing private Storage object to an owned eligible transfer order after validating metadata and state, without direct order update rights. | `050_storage_policies.test.sql` and the 25-case Storage REST API suite cover path, owner, bucket, MIME, size, duplicate, state, and HTTP policy behavior |

Every application definer function uses `set search_path = ''`, explicitly schema-qualifies objects, validates `auth.uid()` or trusted trigger context, and has public/anonymous execution revoked. The private trigger functions also have authenticated execution revoked.

The hosted database also contains the platform-managed `public.rls_auto_enable()` event-trigger helper. It remains `SECURITY DEFINER` because the platform event trigger uses it to enable RLS automatically, but direct `EXECUTE` is revoked from `PUBLIC`, `anon`, and `authenticated`. The event trigger itself is not removed or altered.

## Important SECURITY INVOKER functions

- `private.is_admin`: reads the signed `app_metadata.role` claim under caller rights. It has no client execution grant and is used only by privileged RPCs.
- `private.set_updated_at`: trigger helper that updates only `updated_at` under the invoking table operation. It has no client execution grant.
- `public.admin_list_orders`: reads only the administrator list projection under caller rights and existing `orders` RLS. It checks `auth.uid()` and signed `app_metadata`, has an empty `search_path`, exposes no proof path or customer contact fields, and uses no dynamic SQL.

Invoker mode remains the default preference. Definer mode is limited to the audited cases above where direct grants would expose broader data or mutation capabilities.

## Hosted advisor hardening follow-up

The applied migration `20260715192117_secure_platform_schema.sql` is immutable. Advisor remediation is implemented only by the forward migration `20260716163910_harden_platform_security_and_rls.sql`.

That forward migration:

- revokes direct client execution of `public.rls_auto_enable()` while preserving the platform event trigger;
- enables defensive RLS on `private.order_internal_notes` without adding policies or direct grants;
- recreates the eleven advisor-identified public policies under their existing names and identical ownership/admin predicates;
- wraps `auth.jwt()` and `auth.uid()` calls as scalar initialization subqueries so PostgreSQL can evaluate them once per statement rather than once per candidate row;
- adds `private.order_internal_notes(author_user_id)` and `public.order_status_history(changed_by)` indexes with `CREATE INDEX IF NOT EXISTS`;
- leaves existing indexes in place even when a new, empty database reports them as unused.

The Security Advisor warnings for authenticated execution of application `SECURITY DEFINER` RPCs are intentional. Customers must call `create_order`, `get_my_order_timeline`, and `attach_payment_proof`; administrator clients must call the admin workflow RPCs. Anonymous execution remains revoked, every function has an empty `search_path`, customer functions verify `auth.uid()` and ownership, and administrator functions verify signed `app_metadata.role = admin`. Regression tests verify both the grants and rejection paths instead of disabling required functionality to silence the Advisor.

`admin_list_orders` is not part of that definer inventory. It is intentionally `SECURITY INVOKER`, so the existing administrator RLS policy remains an authorization boundary rather than being bypassed by the function owner.

`admin_get_order_payment_proof_path` is also outside the definer inventory. It is intentionally `SECURITY INVOKER`, so both the administrator order policy and the private Storage select policy remain active authorization boundaries.

`Leaked Password Protection Disabled` is an Auth configuration warning, not a SQL migration concern. Enabling it is deferred to the dedicated Auth setup step in the Supabase Dashboard or supported Auth configuration workflow. No Auth setting is changed by this migration.

## Read-only order-list forward migration

`20260718030259_admin_list_orders_read_only.sql` adds only the deterministic cursor index and `public.admin_list_orders`. Its pgTAP coverage is isolated in `070_admin_list_orders.test.sql` and covers the function contract, execution grants, privacy projection, authentication and admin-claim checks, filters, literal parameterized search, cursor correctness, page limits, and RLS/table-grant regressions.

The migration is designed for local validation before any hosted application. It contains no project reference, remote command, data mutation, RLS change, table-grant change, enum change, or Storage change. Applying it to a hosted project remains a separately approved operation.

## Read-only payment-proof path forward migration

`20260723021628_admin_get_order_payment_proof_read_only.sql` adds only `public.admin_get_order_payment_proof_path`. The function returns one validated private object path or zero rows. The path is a sensitive infrastructure locator that contains user and order UUIDs; it must never reach presentation, Semantics, logs, analytics, or persistent client state. The RPC never returns separate order data, object ownership, Storage metadata, or a signed URL. The linked object must exist in the fixed private bucket, match the order owner, use the order owner's and order's UUID folders, match the existing filename allowlist, and belong to a transfer order.

The function is `STABLE`, `SECURITY INVOKER`, has an empty `search_path`, trusts only the signed administrator claim in `app_metadata`, and is executable only by `authenticated`. Its isolated pgTAP suite verifies the exact one-column projection, grants, RLS-preserving execution mode, object linkage, path validation, caller search-path resistance, and unchanged order and Storage policy counts. Hosted application remains a separate approval gate.

## Migration immutability and operational controls

The original migration is already applied to the hosted project and must never be edited, renamed, or deleted. Every correction uses a new forward migration; rollback is another reviewed forward migration and must preserve real customer data unless a separately approved destructive recovery plan exists. The repository validator pins the original migration's Git blob SHA so accidental edits fail CI.

The repository and Flutter application must never contain a service-role key, Supabase secret key, database password, JWT secret, SMTP credential, Firebase credential, private key, or keystore. Flutter may later receive only the project URL and publishable key. No hosted project, including the forbidden legacy reference, is used by CI.
