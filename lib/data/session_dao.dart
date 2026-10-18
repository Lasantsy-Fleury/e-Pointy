import 'app_database.dart';
import '../models/enums.dart';
import '../models/travel_session.dart';

/// Accès aux sessions de voyage.
class SessionDao {
  SessionDao(this._db);
  final AppDatabase _db;

  Future<List<TravelSession>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('sessions', orderBy: 'updated_at DESC');
    return rows.map(TravelSession.fromMap).toList();
  }

  Future<TravelSession?> getById(String id) async {
    final db = await _db.database;
    final rows =
        await db.query('sessions', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : TravelSession.fromMap(rows.first);
  }

  Future<TravelSession?> getByToken(String token) async {
    final db = await _db.database;
    final rows = await db.query('sessions',
        where: 'token = ?', whereArgs: [token], limit: 1);
    return rows.isEmpty ? null : TravelSession.fromMap(rows.first);
  }

  Future<void> insert(TravelSession session) async {
    final db = await _db.database;
    await db.insert('sessions', session.toMap());
  }

  Future<void> update(TravelSession session) async {
    final db = await _db.database;
    await db.update('sessions', session.toMap(),
        where: 'id = ?', whereArgs: [session.id]);
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('sessions', where: 'id = ?', whereArgs: [id]);
  }

  /// Supprime toutes les données d'une session (restauration « remplacer »).
  Future<void> deleteAllData(String sessionId) async {
    final db = await _db.database;
    final batch = db.batch();
    batch.delete('pointages', where: 'session_id = ?', whereArgs: [sessionId]);
    batch.delete('conflicts', where: 'session_id = ?', whereArgs: [sessionId]);
    batch.delete('audit_log', where: 'session_id = ?', whereArgs: [sessionId]);
    batch.delete('distributions',
        where: 'session_id = ?', whereArgs: [sessionId]);
    batch.delete('days', where: 'session_id = ?', whereArgs: [sessionId]);
    batch.delete('item_types', where: 'session_id = ?', whereArgs: [sessionId]);
    batch.delete('day_templates',
        where: 'session_id = ?', whereArgs: [sessionId]);
    batch.delete('students', where: 'session_id = ?', whereArgs: [sessionId]);
    batch.delete('sessions', where: 'id = ?', whereArgs: [sessionId]);
    await batch.commit(noResult: true);
  }

  /// Change le statut et trace l'horodatage de mise à jour.
  Future<void> setStatus(String id, SessionStatus status, String updatedAt) async {
    final db = await _db.database;
    await db.update('sessions', {'status': status.code, 'updated_at': updatedAt},
        where: 'id = ?', whereArgs: [id]);
  }
}
