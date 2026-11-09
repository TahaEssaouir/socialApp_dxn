import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/logger.dart';
import '../../core/supabase.dart';

enum StatPlatform { facebook, youtube, tiktok, instagram }

extension StatPlatformX on StatPlatform {
  String get label {
    switch (this) {
      case StatPlatform.facebook:
        return 'Facebook';
      case StatPlatform.youtube:
        return 'YouTube';
      case StatPlatform.tiktok:
        return 'TikTok';
      case StatPlatform.instagram:
        return 'Instagram';
    }
  }

  String? get officialUrl {
    switch (this) {
      case StatPlatform.facebook:
        return 'https://www.facebook.com/daxenmoroccoOfficial';
      case StatPlatform.youtube:
        return 'https://www.youtube.com/@dxnmoroccoofficial';
      case StatPlatform.tiktok:
        return null;
      case StatPlatform.instagram:
        return 'https://www.instagram.com/daxenmorocco.llc/';
    }
  }

  IconData get icon {
    switch (this) {
      case StatPlatform.facebook:
        return Icons.facebook;
      case StatPlatform.youtube:
        return Icons.smart_display;
      case StatPlatform.tiktok:
        return Icons.music_note;
      case StatPlatform.instagram:
        return Icons.camera_alt_outlined;
    }
  }
}

class BrandProfile {
  const BrandProfile({
    required this.username,
    required this.displayName,
    this.bio,
    this.avatarUrl,
  });

  final String username;
  final String displayName;
  final String? bio;
  final String? avatarUrl;

  factory BrandProfile.fromMap(Map<String, dynamic> map) {
    final String username = map['username'] as String;
    return BrandProfile(
      username: username,
      displayName: (map['display_name'] as String?)?.trim().isNotEmpty == true
          ? map['display_name'] as String
          : username,
      bio: map['bio'] as String?,
      avatarUrl: map['avatar_url'] as String?,
    );
  }
}

class SocialStat {
  const SocialStat({
    required this.platform,
    required this.followersCount,
    this.lastSuccessAt,
    this.lastAttemptAt,
    this.lastError,
    this.isManual = false,
  });

  final StatPlatform platform;
  final int followersCount;
  final DateTime? lastSuccessAt;
  final DateTime? lastAttemptAt;
  final String? lastError;
  final bool isManual;

  factory SocialStat.fromMap(Map<String, dynamic> map) {
    return SocialStat(
      platform: StatPlatform.values.byName(map['platform'] as String),
      followersCount: (map['followers_count'] as num).toInt(),
      lastSuccessAt: _parseDate(map['last_success_at']),
      lastAttemptAt: _parseDate(map['last_attempt_at']),
      lastError: map['last_error'] as String?,
      isManual: map['source'] == 'manual',
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'platform': platform.name,
      'followers_count': followersCount,
      'last_success_at': lastSuccessAt?.toUtc().toIso8601String(),
      'last_attempt_at': lastAttemptAt?.toUtc().toIso8601String(),
      'last_error': lastError,
    };
  }

  static DateTime? _parseDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toUtc();
  }
}

class ProfileRepository {
  static const String _statsCacheKey = 'social_stats_cache_v1';

  static const Set<String> _avatarExtensions = <String>{
    'jpg',
    'jpeg',
    'png',
    'webp',
  };

  /// Remplace la photo de profil : upload dans le bucket « avatars »
  /// puis enregistre l'URL publique dans brand_profile.avatar_url.
  Future<void> updateAvatar({
    required Uint8List bytes,
    required String extension,
  }) async {
    final String normalized = extension.trim().toLowerCase();
    if (!_avatarExtensions.contains(normalized)) {
      throw const ProfileUnavailableException(
        'Format de photo non supporté (JPG, PNG ou WebP attendu).',
      );
    }

    final String contentType = switch (normalized) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      _ => 'image/webp',
    };
    final String path =
        'avatar_${DateTime.now().toUtc().microsecondsSinceEpoch}'
        '.$normalized';
    final StorageFileApi storage = supabase.storage.from('avatars');

    try {
      await storage.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          contentType: contentType,
          cacheControl: '3600',
          upsert: false,
        ),
      );
    } catch (error, stack) {
      log.error('Upload de la photo de profil impossible', error, stack);
      rethrow;
    }

    final String publicUrl = storage.getPublicUrl(path);
    if (publicUrl.isEmpty) {
      throw const ProfileUnavailableException('URL de la photo indisponible.');
    }

    try {
      await supabase
          .from('brand_profile')
          .update(<String, dynamic>{'avatar_url': publicUrl})
          .eq('id', 1);
    } catch (error, stack) {
      log.error('Mise à jour de la photo de profil impossible', error, stack);
      rethrow;
    }
  }

  /// Retire la photo de profil de brand_profile (l'objet Storage
  /// historique reste en place, les autres versions restent consultables).
  Future<void> removeAvatar() async {
    try {
      await supabase
          .from('brand_profile')
          .update(<String, dynamic>{'avatar_url': null})
          .eq('id', 1);
    } catch (error, stack) {
      log.error('Suppression de la photo de profil impossible', error, stack);
      rethrow;
    }
  }

  /// Définit manuellement le nombre de followers d'une plateforme
  /// (réservé à l'admin, RLS social_stats_admin_update).
  Future<void> setFollowers(StatPlatform platform, int count) async {
    final int clamped = count < 0 ? 0 : count;
    final String now = DateTime.now().toUtc().toIso8601String();
    try {
      await supabase
          .from('social_stats')
          .update(<String, dynamic>{
            'followers_count': clamped,
            'source': 'manual',
            'last_success_at': now,
            'last_attempt_at': now,
            'last_error': null,
          })
          .eq('platform', platform.name);
    } catch (error, stack) {
      log.error(
        'Mise à jour manuelle des followers impossible (${platform.name})',
        error,
        stack,
      );
      rethrow;
    }
  }

  Future<BrandProfile> fetchBrand() async {
    try {
      final Map<String, dynamic>? row = await supabase
          .from('brand_profile')
          .select()
          .eq('id', 1)
          .maybeSingle();
      if (row == null) {
        throw const ProfileUnavailableException(
          'Le profil public n’est pas encore configuré.',
        );
      }
      return BrandProfile.fromMap(row);
    } on PostgrestException catch (error, stack) {
      log.error('Lecture du profil de marque impossible', error, stack);
      rethrow;
    }
  }

  Stream<List<SocialStat>> watchStats() async* {
    List<SocialStat>? cached;
    try {
      cached = await _readCache();
    } catch (error) {
      log.warn('Lecture du cache des statistiques impossible', error);
    }

    if (cached != null && cached.isNotEmpty) {
      yield _sorted(cached);
    }

    try {
      final List<SocialStat> initial = await _fetchStats();
      await _writeCache(initial);
      yield _sorted(initial);
    } catch (error) {
      log.warn('Synchronisation initiale des statistiques impossible', error);
      if (cached == null || cached.isEmpty) rethrow;
    }

    try {
      await for (final List<Map<String, dynamic>> rows
          in supabase
              .from('social_stats')
              .stream(primaryKey: <String>['platform'])) {
        final List<SocialStat> stats = rows
            .map(SocialStat.fromMap)
            .toList(growable: false);
        await _writeCache(stats);
        yield _sorted(stats);
      }
    } catch (error, stack) {
      log.error('Flux Realtime des statistiques interrompu', error, stack);
      rethrow;
    }
  }

  Future<List<SocialStat>> _fetchStats() async {
    final List<Map<String, dynamic>> rows = await supabase
        .from('social_stats')
        .select();
    return rows.map(SocialStat.fromMap).toList(growable: false);
  }

  List<SocialStat> _sorted(List<SocialStat> stats) {
    return List<SocialStat>.of(stats)..sort(
      (SocialStat a, SocialStat b) =>
          a.platform.index.compareTo(b.platform.index),
    );
  }

  Future<List<SocialStat>?> _readCache() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_statsCacheKey);
    if (raw == null || raw.isEmpty) return null;

    final Object? decoded = jsonDecode(raw);
    if (decoded is! List) return null;

    return decoded
        .whereType<Map<Object?, Object?>>()
        .map(
          (Map<Object?, Object?> item) =>
              SocialStat.fromMap(item.cast<String, dynamic>()),
        )
        .toList(growable: false);
  }

  Future<void> _writeCache(List<SocialStat> stats) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _statsCacheKey,
        jsonEncode(
          stats.map((SocialStat stat) => stat.toMap()).toList(growable: false),
        ),
      );
    } catch (error) {
      log.warn('Écriture du cache des statistiques impossible', error);
    }
  }
}

class ProfileUnavailableException implements Exception {
  const ProfileUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

final Provider<ProfileRepository> profileRepositoryProvider =
    Provider<ProfileRepository>((Ref ref) => ProfileRepository());

final FutureProvider<BrandProfile> brandProfileProvider =
    FutureProvider<BrandProfile>(
      (Ref ref) => ref.watch(profileRepositoryProvider).fetchBrand(),
    );

final StreamProvider<List<SocialStat>> socialStatsProvider =
    StreamProvider<List<SocialStat>>(
      (Ref ref) => ref.watch(profileRepositoryProvider).watchStats(),
    );
