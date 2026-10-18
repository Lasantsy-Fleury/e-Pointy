import 'dart:io';

import 'package:mipointy/data/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

bool _initialized = false;

/// Chemin absolu vers un fichier temporaire de test (hors du dépôt).
Future<String> tempFilePath(String name) async {
  final dir = await Directory.systemTemp.createTemp('mipointy_test_');
  return '${dir.path}${Platform.pathSeparator}$name';
}

void initFfiTest() {
  if (_initialized) return;
  sqfliteFfiInit();
  _initialized = true;
}

/// Ouvre une base SQLite en mémoire, isolée pour chaque appel.
///
/// `singleInstance: false` est indispensable : sans cela, sqflite réutilise
/// la même connexion `:memory:` pour un même chemin et les tests partagent
/// leurs données (ce qui fausse les comptages et provoque des conflits
/// d'unicité entre tests).
Future<AppDatabase> openTestDb() async {
  initFfiTest();
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      singleInstance: false,
      onCreate: (db, version) => AppDatabase.createSchema(db),
    ),
  );
  return AppDatabase.test(db);
}
