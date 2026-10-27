/// Configuration injectée au build via `--dart-define-from-file=.env`.
///
/// Aucune clé secrète (service role) ne doit figurer ici : seule la clé
/// publishable/anon est exposée au client Flutter.
abstract final class Env {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
