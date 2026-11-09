-- 0009_avatars_bucket.sql — bucket public de la photo de profil, écriture admin uniquement.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create policy "avatars_public_read"
on storage.objects for select
to anon, authenticated
using (bucket_id = 'avatars');

create policy "avatars_admin_insert"
on storage.objects for insert
to authenticated
with check (bucket_id = 'avatars' and public.is_admin());

create policy "avatars_admin_update"
on storage.objects for update
to authenticated
using (bucket_id = 'avatars' and public.is_admin())
with check (bucket_id = 'avatars' and public.is_admin());

create policy "avatars_admin_delete"
on storage.objects for delete
to authenticated
using (bucket_id = 'avatars' and public.is_admin());
