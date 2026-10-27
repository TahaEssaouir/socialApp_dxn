import 'dart:convert';

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
  });

  final StatPlatform platform;
  final int followersCount;
  final DateTime? lastSuccessAt;
  final DateTime? lastAttemptAt;
  final String? lastError;

  factory SocialStat.fromMap(Map<String, dynamic> map) {
    return SocialStat(
      platform: StatPlatform.values.byName(map['platform'] as String),
      followersCount: (map['followers_count'] as num).toInt(),
      lastSuccessAt: _parseDate(map['last_success_at']),
      lastAttemptAt: _parseDate(map['last_attempt_at']),
      lastError: map['last_error'] as String?,
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
    return List<SocialStat>.of(stats)
      ..sort(
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
