import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/device_id.dart';
import '../../core/logger.dart';
import '../../core/supabase.dart';

class LikeToggleResult {
  const LikeToggleResult({required this.liked, required this.likesCount});

  final bool liked;
  final int likesCount;
}

class LikesRepository {
  Future<Set<String>> fetchLikedIds(List<String> postIds) async {
    if (postIds.isEmpty) return <String>{};
    try {
      final String deviceId = await DeviceId.get();
      final dynamic rows = await supabase.rpc<dynamic>(
        'get_liked_post_ids',
        params: <String, dynamic>{
          'p_device_id': deviceId,
          'p_post_ids': postIds,
        },
      );
      if (rows is! List) return <String>{};
      return rows.map((dynamic e) => e.toString()).toSet();
    } catch (error, stack) {
      log.error('Récupération des « J\'aime » impossible', error, stack);
      return <String>{};
    }
  }

  Future<LikeToggleResult> toggleLike(String postId) async {
    final String deviceId = await DeviceId.get();
    try {
      final dynamic result = await supabase.rpc<dynamic>(
        'toggle_post_like',
        params: <String, dynamic>{'p_post_id': postId, 'p_device_id': deviceId},
      );
      if (result is Map) {
        final bool liked = result['liked'] == true;
        final Object? rawCount = result['likes_count'];
        final int count = switch (rawCount) {
          final int v => v,
          final num v => v.toInt(),
          _ => 0,
        };
        return LikeToggleResult(
          liked: liked,
          likesCount: count < 0 ? 0 : count,
        );
      }
      throw StateError('Réponse inattendue du serveur');
    } catch (error, stack) {
      log.error('Bascule du « J\'aime » impossible', error, stack);
      rethrow;
    }
  }
}

final Provider<LikesRepository> likesRepositoryProvider =
    Provider<LikesRepository>((Ref ref) => LikesRepository());

/// Ensemble des postIds aimés par cet appareil (état confirmé/optimiste).
class LikedPostIdsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  /// Remplace l'ensemble (optimisme, confirmation serveur, retour arrière).
  void replace(Set<String> ids) {
    state = Set<String>.of(ids);
  }

  /// Fusionne des ids confirmés aimés par le serveur.
  void addAll(Set<String> ids) {
    if (ids.isEmpty) return;
    state = Set<String>.of(<String>{...state, ...ids});
  }
}

final NotifierProvider<LikedPostIdsNotifier, Set<String>> likedPostIdsProvider =
    NotifierProvider<LikedPostIdsNotifier, Set<String>>(
      LikedPostIdsNotifier.new,
    );

/// PostIds dont l'état « J'aime » a été vérifié auprès du serveur.
class CheckedLikeIdsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  /// Marque ces ids comme vérifiés (évite les rechargements en boucle).
  void markChecked(Iterable<String> ids) {
    if (ids.isEmpty) return;
    state = Set<String>.of(<String>{...state, ...ids});
  }
}

final NotifierProvider<CheckedLikeIdsNotifier, Set<String>>
checkedLikeIdsProvider = NotifierProvider<CheckedLikeIdsNotifier, Set<String>>(
  CheckedLikeIdsNotifier.new,
);

final Set<String> _likeChecksInFlight = <String>{};

/// Vérifie l'état « J'aime » pour les ids non encore contrôlés.
Future<void> ensureLikesChecked(WidgetRef ref, List<String> postIds) async {
  final Set<String> checked = ref.read(checkedLikeIdsProvider);
  final List<String> pending = postIds
      .where(
        (String id) =>
            !checked.contains(id) && !_likeChecksInFlight.contains(id),
      )
      .toList(growable: false);
  if (pending.isEmpty) return;

  _likeChecksInFlight.addAll(pending);
  try {
    final Set<String> liked = await ref
        .read(likesRepositoryProvider)
        .fetchLikedIds(pending);
    try {
      ref.read(likedPostIdsProvider.notifier).addAll(liked);
      ref.read(checkedLikeIdsProvider.notifier).markChecked(pending);
    } catch (_) {
      // Provider indisponible (widget démonté) : on retentera.
    }
  } finally {
    _likeChecksInFlight.removeAll(pending);
  }
}
