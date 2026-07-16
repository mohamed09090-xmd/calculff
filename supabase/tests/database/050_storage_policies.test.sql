begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_catalog;

select plan(39);

select results_eq(
  $$select (n.nspname::text || '.' || p.proname::text) collate "C" from pg_proc p join pg_namespace n on n.oid = p.pronamespace where p.prosecdef and n.nspname in ('public','private') order by 1$$,
  $$values
    ('private.handle_auth_user_created'::text collate "C"),
    ('private.handle_auth_user_email_changed'::text collate "C"),
    ('public.admin_add_order_internal_note'::text collate "C"),
    ('public.admin_list_order_internal_notes'::text collate "C"),
    ('public.admin_mark_refunded'::text collate "C"),
    ('public.admin_set_order_status'::text collate "C"),
    ('public.admin_set_payment_status'::text collate "C"),
    ('public.attach_payment_proof'::text collate "C"),
    ('public.create_order'::text collate "C"),
    ('public.get_my_order_timeline'::text collate "C")$$,
  'all SECURITY DEFINER functions are discovered from pg_proc'
);
select is(
  (select count(*)::integer from pg_proc p join pg_namespace n on n.oid = p.pronamespace where p.prosecdef and n.nspname in ('public','private')),
  10,
  'exactly ten SECURITY DEFINER functions exist'
);
select is(
  (select count(*)::integer from pg_proc p join pg_namespace n on n.oid = p.pronamespace where p.prosecdef and n.nspname in ('public','private') and coalesce(array_to_string(p.proconfig, ','), '') <> 'search_path=""'),
  0,
  'every SECURITY DEFINER pins an empty search_path'
);
select is(
  (
    select count(*)::integer
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where p.prosecdef
      and n.nspname in ('public','private')
      and exists (
        select 1
        from aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
        where acl.grantee = 0::oid
          and acl.privilege_type = 'EXECUTE'
      )
  ),
  0,
  'PUBLIC can execute no SECURITY DEFINER function'
);
select is(
  (select count(*)::integer from pg_proc p join pg_namespace n on n.oid = p.pronamespace where p.prosecdef and n.nspname in ('public','private') and has_function_privilege('anon', p.oid, 'EXECUTE')),
  0,
  'anon can execute no SECURITY DEFINER function'
);
select is(
  (select count(*)::integer from pg_proc p join pg_namespace n on n.oid = p.pronamespace where p.prosecdef and n.nspname = 'private' and has_function_privilege('authenticated', p.oid, 'EXECUTE')),
  0,
  'authenticated can execute no private SECURITY DEFINER helper'
);
select is(
  (select count(*)::integer from pg_proc p join pg_namespace n on n.oid = p.pronamespace where p.prosecdef and n.nspname = 'public' and has_function_privilege('authenticated', p.oid, 'EXECUTE')),
  8,
  'authenticated receives EXECUTE only on the eight public RPCs'
);

select results_eq(
  $$select (policyname::text || ':' || cmd::text) collate "C" from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname like 'payment_proofs_%' order by 1$$,
  $$values ('payment_proofs_insert_own_order:INSERT'::text collate "C"), ('payment_proofs_select_owner_or_admin:SELECT'::text collate "C")$$,
  'payment-proofs has only INSERT and SELECT client policies'
);
select is((select count(*)::integer from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname like 'payment_proofs_%' and cmd = 'UPDATE'), 0, 'no payment proof UPDATE policy exists');
select is((select count(*)::integer from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname like 'payment_proofs_%' and cmd = 'DELETE'), 0, 'no payment proof DELETE policy exists');
select ok((select with_check like '%payment-proofs%' from pg_policies where policyname = 'payment_proofs_insert_own_order'), 'INSERT policy is bound to payment-proofs bucket');
select ok((select with_check like '%owner_id%' and with_check like '%auth.uid%' from pg_policies where policyname = 'payment_proofs_insert_own_order'), 'INSERT policy verifies Storage owner_id against auth.uid');
select ok((select with_check like '%foldername%' and with_check like '%orders%' and with_check like '%user_id%' from pg_policies where policyname = 'payment_proofs_insert_own_order'), 'INSERT policy verifies user/order path ownership');
select ok((select qual like '%payment_proof_path%' and qual like '%admin%' from pg_policies where policyname = 'payment_proofs_select_owner_or_admin'), 'SELECT policy permits linked owner or admin only');
select is((select count(*)::integer from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname like 'payment_proofs_%' and 'anon' = any(roles)), 0, 'anon is not targeted by payment proof policies');
select is((select public from storage.buckets where id = 'payment-proofs'), false, 'bucket remains private');
select is((select file_size_limit from storage.buckets where id = 'payment-proofs'), 5242880::bigint, 'bucket metadata enforces 5 MiB');

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('11111111-1111-4111-8111-111111111111', 'authenticated', 'authenticated', 'user-a@test.invalid', crypt('password-a', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('22222222-2222-4222-8222-222222222222', 'authenticated', 'authenticated', 'user-b@test.invalid', crypt('password-b', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('33333333-3333-4333-8333-333333333333', 'authenticated', 'authenticated', 'admin@test.invalid', crypt('password-admin', gen_salt('bf')), now(), '{"provider":"email","providers":["email"],"role":"admin"}', '{}', now(), now());
update public.profiles set full_name = 'User A', phone = '0555112233' where id = '11111111-1111-4111-8111-111111111111';
update public.profiles set full_name = 'User B', phone = '0555445566' where id = '22222222-2222-4222-8222-222222222222';
update public.profiles set full_name = 'Admin', phone = '0555000001' where id = '33333333-3333-4333-8333-333333333333';

insert into public.games (id, slug, name_ar, name_fr, reward_unit_code, reward_unit_name_ar, reward_unit_name_fr, is_active) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'active-game', 'لعبة فعالة', 'Jeu actif', 'diamonds', 'جواهر', 'Diamants', true);
insert into public.public_offers (id, game_id, name_ar, name_fr, reward_quantity, sale_price_dzd, is_published) values
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', '100 جوهرة', '100 diamants', 100, 350, true);

insert into public.orders (
  id, user_id, client_request_id, game_id, offer_id, player_id, payment_method,
  game_name_ar_snapshot, game_name_fr_snapshot,
  reward_unit_code_snapshot, reward_unit_name_ar_snapshot, reward_unit_name_fr_snapshot,
  offer_name_ar_snapshot, offer_name_fr_snapshot, reward_quantity_snapshot, sale_price_dzd_snapshot,
  customer_name_snapshot, customer_email_snapshot, customer_phone_snapshot
) values
  ('90000000-0000-4000-8000-000000000001','11111111-1111-4111-8111-111111111111','91000000-0000-4000-8000-000000000001','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1','PLAYER-A','transfer','لعبة فعالة','Jeu actif','diamonds','جواهر','Diamants','100 جوهرة','100 diamants',100,350,'User A','user-a@test.invalid','0555112233'),
  ('90000000-0000-4000-8000-000000000002','11111111-1111-4111-8111-111111111111','91000000-0000-4000-8000-000000000002','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1','PLAYER-A2','transfer','لعبة فعالة','Jeu actif','diamonds','جواهر','Diamants','100 جوهرة','100 diamants',100,350,'User A','user-a@test.invalid','0555112233'),
  ('90000000-0000-4000-8000-000000000003','11111111-1111-4111-8111-111111111111','91000000-0000-4000-8000-000000000003','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1','PLAYER-CASH','cash','لعبة فعالة','Jeu actif','diamonds','جواهر','Diamants','100 جوهرة','100 diamants',100,350,'User A','user-a@test.invalid','0555112233'),
  ('90000000-0000-4000-8000-000000000004','22222222-2222-4222-8222-222222222222','91000000-0000-4000-8000-000000000004','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1','PLAYER-B','transfer','لعبة فعالة','Jeu actif','diamonds','جواهر','Diamants','100 جوهرة','100 diamants',100,350,'User B','user-b@test.invalid','0555445566');

insert into public.orders (
  id, user_id, client_request_id, game_id, offer_id, player_id, payment_method,
  order_status, payment_status, completed_at,
  game_name_ar_snapshot, game_name_fr_snapshot,
  reward_unit_code_snapshot, reward_unit_name_ar_snapshot, reward_unit_name_fr_snapshot,
  offer_name_ar_snapshot, offer_name_fr_snapshot, reward_quantity_snapshot, sale_price_dzd_snapshot,
  customer_name_snapshot, customer_email_snapshot, customer_phone_snapshot
) values (
  '90000000-0000-4000-8000-000000000005','11111111-1111-4111-8111-111111111111','91000000-0000-4000-8000-000000000005',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1','PLAYER-FINAL','transfer',
  'completed','paid',now(),
  'لعبة فعالة','Jeu actif','diamonds','جواهر','Diamants','100 جوهرة','100 diamants',100,350,
  'User A','user-a@test.invalid','0555112233'
);

insert into storage.objects (bucket_id, name, owner_id, metadata) values
  ('payment-proofs','11111111-1111-4111-8111-111111111111/90000000-0000-4000-8000-000000000001/proof_aaaaaaaaaaaaaaaa.jpg','11111111-1111-4111-8111-111111111111','{"mimetype":"image/jpeg","size":100}'::jsonb),
  ('payment-proofs','11111111-1111-4111-8111-111111111111/90000000-0000-4000-8000-000000000001/proof_bbbbbbbbbbbbbbbb.png','11111111-1111-4111-8111-111111111111','{"mimetype":"image/png","size":200}'::jsonb),
  ('payment-proofs','11111111-1111-4111-8111-111111111111/90000000-0000-4000-8000-000000000002/proof_invalidmime000.pdf','11111111-1111-4111-8111-111111111111','{"mimetype":"text/plain","size":100}'::jsonb),
  ('payment-proofs','11111111-1111-4111-8111-111111111111/90000000-0000-4000-8000-000000000002/proof_oversized00000.pdf','11111111-1111-4111-8111-111111111111','{"mimetype":"application/pdf","size":5242881}'::jsonb),
  ('payment-proofs','11111111-1111-4111-8111-111111111111/90000000-0000-4000-8000-000000000002/proof_wrongowner000.pdf','22222222-2222-4222-8222-222222222222','{"mimetype":"application/pdf","size":100}'::jsonb),
  ('payment-proofs','22222222-2222-4222-8222-222222222222/90000000-0000-4000-8000-000000000004/proof_cccccccccccccccc.jpg','22222222-2222-4222-8222-222222222222','{"mimetype":"image/jpeg","size":100}'::jsonb),
  ('payment-proofs','11111111-1111-4111-8111-111111111111/90000000-0000-4000-8000-000000000005/proof_final000000000.jpg','11111111-1111-4111-8111-111111111111','{"mimetype":"image/jpeg","size":100}'::jsonb);

create schema evil;
create function evil.is_admin() returns boolean language sql immutable as $$select true$$;
create table evil.orders (id uuid primary key);

select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select throws_ok(
  $$select public.attach_payment_proof('90000000-0000-4000-8000-000000000001','11111111-1111-4111-8111-111111111111/90000000-0000-4000-8000-000000000001/proof_aaaaaaaaaaaaaaaa.jpg')$$,
  '42501',
  null,
  'anonymous proof attachment is rejected'
);
reset role;

select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
select set_config('request.jwt.claims', '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated","app_metadata":{},"user_metadata":{}}', true);
select set_config('search_path', 'evil,public,extensions,pg_catalog', true);
set local role authenticated;
select throws_ok($$select public.admin_set_order_status('90000000-0000-4000-8000-000000000001','accepted')$$, '42501', 'admin access required', 'caller search_path cannot replace private.is_admin');
select lives_ok($$select public.attach_payment_proof('90000000-0000-4000-8000-000000000001','11111111-1111-4111-8111-111111111111/90000000-0000-4000-8000-000000000001/proof_aaaaaaaaaaaaaaaa.jpg')$$, 'owner can attach a valid proof despite hostile search_path');
select is((select payment_status from public.orders where id = '90000000-0000-4000-8000-000000000001'), 'under_review'::public.payment_status_type, 'valid attach moves transfer payment to under_review');
select is((select count(*)::integer from public.order_status_history where order_id = '90000000-0000-4000-8000-000000000001' and event_type = 'proof_attached'), 0, 'owner still cannot read history directly');
select throws_ok($$select public.attach_payment_proof('90000000-0000-4000-8000-000000000002','11111111-1111-4111-8111-111111111111/90000000-0000-4000-8000-000000000002/missing_000000000000.pdf')$$, 'P0002', 'payment proof object not found', 'attach rejects missing Storage object');
select throws_ok($$select public.attach_payment_proof('90000000-0000-4000-8000-000000000003','11111111-1111-4111-8111-111111111111/90000000-0000-4000-8000-000000000003/proof_aaaaaaaaaaaaaaaa.jpg')$$, '22023', 'payment proofs are accepted only for transfer orders', 'attach rejects cash order');
select throws_ok($$select public.attach_payment_proof('90000000-0000-4000-8000-000000000004','22222222-2222-4222-8222-222222222222/90000000-0000-4000-8000-000000000004/proof_cccccccccccccccc.jpg')$$, '42501', 'order is not owned by the authenticated user', 'attach rejects another user order');
select throws_ok($$select public.attach_payment_proof('90000000-0000-4000-8000-000000000002','11111111-1111-4111-8111-111111111111/90000000-0000-4000-8000-000000000002/proof_invalidmime000.pdf')$$, '22023', 'payment proof MIME type is not allowed', 'attach rejects invalid MIME metadata');
select throws_ok($$select public.attach_payment_proof('90000000-0000-4000-8000-000000000002','11111111-1111-4111-8111-111111111111/90000000-0000-4000-8000-000000000002/proof_oversized00000.pdf')$$, '22023', 'payment proof exceeds the 5 MiB limit', 'attach rejects oversized metadata');
select throws_ok($$select public.attach_payment_proof('90000000-0000-4000-8000-000000000002','11111111-1111-4111-8111-111111111111/90000000-0000-4000-8000-000000000002/proof_wrongowner000.pdf')$$, '42501', 'payment proof owner does not match', 'attach rejects mismatched Storage owner');
select throws_ok($$select public.attach_payment_proof('90000000-0000-4000-8000-000000000005','11111111-1111-4111-8111-111111111111/90000000-0000-4000-8000-000000000005/proof_final000000000.jpg')$$, '22023', 'a final order cannot receive a payment proof', 'completed order rejects a new proof');
select is((select count(*)::integer from storage.objects), 1, 'owner can select only the proof linked to their order');
reset role;

select set_config('request.jwt.claim.sub', '33333333-3333-4333-8333-333333333333', true);
select set_config('request.jwt.claims', '{"sub":"33333333-3333-4333-8333-333333333333","role":"authenticated","app_metadata":{"role":"admin"},"user_metadata":{}}', true);
set local role authenticated;
select is((select count(*)::integer from storage.objects where bucket_id = 'payment-proofs'), 7, 'admin can read all payment proof objects');
select throws_ok($$select public.attach_payment_proof('90000000-0000-4000-8000-000000000002','11111111-1111-4111-8111-111111111111/90000000-0000-4000-8000-000000000002/proof_invalidmime000.pdf')$$, '42501', 'order is not owned by the authenticated user', 'admin cannot bypass owner-only proof attachment');
select lives_ok($$select public.admin_set_payment_status('90000000-0000-4000-8000-000000000001','proof_rejected')$$, 'admin can reject an attached proof');
reset role;

select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
select set_config('request.jwt.claims', '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated","app_metadata":{},"user_metadata":{}}', true);
set local role authenticated;
select lives_ok($$select public.attach_payment_proof('90000000-0000-4000-8000-000000000001','11111111-1111-4111-8111-111111111111/90000000-0000-4000-8000-000000000001/proof_bbbbbbbbbbbbbbbb.png')$$, 'new proof after proof_rejected can be attached');
select is((select payment_status from public.orders where id = '90000000-0000-4000-8000-000000000001'), 'under_review'::public.payment_status_type, 'replacement proof returns payment to under_review');
select is((select payment_proof_path from public.orders where id = '90000000-0000-4000-8000-000000000001'), '11111111-1111-4111-8111-111111111111/90000000-0000-4000-8000-000000000001/proof_bbbbbbbbbbbbbbbb.png', 'replacement proof updates the linked path');
select is((select count(*)::integer from storage.objects), 1, 'after replacement owner reads only the newly linked proof');
reset role;

select set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
select set_config('request.jwt.claims', '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated","app_metadata":{},"user_metadata":{}}', true);
set local role authenticated;
select is((select count(*)::integer from storage.objects), 0, 'user B cannot read an unlinked proof');
select throws_ok($$select public.attach_payment_proof('90000000-0000-4000-8000-000000000001','11111111-1111-4111-8111-111111111111/90000000-0000-4000-8000-000000000001/proof_bbbbbbbbbbbbbbbb.png')$$, '42501', 'order is not owned by the authenticated user', 'user B cannot attach user A proof');
reset role;

select * from finish();
rollback;
