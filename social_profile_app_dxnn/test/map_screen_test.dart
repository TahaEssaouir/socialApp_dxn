// Tests de l'écran carte : bouton liste des villes + popups floutés.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:social_profile_app_dxn/features/auth/auth_repository.dart';
import 'package:social_profile_app_dxn/features/map/map_screen.dart';
import 'package:social_profile_app_dxn/features/map/service_centers_repository.dart';

ServiceCenter _center(String id, String city, String name) {
  return ServiceCenter.fromMap(<String, dynamic>{
    'id': id,
    'city': city,
    'name': name,
    'kind': 'center',
    'address': 'Rue 1',
    'phones': <String>['0620071433'],
    'emails': <String>['test@dxn.com'],
    'location': null,
    'created_at': '2026-11-09T17:12:22.110815Z',
  });
}

Future<void> _pumpMap(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        serviceCentersProvider.overrideWith(
          (_) => Stream<List<ServiceCenter>>.value(<ServiceCenter>[
            _center('id-casa', 'Casablanca', 'DAXEN MOROCCO LLC'),
            _center('id-fes', 'Fes', 'BNS THERAPIE'),
          ]),
        ),
        isAdminProvider.overrideWith((_) => Future<bool>.value(false)),
      ],
      child: const MaterialApp(home: MapScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  Finder findPopupBlurFilter() {
    return find.byWidgetPredicate(
      (Widget widget) =>
          widget is BackdropFilter &&
          widget.filter.toString().contains('8.0, 8.0'),
    );
  }

  testWidgets('les chips de villes disparaissent au profit du bouton Villes', (
    WidgetTester tester,
  ) async {
    await _pumpMap(tester);

    expect(find.byType(ActionChip), findsNothing);
    expect(find.text('Villes du Maroc (2)'), findsOneWidget);
  });

  testWidgets('le bouton Villes du Maroc est remonté au-dessus du nav', (
    WidgetTester tester,
  ) async {
    await _pumpMap(tester);

    expect(
      find.ancestor(
        of: find.text('Villes du Maroc (2)'),
        matching: find.byWidgetPredicate(
          (Widget widget) => widget is Positioned && widget.bottom == 32.0,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('la carte est légèrement décalée vers le bas', (
    WidgetTester tester,
  ) async {
    await _pumpMap(tester);

    final Finder mapPadding = find.byWidgetPredicate(
      (Widget widget) =>
          widget is Padding &&
          widget.padding == const EdgeInsets.fromLTRB(12, 32, 12, 0),
    );

    expect(mapPadding, findsOneWidget);
  });

  testWidgets('le bouton ouvre un popup flouté listant les villes', (
    WidgetTester tester,
  ) async {
    await _pumpMap(tester);

    await tester.tap(find.text('Villes du Maroc (2)'));
    await tester.pumpAndSettle();

    expect(findPopupBlurFilter(), findsOneWidget);
    expect(find.text('Casablanca'), findsOneWidget);
    expect(find.text('Fes'), findsOneWidget);

    // Le bouton fermer referme le popup.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(findPopupBlurFilter(), findsNothing);
    expect(find.text('Casablanca'), findsNothing);
  });

  testWidgets('la liste des centres de services est un popup en blur', (
    WidgetTester tester,
  ) async {
    await _pumpMap(tester);

    await tester.tap(find.text('Villes du Maroc (2)'));
    await tester.pumpAndSettle();
    // La liste des villes se referme, le popup centres s'ouvre en blur.
    await tester.tap(find.text('Casablanca'));
    await tester.pumpAndSettle();

    expect(findPopupBlurFilter(), findsOneWidget);
    expect(find.text('Centres de services — Casablanca'), findsOneWidget);
    expect(find.text('DAXEN MOROCCO LLC'), findsOneWidget);

    // Le bouton fermer referme le popup des centres.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(findPopupBlurFilter(), findsNothing);
    expect(find.text('DAXEN MOROCCO LLC'), findsNothing);
  });
}
