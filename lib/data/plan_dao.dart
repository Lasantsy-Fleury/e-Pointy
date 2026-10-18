import 'app_database.dart';
import '../models/distribution.dart';
import '../models/day_template.dart';
import '../models/item_type.dart';
import '../models/trip_day.dart';

/// Accès à la configuration du plan : types d'éléments, journées,
/// distributions et modèles de journée.
class PlanDao {
  PlanDao(this._db);
  final AppDatabase _db;

  // ---------- Types d'éléments ----------

  Future<List<ItemType>> itemTypes(String sessionId) async {
    final db = await _db.database;
    final rows = await db.query('item_types',
        where: 'session_id = ?', whereArgs: [sessionId], orderBy: 'name');
    return rows.map(ItemType.fromMap).toList();
  }

  Future<void> insertItemType(ItemType t) async {
    final db = await _db.database;
    await db.insert('item_types', t.toMap());
  }

  Future<ItemType?> itemTypeById(String id) async {
    final db = await _db.database;
    final rows = await db.query('item_types',
        where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : ItemType.fromMap(rows.first);
  }

  Future<void> updateItemType(ItemType t) async {
    final db = await _db.database;
    await db.update('item_types', t.toMap(),
        where: 'id = ?', whereArgs: [t.id]);
  }

  Future<void> deleteItemType(String id) async {
    final db = await _db.database;
    await db.delete('item_types', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Journées ----------

  Future<List<TripDay>> days(String sessionId) async {
    final db = await _db.database;
    final rows = await db.query('days',
        where: 'session_id = ?',
        whereArgs: [sessionId],
        orderBy: 'position, label');
    return rows.map(TripDay.fromMap).toList();
  }

  Future<TripDay?> dayById(String id) async {
    final db = await _db.database;
    final rows =
        await db.query('days', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : TripDay.fromMap(rows.first);
  }

  Future<void> insertDay(TripDay d) async {
    final db = await _db.database;
    await db.insert('days', d.toMap());
  }

  Future<void> updateDay(TripDay d) async {
    final db = await _db.database;
    await db.update('days', d.toMap(), where: 'id = ?', whereArgs: [d.id]);
  }

  Future<void> deleteDay(String id) async {
    final db = await _db.database;
    await db.delete('days', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Distributions ----------

  Future<List<Distribution>> distributions(String sessionId) async {
    final db = await _db.database;
    final rows = await db.query('distributions',
        where: 'session_id = ?',
        whereArgs: [sessionId],
        orderBy: 'position, start_time, name');
    return rows.map(Distribution.fromMap).toList();
  }

  Future<Distribution?> distributionById(String id) async {
    final db = await _db.database;
    final rows = await db.query('distributions',
        where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Distribution.fromMap(rows.first);
  }

  Future<void> insertDistribution(Distribution d) async {
    final db = await _db.database;
    await db.insert('distributions', d.toMap());
  }

  Future<void> updateDistribution(Distribution d) async {
    final db = await _db.database;
    await db.update('distributions', d.toMap(),
        where: 'id = ?', whereArgs: [d.id]);
  }

  Future<void> deleteDistribution(String id) async {
    final db = await _db.database;
    await db.delete('distributions', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Modèles de journée ----------

  Future<List<DayTemplate>> dayTemplates(String sessionId) async {
    final db = await _db.database;
    final rows = await db.query('day_templates',
        where: 'session_id = ?', whereArgs: [sessionId], orderBy: 'name');
    return rows.map(DayTemplate.fromMap).toList();
  }

  Future<void> insertDayTemplate(DayTemplate t) async {
    final db = await _db.database;
    await db.insert('day_templates', t.toMap());
  }

  Future<void> deleteDayTemplate(String id) async {
    final db = await _db.database;
    await db.delete('day_templates', where: 'id = ?', whereArgs: [id]);
  }

  /// Distribution la plus récemment mise à jour pour une journée
  /// (utilisée pour proposer la distribution active).
  Future<Distribution?> lastUpdatedOf(String sessionId) async {
    final db = await _db.database;
    final rows = await db.query('distributions',
        where: 'session_id = ?',
        whereArgs: [sessionId],
        orderBy: 'updated_at DESC',
        limit: 1);
    return rows.isEmpty ? null : Distribution.fromMap(rows.first);
  }
}
