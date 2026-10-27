import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logger.dart';
import '../../core/supabase.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.postId,
    required this.title,
    required this.createdAt,
    this.body,
  });

  final String id;
  final String postId;
  final String title;
  final String? body;
  final DateTime createdAt;

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as String,
      postId: map['post_id'] as String,
      title: map['title'] as String,
      body: map['body'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String).toUtc(),
    );
  }
}

const String _lastSeenKey = 'notifications_last_seen_v1';

class NotificationsRepository {
  Stream<List<AppNotification>> watchNotifications() async* {
    try {
      await for (final List<Map<String, dynamic>> rows
          in supabase
              .from('notifications')
              .stream(primaryKey: <String>['id'])
              .order('created_at', ascending: false)
              .limit(100)) {
        yield rows.map(AppNotification.fromMap).toList(growable: false);
      }
    } catch (error, stack) {
      log.error('Flux Realtime des notifications interrompu', error, stack);
      rethrow;
    }
  }

  Future<DateTime?> readLastSeen() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_lastSeenKey);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  Future<void> markSeen(DateTime value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSeenKey, value.toUtc().toIso8601String());
  }
}

int countUnread(Iterable<AppNotification> items, DateTime? lastSeen) {
  if (lastSeen == null) return items.length;
  return items
      .where((AppNotification item) => item.createdAt.isAfter(lastSeen))
      .length;
}

final Provider<NotificationsRepository> notificationsRepositoryProvider =
    Provider<NotificationsRepository>((Ref ref) => NotificationsRepository());

final StreamProvider<List<AppNotification>> notificationsProvider =
    StreamProvider<List<AppNotification>>(
      (Ref ref) => ref.watch(notificationsRepositoryProvider).watchNotifications(),
    );

final FutureProvider<DateTime?> lastSeenProvider = FutureProvider<DateTime?>(
  (Ref ref) => ref.watch(notificationsRepositoryProvider).readLastSeen(),
);

final Provider<int> unreadCountProvider = Provider<int>((Ref ref) {
  final AsyncValue<DateTime?> lastSeenAsync = ref.watch(lastSeenProvider);
  final List<AppNotification> items =
      ref.watch(notificationsProvider).value ?? const <AppNotification>[];

  if (items.isEmpty) return 0;
  if (lastSeenAsync.isLoading && !lastSeenAsync.hasValue) return 0;
  return countUnread(items, lastSeenAsync.value);
});
