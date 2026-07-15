-- Idempotent development seed. No users, offers, prices, roles, or secrets.
insert into public.games (
  slug,
  name_ar,
  name_fr,
  reward_unit_code,
  reward_unit_name_ar,
  reward_unit_name_fr,
  is_active,
  sort_order
)
values (
  'free-fire',
  'فري فاير',
  'Free Fire',
  'diamonds',
  'جواهر',
  'Diamants',
  true,
  0
)
on conflict (slug) do update
set
  name_ar = excluded.name_ar,
  name_fr = excluded.name_fr,
  reward_unit_code = excluded.reward_unit_code,
  reward_unit_name_ar = excluded.reward_unit_name_ar,
  reward_unit_name_fr = excluded.reward_unit_name_fr,
  is_active = excluded.is_active,
  sort_order = excluded.sort_order,
  updated_at = now();
