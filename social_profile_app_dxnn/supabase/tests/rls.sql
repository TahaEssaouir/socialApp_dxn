begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(20);

-- Fixtures : deux utilisateurs auth + profils.
insert into auth.users (id, email, aud, role, raw_app_meta_data, raw_user_meta_data)
values
  ('11111111-1111-4111-8111-111111111111', 'admin@test.local', 'authenticated', 'authenticated',
   '{"provider":"email","providers":["email"]}', '{}'),
  ('22222222-2222-4222-8222-222222222222', 'user@test.local', 'authenticated', 'authenticated',
   '{"provider":"email","providers":["email"]}', '{}');

insert into public.profiles (id, role)
values
  ('11111111-1111-4111-8111-111111111111', 'admin'),
  ('22222222-2222-4222-8222-222222222222', 'user');

-- anon : lecture publique, aucune écriture.
set local role anon;

select is((select count(*)::int from public.brand_profile), 1, 'anon lit brand_profile');
select is((select count(*)::int from public.social_stats), 4, 'anon lit social_stats');
select is((select count(*)::int from public.posts), 0, 'anon lit posts');
select is((select count(*)::int from public.notifications), 0, 'anon lit notifications');
select throws_ok(
  'select * from public.provider_tokens',
  '42501',
  null,
  'anon ne lit pas provider_tokens'
);
select throws_ok(
  $$insert into public.posts (platform, kind, media_path) values ('instagram', 'post', 'x.jpg')$$,
  '42501',
  null,
  'anon ne peut pas insérer un poster'
);

reset role;

-- authenticated non-admin : lecture de son profil, aucune écriture.
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}',
  true
);

select ok(not public.is_admin(), 'un user n''est pas admin');
select is((select count(*)::int from public.profiles), 1, 'un user ne voit que son profil');
select throws_ok(
  $$insert into public.posts (platform, kind, media_path) values ('instagram', 'post', 'x.jpg')$$,
  '42501',
  null,
  'un user ne peut pas insérer un poster'
);
select throws_ok(
  'select * from public.provider_tokens',
  '42501',
  null,
  'un user ne lit pas provider_tokens'
);

reset role;

-- admin : lecture + insertion, notification automatique.
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}',
  true
);

select ok(public.is_admin(), 'l''admin est reconnu');
select lives_ok(
  $$insert into public.posts (platform, kind, caption, media_path)
    values ('instagram', 'post', 'Premier poster', 'seed/premier.jpg')$$,
  'l''admin insère un poster'
);
select lives_ok(
  $$update public.brand_profile set display_name = 'Nxt Taha' where id = 1$$,
  'l''admin modifie le profil de marque'
);

reset role;

select is((select count(*)::int from public.posts), 1, 'le poster est visible');
select is((select count(*)::int from public.notifications), 1, 'le trigger crée la notification');

-- Realtime et Storage.
select is(
  (select count(*)::int from pg_publication_tables
   where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'posts'),
  1,
  'posts est publié en Realtime'
);
select is(
  (select count(*)::int from pg_publication_tables
   where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'social_stats'),
  1,
  'social_stats est publié en Realtime'
);
select is(
  (select count(*)::int from pg_publication_tables
   where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'notifications'),
  1,
  'notifications est publié en Realtime'
);
select is(
  (select file_size_limit from storage.buckets where id = 'posters'),
  10485760::bigint,
  'le bucket posters est limité à 10 Mo'
);
select is(
  (select public from storage.buckets where id = 'posters'),
  true,
  'le bucket posters est public en lecture'
);

select * from finish();
rollback;
