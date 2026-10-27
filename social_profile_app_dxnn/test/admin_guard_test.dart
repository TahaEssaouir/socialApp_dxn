import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:social_profile_app_dxn/features/admin/admin_guard.dart";
import "package:social_profile_app_dxn/features/auth/auth_repository.dart";

void main() {
  Future<void> pumpGuard(WidgetTester tester, {required bool admin}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isAdminProvider.overrideWith((Ref ref) async => admin),
        ],
        child: const MaterialApp(
          home: AdminGuard(
            child: Scaffold(body: Text("Formulaire admin")),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("refuse un visiteur", (WidgetTester tester) async {
    await pumpGuard(tester, admin: false);

    expect(find.text("Accès administrateur requis"), findsOneWidget);
    expect(find.text("Formulaire admin"), findsNothing);
  });

  testWidgets("autorise un administrateur", (WidgetTester tester) async {
    await pumpGuard(tester, admin: true);

    expect(find.text("Formulaire admin"), findsOneWidget);
    expect(find.text("Accès administrateur requis"), findsNothing);
  });
}
