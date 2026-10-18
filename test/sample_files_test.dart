import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mipointy/services/excel_import_service.dart';
import 'package:mipointy/services/stats_service.dart';
import 'package:mipointy/services/sync_service.dart';
import 'package:mipointy/models/distribution.dart';
import 'package:mipointy/models/enums.dart';

import 'test_utils.dart';

/// Vérifie que les fichiers d'exemple livrés avec le projet sont bien
/// exploitables par l'application : import Excel et réception d'une session.
void main() {
  group('Fichiers d’exemple', () {
    test('l’exemple Excel est importable et sans erreur', () {
      final file = File('samples/exemple_etudiants_epointy.xlsx');
      expect(file.existsSync(), true,
          reason: 'Générez les exemples : dart run tool/generate_samples.dart');

      final report = ExcelImportService.parseBytes(file.readAsBytesSync());
      expect(report.totalRows, 8);
      expect(report.invalidRows, isEmpty);
      expect(report.duplicateRows, isEmpty);
      expect(report.validRows.length, 8);
      // Les zéros initiaux sont préservés.
      expect(report.validRows.any((r) => r.matricule == '00123'), true);
    });

    test('la session d’exemple se reçoit et se fusionne', () async {
      final file = File('samples/session_exemple.epointy');
      expect(file.existsSync(), true,
          reason: 'Générez les exemples : dart run tool/generate_samples.dart');

      final appDb = await openTestDb();
      final db = await appDb.database;
      final sync = SyncService(appDb);

      final envelope = sync.parseBundle(file.readAsStringSync());
      expect(envelope.checksumOk, true, reason: 'Empreinte SHA-256 valide');
      expect(envelope.sessionNames, ['Voyage d’étude — Exemple']);
      expect(envelope.studentCount, 8);

      final preview = await sync.previewFor(envelope);
      expect(preview.isNewSession, true);

      final report = await sync.mergeBundle(envelope, mode: MergeMode.fusionner);
      expect(report.sessionsAdded, 1);
      expect(report.studentsAdded, 8);
      expect(report.pointagesApplied, 8);
      expect(report.pointagesConflicts, 0);

      // Idempotence : une seconde réception ne réapplique rien.
      final second = await sync.mergeBundle(envelope, mode: MergeMode.fusionner);
      expect(second.pointagesApplied, 0);
      expect(second.pointagesSkipped, 8);

      // Compteurs du petit-déjeuner de Jour 1 : 5 servis sur 8.
      final dists = await db.query('distributions');
      final petitDej = Distribution.fromMap(
          dists.firstWhere((d) => (d['name'] as String) == 'Petit-déjeuner'));
      final stats = await StatsService(appDb).forDistribution(
          'demo-session-0001', petitDej);
      expect(stats.served, 5);
      expect(stats.totalStudents, 8);
      expect(stats.remaining, 3);
    });
  });
}
