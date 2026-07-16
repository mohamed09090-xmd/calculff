begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_catalog;

select plan(51);

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('11111111-1111-4111-8111-111111111111', 'authenticated', 'authenticated', 'user-a@test.invalid', crypt('password-a', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('22222222-2222-4222-8222-222222222222', 'authenticated', 'authenticated', 'user-b@test.invalid', crypt('password-b', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('33333333-3333-4333-8333-333333333333', 'authenticated', 'authenticated', 'admin@test.invalid', crypt('password-admin', gen_salt('bf')), now(), '{"provider":"email","providers":["email"],"role":"admin"}', '{}', now(), now());

select is((select count(*)::integer from public.profiles where id in ('11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222','33333333-3333-4333-8333-333333333333')), 3, 'auth insert trigger creates one profile per user');
select is((select email from public.profiles where id = '11111111-1111-4111-8111-111111111111'), 'user-a@test.invalid', 'profile email is copied from auth.users');
update auth.users set email = 'user-a-updated@test.invalid' where id = '11111111-1111-4111-8111-111111111111';
select is((select email from public.profiles where id = '11111111-1111-4111-8111-111111111111'), 'user-a-updated@test.invalid', 'auth email changes synchronize to profiles');
select is((select is_complete from public.profiles where id = '11111111-1111-4111-8111-111111111111'), false, 'new profile is incomplete before name and phone');

select ok(not has_table_privilege('anon', 'public.profiles', 'SELECT'), 'anon cannot select profiles');
select ok(not has_table_privilege('anon', 'public.games', 'SELECT'), 'anon cannot select games');
select ok(not has_table_privilege('anon', 'public.public_offers', 'SELECT'), 'anon cannot select offers');
select ok(not has_table_privilege('anon', 'public.orders', 'SELECT'), 'anon cannot select orders');
select ok(not has_table_privilege('anon', 'public.order_status_history', 'SELECT'), 'anon cannot select history');
select ok(not has_table_privilege('authenticated', 'public.orders', 'INSERT'), 'authenticated cannot insert orders directly');
select ok(not has_table_privilege('authenticated', 'public.orders', 'UPDATE'), 'authenticated cannot update orders directly');
select ok(not has_table_privilege('authenticated', 'public.orders', 'DELETE'), 'authenticated cannot delete orders directly');
select ok(not has_table_privilege('authenticated', 'public.order_status_history', 'INSERT'), 'authenticated cannot write history');
select ok(not has_schema_privilege('authenticated', 'private', 'USAGE'), 'authenticated has no USAGE on private schema');
select ok(not has_table_privilege('authenticated', 'private.order_internal_notes', 'SELECT'), 'authenticated cannot read internal notes directly');
select ok(not has_function_privilege('authenticated', 'private.is_admin()', 'EXECUTE'), 'authenticated cannot execute private.is_admin');
select ok(not has_function_privilege('authenticated', 'private.handle_auth_user_created()', 'EXECUTE'), 'authenticated cannot execute auth create trigger helper');
select ok(not has_function_privilege('authenticated', 'private.handle_auth_user_email_changed()', 'EXECUTE'), 'authenticated cannot execute auth email trigger helper');
select is(
  (select array_agg(column_name::text order by column_name) from information_schema.column_privileges where grantee = 'authenticated' and table_schema = 'public' and table_name = 'profiles' and privilege_type = 'UPDATE'),
  array['full_name','locale','phone']::text[],
  'profile UPDATE grant is limited to full_name, locale, and phone'
);
select ok(has_function_privilege('authenticated', 'public.create_order(uuid,uuid,text,text,public.payment_method_type)', 'EXECUTE'), 'authenticated can execute create_order');
select ok(has_function_privilege('authenticated', 'public.get_my_order_timeline(uuid)', 'EXECUTE'), 'authenticated can execute owner timeline RPC');
select ok(not has_function_privilege('anon', 'public.create_order(uuid,uuid,text,text,public.payment_method_type)', 'EXECUTE'), 'anon cannot execute create_order');
select ok(
  not exists (
    select 1
    from pg_proc p
    cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
    where p.oid = 'public.admin_set_order_status(uuid,public.order_status_type,text,text)'::regprocedure
      and acl.grantee = 0::oid
      and acl.privilege_type = 'EXECUTE'
  ),
  'PUBLIC cannot execute admin order RPC'
);
select ok(not has_function_privilege('anon', 'public.admin_mark_refunded(uuid,text,text)', 'EXECUTE'), 'anon cannot execute refund RPC');
select is(
  (select count(*)::integer from information_schema.role_table_grants where grantee in ('anon','authenticated') and table_schema in ('public','private') and privilege_type = 'TRUNCATE'),
  0,
  'client roles have no TRUNCATE grants'
);

insert into public.games (id, slug, name_ar, name_fr, reward_unit_code, reward_unit_name_ar, reward_unit_name_fr, is_active, sort_order) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'active-game', 'لعبة فعالة', 'Jeu actif', 'credits', 'رصيد', 'Crédits', true, 10),
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2', 'inactive-game', 'لعبة معطلة', 'Jeu inactif', 'credits', 'رصيد', 'Crédits', false, 20);
insert into public.public_offers (id, game_id, name_ar, name_fr, reward_quantity, sale_price_dzd, is_published, sort_order) values
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'عرض منشور', 'Offre publiée', 100, 350, true, 10),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'عرض مخفي', 'Offre masquée', 200, 650, false, 20),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2', 'عرض لعبة معطلة', 'Offre jeu inactif', 300, 900, true, 30);
update public.profiles set full_name = 'User A', phone = '+213 (555) 12-34-56', locale = 'ar' where id = '11111111-1111-4111-8111-111111111111';
update public.profiles set full_name = 'User B', phone = '0555 22 33 44', locale = 'fr' where id = '22222222-2222-4222-8222-222222222222';

select is((select is_complete from public.profiles where id = '11111111-1111-4111-8111-111111111111'), true, 'valid name and Algerian-formatted phone complete the profile');

select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
select set_config('request.jwt.claims', '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated","app_metadata":{},"user_metadata":{}}', true);
set local role authenticated;
select is((select count(*)::integer from public.profiles), 1, 'user A sees only their profile');
select is((select count(*)::integer from public.profiles where id = '22222222-2222-4222-8222-222222222222'), 0, 'user A cannot see user B profile');
select lives_ok($$update public.profiles set full_name = 'User A Updated', phone = '+213 555-12-34-56', locale = 'fr' where id = '11111111-1111-4111-8111-111111111111'$$, 'user can update allowed profile columns');
select throws_ok($$update public.profiles set email = 'forged@test.invalid' where id = '11111111-1111-4111-8111-111111111111'$$, '42501', 'permission denied for table profiles', 'user cannot update profile email directly');
select throws_ok($$update public.profiles set id = '99999999-9999-4999-8999-999999999999' where id = '11111111-1111-4111-8111-111111111111'$$, '42501', 'permission denied for table profiles', 'user cannot update profile id directly');
select throws_ok($$update public.profiles set full_name = '  ' where id = '11111111-1111-4111-8111-111111111111'$$, '23514', null, 'blank full_name is rejected');
select throws_ok($$update public.profiles set full_name = 'A' where id = '11111111-1111-4111-8111-111111111111'$$, '23514', null, 'one-character full_name is rejected');
select throws_ok($$update public.profiles set full_name = repeat('A', 101) where id = '11111111-1111-4111-8111-111111111111'$$, '23514', null, 'full_name longer than 100 is rejected');
select throws_ok($$update public.profiles set phone = '' where id = '11111111-1111-4111-8111-111111111111'$$, '23514', null, 'empty phone is rejected');
select throws_ok($$update public.profiles set phone = 'abc123' where id = '11111111-1111-4111-8111-111111111111'$$, '23514', null, 'phone with invalid characters is rejected');
select throws_ok($$update public.profiles set phone = '12345' where id = '11111111-1111-4111-8111-111111111111'$$, '23514', null, 'phone shorter than 6 is rejected');
select throws_ok($$update public.profiles set phone = '------' where id = '11111111-1111-4111-8111-111111111111'$$, '23514', null, 'phone with punctuation but no digits is rejected');
select throws_ok($$update public.profiles set phone = repeat('1', 26) where id = '11111111-1111-4111-8111-111111111111'$$, '23514', null, 'phone longer than 25 is rejected');
select throws_ok($$update public.profiles set locale = 'en' where id = '11111111-1111-4111-8111-111111111111'$$, '23514', null, 'unsupported locale is rejected');
select results_eq($$select slug::text from public.games order by slug$$, $$values ('active-game'::text), ('free-fire')$$, 'authenticated sees active games only');
select results_eq($$select id::text from public.public_offers order by id$$, $$values ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1'::text)$$, 'authenticated sees published offers for active games only');
select throws_ok($$insert into public.games (slug,name_ar,name_fr,reward_unit_code,reward_unit_name_ar,reward_unit_name_fr,is_active) values ('blocked-game','ممنوع','Bloqué','unit','وحدة','Unité',true)$$, '42501', null, 'ordinary user cannot insert games');
select throws_ok($$insert into public.public_offers (game_id,name_ar,name_fr,reward_quantity,sale_price_dzd,is_published) values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1','ممنوع','Bloquée',1,1,true)$$, '42501', null, 'ordinary user cannot insert offers');
reset role;

select set_config('request.jwt.claim.sub', '33333333-3333-4333-8333-333333333333', true);
select set_config('request.jwt.claims', '{"sub":"33333333-3333-4333-8333-333333333333","role":"authenticated","app_metadata":{"role":"admin"},"user_metadata":{}}', true);
set local role authenticated;
select is((select count(*)::integer from public.profiles), 3, 'admin sees all profiles');
select lives_ok($$insert into public.games (slug,name_ar,name_fr,reward_unit_code,reward_unit_name_ar,reward_unit_name_fr,is_active) values ('admin-game','لعبة مدير','Jeu admin','unit','وحدة','Unité',false)$$, 'admin can insert games');
select lives_ok($$update public.games set is_active = true where slug = 'admin-game'$$, 'admin can update games');
select lives_ok($$insert into public.public_offers (game_id,name_ar,name_fr,reward_quantity,sale_price_dzd,is_published) select id,'عرض مدير','Offre admin',10,100,true from public.games where slug = 'admin-game'$$, 'admin can insert offers');
select lives_ok($$delete from public.public_offers where name_fr = 'Offre admin'$$, 'admin can delete offers');
select lives_ok($$delete from public.games where slug = 'admin-game'$$, 'admin can delete games');
reset role;

select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select throws_ok($$select * from public.games$$, '42501', 'permission denied for table games', 'anon cannot read platform games');
reset role;

select * from finish();
rollback;
