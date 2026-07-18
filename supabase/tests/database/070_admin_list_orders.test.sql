begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_catalog;

select plan(76);

select ok(
  to_regclass('public.orders_created_at_id_desc_idx') is not null,
  'orders cursor index exists'
);
select ok(
  pg_get_indexdef('public.orders_created_at_id_desc_idx'::regclass)
    ~ '\(created_at DESC, id DESC\)',
  'orders cursor index orders by created_at and id descending'
);
select ok(
  (select indisvalid and indisready
   from pg_index
   where indexrelid = 'public.orders_created_at_id_desc_idx'::regclass),
  'orders cursor index is valid and ready'
);

select ok(
  to_regprocedure(
    'public.admin_list_orders(public.order_status_type,public.payment_status_type,public.payment_method_type,uuid,timestamptz,timestamptz,text,timestamptz,uuid,integer)'
  ) is not null,
  'admin_list_orders has the approved typed signature'
);
select is(
  (select pronargs::integer
   from pg_proc
   where oid = to_regprocedure(
     'public.admin_list_orders(public.order_status_type,public.payment_status_type,public.payment_method_type,uuid,timestamptz,timestamptz,text,timestamptz,uuid,integer)'
   )),
  10,
  'admin_list_orders accepts ten input parameters'
);
select is(
  (select pronargdefaults::integer
   from pg_proc
   where oid = to_regprocedure(
     'public.admin_list_orders(public.order_status_type,public.payment_status_type,public.payment_method_type,uuid,timestamptz,timestamptz,text,timestamptz,uuid,integer)'
   )),
  10,
  'every optional list parameter has a database default'
);
select is(
  (select proargnames[1:10]
   from pg_proc
   where oid = to_regprocedure(
     'public.admin_list_orders(public.order_status_type,public.payment_status_type,public.payment_method_type,uuid,timestamptz,timestamptz,text,timestamptz,uuid,integer)'
   )),
  array[
    'p_order_status',
    'p_payment_status',
    'p_payment_method',
    'p_game_id',
    'p_date_from',
    'p_date_to_exclusive',
    'p_search_text',
    'p_cursor_created_at',
    'p_cursor_id',
    'p_limit'
  ]::text[],
  'input parameter names match the public contract'
);
select is(
  (select proargnames[11:28]
   from pg_proc
   where oid = to_regprocedure(
     'public.admin_list_orders(public.order_status_type,public.payment_status_type,public.payment_method_type,uuid,timestamptz,timestamptz,text,timestamptz,uuid,integer)'
   )),
  array[
    'id',
    'game_name_ar_snapshot',
    'game_name_fr_snapshot',
    'offer_name_ar_snapshot',
    'offer_name_fr_snapshot',
    'customer_name_snapshot',
    'player_id',
    'in_game_name',
    'sale_price_dzd_snapshot',
    'reward_quantity_snapshot',
    'reward_unit_name_ar_snapshot',
    'reward_unit_name_fr_snapshot',
    'payment_method',
    'order_status',
    'payment_status',
    'created_at',
    'has_payment_proof',
    'has_more'
  ]::text[],
  'result projection contains only list fields and pagination metadata'
);
select ok(
  not (
    (select proargnames
     from pg_proc
     where oid = to_regprocedure(
       'public.admin_list_orders(public.order_status_type,public.payment_status_type,public.payment_method_type,uuid,timestamptz,timestamptz,text,timestamptz,uuid,integer)'
     ))
    && array[
      'customer_email_snapshot',
      'customer_phone_snapshot',
      'user_id',
      'client_request_id',
      'payment_proof_path',
      'changed_by'
    ]::text[]
  ),
  'result contract excludes every forbidden field'
);
select is(
  (select provolatile::text
   from pg_proc
   where oid = to_regprocedure(
     'public.admin_list_orders(public.order_status_type,public.payment_status_type,public.payment_method_type,uuid,timestamptz,timestamptz,text,timestamptz,uuid,integer)'
   )),
  's',
  'admin_list_orders is STABLE'
);
select ok(
  not (select prosecdef
       from pg_proc
       where oid = to_regprocedure(
         'public.admin_list_orders(public.order_status_type,public.payment_status_type,public.payment_method_type,uuid,timestamptz,timestamptz,text,timestamptz,uuid,integer)'
       )),
  'admin_list_orders is SECURITY INVOKER'
);
select is(
  (select proconfig
   from pg_proc
   where oid = to_regprocedure(
     'public.admin_list_orders(public.order_status_type,public.payment_status_type,public.payment_method_type,uuid,timestamptz,timestamptz,text,timestamptz,uuid,integer)'
   )),
  array['search_path=""']::text[],
  'admin_list_orders has an empty search_path'
);
select ok(
  position('user_metadata' in lower(pg_get_functiondef(to_regprocedure(
    'public.admin_list_orders(public.order_status_type,public.payment_status_type,public.payment_method_type,uuid,timestamptz,timestamptz,text,timestamptz,uuid,integer)'
  )))) = 0,
  'admin_list_orders never trusts user_metadata'
);
select ok(
  position('execute ' in lower(pg_get_functiondef(to_regprocedure(
    'public.admin_list_orders(public.order_status_type,public.payment_status_type,public.payment_method_type,uuid,timestamptz,timestamptz,text,timestamptz,uuid,integer)'
  )))) = 0,
  'admin_list_orders contains no dynamic SQL'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.admin_list_orders(public.order_status_type,public.payment_status_type,public.payment_method_type,uuid,timestamptz,timestamptz,text,timestamptz,uuid,integer)',
    'EXECUTE'
  ),
  'authenticated can execute admin_list_orders'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.admin_list_orders(public.order_status_type,public.payment_status_type,public.payment_method_type,uuid,timestamptz,timestamptz,text,timestamptz,uuid,integer)',
    'EXECUTE'
  ),
  'anon cannot execute admin_list_orders'
);
select ok(
  not exists (
    select 1
    from pg_proc p
    cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
    where p.oid = to_regprocedure(
      'public.admin_list_orders(public.order_status_type,public.payment_status_type,public.payment_method_type,uuid,timestamptz,timestamptz,text,timestamptz,uuid,integer)'
    )
      and acl.grantee = 0::oid
      and acl.privilege_type = 'EXECUTE'
  ),
  'PUBLIC cannot execute admin_list_orders'
);

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('11111111-1111-4111-8111-111111111111', 'authenticated', 'authenticated', 'user-a@test.invalid', crypt('password-a', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('22222222-2222-4222-8222-222222222222', 'authenticated', 'authenticated', 'user-b@test.invalid', crypt('password-b', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('33333333-3333-4333-8333-333333333333', 'authenticated', 'authenticated', 'admin@test.invalid', crypt('password-admin', gen_salt('bf')), now(), '{"provider":"email","providers":["email"],"role":"admin"}', '{}', now(), now());

insert into public.games (
  id, slug, name_ar, name_fr, reward_unit_code,
  reward_unit_name_ar, reward_unit_name_fr, is_active, sort_order
) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'orders-read-game-one', 'لعبة أولى', 'Jeu un', 'diamonds', 'جواهر', 'Diamants', true, 10),
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2', 'orders-read-game-two', 'لعبة ثانية', 'Jeu deux', 'coins', 'عملات', 'Pièces', true, 20);

insert into public.public_offers (
  id, game_id, name_ar, name_fr, reward_quantity,
  sale_price_dzd, is_published, sort_order
) values
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'عرض أول', 'Offre une', 100, 350, true, 10),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2', 'عرض ثان', 'Offre deux', 200, 650, true, 20);

insert into public.orders (
  id,
  user_id,
  client_request_id,
  game_id,
  offer_id,
  player_id,
  in_game_name,
  payment_method,
  order_status,
  payment_status,
  payment_proof_path,
  game_name_ar_snapshot,
  game_name_fr_snapshot,
  reward_unit_code_snapshot,
  reward_unit_name_ar_snapshot,
  reward_unit_name_fr_snapshot,
  offer_name_ar_snapshot,
  offer_name_fr_snapshot,
  reward_quantity_snapshot,
  sale_price_dzd_snapshot,
  customer_name_snapshot,
  customer_email_snapshot,
  customer_phone_snapshot,
  created_at,
  updated_at,
  completed_at
) values
  ('10000000-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111', '91000000-0000-4000-8000-000000000001', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1', 'PLAYER-ALPHA', 'Hero Alpha', 'cash', 'new', 'awaiting_payment', null, 'لعبة أولى', 'Jeu un', 'diamonds', 'جواهر', 'Diamants', 'عرض أول', 'Offre une', 100, 350, 'Alpha Customer', 'alpha@test.invalid', '0550000001', '2026-07-18T10:00:00Z', '2026-07-18T10:00:00Z', null),
  ('20000000-0000-4000-8000-000000000002', '11111111-1111-4111-8111-111111111111', '92000000-0000-4000-8000-000000000002', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1', '777001', 'الأسطورة', 'transfer', 'accepted', 'paid', '11111111-1111-4111-8111-111111111111/20000000-0000-4000-8000-000000000002/proof.jpg', 'لعبة أولى', 'Jeu un', 'diamonds', 'جواهر', 'Diamants', 'عرض أول', 'Offre une', 100, 350, 'محمد علي', 'mohamed@test.invalid', '0550000002', '2026-07-18T10:00:00Z', '2026-07-18T10:00:00Z', null),
  ('30000000-0000-4000-8000-000000000003', '11111111-1111-4111-8111-111111111111', '93000000-0000-4000-8000-000000000003', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', 'PLAYER-BETA', 'Beta Hero', 'transfer', 'processing', 'under_review', '11111111-1111-4111-8111-111111111111/30000000-0000-4000-8000-000000000003/proof.png', 'لعبة ثانية', 'Jeu deux', 'coins', 'عملات', 'Pièces', 'عرض ثان', 'Offre deux', 200, 650, 'Beta Customer', 'beta@test.invalid', '0550000003', '2026-07-18T10:00:00Z', '2026-07-18T10:00:00Z', null),
  ('40000000-0000-4000-8000-000000000004', '11111111-1111-4111-8111-111111111111', '94000000-0000-4000-8000-000000000004', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1', 'PLAYER-GAMMA', null, 'cash', 'completed', 'paid', null, 'لعبة أولى', 'Jeu un', 'diamonds', 'جواهر', 'Diamants', 'عرض أول', 'Offre une', 100, 350, 'Gamma Customer', 'gamma@test.invalid', '0550000004', '2026-07-18T09:00:00Z', '2026-07-18T09:00:00Z', '2026-07-18T09:30:00Z'),
  ('50000000-0000-4000-8000-000000000005', '11111111-1111-4111-8111-111111111111', '95000000-0000-4000-8000-000000000005', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', 'PLAYER-DELTA', 'Delta Hero', 'transfer', 'rejected', 'proof_rejected', null, 'لعبة ثانية', 'Jeu deux', 'coins', 'عملات', 'Pièces', 'عرض ثان', 'Offre deux', 200, 650, 'Delta Customer', 'delta@test.invalid', '0550000005', '2026-07-18T08:00:00Z', '2026-07-18T08:00:00Z', null),
  ('60000000-0000-4000-8000-000000000006', '11111111-1111-4111-8111-111111111111', '96000000-0000-4000-8000-000000000006', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1', 'PLAYER-EPSILON', 'Epsilon Hero', 'cash', 'cancelled', 'awaiting_payment', null, 'لعبة أولى', 'Jeu un', 'diamonds', 'جواهر', 'Diamants', 'عرض أول', 'Offre une', 100, 350, 'Epsilon Customer', 'epsilon@test.invalid', '0550000006', '2026-07-18T07:00:00Z', '2026-07-18T07:00:00Z', null),
  ('70000000-0000-4000-8000-000000000007', '11111111-1111-4111-8111-111111111111', '97000000-0000-4000-8000-000000000007', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', 'PLAYER_UNDERSCORE', E'Back\\Slash', 'transfer', 'new', 'awaiting_payment', null, 'لعبة ثانية', 'Jeu deux', 'coins', 'عملات', 'Pièces', 'عرض ثان', 'Offre deux', 200, 650, 'Literal % Percent', 'literal@test.invalid', '0550000007', '2026-07-18T06:00:00Z', '2026-07-18T06:00:00Z', null),
  ('80000000-0000-4000-8000-000000000008', '22222222-2222-4222-8222-222222222222', '98000000-0000-4000-8000-000000000008', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1', 'PLAYER-ZETA', 'Zeta Hero', 'cash', 'new', 'awaiting_payment', null, 'لعبة أولى', 'Jeu un', 'diamonds', 'جواهر', 'Diamants', 'عرض أول', 'Offre une', 100, 350, 'Zeta Customer', 'zeta@test.invalid', '0550000008', '2026-07-18T05:00:00Z', '2026-07-18T05:00:00Z', null);

select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select throws_ok(
  $$select * from public.admin_list_orders()$$,
  '42501',
  null,
  'anonymous callers cannot execute the order-list RPC'
);
reset role;

select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
select set_config('request.jwt.claims', '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated","app_metadata":{},"user_metadata":{}}', true);
set local role authenticated;
select throws_ok(
  $$select * from public.admin_list_orders()$$,
  '42501',
  'admin access required',
  'ordinary authenticated users are rejected inside the RPC'
);
select is(
  (select count(*)::integer from public.orders),
  7,
  'ordinary users retain the existing own-orders RLS behavior'
);
reset role;

select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
select set_config('request.jwt.claims', '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated","app_metadata":{},"user_metadata":{"role":"admin"}}', true);
set local role authenticated;
select throws_ok(
  $$select * from public.admin_list_orders()$$,
  '42501',
  'admin access required',
  'an admin value in user_metadata is not trusted'
);
reset role;

select set_config('request.jwt.claim.sub', '33333333-3333-4333-8333-333333333333', true);
select set_config('request.jwt.claims', '{"sub":"33333333-3333-4333-8333-333333333333","role":"authenticated","app_metadata":{"role":"admin"},"user_metadata":{}}', true);
set local role authenticated;

select lives_ok(
  $$select * from public.admin_list_orders()$$,
  'an authenticated app_metadata administrator can list orders'
);
select is(
  (select count(*)::integer from public.admin_list_orders()),
  8,
  'administrator list includes all synthetic orders through existing admin RLS'
);
select results_eq(
  $$select id::text from public.admin_list_orders()$$,
  $$values
    ('30000000-0000-4000-8000-000000000003'::text),
    ('20000000-0000-4000-8000-000000000002'::text),
    ('10000000-0000-4000-8000-000000000001'::text),
    ('40000000-0000-4000-8000-000000000004'::text),
    ('50000000-0000-4000-8000-000000000005'::text),
    ('60000000-0000-4000-8000-000000000006'::text),
    ('70000000-0000-4000-8000-000000000007'::text),
    ('80000000-0000-4000-8000-000000000008'::text)$$,
  'default ordering is created_at descending then id descending'
);

select ok(
  not (to_jsonb(r) ?| array[
    'customer_email_snapshot',
    'customer_phone_snapshot',
    'user_id',
    'client_request_id',
    'payment_proof_path',
    'changed_by'
  ])
  from public.admin_list_orders(p_limit => 1) as r,
  'runtime response contains none of the forbidden keys'
);
select ok(
  position('alpha@test.invalid' in to_jsonb(r)::text) = 0
  and position('0550000001' in to_jsonb(r)::text) = 0
  and position('/proof.' in to_jsonb(r)::text) = 0
  from public.admin_list_orders(p_limit => 1) as r,
  'runtime response contains no email, phone, or proof path values'
);
select is(
  (select has_payment_proof
   from public.admin_list_orders(p_search_text => '20000000')),
  true,
  'an attached path is represented only as has_payment_proof true'
);
select is(
  (select has_payment_proof
   from public.admin_list_orders(p_search_text => '10000000')),
  false,
  'a missing path is represented as has_payment_proof false'
);

select results_eq(
  $$select id::text from public.admin_list_orders(p_order_status => 'accepted')$$,
  $$values ('20000000-0000-4000-8000-000000000002'::text)$$,
  'order status filter is typed and exact'
);
select results_eq(
  $$select id::text from public.admin_list_orders(p_payment_status => 'under_review')$$,
  $$values ('30000000-0000-4000-8000-000000000003'::text)$$,
  'payment status filter is typed and exact'
);
select results_eq(
  $$select id::text from public.admin_list_orders(p_payment_method => 'transfer')$$,
  $$values
    ('30000000-0000-4000-8000-000000000003'::text),
    ('20000000-0000-4000-8000-000000000002'::text),
    ('50000000-0000-4000-8000-000000000005'::text),
    ('70000000-0000-4000-8000-000000000007'::text)$$,
  'payment method filter is typed and exact'
);
select is(
  (select count(*)::integer
   from public.admin_list_orders(p_game_id => 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2')),
  3,
  'game ID filter selects only its game'
);
select is(
  (select count(*)::integer
   from public.admin_list_orders(p_date_from => '2026-07-18T09:00:00Z')),
  4,
  'date_from is inclusive'
);
select is(
  (select count(*)::integer
   from public.admin_list_orders(p_date_to_exclusive => '2026-07-18T09:00:00Z')),
  4,
  'date_to_exclusive excludes its boundary'
);
select results_eq(
  $$select id::text from public.admin_list_orders(
      p_date_from => '2026-07-18T08:00:00Z',
      p_date_to_exclusive => '2026-07-18T10:00:00Z'
    )$$,
  $$values
    ('40000000-0000-4000-8000-000000000004'::text),
    ('50000000-0000-4000-8000-000000000005'::text)$$,
  'date range combines inclusive start with exclusive end'
);
select results_eq(
  $$select id::text from public.admin_list_orders(
      p_order_status => 'accepted',
      p_payment_status => 'paid',
      p_payment_method => 'transfer',
      p_game_id => 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
    )$$,
  $$values ('20000000-0000-4000-8000-000000000002'::text)$$,
  'multiple typed filters compose without widening results'
);
select throws_ok(
  $$select * from public.admin_list_orders(
      p_date_from => '2026-07-18T10:00:00Z',
      p_date_to_exclusive => '2026-07-18T10:00:00Z'
    )$$,
  '22023',
  'date_to_exclusive must be after date_from',
  'equal date boundaries are rejected'
);
select throws_ok(
  $$select * from public.admin_list_orders(
      p_date_from => '2026-07-18T11:00:00Z',
      p_date_to_exclusive => '2026-07-18T10:00:00Z'
    )$$,
  '22023',
  'date_to_exclusive must be after date_from',
  'reversed date boundaries are rejected'
);

select results_eq(
  $$select id::text from public.admin_list_orders(p_search_text => '20000000')$$,
  $$values ('20000000-0000-4000-8000-000000000002'::text)$$,
  'search matches the eight-character compact order number'
);
select results_eq(
  $$select id::text from public.admin_list_orders(p_search_text => 'محمد')$$,
  $$values ('20000000-0000-4000-8000-000000000002'::text)$$,
  'search matches an Arabic customer name'
);
select results_eq(
  $$select id::text from public.admin_list_orders(p_search_text => 'alpha customer')$$,
  $$values ('10000000-0000-4000-8000-000000000001'::text)$$,
  'search matches customer names case-insensitively'
);
select results_eq(
  $$select id::text from public.admin_list_orders(p_search_text => '777001')$$,
  $$values ('20000000-0000-4000-8000-000000000002'::text)$$,
  'search matches Player ID'
);
select results_eq(
  $$select id::text from public.admin_list_orders(p_search_text => 'الأسطورة')$$,
  $$values ('20000000-0000-4000-8000-000000000002'::text)$$,
  'search matches the in-game name'
);
select results_eq(
  $$select id::text from public.admin_list_orders(p_search_text => '%')$$,
  $$values ('70000000-0000-4000-8000-000000000007'::text)$$,
  'percent is escaped and searched as a literal character'
);
select results_eq(
  $$select id::text from public.admin_list_orders(p_search_text => '_')$$,
  $$values ('70000000-0000-4000-8000-000000000007'::text)$$,
  'underscore is escaped and searched as a literal character'
);
select results_eq(
  $$select id::text from public.admin_list_orders(p_search_text => E'\\')$$,
  $$values ('70000000-0000-4000-8000-000000000007'::text)$$,
  'backslash is escaped and searched as a literal character'
);
select is(
  (select count(*)::integer
   from public.admin_list_orders(p_search_text => $search$' OR true --$search$)),
  0,
  'SQL-looking input stays data and does not widen the query'
);
select is(
  (select count(*)::integer
   from public.admin_list_orders(p_search_text => '   ')),
  8,
  'blank search text normalizes to no search filter'
);
select lives_ok(
  $$select * from public.admin_list_orders(p_search_text => repeat('a', 100))$$,
  'a one-hundred-character search is accepted'
);
select throws_ok(
  $$select * from public.admin_list_orders(p_search_text => repeat('a', 101))$$,
  '22023',
  'search_text must not exceed 100 characters',
  'a search longer than one hundred characters is rejected'
);
select throws_ok(
  $$select * from public.admin_list_orders(p_search_text => 'player' || chr(1))$$,
  '22023',
  'search_text contains control characters',
  'control characters are rejected'
);

select results_eq(
  $$select id::text from public.admin_list_orders(p_limit => 2)$$,
  $$values
    ('30000000-0000-4000-8000-000000000003'::text),
    ('20000000-0000-4000-8000-000000000002'::text)$$,
  'first page follows the descending timestamp and UUID order'
);
select ok(
  (select bool_and(has_more) from public.admin_list_orders(p_limit => 2)),
  'first page reports that more rows exist'
);
select results_eq(
  $$select id::text from public.admin_list_orders(
      p_cursor_created_at => '2026-07-18T10:00:00Z',
      p_cursor_id => '20000000-0000-4000-8000-000000000002',
      p_limit => 2
    )$$,
  $$values
    ('10000000-0000-4000-8000-000000000001'::text),
    ('40000000-0000-4000-8000-000000000004'::text)$$,
  'next page uses the composite cursor without duplicates'
);
select is(
  (select count(*)::integer
   from public.admin_list_orders(
     p_cursor_created_at => '2026-07-18T10:00:00Z',
     p_cursor_id => '20000000-0000-4000-8000-000000000002'
   )
   where id in (
     '20000000-0000-4000-8000-000000000002',
     '30000000-0000-4000-8000-000000000003'
   )),
  0,
  'cursor excludes the cursor row and all rows ordered before it'
);
select results_eq(
  $$select id::text from public.admin_list_orders(
      p_cursor_created_at => '2026-07-18T10:00:00Z',
      p_cursor_id => '30000000-0000-4000-8000-000000000003',
      p_limit => 2
    )$$,
  $$values
    ('20000000-0000-4000-8000-000000000002'::text),
    ('10000000-0000-4000-8000-000000000001'::text)$$,
  'UUID tie-breaker preserves rows sharing the cursor timestamp'
);
select results_eq(
  $$select id::text, has_more from public.admin_list_orders(
      p_cursor_created_at => '2026-07-18T06:00:00Z',
      p_cursor_id => '70000000-0000-4000-8000-000000000007',
      p_limit => 2
    )$$,
  $$values ('80000000-0000-4000-8000-000000000008'::text, false)$$,
  'last page returns its final row and has_more false'
);
select is(
  (select count(*)::integer
   from public.admin_list_orders(
     p_cursor_created_at => '2026-07-18T05:00:00Z',
     p_cursor_id => '80000000-0000-4000-8000-000000000008'
   )),
  0,
  'cursor after the last row returns an empty page'
);
select throws_ok(
  $$select * from public.admin_list_orders(
      p_cursor_created_at => '2026-07-18T10:00:00Z'
    )$$,
  '22023',
  'cursor_created_at and cursor_id must be provided together',
  'cursor timestamp without UUID is rejected'
);
select throws_ok(
  $$select * from public.admin_list_orders(
      p_cursor_id => '20000000-0000-4000-8000-000000000002'
    )$$,
  '22023',
  'cursor_created_at and cursor_id must be provided together',
  'cursor UUID without timestamp is rejected'
);

select is(
  (select count(*)::integer from public.admin_list_orders(p_limit => 1)),
  1,
  'minimum page limit is accepted'
);
select ok(
  (select has_more from public.admin_list_orders(p_limit => 1) limit 1),
  'minimum page reports additional rows'
);
select is(
  (select count(*)::integer from public.admin_list_orders(p_limit => 25)),
  8,
  'maximum page limit is accepted'
);
select ok(
  not (select has_more from public.admin_list_orders(p_limit => 25) limit 1),
  'complete page reports has_more false'
);
select throws_ok(
  $$select * from public.admin_list_orders(p_limit => 0)$$,
  '22023',
  'limit must be between 1 and 25',
  'zero page limit is rejected'
);
select throws_ok(
  $$select * from public.admin_list_orders(p_limit => 26)$$,
  '22023',
  'limit must be between 1 and 25',
  'page limit above twenty-five is rejected'
);
select throws_ok(
  $$select * from public.admin_list_orders(p_limit => null)$$,
  '22023',
  'limit must be between 1 and 25',
  'null page limit is rejected'
);

reset role;

select ok(
  (select relrowsecurity from pg_class where oid = 'public.orders'::regclass),
  'orders RLS remains enabled'
);
select is(
  (select count(*)::integer
   from pg_policies
   where schemaname = 'public'
     and tablename = 'orders'
     and policyname = 'orders_select_own_or_admin'),
  1,
  'existing orders RLS policy remains unchanged'
);
select ok(
  has_table_privilege('authenticated', 'public.orders', 'SELECT'),
  'authenticated retains the existing orders SELECT grant'
);
select ok(
  not has_table_privilege('authenticated', 'public.orders', 'INSERT'),
  'migration adds no direct orders INSERT grant'
);
select ok(
  not has_table_privilege('authenticated', 'public.orders', 'UPDATE'),
  'migration adds no direct orders UPDATE grant'
);
select ok(
  not has_table_privilege('authenticated', 'public.orders', 'DELETE'),
  'migration adds no direct orders DELETE grant'
);
select ok(
  not has_table_privilege('anon', 'public.orders', 'SELECT'),
  'anonymous users remain unable to select orders'
);
select is(
  (select count(*)::integer from public.orders),
  8,
  'read-only RPC tests do not modify order fixtures'
);
select ok(
  position('storage.' in lower(pg_get_functiondef(to_regprocedure(
    'public.admin_list_orders(public.order_status_type,public.payment_status_type,public.payment_method_type,uuid,timestamptz,timestamptz,text,timestamptz,uuid,integer)'
  )))) = 0,
  'admin_list_orders does not access Storage objects or policies'
);

select * from finish();
rollback;
