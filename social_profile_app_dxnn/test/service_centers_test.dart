import 'package:flutter_test/flutter_test.dart';
import 'package:social_profile_app_dxn/features/map/service_centers_repository.dart';

void main() {
  test('normalizeCityKey ignore casse, accents et séparateurs', () {
    expect(normalizeCityKey('Casablanca'), 'casablanca');
    expect(normalizeCityKey('  FÈS '), 'fes');
    expect(normalizeCityKey('Laâyoune'), 'laayoune');
    expect(normalizeCityKey('Ksar El Kébir'), 'ksar el kebir');
    expect(normalizeCityKey('Tan-Tan'), 'tan tan');
    expect(normalizeCityKey("Kénitra"), normalizeCityKey('kenitra'));
  });

  test('kMoroccoCities contient toutes les grandes villes, sans doublon', () {
    expect(kMoroccoCities.length, greaterThan(40));

    final Set<String> keys = <String>{
      for (final MoroccoCity city in kMoroccoCities)
        normalizeCityKey(city.name),
    };
    expect(keys.length, kMoroccoCities.length);

    for (final String city in <String>[
      'Casablanca',
      'Rabat',
      'Marrakech',
      'Fès',
      'Tanger',
      'Agadir',
      'Meknès',
      'Oujda',
      'Laâyoune',
      'Dakhla',
    ]) {
      expect(moroccoCityByName(city), isNotNull, reason: city);
    }

    expect(moroccoCityByName('Paris'), isNull);
    expect(moroccoCityByName('ville inconnue'), isNull);
  });

  test('moroccoCityByName trouve une ville quelle que soit l\'écriture', () {
    final MoroccoCity fes = moroccoCityByName('Fès')!;
    final MoroccoCity fes2 = moroccoCityByName('fes')!;
    final MoroccoCity fes3 = moroccoCityByName('  FES ')!;

    expect(fes.name, 'Fès');
    expect(fes2.name, 'Fès');
    expect(fes3.name, 'Fès');
    expect(fes.position, fes2.position);
    expect(coordsForCity('fes'), fes.position);
  });

  test('ServiceCenter parse les téléphones et emails (tableau ou texte)', () {
    final Map<String, dynamic> arrayRow = <String, dynamic>{
      'id': '11111111-1111-4111-8111-111111111111',
      'city': 'Rabat',
      'name': 'GANO HERBAL REMEDIES',
      'kind': 'center',
      'phones': <String>['06.60.77.44.67', '06.78.28.18.87'],
      'emails': <String>['a@example.com', 'b@example.com'],
      'created_at': '2026-11-10T10:00:00+00:00',
    };
    final ServiceCenter fromArray = ServiceCenter.fromMap(arrayRow);
    expect(fromArray.phones, <String>['06.60.77.44.67', '06.78.28.18.87']);
    expect(fromArray.emails, <String>['a@example.com', 'b@example.com']);

    // Compatibilité ancien format texte (séparateurs « / », « , », « ; »).
    final Map<String, dynamic> legacyRow = <String, dynamic>{
      'id': '22222222-2222-4222-8222-222222222222',
      'city': 'Casablanca',
      'name': 'RAHMA',
      'kind': 'center',
      'phone': '07.75.70.46.86 / 07.75.70.46.85',
      'email': 'x@example.com, y@example.com',
      'created_at': '2026-11-10T10:00:00+00:00',
    };
    final ServiceCenter fromLegacy = ServiceCenter.fromMap(legacyRow);
    expect(fromLegacy.phones, <String>['07.75.70.46.86', '07.75.70.46.85']);
    expect(fromLegacy.emails, <String>['x@example.com', 'y@example.com']);
  });

  test('groupCentersByCity regroupe les variantes d\'écriture', () {
    final ServiceCenter casablanca = ServiceCenter.fromMap(<String, dynamic>{
      'id': '1',
      'city': 'Casablanca',
      'name': 'A',
      'kind': 'center',
      'created_at': '2026-11-10T10:00:00+00:00',
    });
    final ServiceCenter casablancaAccent = ServiceCenter.fromMap(
      <String, dynamic>{
        'id': '2',
        'city': 'casablanca ',
        'name': 'B',
        'kind': 'center',
        'created_at': '2026-11-10T10:00:00+00:00',
      },
    );
    final ServiceCenter fes = ServiceCenter.fromMap(<String, dynamic>{
      'id': '3',
      'city': 'Fès',
      'name': 'C',
      'kind': 'center',
      'created_at': '2026-11-10T10:00:00+00:00',
    });

    final Map<String, List<ServiceCenter>> grouped = groupCentersByCity(
      <ServiceCenter>[casablanca, casablancaAccent, fes],
    );

    expect(grouped.length, 2);
    expect(grouped['casablanca']!.length, 2);
    expect(grouped['fes']!.single.name, 'C');
  });
}
