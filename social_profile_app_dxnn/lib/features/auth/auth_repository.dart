import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/logger.dart';
import '../../core/supabase.dart';

enum SignInFailure { invalidCredentials, notAdmin, network, unknown }

class SignInException implements Exception {
  const SignInException(this.failure, this.message);

  final SignInFailure failure;
  final String message;

  @override
  String toString() => message;
}

class AuthRepository {
  Future<void> signIn({required String email, required String password}) async {
    try {
      final AuthResponse response = await supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final User? user = response.user;
      if (user == null) {
        throw const SignInException(
          SignInFailure.unknown,
          'Connexion impossible. Réessayez.',
        );
      }

      final Map<String, dynamic>? profile = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      if (profile?['role'] != 'admin') {
        await supabase.auth.signOut();
        throw const SignInException(
          SignInFailure.notAdmin,
          'Ce compte ne dispose pas des droits administrateur.',
        );
      }

      log.info('Connexion administrateur réussie', <String, String>{
        'user_id': user.id,
      });
    } on SignInException {
      rethrow;
    } on AuthException catch (error) {
      log.warn('Échec de connexion Supabase', error);
      throw const SignInException(
        SignInFailure.invalidCredentials,
        'Email ou mot de passe incorrect.',
      );
    } on PostgrestException catch (error, stack) {
      await supabase.auth.signOut();
      log.error('Vérification du rôle administrateur impossible', error, stack);
      throw const SignInException(
        SignInFailure.unknown,
        'Impossible de vérifier les droits du compte.',
      );
    } catch (error, stack) {
      log.error('Erreur inattendue à la connexion', error, stack);
      throw const SignInException(
        SignInFailure.network,
        'Connexion impossible. Vérifiez votre réseau.',
      );
    }
  }

  Future<void> signOut() async {
    try {
      await supabase.auth.signOut();
      log.info('Déconnexion administrateur');
    } catch (error, stack) {
      log.error('Échec de déconnexion', error, stack);
      rethrow;
    }
  }
}

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((Ref ref) => AuthRepository());

final StreamProvider<Session?> authStateProvider = StreamProvider<Session?>((
  Ref ref,
) async* {
  final auth = supabase.auth;
  yield auth.currentSession;
  await for (final AuthState state in auth.onAuthStateChange) {
    yield state.session;
  }
});

final FutureProvider<bool> isAdminProvider = FutureProvider<bool>((
  Ref ref,
) async {
  final Session? session = await ref.watch(authStateProvider.future);
  if (session == null) return false;

  try {
    final Map<String, dynamic>? profile = await supabase
        .from('profiles')
        .select('role')
        .eq('id', session.user.id)
        .maybeSingle();
    return profile?['role'] == 'admin';
  } catch (error, stack) {
    log.error('Lecture du rôle impossible', error, stack);
    return false;
  }
});
