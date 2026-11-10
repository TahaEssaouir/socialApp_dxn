import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/ui.dart';
import 'likes_repository.dart';
import 'posts_repository.dart';

/// "J'aime" style Instagram (cœur uniquement), persisté en base.
class _ReactionBar extends ConsumerStatefulWidget {
  const _ReactionBar({required this.postId, required this.likesCount});

  final String postId;
  final int likesCount;

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
    ref.read(likedPostIdsProvider.notifier).replace(optimistic);
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
      ref.read(likedPostIdsProvider.notifier).replace(next);
      setState(() => _countOverride = result.likesCount);
    } catch (_) {
      if (!mounted) return;
      ref.read(likedPostIdsProvider.notifier).replace(current);
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
    final Color iconColor = liked ? likedColor : kNavy;

    return Row(
      children: <Widget>[
        IconButton(
          onPressed: _toggle,
          icon: Icon(icon, color: iconColor),
          iconSize: 28,
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
}

class PostDetailScreen extends ConsumerWidget {
  const PostDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<PostItem>> async = ref.watch(postsProvider);
    final List<PostItem>? items = async.value;

    PostItem? post;
    if (items != null) {
      for (final PostItem item in items) {
        if (item.id == postId) {
          post = item;
          break;
        }
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(post?.platform.label ?? 'Poster')),
      body: SerenityBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: _buildBody(context, ref, async, items, post),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<PostItem>> async,
    List<PostItem>? items,
    PostItem? post,
  ) {
    if (items == null) {
      if (async.hasError) {
        return ErrorPane(
          message: 'Impossible de charger ce poster.',
          onRetry: () => ref.invalidate(postsProvider),
        );
      }
      return const LoadingPane(label: 'Chargement du poster…');
    }

    if (post == null) {
      return const EmptyPane(
        icon: Icons.image_not_supported_outlined,
        message: 'Ce poster n’existe plus.',
      );
    }

    return ListView(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + kToolbarHeight,
      ),
      children: <Widget>[
        AspectRatio(
          aspectRatio: 1,
          child: Hero(
            tag: 'post-${post.id}',
            child: CachedNetworkImage(
              imageUrl: posterPublicUrl(post.mediaPath),
              fit: BoxFit.cover,
              placeholder: (BuildContext context, String url) =>
                  const ColoredBox(color: kWarmMist),
              errorWidget: (BuildContext context, String url, Object error) =>
                  const ColoredBox(
                    color: kWarmMist,
                    child: Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Colors.black26,
                        size: 44,
                      ),
                    ),
                  ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Chip(
                    label: Text(post.kind.label),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (post.facebookLink != null &&
                      post.facebookLink!.trim().isNotEmpty) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () async {
                        final Uri? uri = Uri.tryParse(
                          post.facebookLink!.trim(),
                        );
                        if (uri != null && await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                      icon: const Icon(Icons.facebook, size: 16),
                      label: const Text('Voir sur Facebook'),
                    ),
                  ],
                  if (post.instagramLink != null &&
                      post.instagramLink!.trim().isNotEmpty) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () async {
                        final Uri? uri = Uri.tryParse(
                          post.instagramLink!.trim(),
                        );
                        if (uri != null && await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                      icon: const Icon(Icons.camera_alt_outlined, size: 16),
                      label: const Text('Voir sur Instagram'),
                    ),
                  ],
                ],
              ),
              if (post.caption != null && post.caption!.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  post.caption!.trim(),
                  style: const TextStyle(fontSize: 15, height: 1.4),
                ),
              ],
              const SizedBox(height: 16),
              _ReactionBar(postId: post.id, likesCount: post.likesCount),
              const SizedBox(height: 16),
              Text(
                'Publié le ${formatDateTime(post.createdAt)}',
                style: const TextStyle(color: Colors.black38, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
