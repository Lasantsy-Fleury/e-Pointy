import 'app_database.dart';
import '../core/utils.dart';
import '../models/student.dart';

/// Accès aux étudiants.
class StudentDao {
  StudentDao(this._db);
  final AppDatabase _db;

  Future<List<Student>> getBySession(String sessionId,
      {bool includeInactive = true}) async {
    final db = await _db.database;
    final rows = await db.query(
      'students',
      where: includeInactive ? 'session_id = ?' : 'session_id = ? AND active = 1',
      whereArgs: [sessionId],
      orderBy: 'full_name COLLATE NOCASE',
    );
    return rows.map(Student.fromMap).toList();
  }

  Future<Student?> getById(String id) async {
    final db = await _db.database;
    final rows =
        await db.query('students', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Student.fromMap(rows.first);
  }

  Future<Student?> getByMatricule(String sessionId, String matricule) async {
    final db = await _db.database;
    final rows = await db.query('students',
        where: 'session_id = ? AND matricule = ?',
        whereArgs: [sessionId, matricule],
        limit: 1);
    return rows.isEmpty ? null : Student.fromMap(rows.first);
  }

  Future<Student?> getByQrToken(String sessionId, String qrToken) async {
    final db = await _db.database;
    final rows = await db.query('students',
        where: 'session_id = ? AND qr_token = ?',
        whereArgs: [sessionId, qrToken],
        limit: 1);
    return rows.isEmpty ? null : Student.fromMap(rows.first);
  }

  /// Recherche par matricule (préfixe) ou par nom (insensible casse/accents).
  /// La partie « nom » est filtrée en mémoire car SQLite ne normalise pas
  /// les diacritiques : reste réactive pour des centaines/milliers d'étudiants.
  Future<List<Student>> search(String sessionId, String query,
      {bool includeInactive = true}) async {
    final all = await getBySession(sessionId,
        includeInactive: includeInactive);
    final q = searchKey(query);
    if (q.isEmpty) return all;
    return all
        .where((s) =>
            s.matricule.toLowerCase().contains(q) ||
            searchKey(s.fullName).contains(q))
        .toList();
  }

  Future<void> insert(Student student) async {
    final db = await _db.database;
    await db.insert('students', student.toMap());
  }

  Future<void> insertBatch(List<Student> students) async {
    final db = await _db.database;
    final batch = db.batch();
    for (final s in students) {
      batch.insert('students', s.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<void> update(Student student) async {
    final db = await _db.database;
    await db.update('students', student.toMap(),
        where: 'id = ?', whereArgs: [student.id]);
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('students', where: 'id = ?', whereArgs: [id]);
  }
}
