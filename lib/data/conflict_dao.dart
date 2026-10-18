import 'package:sqflite/sqflite.dart';

import 'app_database.dart';
import '../core/utils.dart';
import '../models/conflict.dart';

/// Accès aux conflits de fusion.
class ConflictDao {
  ConflictDao(this._db);
  final AppDatabase _db;

  Future<List<Conflict>> forSession(String sessionId,
      {bool unresolvedOnly = false}) async {
    final db = await _db.database;
    final rows = await db.query(
      'conflicts',
      where: unresolvedOnly
          ? 'session_id = ? AND resolved = 0'
          : 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'detected_at DESC',
    );
    return rows.map(Conflict.fromMap).toList();
  }

  Future<List<Conflict>> unresolvedForSession(String sessionId) =>
      forSession(sessionId, unresolvedOnly: true);

  Future<int> countUnresolved(String sessionId) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM conflicts WHERE session_id = ? AND resolved = 0',
      [sessionId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> countUnresolvedForDistribution(String distributionId) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM conflicts WHERE distribution_id = ? '
      'AND resolved = 0',
      [distributionId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<Conflict?> getById(String id) async {
    final db = await _db.database;
    final rows =
        await db.query('conflicts', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Conflict.fromMap(rows.first);
  }

  Future<bool> existsById(String id) async {
    final db = await _db.database;
    final rows =
        await db.query('conflicts', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isNotEmpty;
  }

  Future<void> insert(Conflict c) async {
    final db = await _db.database;
    await db.insert('conflicts', c.toMap());
  }

  /// Marque un conflit comme résolu avec sa décision et son auteur.
  Future<void> resolve(String id, String resolution, String actor,
      {String? note}) async {
    final db = await _db.database;
    await db.update(
      'conflicts',
      {
        'resolved': 1,
        'resolution': resolution,
        'resolved_at': DateTime.now().toUtc().toIso8601String(),
        'note': note,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    final c = await getById(id);
    if (c != null) {
      await db.insert('audit_log', {
        'id': newId(),
        'session_id': c.sessionId,
        'at': DateTime.now().toUtc().toIso8601String(),
        'actor': actor,
        'action': 'resolution_conflit',
        'details': 'Conflit $id résolu : $resolution${note != null ? ' — $note' : ''}',
      });
    }
  }
}
