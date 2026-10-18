import 'package:flutter_test/flutter_test.dart';
import 'package:mipointy/core/utils.dart';
import 'package:mipointy/models/distribution.dart';
import 'package:mipointy/models/enums.dart';
import 'package:mipointy/models/pointage.dart';
import 'package:mipointy/models/student.dart';
import 'package:mipointy/models/trip_day.dart';
import 'package:mipointy/models/travel_session.dart';
import 'package:mipointy/services/stats_service.dart';
import 'package:mipointy/services/sync_service.dart';

import 'test_utils.dart';

void main() {
  group('SyncService merge', () {
    test('idempotent: merging same bundle twice only skips pointages',
        () async {
      final dbA = await openTestDb();
      final dba = await dbA.database;

      final now = nowUtcIso();
      await dba.insert(
          'sessions',
          TravelSession(
            id: 's1',
            token: 'TOK1',
            name: 'S1',
            createdAt: now,
            updatedAt: now,
          ).toMap());
      await dba.insert(
          'days',
          TripDay(
            id: 'day1',
            sessionId: 's1',
            label: 'Jour 1',
            createdAt: now,
            updatedAt: now,
          ).toMap());
      await dba.insert(
          'distributions',
          Distribution(
            id: 'dist1',
            sessionId: 's1',
            dayId: 'day1',
            name: 'Repas',
            status: DistributionStatus.ouverte,
            createdAt: now,
            updatedAt: now,
          ).toMap());
      await dba.insert(
          'students',
          Student(
            id: 'st1',
            sessionId: 's1',
            matricule: '001',
            fullName: 'A',
            qrToken: 'Q1',
            createdAt: now,
            updatedAt: now,
          ).toMap());
      final p1 = Pointage(
        id: newId(),
        sessionId: 's1',
        studentId: 'st1',
        distributionId: 'dist1',
        deviceId: 'devA',
        recordedAtUtc: now,
        recordedAtLocal: now,
        createdAt: now,
        updatedAt: now,
      );
      await dba.insert('pointages', p1.toMap());

      final syncA = SyncService(dbA);
      final bundle = await syncA.buildBundle(
        sessionId: 's1',
        kind: 'test',
        deviceId: 'devA',
        deviceName: 'DevA',
      );
      final envelope = syncA.parseBundle(
          await syncA
              .writeBundleFile(bundle, await tempFilePath('test.mipointy'))
              .then((f) => f.readAsString()));

      final dbB = await openTestDb();
      final syncB = SyncService(dbB);
      final preview = await syncB.previewFor(envelope);
      expect(preview.isNewSession, true);

      // First merge
      final r1 = await syncB.mergeBundle(envelope, mode: MergeMode.fusionner);
      expect(r1.pointagesApplied, 1);
      expect(r1.pointagesSkipped, 0);

      // Second merge (idempotent)
      final r2 = await syncB.mergeBundle(envelope, mode: MergeMode.fusionner);
      expect(r2.pointagesSkipped, 1);
      expect(r2.pointagesApplied, 0);
      expect(r2.pointagesConflicts, 0);
    });

    test('conflict when both have valid pointage for same student', () async {
      final dbA = await openTestDb();
      final dba = await dbA.database;

      final now = nowUtcIso();
      await dba.insert(
          'sessions',
          TravelSession(
            id: 's1',
            token: 'TOK1',
            name: 'S1',
            createdAt: now,
            updatedAt: now,
          ).toMap());
      await dba.insert(
          'days',
          TripDay(
            id: 'day1',
            sessionId: 's1',
            label: 'Jour 1',
            createdAt: now,
            updatedAt: now,
          ).toMap());
      await dba.insert(
          'distributions',
          Distribution(
            id: 'dist1',
            sessionId: 's1',
            dayId: 'day1',
            name: 'Repas',
            status: DistributionStatus.ouverte,
            createdAt: now,
            updatedAt: now,
          ).toMap());
      await dba.insert(
          'students',
          Student(
            id: 'st1',
            sessionId: 's1',
            matricule: '001',
            fullName: 'A',
            qrToken: 'Q1',
            createdAt: now,
            updatedAt: now,
          ).toMap());
      final pA = Pointage(
        id: 'pa',
        sessionId: 's1',
        studentId: 'st1',
        distributionId: 'dist1',
        deviceId: 'devA',
        recordedAtUtc: now,
        recordedAtLocal: now,
        createdAt: now,
        updatedAt: now,
      );
      await dba.insert('pointages', pA.toMap());

      final bundle = await SyncService(dbA).buildBundle(
        sessionId: 's1',
        kind: 'sync',
        deviceId: 'devA',
        deviceName: 'DevA',
      );
      final envelope = SyncService(dbA).parseBundle(
          await SyncService(dbA)
              .writeBundleFile(bundle, await tempFilePath('b.mipointy'))
              .then((f) => f.readAsString()));

      final dbB = await openTestDb();
      final dbb = await dbB.database;

      // DBB has same session/student but different pointage id for same student
      await dbb.insert(
          'sessions',
          TravelSession(
            id: 's1',
            token: 'TOK1',
            name: 'S1',
            createdAt: now,
            updatedAt: now,
          ).toMap());
      await dbb.insert(
          'days',
          TripDay(
            id: 'day1',
            sessionId: 's1',
            label: 'Jour 1',
            createdAt: now,
            updatedAt: now,
          ).toMap());
      await dbb.insert(
          'distributions',
          Distribution(
            id: 'dist1',
            sessionId: 's1',
            dayId: 'day1',
            name: 'Repas',
            status: DistributionStatus.ouverte,
            createdAt: now,
            updatedAt: now,
          ).toMap());
      await dbb.insert(
          'students',
          Student(
            id: 'st1',
            sessionId: 's1',
            matricule: '001',
            fullName: 'A',
            qrToken: 'Q1',
            createdAt: now,
            updatedAt: now,
          ).toMap());
      final pB = Pointage(
        id: 'pb',
        sessionId: 's1',
        studentId: 'st1',
        distributionId: 'dist1',
        deviceId: 'devB',
        recordedAtUtc: now,
        recordedAtLocal: now,
        createdAt: now,
        updatedAt: now,
      );
      await dbb.insert('pointages', pB.toMap());

      final r = await SyncService(dbB).mergeBundle(envelope, mode: MergeMode.fusionner);
      expect(r.pointagesConflicts, 1);
      expect(r.conflictsRecorded, 1);

      final conflicts = await dbb.query('conflicts');
      expect(conflicts.length, 1);

      // Served count: only pB is valid locally; incoming pa stored as doublon_potentiel
      final stats = await StatsService(dbB).forDistribution(
          's1', Distribution.fromMap((await dbb.query('distributions')).first));
      expect(stats.served, 1);

      final allPts = await dbb.query('pointages');
      expect(allPts.length, 2); // pB (valide) + pa (doublon_potentiel)
      final paStatus = allPts.firstWhere((pt) => pt['id'] == 'pa')['status'];
      expect(paStatus, 'doublon_potentiel');
    });
  });
}
