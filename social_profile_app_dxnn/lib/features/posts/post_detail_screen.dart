import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/ui.dart';
import '../posts/posts_repository.dart';

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
  const _ReactionBar({super.key});

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _reactionOptions
            .map((_ReactionOption option) {
              final bool selected = _selected.contains(option.emoji);
              final int count = _counts[option.emoji] ?? 0;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _toggle(option.emoji),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
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
                      Text(option.emoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 4),
                      Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
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
      appBar: AppBar(title: Text(post?.platform.label ?? 'Poster')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: _buildBody(context, ref, async, items, post),
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
      children: <Widget>[
        AspectRatio(
          aspectRatio: 1,
          child: Hero(
            tag: 'post-${post.id}',
            child: CachedNetworkImage(
              imageUrl: posterPublicUrl(post.mediaPath),
              fit: BoxFit.cover,
              placeholder: (BuildContext context, String url) =>
                  const ColoredBox(color: Color(0xFF121212)),
              errorWidget: (BuildContext context, String url, Object error) =>
                  const ColoredBox(
                    color: Color(0xFF121212),
                    child: Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white38,
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
              const _ReactionBar(),
              const SizedBox(height: 16),
              Text(
                'Publié le ${formatDateTime(post.createdAt)}',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
