begin;

create function public.admin_get_order_details(
  p_order_id uuid
)
returns table (
  id uuid,
  game_name_ar_snapshot text,
  game_name_fr_snapshot text,
  offer_name_ar_snapshot text,
  offer_name_fr_snapshot text,
  reward_unit_code_snapshot text,
  reward_unit_name_ar_snapshot text,
  reward_unit_name_fr_snapshot text,
  customer_name_snapshot text,
  customer_email_snapshot text,
  customer_phone_snapshot text,
  player_id text,
  in_game_name text,
  sale_price_dzd_snapshot integer,
  reward_quantity_snapshot integer,
  payment_method public.payment_method_type,
  order_status public.order_status_type,
  payment_status public.payment_status_type,
  public_status_message text,
  created_at timestamptz,
  updated_at timestamptz,
  completed_at timestamptz,
  refund_started_at timestamptz,
  refunded_at timestamptz,
  has_payment_proof boolean
)
language plpgsql
stable
security invoker
set search_path = ''
as $function$
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

  return query
  select
    o.id,
    o.game_name_ar_snapshot,
    o.game_name_fr_snapshot,
    o.offer_name_ar_snapshot,
    o.offer_name_fr_snapshot,
    o.reward_unit_code_snapshot,
    o.reward_unit_name_ar_snapshot,
    o.reward_unit_name_fr_snapshot,
    o.customer_name_snapshot,
    o.customer_email_snapshot,
    o.customer_phone_snapshot,
    o.player_id,
    o.in_game_name,
    o.sale_price_dzd_snapshot,
    o.reward_quantity_snapshot,
    o.payment_method,
    o.order_status,
    o.payment_status,
    o.public_status_message,
    o.created_at,
    o.updated_at,
    o.completed_at,
    o.refund_started_at,
    o.refunded_at,
    (o.payment_proof_path is not null) as has_payment_proof
  from public.orders as o
  where o.id = p_order_id;
end;
$function$;

comment on function public.admin_get_order_details(uuid) is
  'SECURITY INVOKER: admin-only read projection for one order. Excludes ownership IDs, catalog IDs, proof paths, audit actors, and internal notes.';

revoke execute on function public.admin_get_order_details(uuid)
  from public, anon;

grant execute on function public.admin_get_order_details(uuid)
  to authenticated;

create function public.admin_get_order_timeline(
  p_order_id uuid
)
returns table (
  event_type public.status_event_type,
  order_status public.order_status_type,
  payment_status public.payment_status_type,
  public_message text,
  created_at timestamptz
)
language plpgsql
stable
security invoker
set search_path = ''
as $function$
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

  return query
  select
    h.event_type,
    h.order_status,
    h.payment_status,
    h.public_message,
    h.created_at
  from public.order_status_history as h
  where h.order_id = p_order_id
  order by h.created_at asc, h.id asc;
end;
$function$;

comment on function public.admin_get_order_timeline(uuid) is
  'SECURITY INVOKER: admin-only public-safe order timeline ordered by created_at and internal event ID. The event ID, order ID, changed_by, and internal notes are not returned.';

revoke execute on function public.admin_get_order_timeline(uuid)
  from public, anon;

grant execute on function public.admin_get_order_timeline(uuid)
  to authenticated;

commit;
