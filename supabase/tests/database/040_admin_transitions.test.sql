begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_catalog;

select plan(67);

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('11111111-1111-4111-8111-111111111111', 'authenticated', 'authenticated', 'user-a@test.invalid', crypt('password-a', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('33333333-3333-4333-8333-333333333333', 'authenticated', 'authenticated', 'admin@test.invalid', crypt('password-admin', gen_salt('bf')), now(), '{"provider":"email","providers":["email"],"role":"admin"}', '{}', now(), now()),
  ('77777777-7777-4777-8777-777777777777', 'authenticated', 'authenticated', 'fake-admin@test.invalid', crypt('password-fake', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"role":"admin"}', now(), now());
update public.profiles set full_name = 'User A', phone = '0555112233' where id = '11111111-1111-4111-8111-111111111111';
update public.profiles set full_name = 'Admin', phone = '0555000001' where id = '33333333-3333-4333-8333-333333333333';
update public.profiles set full_name = 'Fake Admin', phone = '0555000002' where id = '77777777-7777-4777-8777-777777777777';

insert into public.games (id, slug, name_ar, name_fr, reward_unit_code, reward_unit_name_ar, reward_unit_name_fr, is_active) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'active-game', 'لعبة فعالة', 'Jeu actif', 'diamonds', 'جواهر', 'Diamants', true);
insert into public.public_offers (id, game_id, name_ar, name_fr, reward_quantity, sale_price_dzd, is_published) values
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', '100 جوهرة', '100 diamants', 100, 350, true);

create function pg_temp.make_order(
  p_id uuid,
  p_method public.payment_method_type default 'cash',
  p_order_status public.order_status_type default 'new',
  p_payment_status public.payment_status_type default 'awaiting_payment',
  p_proof text default null,
  p_completed_at timestamptz default null,
  p_refund_started_at timestamptz default null,
  p_refunded_at timestamptz default null
) returns void
language sql
as $$
  insert into public.orders (
    id, user_id, client_request_id, game_id, offer_id, player_id, in_game_name,
    payment_method, order_status, payment_status, payment_proof_path,
    game_name_ar_snapshot, game_name_fr_snapshot,
    reward_unit_code_snapshot, reward_unit_name_ar_snapshot, reward_unit_name_fr_snapshot,
    offer_name_ar_snapshot, offer_name_fr_snapshot,
    reward_quantity_snapshot, sale_price_dzd_snapshot,
    customer_name_snapshot, customer_email_snapshot, customer_phone_snapshot,
    completed_at, refund_started_at, refunded_at
  ) values (
    p_id, '11111111-1111-4111-8111-111111111111', p_id,
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1',
    'PLAYER-1', null, p_method, p_order_status, p_payment_status, p_proof,
    'لعبة فعالة', 'Jeu actif', 'diamonds', 'جواهر', 'Diamants',
    '100 جوهرة', '100 diamants', 100, 350,
    'User A', 'user-a@test.invalid', '0555112233',
    p_completed_at, p_refund_started_at, p_refunded_at
  );
$$;

select pg_temp.make_order('80000000-0000-4000-8000-000000000001');
select pg_temp.make_order('80000000-0000-4000-8000-000000000002');
select pg_temp.make_order('80000000-0000-4000-8000-000000000003');
select pg_temp.make_order('80000000-0000-4000-8000-000000000004');
select pg_temp.make_order('80000000-0000-4000-8000-000000000005');
select pg_temp.make_order('80000000-0000-4000-8000-000000000006');
select pg_temp.make_order('80000000-0000-4000-8000-000000000007');
select pg_temp.make_order('80000000-0000-4000-8000-000000000008', 'transfer');
select pg_temp.make_order('80000000-0000-4000-8000-000000000009', 'transfer', 'new', 'awaiting_payment', '11111111-1111-4111-8111-111111111111/80000000-0000-4000-8000-000000000009/proof_0000000000000009.jpg');
select pg_temp.make_order('80000000-0000-4000-8000-000000000010');
select pg_temp.make_order('80000000-0000-4000-8000-000000000011', 'cash', 'new', 'paid');
select pg_temp.make_order('80000000-0000-4000-8000-000000000012', 'cash', 'new', 'paid');
select pg_temp.make_order('80000000-0000-4000-8000-000000000013', 'cash', 'processing', 'paid');
select pg_temp.make_order('80000000-0000-4000-8000-000000000014');
select pg_temp.make_order('80000000-0000-4000-8000-000000000015');

select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
select set_config('request.jwt.claims', '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated","app_metadata":{},"user_metadata":{}}', true);
set local role authenticated;
select throws_ok($$select public.admin_set_order_status('80000000-0000-4000-8000-000000000001','accepted')$$, '42501', 'admin access required', 'ordinary user cannot execute admin order transition');
select throws_ok($$select public.admin_set_payment_status('80000000-0000-4000-8000-000000000001','paid')$$, '42501', 'admin access required', 'ordinary user cannot execute admin payment transition');
select throws_ok($$select public.admin_mark_refunded('80000000-0000-4000-8000-000000000001')$$, '42501', 'admin access required', 'ordinary user cannot mark refunds');
select throws_ok($$select public.admin_add_order_internal_note('80000000-0000-4000-8000-000000000001','hidden')$$, '42501', 'admin access required', 'ordinary user cannot add internal notes');
select throws_ok($$select * from public.admin_list_order_internal_notes('80000000-0000-4000-8000-000000000001')$$, '42501', 'admin access required', 'ordinary user cannot list internal notes');
reset role;

select set_config('request.jwt.claim.sub', '77777777-7777-4777-8777-777777777777', true);
select set_config('request.jwt.claims', '{"sub":"77777777-7777-4777-8777-777777777777","role":"authenticated","app_metadata":{},"user_metadata":{"role":"admin"}}', true);
set local role authenticated;
select throws_ok($$select public.admin_set_order_status('80000000-0000-4000-8000-000000000001','accepted')$$, '42501', 'admin access required', 'user_metadata admin claim grants no authority');
reset role;

select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select throws_ok($$select public.admin_set_order_status('80000000-0000-4000-8000-000000000001','accepted')$$, '42501', null, 'anonymous admin transition is rejected');
select throws_ok($$select public.admin_add_order_internal_note('80000000-0000-4000-8000-000000000001','hidden')$$, '42501', null, 'anonymous internal note is rejected');
select throws_ok($$select * from public.admin_list_order_internal_notes('80000000-0000-4000-8000-000000000001')$$, '42501', null, 'anonymous internal note listing is rejected');
select throws_ok($$select public.admin_set_payment_status('80000000-0000-4000-8000-000000000001','paid')$$, '42501', null, 'anonymous payment transition is rejected');
select throws_ok($$select public.admin_mark_refunded('80000000-0000-4000-8000-000000000001')$$, '42501', null, 'anonymous refund transition is rejected');
reset role;

select set_config('request.jwt.claim.sub', '33333333-3333-4333-8333-333333333333', true);
select set_config('request.jwt.claims', '{"sub":"33333333-3333-4333-8333-333333333333","role":"authenticated","app_metadata":{"role":"admin"},"user_metadata":{}}', true);
set local role authenticated;

select lives_ok($$select public.admin_set_order_status('80000000-0000-4000-8000-000000000001','accepted','تم قبول الطلب','accepted internally')$$, 'new to accepted succeeds');
select is((select order_status from public.orders where id = '80000000-0000-4000-8000-000000000001'), 'accepted'::public.order_status_type, 'order status becomes accepted');
select is((select public_status_message from public.orders where id = '80000000-0000-4000-8000-000000000001'), 'تم قبول الطلب', 'public message is stored separately');
select is((select note from private.order_internal_notes where order_id = '80000000-0000-4000-8000-000000000001'), 'accepted internally', 'internal note is stored only in private table');
select lives_ok($$select public.admin_set_order_status('80000000-0000-4000-8000-000000000001','processing')$$, 'accepted to processing succeeds');
select throws_ok($$select public.admin_set_order_status('80000000-0000-4000-8000-000000000001','completed')$$, '22023', 'an order can be completed only after payment is paid', 'processing cannot complete before payment');
select lives_ok($$select public.admin_set_payment_status('80000000-0000-4000-8000-000000000001','paid')$$, 'cash awaiting_payment to paid succeeds');
select lives_ok($$select public.admin_set_order_status('80000000-0000-4000-8000-000000000001','completed')$$, 'processing to completed succeeds when paid');
select ok((select completed_at is not null from public.orders where id = '80000000-0000-4000-8000-000000000001'), 'completed_at is populated');
select throws_ok($$select public.admin_set_order_status('80000000-0000-4000-8000-000000000001','processing')$$, '22023', 'invalid order status transition', 'completed is terminal');

select throws_ok($$select public.admin_set_order_status('80000000-0000-4000-8000-000000000002','completed')$$, '22023', 'invalid order status transition', 'new to completed is rejected');
select lives_ok($$select public.admin_set_order_status('80000000-0000-4000-8000-000000000002','accepted')$$, 'new to accepted succeeds for second order');
select throws_ok($$select public.admin_set_order_status('80000000-0000-4000-8000-000000000002','completed')$$, '22023', 'invalid order status transition', 'accepted to completed is rejected');
select lives_ok($$select public.admin_set_order_status('80000000-0000-4000-8000-000000000003','rejected')$$, 'new to rejected succeeds when unpaid');
select throws_ok($$select public.admin_set_order_status('80000000-0000-4000-8000-000000000003','accepted')$$, '22023', 'invalid order status transition', 'rejected is terminal');
select lives_ok($$select public.admin_set_order_status('80000000-0000-4000-8000-000000000004','cancelled')$$, 'new to cancelled succeeds when unpaid');
select throws_ok($$select public.admin_set_order_status('80000000-0000-4000-8000-000000000004','accepted')$$, '22023', 'invalid order status transition', 'cancelled is terminal');
select lives_ok($$select public.admin_set_order_status('80000000-0000-4000-8000-000000000005','accepted')$$, 'prepare processing cancellation');
select lives_ok($$select public.admin_set_order_status('80000000-0000-4000-8000-000000000005','processing')$$, 'prepare processing cancellation step two');
select lives_ok($$select public.admin_set_order_status('80000000-0000-4000-8000-000000000005','cancelled')$$, 'processing to cancelled follows the current contract');

select lives_ok($$select public.admin_set_order_status('80000000-0000-4000-8000-000000000006','accepted')$$, 'prepare no-op status test');
select is((select count(*)::integer from public.order_status_history where order_id = '80000000-0000-4000-8000-000000000006'), 1, 'first status change writes one history row');
select lives_ok($$select public.admin_set_order_status('80000000-0000-4000-8000-000000000006','accepted')$$, 'status no-op returns successfully');
select is((select count(*)::integer from public.order_status_history where order_id = '80000000-0000-4000-8000-000000000006'), 1, 'status no-op writes no duplicate history');

select throws_ok($$select public.admin_set_payment_status('80000000-0000-4000-8000-000000000007','under_review')$$, '22023', 'cash payments do not use proof review', 'cash cannot enter under_review');
select lives_ok($$select public.admin_set_payment_status('80000000-0000-4000-8000-000000000007','paid')$$, 'cash awaiting_payment to paid succeeds');
select throws_ok($$select public.admin_set_payment_status('80000000-0000-4000-8000-000000000007','awaiting_payment')$$, '22023', 'invalid payment status transition', 'paid cannot return to awaiting_payment');
select lives_ok($$select public.admin_set_payment_status('80000000-0000-4000-8000-000000000007','paid')$$, 'payment no-op returns successfully');
select is((select count(*)::integer from public.order_status_history where order_id = '80000000-0000-4000-8000-000000000007'), 1, 'payment no-op writes no duplicate history');

select throws_ok($$select public.admin_set_payment_status('80000000-0000-4000-8000-000000000008','under_review')$$, '22023', 'a valid transfer proof is required', 'transfer cannot enter under_review without proof');
select throws_ok($$select public.admin_set_payment_status('80000000-0000-4000-8000-000000000008','paid')$$, '22023', 'a valid transfer proof is required', 'transfer cannot become paid without proof');
select lives_ok($$select public.admin_set_payment_status('80000000-0000-4000-8000-000000000009','under_review')$$, 'transfer with proof can enter under_review');
select lives_ok($$select public.admin_set_payment_status('80000000-0000-4000-8000-000000000009','proof_rejected')$$, 'under_review can become proof_rejected');
select throws_ok($$select public.admin_set_payment_status('80000000-0000-4000-8000-000000000009','paid')$$, '22023', 'invalid payment status transition', 'proof_rejected cannot become paid directly');

select lives_ok($$select public.admin_add_order_internal_note('80000000-0000-4000-8000-000000000010','  private note  ')$$, 'admin can add internal note');
select is((select note from private.order_internal_notes where order_id = '80000000-0000-4000-8000-000000000010'), 'private note', 'internal note is trimmed');
select is((select count(*)::integer from public.admin_list_order_internal_notes('80000000-0000-4000-8000-000000000010')), 1, 'admin can list internal notes');
select throws_ok($$select public.admin_add_order_internal_note('80000000-0000-4000-8000-000000000010','   ')$$, '22023', 'internal note must contain 1 to 2000 characters', 'blank internal note is rejected');
select throws_ok($$select public.admin_add_order_internal_note('80000000-0000-4000-8000-000000000010',repeat('x',2001))$$, '22023', 'internal note must contain 1 to 2000 characters', 'oversized internal note is rejected');

select lives_ok($$select public.admin_set_order_status('80000000-0000-4000-8000-000000000011','rejected','سيتم رد المبلغ','refund private reason')$$, 'rejecting a paid order succeeds atomically');
select is((select order_status from public.orders where id = '80000000-0000-4000-8000-000000000011'), 'rejected'::public.order_status_type, 'paid rejection sets order_status rejected');
select is((select payment_status from public.orders where id = '80000000-0000-4000-8000-000000000011'), 'refund_pending'::public.payment_status_type, 'paid rejection sets refund_pending');
select ok((select refund_started_at is not null from public.orders where id = '80000000-0000-4000-8000-000000000011'), 'paid rejection sets refund_started_at');
select is((select count(*)::integer from public.order_status_history where order_id = '80000000-0000-4000-8000-000000000011' and event_type = 'refund_started'), 1, 'refund_started history is recorded once');
select lives_ok($$select public.admin_mark_refunded('80000000-0000-4000-8000-000000000011','تم رد المبلغ','refund completed internally')$$, 'refund_pending can be marked refunded');
select ok((select payment_status = 'refunded' and refunded_at is not null from public.orders where id = '80000000-0000-4000-8000-000000000011'), 'refunded status and timestamp are populated');
select throws_ok($$select public.admin_set_payment_status('80000000-0000-4000-8000-000000000011','paid')$$, '22023', 'payment status cannot change after the order is final', 'refunded order cannot become paid');
select throws_ok($$select public.admin_set_order_status('80000000-0000-4000-8000-000000000011','completed')$$, '22023', 'invalid order status transition', 'refunded rejected order cannot become completed');

select lives_ok($$select public.admin_set_order_status('80000000-0000-4000-8000-000000000012','cancelled')$$, 'cancelling a paid order starts refund');
select ok((select order_status = 'cancelled' and payment_status = 'refund_pending' and refund_started_at is not null from public.orders where id = '80000000-0000-4000-8000-000000000012'), 'paid cancellation atomically enters refund_pending');
select throws_ok($$select public.admin_mark_refunded('80000000-0000-4000-8000-000000000010')$$, '22023', 'only refund_pending orders can be marked refunded', 'non-refund_pending order cannot be marked refunded');

select lives_ok($$select public.admin_set_order_status('80000000-0000-4000-8000-000000000013','completed')$$, 'paid processing order can complete');
select throws_ok($$select public.admin_set_order_status('80000000-0000-4000-8000-000000000013','rejected')$$, '22023', 'invalid order status transition', 'completed order cannot be rejected');
select throws_ok($$select public.admin_set_order_status('80000000-0000-4000-8000-000000000013','cancelled')$$, '22023', 'invalid order status transition', 'completed order cannot be cancelled');

reset role;

select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
select set_config('request.jwt.claims', '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated","app_metadata":{},"user_metadata":{}}', true);
set local role authenticated;
select results_eq(
  $$select public_message::text from public.get_my_order_timeline('80000000-0000-4000-8000-000000000001') where public_message is not null order by created_at limit 1$$,
  $$values ('تم قبول الطلب'::text)$$,
  'customer timeline exposes public message'
);
select ok(not exists(select 1 from public.get_my_order_timeline('80000000-0000-4000-8000-000000000001') where public_message = 'accepted internally'), 'customer timeline never exposes internal note');
reset role;

select * from finish();
rollback;
