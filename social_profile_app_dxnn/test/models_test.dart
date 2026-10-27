import 'package:flutter_test/flutter_test.dart';
import 'package:social_profile_app_dxn/features/notifications/notifications_repository.dart';
import 'package:social_profile_app_dxn/features/posts/posts_repository.dart';
import 'package:social_profile_app_dxn/features/profile/profile_repository.dart';

void main() {
  test('BrandProfile accepte un display_name manquant', () {
    final BrandProfile profile = BrandProfile.fromMap(<String, dynamic>{
      'username': 'DXN',
      'display_name': '',
      'bio': 'Bio',
      'avatar_url': null,
    });

    expect(profile.username, 'DXN');
    expect(profile.displayName, 'DXN');
    expect(profile.bio, 'Bio');
    expect(profile.avatarUrl, isNull);
  });

  test('SocialStat parse le compteur et les dates', () {
    final SocialStat stat = SocialStat.fromMap(<String, dynamic>{
      'platform': 'youtube',
      'followers_count': 1200000,
      'last_success_at': '2026-10-26T10:00:00+00:00',
      'last_attempt_at': '2026-10-26T10:05:00+00:00',
      'last_error': null,
    });

    expect(stat.platform, StatPlatform.youtube);
    expect(stat.followersCount, 1200000);
    expect(stat.lastSuccessAt, DateTime.utc(2026, 10, 26, 10));
    expect(stat.lastError, isNull);
    expect(stat.toMap()['platform'], 'youtube');
  });

  test('PostItem parse la plateforme, le type et la date', () {
    final PostItem post = PostItem.fromMap(<String, dynamic>{
      'id': '11111111-1111-4111-8111-111111111111',
      'platform': 'whatsapp',
      'kind': 'reel',
      'caption': 'Nouveau poster',
      'media_path': 'posters/abc.jpg',
      'created_at': '2026-10-26T10:00:00+00:00',
    });

    expect(post.platform, PostPlatform.whatsapp);
    expect(post.kind, PostKind.reel);
    expect(post.caption, 'Nouveau poster');
    expect(post.createdAt, DateTime.utc(2026, 10, 26, 10));
  });

  test('AppNotification parse ses champs', () {
    final AppNotification notification = AppNotification.fromMap(
      <String, dynamic>{
        'id': '22222222-2222-4222-8222-222222222222',
        'post_id': '11111111-1111-4111-8111-111111111111',
        'title': 'Nouveau poster',
        'body': 'Instagram',
        'created_at': '2026-10-26T10:00:00+00:00',
      },
    );

    expect(notification.title, 'Nouveau poster');
    expect(notification.body, 'Instagram');
    expect(notification.createdAt, DateTime.utc(2026, 10, 26, 10));
  });

  test('countUnread respecte la dernière consultation', () {
    final List<AppNotification> notifications = <AppNotification>[
      AppNotification(
        id: '3',
        postId: 'p3',
        title: 'Nouveau',
        createdAt: DateTime.utc(2026, 10, 26, 12),
      ),
      AppNotification(
        id: '2',
        postId: 'p2',
        title: 'Ancien',
        createdAt: DateTime.utc(2026, 10, 26, 10),
      ),
      AppNotification(
        id: '1',
        postId: 'p1',
        title: 'Très ancien',
        createdAt: DateTime.utc(2026, 10, 26, 8),
      ),
    ];

    expect(countUnread(notifications, null), 3);
    expect(countUnread(notifications, DateTime.utc(2026, 10, 26, 9)), 2);
    expect(countUnread(notifications, DateTime.utc(2026, 10, 26, 12)), 0);
  });
}
