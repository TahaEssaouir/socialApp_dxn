// Tests du modèle/repository des centres de services (carte).
import 'package:flutter_test/flutter_test.dart';

import 'package:social_profile_app_dxn/features/map/service_centers_repository.dart';

void main() {
  test('ServiceCenter.fromMap lit les tableaux phones/emails', () {
    final ServiceCenter center = ServiceCenter.fromMap(<String, dynamic>{
      'id': 'edb18558-748a-4099-b3de-a5c9c9c0b2e2',
      'city': 'Casablanca',
      'name': 'DAXEN MOROCCO LLC',
      'kind': 'branch',
      'address': 'ANGLE BD AMBASSADEUR BEN AICHA ET RUE SIDO',
      'phones': <String>['+212 6 69 00 85 38', '0620071433'],
      'emails': <String>['salesmaroc@dxn2u.com'],
      'location': null,
      'created_at': '2026-11-09T17:12:22.110815Z',
    });

    expect(center.phones, <String>['+212 6 69 00 85 38', '0620071433']);
    expect(center.emails, <String>['salesmaroc@dxn2u.com']);
  });

  test(
    'buildPayload enregistre des tableaux de contacts (pas phone/email)',
    () {
      final Map<String, dynamic> payload =
          ServiceCentersRepository.buildPayload(
            city: ' Rabat ',
            name: 'Centre Rabat',
            kind: CenterKind.center,
            address: 'Rue X',
            phones: <String>[' 0620071433 ', ' 06.60.77.44.67', ''],
            emails: <String>['a@b.com', ' '],
            location: 'https://maps.app.goo.gl/x',
          );

      expect(payload['city'], 'Rabat');
      expect(payload['phones'], <String>['0620071433', '06.60.77.44.67']);
      expect(payload['emails'], <String>['a@b.com']);
      expect(payload.containsKey('phone'), isFalse);
      expect(payload.containsKey('email'), isFalse);
      expect(payload['location'], 'https://maps.app.goo.gl/x');
    },
  );
}
