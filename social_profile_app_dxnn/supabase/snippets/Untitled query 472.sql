ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS facebook_link text;

ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS instagram_link text;