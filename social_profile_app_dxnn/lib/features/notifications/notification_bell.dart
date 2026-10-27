import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'notifications_repository.dart';

class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int count = ref.watch(unreadCountProvider);
    final String tooltip = count > 0
        ? 'Notifications, $count non lue${count > 1 ? 's' : ''}'
        : 'Notifications';

    return IconButton(
      tooltip: tooltip,
      onPressed: () => context.push('/notifications'),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        child: const Icon(Icons.notifications_none),
      ),
    );
  }
}
