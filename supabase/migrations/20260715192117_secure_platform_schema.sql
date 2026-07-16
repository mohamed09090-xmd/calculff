begin;
create extension if not exists pgcrypto with schema extensions;
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
-- Opt in to least-privilege defaults for every object created below.
alter default privileges for role postgres in schema public
  revoke select, insert, update, delete, truncate, references, trigger on tables
  from public, anon, authenticated;
alter default privileges for role postgres in schema public
  revoke usage, select, update on sequences from public, anon, authenticated;
alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated;
alter default privileges for role postgres in schema private
  revoke all on tables from public, anon, authenticated;
alter default privileges for role postgres in schema private
  revoke all on sequences from public, anon, authenticated;
alter default privileges for role postgres in schema private
  revoke execute on functions from public, anon, authenticated;
create type public.order_status_type as enum (
  'new',
  'accepted',
  'processing',
  'completed',
  'rejected',
  'cancelled'
);
create type public.payment_status_type as enum (
  'awaiting_payment',
  'under_review',
  'paid',
  'proof_rejected',
  'refund_pending',
  'refunded'
);
create type public.payment_method_type as enum (
  'cash',
  'transfer'
);
create type public.status_event_type as enum (
  'created',
  'order_changed',
  'payment_changed',
  'proof_attached',
  'refund_started',
  'refunded'
);
revoke all on type public.order_status_type from public, anon;
revoke all on type public.payment_status_type from public, anon;
revoke all on type public.payment_method_type from public, anon;
revoke all on type public.status_event_type from public, anon;
grant usage on type public.order_status_type to authenticated;
grant usage on type public.payment_status_type to authenticated;
grant usage on type public.payment_method_type to authenticated;
grant usage on type public.status_event_type to authenticated;
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  full_name text,
  phone text,
  locale text not null default 'ar',
  is_complete boolean generated always as (
    email = btrim(email)
    and length(email) between 3 and 320
    and full_name is not null
    and phone is not null
  ) stored,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_email_valid check (
    email = btrim(email)
    and length(email) between 3 and 320
  ),
  constraint profiles_full_name_valid check (
    full_name is null
    or (
      full_name = btrim(full_name)
      and length(full_name) between 2 and 100
    )
  ),
  constraint profiles_phone_valid check (
    phone is null
    or (
      phone = btrim(phone)
      and length(phone) between 6 and 25
      and phone ~ '^[0-9+(). -]+$'
      and length(regexp_replace(phone, '[^0-9]', '', 'g')) between 6 and 15
    )
  ),
  constraint profiles_locale_valid check (locale in ('ar', 'fr'))
);
alter table public.profiles enable row level security;
revoke all on table public.profiles from public, anon, authenticated;
create index profiles_email_idx on public.profiles (email);
create table public.games (
  id uuid primary key default extensions.gen_random_uuid(),
  slug text not null unique,
  name_ar text not null,
  name_fr text not null,
  reward_unit_code text not null,
  reward_unit_name_ar text not null,
  reward_unit_name_fr text not null,
  is_active boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint games_slug_valid check (
    slug = btrim(slug)
    and length(slug) between 2 and 64
    and slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'
  ),
  constraint games_name_ar_valid check (
    name_ar = btrim(name_ar) and length(name_ar) between 1 and 120
  ),
  constraint games_name_fr_valid check (
    name_fr = btrim(name_fr) and length(name_fr) between 1 and 120
  ),
  constraint games_reward_unit_code_valid check (
    reward_unit_code = btrim(reward_unit_code)
    and length(reward_unit_code) between 2 and 32
    and reward_unit_code ~ '^[a-z0-9_]+$'
  ),
  constraint games_reward_unit_name_ar_valid check (
    reward_unit_name_ar = btrim(reward_unit_name_ar)
    and length(reward_unit_name_ar) between 1 and 120
  ),
  constraint games_reward_unit_name_fr_valid check (
    reward_unit_name_fr = btrim(reward_unit_name_fr)
    and length(reward_unit_name_fr) between 1 and 120
  )
);
alter table public.games enable row level security;
revoke all on table public.games from public, anon, authenticated;
create index games_active_sort_idx
  on public.games (is_active, sort_order, id);
create table public.public_offers (
  id uuid primary key default extensions.gen_random_uuid(),
  game_id uuid not null references public.games(id) on delete restrict,
  name_ar text not null,
  name_fr text not null,
  reward_quantity integer not null,
  sale_price_dzd integer not null,
  is_published boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint public_offers_name_ar_valid check (
    name_ar = btrim(name_ar) and length(name_ar) between 1 and 120
  ),
  constraint public_offers_name_fr_valid check (
    name_fr = btrim(name_fr) and length(name_fr) between 1 and 120
  ),
  constraint public_offers_reward_quantity_positive check (reward_quantity > 0),
  constraint public_offers_sale_price_positive check (sale_price_dzd > 0)
);
alter table public.public_offers enable row level security;
revoke all on table public.public_offers from public, anon, authenticated;
create index public_offers_game_published_sort_idx
  on public.public_offers (game_id, is_published, sort_order, id);
create table public.orders (
  id uuid primary key default extensions.gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  client_request_id uuid not null,
  game_id uuid not null references public.games(id) on delete restrict,
  offer_id uuid references public.public_offers(id) on delete set null,
  player_id text not null,
  in_game_name text,
  payment_method public.payment_method_type not null,
  order_status public.order_status_type not null default 'new',
  payment_status public.payment_status_type not null default 'awaiting_payment',
  payment_proof_path text,
  public_status_message text,
  game_name_ar_snapshot text not null,
  game_name_fr_snapshot text not null,
  reward_unit_code_snapshot text not null,
  reward_unit_name_ar_snapshot text not null,
  reward_unit_name_fr_snapshot text not null,
  offer_name_ar_snapshot text not null,
  offer_name_fr_snapshot text not null,
  reward_quantity_snapshot integer not null,
  sale_price_dzd_snapshot integer not null,
  customer_name_snapshot text not null,
  customer_email_snapshot text not null,
  customer_phone_snapshot text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  refund_started_at timestamptz,
  refunded_at timestamptz,
  constraint orders_user_client_request_unique unique (user_id, client_request_id),
  constraint orders_player_id_valid check (
    player_id = btrim(player_id) and length(player_id) between 3 and 64
  ),
  constraint orders_in_game_name_valid check (
    in_game_name is null
    or (
      in_game_name = btrim(in_game_name)
      and length(in_game_name) between 1 and 64
    )
  ),
  constraint orders_public_status_message_valid check (
    public_status_message is null
    or (
      public_status_message = btrim(public_status_message)
      and length(public_status_message) between 1 and 280
    )
  ),
  constraint orders_game_name_ar_snapshot_valid check (
    game_name_ar_snapshot = btrim(game_name_ar_snapshot)
    and length(game_name_ar_snapshot) between 1 and 120
  ),
  constraint orders_game_name_fr_snapshot_valid check (
    game_name_fr_snapshot = btrim(game_name_fr_snapshot)
    and length(game_name_fr_snapshot) between 1 and 120
  ),
  constraint orders_reward_unit_code_snapshot_valid check (
    reward_unit_code_snapshot = btrim(reward_unit_code_snapshot)
    and length(reward_unit_code_snapshot) between 2 and 32
  ),
  constraint orders_reward_unit_name_ar_snapshot_valid check (
    reward_unit_name_ar_snapshot = btrim(reward_unit_name_ar_snapshot)
    and length(reward_unit_name_ar_snapshot) between 1 and 120
  ),
  constraint orders_reward_unit_name_fr_snapshot_valid check (
    reward_unit_name_fr_snapshot = btrim(reward_unit_name_fr_snapshot)
    and length(reward_unit_name_fr_snapshot) between 1 and 120
  ),
  constraint orders_offer_name_ar_snapshot_valid check (
    offer_name_ar_snapshot = btrim(offer_name_ar_snapshot)
    and length(offer_name_ar_snapshot) between 1 and 120
  ),
  constraint orders_offer_name_fr_snapshot_valid check (
    offer_name_fr_snapshot = btrim(offer_name_fr_snapshot)
    and length(offer_name_fr_snapshot) between 1 and 120
  ),
  constraint orders_reward_quantity_snapshot_positive check (reward_quantity_snapshot > 0),
  constraint orders_sale_price_snapshot_positive check (sale_price_dzd_snapshot > 0),
  constraint orders_customer_name_snapshot_valid check (
    customer_name_snapshot = btrim(customer_name_snapshot)
    and length(customer_name_snapshot) between 2 and 100
  ),
  constraint orders_customer_email_snapshot_valid check (
    customer_email_snapshot = btrim(customer_email_snapshot)
    and length(customer_email_snapshot) between 3 and 320
  ),
  constraint orders_customer_phone_snapshot_valid check (
    customer_phone_snapshot = btrim(customer_phone_snapshot)
    and length(customer_phone_snapshot) between 6 and 25
  ),
  constraint orders_payment_proof_path_valid check (
    payment_proof_path is null
    or (
      payment_proof_path = btrim(payment_proof_path)
      and length(payment_proof_path) between 10 and 512
      and position('..' in payment_proof_path) = 0
    )
  ),
  constraint orders_completed_timestamp_consistent check (
    (order_status = 'completed' and completed_at is not null)
    or (order_status <> 'completed' and completed_at is null)
  ),
  constraint orders_refund_started_consistent check (
    (payment_status in ('refund_pending', 'refunded') and refund_started_at is not null)
    or (payment_status not in ('refund_pending', 'refunded') and refund_started_at is null)
  ),
  constraint orders_refunded_consistent check (
    (payment_status = 'refunded' and refunded_at is not null)
    or (payment_status <> 'refunded' and refunded_at is null)
  )
);
alter table public.orders enable row level security;
revoke all on table public.orders from public, anon, authenticated;
create unique index orders_payment_proof_path_unique_idx
  on public.orders (payment_proof_path)
  where payment_proof_path is not null;
create index orders_user_created_idx on public.orders (user_id, created_at desc);
create index orders_order_status_created_idx on public.orders (order_status, created_at desc);
create index orders_payment_status_created_idx on public.orders (payment_status, created_at desc);
create index orders_offer_id_idx on public.orders (offer_id);
create index orders_game_id_idx on public.orders (game_id);
create table public.order_status_history (
  id bigint generated always as identity primary key,
  order_id uuid not null references public.orders(id) on delete cascade,
  event_type public.status_event_type not null,
  order_status public.order_status_type not null,
  payment_status public.payment_status_type not null,
  public_message text,
  changed_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint order_status_history_public_message_valid check (
    public_message is null
    or (
      public_message = btrim(public_message)
      and length(public_message) between 1 and 280
    )
  )
);
alter table public.order_status_history enable row level security;
revoke all on table public.order_status_history from public, anon, authenticated;
revoke all on sequence public.order_status_history_id_seq from public, anon, authenticated;
create index order_status_history_order_created_idx
  on public.order_status_history (order_id, created_at, id);
create index order_status_history_created_idx
  on public.order_status_history (created_at desc);
create table private.order_internal_notes (
  id bigint generated always as identity primary key,
  order_id uuid not null references public.orders(id) on delete cascade,
  author_user_id uuid not null references auth.users(id) on delete restrict,
  note text not null,
  created_at timestamptz not null default now(),
  constraint order_internal_notes_note_valid check (
    note = btrim(note) and length(note) between 1 and 2000
  )
);
revoke all on table private.order_internal_notes from public, anon, authenticated;
revoke all on sequence private.order_internal_notes_id_seq from public, anon, authenticated;
create index order_internal_notes_order_created_idx
  on private.order_internal_notes (order_id, created_at, id);
create or replace function private.is_admin()
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select coalesce(
    (select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin',
    false
  );
$$;
comment on function private.is_admin() is
  'Private authorization helper. Trusts only the signed JWT app_metadata role claim.';
revoke execute on function private.is_admin() from public, anon, authenticated;
create or replace function private.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
revoke execute on function private.set_updated_at() from public, anon, authenticated;
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function private.set_updated_at();
create trigger games_set_updated_at
before update on public.games
for each row execute function private.set_updated_at();
create trigger public_offers_set_updated_at
before update on public.public_offers
for each row execute function private.set_updated_at();
create trigger orders_set_updated_at
before update on public.orders
for each row execute function private.set_updated_at();
-- SECURITY DEFINER is required because this trusted Auth trigger writes a profile
-- while client roles have no INSERT privilege on public.profiles. It is not callable
-- by clients and verifies that it is executing only as the auth.users trigger.
create or replace function private.handle_auth_user_created()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text;
begin
  if tg_op <> 'INSERT' or tg_table_schema <> 'auth' or tg_table_name <> 'users' then
    raise exception 'unauthorized trigger context';
  end if;
  v_email := lower(btrim(coalesce(new.email, '')));
  if length(v_email) < 3 or length(v_email) > 320 then
    raise exception 'a valid email is required';
  end if;
  insert into public.profiles (id, email)
  values (new.id, v_email)
  on conflict (id) do update
  set email = excluded.email;
  return new;
end;
$$;
comment on function private.handle_auth_user_created() is
  'SECURITY DEFINER: trusted auth.users trigger creates the matching profile without exposing profile INSERT to clients.';
revoke execute on function private.handle_auth_user_created() from public, anon, authenticated;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_auth_user_created();
-- SECURITY DEFINER is required because this trusted Auth trigger synchronizes the
-- authoritative email while clients cannot update profiles.email directly.
create or replace function private.handle_auth_user_email_changed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text;
begin
  if tg_op <> 'UPDATE' or tg_table_schema <> 'auth' or tg_table_name <> 'users' then
    raise exception 'unauthorized trigger context';
  end if;
  v_email := lower(btrim(coalesce(new.email, '')));
  if length(v_email) < 3 or length(v_email) > 320 then
    raise exception 'a valid email is required';
  end if;
  update public.profiles
  set email = v_email
  where id = new.id;
  return new;
end;
$$;
comment on function private.handle_auth_user_email_changed() is
  'SECURITY DEFINER: trusted auth.users trigger keeps the profile email authoritative without exposing email updates to clients.';
revoke execute on function private.handle_auth_user_email_changed() from public, anon, authenticated;
create trigger on_auth_user_email_changed
  after update of email on auth.users
  for each row
  when (old.email is distinct from new.email)
  execute function private.handle_auth_user_email_changed();
create policy profiles_select_own_or_admin
on public.profiles
for select
to authenticated
using (
  id = (select auth.uid())
  or coalesce((select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin', false)
);
create policy profiles_update_own
on public.profiles
for update
to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));
grant select on table public.profiles to authenticated;
grant update (full_name, phone, locale) on table public.profiles to authenticated;
create policy games_select_active_or_admin
on public.games
for select
to authenticated
using (
  is_active
  or coalesce((select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin', false)
);
create policy games_admin_insert
on public.games
for insert
to authenticated
with check (coalesce((select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin', false));
create policy games_admin_update
on public.games
for update
to authenticated
using (coalesce((select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin', false))
with check (coalesce((select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin', false));
create policy games_admin_delete
on public.games
for delete
to authenticated
using (coalesce((select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin', false));
grant select, delete on table public.games to authenticated;
grant insert (
  slug,
  name_ar,
  name_fr,
  reward_unit_code,
  reward_unit_name_ar,
  reward_unit_name_fr,
  is_active,
  sort_order
) on table public.games to authenticated;
grant update (
  slug,
  name_ar,
  name_fr,
  reward_unit_code,
  reward_unit_name_ar,
  reward_unit_name_fr,
  is_active,
  sort_order
) on table public.games to authenticated;
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
  or coalesce((select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin', false)
);
create policy public_offers_admin_insert
on public.public_offers
for insert
to authenticated
with check (coalesce((select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin', false));
create policy public_offers_admin_update
on public.public_offers
for update
to authenticated
using (coalesce((select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin', false))
with check (coalesce((select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin', false));
create policy public_offers_admin_delete
on public.public_offers
for delete
to authenticated
using (coalesce((select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin', false));
grant select, delete on table public.public_offers to authenticated;
grant insert (
  game_id,
  name_ar,
  name_fr,
  reward_quantity,
  sale_price_dzd,
  is_published,
  sort_order
) on table public.public_offers to authenticated;
grant update (
  game_id,
  name_ar,
  name_fr,
  reward_quantity,
  sale_price_dzd,
  is_published,
  sort_order
) on table public.public_offers to authenticated;
create policy orders_select_own_or_admin
on public.orders
for select
to authenticated
using (
  user_id = (select auth.uid())
  or coalesce((select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin', false)
);
grant select on table public.orders to authenticated;
create policy order_status_history_admin_select
on public.order_status_history
for select
to authenticated
using (coalesce((select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin', false));
grant select on table public.order_status_history to authenticated;
-- SECURITY DEFINER is required to read auth.users and atomically insert an order
-- and its first history row while clients have no INSERT privileges on either table.
create or replace function public.create_order(
  p_client_request_id uuid,
  p_offer_id uuid,
  p_player_id text,
  p_in_game_name text,
  p_payment_method public.payment_method_type
)
returns public.orders
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_player_id text := btrim(coalesce(p_player_id, ''));
  v_in_game_name text := nullif(btrim(coalesce(p_in_game_name, '')), '');
  v_profile public.profiles%rowtype;
  v_user auth.users%rowtype;
  v_offer public.public_offers%rowtype;
  v_game public.games%rowtype;
  v_order public.orders%rowtype;
begin
  if v_user_id is null then
    raise exception using errcode = '28000', message = 'authentication required';
  end if;
  if p_client_request_id is null or p_offer_id is null or p_payment_method is null then
    raise exception using errcode = '22004', message = 'required order input is missing';
  end if;
  if length(v_player_id) not between 3 and 64 then
    raise exception using errcode = '22023', message = 'player_id must contain 3 to 64 characters';
  end if;
  if v_in_game_name is not null and length(v_in_game_name) > 64 then
    raise exception using errcode = '22023', message = 'in_game_name must not exceed 64 characters';
  end if;
  select * into v_user from auth.users where id = v_user_id;
  if not found then
    raise exception using errcode = 'P0002', message = 'authenticated user not found';
  end if;
  if v_user.email_confirmed_at is null then
    raise exception using errcode = '42501', message = 'email must be confirmed before creating an order';
  end if;
  if nullif(btrim(coalesce(v_user.email, '')), '') is null then
    raise exception using errcode = '22023', message = 'a trusted email is required';
  end if;
  select * into v_profile from public.profiles where id = v_user_id;
  if not found or not v_profile.is_complete then
    raise exception using errcode = '22023', message = 'profile must be complete before creating an order';
  end if;
  select * into v_offer
  from public.public_offers
  where id = p_offer_id
  for share;
  if not found or not v_offer.is_published then
    raise exception using errcode = 'P0002', message = 'published offer not found';
  end if;
  if v_offer.reward_quantity <= 0 or v_offer.sale_price_dzd <= 0 then
    raise exception using errcode = '22023', message = 'offer values must be positive';
  end if;
  select * into v_game
  from public.games
  where id = v_offer.game_id
  for share;
  if not found or not v_game.is_active then
    raise exception using errcode = 'P0002', message = 'active game not found';
  end if;
  insert into public.orders (
    user_id,
    client_request_id,
    game_id,
    offer_id,
    player_id,
    in_game_name,
    payment_method,
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
    customer_phone_snapshot
  )
  values (
    v_user_id,
    p_client_request_id,
    v_game.id,
    v_offer.id,
    v_player_id,
    v_in_game_name,
    p_payment_method,
    v_game.name_ar,
    v_game.name_fr,
    v_game.reward_unit_code,
    v_game.reward_unit_name_ar,
    v_game.reward_unit_name_fr,
    v_offer.name_ar,
    v_offer.name_fr,
    v_offer.reward_quantity,
    v_offer.sale_price_dzd,
    v_profile.full_name,
    btrim(v_user.email),
    v_profile.phone
  )
  on conflict (user_id, client_request_id) do nothing
  returning * into v_order;
  if found then
    insert into public.order_status_history (
      order_id,
      event_type,
      order_status,
      payment_status,
      changed_by
    ) values (
      v_order.id,
      'created',
      v_order.order_status,
      v_order.payment_status,
      v_user_id
    );
    return v_order;
  end if;
  select * into v_order
  from public.orders
  where user_id = v_user_id
    and client_request_id = p_client_request_id;
  if not found then
    raise exception using errcode = '40001', message = 'idempotency race could not be resolved';
  end if;
  if v_order.offer_id is distinct from p_offer_id
     or v_order.player_id is distinct from v_player_id
     or v_order.in_game_name is distinct from v_in_game_name
     or v_order.payment_method is distinct from p_payment_method then
    raise exception using errcode = '23505', message = 'client_request_id conflict: payload differs from the existing order';
  end if;
  return v_order;
end;
$$;
comment on function public.create_order(uuid, uuid, text, text, public.payment_method_type) is
  'SECURITY DEFINER: validates the authenticated user and authoritative snapshots, then inserts an idempotent order without granting direct INSERT.';
revoke execute on function public.create_order(uuid, uuid, text, text, public.payment_method_type)
  from public, anon;
grant execute on function public.create_order(uuid, uuid, text, text, public.payment_method_type)
  to authenticated;
-- SECURITY DEFINER is required because customers have no direct SELECT on the full
-- history table; the function returns only a safe projection after ownership check.
create or replace function public.get_my_order_timeline(p_order_id uuid)
returns table (
  event_type public.status_event_type,
  order_status public.order_status_type,
  payment_status public.payment_status_type,
  public_message text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception using errcode = '28000', message = 'authentication required';
  end if;
  if not exists (
    select 1 from public.orders o
    where o.id = p_order_id and o.user_id = v_user_id
  ) then
    raise exception using errcode = '42501', message = 'order timeline is not available';
  end if;
  return query
  select h.event_type, h.order_status, h.payment_status, h.public_message, h.created_at
  from public.order_status_history h
  where h.order_id = p_order_id
  order by h.created_at, h.id;
end;
$$;
comment on function public.get_my_order_timeline(uuid) is
  'SECURITY DEFINER: exposes only the owner-safe timeline projection and never changed_by or internal notes.';
revoke execute on function public.get_my_order_timeline(uuid) from public, anon;
grant execute on function public.get_my_order_timeline(uuid) to authenticated;
-- SECURITY DEFINER is required because internal notes are in a private schema with
-- no client grants. The function requires the immutable admin app_metadata claim.
create or replace function public.admin_add_order_internal_note(
  p_order_id uuid,
  p_note text
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin_id uuid := auth.uid();
  v_note text := btrim(coalesce(p_note, ''));
  v_id bigint;
begin
  if v_admin_id is null
     or private.is_admin() is not true then
    raise exception using errcode = '42501', message = 'admin access required';
  end if;
  if length(v_note) not between 1 and 2000 then
    raise exception using errcode = '22023', message = 'internal note must contain 1 to 2000 characters';
  end if;
  if not exists (select 1 from public.orders where id = p_order_id) then
    raise exception using errcode = 'P0002', message = 'order not found';
  end if;
  insert into private.order_internal_notes (order_id, author_user_id, note)
  values (p_order_id, v_admin_id, v_note)
  returning id into v_id;
  return v_id;
end;
$$;
comment on function public.admin_add_order_internal_note(uuid, text) is
  'SECURITY DEFINER: admin-only controlled write to private.order_internal_notes.';
revoke execute on function public.admin_add_order_internal_note(uuid, text) from public, anon;
grant execute on function public.admin_add_order_internal_note(uuid, text) to authenticated;
-- SECURITY DEFINER is required because internal notes remain inaccessible through
-- direct table grants. Only an authenticated admin receives them.
create or replace function public.admin_list_order_internal_notes(p_order_id uuid)
returns table (
  id bigint,
  order_id uuid,
  author_user_id uuid,
  note text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null
     or private.is_admin() is not true then
    raise exception using errcode = '42501', message = 'admin access required';
  end if;
  return query
  select n.id, n.order_id, n.author_user_id, n.note, n.created_at
  from private.order_internal_notes n
  where n.order_id = p_order_id
  order by n.created_at, n.id;
end;
$$;
comment on function public.admin_list_order_internal_notes(uuid) is
  'SECURITY DEFINER: admin-only controlled read from private.order_internal_notes.';
revoke execute on function public.admin_list_order_internal_notes(uuid) from public, anon;
grant execute on function public.admin_list_order_internal_notes(uuid) to authenticated;
-- SECURITY DEFINER is required because no client role has UPDATE on orders or INSERT
-- on history. Admin authorization and every allowed transition are enforced inside.
create or replace function public.admin_set_order_status(
  p_order_id uuid,
  p_order_status public.order_status_type,
  p_public_message text default null,
  p_internal_note text default null
)
returns public.orders
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin_id uuid := auth.uid();
  v_order public.orders%rowtype;
  v_public_message text := nullif(btrim(coalesce(p_public_message, '')), '');
  v_internal_note text := nullif(btrim(coalesce(p_internal_note, '')), '');
  v_allowed boolean := false;
begin
  if v_admin_id is null
     or private.is_admin() is not true then
    raise exception using errcode = '42501', message = 'admin access required';
  end if;
  if v_public_message is not null and length(v_public_message) > 280 then
    raise exception using errcode = '22023', message = 'public message must not exceed 280 characters';
  end if;
  if v_internal_note is not null and length(v_internal_note) > 2000 then
    raise exception using errcode = '22023', message = 'internal note must not exceed 2000 characters';
  end if;
  select * into v_order from public.orders where id = p_order_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'order not found';
  end if;
  if v_order.order_status = p_order_status then
    return v_order;
  end if;
  v_allowed := case v_order.order_status
    when 'new' then p_order_status in ('accepted', 'rejected', 'cancelled')
    when 'accepted' then p_order_status in ('processing', 'rejected', 'cancelled')
    when 'processing' then p_order_status in ('completed', 'rejected', 'cancelled')
    else false
  end;
  if not v_allowed then
    raise exception using errcode = '22023', message = 'invalid order status transition';
  end if;
  if p_order_status = 'completed' and v_order.payment_status <> 'paid' then
    raise exception using errcode = '22023', message = 'an order can be completed only after payment is paid';
  end if;
  if p_order_status in ('rejected', 'cancelled') and v_order.payment_status = 'paid' then
    update public.orders
    set
      order_status = p_order_status,
      payment_status = 'refund_pending',
      public_status_message = v_public_message,
      refund_started_at = coalesce(refund_started_at, now()),
      completed_at = null
    where id = p_order_id
    returning * into v_order;
    insert into public.order_status_history (
      order_id, event_type, order_status, payment_status, public_message, changed_by
    ) values (
      v_order.id, 'order_changed', v_order.order_status, v_order.payment_status,
      v_public_message, v_admin_id
    );
    insert into public.order_status_history (
      order_id, event_type, order_status, payment_status, public_message, changed_by
    ) values (
      v_order.id, 'refund_started', v_order.order_status, v_order.payment_status,
      v_public_message, v_admin_id
    );
  else
    update public.orders
    set
      order_status = p_order_status,
      public_status_message = v_public_message,
      completed_at = case when p_order_status = 'completed' then now() else null end
    where id = p_order_id
    returning * into v_order;
    insert into public.order_status_history (
      order_id, event_type, order_status, payment_status, public_message, changed_by
    ) values (
      v_order.id, 'order_changed', v_order.order_status, v_order.payment_status,
      v_public_message, v_admin_id
    );
  end if;
  if v_internal_note is not null then
    insert into private.order_internal_notes (order_id, author_user_id, note)
    values (v_order.id, v_admin_id, v_internal_note);
  end if;
  return v_order;
end;
$$;
comment on function public.admin_set_order_status(uuid, public.order_status_type, text, text) is
  'SECURITY DEFINER: admin-only finite-state order transition, including atomic refund_pending conversion for paid rejected/cancelled orders.';
revoke execute on function public.admin_set_order_status(uuid, public.order_status_type, text, text)
  from public, anon;
grant execute on function public.admin_set_order_status(uuid, public.order_status_type, text, text)
  to authenticated;
-- SECURITY DEFINER is required because payment state changes and history writes must
-- be atomic while direct UPDATE/INSERT privileges remain revoked.
create or replace function public.admin_set_payment_status(
  p_order_id uuid,
  p_payment_status public.payment_status_type,
  p_public_message text default null,
  p_internal_note text default null
)
returns public.orders
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin_id uuid := auth.uid();
  v_order public.orders%rowtype;
  v_public_message text := nullif(btrim(coalesce(p_public_message, '')), '');
  v_internal_note text := nullif(btrim(coalesce(p_internal_note, '')), '');
  v_allowed boolean := false;
begin
  if v_admin_id is null
     or private.is_admin() is not true then
    raise exception using errcode = '42501', message = 'admin access required';
  end if;
  if v_public_message is not null and length(v_public_message) > 280 then
    raise exception using errcode = '22023', message = 'public message must not exceed 280 characters';
  end if;
  if v_internal_note is not null and length(v_internal_note) > 2000 then
    raise exception using errcode = '22023', message = 'internal note must not exceed 2000 characters';
  end if;
  select * into v_order from public.orders where id = p_order_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'order not found';
  end if;
  if v_order.payment_status = p_payment_status then
    return v_order;
  end if;
  if v_order.order_status in ('completed', 'rejected', 'cancelled') then
    raise exception using errcode = '22023', message = 'payment status cannot change after the order is final';
  end if;
  if v_order.payment_status in ('refund_pending', 'refunded') then
    raise exception using errcode = '22023', message = 'refund states must use the dedicated refund workflow';
  end if;
  v_allowed := case v_order.payment_status
    when 'awaiting_payment' then p_payment_status in ('under_review', 'paid')
    when 'under_review' then p_payment_status in ('paid', 'proof_rejected')
    else false
  end;
  if not v_allowed then
    raise exception using errcode = '22023', message = 'invalid payment status transition';
  end if;
  if v_order.payment_method = 'transfer'
     and p_payment_status in ('under_review', 'paid')
     and v_order.payment_proof_path is null then
    raise exception using errcode = '22023', message = 'a valid transfer proof is required';
  end if;
  if v_order.payment_method = 'cash' and p_payment_status = 'under_review' then
    raise exception using errcode = '22023', message = 'cash payments do not use proof review';
  end if;
  update public.orders
  set payment_status = p_payment_status,
      public_status_message = v_public_message
  where id = p_order_id
  returning * into v_order;
  insert into public.order_status_history (
    order_id, event_type, order_status, payment_status, public_message, changed_by
  ) values (
    v_order.id, 'payment_changed', v_order.order_status, v_order.payment_status,
    v_public_message, v_admin_id
  );
  if v_internal_note is not null then
    insert into private.order_internal_notes (order_id, author_user_id, note)
    values (v_order.id, v_admin_id, v_internal_note);
  end if;
  return v_order;
end;
$$;
comment on function public.admin_set_payment_status(uuid, public.payment_status_type, text, text) is
  'SECURITY DEFINER: admin-only finite-state payment transition with transfer-proof enforcement.';
revoke execute on function public.admin_set_payment_status(uuid, public.payment_status_type, text, text)
  from public, anon;
grant execute on function public.admin_set_payment_status(uuid, public.payment_status_type, text, text)
  to authenticated;
-- SECURITY DEFINER is required to finalize a refund atomically without exposing
-- direct order updates or history inserts to client roles.
create or replace function public.admin_mark_refunded(
  p_order_id uuid,
  p_public_message text default null,
  p_internal_note text default null
)
returns public.orders
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin_id uuid := auth.uid();
  v_order public.orders%rowtype;
  v_public_message text := nullif(btrim(coalesce(p_public_message, '')), '');
  v_internal_note text := nullif(btrim(coalesce(p_internal_note, '')), '');
begin
  if v_admin_id is null
     or private.is_admin() is not true then
    raise exception using errcode = '42501', message = 'admin access required';
  end if;
  if v_public_message is not null and length(v_public_message) > 280 then
    raise exception using errcode = '22023', message = 'public message must not exceed 280 characters';
  end if;
  if v_internal_note is not null and length(v_internal_note) > 2000 then
    raise exception using errcode = '22023', message = 'internal note must not exceed 2000 characters';
  end if;
  select * into v_order from public.orders where id = p_order_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'order not found';
  end if;
  if v_order.payment_status <> 'refund_pending' then
    raise exception using errcode = '22023', message = 'only refund_pending orders can be marked refunded';
  end if;
  update public.orders
  set payment_status = 'refunded',
      refunded_at = now(),
      public_status_message = v_public_message
  where id = p_order_id
  returning * into v_order;
  insert into public.order_status_history (
    order_id, event_type, order_status, payment_status, public_message, changed_by
  ) values (
    v_order.id, 'refunded', v_order.order_status, v_order.payment_status,
    v_public_message, v_admin_id
  );
  if v_internal_note is not null then
    insert into private.order_internal_notes (order_id, author_user_id, note)
    values (v_order.id, v_admin_id, v_internal_note);
  end if;
  return v_order;
end;
$$;
comment on function public.admin_mark_refunded(uuid, text, text) is
  'SECURITY DEFINER: admin-only final refund transition and safe public/internal message separation.';
revoke execute on function public.admin_mark_refunded(uuid, text, text) from public, anon;
grant execute on function public.admin_mark_refunded(uuid, text, text) to authenticated;
insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'payment-proofs',
  'payment-proofs',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'application/pdf']::text[]
);
create policy payment_proofs_insert_own_order
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'payment-proofs'
  and owner_id = (select auth.uid())::text
  and length(name) between 10 and 512
  and position('..' in name) = 0
  and array_length(storage.foldername(name), 1) = 2
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and (storage.foldername(name))[2] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  and storage.filename(name) ~ '^[A-Za-z0-9][A-Za-z0-9_-]{15,199}\.(jpg|jpeg|png|pdf)$'
  and exists (
    select 1
    from public.orders o
    where o.id::text = (storage.foldername(name))[2]
      and o.user_id = (select auth.uid())
      and o.payment_method = 'transfer'
      and o.order_status in ('new', 'accepted', 'processing')
      and o.payment_status in ('awaiting_payment', 'proof_rejected')
  )
);
create policy payment_proofs_select_owner_or_admin
on storage.objects
for select
to authenticated
using (
  bucket_id = 'payment-proofs'
  and (
    exists (
      select 1
      from public.orders o
      where o.user_id = (select auth.uid())
        and o.payment_proof_path = storage.objects.name
    )
    or coalesce((select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin', false)
  )
);
-- SECURITY DEFINER is required to verify storage metadata and atomically bind a
-- proof to an order while clients have no direct UPDATE on public.orders.
create or replace function public.attach_payment_proof(
  p_order_id uuid,
  p_object_path text
)
returns public.orders
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_path text := btrim(coalesce(p_object_path, ''));
  v_parts text[];
  v_order public.orders%rowtype;
  v_object storage.objects%rowtype;
  v_mime text;
  v_size bigint;
begin
  if v_user_id is null then
    raise exception using errcode = '28000', message = 'authentication required';
  end if;
  if length(v_path) not between 10 and 512 or position('..' in v_path) > 0 then
    raise exception using errcode = '22023', message = 'invalid payment proof path';
  end if;
  v_parts := string_to_array(v_path, '/');
  if array_length(v_parts, 1) <> 3
     or v_parts[1] <> v_user_id::text
     or v_parts[2] <> p_order_id::text
     or v_parts[3] !~ '^[A-Za-z0-9][A-Za-z0-9_-]{15,199}\.(jpg|jpeg|png|pdf)$' then
    raise exception using errcode = '22023', message = 'payment proof path must match user/order/random-file';
  end if;
  select * into v_order
  from public.orders
  where id = p_order_id
  for update;
  if not found or v_order.user_id <> v_user_id then
    raise exception using errcode = '42501', message = 'order is not owned by the authenticated user';
  end if;
  if v_order.payment_method <> 'transfer' then
    raise exception using errcode = '22023', message = 'payment proofs are accepted only for transfer orders';
  end if;
  if v_order.order_status not in ('new', 'accepted', 'processing') then
    raise exception using errcode = '22023', message = 'a final order cannot receive a payment proof';
  end if;
  if v_order.payment_status not in ('awaiting_payment', 'proof_rejected') then
    raise exception using errcode = '22023', message = 'payment status does not allow attaching a proof';
  end if;
  select * into v_object
  from storage.objects
  where bucket_id = 'payment-proofs' and name = v_path;
  if not found then
    raise exception using errcode = 'P0002', message = 'payment proof object not found';
  end if;
  if v_object.owner_id is distinct from v_user_id::text then
    raise exception using errcode = '42501', message = 'payment proof owner does not match';
  end if;
  v_mime := v_object.metadata ->> 'mimetype';
  if v_mime not in ('image/jpeg', 'image/png', 'application/pdf') then
    raise exception using errcode = '22023', message = 'payment proof MIME type is not allowed';
  end if;
  if coalesce(v_object.metadata ->> 'size', '') !~ '^[0-9]+$' then
    raise exception using errcode = '22023', message = 'payment proof size metadata is invalid';
  end if;
  v_size := (v_object.metadata ->> 'size')::bigint;
  if v_size <= 0 or v_size > 5242880 then
    raise exception using errcode = '22023', message = 'payment proof exceeds the 5 MiB limit';
  end if;
  update public.orders
  set payment_proof_path = v_path,
      payment_status = 'under_review'
  where id = p_order_id
  returning * into v_order;
  insert into public.order_status_history (
    order_id, event_type, order_status, payment_status, changed_by
  ) values (
    v_order.id, 'proof_attached', v_order.order_status, v_order.payment_status, v_user_id
  );
  return v_order;
exception
  when unique_violation then
    raise exception using errcode = '23505', message = 'payment proof path is already linked to another order';
end;
$$;
comment on function public.attach_payment_proof(uuid, text) is
  'SECURITY DEFINER: owner-only proof binding after validating bucket, path, object ownership, MIME, size, and order state.';
revoke execute on function public.attach_payment_proof(uuid, text) from public, anon;
grant execute on function public.attach_payment_proof(uuid, text) to authenticated;
-- Ensure no accidental direct access remains after all objects exist.
revoke all on all tables in schema private from public, anon, authenticated;
revoke all on all sequences in schema private from public, anon, authenticated;
revoke execute on all functions in schema private from public, anon, authenticated;
revoke all on table public.orders from anon;
revoke all on table public.order_status_history from anon;
revoke all on table public.profiles from anon;
revoke all on table public.games from anon;
revoke all on table public.public_offers from anon;
commit;
