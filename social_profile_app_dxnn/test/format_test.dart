import 'package:flutter_test/flutter_test.dart';
import 'package:social_profile_app_dxn/core/format.dart';

void main() {
  group('compactCount', () {
    test('affiche les petits nombres tels quels', () {
      expect(compactCount(0), '0');
      expect(compactCount(999), '999');
    });

    test('compacte les milliers avec une décimale française', () {
      expect(compactCount(1000), '1 k');
      expect(compactCount(12400), '12,4 k');
      expect(compactCount(1250), '1,2 k');
      expect(compactCount(999999), '999 k');
    });

    test('compacte les millions et milliards', () {
      expect(compactCount(1000000), '1 M');
      expect(compactCount(1200000), '1,2 M');
      expect(compactCount(1000000000), '1 Md');
    });
  });

  group('timeAgo', () {
    final DateTime now = DateTime.utc(2026, 10, 26, 12);

    test('gère le présent et les minutes', () {
      expect(timeAgo(now, now: now), 'à l’instant');
      expect(
        timeAgo(now.subtract(const Duration(minutes: 5)), now: now),
        'il y a 5 min',
      );
    });

    test('gère les heures, les jours et les dates anciennes', () {
      expect(
        timeAgo(now.subtract(const Duration(hours: 3)), now: now),
        'il y a 3 h',
      );
      expect(
        timeAgo(now.subtract(const Duration(days: 2)), now: now),
        'il y a 2 j',
      );
      expect(
        timeAgo(now.subtract(const Duration(days: 30)), now: now),
        '26/09/2026',
      );
    });
  });

  test('formatDateTime utilise le format français', () {
    final DateTime date = DateTime(2026, 10, 26, 9, 5);
    expect(formatDateTime(date), '26/10/2026 à 09:05');
  });
}
