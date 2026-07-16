begin;

-- The platform event trigger still owns and invokes this helper. Client roles must
-- never be able to call the SECURITY DEFINER function directly.
do $migration$
begin
  if to_regprocedure('public.rls_auto_enable()') is not null then
    execute 'revoke execute on function public.rls_auto_enable() from public, anon, authenticated';
  end if;
end;
$migration$;

-- Defense in depth for the private notes table. No client policy or grant is added;
-- administrator access continues exclusively through audited SECURITY DEFINER RPCs.
alter table private.order_internal_notes enable row level security;

-- Foreign-key lookup indexes requested by the hosted database advisors.
create index if not exists order_internal_notes_author_user_id_idx
  on private.order_internal_notes (author_user_id);
create index if not exists order_status_history_changed_by_idx
  on public.order_status_history (changed_by);

-- Recreate only the advisor-identified policies. Wrapping auth helpers in scalar
-- subqueries lets PostgreSQL use one initialization plan per statement rather than
-- reevaluating the JWT or UID helper for every candidate row.
drop policy if exists profiles_select_own_or_admin on public.profiles;
create policy profiles_select_own_or_admin
on public.profiles
for select
to authenticated
using (
  id = (select auth.uid())
  or coalesce((((select auth.jwt()) -> 'app_metadata') ->> 'role') = 'admin', false)
);

drop policy if exists games_select_active_or_admin on public.games;
create policy games_select_active_or_admin
on public.games
for select
to authenticated
using (
  is_active
  or coalesce((((select auth.jwt()) -> 'app_metadata') ->> 'role') = 'admin', false)
);

drop policy if exists games_admin_insert on public.games;
create policy games_admin_insert
on public.games
for insert
to authenticated
with check (
  coalesce((((select auth.jwt()) -> 'app_metadata') ->> 'role') = 'admin', false)
);

drop policy if exists games_admin_update on public.games;
create policy games_admin_update
on public.games
for update
to authenticated
using (
  coalesce((((select auth.jwt()) -> 'app_metadata') ->> 'role') = 'admin', false)
)
with check (
  coalesce((((select auth.jwt()) -> 'app_metadata') ->> 'role') = 'admin', false)
);

drop policy if exists games_admin_delete on public.games;
create policy games_admin_delete
on public.games
for delete
to authenticated
using (
  coalesce((((select auth.jwt()) -> 'app_metadata') ->> 'role') = 'admin', false)
);

drop policy if exists public_offers_select_published_or_admin on public.public_offers;
create policy public_offers_select_published_or_admin
on public.public_offers
for select
to authenticated
using (
  (
    is_published
    and exists (
      select 1
      from public.games g
      where g.id = public_offers.game_id
        and g.is_active
    )
  )
  or coalesce((((select auth.jwt()) -> 'app_metadata') ->> 'role') = 'admin', false)
);

drop policy if exists public_offers_admin_insert on public.public_offers;
create policy public_offers_admin_insert
on public.public_offers
for insert
to authenticated
with check (
  coalesce((((select auth.jwt()) -> 'app_metadata') ->> 'role') = 'admin', false)
);

drop policy if exists public_offers_admin_update on public.public_offers;
create policy public_offers_admin_update
on public.public_offers
for update
to authenticated
using (
  coalesce((((select auth.jwt()) -> 'app_metadata') ->> 'role') = 'admin', false)
)
with check (
  coalesce((((select auth.jwt()) -> 'app_metadata') ->> 'role') = 'admin', false)
);

drop policy if exists public_offers_admin_delete on public.public_offers;
create policy public_offers_admin_delete
on public.public_offers
for delete
to authenticated
using (
  coalesce((((select auth.jwt()) -> 'app_metadata') ->> 'role') = 'admin', false)
);

drop policy if exists orders_select_own_or_admin on public.orders;
create policy orders_select_own_or_admin
on public.orders
for select
to authenticated
using (
  user_id = (select auth.uid())
  or coalesce((((select auth.jwt()) -> 'app_metadata') ->> 'role') = 'admin', false)
);

drop policy if exists order_status_history_admin_select on public.order_status_history;
create policy order_status_history_admin_select
on public.order_status_history
for select
to authenticated
using (
  coalesce((((select auth.jwt()) -> 'app_metadata') ->> 'role') = 'admin', false)
);

commit;
