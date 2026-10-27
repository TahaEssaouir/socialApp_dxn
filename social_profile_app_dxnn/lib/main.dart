import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/env.dart';
import 'core/logger.dart';
import 'core/supabase.dart';
import 'core/url_strategy.dart'
    if (dart.library.js_interop) 'core/url_strategy_web.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureUrlStrategy();

  if (!Env.isConfigured) {
    log.warn('Configuration Supabase absente');
    runApp(
      const StartupErrorApp(
        message:
            'Configuration Supabase manquante.\n\n'
            'Créez un fichier .env à partir de .env.example, puis lancez '
            'l’application avec --dart-define-from-file=.env.',
      ),
    );
    return;
  }

  try {
    await initializeSupabase();
    log.info('Application démarrée');
    runApp(const ProviderScope(child: SocialApp()));
  } catch (error, stack) {
    log.error('Initialisation Supabase impossible', error, stack);
    runApp(
      const StartupErrorApp(
        message:
            'Impossible de joindre Supabase.\n\n'
            'Vérifiez la connexion réseau et les valeurs SUPABASE_URL / '
            'SUPABASE_ANON_KEY.',
      ),
    );
  }
}
