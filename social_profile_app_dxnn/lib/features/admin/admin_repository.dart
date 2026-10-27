import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/logger.dart';
import '../../core/supabase.dart';
import '../posts/posts_repository.dart';

class AdminRepository {
  Future<void> createPoster({
    required Uint8List bytes,
    required String extension,
    required PostPlatform platform,
    required PostKind kind,
    String? caption,
  }) async {
    final String contentType = _contentType(extension);
    final String path =
        '${DateTime.now().toUtc().microsecondsSinceEpoch}.$extension';
    final StorageFileApi storage = supabase.storage.from('posters');
    bool uploaded = false;

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
      uploaded = true;

      await supabase.from('posts').insert(<String, dynamic>{
        'platform': platform.name,
        'kind': kind.name,
        'caption': (caption?.trim().isEmpty ?? true) ? null : caption!.trim(),
        'media_path': path,
      });

      log.info('Poster publié', <String, Object>{
        'platform': platform.name,
        'kind': kind.name,
        'bytes': bytes.length,
      });
    } catch (error, stack) {
      log.error('Publication du poster impossible', error, stack);
      if (uploaded) {
        try {
          await storage.remove(<String>[path]);
        } catch (cleanupError) {
          log.warn('Nettoyage du poster orphelin impossible', cleanupError);
        }
      }
      rethrow;
    }
  }

  Future<void> updatePoster({
    required String id,
    required String oldMediaPath,
    required PostPlatform platform,
    required PostKind kind,
    String? caption,
    Uint8List? bytes,
    String? extension,
  }) async {
    final StorageFileApi storage = supabase.storage.from('posters');
    String? newMediaPath;
    bool databaseUpdated = false;

    try {
      if (bytes != null && extension != null) {
        newMediaPath =
            '${DateTime.now().toUtc().microsecondsSinceEpoch}.$extension';
        await storage.uploadBinary(
          newMediaPath,
          bytes,
          fileOptions: FileOptions(
            contentType: _contentType(extension),
            cacheControl: '3600',
            upsert: false,
          ),
        );
      }

      await supabase
          .from('posts')
          .update(<String, dynamic>{
            'platform': platform.name,
            'kind': kind.name,
            'caption': (caption?.trim().isEmpty ?? true)
                ? null
                : caption!.trim(),
            if (newMediaPath case final String mediaPath)
              'media_path': mediaPath,
          })
          .eq('id', id);
      databaseUpdated = true;

      if (newMediaPath != null) {
        try {
          await storage.remove(<String>[oldMediaPath]);
        } catch (cleanupError) {
          log.warn('Nettoyage de l’ancien poster impossible', cleanupError);
        }
      }
      log.info('Poster modifié', <String, Object>{
        'id': id,
        'replacedMedia': newMediaPath != null,
      });
    } catch (error, stack) {
      log.error('Modification du poster impossible', error, stack);
      if (newMediaPath != null && !databaseUpdated) {
        try {
          await storage.remove(<String>[newMediaPath]);
        } catch (cleanupError) {
          log.warn('Nettoyage du nouveau poster impossible', cleanupError);
        }
      }
      rethrow;
    }
  }

  Future<void> deletePoster({
    required String id,
    required String mediaPath,
  }) async {
    try {
      await supabase.from('posts').delete().eq('id', id);
      await supabase.storage.from('posters').remove(<String>[mediaPath]);
      log.info('Poster supprimé', <String, Object>{'id': id});
    } catch (error, stack) {
      log.error('Suppression du poster impossible', error, stack);
      rethrow;
    }
  }

  String _contentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        throw ArgumentError.value(
          extension,
          'extension',
          'Format non supporté',
        );
    }
  }
}

final Provider<AdminRepository> adminRepositoryProvider =
    Provider<AdminRepository>((Ref ref) => AdminRepository());
