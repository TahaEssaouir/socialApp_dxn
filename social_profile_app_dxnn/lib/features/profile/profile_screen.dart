import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/logger.dart';
import '../../core/ui.dart';
import '../auth/auth_repository.dart';
import '../admin/admin_repository.dart';
import '../notifications/notification_bell.dart';
import '../posts/posts_repository.dart';
import 'profile_repository.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  PostKind _kind = PostKind.post;

  Future<void> _refresh() async {
    ref.invalidate(brandProfileProvider);
    ref.invalidate(socialStatsProvider);
    ref.invalidate(postsProvider);
    try {
      await ref.read(brandProfileProvider.future);
    } catch (error) {
      // L'état d'erreur est déjà exposé par le provider.
    }
  }

  Future<void> _signOut() async {
    try {
      await ref.read(authRepositoryProvider).signOut();
      if (!mounted) return;
      context.go('/');
    } catch (error, stack) {
      log.error('Déconnexion impossible', error, stack);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Déconnexion impossible.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<BrandProfile> brandAsync = ref.watch(brandProfileProvider);
    final AsyncValue<List<SocialStat>> statsAsync = ref.watch(
      socialStatsProvider,
    );
    final AsyncValue<List<PostItem>> postsAsync = ref.watch(postsProvider);
    final bool isAdmin = ref.watch(isAdminProvider).value ?? false;
    final BrandProfile? brand = brandAsync.value;

    return DefaultTabController(
      length: PostKind.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(brand?.username ?? 'Profil'),
          leading: isAdmin
              ? null
              : IconButton(
                  tooltip: 'Connexion administrateur',
                  onPressed: () => context.push('/login'),
                  icon: const Icon(Icons.lock_outline),
                ),
          actions: <Widget>[
            const NotificationBell(),
            if (isAdmin)
              IconButton(
                tooltip: 'Ajouter un poster',
                onPressed: () => context.push('/admin/new'),
                icon: const Icon(Icons.add_box_outlined),
              ),
            if (isAdmin)
              PopupMenuButton<String>(
                tooltip: 'Compte administrateur',
                icon: const Icon(Icons.account_circle_outlined),
                onSelected: (String value) {
                  if (value == 'logout') {
                    unawaited(_signOut());
                  }
                },
                itemBuilder: (BuildContext context) =>
                    const <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'logout',
                        child: Text('Déconnexion'),
                      ),
                    ],
              ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 935),
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: <Widget>[
                  if (brandAsync.hasError && brand == null)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: ErrorPane(
                        message: 'Le profil est temporairement indisponible.',
                        onRetry: () => ref.invalidate(brandProfileProvider),
                      ),
                    )
                  else ...<Widget>[
                    SliverToBoxAdapter(
                      child: _ProfileHeader(
                        brand: brand,
                        stats: statsAsync.value,
                        statsHasError: statsAsync.hasError,
                        statsLoading: statsAsync.isLoading,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: TabBar(
                        onTap: (int index) => setState(() {
                          _kind = PostKind.values[index];
                        }),
                        tabs: PostKind.values
                            .map(
                              (PostKind kind) => Tab(text: kind.sectionLabel),
                            )
                            .toList(growable: false),
                      ),
                    ),
                    ..._buildGrid(postsAsync, isAdmin),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildGrid(AsyncValue<List<PostItem>> async, bool isAdmin) {
    final List<PostItem>? items = async.value;

    if (items == null) {
      if (async.hasError) {
        return <Widget>[
          SliverFillRemaining(
            hasScrollBody: false,
            child: ErrorPane(
              message: 'Impossible de charger les posters.',
              onRetry: () => ref.invalidate(postsProvider),
            ),
          ),
        ];
      }
      return const <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: LoadingPane(label: 'Chargement des posters…'),
        ),
      ];
    }

    final List<PostItem> filtered = items
        .where((PostItem post) => post.kind == _kind)
        .toList(growable: false);

    if (filtered.isEmpty) {
      final bool isPost = _kind == PostKind.post;
      return <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyPane(
            icon: isPost ? Icons.grid_on : Icons.movie_outlined,
            message: isPost
                ? 'Aucun post pour le moment.'
                : 'Aucun reel pour le moment.',
          ),
        ),
      ];
    }

    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.only(bottom: 24),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            childAspectRatio: 1,
          ),
          itemCount: filtered.length,
          itemBuilder: (BuildContext context, int index) =>
              _PostTile(post: filtered[index], isAdmin: isAdmin),
        ),
      ),
    ];
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.brand,
    required this.stats,
    required this.statsHasError,
    required this.statsLoading,
  });

  final BrandProfile? brand;
  final List<SocialStat>? stats;
  final bool statsHasError;
  final bool statsLoading;

  SocialStat? _statFor(StatPlatform platform) {
    for (final SocialStat stat in stats ?? const <SocialStat>[]) {
      if (stat.platform == platform) return stat;
    }
    return null;
  }

  void _showDetails(
    BuildContext context,
    StatPlatform platform,
    SocialStat? stat,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(platform.icon, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      platform.label,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  stat == null ? '—' : compactCount(stat.followersCount),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text(
                  'followers',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 18),
                Text(
                  'Dernière synchronisation : '
                  '${stat?.lastSuccessAt == null ? 'jamais' : formatDateTime(stat!.lastSuccessAt!)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                if (stat?.lastError != null &&
                    stat!.lastError!.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          stat.lastError!,
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Source : API officielle de la plateforme.',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget avatar = BrandAvatar(url: brand?.avatarUrl);
    final Widget statsRow = Row(
      children: StatPlatform.values
          .map((StatPlatform platform) {
            final SocialStat? stat = _statFor(platform);
            return Expanded(
              child: _StatColumn(
                platform: platform,
                stat: stat,
                loading: statsLoading,
                hasError: statsHasError,
                onTap: () => _showDetails(context, platform, stat),
              ),
            );
          })
          .toList(growable: false),
    );

    final Widget identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          brand?.username ?? 'Profil',
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
        ),
        if (brand != null && brand!.displayName != brand!.username) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            brand!.displayName,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
        if (statsHasError && stats == null) ...<Widget>[
          const SizedBox(height: 6),
          const Text(
            'Statistiques indisponibles',
            style: TextStyle(color: Colors.orange, fontSize: 12),
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              if (constraints.maxWidth < 560) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        avatar,
                        const SizedBox(width: 16),
                        Expanded(child: identity),
                      ],
                    ),
                    const SizedBox(height: 18),
                    statsRow,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  avatar,
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        identity,
                        const SizedBox(height: 18),
                        statsRow,
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          if (brand?.bio?.trim().isNotEmpty ?? false) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              brand!.bio!.trim(),
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.platform,
    required this.stat,
    required this.loading,
    required this.hasError,
    required this.onTap,
  });

  final StatPlatform platform;
  final SocialStat? stat;
  final bool loading;
  final bool hasError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String value = stat != null
        ? compactCount(stat!.followersCount)
        : (loading ? '…' : '—');
    final bool warning = stat?.lastError != null || (hasError && stat == null);

    return Semantics(
      button: true,
      label:
          '${platform.label}, '
          '${stat == null ? 'donnée indisponible' : '${stat!.followersCount} followers'}',
      child: Tooltip(
        message: 'Détails ${platform.label}',
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (warning)
                      const Padding(
                        padding: EdgeInsets.only(left: 3),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          size: 12,
                          color: Colors.orange,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  platform.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PostTile extends ConsumerWidget {
  const _PostTile({required this.post, required this.isAdmin});

  final PostItem post;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      button: true,
      label: '${post.platform.label}, ${post.kind.label}, ouvrir le poster',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            GestureDetector(
              onTap: () => context.push('/post/${post.id}'),
              child: Hero(
                tag: 'post-${post.id}',
                child: CachedNetworkImage(
                  imageUrl: posterPublicUrl(post.mediaPath),
                  fit: BoxFit.cover,
                  memCacheWidth: 500,
                  placeholder: (BuildContext context, String url) =>
                      const ColoredBox(color: Color(0xFF121212)),
                  errorWidget:
                      (BuildContext context, String url, Object error) =>
                          const ColoredBox(
                            color: Color(0xFF121212),
                            child: Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: Colors.white38,
                              ),
                            ),
                          ),
                ),
              ),
            ),
            if (isAdmin)
              Positioned(
                top: 4,
                right: 4,
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  color: const Color(0xFF262626),
                  onSelected: (String value) async {
                    if (value == 'edit') {
                      context.push('/admin/edit/${post.id}', extra: post);
                    } else if (value == 'delete') {
                      final bool? confirmed = await showDialog<bool>(
                        context: context,
                        builder: (BuildContext context) => AlertDialog(
                          title: const Text('Supprimer le poster ?'),
                          content: const Text('Cette action est irréversible.'),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Annuler'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Supprimer'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true || !context.mounted) return;
                      try {
                        await ref
                            .read(adminRepositoryProvider)
                            .deletePoster(
                              id: post.id,
                              mediaPath: post.mediaPath,
                            );
                        ref.invalidate(postsProvider);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Poster supprimé.')),
                        );
                      } catch (error, stack) {
                        log.error(
                          'Suppression du poster impossible',
                          error,
                          stack,
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Suppression impossible.'),
                          ),
                        );
                      }
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      const <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'edit',
                          child: Text('Modifier'),
                        ),
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('Supprimer'),
                        ),
                      ],
                ),
              ),
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: Icon(post.platform.icon, size: 13, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
