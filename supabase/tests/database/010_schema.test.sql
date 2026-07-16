begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_catalog;

select plan(32);

select ok(to_regtype('public.order_status_type') is not null, 'order_status_type exists');
select ok(to_regtype('public.payment_status_type') is not null, 'payment_status_type exists');
select ok(to_regtype('public.payment_method_type') is not null, 'payment_method_type exists');
select ok(to_regtype('public.status_event_type') is not null, 'status_event_type exists');

select results_eq(
  $$select enumlabel::text from pg_enum where enumtypid = 'public.order_status_type'::regtype order by enumsortorder$$,
  $$values ('new'::text), ('accepted'), ('processing'), ('completed'), ('rejected'), ('cancelled')$$,
  'order status enum labels match the contract'
);
select results_eq(
  $$select enumlabel::text from pg_enum where enumtypid = 'public.payment_status_type'::regtype order by enumsortorder$$,
  $$values ('awaiting_payment'::text), ('under_review'), ('paid'), ('proof_rejected'), ('refund_pending'), ('refunded')$$,
  'payment status enum labels include refund states'
);
select results_eq(
  $$select enumlabel::text from pg_enum where enumtypid = 'public.payment_method_type'::regtype order by enumsortorder$$,
  $$values ('cash'::text), ('transfer')$$,
  'payment method enum labels match the contract'
);
select results_eq(
  $$select enumlabel::text from pg_enum where enumtypid = 'public.status_event_type'::regtype order by enumsortorder$$,
  $$values ('created'::text), ('order_changed'), ('payment_changed'), ('proof_attached'), ('refund_started'), ('refunded')$$,
  'status event enum labels match the contract'
);

select ok(to_regclass('public.profiles') is not null, 'profiles table exists');
select ok(to_regclass('public.games') is not null, 'games table exists');
select ok(to_regclass('public.public_offers') is not null, 'public_offers table exists');
select ok(to_regclass('public.orders') is not null, 'orders table exists');
select ok(to_regclass('public.order_status_history') is not null, 'order_status_history table exists');
select ok(to_regclass('private.order_internal_notes') is not null, 'private order_internal_notes table exists');
select ok(to_regclass('public.device_tokens') is null and to_regclass('private.device_tokens') is null, 'device_tokens does not exist');

select results_eq(
  $$select column_name::text from information_schema.columns where table_schema = 'public' and table_name = 'orders' and column_name in ('client_request_id','game_name_ar_snapshot','game_name_fr_snapshot','reward_unit_code_snapshot','reward_unit_name_ar_snapshot','reward_unit_name_fr_snapshot','offer_name_ar_snapshot','offer_name_fr_snapshot','reward_quantity_snapshot','sale_price_dzd_snapshot','customer_name_snapshot','customer_email_snapshot','customer_phone_snapshot','refund_started_at','refunded_at') order by column_name$$,
  $$values ('client_request_id'::text), ('customer_email_snapshot'), ('customer_name_snapshot'), ('customer_phone_snapshot'), ('game_name_ar_snapshot'), ('game_name_fr_snapshot'), ('offer_name_ar_snapshot'), ('offer_name_fr_snapshot'), ('refund_started_at'), ('refunded_at'), ('reward_quantity_snapshot'), ('reward_unit_code_snapshot'), ('reward_unit_name_ar_snapshot'), ('reward_unit_name_fr_snapshot'), ('sale_price_dzd_snapshot')$$,
  'orders contains idempotency, snapshot, and refund columns'
);
select results_eq(
  $$select column_name::text from information_schema.columns where table_schema = 'public' and table_name = 'profiles' order by ordinal_position$$,
  $$values ('id'::text), ('email'), ('full_name'), ('phone'), ('locale'), ('is_complete'), ('created_at'), ('updated_at')$$,
  'profiles columns match the public contract'
);
select results_eq(
  $$select column_name::text from information_schema.columns where table_schema = 'private' and table_name = 'order_internal_notes' order by ordinal_position$$,
  $$values ('id'::text), ('order_id'), ('author_user_id'), ('note'), ('created_at')$$,
  'internal notes stay in the private schema'
);
select is(
  (select count(*)::integer from information_schema.columns where table_schema = 'public' and table_name = 'public_offers' and column_name ~ '(cost|profit|stock|inventory)'),
  0,
  'public_offers exposes no cost, profit, stock, or inventory columns'
);

select ok(
  exists (
    select 1 from pg_constraint
    where conrelid = 'public.orders'::regclass
      and contype = 'u'
      and pg_get_constraintdef(oid) = 'UNIQUE (user_id, client_request_id)'
  ),
  'orders has UNIQUE (user_id, client_request_id)'
);
select is(
  (select confdeltype::text from pg_constraint where conrelid = 'public.orders'::regclass and contype = 'f' and conname = 'orders_offer_id_fkey'),
  'n',
  'orders.offer_id uses ON DELETE SET NULL'
);
select results_eq(
  $$select indexname::text from pg_indexes where schemaname = 'public' and tablename = 'orders' and indexname in ('orders_payment_proof_path_unique_idx','orders_user_created_idx','orders_order_status_created_idx','orders_payment_status_created_idx','orders_offer_id_idx','orders_game_id_idx') order by indexname$$,
  $$values ('orders_game_id_idx'::text), ('orders_offer_id_idx'), ('orders_order_status_created_idx'), ('orders_payment_proof_path_unique_idx'), ('orders_payment_status_created_idx'), ('orders_user_created_idx')$$,
  'required order indexes exist'
);
select ok(
  exists (select 1 from pg_indexes where schemaname = 'public' and tablename = 'order_status_history' and indexname = 'order_status_history_order_created_idx'),
  'history order/created index exists'
);

select results_eq(
  $$select relname::text from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relkind = 'r' and c.relname in ('profiles','games','public_offers','orders','order_status_history') and c.relrowsecurity order by relname$$,
  $$values ('games'::text), ('order_status_history'), ('orders'), ('profiles'), ('public_offers')$$,
  'RLS is enabled on all five public platform tables'
);

select is((select public from storage.buckets where id = 'payment-proofs'), false, 'payment-proofs bucket is private');
select is((select file_size_limit from storage.buckets where id = 'payment-proofs'), 5242880::bigint, 'payment-proofs bucket limit is 5 MiB');
select is(
  (select allowed_mime_types from storage.buckets where id = 'payment-proofs'),
  array['image/jpeg','image/png','application/pdf']::text[],
  'payment-proofs MIME allowlist is exact'
);
select is((select count(*)::integer from storage.buckets where id = 'payment-proofs'), 1, 'payment-proofs bucket exists once');

select is((select count(*)::integer from public.games where slug = 'free-fire'), 1, 'seed inserts Free Fire exactly once');
select is((select count(*)::integer from public.public_offers), 0, 'seed inserts no offers or prices');
select is((select count(*)::integer from auth.users), 0, 'seed inserts no users');
select is((select count(*)::integer from public.profiles), 0, 'seed inserts no profiles');

select * from finish();
rollback;
