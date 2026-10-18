import 'package:sqflite/sqflite.dart';

import '../core/utils.dart';
import '../data/app_database.dart';
import '../data/audit_dao.dart';
import '../data/pointage_dao.dart';
import '../data/session_dao.dart';
import '../data/student_dao.dart';
import '../models/distribution.dart';
import '../models/enums.dart';
import '../models/pointage.dart';
import '../models/scan_result.dart';
import '../models/student.dart';
import 'qr_service.dart';

/// Identité de l'appareil et de l'opérateur pour les pointages.
class OperatorContext {
  const OperatorContext({
    required this.deviceId,
    required this.deviceName,
    required this.operator,
  });

  final String deviceId;
  final String deviceName;
  final String operator;
}

/// Règles métier du pointage : identification QR, prévention des doublons,
/// enregistrement local vérifié et traçabilité.
class ScanService {
  ScanService(AppDatabase db)
      : _sessions = SessionDao(db),
        _students = StudentDao(db),
        _pointages = PointageDao(db),
        _audit = AuditDao(db);

  final SessionDao _sessions;
  final StudentDao _students;
  final PointageDao _pointages;
  final AuditDao _audit;

  /// Traite un contenu QR scanné pour la session et la distribution actives.
  Future<ScanResult> processRaw({
    required String raw,
    required String activeSessionId,
    Distribution? activeDistribution,
    required OperatorContext ctx,
  }) async {
    // 1. Format du QR.
    final payload = QrService.decode(raw);
    if (payload == null) {
      return ScanResult.failure(
        ScanOutcome.qrInvalide,
        'QR invalide',
        detail: 'Ce code ne correspond pas au format Mipointy.',
      );
    }

    // 2. Session portée par le QR.
    final session = await _sessions.getByToken(payload.sessionToken);
    if (session == null) {
      return ScanResult.failure(
        ScanOutcome.qrInvalide,
        'QR invalide',
        detail: 'Session inconnue pour ce code.',
      );
    }
    if (session.id != activeSessionId) {
      return ScanResult.failure(
        ScanOutcome.mauvaiseSession,
        'Mauvaise session',
        detail:
            'Ce QR appartient à la session « ${session.name} ». Sélectionnez-la ou demandez le badge correspondant.',
      );
    }

    // 3. Distribution active.
    final distribution = activeDistribution;
    if (distribution == null) {
      return ScanResult.failure(
        ScanOutcome.sansDistribution,
        'Aucune distribution active',
        detail: 'Choisissez d’abord la distribution en cours.',
      );
    }

    // 4. Étudiant.
    final student =
        await _students.getByQrToken(session.id, payload.studentToken);
    if (student == null) {
      return ScanResult.failure(
        ScanOutcome.etudiantInconnu,
        'Étudiant inconnu',
        detail: 'Aucun étudiant de cette session ne correspond à ce QR.',
      );
    }

    return recordForStudent(
      student: student,
      distribution: distribution,
      mode: ScanMode.qr,
      ctx: ctx,
    );
  }

  /// Enregistre un pointage pour un étudiant (QR ou recherche manuelle).
  Future<ScanResult> recordForStudent({
    required Student student,
    required Distribution distribution,
    required ScanMode mode,
    required OperatorContext ctx,
  }) async {
    // Étudiant désactivé : signalé, pas de pointage.
    if (!student.active) {
      return ScanResult.failure(
        ScanOutcome.desactive,
        'Étudiant désactivé',
        student: student,
        distribution: distribution,
        detail: 'Cet étudiant est désactivé dans la session.',
      );
    }

    // Distribution ouverte uniquement (horaires indicatifs).
    if (!distribution.acceptsPointage) {
      return ScanResult.failure(
        ScanOutcome.distributionFermee,
        'Distribution ${distribution.status.label.toLowerCase()}',
        student: student,
        distribution: distribution,
        detail: distribution.status == DistributionStatus.cloturee
            ? 'Distribution clôturée : ouvrez-la de nouveau pour autoriser un pointage.'
            : 'Seule une distribution ouverte accepte des pointages.',
      );
    }

    // Règle : un seul pointage validé par étudiant et par distribution,
    // sauf distributions configurées pour plusieurs passages.
    final existing =
        await _pointages.getValide(student.id, distribution.id);
    if (existing != null) {
      if (distribution.allowMultiple &&
          distribution.maxPassages > 1 &&
          existing.quantity < distribution.maxPassages) {
        final updated = existing.copyWith(
          quantity: existing.quantity + 1,
          updatedAt: nowUtcIso(),
        );
        await _pointages.update(updated);
        final remaining = distribution.maxPassages - updated.quantity;
        await _journalScan(student, distribution, mode, ctx, 'quantite');
        return ScanResult(
          outcome: ScanOutcome.enregistre,
          student: student,
          distribution: distribution,
          message: 'Pointage enregistré',
          detail: 'Passage ${updated.quantity}/${distribution.maxPassages} '
              '— restants : $remaining',
          quantity: updated.quantity,
        );
      }
      final at = DateTime.tryParse(existing.recordedAtLocal)?.toLocal();
      final heure = at != null
          ? '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}'
          : null;
      return ScanResult.failure(
        ScanOutcome.dejaServi,
        'Déjà servi',
        student: student,
        distribution: distribution,
        detail: distribution.allowMultiple
            ? 'Nombre maximum de passages atteint '
                '(${existing.quantity}/${distribution.maxPassages}).'
            : 'Un pointage existe déjà pour cette distribution'
                '${heure != null ? ' à $heure' : ''}'
                '${existing.operator != null ? ' par ${existing.operator}' : ''}.',
        existingPointage: existing,
      );
    }

    // Enregistrement local, puis relecture pour confirmer la persistance :
    // un pointage n'est réussi que si son écriture est confirmée.
    final now = DateTime.now();
    final pointage = Pointage(
      id: newId(),
      sessionId: distribution.sessionId,
      studentId: student.id,
      distributionId: distribution.id,
      status: PointageStatus.valide,
      mode: mode,
      deviceId: ctx.deviceId,
      deviceName: ctx.deviceName,
      operator: ctx.operator.isEmpty ? null : ctx.operator,
      recordedAtUtc: now.toUtc().toIso8601String(),
      recordedAtLocal: now.toIso8601String(),
      createdAt: now.toUtc().toIso8601String(),
      updatedAt: now.toUtc().toIso8601String(),
    );
    try {
      await _pointages.insert(pointage);
      final confirmed = await _pointages.getById(pointage.id);
      if (confirmed == null || !confirmed.isValid) {
        return ScanResult.failure(
          ScanOutcome.erreurEnregistrement,
          'Erreur d’enregistrement',
          student: student,
          distribution: distribution,
          detail: 'Le pointage n’a pas pu être confirmé localement. '
              'Réessayez.',
        );
      }
    } on DatabaseException catch (e) {
      // Contrainte d'unicité atteinte entre-temps : traité comme doublon.
      if (isUniqueConstraint(e)) {
        return ScanResult.failure(
          ScanOutcome.dejaServi,
          'Déjà servi',
          student: student,
          distribution: distribution,
          detail: 'Un pointage vient d’être enregistré pour cet étudiant.',
        );
      }
      return ScanResult.failure(
        ScanOutcome.erreurEnregistrement,
        'Erreur d’enregistrement',
        student: student,
        distribution: distribution,
        detail: 'Échec d’écriture locale : ${e.toString()}',
      );
    } catch (e) {
      return ScanResult.failure(
        ScanOutcome.erreurEnregistrement,
        'Erreur d’enregistrement',
        student: student,
        distribution: distribution,
        detail: 'Échec d’écriture locale : $e',
      );
    }

    await _journalScan(student, distribution, mode, ctx, 'enregistre');
    return ScanResult(
      outcome: ScanOutcome.enregistre,
      student: student,
      distribution: distribution,
      message: 'Pointage enregistré',
      detail: mode == ScanMode.manuel
          ? 'Pointage manuel — ${distribution.name}'
          : distribution.name,
    );
  }

  /// Annule un pointage (correction autorisée, avec motif obligatoire).
  Future<void> cancelPointage({
    required Pointage pointage,
    required String reason,
    required OperatorContext ctx,
  }) async {
    await _pointages.cancel(
      id: pointage.id,
      sessionId: pointage.sessionId,
      reason: reason,
      actor: ctx.operator.isEmpty ? ctx.deviceName : ctx.operator,
    );
    await _audit.log(
      sessionId: pointage.sessionId,
      actor: ctx.operator.isEmpty ? ctx.deviceName : ctx.operator,
      action: 'correction_pointage',
      details: 'Pointage ${pointage.id} annulé : $reason',
    );
  }

  Future<void> _journalScan(
    Student student,
    Distribution distribution,
    ScanMode mode,
    OperatorContext ctx,
    String action,
  ) async {
    // Journal local optionnel : aide au diagnostic, jamais bloquant.
    try {
      await _audit.log(
        sessionId: distribution.sessionId,
        actor: ctx.operator.isEmpty ? ctx.deviceName : ctx.operator,
        action: 'scan_$action',
        details:
            '${student.matricule} — ${student.fullName} — ${distribution.name}',
      );
    } catch (_) {
      // Le journal ne doit jamais faire échouer un pointage.
    }
  }
}

/// Détecte une violation de contrainte d'unicité SQLite.
bool isUniqueConstraint(DatabaseException e) {
  final code = e.toString().toUpperCase();
  return code.contains('UNIQUE') || code.contains('CONSTRAINT');
}
