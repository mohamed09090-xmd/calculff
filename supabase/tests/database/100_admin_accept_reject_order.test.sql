begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_catalog;

select plan(32);

select ok(to_regprocedure('public.admin_accept_order(uuid,text)') is not null, 'accept RPC exists');
select ok(to_regprocedure('public.admin_reject_order(uuid,text)') is not null, 'reject RPC exists');
select is(pg_get_function_result(to_regprocedure('public.admin_accept_order(uuid,text)')), 'TABLE(order_status order_status_type, payment_status payment_status_type)', 'accept returns statuses only');
select is(pg_get_function_result(to_regprocedure('public.admin_reject_order(uuid,text)')), 'TABLE(order_status order_status_type, payment_status payment_status_type)', 'reject returns statuses only');
select ok((select prosecdef from pg_proc where oid = to_regprocedure('public.admin_accept_order(uuid,text)')), 'accept is SECURITY DEFINER');
select ok((select prosecdef from pg_proc where oid = to_regprocedure('public.admin_reject_order(uuid,text)')), 'reject is SECURITY DEFINER');
select is((select proconfig from pg_proc where oid = to_regprocedure('public.admin_accept_order(uuid,text)')), array['search_path=""']::text[], 'accept has empty search_path');
select is((select proconfig from pg_proc where oid = to_regprocedure('public.admin_reject_order(uuid,text)')), array['search_path=""']::text[], 'reject has empty search_path');
select ok(has_function_privilege('authenticated', 'public.admin_accept_order(uuid,text)', 'EXECUTE'), 'authenticated can execute accept');
select ok(has_function_privilege('authenticated', 'public.admin_reject_order(uuid,text)', 'EXECUTE'), 'authenticated can execute reject');
select ok(not has_function_privilege('anon', 'public.admin_accept_order(uuid,text)', 'EXECUTE'), 'anon cannot execute accept');
select ok(not has_function_privilege('anon', 'public.admin_reject_order(uuid,text)', 'EXECUTE'), 'anon cannot execute reject');

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('61111111-1111-4111-8111-111111111111', 'authenticated', 'authenticated', 'actions-user@test.invalid', crypt('password-a', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('63333333-3333-4333-8333-333333333333', 'authenticated', 'authenticated', 'actions-admin@test.invalid', crypt('password-admin', gen_salt('bf')), now(), '{"provider":"email","providers":["email"],"role":"admin"}', '{}', now(), now());
update public.profiles set full_name = 'Actions User', phone = '0555000061' where id = '61111111-1111-4111-8111-111111111111';
update public.profiles set full_name = 'Actions Admin', phone = '0555000063' where id = '63333333-3333-4333-8333-333333333333';

insert into public.games (
  id, slug, name_ar, name_fr, reward_unit_code,
  reward_unit_name_ar, reward_unit_name_fr, is_active
) values (
  '6aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'actions-game',
  'لعبة الإجراءات', 'Jeu actions', 'diamonds', 'جواهر', 'Diamants', true
);
insert into public.public_offers (
  id, game_id, name_ar, name_fr, reward_quantity,
  sale_price_dzd, is_published
) values (
  '6bbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1',
  '6aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
  'عرض الإجراءات', 'Offre actions', 100, 350, true
);

create function pg_temp.make_action_order(
  p_id uuid,
  p_method public.payment_method_type,
  p_order_status public.order_status_type,
  p_payment_status public.payment_status_type,
  p_proof text default null
) returns void
language sql
as $$
  insert into public.orders (
    id, user_id, client_request_id, game_id, offer_id, player_id,
    payment_method, order_status, payment_status, payment_proof_path,
    game_name_ar_snapshot, game_name_fr_snapshot,
    reward_unit_code_snapshot, reward_unit_name_ar_snapshot,
    reward_unit_name_fr_snapshot, offer_name_ar_snapshot,
    offer_name_fr_snapshot, reward_quantity_snapshot, sale_price_dzd_snapshot,
    customer_name_snapshot, customer_email_snapshot, customer_phone_snapshot,
    completed_at
  ) values (
    p_id, '61111111-1111-4111-8111-111111111111', p_id,
    '6aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
    '6bbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1', 'PLAYER-ACTIONS',
    p_method, p_order_status, p_payment_status, p_proof,
    'لعبة الإجراءات', 'Jeu actions', 'diamonds', 'جواهر', 'Diamants',
    'عرض الإجراءات', 'Offre actions', 100, 350,
    'Actions User', 'actions-user@test.invalid', '0555000061',
    case when p_order_status = 'completed' then now() else null end
  );
$$;

select pg_temp.make_action_order('60000000-0000-4000-8000-000000000061', 'cash', 'new', 'awaiting_payment');
select pg_temp.make_action_order('60000000-0000-4000-8000-000000000062', 'transfer', 'new', 'under_review', '61111111-1111-4111-8111-111111111111/60000000-0000-4000-8000-000000000062/proof_aaaaaaaaaaaaaaaa.jpg');
select pg_temp.make_action_order('60000000-0000-4000-8000-000000000063', 'transfer', 'processing', 'under_review', '61111111-1111-4111-8111-111111111111/60000000-0000-4000-8000-000000000063/proof_bbbbbbbbbbbbbbbb.png');
select pg_temp.make_action_order('60000000-0000-4000-8000-000000000064', 'cash', 'processing', 'paid');
select pg_temp.make_action_order('60000000-0000-4000-8000-000000000065', 'cash', 'completed', 'paid');

select set_config('request.jwt.claim.sub', '61111111-1111-4111-8111-111111111111', true);
select set_config('request.jwt.claims', '{"sub":"61111111-1111-4111-8111-111111111111","role":"authenticated","app_metadata":{},"user_metadata":{}}', true);
set local role authenticated;
select throws_ok($$select * from public.admin_accept_order('60000000-0000-4000-8000-000000000061')$$, '42501', 'admin access required', 'ordinary user cannot accept');
select throws_ok($$select * from public.admin_reject_order('60000000-0000-4000-8000-000000000061')$$, '42501', 'admin access required', 'ordinary user cannot reject');
reset role;

select set_config('request.jwt.claim.sub', '63333333-3333-4333-8333-333333333333', true);
select set_config('request.jwt.claims', '{"sub":"63333333-3333-4333-8333-333333333333","role":"authenticated","app_metadata":{"role":"admin"},"user_metadata":{}}', true);
set local role authenticated;

select lives_ok($$select * from public.admin_accept_order('60000000-0000-4000-8000-000000000061','تم قبول الطلب')$$, 'cash order acceptance succeeds');
select ok((select order_status = 'processing' and payment_status = 'paid' from public.orders where id = '60000000-0000-4000-8000-000000000061'), 'cash acceptance updates payment and execution');
select is((select public_status_message from public.orders where id = '60000000-0000-4000-8000-000000000061'), 'تم قبول الطلب', 'accept stores public message');
select is((select count(*)::integer from public.order_status_history where order_id = '60000000-0000-4000-8000-000000000061'), 3, 'accept writes payment accepted and processing history');
select lives_ok($$select * from public.admin_accept_order('60000000-0000-4000-8000-000000000061','ignored duplicate')$$, 'accept is idempotent for processing paid order');
select is((select count(*)::integer from public.order_status_history where order_id = '60000000-0000-4000-8000-000000000061'), 3, 'duplicate accept writes no history');

select results_eq(
  $$select order_status::text, payment_status::text from public.admin_accept_order('60000000-0000-4000-8000-000000000062','تم التنفيذ')$$,
  $$values ('processing'::text, 'paid'::text)$$,
  'transfer acceptance returns only final statuses'
);
select lives_ok($$select * from public.admin_reject_order('60000000-0000-4000-8000-000000000063','رُفض الإثبات')$$, 'proof rejection succeeds');
select ok((select order_status = 'rejected' and payment_status = 'proof_rejected' from public.orders where id = '60000000-0000-4000-8000-000000000063'), 'proof rejection updates both states');
select is((select public_status_message from public.orders where id = '60000000-0000-4000-8000-000000000063'), 'رُفض الإثبات', 'reject stores public message');
select lives_ok($$select * from public.admin_reject_order('60000000-0000-4000-8000-000000000063','ignored duplicate')$$, 'reject is idempotent');
select is((select count(*)::integer from public.order_status_history where order_id = '60000000-0000-4000-8000-000000000063'), 2, 'duplicate reject writes no history');

select lives_ok($$select * from public.admin_reject_order('60000000-0000-4000-8000-000000000064','سيتم الاسترداد')$$, 'paid rejection succeeds');
select ok((select order_status = 'rejected' and payment_status = 'refund_pending' and refund_started_at is not null from public.orders where id = '60000000-0000-4000-8000-000000000064'), 'paid rejection starts refund atomically');
select throws_ok($$select * from public.admin_accept_order('60000000-0000-4000-8000-000000000065')$$, '22023', 'final orders cannot be accepted', 'completed order cannot be accepted');
select throws_ok($$select * from public.admin_reject_order('60000000-0000-4000-8000-000000000065')$$, '22023', 'final orders cannot be rejected', 'completed order cannot be rejected');
select throws_ok($$select * from public.admin_accept_order('60000000-0000-4000-8000-000000000099')$$, 'P0002', 'order not found', 'missing order is rejected safely');
select throws_ok($$select * from public.admin_reject_order('60000000-0000-4000-8000-000000000099')$$, 'P0002', 'order not found', 'missing rejection is rejected safely');

reset role;

select * from finish();
rollback;
