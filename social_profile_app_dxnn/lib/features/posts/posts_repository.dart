import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logger.dart';
import '../../core/supabase.dart';

enum PostPlatform { whatsapp, facebook, instagram }

extension PostPlatformX on PostPlatform {
  String get label {
    switch (this) {
      case PostPlatform.whatsapp:
        return 'WhatsApp';
      case PostPlatform.facebook:
        return 'Facebook';
      case PostPlatform.instagram:
        return 'Instagram';
    }
  }

  IconData get icon {
    switch (this) {
      case PostPlatform.whatsapp:
        return Icons.chat;
      case PostPlatform.facebook:
        return Icons.facebook;
      case PostPlatform.instagram:
        return Icons.camera_alt_outlined;
    }
  }
}

enum PostKind { post, reel }

extension PostKindX on PostKind {
  String get label {
    switch (this) {
      case PostKind.post:
        return 'Post';
      case PostKind.reel:
        return 'Reel';
    }
  }

  String get sectionLabel {
    switch (this) {
      case PostKind.post:
        return 'Publications';
      case PostKind.reel:
        return 'Reels';
    }
  }
}

class PostItem {
  const PostItem({
    required this.id,
    required this.platform,
    required this.kind,
    required this.mediaPath,
    required this.createdAt,
    this.caption,
  });

  final String id;
  final PostPlatform platform;
  final PostKind kind;
  final String mediaPath;
  final DateTime createdAt;
  final String? caption;

  factory PostItem.fromMap(Map<String, dynamic> map) {
    return PostItem(
      id: map['id'] as String,
      platform: PostPlatform.values.byName(map['platform'] as String),
      kind: PostKind.values.byName(map['kind'] as String),
      mediaPath: map['media_path'] as String,
      createdAt: DateTime.parse(map['created_at'] as String).toUtc(),
      caption: map['caption'] as String?,
    );
  }
}

String posterPublicUrl(String path) {
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return path;
  }
  return supabase.storage.from('posters').getPublicUrl(path);
}

class PostsRepository {
  Stream<List<PostItem>> watchPosts() async* {
    try {
      await for (final List<Map<String, dynamic>> rows
          in supabase
              .from('posts')
              .stream(primaryKey: <String>['id'])
              .order('created_at', ascending: false)
              .limit(200)) {
        yield rows.map(PostItem.fromMap).toList(growable: false);
      }
    } catch (error, stack) {
      log.error('Flux Realtime des posters interrompu', error, stack);
      rethrow;
    }
  }
}

final Provider<PostsRepository> postsRepositoryProvider =
    Provider<PostsRepository>((Ref ref) => PostsRepository());

final StreamProvider<List<PostItem>> postsProvider =
    StreamProvider<List<PostItem>>(
      (Ref ref) => ref.watch(postsRepositoryProvider).watchPosts(),
    );
