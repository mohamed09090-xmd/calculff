begin;

-- These orchestration RPCs deliberately remain SECURITY DEFINER because direct
-- order/history writes are revoked from clients. They delegate every transition
-- to the already-audited finite-state RPCs in one database transaction.
create function public.admin_accept_order(
  p_order_id uuid,
  p_public_message text default null
)
returns table (
  order_status public.order_status_type,
  payment_status public.payment_status_type
)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_order public.orders%rowtype;
begin
  if auth.uid() is null or private.is_admin() is not true then
    raise exception using
      errcode = '42501',
      message = 'admin access required';
  end if;

  select *
  into v_order
  from public.orders
  where id = p_order_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'order not found';
  end if;
  if v_order.order_status in ('completed', 'rejected', 'cancelled') then
    raise exception using
      errcode = '22023',
      message = 'final orders cannot be accepted';
  end if;
  if v_order.payment_status in ('proof_rejected', 'refund_pending', 'refunded') then
    raise exception using
      errcode = '22023',
      message = 'payment state cannot be accepted';
  end if;

  if v_order.payment_status in ('awaiting_payment', 'under_review') then
    select *
    into v_order
    from public.admin_set_payment_status(p_order_id, 'paid', null, null);
  end if;

  if v_order.order_status = 'new' then
    select *
    into v_order
    from public.admin_set_order_status(p_order_id, 'accepted', null, null);
  end if;
  if v_order.order_status = 'accepted' then
    select *
    into v_order
    from public.admin_set_order_status(
      p_order_id,
      'processing',
      p_public_message,
      null
    );
  end if;

  return query
  select v_order.order_status, v_order.payment_status;
end;
$function$;

comment on function public.admin_accept_order(uuid, text) is
  'SECURITY DEFINER: admin-only atomic payment acceptance and transition to processing; returns statuses only.';

revoke execute on function public.admin_accept_order(uuid, text)
  from public, anon;
grant execute on function public.admin_accept_order(uuid, text)
  to authenticated;

create function public.admin_reject_order(
  p_order_id uuid,
  p_public_message text default null
)
returns table (
  order_status public.order_status_type,
  payment_status public.payment_status_type
)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_order public.orders%rowtype;
begin
  if auth.uid() is null or private.is_admin() is not true then
    raise exception using
      errcode = '42501',
      message = 'admin access required';
  end if;

  select *
  into v_order
  from public.orders
  where id = p_order_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'order not found';
  end if;
  if v_order.order_status = 'rejected' then
    return query
    select v_order.order_status, v_order.payment_status;
    return;
  end if;
  if v_order.order_status in ('completed', 'cancelled') then
    raise exception using
      errcode = '22023',
      message = 'final orders cannot be rejected';
  end if;

  if v_order.payment_status = 'under_review' then
    select *
    into v_order
    from public.admin_set_payment_status(
      p_order_id,
      'proof_rejected',
      null,
      null
    );
  end if;

  select *
  into v_order
  from public.admin_set_order_status(
    p_order_id,
    'rejected',
    p_public_message,
    null
  );

  return query
  select v_order.order_status, v_order.payment_status;
end;
$function$;

comment on function public.admin_reject_order(uuid, text) is
  'SECURITY DEFINER: admin-only atomic proof/order rejection with automatic refund_pending for paid orders; returns statuses only.';

revoke execute on function public.admin_reject_order(uuid, text)
  from public, anon;
grant execute on function public.admin_reject_order(uuid, text)
  to authenticated;

commit;
