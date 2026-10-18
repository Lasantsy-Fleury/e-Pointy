import 'package:flutter_test/flutter_test.dart';
import 'package:mipointy/main.dart';
import 'package:mipointy/state/app_settings.dart';
import 'package:mipointy/state/session_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_utils.dart';

void main() {
  testWidgets('App boot smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    // L'accès à la base est une entrée/sortie réelle : il doit s'exécuter dans
    // une zone asynchrone réelle (`runAsync`), pas dans l'horloge simulée des
    // widgets de test.
    await tester.runAsync(() async {
      final db = await openTestDb();
      final settings = AppSettings();
      await settings.load();
      await tester.pumpWidget(MipointyApp(
        settings: settings,
        controller: SessionController(settings: settings, db: db),
      ));
      // Laisse le chargement de la liste des sessions se terminer.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pump();
    });

    // Écran d'accueil : titre de l'application + état vide.
    expect(find.text('e-Pointy'), findsOneWidget);
    expect(find.text('Aucune session de voyage'), findsOneWidget);
  });
}
