import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/logger.dart';
import '../../core/supabase.dart';

/// Coordonnées approximatives des principales villes marocaines.
const Map<String, LatLng> kMoroccoCityCoords = <String, LatLng>{
  'casablanca': LatLng(33.5731, -7.5898),
  'rabat': LatLng(34.0209, -6.8416),
  'tanger': LatLng(35.7595, -5.8340),
  'tangier': LatLng(35.7595, -5.8340),
  'agadir': LatLng(30.4278, -9.5981),
  'marrakech': LatLng(31.6295, -7.9811),
  'fes': LatLng(34.0181, -5.0078),
  'fès': LatLng(34.0181, -5.0078),
  'meknes': LatLng(33.8731, -5.5407),
  'meknès': LatLng(33.8731, -5.5407),
  'oujda': LatLng(34.6814, -1.9086),
  'kenitra': LatLng(34.2610, -6.5802),
  'kénitra': LatLng(34.2610, -6.5802),
  'tetouan': LatLng(35.5889, -5.3626),
  'tétouan': LatLng(35.5889, -5.3626),
  'safi': LatLng(32.2994, -9.2372),
  'el jadida': LatLng(33.2316, -8.5007),
  'nador': LatLng(35.1681, -2.9333),
  'laayoune': LatLng(27.1536, -13.2033),
  'dakhla': LatLng(23.6848, -15.9570),
  'mohammedia': LatLng(33.6861, -7.3830),
  'beni mellal': LatLng(32.3373, -6.3498),
  'béni mellal': LatLng(32.3373, -6.3498),
  'khouribga': LatLng(32.8811, -6.9063),
  'settat': LatLng(33.0010, -7.6166),
  'sale': LatLng(34.0531, -6.7985),
  'salé': LatLng(34.0531, -6.7985),
  'temara': LatLng(33.9287, -6.9066),
  'témara': LatLng(33.9287, -6.9066),
  'errachidia': LatLng(31.9314, -4.4244),
  'ouarzazate': LatLng(30.9189, -6.8934),
  'al hoceima': LatLng(35.2517, -3.9372),
  'larache': LatLng(35.1932, -6.1561),
  'taza': LatLng(34.2100, -4.0100),
  'essaouira': LatLng(31.5085, -9.7595),
};

String normalizeCity(String city) => city.trim().toLowerCase();

LatLng? coordsForCity(String city) => kMoroccoCityCoords[normalizeCity(city)];

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

class ServiceCenter {
  const ServiceCenter({
    required this.id,
    required this.city,
    required this.name,
    required this.createdAt,
    required this.kind,
    this.address,
    this.phone,
    this.email,
    this.location,
  });

  final String id;
  final String city;
  final String name;
  final DateTime createdAt;
  final CenterKind kind;
  final String? address;
  final String? phone;
  final String? email;
  final String? location;

  factory ServiceCenter.fromMap(Map<String, dynamic> map) {
    return ServiceCenter(
      id: map['id'] as String,
      city: (map['city'] as String?)?.trim() ?? '',
      name: (map['name'] as String?)?.trim() ?? '',
      address: (map['address'] as String?)?.trim(),
      phone: (map['phone'] as String?)?.trim(),
      email: (map['email'] as String?)?.trim(),
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
    String? phone,
    String? email,
    String? location,
  }) async {
    try {
      await supabase.from('service_centers').insert(<String, dynamic>{
        'city': city.trim(),
        'name': name.trim(),
        'kind': kind.name,
        'address': _nullIfEmpty(address),
        'phone': _nullIfEmpty(phone),
        'email': _nullIfEmpty(email),
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
    String? phone,
    String? email,
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
            'phone': _nullIfEmpty(phone),
            'email': _nullIfEmpty(email),
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
}

final Provider<ServiceCentersRepository> serviceCentersRepositoryProvider =
    Provider<ServiceCentersRepository>((Ref ref) => ServiceCentersRepository());

final StreamProvider<List<ServiceCenter>> serviceCentersProvider =
    StreamProvider<List<ServiceCenter>>(
      (Ref ref) => ref.watch(serviceCentersRepositoryProvider).watchCenters(),
    );

/// Regroupe les centres par ville (ordre d'apparition).
Map<String, List<ServiceCenter>> groupCentersByCity(
  List<ServiceCenter> centers,
) {
  final Map<String, List<ServiceCenter>> grouped =
      <String, List<ServiceCenter>>{};
  for (final ServiceCenter center in centers) {
    final String key = center.city.trim().isEmpty
        ? 'Autre'
        : center.city.trim();
    (grouped[key] ??= <ServiceCenter>[]).add(center);
  }
  return grouped;
}
