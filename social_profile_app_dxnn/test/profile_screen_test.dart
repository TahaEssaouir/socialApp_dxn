import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:social_profile_app_dxn/app.dart";
import "package:social_profile_app_dxn/features/auth/auth_repository.dart";
import "package:social_profile_app_dxn/features/notifications/notifications_repository.dart";
import "package:social_profile_app_dxn/features/posts/posts_repository.dart";
import "package:social_profile_app_dxn/features/profile/profile_repository.dart";
import "package:social_profile_app_dxn/features/profile/profile_screen.dart";

void main() {
  final BrandProfile brand = BrandProfile(
    username: "nxt_taha",
    displayName: "Nxt Taha",
    bio: "Bio de test",
  );

  final List<SocialStat> stats = <SocialStat>[
    const SocialStat(platform: StatPlatform.facebook, followersCount: 12400),
    const SocialStat(platform: StatPlatform.youtube, followersCount: 1200000),
    const SocialStat(platform: StatPlatform.tiktok, followersCount: 10000),
    const SocialStat(platform: StatPlatform.instagram, followersCount: 8500),
  ];

  Future<void> pumpProfile(
    WidgetTester tester, {
    required bool isAdmin,
    List<PostItem> posts = const <PostItem>[],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          brandProfileProvider.overrideWith((Ref ref) async => brand),
          socialStatsProvider.overrideWith(
            (Ref ref) => Stream<List<SocialStat>>.value(stats),
          ),
          postsProvider.overrideWith(
            (Ref ref) => Stream<List<PostItem>>.value(posts),
          ),
          notificationsProvider.overrideWith(
            (Ref ref) =>
                Stream<List<AppNotification>>.value(const <AppNotification>[]),
          ),
          lastSeenProvider.overrideWith((Ref ref) async => null),
          isAdminProvider.overrideWith((Ref ref) async => isAdmin),
        ],
        child: MaterialApp(theme: buildAppTheme(), home: const ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("affiche le profil public, les compteurs et les onglets", (
    WidgetTester tester,
  ) async {
    await pumpProfile(tester, isAdmin: false);

    expect(find.text("nxt_taha"), findsWidgets);
    expect(find.text("12,4 k"), findsOneWidget);
    expect(find.text("1,2 M"), findsOneWidget);
    expect(find.text("10 k"), findsOneWidget);
    expect(find.text("8,5 k"), findsOneWidget);
    expect(find.text("Publications"), findsOneWidget);
    expect(find.text("Reels"), findsOneWidget);
    expect(find.text("Aucun post pour le moment."), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byIcon(Icons.add_box_outlined), findsNothing);
  });

  testWidgets("bascule vers l’onglet Reels", (WidgetTester tester) async {
    await pumpProfile(tester, isAdmin: false);

    await tester.tap(find.text("Reels"));
    await tester.pumpAndSettle();

    expect(find.text("Aucun reel pour le moment."), findsOneWidget);
  });

  testWidgets("affiche l’action admin pour un administrateur", (
    WidgetTester tester,
  ) async {
    await pumpProfile(tester, isAdmin: true);

    expect(find.byIcon(Icons.add_box_outlined), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
  });

  testWidgets(
    "affiche les actions de modification et suppression pour un admin",
    (WidgetTester tester) async {
      await pumpProfile(
        tester,
        isAdmin: true,
        posts: <PostItem>[
          PostItem(
            id: "11111111-1111-4111-8111-111111111111",
            platform: PostPlatform.instagram,
            kind: PostKind.post,
            mediaPath: "https://example.com/poster.jpg",
            createdAt: DateTime.utc(2026, 10, 26),
          ),
        ],
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text("Modifier"), findsOneWidget);
      expect(find.text("Supprimer"), findsOneWidget);
    },
  );
}
