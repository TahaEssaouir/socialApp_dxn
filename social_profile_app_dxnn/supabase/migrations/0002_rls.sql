-- 0002_rls.sql — lecture publique, écriture admin uniquement.

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and role = 'admin'
  );
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to anon, authenticated;

alter table public.profiles enable row level security;
alter table public.brand_profile enable row level security;
alter table public.social_stats enable row level security;
alter table public.posts enable row level security;
alter table public.notifications enable row level security;

-- Privilèges explicites : le RLS ne remplace pas les grants.
revoke all on public.profiles, public.brand_profile, public.social_stats,
  public.posts, public.notifications from anon, authenticated;

grant select on public.brand_profile, public.social_stats, public.posts,
  public.notifications to anon, authenticated;
grant select on public.profiles to authenticated;
grant insert on public.posts to authenticated;
grant update on public.brand_profile to authenticated;

revoke all on public.provider_tokens from anon, authenticated;

create policy "profiles_read_own"
on public.profiles for select
to authenticated
using (id = auth.uid());

create policy "brand_profile_read"
on public.brand_profile for select
to anon, authenticated
using (true);

create policy "brand_profile_admin_update"
on public.brand_profile for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "social_stats_read"
on public.social_stats for select
to anon, authenticated
using (true);

create policy "posts_read"
on public.posts for select
to anon, authenticated
using (true);

create policy "posts_admin_insert"
on public.posts for insert
to authenticated
with check (public.is_admin() and created_by = auth.uid());

create policy "notifications_read"
on public.notifications for select
to anon, authenticated
using (true);
