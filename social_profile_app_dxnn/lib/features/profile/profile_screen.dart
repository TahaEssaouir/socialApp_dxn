import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/floating_nav.dart';
import '../../core/logger.dart';
import '../../core/ui.dart';
import '../auth/auth_repository.dart';
import '../admin/admin_repository.dart';
import '../notifications/notification_bell.dart';
import '../posts/likes_repository.dart';
import '../posts/posts_repository.dart';
import 'profile_repository.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  PostKind _kind = PostKind.post;
  bool _avatarBusy = false;
  final ImagePicker _avatarPicker = ImagePicker();

  void _syncLikedIds(List<PostItem> posts) {
    if (posts.isEmpty) return;
    final List<String> ids = posts
        .map((PostItem p) => p.id)
        .toList(growable: false);
    unawaited(ensureLikesChecked(ref, ids));
  }

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

  /// Feuille de choix pour la photo de profil (admin uniquement).
  Future<void> _showAvatarActionsSheet(BrandProfile? brand) async {
    final bool hasPhoto = (brand?.avatarUrl ?? '').trim().isNotEmpty;
    final String? action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(
                Icons.photo_camera_outlined,
                color: kDeepTeal,
              ),
              title: Text(hasPhoto ? 'Modifier la photo' : 'Ajouter une photo'),
              subtitle: const Text('JPG, PNG ou WebP · 10 Mo maximum'),
              onTap: () => Navigator.pop(sheetContext, 'change'),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Supprimer la photo'),
                onTap: () => Navigator.pop(sheetContext, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    await _changeAvatar(remove: action == 'remove');
  }

  Future<void> _changeAvatar({required bool remove}) async {
    if (_avatarBusy) return;
    setState(() => _avatarBusy = true);

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    try {
      if (remove) {
        await ref.read(profileRepositoryProvider).removeAvatar();
      } else {
        final XFile? picked = await _avatarPicker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1024,
          imageQuality: 90,
        );
        if (picked == null) {
          if (mounted) setState(() => _avatarBusy = false);
          return;
        }

        final Uint8List bytes = await picked.readAsBytes();
        if (bytes.lengthInBytes > 10 * 1024 * 1024) {
          messenger.showSnackBar(
            const SnackBar(content: Text('La photo dépasse 10 Mo.')),
          );
          if (mounted) setState(() => _avatarBusy = false);
          return;
        }

        final String extension = picked.name.split('.').last.toLowerCase();
        await ref
            .read(profileRepositoryProvider)
            .updateAvatar(bytes: bytes, extension: extension);
      }

      if (mounted) ref.invalidate(brandProfileProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Photo de profil mise à jour.')),
      );
    } catch (error, stack) {
      log.error('Photo de profil impossible', error, stack);
      messenger.showSnackBar(
        const SnackBar(content: Text('Modification de la photo impossible.')),
      );
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
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
    final List<PostItem>? allPosts = postsAsync.value;
    if (allPosts != null) _syncLikedIds(allPosts);

    return DefaultTabController(
      length: PostKind.values.length,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        extendBody: true,
        bottomNavigationBar: const FloatingNav(currentIndex: 0),
        appBar: AppBar(
          title: Text(brand?.username ?? 'Profil'),
          leading: isAdmin
              ? null
              : IconButton(
                  tooltip: 'Connexion administrateur',
                  onPressed: () => context.push('/login'),
                  icon: const Icon(Icons.more_vert),
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
        body: SerenityBackground(
          child: Center(
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
                          isAdmin: isAdmin,
                          avatarBusy: _avatarBusy,
                          onAvatarTap: (_avatarBusy || !isAdmin)
                              ? null
                              : () => _showAvatarActionsSheet(brand),
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
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 24),
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
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 24),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
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

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({
    required this.brand,
    required this.stats,
    required this.statsHasError,
    required this.statsLoading,
    required this.isAdmin,
    required this.avatarBusy,
    this.onAvatarTap,
  });

  final BrandProfile? brand;
  final List<SocialStat>? stats;
  final bool statsHasError;
  final bool statsLoading;
  final bool isAdmin;
  final bool avatarBusy;
  final VoidCallback? onAvatarTap;

  SocialStat? _statFor(StatPlatform platform) {
    for (final SocialStat stat in stats ?? const <SocialStat>[]) {
      if (stat.platform == platform) return stat;
    }
    return null;
  }

  void _showDetails(
    BuildContext parentContext,
    WidgetRef ref,
    StatPlatform platform,
    SocialStat? stat,
  ) {
    showModalBottomSheet<void>(
      context: parentContext,
      backgroundColor: Colors.white,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8,
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
                          color: kNavy,
                        ),
                      ),
                    ],
                  ),
                  if (platform == StatPlatform.youtube ||
                      platform == StatPlatform.facebook ||
                      platform == StatPlatform.instagram) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      switch (platform) {
                        StatPlatform.youtube => '@dxnmoroccoofficial',
                        StatPlatform.facebook => 'daxenmoroccoOfficial',
                        StatPlatform.instagram => 'daxenmorocco.llc',
                        StatPlatform.tiktok => '',
                      },
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    stat == null ? '—' : compactCount(stat.followersCount),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: kNavy,
                    ),
                  ),
                  const Text(
                    'followers',
                    style: TextStyle(color: Colors.black45, fontSize: 13),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Dernière synchronisation : '
                    '${stat?.lastSuccessAt == null ? 'jamais' : formatDateTime(stat!.lastSuccessAt!)}'
                    '${stat?.isManual ?? false ? ' · saisie manuelle' : ''}',
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
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
                  if (isAdmin && platform == StatPlatform.facebook) ...<Widget>[
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _editFollowersManually(
                          parentContext,
                          ref,
                          platform,
                          stat,
                        );
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text(
                        'Modifier les followers manuellement',
                      ),
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
                    if (platform == StatPlatform.youtube ||
                        platform == StatPlatform.facebook ||
                        platform == StatPlatform.instagram) ...<Widget>[
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: () async {
                          await Clipboard.setData(
                            ClipboardData(text: platform.officialUrl!),
                          );
                          if (!sheetContext.mounted) return;
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            SnackBar(
                              content: Text('Lien ${platform.label} copié.'),
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
                                    color: Colors.black54,
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Boîte de saisie du nombre de followers (admin, Facebook).
  Future<void> _editFollowersManually(
    BuildContext context,
    WidgetRef ref,
    StatPlatform platform,
    SocialStat? stat,
  ) async {
    final TextEditingController controller = TextEditingController(
      text: stat?.followersCount.toString() ?? '',
    );
    final int? value = await showDialog<int>(
      context: context,
      builder: (BuildContext dialogContext) {
        final GlobalKey<FormState> formKey = GlobalKey<FormState>();
        return AlertDialog(
          title: Text('Followers ${platform.label} (manuel)'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nombre de followers',
                hintText: 'Ex. 5200',
              ),
              validator: (String? input) {
                final String normalized = input?.trim() ?? '';
                if (normalized.isEmpty) {
                  return 'Entrez un nombre.';
                }
                if (int.tryParse(normalized) == null) {
                  return 'Nombre invalide.';
                }
                return null;
              },
              onFieldSubmitted: (_) {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(
                    dialogContext,
                    int.parse(controller.text.trim()),
                  );
                }
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(
                    dialogContext,
                    int.parse(controller.text.trim()),
                  );
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );

    if (value == null || !context.mounted) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(profileRepositoryProvider).setFollowers(platform, value);
      ref.invalidate(socialStatsProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Followers ${platform.label} mis à jour ($value).'),
        ),
      );
    } catch (error, stack) {
      log.error('Mise à jour manuelle des followers impossible', error, stack);
      messenger.showSnackBar(
        const SnackBar(content: Text('Mise à jour manuelle impossible.')),
      );
    }
  }

  void _showNetworks(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final StatPlatform platform in StatPlatform.values)
                if (platform.officialUrl != null)
                  ListTile(
                    leading: Icon(platform.icon, color: kDeepTeal),
                    title: Text(platform.label),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () async {
                      final Uri uri = Uri.parse(platform.officialUrl!);
                      if (context.mounted) Navigator.pop(context);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                  ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Widget statsRow = Row(
      children: <Widget>[
        for (int i = 0; i < StatPlatform.values.length; i++) ...<Widget>[
          if (i > 0) Container(width: 1, height: 30, color: Colors.black12),
          Expanded(
            child: _StatColumn(
              platform: StatPlatform.values[i],
              stat: _statFor(StatPlatform.values[i]),
              loading: statsLoading,
              hasError: statsHasError,
              onTap: () => _showDetails(
                context,
                ref,
                StatPlatform.values[i],
                _statFor(StatPlatform.values[i]),
              ),
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top +
            8, // Au lieu de kToolbarHeight - 28 (~28px de moins)
        16,
        10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          // 1. Avatar centré
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              BrandAvatar(url: brand?.avatarUrl, size: 112),
              if (avatarBusy)
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black38,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              if (isAdmin)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onAvatarTap,
                      child: const SizedBox(
                        width: 32,
                        height: 32,
                        child: Center(
                          child: Icon(Icons.add, size: 20, color: kNavy),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // L'équilibre avatar/nom/compteurs est vérifié par le test
          // « equilibre les distances autour du nom du profil » (≈41 px
          // de part et d'autre du bloc du nom, titre inclus).
          const SizedBox(height: 3),

          // 3. Afficher le username uniquement s'il est renseigné et non vide
          if (brand?.username != null &&
              brand!.username.trim().isNotEmpty) ...<Widget>[
            Text(
              brand!.username,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: kNavy,
              ),
            ),
            const SizedBox(height: 4),
          ],

          // 4. Titre affiché ("Daxen Morocco")
          if (brand != null &&
              (brand!.displayName.trim().isNotEmpty &&
                  brand!.displayName != brand!.username)) ...<Widget>[
            Text(
              brand!.displayName,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 14),
            ),
          ],

          if (statsHasError && stats == null) ...<Widget>[
            const SizedBox(height: 6),
            const Text(
              'Statistiques indisponibles',
              style: TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ],
          if (brand?.bio?.trim().isNotEmpty ?? false) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              brand!.bio!.trim(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Colors.black87,
              ),
            ),
          ],
          const SizedBox(height: 6),
          statsRow,
          const SizedBox(height: 14),
          // Bouton pilule centré (« Edit Profile » du template).
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFB7D9D4)),
              foregroundColor: kNavy,
              fixedSize: const Size(200, 42),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: kNavy,
              ),
              shape: const StadiumBorder(),
            ),
            onPressed: () {
              if (isAdmin) {
                context.push('/admin/new');
              } else {
                _showNetworks(context);
              }
            },
            child: Text(isAdmin ? 'Publier un contenu' : 'Suivre DAXEN'),
          ),
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
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: kNavy,
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
                  style: const TextStyle(color: Colors.black54, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Barre "J'aime" style Instagram (cœur uniquement), persisté en base.
class _ReactionBar extends ConsumerStatefulWidget {
  const _ReactionBar({
    required this.postId,
    required this.likesCount,
    this.compact = false,
  });

  final String postId;
  final int likesCount;
  final bool compact;

  @override
  ConsumerState<_ReactionBar> createState() => _ReactionBarState();
}

class _ReactionBarState extends ConsumerState<_ReactionBar> {
  int? _countOverride;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Future<void>(() => ensureLikesChecked(ref, <String>[widget.postId]));
  }

  @override
  void didUpdateWidget(covariant _ReactionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_countOverride != null && widget.likesCount == _countOverride) {
      _countOverride = null;
    }
  }

  Future<void> _toggle() async {
    if (_busy) return;
    _busy = true;

    final Set<String> current = ref.read(likedPostIdsProvider);
    final bool wasLiked = current.contains(widget.postId);
    final Set<String> optimistic = <String>{...current};
    if (wasLiked) {
      optimistic.remove(widget.postId);
    } else {
      optimistic.add(widget.postId);
    }
    ref.read(likedPostIdsProvider.notifier).state = optimistic;
    setState(() {
      final int base = _countOverride ?? widget.likesCount;
      _countOverride = wasLiked ? (base - 1) : (base + 1);
      if (_countOverride! < 0) _countOverride = 0;
    });

    try {
      final LikeToggleResult result = await ref
          .read(likesRepositoryProvider)
          .toggleLike(widget.postId);
      if (!mounted) return;
      final Set<String> next = <String>{...ref.read(likedPostIdsProvider)};
      if (result.liked) {
        next.add(widget.postId);
      } else {
        next.remove(widget.postId);
      }
      ref.read(likedPostIdsProvider.notifier).state = next;
      setState(() => _countOverride = result.likesCount);
    } catch (_) {
      if (!mounted) return;
      ref.read(likedPostIdsProvider.notifier).state = current;
      setState(() => _countOverride = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'enregistrer le J\'aime.')),
      );
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color likedColor = Color(0xFFED4956);
    final bool liked = ref.watch(likedPostIdsProvider).contains(widget.postId);
    final int count = _countOverride ?? widget.likesCount;
    final IconData icon = liked ? Icons.favorite : Icons.favorite_border;

    if (!widget.compact) {
      final Color iconColor = liked ? likedColor : kNavy;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            onPressed: _toggle,
            icon: Icon(icon, color: iconColor),
            iconSize: 26,
            tooltip: 'J\'aime',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          if (count > 0) ...<Widget>[
            const SizedBox(width: 6),
            Text(
              '$count J\'aime${count > 1 ? 's' : ''}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: kNavy,
                fontSize: 14,
              ),
            ),
          ],
        ],
      );
    }

    final Color iconColor = liked ? likedColor : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
      ),
      child: InkWell(
        onTap: _toggle,
        borderRadius: BorderRadius.circular(999),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: iconColor),
            if (count > 0) ...<Widget>[
              const SizedBox(width: 3),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFB7D9D4)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openDrive(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: kWarmMist,
                  child: Icon(Icons.folder_outlined, color: kDeepTeal),
                ),
                title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: const Text(
                  'Google Drive',
                  style: TextStyle(color: Colors.black45),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (isAdmin)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: kNavy),
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
                child: _ReactionBar(
                  postId: post.id,
                  likesCount: post.likesCount,
                ),
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
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          const Text('Regarder ce Reel'),
          IconButton(
            onPressed: () => Navigator.pop(dialogContext),
            icon: const Icon(Icons.close, color: Colors.red),
            tooltip: 'Fermer',
          ),
        ],
      ),
      content: const Text('Choisissez la plateforme à ouvrir.'),
      actions: <Widget>[
        if (post.facebookLink?.trim().isNotEmpty ?? false)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FilledButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await openLink(post.facebookLink!.trim());
              },
              icon: const Icon(Icons.facebook),
              label: const Text('Voir sur Facebook'),
            ),
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
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: kWarmMist,
          ),
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
                        const ColoredBox(color: kWarmMist),
                    errorWidget:
                        (BuildContext context, String url, Object error) =>
                            const ColoredBox(
                              color: kWarmMist,
                              child: Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.black26,
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
                  top: 6,
                  right: 6,
                  child: PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      color: Colors.white,
                      shadows: <Shadow>[Shadow(blurRadius: 6)],
                    ),
                    onSelected: (String value) async {
                      if (value == 'edit') {
                        context.push('/admin/edit/${post.id}', extra: post);
                      } else if (value == 'delete') {
                        final bool? confirmed = await showDialog<bool>(
                          context: context,
                          builder: (BuildContext context) => AlertDialog(
                            title: const Text('Supprimer le poster ?'),
                            content: const Text(
                              'Cette action est irréversible.',
                            ),
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
                    color: kNavy,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    post.platform.icon,
                    size: 13,
                    color: Colors.white,
                  ),
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
                    child: _ReactionBar(
                      compact: true,
                      postId: post.id,
                      likesCount: post.likesCount,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
