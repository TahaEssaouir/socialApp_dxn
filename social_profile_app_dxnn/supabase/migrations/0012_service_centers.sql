-- 0012_service_centers.sql — centres de services DXN Maroc (carte).

create table if not exists public.service_centers (
  id         uuid primary key default gen_random_uuid(),
  city       text not null check (char_length(trim(city)) between 1 and 120),
  name       text not null check (char_length(trim(name)) between 1 and 200),
  address    text,
  phone      text,
  email      text,
  created_by uuid default auth.uid() references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists service_centers_city_idx
  on public.service_centers (city);

alter table public.service_centers enable row level security;

grant select on public.service_centers to anon, authenticated;
grant insert, update, delete on public.service_centers to authenticated;

create policy "service_centers_read"
on public.service_centers for select
to anon, authenticated
using (true);

create policy "service_centers_admin_insert"
on public.service_centers for insert
to authenticated
with check (public.is_admin());

create policy "service_centers_admin_update"
on public.service_centers for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "service_centers_admin_delete"
on public.service_centers for delete
to authenticated
using (public.is_admin());

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'service_centers'
  ) then
    alter publication supabase_realtime add table public.service_centers;
  end if;
end;
$$;
