// Générateur d'exemples livrés avec le projet.
//
// Usage (depuis la racine du projet) :
//   dart run tool/generate_samples.dart
//
// Produit :
//   samples/exemple_etudiants_epointy.xlsx  — fichier d'import conforme
//   samples/session_exemple.epointy         — session fictive à recevoir
//                                              dans l'application (transfert)
//
// Ce script est purement Dart : il n'ouvre aucune base et n'utilise aucun
// plugin Flutter. Il réutilise les modèles de l'application pour garantir que
// les données produites correspondent exactement au format attendu.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:excel/excel.dart';
import 'package:mipointy/core/constants.dart';
import 'package:mipointy/models/distribution.dart';
import 'package:mipointy/models/enums.dart';
import 'package:mipointy/models/item_type.dart';
import 'package:mipointy/models/pointage.dart';
import 'package:mipointy/models/student.dart';
import 'package:mipointy/models/travel_session.dart';
import 'package:mipointy/models/trip_day.dart';

void main() {
  final outDir = Directory('samples')..createSync(recursive: true);
  _writeStudentsExcel(File('${outDir.path}/exemple_etudiants_epointy.xlsx'));
  _writeSessionBundle(File('${outDir.path}/session_exemple.epointy'));
  stdout.writeln('Exemples écrits dans ${outDir.path}');
}

// ----------------------------------------------------------------- Excel

void _writeStudentsExcel(File file) {
  final excel = Excel.createExcel();
  final sheet = excel['Étudiants'];
  final defaultSheet = excel.getDefaultSheet();
  sheet.appendRow([
    TextCellValue('Matricule'),
    TextCellValue('Nom et Prénoms'),
  ]);
  for (final row in _studentsSeed) {
    sheet.appendRow([TextCellValue(row.$1), TextCellValue(row.$2)]);
  }
  if (defaultSheet != null) excel.delete(defaultSheet);
  file.writeAsBytesSync(excel.encode() ?? <int>[]);
  stdout.writeln('  - ${file.path}');
}

/// (matricule, nom) — les matricules courts conservent leurs zéros initiaux.
const _studentsSeed = <(String, String)>[
  ('2024001', 'RAKOTO Jean'),
  ('00123', 'ANDRIANINA Marie Claire'),
  ('2024002', 'RASOAMANANA Hery'),
  ('2024003', 'RANDRIANASOLO Fanja'),
  ('2024004', 'RAZAFINDRABE Tiana'),
  ('2024005', 'RAKOTOMALALA Miora'),
  ('2024006', 'ANDRIANTSOA Tovo'),
  ('2024007', 'RAHARISON Lova'),
];

// ----------------------------------------------------------------- Bundle

void _writeSessionBundle(File file) {
  const sessionId = 'demo-session-0001';
  const sessionToken = 'DEMO2026';
  final created = DateTime.utc(2026, 7, 1, 8).toIso8601String();

  final session = TravelSession(
    id: sessionId,
    token: sessionToken,
    name: 'Voyage d’étude — Exemple',
    school: 'Université d’exemple',
    startDate: DateTime.utc(2026, 7, 6),
    endDate: DateTime.utc(2026, 7, 10),
    responsible: 'Responsable Exemple',
    status: SessionStatus.enCours,
    createdAt: created,
    updatedAt: created,
  );

  final days = <TripDay>[
    TripDay(
      id: 'demo-day-1',
      sessionId: sessionId,
      label: 'Jour 1',
      dayDate: DateTime.utc(2026, 7, 6),
      position: 0,
      createdAt: created,
      updatedAt: created,
    ),
    TripDay(
      id: 'demo-day-2',
      sessionId: sessionId,
      label: 'Jour 2',
      dayDate: DateTime.utc(2026, 7, 7),
      position: 1,
      createdAt: created,
      updatedAt: created,
    ),
  ];

  final itemTypes = <ItemType>[
    ItemType(
      id: 'demo-item-petitdej',
      sessionId: sessionId,
      name: 'Petit-déjeuner',
      category: 'repas',
      createdAt: created,
      updatedAt: created,
    ),
    ItemType(
      id: 'demo-item-dejeuner',
      sessionId: sessionId,
      name: 'Déjeuner',
      category: 'repas',
      createdAt: created,
      updatedAt: created,
    ),
    ItemType(
      id: 'demo-item-diner',
      sessionId: sessionId,
      name: 'Dîner',
      category: 'repas',
      createdAt: created,
      updatedAt: created,
    ),
    ItemType(
      id: 'demo-item-eau',
      sessionId: sessionId,
      name: 'Eau',
      category: 'eau',
      unit: 'bouteille',
      createdAt: created,
      updatedAt: created,
    ),
  ];

  final slots = <(String, String, String, String, String)>[
    // (id, itemId, nom, début, fin)
    ('petitdej', 'demo-item-petitdej', 'Petit-déjeuner', '06:30', '08:00'),
    ('eaumatin', 'demo-item-eau', 'Eau du matin', '08:00', '10:00'),
    ('dejeuner', 'demo-item-dejeuner', 'Déjeuner', '11:30', '13:30'),
    ('eauaprem', 'demo-item-eau', 'Eau de l’après-midi', '15:00', '17:00'),
    ('diner', 'demo-item-diner', 'Dîner', '18:30', '20:30'),
  ];

  final distributions = <Distribution>[];
  for (final day in days) {
    var position = 0;
    for (final slot in slots) {
      distributions.add(Distribution(
        id: 'demo-dist-${day.id}-${slot.$1}',
        sessionId: sessionId,
        dayId: day.id,
        itemTypeId: slot.$2,
        name: slot.$3,
        startTime: slot.$4,
        endTime: slot.$5,
        status: DistributionStatus.ouverte,
        position: position++,
        createdAt: created,
        updatedAt: created,
      ));
    }
  }

  final students = <Student>[
    for (var i = 0; i < _studentsSeed.length; i++)
      Student(
        id: 'demo-student-${i + 1}',
        sessionId: sessionId,
        matricule: _studentsSeed[i].$1,
        fullName: _studentsSeed[i].$2,
        qrToken: 'DEMO${(i + 1).toString().padLeft(3, '0')}',
        createdAt: created,
        updatedAt: created,
      ),
  ];

  // Quelques pointages fictifs : 5 servis au petit-déjeuner, 3 au déjeuner.
  final pointages = <Pointage>[];
  var seq = 0;
  void addPointage(String studentId, String distId, String recordedAt) {
    seq++;
    pointages.add(Pointage(
      id: 'demo-pointage-${seq.toString().padLeft(3, '0')}',
      sessionId: sessionId,
      studentId: studentId,
      distributionId: distId,
      deviceId: 'demo-device',
      deviceName: 'Appareil exemple',
      operator: 'Pointeur exemple',
      mode: ScanMode.qr,
      recordedAtUtc: recordedAt,
      recordedAtLocal: recordedAt,
      createdAt: recordedAt,
      updatedAt: recordedAt,
    ));
  }

  final petitDej = distributions.firstWhere((d) => d.id.endsWith('-petitdej'));
  final dejeuner = distributions.firstWhere((d) => d.id.endsWith('-dejeuner'));
  for (var i = 0; i < 5; i++) {
    addPointage(
        students[i].id, petitDej.id, '2026-07-06T0${6 + i}:15:00.000Z');
  }
  for (var i = 0; i < 3; i++) {
    addPointage(students[i].id, dejeuner.id, '2026-07-06T13:0$i:00.000Z');
  }

  final payload = <String, dynamic>{
    'sessions': [session.toMap()],
    'students': students.map((s) => s.toMap()).toList(),
    'item_types': itemTypes.map((t) => t.toMap()).toList(),
    'days': days.map((d) => d.toMap()).toList(),
    'distributions': distributions.map((d) => d.toMap()).toList(),
    'pointages': pointages.map((p) => p.toMap()).toList(),
    'conflicts': <Map<String, Object?>>[],
  };

  final payloadJson = jsonEncode(payload);
  final bundle = <String, dynamic>{
    'format': AppConstants.bundleFormat,
    'version': AppConstants.bundleVersion,
    'kind': AppConstants.bundleKindBackup,
    'generatedAt': created,
    'generator': {
      'deviceId': 'demo-device',
      'deviceName': 'Exemple',
    },
    'sha256': sha256.convert(utf8.encode(payloadJson)).toString(),
    'payload': payload,
  };

  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(bundle));
  stdout.writeln('  - ${file.path}');
}
