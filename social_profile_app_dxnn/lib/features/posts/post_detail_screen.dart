import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/ui.dart';
import '../posts/posts_repository.dart';

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
              errorWidget:
                  (BuildContext context, String url, Object error) =>
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
                    avatar: Icon(post.platform.icon, size: 16),
                    label: Text(post.platform.label),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(post.kind.label),
                    visualDensity: VisualDensity.compact,
                  ),
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
