/// Conflit détecté lors d'une fusion : deux appareils ont pointé le même
/// étudiant pour la même distribution avec des événements différents.
class Conflict {
  const Conflict({
    required this.id,
    required this.sessionId,
    required this.distributionId,
    required this.studentId,
    required this.keptPointageId,
    required this.conflictingPointageId,
    this.type = 'doublon_appareils',
    required this.detectedAt,
    this.resolved = false,
    this.resolution,
    this.resolvedAt,
    this.note,
  });

  final String id;
  final String sessionId;
  final String distributionId;
  final String studentId;

  /// Pointage resté validé sur cet appareil.
  final String keptPointageId;

  /// Pointage reçu d'un autre appareil, stocké en « doublon potentiel ».
  final String conflictingPointageId;
  final String type;
  final String detectedAt;
  final bool resolved;

  /// garde_existant | garde_importe
  final String? resolution;
  final String? resolvedAt;
  final String? note;

  Map<String, Object?> toMap() => {
        'id': id,
        'session_id': sessionId,
        'distribution_id': distributionId,
        'student_id': studentId,
        'kept_pointage_id': keptPointageId,
        'conflicting_pointage_id': conflictingPointageId,
        'type': type,
        'detected_at': detectedAt,
        'resolved': resolved ? 1 : 0,
        'resolution': resolution,
        'resolved_at': resolvedAt,
        'note': note,
      };

  factory Conflict.fromMap(Map<String, Object?> m) => Conflict(
        id: m['id']! as String,
        sessionId: m['session_id']! as String,
        distributionId: m['distribution_id']! as String,
        studentId: m['student_id']! as String,
        keptPointageId: m['kept_pointage_id']! as String,
        conflictingPointageId: m['conflicting_pointage_id']! as String,
        type: (m['type'] as String?) ?? 'doublon_appareils',
        detectedAt: m['detected_at']! as String,
        resolved: ((m['resolved'] as int?) ?? 0) == 1,
        resolution: m['resolution'] as String?,
        resolvedAt: m['resolved_at'] as String?,
        note: m['note'] as String?,
      );
}
