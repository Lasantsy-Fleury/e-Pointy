import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../core/utils.dart';
import '../data/app_database.dart';
import '../data/audit_dao.dart';
import '../data/conflict_dao.dart';
import '../data/pointage_dao.dart';
import '../data/plan_dao.dart';
import '../data/session_dao.dart';
import '../data/student_dao.dart';
import '../models/enums.dart';
import '../models/travel_session.dart';
import 'file_output.dart';
import 'qr_service.dart';
import 'stats_service.dart';

enum ExportKind {
  etudiants('Liste des étudiants'),
  etudiantsAvecQr('Liste des étudiants avec QR'),
  recapDistributions('Récapitulatif par distribution'),
  detailPointages('Détail des pointages'),
  nonServis('Étudiants n’ayant pas reçu une distribution'),
  bilanGlobal('Bilan global du voyage'),
  anomalies('Anomalies et corrections');

  const ExportKind(this.label);
  final String label;
}

/// Exports `.xlsx` et `.csv` exploitables par l'équipe organisatrice.
/// Les matricules restent au format texte (zéros initiaux préservés).
class ExportService {
  ExportService(this._db)
      : _sessions = SessionDao(_db),
        _students = StudentDao(_db),
        _plan = PlanDao(_db),
        _pointages = PointageDao(_db),
        _conflicts = ConflictDao(_db),
        _audit = AuditDao(_db);

  final AppDatabase _db;
  final SessionDao _sessions;
  final StudentDao _students;
  final PlanDao _plan;
  final PointageDao _pointages;
  final ConflictDao _conflicts;
  final AuditDao _audit;

  static final DateFormat _date = DateFormat('dd/MM/yyyy');
  static final DateFormat _dateTime = DateFormat('dd/MM/yyyy HH:mm');

  /// Génère le fichier demandé et retourne son chemin.
  Future<String> export({
    required String sessionId,
    required ExportKind kind,
    bool asCsv = false,
    String? distributionId,
  }) async {
    final session = await _sessions.getById(sessionId);
    if (session == null) throw StateError('Session introuvable');
    final tables = await _buildTables(session, kind, distributionId);
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final baseName =
        '${sanitizeFileName(session.name)}_${sanitizeFileName(kind.label)}_$stamp';
    if (asCsv) {
      final file = await FileOutput.writeText(
          '$baseName.csv', _toCsv(tables));
      return file.path;
    }
    final file = await FileOutput.writeBytes('$baseName.xlsx', _toXlsx(tables));
    return file.path;
  }

  // -------------------------------------------------------------- contenu

  Future<List<_Table>> _buildTables(
    TravelSession session,
    ExportKind kind,
    String? distributionId,
  ) async {
    final students = await _students.getBySession(session.id);
    final days = await _plan.days(session.id);
    final distributions = await _plan.distributions(session.id);
    final pointages = await _pointages.forSession(session.id);
    final header = _sessionHeader(session);

    switch (kind) {
      case ExportKind.etudiants:
        return [
          _Table('${session.name} — ${kind.label}', header, [
            ['Matricule', 'Nom et Prénoms', 'Statut', 'Distributions reçues',
              'Créé le', 'Mis à jour le'],
            for (final s in students)
              [
                s.matricule,
                s.fullName,
                s.active ? 'Actif' : 'Désactivé',
                pointages
                    .where((p) => p.studentId == s.id && p.isValid)
                    .length
                    .toString(),
                _dateTime.format(
                    DateTime.tryParse(s.createdAt)?.toLocal() ?? DateTime.now()),
                _dateTime.format(
                    DateTime.tryParse(s.updatedAt)?.toLocal() ?? DateTime.now()),
              ],
          ]),
        ];

      case ExportKind.etudiantsAvecQr:
        return [
          _Table('${session.name} — ${kind.label}', header, [
            ['Matricule', 'Nom et Prénoms', 'Statut', 'QR Token', 'QR String'],
            for (final s in students)
              [
                s.matricule,
                s.fullName,
                s.active ? 'Actif' : 'Désactivé',
                s.qrToken,
                QrService.encodeForStudent(
                  sessionToken: session.token,
                  studentQrToken: s.qrToken,
                ),
              ],
          ]),
        ];

      case ExportKind.recapDistributions:
        final stats = StatsService(_db);
        final rows = <List<String>>[];
        for (final day in days) {
          final recap = await stats.dayRecap(session.id, day);
          for (final entry in recap) {
            final d = entry.key;
            final s = entry.value;
            rows.add([
              day.label,
              d.name,
              d.horaires,
              d.status.label,
              s.totalStudents.toString(),
              s.served.toString(),
              s.remaining.toString(),
              '${s.ratePercent} %',
              s.duplicates.toString(),
              s.manual.toString(),
              s.quantityTotal.toString(),
            ]);
          }
        }
        return [
          _Table('${session.name} — ${kind.label}', header, [
            ['Journée', 'Distribution', 'Horaires', 'Statut', 'Inscrits',
              'Servis', 'Restants', 'Taux', 'Doublons', 'Manuels',
              'Quantité totale'],
            ...rows,
          ]),
        ];

      case ExportKind.detailPointages:
        final studentsById = {for (final s in students) s.id: s};
        final distsById = {for (final d in distributions) d.id: d};
        final daysById = {for (final d in days) d.id: d};
        return [
          _Table('${session.name} — ${kind.label}', header, [
            ['Matricule', 'Nom', 'Journée', 'Distribution', 'Statut pointage',
              'Mode', 'Quantité', 'Date-heure (locale)', 'Date-heure (UTC)',
              'Appareil', 'Opérateur', 'Motif de correction'],
            for (final p in pointages)
              [
                studentsById[p.studentId]?.matricule ?? '—',
                studentsById[p.studentId]?.fullName ?? '—',
                daysById[distsById[p.distributionId]?.dayId]?.label ?? '—',
                distsById[p.distributionId]?.name ?? '—',
                p.status.label,
                p.mode.label,
                p.quantity.toString(),
                _dateTime.format(
                    DateTime.tryParse(p.recordedAtLocal)?.toLocal() ?? DateTime.now()),
                _dateTime.format(
                    DateTime.tryParse(p.recordedAtUtc)?.toUtc() ?? DateTime.now()),
                p.deviceName ?? p.deviceId,
                p.operator ?? '—',
                p.correctionReason ?? '',
              ],
          ]),
        ];

      case ExportKind.nonServis:
        final targets = distributionId != null
            ? distributions.where((d) => d.id == distributionId).toList()
            : distributions
                .where((d) => d.status == DistributionStatus.cloturee)
                .toList();
        if (targets.isEmpty) {
          throw StateError(
              'Aucune distribution concernée. Clôturez une distribution ou '
              'choisissez-en une pour exporter les étudiants non servis.');
        }
        final tables = <_Table>[];
        for (final d in targets) {
          final servedIds = await _pointages.servedStudentIds(d.id);
          final missing =
              students.where((s) => !servedIds.contains(s.id)).toList();
          tables.add(_Table(
            '${session.name} — non servis — ${d.name}',
            header,
            [
              ['Matricule', 'Nom et Prénoms', 'Distribution', 'Statut étudiant'],
              for (final s in missing)
                [s.matricule, s.fullName, d.name, s.active ? 'Actif' : 'Désactivé'],
            ],
          ));
        }
        return tables;

      case ExportKind.bilanGlobal:
        final stats = StatsService(_db);
        final sessionStats = await stats.sessionStats(session.id);
        final rows = <List<String>>[];
        for (final day in days) {
          final recap = await stats.dayRecap(session.id, day);
          var served = 0;
          var total = 0;
          for (final e in recap) {
            served += e.value.served;
            total += e.value.totalStudents;
          }
          rows.add([
            day.label,
            day.dayDate != null ? _date.format(day.dayDate!) : '',
            recap.length.toString(),
            served.toString(),
            total.toString(),
            total == 0 ? '0 %' : '${(served / total * 100).round()} %',
          ]);
        }
        return [
          _Table('${session.name} — ${kind.label}', header, [
            ['Indicateur', 'Valeur'],
            ['Session', session.name],
            ['Établissement / groupe', session.school ?? '—'],
            ['Responsable', session.responsible ?? '—'],
            ['Période',
              '${session.startDate != null ? _date.format(session.startDate!) : '—'}'
                  ' au '
                  '${session.endDate != null ? _date.format(session.endDate!) : '—'}'],
            ['Statut de la session', session.status.label],
            ['Étudiants inscrits', sessionStats.totalStudents.toString()],
            ['Étudiants actifs', sessionStats.activeStudents.toString()],
            ['Distributions', sessionStats.totalDistributions.toString()],
            ['Distributions clôturées',
              sessionStats.distributionsCloses.toString()],
            ['Pointages validés', sessionStats.totalPointages.toString()],
            ['Pointages manuels', sessionStats.totalManual.toString()],
            ['Doublons à vérifier', sessionStats.totalDuplicates.toString()],
            ['Taux de couverture moyen',
              '${sessionStats.averageRatePercent} %'],
            [],
            ['Journée', 'Date', 'Distributions', 'Servis', 'Inscrits', 'Taux'],
            ...rows,
          ]),
        ];

      case ExportKind.anomalies:
        final conflicts = await _conflicts.forSession(session.id);
        final studentsById = {for (final s in students) s.id: s};
        final distsById = {for (final d in distributions) d.id: d};
        final audit = await _audit.forSession(session.id, limit: 1000);
        final manualAndCancelled = pointages
            .where((p) => p.mode == ScanMode.manuel || !p.isValid)
            .toList();
        return [
          _Table('${session.name} — doublons et conflits', header, [
            ['Matricule', 'Nom', 'Distribution', 'Type', 'Résolu',
              'Décision', 'Détecté le', 'Note'],
            for (final c in conflicts)
              [
                studentsById[c.studentId]?.matricule ?? '—',
                studentsById[c.studentId]?.fullName ?? '—',
                distsById[c.distributionId]?.name ?? '—',
                c.type,
                c.resolved ? 'Oui' : 'Non',
                c.resolution ?? '',
                _dateTime.format(
                    DateTime.tryParse(c.detectedAt)?.toLocal() ?? DateTime.now()),
                c.note ?? '',
              ],
          ]),
          _Table('${session.name} — pointages manuels et annulés', header, [
            ['Matricule', 'Nom', 'Distribution', 'Statut', 'Mode', 'Date-heure',
              'Appareil', 'Opérateur', 'Motif'],
            for (final p in manualAndCancelled)
              [
                studentsById[p.studentId]?.matricule ?? '—',
                studentsById[p.studentId]?.fullName ?? '—',
                distsById[p.distributionId]?.name ?? '—',
                p.status.label,
                p.mode.label,
                _dateTime.format(
                    DateTime.tryParse(p.recordedAtLocal)?.toLocal() ?? DateTime.now()),
                p.deviceName ?? p.deviceId,
                p.operator ?? '—',
                p.correctionReason ?? '',
              ],
          ]),
          _Table('${session.name} — journal des modifications', header, [
            ['Date-heure', 'Auteur', 'Action', 'Détails'],
            for (final a in audit)
              [
                _dateTime.format(
                    DateTime.tryParse(a.at)?.toLocal() ?? DateTime.now()),
                a.actor,
                a.action,
                a.details,
              ],
          ]),
        ];
    }
  }

  List<List<String>> _sessionHeader(TravelSession session) => [
        ['Session', session.name],
        ['Généré le', _dateTime.format(DateTime.now())],
        ['Distributions concernées', 'toutes les distributions de la session'],
      ];

  // -------------------------------------------------------------- formats

  List<int> _toXlsx(List<_Table> tables) {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    final usedNames = <String>{};
    for (final table in tables) {
      var name = table.name;
      if (name.length > 31) name = name.substring(0, 31);
      var candidate = name;
      var suffix = 2;
      while (usedNames.contains(candidate.toLowerCase())) {
        final tail = '_$suffix';
        candidate = name.length + tail.length > 31
            ? '${name.substring(0, 31 - tail.length)}$tail'
            : '$name$tail';
        suffix++;
      }
      usedNames.add(candidate.toLowerCase());
      final sheet = excel[candidate];
      for (final line in table.header) {
        sheet.appendRow([
          TextCellValue(line[0]),
          TextCellValue(line[1]),
        ]);
      }
      sheet.appendRow([TextCellValue('')]);
      for (final row in table.rows) {
        sheet.appendRow([
          for (final cell in row) TextCellValue(cell),
        ]);
      }
    }
    if (defaultSheet != null && tables.isNotEmpty) {
      excel.delete(defaultSheet);
    }
    final bytes = excel.encode();
    return bytes ?? <int>[];
  }

  String _toCsv(List<_Table> tables) {
    final buffer = StringBuffer();
    for (final table in tables) {
      buffer.writeln('# ${table.name}');
      for (final line in table.header) {
        buffer.writeln('# ${line[0]} : ${line[1]}');
      }
      // CsvEncoder(addBom: true) ajoute le BOM UTF-8 (accents reconnus par Excel).
      final csv = CsvEncoder(addBom: true).convert(table.rows);
      buffer.writeln(csv);
      buffer.writeln();
    }
    return buffer.toString();
  }

  /// Écrit un exemple de fichier Excel conforme au format d'import attendu.
  Future<String> writeSampleImportFile() async {
    final excel = Excel.createExcel();
    final sheet = excel['Étudiants'];
    final defaultSheet = excel.getDefaultSheet();
    sheet.appendRow([
      TextCellValue('Matricule'),
      TextCellValue('Nom et Prénoms'),
    ]);
    final samples = <List<String>>[
      ['2024001', 'RAKOTO Jean'],
      ['00123', 'ANDRIANINA Marie Claire'],
      ['2024002', 'RASOAMANANA Hery'],
      ['2024003', 'RANDRIANASOLO Fanja'],
      ['2024004', 'RAZAFINDRABE Tiana'],
    ];
    for (final s in samples) {
      sheet.appendRow([TextCellValue(s[0]), TextCellValue(s[1])]);
    }
    if (defaultSheet != null) excel.delete(defaultSheet);
    final bytes = excel.encode() ?? <int>[];
    final file = await FileOutput.writeBytes(
        'exemple_etudiants_epointy.xlsx', bytes);
    return file.path;
  }
}

class _Table {
  _Table(this.name, this.header, this.rows);
  final String name;
  final List<List<String>> header;
  final List<List<String>> rows;
}

/// Sérialise une liste de listes en CSV (utilisé aussi par les tests).
String listToCsv(List<List<Object?>> rows) => CsvEncoder().convert(rows);

/// Encode une chaîne en UTF-8 (exposé pour les tests).
List<int> utf8Bytes(String input) => utf8.encode(input);
