import 'package:sqflite/sqflite.dart';

import '../core/utils.dart';
import 'app_database.dart';
import '../models/enums.dart';
import '../models/pointage.dart';

/// Accès aux pointages (journal d'audit des réceptions).
class PointageDao {
  PointageDao(this._db);
  final AppDatabase _db;

  Future<Pointage?> getById(String id) async {
    final db = await _db.database;
    final rows =
        await db.query('pointages', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Pointage.fromMap(rows.first);
  }

  /// Pointage validé pour un couple étudiant / distribution.
  Future<Pointage?> getValide(String studentId, String distributionId) async {
    final db = await _db.database;
    final rows = await db.query('pointages',
        where: 'student_id = ? AND distribution_id = ? AND status = ?',
        whereArgs: [studentId, distributionId, PointageStatus.valide.code],
        limit: 1);
    return rows.isEmpty ? null : Pointage.fromMap(rows.first);
  }

  Future<List<Pointage>> forDistribution(String distributionId) async {
    final db = await _db.database;
    final rows = await db.query('pointages',
        where: 'distribution_id = ?',
        whereArgs: [distributionId],
        orderBy: 'recorded_at_utc');
    return rows.map(Pointage.fromMap).toList();
  }

  Future<List<Pointage>> forStudent(String studentId) async {
    final db = await _db.database;
    final rows = await db.query('pointages',
        where: 'student_id = ?',
        whereArgs: [studentId],
        orderBy: 'recorded_at_utc DESC');
    return rows.map(Pointage.fromMap).toList();
  }

  Future<List<Pointage>> forSession(String sessionId) async {
    final db = await _db.database;
    final rows = await db.query('pointages',
        where: 'session_id = ?', whereArgs: [sessionId]);
    return rows.map(Pointage.fromMap).toList();
  }

  /// IDs des étudiants uniques réellement servis pour une distribution.
  Future<Set<String>> servedStudentIds(String distributionId) async {
    final db = await _db.database;
    final rows = await db.query('pointages',
        columns: ['student_id'],
        where: 'distribution_id = ? AND status = ?',
        whereArgs: [distributionId, PointageStatus.valide.code]);
    return rows.map((r) => r['student_id']! as String).toSet();
  }

  /// Nombre de pointages validés saisis manuellement.
  Future<int> manualValidCount(String distributionId) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM pointages WHERE distribution_id = ? '
      "AND status = 'valide' AND mode = 'manuel'",
      [distributionId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// IDs des étudiants ayant au moins un pointage (toutes distributions).
  Future<Set<String>> studentIdsWithPointages(String sessionId) async {
    final db = await _db.database;
    final rows = await db.query('pointages',
        columns: ['student_id'],
        distinct: true,
        where: 'session_id = ?',
        whereArgs: [sessionId]);
    return rows.map((r) => r['student_id']! as String).toSet();
  }

  Future<int> countValidForDistribution(String distributionId) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM pointages WHERE distribution_id = ? '
      "AND status = 'valide'",
      [distributionId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Pointages créés sur cet appareil et jamais encore inclus dans un transfert.
  Future<int> pendingOutCount(String sessionId, String deviceId) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM pointages WHERE session_id = ? '
      'AND device_id = ? AND synced_out = 0',
      [sessionId, deviceId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Marque tous les pointages de la session comme transmis (après envoi).
  Future<void> markSyncedOut(String sessionId) async {
    final db = await _db.database;
    await db.update('pointages', {'synced_out': 1},
        where: 'session_id = ?', whereArgs: [sessionId]);
  }

  Future<void> insert(Pointage p) async {
    final db = await _db.database;
    await db.insert('pointages', p.toMap());
  }

  Future<void> update(Pointage p) async {
    final db = await _db.database;
    await db.update('pointages', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
  }

  /// Annule un pointage en conservant la trace (motif obligatoire).
  /// L'événement initial n'est jamais supprimé : seule la trace d'annulation
  /// et son motif sont ajoutés, et l'auteur est écrit dans le journal d'audit.
  Future<void> cancel({
    required String id,
    required String sessionId,
    required String reason,
    required String actor,
  }) async {
    final db = await _db.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'pointages',
      {
        'status': PointageStatus.annule.code,
        'correction_reason': reason,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await db.insert('audit_log', {
      'id': newId(),
      'session_id': sessionId,
      'at': now,
      'actor': actor,
      'action': 'annulation_pointage',
      'details': 'Pointage $id annulé : $reason',
    });
  }
}
