begin;

create index orders_created_at_id_desc_idx
  on public.orders (created_at desc, id desc);

create function public.admin_list_orders(
  p_order_status public.order_status_type default null,
  p_payment_status public.payment_status_type default null,
  p_payment_method public.payment_method_type default null,
  p_game_id uuid default null,
  p_date_from timestamptz default null,
  p_date_to_exclusive timestamptz default null,
  p_search_text text default null,
  p_cursor_created_at timestamptz default null,
  p_cursor_id uuid default null,
  p_limit integer default 25
)
returns table (
  id uuid,
  game_name_ar_snapshot text,
  game_name_fr_snapshot text,
  offer_name_ar_snapshot text,
  offer_name_fr_snapshot text,
  customer_name_snapshot text,
  player_id text,
  in_game_name text,
  sale_price_dzd_snapshot integer,
  reward_quantity_snapshot integer,
  reward_unit_name_ar_snapshot text,
  reward_unit_name_fr_snapshot text,
  payment_method public.payment_method_type,
  order_status public.order_status_type,
  payment_status public.payment_status_type,
  created_at timestamptz,
  has_payment_proof boolean,
  has_more boolean
)
language plpgsql
stable
security invoker
set search_path = ''
as $function$
declare
  v_search_text text := nullif(btrim(coalesce(p_search_text, '')), '');
  v_search_pattern text;
begin
  if auth.uid() is null
     or coalesce(
       ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'),
       false
     ) is not true then
    raise exception using
      errcode = '42501',
      message = 'admin access required';
  end if;

  if p_limit is null or p_limit < 1 or p_limit > 25 then
    raise exception using
      errcode = '22023',
      message = 'limit must be between 1 and 25';
  end if;

  if p_date_from is not null
     and p_date_to_exclusive is not null
     and p_date_to_exclusive <= p_date_from then
    raise exception using
      errcode = '22023',
      message = 'date_to_exclusive must be after date_from';
  end if;

  if (p_cursor_created_at is null) <> (p_cursor_id is null) then
    raise exception using
      errcode = '22023',
      message = 'cursor_created_at and cursor_id must be provided together';
  end if;

  if v_search_text is not null then
    if char_length(v_search_text) > 100 then
      raise exception using
        errcode = '22023',
        message = 'search_text must not exceed 100 characters';
    end if;

    if v_search_text ~ '[[:cntrl:]]' then
      raise exception using
        errcode = '22023',
        message = 'search_text contains control characters';
    end if;

    v_search_pattern :=
      '%' ||
      replace(
        replace(
          replace(v_search_text, E'\\', E'\\\\'),
          '%',
          E'\\%'
        ),
        '_',
        E'\\_'
      ) ||
      '%';
  end if;

  return query
  with candidates as materialized (
    select
      o.id,
      o.game_name_ar_snapshot,
      o.game_name_fr_snapshot,
      o.offer_name_ar_snapshot,
      o.offer_name_fr_snapshot,
      o.customer_name_snapshot,
      o.player_id,
      o.in_game_name,
      o.sale_price_dzd_snapshot,
      o.reward_quantity_snapshot,
      o.reward_unit_name_ar_snapshot,
      o.reward_unit_name_fr_snapshot,
      o.payment_method,
      o.order_status,
      o.payment_status,
      o.created_at,
      (o.payment_proof_path is not null) as has_payment_proof
    from public.orders as o
    where
      (p_order_status is null or o.order_status = p_order_status)
      and (p_payment_status is null or o.payment_status = p_payment_status)
      and (p_payment_method is null or o.payment_method = p_payment_method)
      and (p_game_id is null or o.game_id = p_game_id)
      and (p_date_from is null or o.created_at >= p_date_from)
      and (p_date_to_exclusive is null or o.created_at < p_date_to_exclusive)
      and (
        p_cursor_created_at is null
        or (o.created_at, o.id) < (p_cursor_created_at, p_cursor_id)
      )
      and (
        v_search_text is null
        or left(replace(o.id::text, '-', ''), 8)
             ilike v_search_pattern escape E'\\'
        or o.customer_name_snapshot
             ilike v_search_pattern escape E'\\'
        or o.player_id
             ilike v_search_pattern escape E'\\'
        or coalesce(o.in_game_name, '')
             ilike v_search_pattern escape E'\\'
      )
    order by o.created_at desc, o.id desc
    limit p_limit + 1
  ),
  page_metadata as (
    select count(*) > p_limit as has_more
    from candidates
  )
  select
    c.id,
    c.game_name_ar_snapshot,
    c.game_name_fr_snapshot,
    c.offer_name_ar_snapshot,
    c.offer_name_fr_snapshot,
    c.customer_name_snapshot,
    c.player_id,
    c.in_game_name,
    c.sale_price_dzd_snapshot,
    c.reward_quantity_snapshot,
    c.reward_unit_name_ar_snapshot,
    c.reward_unit_name_fr_snapshot,
    c.payment_method,
    c.order_status,
    c.payment_status,
    c.created_at,
    c.has_payment_proof,
    m.has_more
  from candidates as c
  cross join page_metadata as m
  order by c.created_at desc, c.id desc
  limit p_limit;
end;
$function$;

comment on function public.admin_list_orders(
  public.order_status_type,
  public.payment_status_type,
  public.payment_method_type,
  uuid,
  timestamptz,
  timestamptz,
  text,
  timestamptz,
  uuid,
  integer
) is
  'SECURITY INVOKER: admin-only read projection for cursor-paginated order lists. Excludes customer contact data, user_id, client_request_id, proof paths, and audit actor identifiers.';

revoke execute on function public.admin_list_orders(
  public.order_status_type,
  public.payment_status_type,
  public.payment_method_type,
  uuid,
  timestamptz,
  timestamptz,
  text,
  timestamptz,
  uuid,
  integer
) from public, anon;

grant execute on function public.admin_list_orders(
  public.order_status_type,
  public.payment_status_type,
  public.payment_method_type,
  uuid,
  timestamptz,
  timestamptz,
  text,
  timestamptz,
  uuid,
  integer
) to authenticated;

commit;
