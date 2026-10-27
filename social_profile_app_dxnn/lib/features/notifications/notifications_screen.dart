import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/logger.dart';
import '../../core/ui.dart';
import 'notifications_repository.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  DateTime? _lastMarked;

  Future<void> _markSeen(DateTime newest) async {
    if (_lastMarked != null && !newest.isAfter(_lastMarked!)) return;
    _lastMarked = newest;

    try {
      await ref.read(notificationsRepositoryProvider).markSeen(newest);
      ref.invalidate(lastSeenProvider);
    } catch (error) {
      log.warn('Mise à jour de la dernière consultation impossible', error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<AppNotification>> async = ref.watch(
      notificationsProvider,
    );

    ref.listen<AsyncValue<List<AppNotification>>>(notificationsProvider, (
      AsyncValue<List<AppNotification>>? previous,
      AsyncValue<List<AppNotification>> next,
    ) {
      final List<AppNotification>? items = next.value;
      if (items != null && items.isNotEmpty) {
        _markSeen(items.first.createdAt);
      }
    });

    final List<AppNotification>? items = async.value;
    if (items != null && items.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _markSeen(items.first.createdAt);
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: _buildBody(async, items),
        ),
      ),
    );
  }

  Widget _buildBody(
    AsyncValue<List<AppNotification>> async,
    List<AppNotification>? items,
  ) {
    if (items == null) {
      if (async.hasError) {
        return ErrorPane(
          message: 'Impossible de charger les notifications.',
          onRetry: () => ref.invalidate(notificationsProvider),
        );
      }
      return const LoadingPane(label: 'Chargement des notifications…');
    }

    if (items.isEmpty) {
      return const EmptyPane(
        icon: Icons.notifications_none,
        message: 'Aucune notification pour le moment.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      separatorBuilder: (BuildContext context, int index) =>
          const Divider(height: 1),
      itemBuilder: (BuildContext context, int index) {
        final AppNotification item = items[index];
        return ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFF1A1A1A),
            child: Icon(Icons.notifications_none, size: 20),
          ),
          title: Text(
            item.title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: item.body == null || item.body!.trim().isEmpty
              ? null
              : Text(
                  item.body!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
          trailing: Text(
            timeAgo(item.createdAt),
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          onTap: () => context.push('/post/${item.postId}'),
        );
      },
    );
  }
}
