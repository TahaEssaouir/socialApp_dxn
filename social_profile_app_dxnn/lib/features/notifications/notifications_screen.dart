import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/floating_nav.dart';
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
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      extendBody: true,
      bottomNavigationBar: const FloatingNav(currentIndex: 1),
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          tooltip: 'Retour',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: SerenityBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: _buildBody(context, async, items),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
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
      padding: EdgeInsets.fromLTRB(
        0,
        MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
        0,
        80, // Espace suffisant en bas pour ne pas être masqué par la FloatingNav
      ),
      itemCount: items.length,
      separatorBuilder: (BuildContext context, int index) =>
          const Divider(height: 1),
      itemBuilder: (BuildContext context, int index) {
        final AppNotification item = items[index];
        return ListTile(
          leading: const CircleAvatar(
            backgroundColor: kWarmMist,
            child: Icon(Icons.notifications_none, size: 20, color: kDeepTeal),
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
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
          trailing: Text(
            timeAgo(item.createdAt),
            style: const TextStyle(color: Colors.black38, fontSize: 11),
          ),
          onTap: () => context.push('/post/${item.postId}'),
        );
      },
    );
  }
}