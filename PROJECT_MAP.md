# PROJECT_MAP.md — Social Profile App (dashboard followers + posters)

> Statut : **APPROUVÉ v4 — M0 TERMINÉ**. Décisions du 2026-10-26 : comptes officiels de la marque,
> **lecture publique**, notifications in-app, images uniquement, Flutter + Supabase.
> Le mock UI est conservé jusqu'à M3, puis remplacé par les données Supabase.
> Date de référence : **2026-10-26** (UTC). Auteur : Tech Lead / Staff Engineer.
> Périmètre : application mobile (iOS/Android) + version web, style « profil Instagram »,
> 4 compteurs de followers dynamiques (Facebook / YouTube / TikTok / Instagram), rôles `admin` / `user`,
> publication de posters (WhatsApp / Facebook / Instagram), notifications in-app, version web.

## [HYPOTHÈSES DE TRAVAIL] (à invalider avant M1)

| # | Hypothèse | Si faux |
|---|---|---|
| A-01 | **Mono-profil** : l'app expose un seul profil de marque, partagé par tous les utilisateurs. Ce n'est pas un réseau social multi-profils. | Refonte du modèle (`brand_profile` → multi-lignes) et des RLS. |
| A-02 | Les 4 compteurs sont ceux des **comptes officiels de la marque**, pas de comptes publics arbitraires. | Ingestion par scraping/tiers : hors périmètre, coût + ToS. |
| A-03 | Les 4 libellés du haut sont **Facebook / YouTube / TikTok / Instagram**. Le mot « publication » de la demande désigne l'emplacement, pas le libellé. | Changement UI + mapping de données. |
| A-04 | **WhatsApp** est une source de posters uniquement, pas un compteur de followers (aucune API publique). | Compteur manuel ou retrait. |
| A-05 | L'admin publie des posters WhatsApp / Facebook / Instagram ; le user est strictement en lecture. | Ajout d'un rôle éditeur / modération. |
| A-06 | **Lecture publique** : le profil, les 4 compteurs et les posters sont visibles sans compte. Seul l'**admin** se connecte (email + mot de passe). Pas d'inscription publique. | RLS anonyme + inscription + UX auth pour tous. |
| A-07 | Web = **Flutter Web** (même code). Notifications **in-app uniquement** en V1 (badge + centre de notifications) ; push système hors V1. | Ajout Firebase/FCM + service worker + VAPID = milestone supplémentaire. |
| A-08 | « Reels » est une **catégorie de poster image**, pas une vidéo. V1 accepte uniquement JPEG/PNG/WebP ≤ 10 Mo. | Ajout `video_player`, transcodage, limites et coûts stockage. |
| A-09 | Pas de recherche ni de filtres plateforme en V1. Les onglets **Publications / Reels** structurent la grille ; l'admin peut modifier ou supprimer un poster. | +1 milestone et +surface RLS/UI. |

---

## [TECH_STACK]

### Constat du dépôt (existant, non jetable)

| Élément | État observé |
|---|---|
| `social_profile_app_dxnn/` | Projet **Flutter** (Android, iOS, web, Windows…), `lib/main.dart` = UI statique mockée, valeurs `12K`, `5.4K`…, aucun appel réseau. |
| `social_profile_app_dxnn/supabase/schema.sql` | **Vide**. |
| `social_dashboard_backend/main.py` | **FastAPI** mock, 3 `sleep()` + `/api/social-stats`, aucune persistance. |
| `pubspec.yaml` | SDK `^3.11.3`, zéro dépendance runtime hors `cupertino_icons`. |
| Git | 3 commits (`backend`, `upp`, `upp`), pas de CI, pas de tests. |

Décision : **on conserve Flutter** (déjà scaffoldé, cible web incluse, coût de réécriture nul) et on
**remplace FastAPI par Supabase** (Auth + Postgres + Storage + Realtime + Edge Functions).
FastAPI est archivé sous `legacy/`, jamais déployé.

### Versions vérifiées le 2026-10-26 (sources : pub.dev API, npm registry, Flutter releases JSON, docs éditeurs)

| Composant | Version retenue | Publication | Justification / note |
|---|---|---|---|
| Flutter (stable) | **3.47.8** | 2026-10-23 | Dernière stable. Machine locale : **3.41.5 / Dart 3.11.3** → `flutter upgrade` en M0. |
| Dart SDK | **3.13.7** | 2026-10-23 | Fourni par Flutter 3.47.8. Contrainte `sdk: ^3.13.0`. |
| `supabase_flutter` | **2.18.3** | 2026-10-12 | Auth + Postgres + Storage + Realtime, un seul SDK. |
| `flutter_riverpod` | **3.4.3** | 2026-09-03 | État async (auth, stats, fil), pas de `setState` global. |
| `go_router` | **18.1.1** | 2026-10-20 | URLs profondes obligatoires pour le web. |
| `cached_network_image` | **4.0.5** | 2026-10-21 | Cache des posters (grille type Instagram). |
| `image_picker` | **1.2.4** | 2026-10-06 | Sélection média admin (mobile + web). |
| `shared_preferences` | **2.5.6** | 2026-10-05 | `last_seen_notification_at` + cache des stats. |
| Supabase CLI | **2.122.0** | npm, dernier | Migrations, `functions deploy`, `secrets set`. |
| Postgres (Supabase) | 17.x managé | — | RLS, triggers, `pg_cron`, `pg_net`. |
| Edge Functions | Deno (runtime Supabase) | — | Appels HTTP plateformes + refresh tokens. |
| Facebook Graph API | **v26.0** | 2026-07-29 | Dernière version. `v20.0` retirée le **2026-09-24** ; `v21.0` retirée le **2027-01-21**. |
| Instagram Graph API | via Graph **v26.0** | — | Compte Business/Creator lié à une Page. |
| YouTube Data API | **v3** | — | `channels.list` = 1 unité / 10 000 par jour. |
| TikTok Display API | **v2** | doc MAJ 2026 | `/v2/user/info/`, scope `user.info.stats` pour `follower_count`. |

> **Bloquant toolchain** : `go_router 18.1.1` et `cached_network_image 4.0.5` exigent Flutter ≥ 3.44
> et Dart `^3.12.0`. La machine est en Flutter 3.41.5 / Dart 3.11.3 : l'upgrade M0 est un prérequis
> de compilation, pas une remise à niveau cosmétique.

### Explicitement rejeté (obsolète / surdimensionné / hors périmètre)

- **Firebase / FCM / `firebase_messaging`** : la demande est une notification **dans l'application**.
  Le badge Realtime + centre de notifications suffit. Push système = V2.
- **`video_player` / `chewie` / transcodage** : les posters sont des images en V1 (A-08).
- **`dio`** : aucun appel HTTP direct côté client (SDK Supabase + `functions.invoke` suffisent).
- **`freezed` / `json_serializable` / `build_runner`** : 4 modèles, ~120 lignes de `fromJson` manuel.
- **`fl_chart`** : aucun graphique demandé.
- **`intl` / `timeago`** : formateur compact + `il y a X` ≈ 30 lignes.
- **`url_launcher`** : aucun lien externe demandé en V1.
- **`flutter_local_notifications`** : notifications in-app, pas de notification OS.
- **Next.js / Expo / React** : le client est Flutter, déjà scaffoldé.
- **Scraping tiers (Apify/RapidAPI)** : coût, ToS, clés supplémentaires.
- Graph API ≤ v20, TikTok API v1, `supabase_flutter` v1, Riverpod v2, `go_router` < 10.
- Suppression de poster, édition de profil, likes, commentaires, recherche, filtres plateforme,
  historique/graphiques, multi-profils, i18n : **hors V1**. La modification et la suppression de posters
  sont couvertes par le parcours admin et la migration `0006_admin_post_management.sql`.

---

## [SYSTEM_FLOW]

### Acteurs

- **Visiteur anonyme** : consulte le profil, les 4 compteurs, la grille de posters et la cloche,
  sans compte (clé `anon` + RLS `SELECT`).
- **`admin`** : se connecte (email + mot de passe) ; c'est le seul rôle provisionné en V1.
  Le rôle `user` reste dans l'enum pour de futurs comptes authentifiés, sans inscription publique.
- **Service** : Edge Function planifiée qui rafraîchit les 4 compteurs.

### Parcours visiteur (objectifs vérifiables)

1. **VG-01** — Ouvre l'app/web **sans login** → écran profil : avatar, nom, bio, 4 compteurs.
   Warm start < 1 s (cache), cold start < 3 s sur milieu de gamme. Aucune valeur hardcodée.
2. **VG-02** — Les compteurs affichent la valeur persistée de `social_stats`, formatée
   (`1,2 M`, `12,4 k`), avec `last_success_at` visible au tap.
3. **VG-03** — La grille affiche les posters triés `created_at DESC`, onglets **Publications / Reels**,
   badge de plateforme (WhatsApp / Facebook / Instagram) sur chaque carte.
4. **VG-04** — Tap sur un poster → média plein écran + légende. Retour sans perte de scroll.
5. **VG-05** — La cloche affiche un badge = nombre de notifications postérieures à `last_seen`
   (persisté localement). L'ouverture du centre remet le badge à zéro.
6. **VG-06** — Un poster ajouté par l'admin apparaît dans la grille **sans redémarrage** (< 2 s)
   et incrémente le badge de notification.

### Parcours `admin`

7. **VG-07** — Le bouton « Ajouter » n'est visible que si la session est `admin`. Un visiteur qui
   force `/admin/new` est redirigé vers le login, puis reçoit un écran 403 s'il n'est pas admin.
8. **VG-08** — L'admin peut ouvrir le menu d'un poster, modifier ses métadonnées ou son image, et
   le supprimer après confirmation ; l'objet Storage est nettoyé.
   La RLS refuse aussi l'écriture côté serveur.
9. **VG-09** — Formulaire : plateforme, type (Post/Reel), légende, image (JPEG/PNG/WebP ≤ 10 Mo)
   → upload Storage → insert `posts` → succès visible < 5 s.
10. **VG-10** — La Edge Function planifiée met à jour les 4 compteurs. Un échec plateforme
   **n'écrase jamais** la dernière valeur valide : `followers_count` conservé, `last_error` renseigné.
11. **VG-11** — Parité web : mêmes parcours à 360 px et 1440 px, deep links `/post/:id` et
    `/notifications` rechargeables (F5) sans login ; session admin persistée après reload.

### Flux de données (serveur)

```
[pg_cron 6h] ──► Edge Function refresh-stats (service role)
                     ├─ YouTube Data API v3  (API key)
                     ├─ Graph v26.0 /{page-id}?fields=followers_count (Page token)
                     ├─ Graph v26.0 /{ig-user-id}?fields=followers_count (IG token)
                     ├─ TikTok /v2/user/info/?fields=follower_count (OAuth user token + refresh)
                     └─ WhatsApp : aucun compteur (posters uniquement)
                              │
                              ▼
                   UPDATE social_stats SET followers_count, last_success_at
                   (échec → last_attempt_at + last_error, valeur conservée)
                              │
                              ▼
                   Client : Supabase Realtime (postgres_changes) → UI
```

```
[INSERT posts par admin] ──► trigger SQL ──► INSERT notifications
                                                  │
                                                  ▼
                                      Realtime ──► badge + centre in-app
```

### Règle de véracité des données

- Un échec de récupération **n'écrase jamais** une valeur valide.
- `hiddenSubscriberCount = true` (YouTube) ou compte non autorisé : valeur précédente conservée,
  état « non synchronisé » discret via `last_error`.
- Aucun secret plateforme côté client.

---

## [ARCHITECTURE]

### Principe

**Monolithe client Flutter + BaaS Supabase.** Aucun serveur CRUD custom. Une seule fonction serveur
(Edge Function) pour ce que le client ne peut pas faire : secrets plateformes + cron.
Découpage par **domaines**, pas par couches techniques. Interdiction de fichiers < 40 lignes purement
délégatifs (no micro-files) : un domaine = 2 à 4 fichiers.

### Arborescence cible

```
lib/
  main.dart                 # bootstrap Supabase + runApp (≤ 30 lignes)
  app.dart                  # MaterialApp.router, thème sombre, guards de rôle
  core/
    supabase.dart           # client + constantes d'environnement (1 fichier)
    logger.dart             # journalisation async (1 fichier)
    format.dart             # compactCount(), timeAgo() (1 fichier)
  features/
    auth/                   # auth_repository.dart, auth_screen.dart
    profile/                # profile_screen.dart (header + 4 stats + bio + cloche)
    posts/                  # posts_repository.dart, posts_grid.dart, post_detail_screen.dart
    notifications/          # notifications_repository.dart, notifications_screen.dart, bell.dart
    admin/                  # admin_post_form.dart, admin_guard.dart
supabase/
  migrations/               # 0001_init.sql, 0002_rls.sql, 0003_notifications.sql
  functions/
    refresh-stats/index.ts
  tests/
    rls.sql                 # assertions pgTAP
```

### Modèle de données (`supabase/migrations/0001_init.sql`)

```sql
create type user_role     as enum ('admin','user');
create type stat_platform as enum ('facebook','youtube','tiktok','instagram');
create type post_platform as enum ('whatsapp','facebook','instagram');
create type post_kind     as enum ('post','reel','explication');

-- Utilisateurs de l'app (rôle uniquement ; l'identité vient de auth.users)
create table profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  role       user_role not null default 'user',
  created_at timestamptz not null default now()
);

-- Profil unique de la marque (mono-profil)
create table brand_profile (
  id           smallint primary key default 1 check (id = 1),
  username     text not null,
  display_name text not null,
  bio          text,
  avatar_url   text,
  updated_at   timestamptz not null default now()
);

-- 4 lignes fixes, une par plateforme
create table social_stats (
  platform        stat_platform primary key,
  followers_count bigint not null default 0 check (followers_count >= 0),
  source          text not null default 'api' check (source in ('api','manual')),
  last_success_at timestamptz,
  last_attempt_at timestamptz,
  last_error      text
);

create table posts (
  id          uuid primary key default gen_random_uuid(),
  platform    post_platform not null,
  kind        post_kind not null default 'post',
  caption     text check (char_length(caption) <= 2200),
  media_path  text not null,                 -- bucket "posters"
  created_by  uuid references profiles(id),
  created_at  timestamptz not null default now()
);
create index posts_feed_idx on posts (kind, created_at desc);

create table notifications (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references posts(id) on delete cascade,
  title      text not null,
  body       text,
  created_at timestamptz not null default now()
);
create index notifications_recent_idx on notifications (created_at desc);

-- Secrets de rafraîchissement (rotation TikTok / Meta). Aucune policy = service role only.
create table provider_tokens (
  provider     text primary key check (provider in ('meta','tiktok')),
  refresh_token text not null,
  updated_at   timestamptz not null default now()
);
alter table provider_tokens enable row level security;

-- Seed
insert into social_stats (platform) values ('facebook'),('youtube'),('tiktok'),('instagram');
insert into brand_profile (id, username, display_name, bio)
values (1, 'brand', 'Brand', 'Bio à définir');
```

### Notifications (trigger)

```sql
create function notify_new_post() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into notifications (post_id, title, body)
  values (new.id, 'Nouveau poster', coalesce(new.caption, new.platform::text));
  return new;
end $$;

create trigger posts_notify
after insert on posts
for each row execute function notify_new_post();
```

### RLS (résumé exécutable)

- `is_admin()` = `security definer`, `stable`, lit `profiles.role = 'admin'` pour `auth.uid()`.
- `social_stats`, `posts`, `notifications`, `brand_profile` : `SELECT` pour **`anon` et `authenticated`**
  (lecture publique) ; aucune écriture client. Écritures via service role (Edge Function) ou trigger
  `security definer`.
- `profiles` : `SELECT` de sa propre ligne uniquement (`authenticated`). Aucun `UPDATE` client
  (le rôle est provisionné hors app) → pas de trigger de garde nécessaire.
- Storage `posters` : bucket **public** en lecture, `INSERT` réservé à `is_admin()`,
  MIME whitelist (`image/jpeg`,`image/png`,`image/webp`), taille ≤ 10 Mo.
- `provider_tokens` : RLS activée, **aucune policy** → inaccessible aux clients.
- Realtime : `posts`, `social_stats`, `notifications` ajoutés à `supabase_realtime`.

### Décisions structurantes

| Sujet | Décision | Raison |
|---|---|---|
| Web | **Flutter Web**, même code, même repo (`flutter build web`) | Zéro duplication UI, déjà scaffoldé. |
| Admin web | Même build, route `/admin/new` gardée | Pas de back-office séparé. |
| Auth | **Login admin uniquement** ; visiteurs anonymes via clé `anon` + RLS `SELECT` | Le profil est public ; seul l'admin a besoin d'une identité. |
| Rôles | Colonne `profiles.role` ; `admin` provisionné, `user` conservé pour V2 | Pas de custom claims/JWT hook = moins de surface. |
| Inscription | **Aucune** en V1 | Évite spam et gestion de comptes inutile. |
| Notifications | Table + Realtime + `last_seen` local | Pas de table de lectures par utilisateur, pas de FCM. |
| Stats history | **Non implémenté** | Aucun graphique demandé. |
| Médias | Bucket public, URL directe, images seulement | Contenu marketing public ; signed URLs = +code. |
| Suppression | **Non implémentée en V1** | Hors périmètre ; soft-delete ajouté si besoin opérationnel. |
| Refresh manuel | **Non implémenté en V1** | Le cron 6 h suffit ; fallback ops via SQL. |

### Dégradation & erreurs

- Client hors-ligne : dernière valeur des stats + `last_seen` en cache (`shared_preferences`) ;
  bannière « hors ligne » ; grille en erreur avec retry.
- Edge Function : timeout 8 s par plateforme, `Promise.allSettled`, retour
  `{platform, ok, count?, error?}` ; jamais de throw global.
- Rotation des tokens : TikTok `refresh_token` (365 j) échangé à chaque run ; Meta long-lived token
  échangé périodiquement. Les nouveaux refresh tokens sont réécrits dans `provider_tokens`.
- Aucun secret côté client : tokens plateformes uniquement dans les secrets Supabase.

---

## [LOGGING] (Protocole 4)

`lib/core/logger.dart` — ~40 lignes, 4 niveaux `debug | info | warn | error`.

- API : `log.info('msg', data)` ; `debug` désactivé en release.
- **Non bloquant** : `unawaited()` vers `developer.log`, file mémoire bornée (200 entrées) pour le
  debug local ; aucun flush réseau en V1, jamais dans le chemin UI.
- Aucun PII : pas de token, pas d'email, pas de contenu de légende.
- Serveur : `console.log/warn/error` structuré JSON dans `refresh-stats`, exploitable dans les logs
  Supabase. Un échec plateforme = `warn` avec `platform` + code d'erreur, jamais le token.

---

## [MILESTONES] — plan d'action vérifiable

| # | Livrable | Critère de réussite (Verifiable Goal) |
|---|---|---|
| **M0** | Socle | ✅ Flutter 3.47.8 / Dart 3.13.7 ; dépendances résolues ; `flutter analyze` = 0 issue ; `flutter test` vert ; `.env` non commité ; `flutter build web --release` OK. |
| **M1** | Schéma + RLS + Storage | CLI Supabase installée ; `supabase db reset` OK ; migrations appliquées ; tests pgTAP : `anon` lecture OK, `anon` écriture refusée, `authenticated` non-admin écriture refusée, admin écriture autorisée ; bucket `posters` configuré. |
| **M2** | Auth admin + guards | Login/logout admin ; session persistée au reload web ; `/admin/new` redirige un visiteur vers le login puis 403 si non-admin (UI + RLS) ; VG-07. |
| **M3** | Profil + stats | VG-01, VG-02, VG-03, VG-04 ; aucune valeur hardcodée ; Realtime stats < 2 s. |
| **M4** | Ingestion followers | `refresh-stats` déployée ; YouTube + Meta renvoient des valeurs réelles ; TikTok OAuth validé ou fallback documenté ; échec simulé → valeur conservée ; cron 6 h actif ; VG-09. |
| **M5** | Admin + posters | VG-08 ; upload image ; insert `posts` ; grille + onglets ; Realtime < 2 s ; VG-06 (partie grille). |
| **M6** | Notifications in-app | Trigger → notification < 2 s ; badge ; centre ; reset `last_seen` ; VG-05, VG-06 complets. |
| **M7** | Web + durcissement | `flutter build web` OK ; responsive 360 → 1440 px ; deep links F5 ; Lighthouse accessibilité ≥ 90 ; logs vérifiés ; README de déploiement. |

**Chemin critique** : M0 → M1 → M2 → M3 → M5 → M6 → M7. M4 est parallélisable après M1 mais
bloqué par les accès plateformes (P-03/P-04).

**Hors périmètre explicite** : likes, commentaires, messagerie, multi-profils, historique/graphiques,
scraping, OAuth social côté utilisateur, paiement, i18n, web push, push système, suppression/édition
de poster, recherche, filtres plateforme, édition de profil.

### Journal d'exécution

- **M0 — 2026-10-26** : ✅ Flutter 3.47.8 / Dart 3.13.7 ; 7 dépendances runtime verrouillées ;
  `flutter analyze` = 0 ; `flutter test` = 1/1 ; `flutter build web --release` OK ;
  `.env.example` créé, `.env` ignoré ; avatar réseau du mock remplacé (test déterministe).
  ⚠️ Android : `cmdline-tools` manquants + licences non acceptées (P-18) ; build APK non vérifié.

---

## [ORPHANS & PENDING]

| # | Élément | Type | Impact | Décision attendue |
|---|---|---|---|---|
| P-01 | **Comptes ciblés** | ~~Bloquant~~ **Résolu** | Comptes officiels de la marque (décision 2026-10-26). | Fournir les identifiants/tokens en M4. |
| P-02 | **WhatsApp** : aucune API publique ne retourne un nombre d'abonnés (Cloud API = messagerie). | Scope | Pas de 5ᵉ compteur. | Confirmé : posters uniquement (A-04). |
| P-03 | **Meta** : `followers_count` exige une Page + un compte IG Business/Creator lié + tokens. | Bloquant M4 | Sans tokens : valeurs manuelles uniquement. | Fournir Page ID, IG User ID, tokens via secrets. |
| P-04 | **TikTok** : scope `user.info.stats` + OAuth du compte + rotation du refresh token. | Bloquant M4 | Sans OAuth : pas de valeur automatique. | Lancer la demande d'accès TikTok ; sinon valeur manuelle. |
| P-05 | **Accès** | ~~Ambiguïté~~ **Résolu** | Lecture publique anonyme ; login admin uniquement (décision 2026-10-26). | RLS `anon` en M1. |
| P-06 | **Notifications** | ~~Scope~~ **Résolu** | In-app uniquement (badge + centre) ; FCM hors V1 (décision 2026-10-26). | Aucune action. |
| P-07 | **Médias** | ~~Scope~~ **Résolu** | Images JPEG/PNG/WebP ≤ 10 Mo ; vidéo hors V1 (décision 2026-10-26). | Aucune action. |
| P-08 | **Libellés** | ~~Ambiguïté~~ **Résolu** | Facebook / YouTube / TikTok / Instagram (A-03). | Aucune action. |
| P-09 | `main.py` FastAPI mock + `schema.sql` vide | Dette | Confusion sur la source de vérité. | Archiver `main.py` sous `legacy/`, remplacer `schema.sql` par les migrations. |
| P-10 | Aucune suppression/édition de poster en V1 | Risque ops | Un poster erroné ne peut être retiré que via SQL. | Accepter en V1 ou ajouter le soft-delete (+1 milestone). |
| P-11 | Stockage des refresh tokens dans `provider_tokens` (plaintext, RLS sans policy) | Sécurité | DB chiffrée au repos ; accès service role uniquement. | Valider, ou migrer vers Supabase Vault en V2. |
| P-12 | Provisionnement du **compte admin** | Ops | Pas d'UI d'inscription. | Création via dashboard Supabase + `insert into profiles (id, role)`. |
| P-13 | Flavors dev/prod + signatures Android/iOS | Ops | Bloque la publication store. | M7. |
| P-14 | Suppression de compte / RGPD | Conformité | Non traité. | À planifier avant store. |
| P-15 | Maquette / specs UI détaillées | UI | Style exact non reproductible sans description. | Fournir écrans, couleurs, ordre des blocs. |
| P-16 | Multi-profils / multi-tenant | Scope | Modèle mono-profil. | Hors V1. |
| P-17 | CI (analyze + tests + migrations) | Qualité | Pas de garde-fou. | GitHub Actions en M7. |
| P-18 | **Android SDK** : `cmdline-tools` absent, licences non acceptées (`flutter doctor`) | Ops | `flutter build apk` impossible en l'état. | Installer cmdline-tools + `flutter doctor --android-licenses` avant M7. |
| P-19 | **Supabase CLI absente** (`supabase` non reconnu) ; Docker 28.4.0 présent | Ops | M1 ne peut pas démarrer. | `npm i -g supabase@2.122.0` ou `npx supabase@2.122.0`. |

---

## Décisions validées le 2026-10-26

| Question | Décision |
|---|---|
| Comptes suivis | **Comptes officiels de la marque** (Facebook Page, IG Business, YouTube, TikTok). |
| Accès | **Profil public en lecture** ; login **admin uniquement**. |
| Notifications | **In-app** : badge + centre via Realtime. Pas de FCM en V1. |
| Médias | **Images uniquement** (JPEG/PNG/WebP ≤ 10 Mo). |
| Architecture | **Flutter + Supabase**, FastAPI archivé, mono-profil. |
| Approbation | **M0 approuvé et démarré**. |

## Bloquants restants (M4 uniquement)

1. **P-03 Meta** : Page ID, IG User ID, tokens Page/IG Business.
2. **P-04 TikTok** : OAuth du compte + scope `user.info.stats` approuvé.
3. **P-10** : suppression et modification de posters désormais implémentées côté admin ; aucun soft-delete
   n'est prévu, la suppression physique est protégée par RLS.

---

## Prochaine étape

**M0 terminé.** En attente de validation pour démarrer **M1 — schéma + RLS + Storage**.
Prérequis M1 : installer la CLI Supabase (P-19) ; Docker est déjà présent.
Aucun code de production supplémentaire ne sera écrit avant cet accord.
