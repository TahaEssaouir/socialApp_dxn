-- 0001_init.sql — modèle de données du profil public.
-- Aucune écriture cliente : les stats viennent de l'Edge Function (service role),
-- les notifications d'un trigger, les posters de l'admin via RLS.

create type public.user_role as enum ('admin', 'user');
create type public.stat_platform as enum ('facebook', 'youtube', 'tiktok', 'instagram');
create type public.post_platform as enum ('whatsapp', 'facebook', 'instagram');
create type public.post_kind as enum ('post', 'reel', 'explication');

create table public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  role       public.user_role not null default 'user',
  created_at timestamptz not null default now()
);

create table public.brand_profile (
  id           smallint primary key default 1 check (id = 1),
  username     text not null,
  display_name text not null,
  bio          text,
  avatar_url   text,
  updated_at   timestamptz not null default now()
);

create table public.social_stats (
  platform        public.stat_platform primary key,
  followers_count bigint not null default 0 check (followers_count >= 0),
  source          text not null default 'api' check (source in ('api', 'manual')),
  last_success_at timestamptz,
  last_attempt_at timestamptz,
  last_error      text
);

create table public.posts (
  id         uuid primary key default gen_random_uuid(),
  platform   public.post_platform not null,
  kind       public.post_kind not null default 'post',
  caption    text check (char_length(caption) <= 2200),
  media_path text not null,
  created_by uuid default auth.uid() references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create index posts_feed_idx on public.posts (kind, created_at desc);

create table public.notifications (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references public.posts (id) on delete cascade,
  title      text not null,
  body       text,
  created_at timestamptz not null default now()
);

create index notifications_recent_idx on public.notifications (created_at desc);

-- Secrets de rafraîchissement (Meta / TikTok). Aucun accès client.
create table public.provider_tokens (
  provider      text primary key check (provider in ('meta', 'tiktok')),
  refresh_token text not null,
  updated_at    timestamptz not null default now()
);

alter table public.provider_tokens enable row level security;
