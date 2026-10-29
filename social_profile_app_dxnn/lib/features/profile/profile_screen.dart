import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

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
      if (_kind == PostKind.post) {
        return <Widget>[
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyPane(
              icon: Icons.grid_on,
              message: 'Aucun post pour le moment.',
            ),
          ),
        ];
      } else if (_kind == PostKind.reel) {
        return <Widget>[
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyPane(
              icon: Icons.movie_outlined,
              message: 'Aucun reel pour le moment.',
            ),
          ),
        ];
      } else {
        return <Widget>[
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyPane(
              icon: Icons.folder_outlined,
              message: 'Aucune explication pour le moment.',
            ),
          ),
        ];
      }
    }

    if (_kind == PostKind.explication) {
      return <Widget>[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          sliver: SliverList.builder(
            itemCount: filtered.length,
            itemBuilder: (BuildContext context, int index) =>
                _ExplicationTile(post: filtered[index], isAdmin: isAdmin),
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
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.8,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
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
                  if (platform == StatPlatform.youtube) ...<Widget>[
                    const SizedBox(height: 4),
                    const Text(
                      '@dxnmoroccoofficial',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
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
                  if (platform.officialUrl != null) ...<Widget>[
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: () async {
                        final Uri uri = Uri.parse(platform.officialUrl!);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text('Ouvrir ${platform.label}'),
                    ),
                    if (platform == StatPlatform.youtube) ...<Widget>[
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: () async {
                          await Clipboard.setData(
                            ClipboardData(text: platform.officialUrl!),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Lien YouTube copié.'),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 4,
                          ),
                          child: Row(
                            children: <Widget>[
                              const Icon(Icons.link, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SelectableText(
                                  platform.officialUrl!,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const Icon(Icons.copy, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 12),
                  const Text(
                    'Source : API officielle de la plateforme.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
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

const List<_ReactionOption> _reactionOptions = <_ReactionOption>[
  _ReactionOption(emoji: '😍', label: 'Love'),
  _ReactionOption(emoji: '🔥', label: 'Fire'),
  _ReactionOption(emoji: '👏', label: 'Bravo'),
  _ReactionOption(emoji: '😮', label: 'Wow'),
  _ReactionOption(emoji: '💬', label: 'Commentaire'),
];

class _ReactionOption {
  const _ReactionOption({required this.emoji, required this.label});

  final String emoji;
  final String label;
}

class _ReactionBar extends StatefulWidget {
  const _ReactionBar({super.key, this.compact = false});

  final bool compact;

  @override
  State<_ReactionBar> createState() => _ReactionBarState();
}

class _ReactionBarState extends State<_ReactionBar> {
  final Map<String, int> _counts = <String, int>{
    '😍': 0,
    '🔥': 0,
    '👏': 0,
    '😮': 0,
    '💬': 0,
  };
  final Set<String> _selected = <String>{};

  void _toggle(String emoji) {
    setState(() {
      final bool isSelected = _selected.contains(emoji);
      if (isSelected) {
        _selected.remove(emoji);
        _counts[emoji] = (_counts[emoji] ?? 0) - 1;
      } else {
        _selected.add(emoji);
        _counts[emoji] = (_counts[emoji] ?? 0) + 1;
      }
      if ((_counts[emoji] ?? 0) < 0) {
        _counts[emoji] = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> items = _reactionOptions
        .map((_ReactionOption option) {
          final bool selected = _selected.contains(option.emoji);
          final int count = _counts[option.emoji] ?? 0;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _toggle(option.emoji),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.compact ? 2 : 4),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.compact ? 4 : 6,
                  vertical: widget.compact ? 2 : 3,
                ),
                decoration: selected
                    ? BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      )
                    : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      option.emoji,
                      style: TextStyle(fontSize: widget.compact ? 13 : 18),
                    ),
                    if (!widget.compact || count > 0) ...<Widget>[
                      const SizedBox(width: 3),
                      Text(
                        '$count',
                        style: TextStyle(
                          fontSize: widget.compact ? 9 : 11,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        })
        .toList(growable: false);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 6 : 10,
        vertical: widget.compact ? 3 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: widget.compact ? 2 : 4,
        runSpacing: widget.compact ? 2 : 0,
        children: items,
      ),
    );
  }
}

class _ExplicationTile extends ConsumerWidget {
  const _ExplicationTile({required this.post, required this.isAdmin});

  final PostItem post;
  final bool isAdmin;

  Future<void> _openDrive(BuildContext context) async {
    final String url = posterPublicUrl(post.mediaPath);
    final Uri uri = Uri.tryParse(url) ?? Uri();
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      if (!context.mounted) return;
      await Clipboard.setData(ClipboardData(text: url));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lien copié dans le presse-papiers.')),
      );
      return;
    }
    final bool launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (launched) return;
    if (!context.mounted) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Impossible d\'ouvrir le lien. Copié dans le presse-papiers.',
        ),
      ),
    );
  }

  Future<void> _copyLink(BuildContext context) async {
    final String url = posterPublicUrl(post.mediaPath);
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lien copié dans le presse-papiers.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String name = (post.caption ?? '').trim().isEmpty
        ? 'Explication'
        : post.caption!.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openDrive(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF1F1F1F),
                  child: Icon(Icons.folder_outlined, color: Colors.white),
                ),
                title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: const Text(
                  'Google Drive',
                  style: TextStyle(color: Colors.white54),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (isAdmin)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        color: const Color(0xFF262626),
                        onSelected: (String value) async {
                          if (value == 'edit') {
                            context.push('/admin/edit/${post.id}', extra: post);
                          } else if (value == 'delete') {
                            final bool? confirmed = await showDialog<bool>(
                              context: context,
                              builder: (BuildContext context) => AlertDialog(
                                title: const Text('Supprimer l\'explication ?'),
                                content: const Text(
                                  'Cette action est irréversible.',
                                ),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Annuler'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
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
                                const SnackBar(
                                  content: Text('Explication supprimée.'),
                                ),
                              );
                            } catch (error, stack) {
                              log.error(
                                'Suppression de l\'explication impossible',
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
                    TextButton.icon(
                      onPressed: () => _copyLink(context),
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copier le lien'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _ReactionBar(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showReelLinksDialog(BuildContext context, PostItem post) {
  Future<void> openLink(String link) async {
    final Uri? uri = Uri.tryParse(link);
    if (uri == null || !await canLaunchUrl(uri)) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: const Text('Regarder ce Reel'),
      content: const Text('Choisissez la plateforme à ouvrir.'),
      actions: <Widget>[
        if (post.facebookLink?.trim().isNotEmpty ?? false)
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await openLink(post.facebookLink!.trim());
            },
            icon: const Icon(Icons.facebook),
            label: const Text('Voir sur Facebook'),
          ),
        if (post.instagramLink?.trim().isNotEmpty ?? false)
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await openLink(post.instagramLink!.trim());
            },
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Voir sur Instagram'),
          ),
      ],
    ),
  );
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
            if (post.kind == PostKind.reel)
              Center(
                child: IconButton.filled(
                  tooltip: 'Ouvrir les liens du Reel',
                  onPressed: () => _showReelLinksDialog(context, post),
                  icon: const Icon(Icons.play_arrow),
                  iconSize: 34,
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
              left: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: Icon(post.platform.icon, size: 13, color: Colors.white),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: _ReactionBar(compact: true),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
