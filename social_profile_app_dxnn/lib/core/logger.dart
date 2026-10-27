import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warn, error }

/// Journalise sans bloquer l'interface : écriture asynchrone, tampon borné,
/// et masquage des jetons avant toute sortie.
class AppLogger {
  AppLogger._();

  static final AppLogger instance = AppLogger._();

  static const int _maxEntries = 200;
  static const int _maxMessageLength = 2000;

  static final RegExp _jwt = RegExp(
    r'eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}',
  );
  static final RegExp _bearer = RegExp(
    r'Bearer\s+[A-Za-z0-9._-]+',
    caseSensitive: false,
  );
  static final RegExp _secretValue = RegExp(
    r'(service_role|anon_key|access_token|refresh_token)(["\s:=]+)([A-Za-z0-9._-]{8,})',
    caseSensitive: false,
  );

  final List<String> _buffer = <String>[];

  List<String> get recent => List<String>.unmodifiable(_buffer);

  void debug(String message, [Object? data]) {
    _write(LogLevel.debug, message, data);
  }

  void info(String message, [Object? data]) {
    _write(LogLevel.info, message, data);
  }

  void warn(String message, [Object? data]) {
    _write(LogLevel.warn, message, data);
  }

  void error(String message, Object? error, [StackTrace? stackTrace]) {
    _write(
      LogLevel.error,
      message,
      <Object?>[?error, ?stackTrace],
    );
  }

  void _write(LogLevel level, String message, Object? data) {
    if (kReleaseMode && level == LogLevel.debug) return;

    final StringBuffer line = StringBuffer()
      ..write(DateTime.now().toUtc().toIso8601String())
      ..write(' [')
      ..write(level.name.toUpperCase())
      ..write('] ')
      ..write(_sanitize(message));

    if (data != null) {
      line
        ..write(' | ')
        ..write(_sanitize(_stringify(data)));
    }

    final String entry = line.toString();
    final String bounded = entry.length > _maxMessageLength
        ? '${entry.substring(0, _maxMessageLength)}…'
        : entry;

    _buffer.add(bounded);
    if (_buffer.length > _maxEntries) {
      _buffer.removeAt(0);
    }

    unawaited(
      Future<void>.microtask(() {
        developer.log(bounded, name: 'social_profile');
      }),
    );
  }

  String _stringify(Object? data) {
    if (data is StackTrace) return data.toString();
    if (data is Iterable<Object?>) {
      return data.map(_stringify).join(' | ');
    }
    return data.toString();
  }

  String _sanitize(String value) {
    return value
        .replaceAll(_jwt, '<jwt>')
        .replaceAll(_bearer, 'Bearer <redacted>')
        .replaceAllMapped(
          _secretValue,
          (Match match) => '${match.group(1)}${match.group(2)}<redacted>',
        );
  }
}

final AppLogger log = AppLogger.instance;
