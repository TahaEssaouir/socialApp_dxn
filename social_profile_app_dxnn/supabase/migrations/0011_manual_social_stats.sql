-- 0011_manual_social_stats.sql — édition manuelle des followers par l'admin.

-- L'admin peut mettre à jour social_stats (ex. Facebook en saisie manuelle).
create policy "social_stats_admin_update"
on public.social_stats for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

grant update on public.social_stats to authenticated;
