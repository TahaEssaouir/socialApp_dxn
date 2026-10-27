import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_profile_app_dxn/features/auth/login_screen.dart';

void main() {
  testWidgets('valide les champs avant tout appel réseau', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.tap(find.text('Se connecter'));
    await tester.pump();

    expect(find.text('Saisissez votre email.'), findsOneWidget);
    expect(find.text('Saisissez votre mot de passe.'), findsOneWidget);
  });

  testWidgets('affiche le formulaire administrateur', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginScreen()),
      ),
    );

    expect(find.text('Espace administrateur'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Mot de passe'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  });
}
