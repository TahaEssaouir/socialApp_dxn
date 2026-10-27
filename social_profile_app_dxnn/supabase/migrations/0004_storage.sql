-- 0004_storage.sql — bucket public des posters, écriture admin uniquement.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'posters',
  'posters',
  true,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create policy "posters_public_read"
on storage.objects for select
to anon, authenticated
using (bucket_id = 'posters');

create policy "posters_admin_insert"
on storage.objects for insert
to authenticated
with check (bucket_id = 'posters' and public.is_admin());
