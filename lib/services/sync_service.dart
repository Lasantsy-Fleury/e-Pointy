import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../core/constants.dart';
import '../core/utils.dart';
import '../data/app_database.dart';
import '../data/conflict_dao.dart';
import '../data/pointage_dao.dart';
import '../data/plan_dao.dart';
import '../data/session_dao.dart';
import '../data/student_dao.dart';
import '../models/conflict.dart';
import '../models/distribution.dart';
import '../models/enums.dart';
import '../models/item_type.dart';
import '../models/merge_report.dart';
import '../models/pointage.dart';
import '../models/student.dart';
import '../models/travel_session.dart';
import '../models/trip_day.dart';

/// Transfert de données entre appareils par fichier bundle.
///
/// Méthode retenue (documentée dans docs/SYNCHRONISATION.md) :
/// un fichier `.mipointy` contenant la session, les étudiants, la
/// configuration, les pointages et les conflits, protégé par une empreinte
/// SHA-256. Le transfert peut être fait par n'importe quel moyen disponible
/// (partage Android, câble, carte SD, messagerie…), sans Internet.
///
/// Propriétés garanties :
/// - idempotence : un événement reçu plusieurs fois n'est appliqué qu'une fois ;
/// - les pointages valides ne sont jamais supprimés par une fusion ;
/// - deux appareils pointant le même étudiant créent un conflit explicite,
///   jamais un double comptage ;
/// - le rapport final n'affiche « terminé » qu'après vérification.
class SyncService {
  SyncService(AppDatabase db)
      : _sessions = SessionDao(db),
        _students = StudentDao(db),
        _plan = PlanDao(db),
        _pointages = PointageDao(db),
        _conflicts = ConflictDao(db);

  final SessionDao _sessions;
  final StudentDao _students;
  final PlanDao _plan;
  final PointageDao _pointages;
  final ConflictDao _conflicts;

  // ---------------------------------------------------------------- build

  /// Construit le bundle complet d'une session.
  Future<Map<String, dynamic>> buildBundle({
    required String sessionId,
    required String kind,
    required String deviceId,
    required String deviceName,
  }) async {
    final session = await _sessions.getById(sessionId);
    if (session == null) {
      throw StateError('Session introuvable : $sessionId');
    }
    final payload = <String, dynamic>{
      'sessions': [session.toMap()],
      'students':
          (await _students.getBySession(sessionId)).map((s) => s.toMap()).toList(),
      'item_types': (await _plan.itemTypes(sessionId))
          .map((t) => t.toMap())
          .toList(),
      'days': (await _plan.days(sessionId)).map((d) => d.toMap()).toList(),
      'distributions': (await _plan.distributions(sessionId))
          .map((d) => d.toMap())
          .toList(),
      'pointages':
          (await _pointages.forSession(sessionId)).map((p) => p.toMap()).toList(),
      'conflicts':
          (await _conflicts.forSession(sessionId)).map((c) => c.toMap()).toList(),
    };
    final payloadJson = jsonEncode(payload);
    return <String, dynamic>{
      'format': AppConstants.bundleFormat,
      'version': AppConstants.bundleVersion,
      'kind': kind,
      'generatedAt': nowUtcIso(),
      'generator': {'deviceId': deviceId, 'deviceName': deviceName},
      'sha256': sha256.convert(utf8.encode(payloadJson)).toString(),
      'payload': payload,
    };
  }

  /// Écrit le bundle sur disque (fichier unique, extension .mipointy).
  Future<File> writeBundleFile(Map<String, dynamic> bundle, String path) async {
    final file = File(path);
    await file.writeAsString(jsonEncode(bundle), flush: true);
    return file;
  }

  // ---------------------------------------------------------------- read

  /// Lit et vérifie un bundle. Lance [BundleFormatException] si le fichier
  /// est corrompu ou d'un format non reconnu.
  Future<BundleEnvelope> readBundleFile(String path) async {
    final content = await File(path).readAsString();
    return parseBundle(content);
  }

  BundleEnvelope parseBundle(String content) {
    dynamic decoded;
    try {
      decoded = jsonDecode(content);
    } catch (_) {
      throw const BundleFormatException(
          'Fichier illisible : ce n’est pas un fichier de transfert Mipointy.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const BundleFormatException(
          'Fichier illisible : structure inattendue.');
    }
    final format = decoded['format'];
    if (format != AppConstants.bundleFormat) {
      throw BundleFormatException(
          'Format non reconnu (« $format »). Attendu : ${AppConstants.bundleFormat}.');
    }
    final version = (decoded['version'] as num?)?.toInt() ?? 0;
    if (version > AppConstants.bundleVersion) {
      throw BundleFormatException(
          'Version $version plus récente que l’application. Mettez à jour l’application sur cet appareil.');
    }
    final payload = decoded['payload'];
    if (payload is! Map<String, dynamic>) {
      throw const BundleFormatException('Fichier corrompu : contenu absent.');
    }
    // Vérification d'intégrité : empreinte SHA-256 du contenu.
    final expected = decoded['sha256'] as String?;
    final actual =
        sha256.convert(utf8.encode(jsonEncode(payload))).toString();
    final checksumOk = expected != null && expected == actual;

    final generator =
        (decoded['generator'] as Map?)?.cast<String, dynamic>() ?? const {};
    final sessions = (payload['sessions'] as List? ?? const [])
        .map((e) => TravelSession.fromMap((e as Map).cast<String, Object?>()))
        .toList();
    final students = payload['students'] as List? ?? const [];
    final distributions = payload['distributions'] as List? ?? const [];
    final pointages = payload['pointages'] as List? ?? const [];

    return BundleEnvelope(
      bundle: decoded,
      checksumOk: checksumOk,
      kind: (decoded['kind'] as String?) ?? AppConstants.bundleKindSync,
      version: version,
      sessionNames: sessions.map((s) => s.name).toList(),
      generatedAt: (decoded['generatedAt'] as String?) ?? '',
      sourceDevice: (generator['deviceName'] as String?) ?? 'Appareil inconnu',
      studentCount: students.length,
      distributionCount: distributions.length,
      pointageCount: pointages.length,
      isNewSession: true,
    );
  }

  /// Complète l'aperçu en croisant avec les sessions locales.
  Future<BundlePreview> previewFor(BundleEnvelope envelope) async {
    var isNew = true;
    for (final raw in (envelope.bundle['payload']['sessions'] as List)) {
      final s = TravelSession.fromMap((raw as Map).cast<String, Object?>());
      final local = await _sessions.getById(s.id);
      if (local != null) isNew = false;
    }
    return BundlePreview(
      kind: envelope.kind,
      sessionNames: envelope.sessionNames,
      generatedAt: envelope.generatedAt,
      sourceDevice: envelope.sourceDevice,
      studentCount: envelope.studentCount,
      distributionCount: envelope.distributionCount,
      pointageCount: envelope.pointageCount,
      checksumOk: envelope.checksumOk,
      isNewSession: isNew,
      version: envelope.version,
    );
  }

  // ---------------------------------------------------------------- merge

  /// Fusionne un bundle dans la base locale.
  ///
  /// [mode] `fusionner` : ajoute et met à jour sans supprimer (transfert).
  /// [mode] `remplacer` : remplace entièrement les sessions du bundle
  /// (restauration, protégée par confirmation dans l'interface).
  Future<MergeReport> mergeBundle(
    BundleEnvelope envelope, {
    required MergeMode mode,
  }) async {
    if (!envelope.checksumOk) {
      throw const BundleFormatException(
          'Empreinte de vérification incorrecte : le fichier est corrompu ou '
          'a été modifié. Aucune donnée n’a été importée.');
    }
    final payload =
        envelope.bundle['payload'] as Map<String, dynamic>;
    final report = MergeReport(sessionNames: envelope.sessionNames);

    final sessionIds = <String>{}; // sessions du bundle
    final incomingSessions = <TravelSession>[];
    for (final raw in (payload['sessions'] as List? ?? const [])) {
      final s = TravelSession.fromMap((raw as Map).cast<String, Object?>());
      incomingSessions.add(s);
      sessionIds.add(s.id);
    }

    // Remplacement (restauration) : purge des sessions concernées.
    if (mode == MergeMode.remplacer) {
      for (final s in incomingSessions) {
        await _sessions.deleteAllData(s.id);
      }
      report.replaced = true;
      report.infos.add('Données locales remplacées pour : '
          '${incomingSessions.map((s) => s.name).join(', ')}.');
    }

    // ---- Sessions ----
    for (final incoming in incomingSessions) {
      final local = await _sessions.getById(incoming.id);
      if (local == null) {
        // Protection contre les sessions incompatibles : même token,
        // identifiant différent => données non fusionnables.
        final byToken = await _sessions.getByToken(incoming.token);
        if (byToken != null) {
          report.anomalies.add(
              'Session incompatible : « ${incoming.name} » utilise le même '
              'identifiant de session que « ${byToken.name} » mais avec des '
              'identifiants différents. Données ignorées.');
          sessionIds.remove(incoming.id);
          continue;
        }
        await _sessions.insert(incoming);
        report.sessionsAdded++;
      } else {
        if (incoming.updatedAt.compareTo(local.updatedAt) > 0) {
          await _sessions.update(incoming);
          report.sessionsUpdated++;
        } else {
          report.infos.add(
              'Session « ${incoming.name} » : configuration locale conservée (plus récente).');
        }
      }
    }

    // ---- Étudiants (avec remappage par matricule) ----
    // Si deux appareils ont importé la même liste séparément, les identifiants
    // diffèrent : les pointages entrants sont remappés sur l'étudiant local.
    final studentIdMap = <String, String>{};
    final incomingStudents = (payload['students'] as List? ?? const [])
        .map((e) => Student.fromMap((e as Map).cast<String, Object?>()))
        .where((s) => sessionIds.contains(s.sessionId))
        .toList();
    for (final incoming in incomingStudents) {
      final local = await _students.getById(incoming.id);
      if (local != null) {
        studentIdMap[incoming.id] = local.id;
        if (incoming.updatedAt.compareTo(local.updatedAt) > 0 &&
            (incoming.matricule != local.matricule ||
                incoming.fullName != local.fullName ||
                incoming.qrToken != local.qrToken ||
                incoming.active != local.active)) {
          await _students.update(incoming);
          report.studentsUpdated++;
        }
        continue;
      }
      final byMatricule =
          await _students.getByMatricule(incoming.sessionId, incoming.matricule);
      if (byMatricule != null) {
        studentIdMap[incoming.id] = byMatricule.id;
        report.infos.add(
            'Matricule ${incoming.matricule} déjà présent avec un identifiant '
            'différent : pointages associés à l’étudiant local.');
        if (incoming.updatedAt.compareTo(byMatricule.updatedAt) > 0) {
          await _students.update(incoming.withId(byMatricule.id));
          report.studentsUpdated++;
        }
        continue;
      }
      await _students.insert(incoming);
      studentIdMap[incoming.id] = incoming.id;
      report.studentsAdded++;
    }

    // ---- Types d'éléments ----
    for (final raw in (payload['item_types'] as List? ?? const [])) {
      final incoming =
          ItemType.fromMap((raw as Map).cast<String, Object?>());
      if (!sessionIds.contains(incoming.sessionId)) continue;
      final local = await _plan.itemTypeById(incoming.id);
      if (local == null) {
        await _plan.insertItemType(incoming);
      } else if (incoming.updatedAt.compareTo(local.updatedAt) > 0) {
        await _plan.updateItemType(incoming);
      }
    }

    // ---- Journées (remappage par libellé) ----
    final dayIdMap = <String, String>{};
    for (final raw in (payload['days'] as List? ?? const [])) {
      final incoming = TripDay.fromMap((raw as Map).cast<String, Object?>());
      if (!sessionIds.contains(incoming.sessionId)) continue;
      final local = await _plan.dayById(incoming.id);
      if (local != null) {
        dayIdMap[incoming.id] = local.id;
        if (incoming.updatedAt.compareTo(local.updatedAt) > 0) {
          await _plan.updateDay(incoming);
          report.daysUpdated++;
        }
        continue;
      }
      // Correspondance par libellé de journée (deux appareils ayant créé
      // « Jour 1 » indépendamment).
      final localDays = await _plan.days(incoming.sessionId);
      final match = localDays
          .where((d) => searchKey(d.label) == searchKey(incoming.label))
          .toList();
      if (match.isNotEmpty) {
        dayIdMap[incoming.id] = match.first.id;
        report.infos.add(
            'Journée « ${incoming.label} » fusionnée avec la journée locale existante.');
        continue;
      }
      await _plan.insertDay(incoming);
      dayIdMap[incoming.id] = incoming.id;
      report.daysAdded++;
    }

    // ---- Distributions (remappage par jour + nom) ----
    final distIdMap = <String, String>{};
    for (final raw in (payload['distributions'] as List? ?? const [])) {
      final incoming =
          Distribution.fromMap((raw as Map).cast<String, Object?>());
      if (!sessionIds.contains(incoming.sessionId)) continue;
      final local = await _plan.distributionById(incoming.id);
      if (local != null) {
        distIdMap[incoming.id] = local.id;
        if (incoming.updatedAt.compareTo(local.updatedAt) > 0) {
          // Ne jamais régresser un statut ouvert/clôturé par une vieille copie.
          await _plan.updateDistribution(incoming);
          report.distributionsUpdated++;
        }
        continue;
      }
      final mappedDay = dayIdMap[incoming.dayId] ?? incoming.dayId;
      final localDists = await _plan.distributions(incoming.sessionId);
      final match = localDists.where((d) =>
          d.dayId == mappedDay && searchKey(d.name) == searchKey(incoming.name));
      if (match.isNotEmpty) {
        distIdMap[incoming.id] = match.first.id;
        report.infos.add(
            'Distribution « ${incoming.name} » fusionnée avec la distribution locale équivalente.');
        continue;
      }
      await _plan.insertDistribution(
          incoming.copyWithDayId(mappedDay));
      distIdMap[incoming.id] = incoming.id;
      report.distributionsAdded++;
    }

    // ---- Pointages (append-only, idempotents, conflits détectés) ----
    for (final raw in (payload['pointages'] as List? ?? const [])) {
      final incoming = Pointage.fromMap((raw as Map).cast<String, Object?>());
      if (!sessionIds.contains(incoming.sessionId)) continue;

      // Idempotence : un événement déjà connu n'est jamais réappliqué.
      final known = await _pointages.getById(incoming.id);
      if (known != null) {
        report.pointagesSkipped++;
        continue;
      }

      final mappedStudent = studentIdMap[incoming.studentId];
      final mappedDist = distIdMap[incoming.distributionId];
      if (mappedStudent == null || mappedDist == null) {
        report.anomalies.add(
            'Pointage ignoré : étudiant ou distribution inconnu localement '
            '(événement ${incoming.id.substring(0, 8)}…).');
        continue;
      }
      final resolved = incoming.copyWithIds(mappedStudent, mappedDist);

      final existing = await _pointages.getValide(mappedStudent, mappedDist);
      if (existing != null && resolved.isValid) {
        // Deux appareils ont pointé le même étudiant : le pointage entrant
        // est conservé en « doublon potentiel » et un conflit est créé.
        // Le nombre d'étudiants servis n'augmente pas artificiellement.
        final stored = resolved.copyWithStatus(PointageStatus.doublonPotentiel);
        await _pointages.insert(stored);
        report.pointagesConflicts++;
        final conflict = Conflict(
          id: newId(),
          sessionId: resolved.sessionId,
          distributionId: mappedDist,
          studentId: mappedStudent,
          keptPointageId: existing.id,
          conflictingPointageId: stored.id,
          detectedAt: nowUtcIso(),
        );
        await _conflicts.insert(conflict);
        report.conflictsRecorded++;
        continue;
      }

      await _pointages.insert(resolved);
      report.pointagesApplied++;
    }

    // ---- Conflits déjà documentés sur l'autre appareil ----
    for (final raw in (payload['conflicts'] as List? ?? const [])) {
      final incoming = Conflict.fromMap((raw as Map).cast<String, Object?>());
      if (!sessionIds.contains(incoming.sessionId)) continue;
      if (await _conflicts.existsById(incoming.id)) continue;
      await _conflicts.insert(incoming);
      report.conflictsRecorded++;
    }

    report.infos.add('Transfert vérifié et terminé.');
    return report;
  }
}

/// Conteneur d'un bundle lu (fichier vérifié ou non).
class BundleEnvelope {
  const BundleEnvelope({
    required this.bundle,
    required this.checksumOk,
    required this.kind,
    required this.version,
    required this.sessionNames,
    required this.generatedAt,
    required this.sourceDevice,
    required this.studentCount,
    required this.distributionCount,
    required this.pointageCount,
    required this.isNewSession,
  });

  final Map<String, dynamic> bundle;
  final bool checksumOk;
  final String kind;
  final int version;
  final List<String> sessionNames;
  final String generatedAt;
  final String sourceDevice;
  final int studentCount;
  final int distributionCount;
  final int pointageCount;
  final bool isNewSession;
}

/// Erreur de fichier de transfert, destinée à l'utilisateur.
class BundleFormatException implements Exception {
  const BundleFormatException(this.message);
  final String message;
  @override
  String toString() => message;
}

extension on Distribution {
  Distribution copyWithDayId(String newDayId) => Distribution(
        id: id,
        sessionId: sessionId,
        dayId: newDayId,
        itemTypeId: itemTypeId,
        name: name,
        startTime: startTime,
        endTime: endTime,
        status: status,
        allowMultiple: allowMultiple,
        maxPassages: maxPassages,
        trackQuantity: trackQuantity,
        instructions: instructions,
        position: position,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

extension on Student {
  /// Conserve les données entrantes en remplaçant l'identifiant par celui
  /// de l'étudiant local (correspondance par matricule).
  Student withId(String newId) => Student(
        id: newId,
        sessionId: sessionId,
        matricule: matricule,
        fullName: fullName,
        qrToken: qrToken,
        active: active,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

extension on Pointage {
  Pointage copyWithIds(String studentId, String distributionId) => Pointage(
        id: id,
        sessionId: sessionId,
        studentId: studentId,
        distributionId: distributionId,
        status: status,
        mode: mode,
        deviceId: deviceId,
        deviceName: deviceName,
        operator: operator,
        recordedAtUtc: recordedAtUtc,
        recordedAtLocal: recordedAtLocal,
        quantity: quantity,
        correctionOf: correctionOf,
        correctionReason: correctionReason,
        syncedOut: true,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  Pointage copyWithStatus(PointageStatus status) =>
      copyWith(status: status, updatedAt: nowUtcIso());
}
