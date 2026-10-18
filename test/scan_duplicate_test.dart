import 'package:flutter_test/flutter_test.dart';
import 'package:mipointy/core/utils.dart';
import 'package:mipointy/models/distribution.dart';
import 'package:mipointy/models/enums.dart';
import 'package:mipointy/models/student.dart';
import 'package:mipointy/models/trip_day.dart';
import 'package:mipointy/models/travel_session.dart';
import 'package:mipointy/services/scan_service.dart';

import 'test_utils.dart';

void main() {
  group('ScanService duplicate prevention', () {
    test('prevents duplicate valid pointage with unique index', () async {
      final appDb = await openTestDb();
      final db = await appDb.database;

      final now = nowUtcIso();
      final session = TravelSession(
        id: 's1',
        token: newToken(8),
        name: 'Session',
        createdAt: now,
        updatedAt: now,
      );
      await db.insert('sessions', session.toMap());

      final day = TripDay(
        id: 'd1',
        sessionId: 's1',
        label: 'Jour 1',
        createdAt: now,
        updatedAt: now,
      );
      await db.insert('days', day.toMap());

      final dist = Distribution(
        id: 'dist1',
        sessionId: 's1',
        dayId: 'd1',
        name: 'Repas',
        status: DistributionStatus.ouverte,
        createdAt: now,
        updatedAt: now,
      );
      await db.insert('distributions', dist.toMap());

      final student = Student(
        id: 'st1',
        sessionId: 's1',
        matricule: '001',
        fullName: 'Jean',
        qrToken: 'T001',
        createdAt: now,
        updatedAt: now,
      );
      await db.insert('students', student.toMap());

      final scan = ScanService(appDb);
      final ctx = const OperatorContext(
        deviceId: 'dev1',
        deviceName: 'Appareil',
        operator: 'Op',
      );

      final r1 = await scan.recordForStudent(
        student: student,
        distribution: dist,
        mode: ScanMode.qr,
        ctx: ctx,
      );
      expect(r1.isSuccess, true);

      final r2 = await scan.recordForStudent(
        student: student,
        distribution: dist,
        mode: ScanMode.qr,
        ctx: ctx,
      );
      expect(r2.isSuccess, false);
      expect(r2.outcome, ScanOutcome.dejaServi);

      // Served count should be 1
      final pointages = await db.query('pointages');
      expect(pointages.length, 1);
    });

    test('allows multiple passages when allowMultiple and under max', () async {
      final appDb = await openTestDb();
      final db = await appDb.database;

      final now = nowUtcIso();
      await db.insert(
          'sessions',
          TravelSession(
            id: 's2',
            token: 'T2',
            name: 'S2',
            createdAt: now,
            updatedAt: now,
          ).toMap());
      await db.insert(
          'days',
          TripDay(
            id: 'd2',
            sessionId: 's2',
            label: 'J1',
            createdAt: now,
            updatedAt: now,
          ).toMap());
      await db.insert(
          'distributions',
          Distribution(
            id: 'dist2',
            sessionId: 's2',
            dayId: 'd2',
            name: 'Eau',
            status: DistributionStatus.ouverte,
            allowMultiple: true,
            maxPassages: 2,
            createdAt: now,
            updatedAt: now,
          ).toMap());
      await db.insert(
          'students',
          Student(
            id: 'st2',
            sessionId: 's2',
            matricule: '002',
            fullName: 'Marie',
            qrToken: 'T002',
            createdAt: now,
            updatedAt: now,
          ).toMap());

      final scan = ScanService(appDb);
      final ctx = const OperatorContext(
        deviceId: 'dev',
        deviceName: 'D',
        operator: 'O',
      );

      final r1 = await scan.recordForStudent(
        student: (await db.query('students')).map(Student.fromMap).first,
        distribution:
            (await db.query('distributions')).map(Distribution.fromMap).first,
        mode: ScanMode.qr,
        ctx: ctx,
      );
      expect(r1.isSuccess, true);

      final r2 = await scan.recordForStudent(
        student: (await db.query('students')).map(Student.fromMap).first,
        distribution:
            (await db.query('distributions')).map(Distribution.fromMap).first,
        mode: ScanMode.qr,
        ctx: ctx,
      );
      expect(r2.isSuccess, true);
      expect(r2.quantity, 2);

      final r3 = await scan.recordForStudent(
        student: (await db.query('students')).map(Student.fromMap).first,
        distribution:
            (await db.query('distributions')).map(Distribution.fromMap).first,
        mode: ScanMode.qr,
        ctx: ctx,
      );
      expect(r3.isSuccess, false);
    });
  });
}
