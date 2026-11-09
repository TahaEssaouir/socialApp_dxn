import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/supabase.dart';
import 'core/ui.dart';
import 'features/admin/admin_guard.dart';
import 'features/admin/admin_post_form.dart';
import 'features/auth/login_screen.dart';
import 'features/map/admin_center_form.dart';
import 'features/map/map_screen.dart';
import 'features/map/service_centers_repository.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/posts/post_detail_screen.dart';
import 'features/posts/posts_repository.dart';
import 'features/profile/profile_screen.dart';

final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) =>
            const ProfileScreen(),
      ),
      GoRoute(
        path: '/post/:id',
        builder: (BuildContext context, GoRouterState state) =>
            PostDetailScreen(postId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/notifications',
        builder: (BuildContext context, GoRouterState state) =>
            const NotificationsScreen(),
      ),
      GoRoute(
        path: '/map',
        builder: (BuildContext context, GoRouterState state) =>
            const MapScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) =>
            LoginScreen(redirectTo: state.uri.queryParameters['from']),
      ),
      GoRoute(
        path: '/admin/new',
        redirect: (BuildContext context, GoRouterState state) {
          if (supabase.auth.currentSession == null) {
            final String from = Uri.encodeComponent(state.uri.toString());
            return '/login?from=$from';
          }
          return null;
        },
        builder: (BuildContext context, GoRouterState state) =>
            const AdminGuard(child: AdminPostForm()),
      ),
      GoRoute(
        path: '/admin/center/new',
        redirect: (BuildContext context, GoRouterState state) {
          if (supabase.auth.currentSession == null) {
            final String from = Uri.encodeComponent(state.uri.toString());
            return '/login?from=$from';
          }
          return null;
        },
        builder: (BuildContext context, GoRouterState state) =>
            const AdminGuard(child: AdminCenterForm()),
      ),
      GoRoute(
        path: '/admin/center/edit',
        redirect: (BuildContext context, GoRouterState state) {
          if (supabase.auth.currentSession == null) {
            final String from = Uri.encodeComponent(state.uri.toString());
            return '/login?from=$from';
          }
          return null;
        },
        builder: (BuildContext context, GoRouterState state) => AdminGuard(
          child: AdminCenterForm(center: state.extra as ServiceCenter?),
        ),
      ),
      GoRoute(
        path: '/admin/edit/:id',
        redirect: (BuildContext context, GoRouterState state) {
          if (supabase.auth.currentSession == null) {
            final String from = Uri.encodeComponent(state.uri.toString());
            return '/login?from=$from';
          }
          return null;
        },
        builder: (BuildContext context, GoRouterState state) =>
            AdminGuard(child: AdminPostForm(post: state.extra as PostItem?)),
      ),
    ],
    errorBuilder: (BuildContext context, GoRouterState state) =>
        const NotFoundScreen(),
  );

  ref.onDispose(router.dispose);
  return router;
});

class SocialApp extends ConsumerWidget {
  const SocialApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'DXN',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}

ThemeData buildAppTheme() {
  final ColorScheme scheme =
      ColorScheme.fromSeed(
        seedColor: kDeepTeal,
        brightness: Brightness.light,
      ).copyWith(
        primary: kDeepTeal,
        onPrimary: Colors.white,
        secondary: kMintTeal,
        onSecondary: Colors.white,
        tertiary: kNavy,
        surface: Colors.white,
        surfaceContainerHighest: kWarmMist,
        outline: const Color(0xFFB7D9D4),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: kWarmMist,
    visualDensity: VisualDensity.standard,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: kNavy,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    tabBarTheme: const TabBarThemeData(
      indicatorColor: kDeepTeal,
      labelColor: kNavy,
      unselectedLabelColor: Colors.black54,
      dividerColor: Color(0xFFB7D9D4),
      indicatorSize: TabBarIndicatorSize.tab,
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFB7D9D4),
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFB7D9D4)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFB7D9D4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kDeepTeal, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kDeepTeal,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: kDeepTeal),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(46),
        foregroundColor: kDeepTeal,
        side: const BorderSide(color: kDeepTeal),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: kNavy,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: kDeepTeal),
  );
}

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Page introuvable')),
      body: SerenityBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.explore_off_outlined,
                  size: 48,
                  color: Colors.black26,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Cette page n’existe pas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Retour au profil'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Configuration requise',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: Scaffold(
        body: SerenityBackground(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.settings_ethernet,
                        size: 48,
                        color: Colors.black26,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Application non configurée',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
