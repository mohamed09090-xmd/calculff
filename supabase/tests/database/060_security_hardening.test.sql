begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_catalog;

select plan(51);

select ok(
  (select relrowsecurity from pg_class where oid = 'private.order_internal_notes'::regclass),
  'RLS is enabled on private.order_internal_notes'
);
select ok(not has_schema_privilege('anon', 'private', 'USAGE'), 'anon has no USAGE on private schema');
select ok(not has_schema_privilege('authenticated', 'private', 'USAGE'), 'authenticated has no USAGE on private schema');
select ok(not has_table_privilege('anon', 'private.order_internal_notes', 'SELECT'), 'anon cannot select internal notes directly');
select ok(not has_table_privilege('anon', 'private.order_internal_notes', 'INSERT'), 'anon cannot insert internal notes directly');
select ok(not has_table_privilege('anon', 'private.order_internal_notes', 'UPDATE'), 'anon cannot update internal notes directly');
select ok(not has_table_privilege('anon', 'private.order_internal_notes', 'DELETE'), 'anon cannot delete internal notes directly');
select ok(not has_table_privilege('authenticated', 'private.order_internal_notes', 'SELECT'), 'authenticated cannot select internal notes directly');
select ok(not has_table_privilege('authenticated', 'private.order_internal_notes', 'INSERT'), 'authenticated cannot insert internal notes directly');
select ok(not has_table_privilege('authenticated', 'private.order_internal_notes', 'UPDATE'), 'authenticated cannot update internal notes directly');
select ok(not has_table_privilege('authenticated', 'private.order_internal_notes', 'DELETE'), 'authenticated cannot delete internal notes directly');

select ok(to_regprocedure('public.rls_auto_enable()') is not null, 'rls_auto_enable remains installed for the platform event trigger');
select ok(
  not exists (
    select 1
    from pg_proc p
    cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
    where p.oid = 'public.rls_auto_enable()'::regprocedure
      and acl.grantee = 0::oid
      and acl.privilege_type = 'EXECUTE'
  ),
  'PUBLIC cannot execute rls_auto_enable'
);
select ok(not has_function_privilege('anon', 'public.rls_auto_enable()', 'EXECUTE'), 'anon cannot execute rls_auto_enable');
select ok(not has_function_privilege('authenticated', 'public.rls_auto_enable()', 'EXECUTE'), 'authenticated cannot execute rls_auto_enable');

select ok(has_function_privilege('authenticated', 'public.create_order(uuid,uuid,text,text,public.payment_method_type)', 'EXECUTE'), 'authenticated retains create_order EXECUTE');
select ok(has_function_privilege('authenticated', 'public.get_my_order_timeline(uuid)', 'EXECUTE'), 'authenticated retains timeline EXECUTE');
select ok(has_function_privilege('authenticated', 'public.attach_payment_proof(uuid,text)', 'EXECUTE'), 'authenticated retains proof-binding EXECUTE');
select ok(has_function_privilege('authenticated', 'public.admin_add_order_internal_note(uuid,text)', 'EXECUTE'), 'authenticated retains admin note RPC EXECUTE');
select ok(has_function_privilege('authenticated', 'public.admin_list_order_internal_notes(uuid)', 'EXECUTE'), 'authenticated retains admin note-list RPC EXECUTE');
select ok(has_function_privilege('authenticated', 'public.admin_set_order_status(uuid,public.order_status_type,text,text)', 'EXECUTE'), 'authenticated retains admin order RPC EXECUTE');
select ok(has_function_privilege('authenticated', 'public.admin_set_payment_status(uuid,public.payment_status_type,text,text)', 'EXECUTE'), 'authenticated retains admin payment RPC EXECUTE');
select ok(has_function_privilege('authenticated', 'public.admin_mark_refunded(uuid,text,text)', 'EXECUTE'), 'authenticated retains admin refund RPC EXECUTE');
select ok(not has_function_privilege('anon', 'public.create_order(uuid,uuid,text,text,public.payment_method_type)', 'EXECUTE'), 'anon remains blocked from create_order');
select ok(not has_function_privilege('anon', 'public.get_my_order_timeline(uuid)', 'EXECUTE'), 'anon remains blocked from timeline');
select ok(not has_function_privilege('anon', 'public.attach_payment_proof(uuid,text)', 'EXECUTE'), 'anon remains blocked from proof binding');
select ok(not has_function_privilege('anon', 'public.admin_set_order_status(uuid,public.order_status_type,text,text)', 'EXECUTE'), 'anon remains blocked from admin order RPC');

select ok(to_regclass('private.order_internal_notes_author_user_id_idx') is not null, 'internal note author foreign-key index exists');
select ok(to_regclass('public.order_status_history_changed_by_idx') is not null, 'history changed_by foreign-key index exists');

select is(
  (select count(*)::integer from pg_policies where schemaname = 'public' and tablename = 'profiles' and policyname = 'profiles_select_own_or_admin'),
  1,
  'profiles ownership/admin policy keeps its original name'
);
select is(
  (select count(*)::integer from pg_policies where schemaname = 'public' and tablename = 'games' and policyname in ('games_select_active_or_admin','games_admin_insert','games_admin_update','games_admin_delete')),
  4,
  'all games policies keep their original names'
);
select is(
  (select count(*)::integer from pg_policies where schemaname = 'public' and tablename = 'public_offers' and policyname in ('public_offers_select_published_or_admin','public_offers_admin_insert','public_offers_admin_update','public_offers_admin_delete')),
  4,
  'all offer policies keep their original names'
);
select is(
  (select count(*)::integer from pg_policies where schemaname = 'public' and tablename = 'orders' and policyname = 'orders_select_own_or_admin'),
  1,
  'orders ownership/admin policy keeps its original name'
);
select is(
  (select count(*)::integer from pg_policies where schemaname = 'public' and tablename = 'order_status_history' and policyname = 'order_status_history_admin_select'),
  1,
  'history admin policy keeps its original name'
);
select is(
  (select count(*)::integer from pg_policies where schemaname = 'public' and tablename in ('profiles','games','public_offers','orders','order_status_history') and position('select auth.jwt()' in lower(coalesce(qual, '') || ' ' || coalesce(with_check, ''))) > 0),
  11,
  'all eleven advisor-identified policies use a JWT initialization subquery'
);
select is(
  (select count(*)::integer from pg_policies where schemaname = 'public' and tablename in ('profiles','orders') and position('select auth.uid()' in lower(coalesce(qual, ''))) > 0),
  2,
  'ownership policies retain UID initialization subqueries'
);

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('11111111-1111-4111-8111-111111111111', 'authenticated', 'authenticated', 'hardening-user-a@test.invalid', crypt('password-a', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('22222222-2222-4222-8222-222222222222', 'authenticated', 'authenticated', 'hardening-user-b@test.invalid', crypt('password-b', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('33333333-3333-4333-8333-333333333333', 'authenticated', 'authenticated', 'hardening-admin@test.invalid', crypt('password-admin', gen_salt('bf')), now(), '{"provider":"email","providers":["email"],"role":"admin"}', '{}', now(), now());

update public.profiles set full_name = 'User A', phone = '0555112233' where id = '11111111-1111-4111-8111-111111111111';
update public.profiles set full_name = 'User B', phone = '0555223344' where id = '22222222-2222-4222-8222-222222222222';
update public.profiles set full_name = 'Admin', phone = '0555000001' where id = '33333333-3333-4333-8333-333333333333';

insert into public.games (id, slug, name_ar, name_fr, reward_unit_code, reward_unit_name_ar, reward_unit_name_fr, is_active, sort_order) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'hardening-active', 'لعبة فعالة', 'Jeu actif', 'credits', 'رصيد', 'Crédits', true, 10),
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2', 'hardening-hidden', 'لعبة مخفية', 'Jeu masqué', 'credits', 'رصيد', 'Crédits', false, 20);
insert into public.public_offers (id, game_id, name_ar, name_fr, reward_quantity, sale_price_dzd, is_published, sort_order) values
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'عرض ظاهر', 'Offre visible', 100, 350, true, 10),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'عرض مخفي', 'Offre masquée', 200, 650, false, 20);

insert into public.orders (
  id, user_id, client_request_id, game_id, offer_id, player_id, payment_method,
  game_name_ar_snapshot, game_name_fr_snapshot,
  reward_unit_code_snapshot, reward_unit_name_ar_snapshot, reward_unit_name_fr_snapshot,
  offer_name_ar_snapshot, offer_name_fr_snapshot, reward_quantity_snapshot, sale_price_dzd_snapshot,
  customer_name_snapshot, customer_email_snapshot, customer_phone_snapshot
) values
  ('80000000-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111', '80000000-0000-4000-8000-000000000001', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1', 'PLAYER-A', 'cash', 'لعبة فعالة', 'Jeu actif', 'credits', 'رصيد', 'Crédits', 'عرض ظاهر', 'Offre visible', 100, 350, 'User A', 'hardening-user-a@test.invalid', '0555112233'),
  ('80000000-0000-4000-8000-000000000002', '22222222-2222-4222-8222-222222222222', '80000000-0000-4000-8000-000000000002', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1', 'PLAYER-B', 'cash', 'لعبة فعالة', 'Jeu actif', 'credits', 'رصيد', 'Crédits', 'عرض ظاهر', 'Offre visible', 100, 350, 'User B', 'hardening-user-b@test.invalid', '0555223344');
insert into public.order_status_history (order_id, event_type, order_status, payment_status, changed_by)
values
  ('80000000-0000-4000-8000-000000000001', 'created', 'new', 'awaiting_payment', '11111111-1111-4111-8111-111111111111'),
  ('80000000-0000-4000-8000-000000000002', 'created', 'new', 'awaiting_payment', '22222222-2222-4222-8222-222222222222');

select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
select set_config('request.jwt.claims', '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated","app_metadata":{},"user_metadata":{}}', true);
set local role authenticated;
select is((select count(*)::integer from public.profiles), 1, 'ordinary user still sees only their profile');
select is((select count(*)::integer from public.orders), 1, 'ordinary user still sees only their order');
select is((select count(*)::integer from public.order_status_history), 0, 'ordinary user still sees no direct history rows');
select results_eq($$select slug::text from public.games where slug like 'hardening-%' order by slug$$, $$values ('hardening-active'::text)$$, 'ordinary user still sees active games only');
select results_eq($$select id::text from public.public_offers where id in ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2') order by id$$, $$values ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1'::text)$$, 'ordinary user still sees published offers only');
select throws_ok($$select * from private.order_internal_notes$$, '42501', null, 'ordinary user cannot directly select internal notes');
select throws_ok($$insert into private.order_internal_notes (order_id, author_user_id, note) values ('80000000-0000-4000-8000-000000000001','11111111-1111-4111-8111-111111111111','blocked')$$, '42501', null, 'ordinary user cannot directly insert internal notes');
select throws_ok($$update private.order_internal_notes set note = 'blocked'$$, '42501', null, 'ordinary user cannot directly update internal notes');
select throws_ok($$delete from private.order_internal_notes$$, '42501', null, 'ordinary user cannot directly delete internal notes');
select throws_ok($$select public.admin_set_order_status('80000000-0000-4000-8000-000000000001','accepted')$$, '42501', 'admin access required', 'ordinary user remains blocked from admin RPCs');
reset role;

select set_config('request.jwt.claim.sub', '33333333-3333-4333-8333-333333333333', true);
select set_config('request.jwt.claims', '{"sub":"33333333-3333-4333-8333-333333333333","role":"authenticated","app_metadata":{"role":"admin"},"user_metadata":{}}', true);
set local role authenticated;
select is((select count(*)::integer from public.profiles), 3, 'admin still sees all profiles');
select is((select count(*)::integer from public.orders), 2, 'admin still sees all orders');
select is((select count(*)::integer from public.order_status_history), 2, 'admin still sees all history rows');
select lives_ok($$select public.admin_add_order_internal_note('80000000-0000-4000-8000-000000000001','hardening note')$$, 'admin note RPC still writes through defensive RLS');
select is((select note from public.admin_list_order_internal_notes('80000000-0000-4000-8000-000000000001')), 'hardening note', 'admin note RPC still reads through defensive RLS');
reset role;

select * from finish();
rollback;
