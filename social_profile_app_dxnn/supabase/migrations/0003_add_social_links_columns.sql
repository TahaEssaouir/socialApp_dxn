alter table public.posts
  add column if not exists facebook_link text,
  add column if not exists instagram_link text;
