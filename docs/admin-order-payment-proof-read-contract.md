# Administrator payment-proof read contract

## Scope

The administrator order-details screen needs a narrowly scoped way to locate the private payment proof attached to one transfer order. The database contract returns only the validated Storage object path. That path is a sensitive infrastructure locator because its folders contain user and order UUIDs; it must not cross into the domain or presentation model. The RPC does not return separate customer or order fields, Storage ownership or metadata, a public URL, or a signed URL.

## RPC

`public.admin_get_order_payment_proof_path(p_order_id uuid)` returns a table with one result-set column:

- `payment_proof_path text`

The function returns either one row or zero rows. Zero rows cover an unknown order, a null proof, a missing object, a non-transfer order, an owner mismatch, an invalid folder structure, an invalid filename, or a null order identifier.

## Authorization and validation

The RPC is `STABLE`, `SECURITY INVOKER`, and uses an empty `search_path`. `PUBLIC` and `anon` execution are revoked; `authenticated` may execute it. The body still requires both `auth.uid()` and the signed `auth.jwt() -> 'app_metadata' ->> 'role' = 'admin'` claim. Values in `user_metadata` are ignored.

Because it runs with invoker rights, the existing administrator policy on `public.orders` and administrator select policy on the private `payment-proofs` bucket remain active. A result is returned only when all of the following are true:

- the requested order exists and uses transfer payment;
- `orders.payment_proof_path` is non-null and points to an existing object in the fixed `payment-proofs` bucket;
- the Storage object's owner matches the order owner;
- the path has exactly the existing user UUID and order UUID folders;
- the path contains no traversal marker, is at most 512 characters, and matches the existing image/PDF filename allowlist.

## Client handling

The future Flutter data-source layer must keep the object path in memory only long enough to request an authenticated download or a short-lived signed URL from the fixed private bucket. Neither value may enter domain or presentation models, Semantics, persistent state, logs, analytics, or error reports. The viewer must validate the download response as JPEG, PNG, or PDF and enforce the 5 MiB limit instead of trusting the filename alone. Signed URLs should use a short expiry such as 60 seconds and should be discarded when the screen or administrator session ends.

## Migration and verification

Forward migration:

`20260723021628_admin_get_order_payment_proof_read_only.sql`

pgTAP suite:

`090_admin_order_payment_proof_read_only.test.sql`

The suite contains 47 assertions covering the exact signature, output type, and projection; function security attributes; execution grants; signed-claim authorization; privacy exclusions; valid isolation across orders; missing and malformed cases; owner and folder mismatches; transfer-only behavior; traversal and length enforcement; caller search-path resistance; and unchanged RLS policy counts.

This migration is repository-only until separately approved for the hosted Supabase project. It changes no data, RLS policy, Storage policy, bucket, table grant, mutation RPC, or client application.
