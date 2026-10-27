import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';

Future<void> initializeSupabase() async {
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
    debug: false,
  );
}

SupabaseClient get supabase => Supabase.instance.client;
