begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_catalog;

select plan(49);

select ok(
  to_regprocedure('public.admin_get_order_details(uuid)') is not null,
  'admin_get_order_details has the approved signature'
);
select is(
  (select proargnames[1:1] from pg_proc where oid = to_regprocedure('public.admin_get_order_details(uuid)')),
  array['p_order_id']::text[],
  'details input parameter is named p_order_id'
);
select is(
  (select proargnames[2:26] from pg_proc where oid = to_regprocedure('public.admin_get_order_details(uuid)')),
  array[
    'id',
    'game_name_ar_snapshot',
    'game_name_fr_snapshot',
    'offer_name_ar_snapshot',
    'offer_name_fr_snapshot',
    'reward_unit_code_snapshot',
    'reward_unit_name_ar_snapshot',
    'reward_unit_name_fr_snapshot',
    'customer_name_snapshot',
    'customer_email_snapshot',
    'customer_phone_snapshot',
    'player_id',
    'in_game_name',
    'sale_price_dzd_snapshot',
    'reward_quantity_snapshot',
    'payment_method',
    'order_status',
    'payment_status',
    'public_status_message',
    'created_at',
    'updated_at',
    'completed_at',
    'refund_started_at',
    'refunded_at',
    'has_payment_proof'
  ]::text[],
  'details result projection is exact and ordered'
);
select ok(
  not ((select proargnames from pg_proc where oid = to_regprocedure('public.admin_get_order_details(uuid)'))
    && array['user_id','client_request_id','payment_proof_path','game_id','offer_id','changed_by','order_id','internal_notes']::text[]),
  'details contract excludes forbidden identifiers and proof path'
);
select is(
  (select provolatile::text from pg_proc where oid = to_regprocedure('public.admin_get_order_details(uuid)')),
  's',
  'admin_get_order_details is STABLE'
);
select ok(
  not (select prosecdef from pg_proc where oid = to_regprocedure('public.admin_get_order_details(uuid)')),
  'admin_get_order_details is SECURITY INVOKER'
);
select is(
  (select proconfig from pg_proc where oid = to_regprocedure('public.admin_get_order_details(uuid)')),
  array['search_path=""']::text[],
  'admin_get_order_details has an empty search_path'
);
select ok(
  position('user_metadata' in lower(pg_get_functiondef(to_regprocedure('public.admin_get_order_details(uuid)')))) = 0,
  'details function never trusts user_metadata'
);
select ok(
  position('execute ' in lower(pg_get_functiondef(to_regprocedure('public.admin_get_order_details(uuid)')))) = 0,
  'details function contains no dynamic SQL'
);
select ok(
  position('private.order_internal_notes' in lower(pg_get_functiondef(to_regprocedure('public.admin_get_order_details(uuid)')))) = 0,
  'details function never reads internal notes'
);

select ok(
  to_regprocedure('public.admin_get_order_timeline(uuid)') is not null,
  'admin_get_order_timeline has the approved signature'
);
select is(
  (select proargnames[1:1] from pg_proc where oid = to_regprocedure('public.admin_get_order_timeline(uuid)')),
  array['p_order_id']::text[],
  'timeline input parameter is named p_order_id'
);
select is(
  (select proargnames[2:6] from pg_proc where oid = to_regprocedure('public.admin_get_order_timeline(uuid)')),
  array['event_type','order_status','payment_status','public_message','created_at']::text[],
  'timeline result projection is exact and ordered'
);
select ok(
  not ((select proargnames from pg_proc where oid = to_regprocedure('public.admin_get_order_timeline(uuid)'))
    && array['id','event_id','order_id','changed_by','internal_notes']::text[]),
  'timeline contract excludes event, order, actor, and note identifiers'
);
select is(
  (select provolatile::text from pg_proc where oid = to_regprocedure('public.admin_get_order_timeline(uuid)')),
  's',
  'admin_get_order_timeline is STABLE'
);
select ok(
  not (select prosecdef from pg_proc where oid = to_regprocedure('public.admin_get_order_timeline(uuid)')),
  'admin_get_order_timeline is SECURITY INVOKER'
);
select is(
  (select proconfig from pg_proc where oid = to_regprocedure('public.admin_get_order_timeline(uuid)')),
  array['search_path=""']::text[],
  'admin_get_order_timeline has an empty search_path'
);
select ok(
  position('user_metadata' in lower(pg_get_functiondef(to_regprocedure('public.admin_get_order_timeline(uuid)')))) = 0,
  'timeline function never trusts user_metadata'
);
select ok(
  position('execute ' in lower(pg_get_functiondef(to_regprocedure('public.admin_get_order_timeline(uuid)')))) = 0,
  'timeline function contains no dynamic SQL'
);
select ok(
  position('private.order_internal_notes' in lower(pg_get_functiondef(to_regprocedure('public.admin_get_order_timeline(uuid)')))) = 0,
  'timeline function never reads internal notes'
);
select ok(
  pg_get_functiondef(to_regprocedure('public.admin_get_order_timeline(uuid)'))
    ~* 'order by h\.created_at asc, h\.id asc',
  'timeline ordering uses created_at ascending then internal id ascending'
);

select ok(
  has_function_privilege('authenticated', 'public.admin_get_order_details(uuid)', 'EXECUTE'),
  'authenticated can execute details RPC'
);
select ok(
  not has_function_privilege('anon', 'public.admin_get_order_details(uuid)', 'EXECUTE'),
  'anon cannot execute details RPC'
);
select ok(
  not exists (
    select 1
    from pg_proc p
    cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
    where p.oid = to_regprocedure('public.admin_get_order_details(uuid)')
      and acl.grantee = 0::oid
      and acl.privilege_type = 'EXECUTE'
  ),
  'PUBLIC cannot execute details RPC'
);
select ok(
  has_function_privilege('authenticated', 'public.admin_get_order_timeline(uuid)', 'EXECUTE'),
  'authenticated can execute timeline RPC'
);
select ok(
  not has_function_privilege('anon', 'public.admin_get_order_timeline(uuid)', 'EXECUTE'),
  'anon cannot execute timeline RPC'
);
select ok(
  not exists (
    select 1
    from pg_proc p
    cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
    where p.oid = to_regprocedure('public.admin_get_order_timeline(uuid)')
      and acl.grantee = 0::oid
      and acl.privilege_type = 'EXECUTE'
  ),
  'PUBLIC cannot execute timeline RPC'
);

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('41111111-1111-4111-8111-111111111111', 'authenticated', 'authenticated', 'details-user@test.invalid', crypt('password-user', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('43333333-3333-4333-8333-333333333333', 'authenticated', 'authenticated', 'details-admin@test.invalid', crypt('password-admin', gen_salt('bf')), now(), '{"provider":"email","providers":["email"],"role":"admin"}', '{}', now(), now());

insert into public.games (
  id, slug, name_ar, name_fr, reward_unit_code,
  reward_unit_name_ar, reward_unit_name_fr, is_active, sort_order
) values (
  '4aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'details-read-game', 'لعبة التفاصيل', 'Jeu détails',
  'diamonds', 'جواهر', 'Diamants', true, 40
);

insert into public.public_offers (
  id, game_id, name_ar, name_fr, reward_quantity,
  sale_price_dzd, is_published, sort_order
) values (
  '4bbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1', '4aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
  'عرض التفاصيل', 'Offre détails', 520, 1300, true, 40
);

insert into public.orders (
  id, user_id, client_request_id, game_id, offer_id,
  player_id, in_game_name, payment_method, order_status, payment_status,
  payment_proof_path, public_status_message,
  game_name_ar_snapshot, game_name_fr_snapshot,
  reward_unit_code_snapshot, reward_unit_name_ar_snapshot, reward_unit_name_fr_snapshot,
  offer_name_ar_snapshot, offer_name_fr_snapshot,
  reward_quantity_snapshot, sale_price_dzd_snapshot,
  customer_name_snapshot, customer_email_snapshot, customer_phone_snapshot,
  created_at, updated_at, completed_at, refund_started_at, refunded_at
) values (
  '40000000-0000-4000-8000-000000000041',
  '41111111-1111-4111-8111-111111111111',
  '49000000-0000-4000-8000-000000000041',
  '4aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
  '4bbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1',
  'PLAYER-DETAILS', null, 'transfer', 'processing', 'under_review',
  '41111111-1111-4111-8111-111111111111/40000000-0000-4000-8000-000000000041/proof.pdf',
  null,
  'لعبة التفاصيل', 'Jeu détails', 'diamonds', 'جواهر', 'Diamants',
  'عرض التفاصيل', 'Offre détails', 520, 1300,
  'Details Customer', 'details-customer@test.invalid', '0550000041',
  '2026-07-18T12:00:00Z', '2026-07-18T12:30:00Z', null, null, null
);

delete from public.order_status_history
where order_id = '40000000-0000-4000-8000-000000000041';

insert into public.order_status_history (
  order_id, event_type, order_status, payment_status, public_message, changed_by, created_at
) values
  ('40000000-0000-4000-8000-000000000041', 'created', 'new', 'awaiting_payment', null, null, '2026-07-18T12:00:00Z'),
  ('40000000-0000-4000-8000-000000000041', 'payment_changed', 'accepted', 'under_review', 'Payment under review', '43333333-3333-4333-8333-333333333333', '2026-07-18T12:10:00Z'),
  ('40000000-0000-4000-8000-000000000041', 'order_changed', 'processing', 'under_review', null, '43333333-3333-4333-8333-333333333333', '2026-07-18T12:10:00Z');

select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select throws_ok(
  $$select * from public.admin_get_order_details('40000000-0000-4000-8000-000000000041')$$,
  '42501',
  null,
  'anonymous callers cannot execute details RPC'
);
reset role;

select set_config('request.jwt.claim.sub', '41111111-1111-4111-8111-111111111111', true);
select set_config('request.jwt.claims', '{"sub":"41111111-1111-4111-8111-111111111111","role":"authenticated","app_metadata":{},"user_metadata":{}}', true);
set local role authenticated;
select throws_ok(
  $$select * from public.admin_get_order_details('40000000-0000-4000-8000-000000000041')$$,
  '42501',
  'admin access required',
  'ordinary authenticated users are rejected by details RPC'
);
select throws_ok(
  $$select * from public.admin_get_order_timeline('40000000-0000-4000-8000-000000000041')$$,
  '42501',
  'admin access required',
  'ordinary authenticated users are rejected by timeline RPC'
);
reset role;

select set_config('request.jwt.claim.sub', '41111111-1111-4111-8111-111111111111', true);
select set_config('request.jwt.claims', '{"sub":"41111111-1111-4111-8111-111111111111","role":"authenticated","app_metadata":{},"user_metadata":{"role":"admin"}}', true);
set local role authenticated;
select throws_ok(
  $$select * from public.admin_get_order_details('40000000-0000-4000-8000-000000000041')$$,
  '42501',
  'admin access required',
  'details RPC ignores an admin value in user_metadata'
);
select throws_ok(
  $$select * from public.admin_get_order_timeline('40000000-0000-4000-8000-000000000041')$$,
  '42501',
  'admin access required',
  'timeline RPC ignores an admin value in user_metadata'
);
reset role;

select set_config('request.jwt.claim.sub', '43333333-3333-4333-8333-333333333333', true);
select set_config('request.jwt.claims', '{"sub":"43333333-3333-4333-8333-333333333333","role":"authenticated","app_metadata":{"role":"admin"},"user_metadata":{}}', true);
set local role authenticated;

select lives_ok(
  $$select * from public.admin_get_order_details('40000000-0000-4000-8000-000000000041')$$,
  'authenticated app_metadata administrator can read details'
);
select is(
  (select count(*)::integer from public.admin_get_order_details('40000000-0000-4000-8000-000000000041')),
  1,
  'details RPC returns exactly one matching order'
);
select ok(
  (select not (to_jsonb(r) ?| array['user_id','client_request_id','payment_proof_path','game_id','offer_id','changed_by','order_id','internal_notes'])
   from public.admin_get_order_details('40000000-0000-4000-8000-000000000041') as r),
  'details runtime response contains no forbidden keys'
);
select is(
  (select has_payment_proof from public.admin_get_order_details('40000000-0000-4000-8000-000000000041')),
  true,
  'details exposes proof presence only as a boolean'
);
select ok(
  (select in_game_name is null and public_status_message is null and completed_at is null
          and refund_started_at is null and refunded_at is null
   from public.admin_get_order_details('40000000-0000-4000-8000-000000000041')),
  'details preserves every approved nullable field'
);
select is(
  (select count(*)::integer from public.admin_get_order_details('40000000-0000-4000-8000-000000000099')),
  0,
  'details returns an empty set for an unknown order'
);
select lives_ok(
  $$select * from public.admin_get_order_timeline('40000000-0000-4000-8000-000000000041')$$,
  'authenticated app_metadata administrator can read timeline'
);
select results_eq(
  $$select event_type::text from public.admin_get_order_timeline('40000000-0000-4000-8000-000000000041')$$,
  $$values ('created'::text), ('payment_changed'::text), ('order_changed'::text)$$,
  'timeline orders equal timestamps by internal event id ascending'
);
select ok(
  (select bool_and(not (to_jsonb(r) ?| array['id','event_id','order_id','changed_by','internal_notes']))
   from public.admin_get_order_timeline('40000000-0000-4000-8000-000000000041') as r),
  'timeline runtime response contains no forbidden keys'
);
select is(
  (select public_message from public.admin_get_order_timeline('40000000-0000-4000-8000-000000000041') limit 1),
  null,
  'timeline preserves a nullable public message'
);
select is(
  (select count(*)::integer from public.admin_get_order_timeline('40000000-0000-4000-8000-000000000099')),
  0,
  'timeline returns an empty set for an unknown order'
);
reset role;

select is(
  (select count(*)::integer from pg_policies where schemaname = 'public' and tablename = 'orders'),
  1,
  'details migration does not change orders RLS policy count'
);
select is(
  (select count(*)::integer from pg_policies where schemaname = 'public' and tablename = 'order_status_history'),
  1,
  'details migration does not change timeline RLS policy count'
);
select ok(
  not has_table_privilege('authenticated', 'public.orders', 'INSERT,UPDATE,DELETE'),
  'details migration adds no authenticated order mutation privilege'
);
select ok(
  not has_table_privilege('authenticated', 'public.order_status_history', 'INSERT,UPDATE,DELETE'),
  'details migration adds no authenticated history mutation privilege'
);
select ok(
  pg_get_functiondef(to_regprocedure('public.admin_get_order_details(uuid)'))
    !~* '\m(game_id|offer_id|user_id|client_request_id)\M',
  'details function body does not select forbidden identifier columns'
);
select ok(
  pg_get_functiondef(to_regprocedure('public.admin_get_order_timeline(uuid)'))
    !~* '\m(changed_by|internal_notes)\M',
  'timeline function body does not select actor IDs or internal notes'
);

select * from finish();
rollback;
