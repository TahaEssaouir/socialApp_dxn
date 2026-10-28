import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/logger.dart';
import '../../core/supabase.dart';
import '../posts/posts_repository.dart';

class AdminRepository {
  Future<void> createDriveLinkPoster({
    required String driveUrl,
    required PostPlatform platform,
    required PostKind kind,
    String? caption,
  }) async {
    try {
      await supabase.from('posts').insert(<String, dynamic>{
        'platform': platform.name,
        'kind': kind.name,
        'caption': (caption?.trim().isEmpty ?? true) ? null : caption!.trim(),
        'media_path': driveUrl.trim(),
      });

      log.info('Poster Drive ajouté', <String, Object>{
        'platform': platform.name,
        'kind': kind.name,
      });
    } catch (error, stack) {
      log.error("Ajout d'un poster Drive impossible", error, stack);
      rethrow;
    }
  }

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
    String? driveLink,
  }) async {
    final StorageFileApi storage = supabase.storage.from('posters');
    String? newMediaPath;
    bool databaseUpdated = false;

    try {
      if (bytes != null && extension != null && kind != PostKind.explication) {
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

      final Map<String, dynamic> updateData = <String, dynamic>{
        'platform': platform.name,
        'kind': kind.name,
        'caption': (caption?.trim().isEmpty ?? true)
            ? null
            : caption!.trim(),
      };
      if (kind == PostKind.explication && driveLink != null && driveLink.trim().isNotEmpty) {
        updateData['media_path'] = driveLink.trim();
      } else if (newMediaPath case final String mediaPath) {
        updateData['media_path'] = mediaPath;
      }

      await supabase.from('posts').update(updateData).eq('id', id);
      databaseUpdated = true;

      if (newMediaPath != null) {
        try {
          if (!(oldMediaPath.startsWith('http://') || oldMediaPath.startsWith('https://'))) {
            await storage.remove(<String>[oldMediaPath]);
          }
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
      if (!(mediaPath.startsWith('http://') || mediaPath.startsWith('https://'))) {
        try {
          await supabase.storage.from('posters').remove(<String>[mediaPath]);
        } catch (cleanupError) {
          log.warn('Nettoyage du fichier poster impossible', cleanupError);
        }
      }
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
