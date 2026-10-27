-- Données de démonstration locales. Ne contient aucun secret.
-- Le compte admin est créé par scripts/create-admin.mjs (Admin API).

insert into public.brand_profile (id, username, display_name, bio)
values (1, 'nxt_taha', 'Nxt Taha', E'🔥 Pubg mobile 🔥\n🇲🇦')
on conflict (id) do nothing;

insert into public.social_stats (platform)
values ('facebook'), ('youtube'), ('tiktok'), ('instagram')
on conflict (platform) do nothing;
