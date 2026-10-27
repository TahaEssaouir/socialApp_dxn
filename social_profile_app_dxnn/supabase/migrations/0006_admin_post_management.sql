-- 0006_admin_post_management.sql — modification et suppression des posters.

grant update, delete on public.posts to authenticated;

create policy "posts_admin_update"
on public.posts for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "posts_admin_delete"
on public.posts for delete
to authenticated
using (public.is_admin());

create policy "posters_admin_update"
on storage.objects for update
to authenticated
using (bucket_id = 'posters' and public.is_admin())
with check (bucket_id = 'posters' and public.is_admin());

create policy "posters_admin_delete"
on storage.objects for delete
to authenticated
using (bucket_id = 'posters' and public.is_admin());
