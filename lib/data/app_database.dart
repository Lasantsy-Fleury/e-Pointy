import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../core/constants.dart';

/// Point d'accès à la base de données locale SQLite.
///
/// Choix : SQLite via sqflite, fiable, persistant et sans connexion.
/// Pas de clé étrangonne en base : l'intégrité est gérée au niveau applicatif
/// afin de garder les fusions entre appareils indépendantes de l'ordre
/// d'insertion.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;
  Database? _injected;

  /// Utilisé par les tests : base injectée (sqflite_common_ffi).
  factory AppDatabase.test(Database db) {
    return AppDatabase._().._injected = db;
  }

  Future<Database> get database async {
    final injected = _injected;
    if (injected != null) return injected;
    final existing = _db;
    if (existing != null) return existing;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, AppConstants.dbFileName);
    _db = await openDatabaseInstance(path);
    return _db!;
  }

  /// Ouvre (ou crée) une base au chemin donné. Exposé pour les tests.
  static Future<Database> openDatabaseInstance(String path) {
    return openDatabase(
      path,
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA journal_mode = WAL'),
      onCreate: (db, version) => createSchema(db),
    );
  }

  /// Crée l'ensemble du schéma.
  static Future<void> createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE sessions (
        id TEXT PRIMARY KEY,
        token TEXT NOT NULL,
        name TEXT NOT NULL,
        school TEXT,
        start_date TEXT,
        end_date TEXT,
        responsible TEXT,
        notes TEXT,
        status TEXT NOT NULL DEFAULT 'preparation',
        config_version INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE students (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        matricule TEXT NOT NULL,
        full_name TEXT NOT NULL,
        qr_token TEXT NOT NULL,
        active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE UNIQUE INDEX idx_students_matricule ON students(session_id, matricule)');
    await db.execute(
        'CREATE UNIQUE INDEX idx_students_qr ON students(session_id, qr_token)');
    await db.execute('CREATE INDEX idx_students_session ON students(session_id)');

    await db.execute('''
      CREATE TABLE item_types (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        name TEXT NOT NULL,
        category TEXT,
        unit TEXT,
        description TEXT,
        active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE days (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        label TEXT NOT NULL,
        day_date TEXT,
        position INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE distributions (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        day_id TEXT NOT NULL,
        item_type_id TEXT,
        name TEXT NOT NULL,
        start_time TEXT,
        end_time TEXT,
        status TEXT NOT NULL DEFAULT 'a_venir',
        allow_multiple INTEGER NOT NULL DEFAULT 0,
        max_passages INTEGER NOT NULL DEFAULT 1,
        track_quantity INTEGER NOT NULL DEFAULT 0,
        instructions TEXT,
        position INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_distributions_day ON distributions(day_id)');

    await db.execute('''
      CREATE TABLE day_templates (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        name TEXT NOT NULL,
        items_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE pointages (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        student_id TEXT NOT NULL,
        distribution_id TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'valide',
        mode TEXT NOT NULL DEFAULT 'qr',
        device_id TEXT NOT NULL,
        device_name TEXT,
        operator TEXT,
        recorded_at_utc TEXT NOT NULL,
        recorded_at_local TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        correction_of TEXT,
        correction_reason TEXT,
        synced_out INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    // Un seul pointage validé par étudiant et par distribution.
    await db.execute('''
      CREATE UNIQUE INDEX idx_pointages_unique_valide
      ON pointages(distribution_id, student_id) WHERE status = 'valide'
    ''');
    await db.execute(
        'CREATE INDEX idx_pointages_session ON pointages(session_id)');
    await db.execute(
        'CREATE INDEX idx_pointages_student ON pointages(student_id)');
    await db.execute(
        'CREATE INDEX idx_pointages_distribution ON pointages(distribution_id)');

    await db.execute('''
      CREATE TABLE conflicts (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        distribution_id TEXT NOT NULL,
        student_id TEXT NOT NULL,
        kept_pointage_id TEXT NOT NULL,
        conflicting_pointage_id TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'doublon_appareils',
        detected_at TEXT NOT NULL,
        resolved INTEGER NOT NULL DEFAULT 0,
        resolution TEXT,
        resolved_at TEXT,
        note TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE audit_log (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        at TEXT NOT NULL,
        actor TEXT NOT NULL,
        action TEXT NOT NULL,
        details TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_audit_session ON audit_log(session_id)');
  }

  /// Réinitialise complètement la base (tests uniquement).
  Future<void> reset() async {
    final db = await database;
    await db.close();
    _db = null;
    _injected = null;
  }
}
