import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/logger.dart';
import '../../core/supabase.dart';

/// Une ville du Maroc affichée sur la carte.
class MoroccoCity {
  const MoroccoCity(this.name, this.position);

  final String name;
  final LatLng position;
}

/// Villes du Maroc affichées sur la carte (ordre alphabétique).
const List<MoroccoCity> kMoroccoCities = <MoroccoCity>[
  MoroccoCity('Agadir', LatLng(30.4278, -9.5981)),
  MoroccoCity('Al Hoceima', LatLng(35.2517, -3.9372)),
  MoroccoCity('Azilal', LatLng(31.9636, -6.5714)),
  MoroccoCity('Azrou', LatLng(33.4333, -5.2167)),
  MoroccoCity('Béni Mellal', LatLng(32.3373, -6.3498)),
  MoroccoCity('Berkane', LatLng(34.9455, -2.1663)),
  MoroccoCity('Berrechid', LatLng(33.2667, -7.5872)),
  MoroccoCity('Casablanca', LatLng(33.5731, -7.5898)),
  MoroccoCity('Chefchaouen', LatLng(35.1688, -5.2636)),
  MoroccoCity('Dakhla', LatLng(23.6848, -15.957)),
  MoroccoCity('El Jadida', LatLng(33.2316, -8.5007)),
  MoroccoCity('El Kelâa des Sraghna', LatLng(31.6864, -8.1531)),
  MoroccoCity('Errachidia', LatLng(31.9314, -4.4244)),
  MoroccoCity('Essaouira', LatLng(31.5085, -9.7595)),
  MoroccoCity('Fès', LatLng(34.0181, -5.0078)),
  MoroccoCity('Figuig', LatLng(32.1131, -1.23)),
  MoroccoCity('Guelmim', LatLng(28.987, -10.0574)),
  MoroccoCity('Ifrane', LatLng(33.5228, -5.1106)),
  MoroccoCity('Inezgane', LatLng(30.3299, -9.5964)),
  MoroccoCity('Kénitra', LatLng(34.261, -6.5802)),
  MoroccoCity('Khemisset', LatLng(33.8242, -6.0658)),
  MoroccoCity('Khouribga', LatLng(32.8811, -6.9063)),
  MoroccoCity('Ksar El Kébir', LatLng(35.1892, -5.8997)),
  MoroccoCity('Laâyoune', LatLng(27.1536, -13.2033)),
  MoroccoCity('Larache', LatLng(35.1932, -6.1561)),
  MoroccoCity('Marrakech', LatLng(31.6295, -7.9811)),
  MoroccoCity('Meknès', LatLng(33.8731, -5.5407)),
  MoroccoCity('Midelt', LatLng(32.6864, -4.735)),
  MoroccoCity('Mohammedia', LatLng(33.6861, -7.383)),
  MoroccoCity('Nador', LatLng(35.1681, -2.9333)),
  MoroccoCity('Ouarzazate', LatLng(30.9189, -6.8934)),
  MoroccoCity('Oued Zem', LatLng(32.8625, -6.5731)),
  MoroccoCity('Oujda', LatLng(34.6814, -1.9086)),
  MoroccoCity('Oulad Teima', LatLng(30.3936, -9.211)),
  MoroccoCity('Ouazzane', LatLng(34.7969, -5.5833)),
  MoroccoCity('Rabat', LatLng(34.0209, -6.8416)),
  MoroccoCity('Safi', LatLng(32.2994, -9.2372)),
  MoroccoCity('Salé', LatLng(34.0531, -6.7985)),
  MoroccoCity('Settat', LatLng(33.001, -7.6166)),
  MoroccoCity('Sidi Ifni', LatLng(29.3847, -10.1792)),
  MoroccoCity('Sidi Kacem', LatLng(34.2211, -5.7017)),
  MoroccoCity('Sidi Slimane', LatLng(34.2639, -5.9231)),
  MoroccoCity('Tan-Tan', LatLng(28.4375, -11.1011)),
  MoroccoCity('Tanger', LatLng(35.7595, -5.834)),
  MoroccoCity('Taourirt', LatLng(34.4472, -2.9728)),
  MoroccoCity('Taza', LatLng(34.21, -4.01)),
  MoroccoCity('Témara', LatLng(33.9287, -6.9066)),
  MoroccoCity('Tétouan', LatLng(35.5889, -5.3626)),
  MoroccoCity('Tiznit', LatLng(29.6974, -8.9736)),
  MoroccoCity('Zagora', LatLng(30.3324, -5.8378)),
];

/// Normalise un nom de ville : minuscules, sans accents, espaces simples.
String normalizeCityKey(String city) {
  const Map<String, String> diacritics = <String, String>{
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'î': 'i',
    'ï': 'i',
    'ô': 'o',
    'ö': 'o',
    'û': 'u',
    'ù': 'u',
    'ü': 'u',
    'ç': 'c',
  };
  String normalized = city.trim().toLowerCase();
  diacritics.forEach((String key, String value) {
    normalized = normalized.replaceAll(key, value);
  });
  normalized = normalized.replaceAll('-', ' ').replaceAll("'", ' ');
  return normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
}

final Map<String, MoroccoCity> _moroccoCitiesByKey = <String, MoroccoCity>{
  for (final MoroccoCity city in kMoroccoCities)
    normalizeCityKey(city.name): city,
};

/// Recherche une ville du Maroc par son nom (tolérant casse, accents, tirets).
MoroccoCity? moroccoCityByName(String name) =>
    _moroccoCitiesByKey[normalizeCityKey(name)];

LatLng? coordsForCity(String city) => moroccoCityByName(city)?.position;

enum CenterKind { center, branch }

extension CenterKindX on CenterKind {
  String get label {
    switch (this) {
      case CenterKind.center:
        return 'Centre de services';
      case CenterKind.branch:
        return 'Branche principale';
    }
  }

  static CenterKind fromName(String? name) {
    switch (name) {
      case 'branch':
        return CenterKind.branch;
      default:
        return CenterKind.center;
    }
  }
}

/// Convertit une valeur SQL (tableau text[] ou ancien texte séparé) en liste.
List<String> stringListFromSql(dynamic value) {
  if (value == null) return const <String>[];
  if (value is List<dynamic>) {
    return value
        .map((dynamic item) => item?.toString().trim() ?? '')
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
  }
  if (value is String) {
    return value
        .split(RegExp(r'[,;/]'))
        .map((String part) => part.trim())
        .where((String part) => part.isNotEmpty)
        .toList(growable: false);
  }
  return const <String>[];
}

class ServiceCenter {
  const ServiceCenter({
    required this.id,
    required this.city,
    required this.name,
    required this.createdAt,
    required this.kind,
    required this.phones,
    required this.emails,
    this.address,
    this.location,
  });

  final String id;
  final String city;
  final String name;
  final DateTime createdAt;
  final CenterKind kind;
  final String? address;
  final List<String> phones;
  final List<String> emails;
  final String? location;

  factory ServiceCenter.fromMap(Map<String, dynamic> map) {
    return ServiceCenter(
      id: map['id'] as String,
      city: (map['city'] as String?)?.trim() ?? '',
      name: (map['name'] as String?)?.trim() ?? '',
      address: (map['address'] as String?)?.trim(),
      phones: stringListFromSql(map['phones'] ?? map['phone']),
      emails: stringListFromSql(map['emails'] ?? map['email']),
      kind: CenterKindX.fromName(map['kind'] as String?),
      location: (map['location'] as String?)?.trim(),
      createdAt: DateTime.parse(map['created_at'] as String).toUtc(),
    );
  }
}

class ServiceCentersRepository {
  Stream<List<ServiceCenter>> watchCenters() async* {
    try {
      await for (final List<Map<String, dynamic>> rows
          in supabase
              .from('service_centers')
              .stream(primaryKey: <String>['id'])
              .order('city', ascending: true)) {
        // Déduplique par id (Realtime peut réémettre une ligne déjà présente).
        final Map<String, ServiceCenter> seen = <String, ServiceCenter>{
          for (final ServiceCenter center
              in rows.map(ServiceCenter.fromMap).toList(growable: false))
            center.id: center,
        };
        yield seen.values.toList(growable: false);
      }
    } catch (error, stack) {
      log.error(
        'Flux Realtime des centres de services interrompu',
        error,
        stack,
      );
      rethrow;
    }
  }

  Future<void> createCenter({
    required String city,
    required String name,
    CenterKind kind = CenterKind.center,
    String? address,
    List<String> phones = const <String>[],
    List<String> emails = const <String>[],
    String? location,
  }) async {
    try {
      await supabase.from('service_centers').insert(<String, dynamic>{
        'city': city.trim(),
        'name': name.trim(),
        'kind': kind.name,
        'address': _nullIfEmpty(address),
        'phones': _cleanList(phones),
        'emails': _cleanList(emails),
        'location': _nullIfEmpty(location),
      });
    } catch (error, stack) {
      log.error('Ajout du centre de services impossible', error, stack);
      rethrow;
    }
  }

  Future<void> updateCenter({
    required String id,
    required String city,
    required String name,
    required CenterKind kind,
    String? address,
    List<String> phones = const <String>[],
    List<String> emails = const <String>[],
    String? location,
  }) async {
    try {
      await supabase
          .from('service_centers')
          .update(<String, dynamic>{
            'city': city.trim(),
            'name': name.trim(),
            'kind': kind.name,
            'address': _nullIfEmpty(address),
            'phones': _cleanList(phones),
            'emails': _cleanList(emails),
            'location': _nullIfEmpty(location),
          })
          .eq('id', id);
    } catch (error, stack) {
      log.error('Modification du centre de services impossible', error, stack);
      rethrow;
    }
  }

  Future<void> deleteCenter(String id) async {
    try {
      await supabase.from('service_centers').delete().eq('id', id);
    } catch (error, stack) {
      log.error('Suppression du centre de services impossible', error, stack);
      rethrow;
    }
  }

  static String? _nullIfEmpty(String? value) {
    final String trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Nettoie une liste (trim, doublons, vides) ; null si la liste est vide.
  static List<String>? _cleanList(List<String> values) {
    final List<String> cleaned = <String>[];
    for (final String value in values) {
      final String trimmed = value.trim();
      if (trimmed.isNotEmpty && !cleaned.contains(trimmed)) {
        cleaned.add(trimmed);
      }
    }
    return cleaned.isEmpty ? null : cleaned;
  }
}

final Provider<ServiceCentersRepository> serviceCentersRepositoryProvider =
    Provider<ServiceCentersRepository>((Ref ref) => ServiceCentersRepository());

final StreamProvider<List<ServiceCenter>> serviceCentersProvider =
    StreamProvider<List<ServiceCenter>>(
      (Ref ref) => ref.watch(serviceCentersRepositoryProvider).watchCenters(),
    );

/// Regroupe les centres par ville (clé normalisée, ordre d'apparition).
Map<String, List<ServiceCenter>> groupCentersByCity(
  List<ServiceCenter> centers,
) {
  final Map<String, List<ServiceCenter>> grouped =
      <String, List<ServiceCenter>>{};
  for (final ServiceCenter center in centers) {
    final String raw = center.city.trim();
    final String key = raw.isEmpty ? 'autre' : normalizeCityKey(raw);
    (grouped[key] ??= <ServiceCenter>[]).add(center);
  }
  return grouped;
}
