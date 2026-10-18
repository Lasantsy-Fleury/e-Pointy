import 'package:flutter_test/flutter_test.dart';
import 'package:mipointy/core/utils.dart';
import 'package:mipointy/models/distribution.dart';
import 'package:mipointy/models/enums.dart';
import 'package:mipointy/models/pointage.dart';
import 'package:mipointy/models/student.dart';
import 'package:mipointy/models/trip_day.dart';
import 'package:mipointy/models/travel_session.dart';
import 'package:mipointy/services/stats_service.dart';

import 'test_utils.dart';

void main() {
  group('StatsService', () {
    test('computes served/remaining/rate correctly', () async {
      final appDb = await openTestDb();
      final db = await appDb.database;

      final now = nowUtcIso();
      await db.insert(
          'sessions',
          TravelSession(
            id: 's1',
            token: 'T1',
            name: 'S',
            createdAt: now,
            updatedAt: now,
          ).toMap());
      await db.insert(
          'days',
          TripDay(
            id: 'd1',
            sessionId: 's1',
            label: 'J1',
            createdAt: now,
            updatedAt: now,
          ).toMap());
      await db.insert(
          'distributions',
          Distribution(
            id: 'dist1',
            sessionId: 's1',
            dayId: 'd1',
            name: 'Repas',
            status: DistributionStatus.ouverte,
            createdAt: now,
            updatedAt: now,
          ).toMap());

      final students = [
        Student(
          id: 'st1',
          sessionId: 's1',
          matricule: '001',
          fullName: 'A',
          qrToken: 'T1',
          createdAt: now,
          updatedAt: now,
        ),
        Student(
          id: 'st2',
          sessionId: 's1',
          matricule: '002',
          fullName: 'B',
          qrToken: 'T2',
          createdAt: now,
          updatedAt: now,
        ),
        Student(
          id: 'st3',
          sessionId: 's1',
          matricule: '003',
          fullName: 'C',
          qrToken: 'T3',
          createdAt: now,
          updatedAt: now,
        ),
        Student(
          id: 'st4',
          sessionId: 's1',
          matricule: '004',
          fullName: 'D',
          qrToken: 'T4',
          createdAt: now,
          updatedAt: now,
        ),
        Student(
          id: 'st5',
          sessionId: 's1',
          matricule: '005',
          fullName: 'E',
          qrToken: 'T5',
          createdAt: now,
          updatedAt: now,
        ),
      ];
      for (final s in students) {
        await db.insert('students', s.toMap());
      }

      // Insert 3 valid pointages
      for (final sid in ['st1', 'st2', 'st3']) {
        await db.insert(
            'pointages',
            Pointage(
              id: newId(),
              sessionId: 's1',
              studentId: sid,
              distributionId: 'dist1',
              deviceId: 'dev',
              recordedAtUtc: now,
              recordedAtLocal: now,
              createdAt: now,
              updatedAt: now,
            ).toMap());
      }

      final stats = await StatsService(appDb).forDistribution(
          's1', Distribution.fromMap((await db.query('distributions')).first));
      expect(stats.totalStudents, 5);
      expect(stats.served, 3);
      expect(stats.remaining, 2);
      expect(stats.ratePercent, 60);
      expect(stats.summary, '3 servis sur 5 — 60 % — 2 restants');
    });
  });
}
