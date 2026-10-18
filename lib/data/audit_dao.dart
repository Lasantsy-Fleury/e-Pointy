import 'package:sqflite/sqflite.dart';

import 'app_database.dart';
import '../core/utils.dart';
import '../models/audit_entry.dart';

/// Journal des modifications importantes.
class AuditDao {
  AuditDao(this._db);
  final AppDatabase _db;

  Future<void> log({
    required String sessionId,
    required String actor,
    required String action,
    required String details,
  }) async {
    final db = await _db.database;
    await db.insert('audit_log', {
      'id': newId(),
      'session_id': sessionId,
      'at': DateTime.now().toUtc().toIso8601String(),
      'actor': actor,
      'action': action,
      'details': details,
    });
  }

  Future<List<AuditEntry>> forSession(String sessionId, {int limit = 500}) async {
    final db = await _db.database;
    final rows = await db.query('audit_log',
        where: 'session_id = ?',
        whereArgs: [sessionId],
        orderBy: 'at DESC',
        limit: limit);
    return rows.map(AuditEntry.fromMap).toList();
  }

  Future<int> countForSession(String sessionId) async {
    final db = await _db.database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM audit_log WHERE session_id = ?',
        [sessionId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
