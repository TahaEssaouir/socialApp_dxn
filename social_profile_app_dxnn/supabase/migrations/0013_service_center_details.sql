-- 0013_service_center_details.sql — type (Centre / Branche) + lien de localisation.

alter table public.service_centers
  add column if not exists kind text not null default 'center',
  add column if not exists location text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'service_centers_kind_check'
  ) then
    alter table public.service_centers
      add constraint service_centers_kind_check
      check (kind in ('center', 'branch'));
  end if;
end;
$$;
