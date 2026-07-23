begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_catalog;

select plan(47);

select ok(
  to_regprocedure('public.admin_get_order_payment_proof_path(uuid)') is not null,
  'admin_get_order_payment_proof_path has the approved signature'
);
select is(
  (select proargnames[1:1] from pg_proc where oid = to_regprocedure('public.admin_get_order_payment_proof_path(uuid)')),
  array['p_order_id']::text[],
  'proof input parameter is named p_order_id'
);
select is(
  (select proargnames[2:2] from pg_proc where oid = to_regprocedure('public.admin_get_order_payment_proof_path(uuid)')),
  array['payment_proof_path']::text[],
  'proof result projection contains only the payment proof path'
);
select is(
  pg_get_function_result(to_regprocedure('public.admin_get_order_payment_proof_path(uuid)')),
  'TABLE(payment_proof_path text)',
  'proof result field has the exact text type'
);
select is(
  (select pronargdefaults::integer from pg_proc where oid = to_regprocedure('public.admin_get_order_payment_proof_path(uuid)')),
  0,
  'proof function has no optional arguments'
);
select ok(
  (select proretset from pg_proc where oid = to_regprocedure('public.admin_get_order_payment_proof_path(uuid)')),
  'proof function returns a set so absent proofs are represented by zero rows'
);
select is(
  (select provolatile::text from pg_proc where oid = to_regprocedure('public.admin_get_order_payment_proof_path(uuid)')),
  's',
  'proof function is STABLE'
);
select ok(
  not (select prosecdef from pg_proc where oid = to_regprocedure('public.admin_get_order_payment_proof_path(uuid)')),
  'proof function is SECURITY INVOKER'
);
select is(
  (select proconfig from pg_proc where oid = to_regprocedure('public.admin_get_order_payment_proof_path(uuid)')),
  array['search_path=""']::text[],
  'proof function has an empty search_path'
);
select ok(
  position('user_metadata' in lower(pg_get_functiondef(to_regprocedure('public.admin_get_order_payment_proof_path(uuid)')))) = 0,
  'proof function never trusts user_metadata'
);
select ok(
  position('execute ' in lower(pg_get_functiondef(to_regprocedure('public.admin_get_order_payment_proof_path(uuid)')))) = 0,
  'proof function contains no dynamic SQL'
);
select ok(
  lower(pg_get_functiondef(to_regprocedure('public.admin_get_order_payment_proof_path(uuid)')))
    !~ '(insert into|update public|delete from|upsert|storage\.create)',
  'proof function contains no mutation path'
);
select ok(
  pg_get_functiondef(to_regprocedure('public.admin_get_order_payment_proof_path(uuid)'))
    ~* 'obj\.bucket_id = ''payment-proofs''.*obj\.name = o\.payment_proof_path',
  'proof function joins only the linked private bucket object'
);
select ok(
  pg_get_functiondef(to_regprocedure('public.admin_get_order_payment_proof_path(uuid)'))
    ~* 'obj\.owner_id = o\.user_id::text',
  'proof function requires the Storage owner to match the order owner'
);
select ok(
  pg_get_functiondef(to_regprocedure('public.admin_get_order_payment_proof_path(uuid)'))
    ~* 'o\.payment_method = ''transfer''',
  'proof function accepts transfer orders only'
);
select ok(
  pg_get_functiondef(to_regprocedure('public.admin_get_order_payment_proof_path(uuid)'))
    ~* 'storage\.foldername\(o\.payment_proof_path\).*o\.user_id::text',
  'proof function validates the user folder'
);
select ok(
  pg_get_functiondef(to_regprocedure('public.admin_get_order_payment_proof_path(uuid)'))
    ~* 'storage\.foldername\(o\.payment_proof_path\).*o\.id::text',
  'proof function validates the order folder'
);
select ok(
  pg_get_functiondef(to_regprocedure('public.admin_get_order_payment_proof_path(uuid)'))
    ~* 'storage\.filename\(o\.payment_proof_path\)',
  'proof function validates the proof filename'
);
select ok(
  pg_get_functiondef(to_regprocedure('public.admin_get_order_payment_proof_path(uuid)'))
    ~* 'length\(o\.payment_proof_path\) between 10 and 512',
  'proof function enforces the bounded path length'
);
select ok(
  pg_get_functiondef(to_regprocedure('public.admin_get_order_payment_proof_path(uuid)'))
    ~* 'position\(''\.\.'' in o\.payment_proof_path\) = 0',
  'proof function rejects traversal markers'
);
select ok(
  has_function_privilege('authenticated', 'public.admin_get_order_payment_proof_path(uuid)', 'EXECUTE'),
  'authenticated can execute the proof RPC'
);
select ok(
  not has_function_privilege('anon', 'public.admin_get_order_payment_proof_path(uuid)', 'EXECUTE'),
  'anon cannot execute the proof RPC'
);
select ok(
  not exists (
    select 1
    from pg_proc p
    cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
    where p.oid = to_regprocedure('public.admin_get_order_payment_proof_path(uuid)')
      and acl.grantee = 0::oid
      and acl.privilege_type = 'EXECUTE'
  ),
  'PUBLIC has no proof RPC execute grant'
);

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('51111111-1111-4111-8111-111111111111', 'authenticated', 'authenticated', 'proof-a@test.invalid', crypt('password-a', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('52222222-2222-4222-8222-222222222222', 'authenticated', 'authenticated', 'proof-b@test.invalid', crypt('password-b', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('53333333-3333-4333-8333-333333333333', 'authenticated', 'authenticated', 'proof-admin@test.invalid', crypt('password-admin', gen_salt('bf')), now(), '{"provider":"email","providers":["email"],"role":"admin"}', '{}', now(), now());

update public.profiles set full_name = 'Proof A', phone = '0555000051' where id = '51111111-1111-4111-8111-111111111111';
update public.profiles set full_name = 'Proof B', phone = '0555000052' where id = '52222222-2222-4222-8222-222222222222';
update public.profiles set full_name = 'Proof Admin', phone = '0555000053' where id = '53333333-3333-4333-8333-333333333333';

insert into public.games (
  id, slug, name_ar, name_fr, reward_unit_code,
  reward_unit_name_ar, reward_unit_name_fr, is_active, sort_order
) values (
  '5aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'proof-read-game',
  'لعبة الإثبات', 'Jeu preuve', 'diamonds', 'جواهر', 'Diamants', true, 50
);

insert into public.public_offers (
  id, game_id, name_ar, name_fr, reward_quantity,
  sale_price_dzd, is_published, sort_order
) values (
  '5bbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1',
  '5aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
  'عرض الإثبات', 'Offre preuve', 530, 1400, true, 50
);

insert into public.orders (
  id, user_id, client_request_id, game_id, offer_id,
  player_id, payment_method, order_status, payment_status,
  payment_proof_path,
  game_name_ar_snapshot, game_name_fr_snapshot,
  reward_unit_code_snapshot, reward_unit_name_ar_snapshot, reward_unit_name_fr_snapshot,
  offer_name_ar_snapshot, offer_name_fr_snapshot,
  reward_quantity_snapshot, sale_price_dzd_snapshot,
  customer_name_snapshot, customer_email_snapshot, customer_phone_snapshot
) values
  (
    '50000000-0000-4000-8000-000000000051',
    '51111111-1111-4111-8111-111111111111',
    '59000000-0000-4000-8000-000000000051',
    '5aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
    '5bbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1',
    'PLAYER-PROOF-A', 'transfer', 'processing', 'under_review',
    '51111111-1111-4111-8111-111111111111/50000000-0000-4000-8000-000000000051/proof_aaaaaaaaaaaaaaaa.jpg',
    'لعبة الإثبات', 'Jeu preuve', 'diamonds', 'جواهر', 'Diamants',
    'عرض الإثبات', 'Offre preuve', 530, 1400,
    'Proof A', 'proof-a@test.invalid', '0555000051'
  ),
  (
    '50000000-0000-4000-8000-000000000052',
    '52222222-2222-4222-8222-222222222222',
    '59000000-0000-4000-8000-000000000052',
    '5aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
    '5bbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1',
    'PLAYER-PROOF-B', 'transfer', 'processing', 'under_review',
    '52222222-2222-4222-8222-222222222222/50000000-0000-4000-8000-000000000052/proof_bbbbbbbbbbbbbbbb.pdf',
    'لعبة الإثبات', 'Jeu preuve', 'diamonds', 'جواهر', 'Diamants',
    'عرض الإثبات', 'Offre preuve', 530, 1400,
    'Proof B', 'proof-b@test.invalid', '0555000052'
  ),
  (
    '50000000-0000-4000-8000-000000000053',
    '51111111-1111-4111-8111-111111111111',
    '59000000-0000-4000-8000-000000000053',
    '5aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
    '5bbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1',
    'PLAYER-NO-PROOF', 'cash', 'new', 'awaiting_payment', null,
    'لعبة الإثبات', 'Jeu preuve', 'diamonds', 'جواهر', 'Diamants',
    'عرض الإثبات', 'Offre preuve', 530, 1400,
    'Proof A', 'proof-a@test.invalid', '0555000051'
  ),
  (
    '50000000-0000-4000-8000-000000000054',
    '51111111-1111-4111-8111-111111111111',
    '59000000-0000-4000-8000-000000000054',
    '5aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
    '5bbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1',
    'PLAYER-MISSING-PROOF', 'transfer', 'processing', 'under_review',
    '51111111-1111-4111-8111-111111111111/50000000-0000-4000-8000-000000000054/missing_cccccccccccccc.png',
    'لعبة الإثبات', 'Jeu preuve', 'diamonds', 'جواهر', 'Diamants',
    'عرض الإثبات', 'Offre preuve', 530, 1400,
    'Proof A', 'proof-a@test.invalid', '0555000051'
  ),
  (
    '50000000-0000-4000-8000-000000000055',
    '51111111-1111-4111-8111-111111111111',
    '59000000-0000-4000-8000-000000000055',
    '5aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
    '5bbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1',
    'PLAYER-VALIDATION', 'transfer', 'processing', 'under_review',
    '51111111-1111-4111-8111-111111111111/50000000-0000-4000-8000-000000000055/proof_cccccccccccccccc.png',
    'لعبة الإثبات', 'Jeu preuve', 'diamonds', 'جواهر', 'Diamants',
    'عرض الإثبات', 'Offre preuve', 530, 1400,
    'Proof A', 'proof-a@test.invalid', '0555000051'
  );

insert into storage.objects (bucket_id, name, owner_id, metadata) values
  (
    'payment-proofs',
    '51111111-1111-4111-8111-111111111111/50000000-0000-4000-8000-000000000051/proof_aaaaaaaaaaaaaaaa.jpg',
    '51111111-1111-4111-8111-111111111111',
    '{"mimetype":"IMAGE/JPEG","size":100}'::jsonb
  ),
  (
    'payment-proofs',
    '52222222-2222-4222-8222-222222222222/50000000-0000-4000-8000-000000000052/proof_bbbbbbbbbbbbbbbb.pdf',
    '52222222-2222-4222-8222-222222222222',
    '{"mimetype":"application/pdf","size":200}'::jsonb
  ),
  (
    'payment-proofs',
    '51111111-1111-4111-8111-111111111111/50000000-0000-4000-8000-000000000055/proof_cccccccccccccccc.png',
    '51111111-1111-4111-8111-111111111111',
    '{"mimetype":"image/png","size":50}'::jsonb
  );

select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select throws_ok(
  $$select * from public.admin_get_order_payment_proof_path('50000000-0000-4000-8000-000000000051')$$,
  '42501',
  null,
  'anonymous callers cannot execute the proof RPC'
);
reset role;

select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claims', '{"role":"authenticated","app_metadata":{},"user_metadata":{}}', true);
set local role authenticated;
select throws_ok(
  $$select * from public.admin_get_order_payment_proof_path('50000000-0000-4000-8000-000000000051')$$,
  '42501',
  'admin access required',
  'an authenticated role without a user cannot read a proof'
);
reset role;

select set_config('request.jwt.claim.sub', '51111111-1111-4111-8111-111111111111', true);
select set_config('request.jwt.claims', '{"sub":"51111111-1111-4111-8111-111111111111","role":"authenticated","app_metadata":{},"user_metadata":{}}', true);
set local role authenticated;
select throws_ok(
  $$select * from public.admin_get_order_payment_proof_path('50000000-0000-4000-8000-000000000051')$$,
  '42501',
  'admin access required',
  'an ordinary owner cannot use the admin proof RPC'
);
reset role;

select set_config('request.jwt.claim.sub', '51111111-1111-4111-8111-111111111111', true);
select set_config('request.jwt.claims', '{"sub":"51111111-1111-4111-8111-111111111111","role":"authenticated","app_metadata":{},"user_metadata":{"role":"admin"}}', true);
set local role authenticated;
select throws_ok(
  $$select * from public.admin_get_order_payment_proof_path('50000000-0000-4000-8000-000000000051')$$,
  '42501',
  'admin access required',
  'the proof RPC ignores an admin value in user_metadata'
);
reset role;

select set_config('request.jwt.claim.sub', '53333333-3333-4333-8333-333333333333', true);
select set_config('request.jwt.claims', '{"sub":"53333333-3333-4333-8333-333333333333","role":"authenticated","app_metadata":{"role":"admin"},"user_metadata":{}}', true);
set local role authenticated;

select lives_ok(
  $$select * from public.admin_get_order_payment_proof_path('50000000-0000-4000-8000-000000000051')$$,
  'an app_metadata administrator can read one linked proof'
);
select is(
  (select payment_proof_path from public.admin_get_order_payment_proof_path('50000000-0000-4000-8000-000000000051')),
  '51111111-1111-4111-8111-111111111111/50000000-0000-4000-8000-000000000051/proof_aaaaaaaaaaaaaaaa.jpg',
  'proof RPC returns the exact linked object path'
);
select is(
  (select count(*)::integer from public.admin_get_order_payment_proof_path('50000000-0000-4000-8000-000000000051')),
  1,
  'proof RPC returns at most the one requested proof'
);
select is(
  (select pg_typeof(payment_proof_path)::text
   from public.admin_get_order_payment_proof_path('50000000-0000-4000-8000-000000000051')),
  'text',
  'proof runtime response uses the expected text type'
);
select ok(
  not (
    (select proargnames from pg_proc
     where oid = to_regprocedure('public.admin_get_order_payment_proof_path(uuid)'))
    && array['order_id','user_id','owner_id','bucket_id','metadata','signed_url']::text[]
  ),
  'proof response contract contains no order, owner, metadata, or URL fields'
);
select results_eq(
  $$select payment_proof_path from public.admin_get_order_payment_proof_path('50000000-0000-4000-8000-000000000052')$$,
  $$values ('52222222-2222-4222-8222-222222222222/50000000-0000-4000-8000-000000000052/proof_bbbbbbbbbbbbbbbb.pdf'::text)$$,
  'proof RPC never crosses from the requested order to another order'
);
select is(
  (select count(*)::integer from public.admin_get_order_payment_proof_path('50000000-0000-4000-8000-000000000053')),
  0,
  'an order without a proof returns an empty set'
);
select is(
  (select count(*)::integer from public.admin_get_order_payment_proof_path('50000000-0000-4000-8000-000000000054')),
  0,
  'a missing Storage object returns an empty set'
);
select is(
  (select count(*)::integer from public.admin_get_order_payment_proof_path('50000000-0000-4000-8000-000000000099')),
  0,
  'an unknown order returns an empty set'
);
select is(
  (select count(*)::integer from public.admin_get_order_payment_proof_path(null)),
  0,
  'a null order identifier returns an empty set'
);
reset role;

update storage.objects
set owner_id = '52222222-2222-4222-8222-222222222222'
where bucket_id = 'payment-proofs'
  and name = '51111111-1111-4111-8111-111111111111/50000000-0000-4000-8000-000000000055/proof_cccccccccccccccc.png';
set local role authenticated;
select is(
  (select count(*)::integer from public.admin_get_order_payment_proof_path('50000000-0000-4000-8000-000000000055')),
  0,
  'a Storage object owned by another user fails closed'
);
reset role;

insert into storage.objects (bucket_id, name, owner_id, metadata) values (
  'payment-proofs',
  '52222222-2222-4222-8222-222222222222/50000000-0000-4000-8000-000000000055/proof_dddddddddddddddd.jpg',
  '51111111-1111-4111-8111-111111111111',
  '{"mimetype":"image/jpeg","size":50}'::jsonb
);
update public.orders
set payment_proof_path = '52222222-2222-4222-8222-222222222222/50000000-0000-4000-8000-000000000055/proof_dddddddddddddddd.jpg'
where id = '50000000-0000-4000-8000-000000000055';
set local role authenticated;
select is(
  (select count(*)::integer from public.admin_get_order_payment_proof_path('50000000-0000-4000-8000-000000000055')),
  0,
  'a path in another user folder fails closed'
);
reset role;

insert into storage.objects (bucket_id, name, owner_id, metadata) values (
  'payment-proofs',
  '51111111-1111-4111-8111-111111111111/50000000-0000-4000-8000-000000000051/proof_eeeeeeeeeeeeeeee.pdf',
  '51111111-1111-4111-8111-111111111111',
  '{"mimetype":"application/pdf","size":50}'::jsonb
);
update public.orders
set payment_proof_path = '51111111-1111-4111-8111-111111111111/50000000-0000-4000-8000-000000000051/proof_eeeeeeeeeeeeeeee.pdf'
where id = '50000000-0000-4000-8000-000000000055';
set local role authenticated;
select is(
  (select count(*)::integer from public.admin_get_order_payment_proof_path('50000000-0000-4000-8000-000000000055')),
  0,
  'a path in another order folder fails closed'
);
reset role;

update public.orders
set payment_method = 'cash',
    payment_proof_path = '51111111-1111-4111-8111-111111111111/50000000-0000-4000-8000-000000000055/proof_cccccccccccccccc.png'
where id = '50000000-0000-4000-8000-000000000055';
update storage.objects
set owner_id = '51111111-1111-4111-8111-111111111111'
where bucket_id = 'payment-proofs'
  and name = '51111111-1111-4111-8111-111111111111/50000000-0000-4000-8000-000000000055/proof_cccccccccccccccc.png';
set local role authenticated;
select is(
  (select count(*)::integer from public.admin_get_order_payment_proof_path('50000000-0000-4000-8000-000000000055')),
  0,
  'a cash order cannot expose a proof path'
);
reset role;

insert into storage.objects (bucket_id, name, owner_id, metadata) values (
  'payment-proofs',
  '51111111-1111-4111-8111-111111111111/50000000-0000-4000-8000-000000000055/proof_ffffffffffffffff.txt',
  '51111111-1111-4111-8111-111111111111',
  '{"mimetype":"text/plain","size":50}'::jsonb
);
update public.orders
set payment_method = 'transfer',
    payment_proof_path = '51111111-1111-4111-8111-111111111111/50000000-0000-4000-8000-000000000055/proof_ffffffffffffffff.txt'
where id = '50000000-0000-4000-8000-000000000055';
set local role authenticated;
select is(
  (select count(*)::integer from public.admin_get_order_payment_proof_path('50000000-0000-4000-8000-000000000055')),
  0,
  'a filename with a disallowed extension fails closed'
);
reset role;

insert into storage.objects (bucket_id, name, owner_id, metadata) values (
  'payment-proofs',
  'proof_hhhhhhhhhhhhhhhh.jpg',
  '51111111-1111-4111-8111-111111111111',
  '{"mimetype":"image/jpeg","size":50}'::jsonb
);
update public.orders
set payment_proof_path = 'proof_hhhhhhhhhhhhhhhh.jpg'
where id = '50000000-0000-4000-8000-000000000055';
set local role authenticated;
select is(
  (select count(*)::integer from public.admin_get_order_payment_proof_path('50000000-0000-4000-8000-000000000055')),
  0,
  'a path without user and order folders fails closed'
);
reset role;

update public.orders
set payment_proof_path = '51111111-1111-4111-8111-111111111111/50000000-0000-4000-8000-000000000055/proof_cccccccccccccccc.png'
where id = '50000000-0000-4000-8000-000000000055';
set local search_path = pg_temp, public, extensions, pg_catalog;
set local role authenticated;
select is(
  (select payment_proof_path from public.admin_get_order_payment_proof_path('50000000-0000-4000-8000-000000000055')),
  '51111111-1111-4111-8111-111111111111/50000000-0000-4000-8000-000000000055/proof_cccccccccccccccc.png',
  'an attacker-controlled caller search_path cannot redirect proof reads'
);
reset role;
set local search_path = public, extensions, pg_catalog;

select is(
  (select count(*)::integer from pg_policies where schemaname = 'public' and tablename = 'orders'),
  1,
  'proof migration does not change orders RLS policy count'
);
select is(
  (select count(*)::integer from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname like 'payment_proofs_%'),
  2,
  'proof migration does not change private bucket policies'
);
select is(
  (select count(*)::integer from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname like 'payment_proofs_%' and cmd in ('UPDATE','DELETE')),
  0,
  'proof migration adds no Storage mutation policy'
);

select * from finish();
rollback;
