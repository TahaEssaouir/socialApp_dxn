import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import '../auth/auth_repository.dart';

class AdminGuard extends ConsumerWidget {
  const AdminGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<bool> admin = ref.watch(isAdminProvider);

    if (admin.isLoading && !admin.hasValue) {
      return const Scaffold(
        body: LoadingPane(label: 'Vérification des droits…'),
      );
    }

    if (admin.hasError || admin.value != true) {
      return const ForbiddenScreen();
    }

    return child;
  }
}

class ForbiddenScreen extends StatelessWidget {
  const ForbiddenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accès refusé')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.lock_outline, size: 48, color: Colors.white38),
                const SizedBox(height: 18),
                const Text(
                  'Accès administrateur requis',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Cette action est réservée au propriétaire du profil.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Se connecter'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
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
