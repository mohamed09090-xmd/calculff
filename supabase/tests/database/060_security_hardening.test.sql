begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_catalog;

select plan(39);

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

select ok(
  to_regprocedure('public.rls_auto_enable()') is null
  or (select prosecdef from pg_proc where oid = to_regprocedure('public.rls_auto_enable()')),
  'hosted rls_auto_enable remains SECURITY DEFINER when present'
);
select ok(
  not exists (
    select 1
    from pg_proc p
    cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
    where p.oid = to_regprocedure('public.rls_auto_enable()')
      and acl.grantee = 0::oid
      and acl.privilege_type = 'EXECUTE'
  ),
  'PUBLIC cannot execute hosted rls_auto_enable when present'
);
select ok(
  not exists (
    select 1
    from pg_proc p
    cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
    where p.oid = to_regprocedure('public.rls_auto_enable()')
      and acl.grantee = (select oid from pg_roles where rolname = 'anon')
      and acl.privilege_type = 'EXECUTE'
  ),
  'anon cannot execute hosted rls_auto_enable when present'
);
select ok(
  not exists (
    select 1
    from pg_proc p
    cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
    where p.oid = to_regprocedure('public.rls_auto_enable()')
      and acl.grantee = (select oid from pg_roles where rolname = 'authenticated')
      and acl.privilege_type = 'EXECUTE'
  ),
  'authenticated cannot execute hosted rls_auto_enable when present'
);

select ok(has_function_privilege('authenticated', 'public.create_order(uuid,uuid,text,text,public.payment_method_type)', 'EXECUTE'), 'authenticated retains create_order EXECUTE');
select ok(has_function_privilege('authenticated', 'public.get_my_order_timeline(uuid)', 'EXECUTE'), 'authenticated retains timeline EXECUTE');
select ok(has_function_privilege('authenticated', 'public.attach_payment_proof(uuid,text)', 'EXECUTE'), 'authenticated retains proof RPC EXECUTE');
select ok(has_function_privilege('authenticated', 'public.admin_add_order_internal_note(uuid,text)', 'EXECUTE'), 'authenticated retains admin note RPC EXECUTE');
select ok(has_function_privilege('authenticated', 'public.admin_list_order_internal_notes(uuid)', 'EXECUTE'), 'authenticated retains admin note-list RPC EXECUTE');
select ok(has_function_privilege('authenticated', 'public.admin_set_order_status(uuid,public.order_status_type,text,text)', 'EXECUTE'), 'authenticated retains admin order RPC EXECUTE');
select ok(has_function_privilege('authenticated', 'public.admin_set_payment_status(uuid,public.payment_status_type,text,text)', 'EXECUTE'), 'authenticated retains admin payment RPC EXECUTE');
select ok(has_function_privilege('authenticated', 'public.admin_mark_refunded(uuid,text,text)', 'EXECUTE'), 'authenticated retains admin refund RPC EXECUTE');
select ok(not has_function_privilege('anon', 'public.create_order(uuid,uuid,text,text,public.payment_method_type)', 'EXECUTE'), 'anon remains blocked from create_order');
select ok(not has_function_privilege('anon', 'public.get_my_order_timeline(uuid)', 'EXECUTE'), 'anon remains blocked from timeline');
select ok(not has_function_privilege('anon', 'public.attach_payment_proof(uuid,text)', 'EXECUTE'), 'anon remains blocked from proof RPC');
select ok(not has_function_privilege('anon', 'public.admin_set_order_status(uuid,public.order_status_type,text,text)', 'EXECUTE'), 'anon remains blocked from admin RPC');

select ok(to_regclass('private.order_internal_notes_author_user_id_idx') is not null, 'internal note author foreign-key index exists');
select ok(to_regclass('public.order_status_history_changed_by_idx') is not null, 'history changed_by foreign-key index exists');

select is(
  (select count(*)::integer from pg_policies
   where schemaname = 'public'
     and (tablename, policyname) in (
       ('profiles', 'profiles_select_own_or_admin'),
       ('games', 'games_select_active_or_admin'),
       ('games', 'games_admin_insert'),
       ('games', 'games_admin_update'),
       ('games', 'games_admin_delete'),
       ('public_offers', 'public_offers_select_published_or_admin'),
       ('public_offers', 'public_offers_admin_insert'),
       ('public_offers', 'public_offers_admin_update'),
       ('public_offers', 'public_offers_admin_delete'),
       ('orders', 'orders_select_own_or_admin'),
       ('order_status_history', 'order_status_history_admin_select')
     )),
  11,
  'all eleven optimized policies keep their original names'
);
select is(
  (select count(*)::integer from pg_policies
   where schemaname = 'public'
     and tablename in ('profiles','games','public_offers','orders','order_status_history')
     and position('select auth.jwt()' in lower(coalesce(qual, '') || ' ' || coalesce(with_check, ''))) > 0),
  11,
  'all eleven optimized policies use JWT initialization subqueries'
);
select is(
  (select count(*)::integer from pg_policies
   where schemaname = 'public'
     and tablename in ('profiles','orders')
     and position('select auth.uid()' in lower(coalesce(qual, ''))) > 0),
  3,
  'ownership and profile-update policies retain UID initialization subqueries'
);
select ok(
  (select qual from pg_policies where schemaname = 'public' and tablename = 'profiles' and policyname = 'profiles_select_own_or_admin')
    ~ 'id = .*auth.uid',
  'profiles policy retains own-row predicate'
);
select ok(
  (select qual from pg_policies where schemaname = 'public' and tablename = 'orders' and policyname = 'orders_select_own_or_admin')
    ~ 'user_id = .*auth.uid',
 'orders policy retains owner predicate'
);
select ok(
  (select qual from pg_policies where schemaname = 'public' and tablename = 'games' and policyname = 'games_select_active_or_admin')
    ~ 'is_active',
  'games policy retains active-game predicate'
);
select ok(
  (select qual from pg_policies where schemaname = 'public' and tablename = 'public_offers' and policyname = 'public_offers_select_published_or_admin')
    ~ 'is_published.*is_active',
  'offers policy retains published-and-active predicate'
);
select ok(
  (select qual from pg_policies where schemaname = 'public' and tablename = 'order_status_history' and policyname = 'order_status_history_admin_select')
    ~ 'app_metadata.*admin',
  'history policy remains administrator-only'
);

select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
select set_config('request.jwt.claims', '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated","app_metadata":{},"user_metadata":{}}', true);
set local role authenticated;
select throws_ok(
  $$select * from private.order_internal_notes$$,
  '42501',
  null,
  'ordinary user cannot directly read internal notes'
);
select throws_ok(
  $$select public.admin_set_order_status('80000000-0000-4000-8000-000000000001','accepted')$$,
  '42501',
  'admin access required',
  'ordinary user remains blocked from admin RPCs'
);
reset role;

select * from finish();
rollback;
