import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/supabase.dart';
import 'features/admin/admin_guard.dart';
import 'features/admin/admin_post_form.dart';
import 'features/auth/login_screen.dart';
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
        seedColor: const Color(0xFF0095F6),
        brightness: Brightness.dark,
      ).copyWith(
        surface: Colors.black,
        surfaceContainerHighest: const Color(0xFF1A1A1A),
        outline: const Color(0xFF262626),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.black,
    visualDensity: VisualDensity.standard,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    tabBarTheme: const TabBarThemeData(
      indicatorColor: Colors.white,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white54,
      dividerColor: Color(0xFF262626),
      indicatorSize: TabBarIndicatorSize.tab,
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF262626),
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF121212),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF262626)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF262626)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF0095F6)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(46),
        side: const BorderSide(color: Color(0xFF363636)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Color(0xFF262626),
      contentTextStyle: TextStyle(color: Colors.white),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF1A1A1A),
      surfaceTintColor: Colors.transparent,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Color(0xFF0095F6),
    ),
  );
}

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page introuvable')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.explore_off_outlined,
                size: 48,
                color: Colors.white38,
              ),
              const SizedBox(height: 14),
              const Text(
                'Cette page n’existe pas.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
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
        body: SafeArea(
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
                      color: Colors.white38,
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
                        color: Colors.white70,
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
    );
  }
}
