import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Identifiant anonyme persistant par appareil, utilisé pour les « J'aime ».
class DeviceId {
  static const String _key = 'device_id_v1';
  static String? _cached;

  static Future<String> get() async {
    final String? cached = _cached;
    if (cached != null && cached.isNotEmpty) return cached;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(_key);
    if (id == null || id.trim().length < 8) {
      id = _generate();
      await prefs.setString(_key, id);
    }
    _cached = id;
    return id;
  }

  static String _generate() {
    final Random random = Random.secure();
    final String time = DateTime.now()
        .toUtc()
        .microsecondsSinceEpoch
        .toRadixString(16);
    final String rand = List<String>.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return 'd_${time}_$rand';
  }
}
