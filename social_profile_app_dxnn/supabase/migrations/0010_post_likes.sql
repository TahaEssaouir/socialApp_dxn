-- 0010_post_likes.sql — « J'aime » persistant (compteur global + état par appareil).

alter table public.posts
  add column if not exists likes_count integer not null default 0
  check (likes_count >= 0);

create table if not exists public.post_likes (
  post_id    uuid not null references public.posts (id) on delete cascade,
  device_id  text not null check (char_length(trim(device_id)) between 8 and 128),
  created_at timestamptz not null default now(),
  primary key (post_id, device_id)
);

create index if not exists post_likes_post_idx on public.post_likes (post_id);

alter table public.post_likes enable row level security;
-- Accès direct refusé ; tout passe par les fonctions security definer.
revoke all on public.post_likes from anon, authenticated;

-- Maintient posts.likes_count en cohérence.
create or replace function public.sync_post_likes_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.posts
    set likes_count = likes_count + 1
    where id = new.post_id;
    return new;
  else
    update public.posts
    set likes_count = greatest(likes_count - 1, 0)
    where id = old.post_id;
    return old;
  end if;
end;
$$;

revoke all on function public.sync_post_likes_count() from public;

drop trigger if exists post_likes_sync on public.post_likes;
create trigger post_likes_sync
after insert or delete on public.post_likes
for each row execute function public.sync_post_likes_count();

-- Bascule le « J'aime » d'un appareil sur un poster et renvoie l'état.
create or replace function public.toggle_post_like(
  p_post_id uuid,
  p_device_id text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_liked boolean;
  v_count integer;
begin
  if p_device_id is null or char_length(trim(p_device_id)) < 8 then
    raise exception 'device_id invalide';
  end if;

  if exists (
    select 1 from public.post_likes
    where post_id = p_post_id and device_id = p_device_id
  ) then
    delete from public.post_likes
    where post_id = p_post_id and device_id = p_device_id;
    v_liked := false;
  else
    insert into public.post_likes (post_id, device_id)
    values (p_post_id, p_device_id)
    on conflict do nothing;
    v_liked := exists (
      select 1 from public.post_likes
      where post_id = p_post_id and device_id = p_device_id
    );
  end if;

  select likes_count into v_count
  from public.posts
  where id = p_post_id;

  return jsonb_build_object(
    'liked', v_liked,
    'likes_count', coalesce(v_count, 0)
  );
end;
$$;

grant execute on function public.toggle_post_like(uuid, text)
  to anon, authenticated;

-- Retourne les ids des posters aimés par cet appareil (parmi une liste).
create or replace function public.get_liked_post_ids(
  p_device_id text,
  p_post_ids uuid[]
)
returns setof uuid
language sql
stable
security definer
set search_path = public
as $$
  select post_id
  from public.post_likes
  where device_id = p_device_id
    and post_id = any(p_post_ids);
$$;

grant execute on function public.get_liked_post_ids(text, uuid[])
  to anon, authenticated;
