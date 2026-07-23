begin;

create function public.admin_get_order_payment_proof_path(
  p_order_id uuid
)
returns table (
  payment_proof_path text
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
  select o.payment_proof_path
  from public.orders as o
  join storage.objects as obj
    on obj.bucket_id = 'payment-proofs'
   and obj.name = o.payment_proof_path
   and obj.owner_id = o.user_id::text
  where o.id = p_order_id
    and o.payment_method = 'transfer'
    and o.payment_proof_path is not null
    and length(o.payment_proof_path) between 10 and 512
    and position('..' in o.payment_proof_path) = 0
    and array_length(storage.foldername(o.payment_proof_path), 1) = 2
    and (storage.foldername(o.payment_proof_path))[1] = o.user_id::text
    and (storage.foldername(o.payment_proof_path))[2] = o.id::text
    and storage.filename(o.payment_proof_path)
      ~ '^[A-Za-z0-9][A-Za-z0-9_-]{15,199}\.(jpg|jpeg|png|pdf)$';
end;
$function$;

comment on function public.admin_get_order_payment_proof_path(uuid) is
  'SECURITY INVOKER: admin-only read of one validated private Storage proof path. Returns no order data, Storage metadata, or signed URL.';

revoke execute on function public.admin_get_order_payment_proof_path(uuid)
  from public, anon;

grant execute on function public.admin_get_order_payment_proof_path(uuid)
  to authenticated;

commit;
