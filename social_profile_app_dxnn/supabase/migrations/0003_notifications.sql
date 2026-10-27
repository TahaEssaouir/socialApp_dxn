-- 0003_notifications.sql — notification in-app à chaque poster + Realtime.

create or replace function public.notify_new_post()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notifications (post_id, title, body)
  values (
    new.id,
    'Nouveau poster',
    coalesce(nullif(new.caption, ''), new.platform::text)
  );
  return new;
end;
$$;

revoke all on function public.notify_new_post() from public;

create trigger posts_notify
after insert on public.posts
for each row execute function public.notify_new_post();

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'posts'
  ) then
    alter publication supabase_realtime add table public.posts;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'social_stats'
  ) then
    alter publication supabase_realtime add table public.social_stats;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end;
$$;
