begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_catalog;

select plan(43);

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('11111111-1111-4111-8111-111111111111', 'authenticated', 'authenticated', 'user-a@test.invalid', crypt('password-a', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('22222222-2222-4222-8222-222222222222', 'authenticated', 'authenticated', 'user-b@test.invalid', crypt('password-b', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('44444444-4444-4444-8444-444444444444', 'authenticated', 'authenticated', 'unconfirmed@test.invalid', crypt('password-u', gen_salt('bf')), null, '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('55555555-5555-4555-8555-555555555555', 'authenticated', 'authenticated', 'missing-profile@test.invalid', crypt('password-m', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('66666666-6666-4666-8666-666666666666', 'authenticated', 'authenticated', 'incomplete@test.invalid', crypt('password-i', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('33333333-3333-4333-8333-333333333333', 'authenticated', 'authenticated', 'admin@test.invalid', crypt('password-admin', gen_salt('bf')), now(), '{"provider":"email","providers":["email"],"role":"admin"}', '{}', now(), now());

update public.profiles set full_name = 'User A', phone = '+213 555 11 22 33', locale = 'ar' where id = '11111111-1111-4111-8111-111111111111';
update public.profiles set full_name = 'User B', phone = '+213 555 44 55 66', locale = 'fr' where id = '22222222-2222-4222-8222-222222222222';
update public.profiles set full_name = 'Unconfirmed', phone = '0555000000' where id = '44444444-4444-4444-8444-444444444444';
update public.profiles set full_name = 'Admin', phone = '0555000001' where id = '33333333-3333-4333-8333-333333333333';
delete from public.profiles where id = '55555555-5555-4555-8555-555555555555';

insert into public.games (id, slug, name_ar, name_fr, reward_unit_code, reward_unit_name_ar, reward_unit_name_fr, is_active, sort_order) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'active-game', 'لعبة فعالة', 'Jeu actif', 'diamonds', 'جواهر', 'Diamants', true, 10),
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2', 'inactive-game', 'لعبة معطلة', 'Jeu inactif', 'coins', 'عملات', 'Pièces', false, 20);
insert into public.public_offers (id, game_id, name_ar, name_fr, reward_quantity, sale_price_dzd, is_published, sort_order) values
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', '100 جوهرة', '100 diamants', 100, 350, true, 10),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', '200 جوهرة', '200 diamants', 200, 650, true, 20),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'عرض مخفي', 'Offre masquée', 300, 900, false, 30),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb4', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2', 'عرض لعبة معطلة', 'Offre jeu inactif', 400, 1200, true, 40);

select is(
  (select proargnames from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'create_order'),
  array['p_client_request_id','p_offer_id','p_player_id','p_in_game_name','p_payment_method']::text[],
  'create_order exposes only authoritative-safe input parameters'
);
select ok(
  not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace, unnest(coalesce(p.proargnames, array[]::text[])) arg
    where n.nspname = 'public' and p.proname = 'create_order' and arg ~ '(price|reward_quantity|customer_)'
  ),
  'create_order accepts no caller-supplied price, reward, or customer snapshot parameters'
);

select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select throws_ok(
  $$select public.create_order('70000000-0000-4000-8000-000000000001','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1','player-1',null,'cash')$$,
  '42501', null, 'anonymous create_order is rejected'
);
select throws_ok(
  $$select * from public.get_my_order_timeline('70000000-0000-4000-8000-000000000100')$$,
  '42501', null, 'anonymous timeline access is rejected'
);
reset role;

select set_config('request.jwt.claim.sub', '44444444-4444-4444-8444-444444444444', true);
select set_config('request.jwt.claims', '{"sub":"44444444-4444-4444-8444-444444444444","role":"authenticated","app_metadata":{},"user_metadata":{}}', true);
set local role authenticated;
select throws_ok(
  $$select public.create_order('70000000-0000-4000-8000-000000000002','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1','player-1',null,'cash')$$,
  '42501', 'email must be confirmed before creating an order', 'unconfirmed email cannot create an order'
);
reset role;

select set_config('request.jwt.claim.sub', '55555555-5555-4555-8555-555555555555', true);
select set_config('request.jwt.claims', '{"sub":"55555555-5555-4555-8555-555555555555","role":"authenticated","app_metadata":{},"user_metadata":{}}', true);
set local role authenticated;
select throws_ok(
  $$select public.create_order('70000000-0000-4000-8000-000000000003','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1','player-1',null,'cash')$$,
  '22023', 'profile must be complete before creating an order', 'missing profile cannot create an order'
);
reset role;

select set_config('request.jwt.claim.sub', '66666666-6666-4666-8666-666666666666', true);
select set_config('request.jwt.claims', '{"sub":"66666666-6666-4666-8666-666666666666","role":"authenticated","app_metadata":{},"user_metadata":{}}', true);
set local role authenticated;
select throws_ok(
  $$select public.create_order('70000000-0000-4000-8000-000000000004','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1','player-1',null,'cash')$$,
  '22023', 'profile must be complete before creating an order', 'incomplete profile cannot create an order'
);
reset role;

select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
select set_config('request.jwt.claims', '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated","app_metadata":{},"user_metadata":{}}', true);
set local role authenticated;
select throws_ok($$select public.create_order('70000000-0000-4000-8000-000000000005','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1','  ',null,'cash')$$, '22023', 'player_id must contain 3 to 64 characters', 'blank player_id is rejected');
select throws_ok($$select public.create_order('70000000-0000-4000-8000-000000000006','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1','ab',null,'cash')$$, '22023', 'player_id must contain 3 to 64 characters', 'short player_id is rejected');
select throws_ok($$select public.create_order('70000000-0000-4000-8000-000000000007','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1',repeat('p',65),null,'cash')$$, '22023', 'player_id must contain 3 to 64 characters', 'long player_id is rejected');
select throws_ok($$select public.create_order('70000000-0000-4000-8000-000000000008','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1','player-1',repeat('n',65),'cash')$$, '22023', 'in_game_name must not exceed 64 characters', 'long in_game_name is rejected');
select throws_ok($$select public.create_order('70000000-0000-4000-8000-000000000009','99999999-9999-4999-8999-999999999999','player-1',null,'cash')$$, 'P0002', 'published offer not found', 'missing offer is rejected');
select throws_ok($$select public.create_order('70000000-0000-4000-8000-000000000010','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3','player-1',null,'cash')$$, 'P0002', 'published offer not found', 'hidden offer is rejected');
select throws_ok($$select public.create_order('70000000-0000-4000-8000-000000000011','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb4','player-1',null,'cash')$$, 'P0002', 'active game not found', 'offer for inactive game is rejected');

select ok(
  (public.create_order('70000000-0000-4000-8000-000000000100','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1',' PLAYER-42 ','   ','cash')).id is not null,
  'valid offer creates an order'
);
select is((select count(*)::integer from public.orders where client_request_id = '70000000-0000-4000-8000-000000000100'), 1, 'valid create_order inserts one order');
select is((select player_id from public.orders where client_request_id = '70000000-0000-4000-8000-000000000100'), 'PLAYER-42', 'player_id is trimmed');
select is((select in_game_name from public.orders where client_request_id = '70000000-0000-4000-8000-000000000100'), null, 'blank in_game_name normalizes to null');
select is((select sale_price_dzd_snapshot from public.orders where client_request_id = '70000000-0000-4000-8000-000000000100'), 350, 'sale price snapshot comes from the offer');
select is((select reward_quantity_snapshot from public.orders where client_request_id = '70000000-0000-4000-8000-000000000100'), 100, 'reward quantity snapshot comes from the offer');
select is((select game_name_fr_snapshot from public.orders where client_request_id = '70000000-0000-4000-8000-000000000100'), 'Jeu actif', 'game name snapshot comes from the game');
select is((select offer_name_fr_snapshot from public.orders where client_request_id = '70000000-0000-4000-8000-000000000100'), '100 diamants', 'offer name snapshot comes from the offer');
select is((select reward_unit_name_fr_snapshot from public.orders where client_request_id = '70000000-0000-4000-8000-000000000100'), 'Diamants', 'reward unit snapshot comes from the game');
select is((select customer_name_snapshot from public.orders where client_request_id = '70000000-0000-4000-8000-000000000100'), 'User A', 'customer name snapshot comes from the profile');
select is((select customer_email_snapshot from public.orders where client_request_id = '70000000-0000-4000-8000-000000000100'), 'user-a@test.invalid', 'customer email snapshot comes from auth.users');
select is((select customer_phone_snapshot from public.orders where client_request_id = '70000000-0000-4000-8000-000000000100'), '+213 555 11 22 33', 'customer phone snapshot comes from the profile');
select is((select count(*)::integer from public.order_status_history h join public.orders o on o.id = h.order_id where o.client_request_id = '70000000-0000-4000-8000-000000000100' and h.event_type = 'created'), 0, 'customer cannot read history directly through RLS');
reset role;

update public.public_offers set name_fr = 'Offre modifiée', reward_quantity = 999, sale_price_dzd = 9999 where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1';
update public.games set name_fr = 'Jeu modifié', reward_unit_name_fr = 'Unités modifiées' where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
select is((select sale_price_dzd_snapshot from public.orders where client_request_id = '70000000-0000-4000-8000-000000000100'), 350, 'offer price changes do not mutate old snapshots');
select is((select game_name_fr_snapshot from public.orders where client_request_id = '70000000-0000-4000-8000-000000000100'), 'Jeu actif', 'game changes do not mutate old snapshots');
select is((select count(*)::integer from public.order_status_history h join public.orders o on o.id = h.order_id where o.client_request_id = '70000000-0000-4000-8000-000000000100'), 1, 'creation history is written exactly once');
create temporary table pg_temp.created_order_snapshot as
select id, created_at
from public.orders
where user_id = '11111111-1111-4111-8111-111111111111'
  and client_request_id = '70000000-0000-4000-8000-000000000100';
grant select on table pg_temp.created_order_snapshot to authenticated;

select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
select set_config('request.jwt.claims', '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated","app_metadata":{},"user_metadata":{}}', true);
set local role authenticated;
select is(
  (public.create_order('70000000-0000-4000-8000-000000000100','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1','PLAYER-42',null,'cash')).id,
  (select id from public.orders where client_request_id = '70000000-0000-4000-8000-000000000100'),
  'same idempotency key and normalized payload returns the same order id'
);
select is((select count(*)::integer from public.orders where client_request_id = '70000000-0000-4000-8000-000000000100'), 1, 'idempotent retry creates no second order');
select is(
  (select o.created_at from public.orders o join pg_temp.created_order_snapshot s on s.id = o.id),
  (select created_at from pg_temp.created_order_snapshot),
  'idempotent retry preserves the original created_at'
);
select is(
  (select count(*)::integer from public.get_my_order_timeline((select id from public.orders where client_request_id = '70000000-0000-4000-8000-000000000100'))),
  1,
  'idempotent retry creates no second history row'
);
select throws_ok($$select public.create_order('70000000-0000-4000-8000-000000000100','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2','PLAYER-42',null,'cash')$$, '23505', 'client_request_id conflict: payload differs from the existing order', 'same key with a different offer is rejected');
select throws_ok($$select public.create_order('70000000-0000-4000-8000-000000000100','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1','DIFFERENT',null,'cash')$$, '23505', 'client_request_id conflict: payload differs from the existing order', 'same key with a different player_id is rejected');
select throws_ok($$select public.create_order('70000000-0000-4000-8000-000000000100','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1','PLAYER-42',null,'transfer')$$, '23505', 'client_request_id conflict: payload differs from the existing order', 'same key with a different payment method is rejected');
select results_eq(
  $$select key::text collate "C" from jsonb_object_keys(to_jsonb((select t from public.get_my_order_timeline((select id from public.orders where client_request_id = '70000000-0000-4000-8000-000000000100')) t limit 1))) key order by key$$,
  $$values ('created_at'::text collate "C"), ('event_type'::text collate "C"), ('order_status'::text collate "C"), ('payment_status'::text collate "C"), ('public_message'::text collate "C")$$,
  'timeline exposes only the five public fields'
);
reset role;

select set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
select set_config('request.jwt.claims', '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated","app_metadata":{},"user_metadata":{}}', true);
set local role authenticated;
select ok((public.create_order('70000000-0000-4000-8000-000000000100','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2','PLAYER-B',null,'cash')).id is not null, 'different users can reuse the same client_request_id');
select throws_ok(
  $$select * from public.get_my_order_timeline((select id from public.orders where user_id = '11111111-1111-4111-8111-111111111111' and client_request_id = '70000000-0000-4000-8000-000000000100'))$$,
  '42501', 'order timeline is not available', 'user B cannot read user A timeline'
);
reset role;

select set_config('request.jwt.claim.sub', '33333333-3333-4333-8333-333333333333', true);
select set_config('request.jwt.claims', '{"sub":"33333333-3333-4333-8333-333333333333","role":"authenticated","app_metadata":{"role":"admin"},"user_metadata":{}}', true);
set local role authenticated;
select throws_ok(
  $$select * from public.get_my_order_timeline((select id from public.orders where user_id = '11111111-1111-4111-8111-111111111111' and client_request_id = '70000000-0000-4000-8000-000000000100'))$$,
  '42501', 'order timeline is not available', 'admin cannot bypass owner-only customer timeline'
);
reset role;

select is((select count(*)::integer from public.orders where client_request_id = '70000000-0000-4000-8000-000000000100'), 2, 'same idempotency key is scoped per user');
select ok(not ('internal_note' = any (array(select jsonb_object_keys(to_jsonb(o)) from public.orders o limit 1))), 'orders expose no internal_note field');

select * from finish();
rollback;
