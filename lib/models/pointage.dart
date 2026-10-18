import 'enums.dart';

/// Événement de pointage (journal d'audit d'une réception).
///
/// Un seul pointage « validé » peut exister par couple (étudiant, distribution),
/// garanti par un index unique partiel en base. Les pointages annulés et les
/// doublons potentiels restent consultables pour l'audit.
class Pointage {
  const Pointage({
    required this.id,
    required this.sessionId,
    required this.studentId,
    required this.distributionId,
    this.status = PointageStatus.valide,
    this.mode = ScanMode.qr,
    required this.deviceId,
    this.deviceName,
    this.operator,
    required this.recordedAtUtc,
    required this.recordedAtLocal,
    this.quantity = 1,
    this.correctionOf,
    this.correctionReason,
    this.syncedOut = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Identifiant unique et stable de l'événement (UUID) :
  /// c'est la clé d'idempotence des transferts entre appareils.
  final String id;
  final String sessionId;
  final String studentId;
  final String distributionId;
  final PointageStatus status;
  final ScanMode mode;
  final String deviceId;
  final String? deviceName;
  final String? operator;

  /// Date-heure UTC enregistrée par l'appareil.
  final String recordedAtUtc;

  /// Date-heure locale de l'appareil (interprétée avec prudence).
  final String recordedAtLocal;

  /// Quantité ou nombre de passages (1 par défaut).
  final int quantity;

  /// Si correction : identifiant du pointage annulé.
  final String? correctionOf;
  final String? correctionReason;

  /// false = créé sur cet appareil, jamais encore inclus dans un transfert.
  final bool syncedOut;
  final String createdAt;
  final String updatedAt;

  bool get isValid => status == PointageStatus.valide;

  Pointage copyWith({
    PointageStatus? status,
    int? quantity,
    String? correctionOf,
    String? correctionReason,
    bool? syncedOut,
    String? updatedAt,
  }) {
    return Pointage(
      id: id,
      sessionId: sessionId,
      studentId: studentId,
      distributionId: distributionId,
      status: status ?? this.status,
      mode: mode,
      deviceId: deviceId,
      deviceName: deviceName,
      operator: operator,
      recordedAtUtc: recordedAtUtc,
      recordedAtLocal: recordedAtLocal,
      quantity: quantity ?? this.quantity,
      correctionOf: correctionOf ?? this.correctionOf,
      correctionReason: correctionReason ?? this.correctionReason,
      syncedOut: syncedOut ?? this.syncedOut,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'session_id': sessionId,
        'student_id': studentId,
        'distribution_id': distributionId,
        'status': status.code,
        'mode': mode.code,
        'device_id': deviceId,
        'device_name': deviceName,
        'operator': operator,
        'recorded_at_utc': recordedAtUtc,
        'recorded_at_local': recordedAtLocal,
        'quantity': quantity,
        'correction_of': correctionOf,
        'correction_reason': correctionReason,
        'synced_out': syncedOut ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory Pointage.fromMap(Map<String, Object?> m) => Pointage(
        id: m['id']! as String,
        sessionId: m['session_id']! as String,
        studentId: m['student_id']! as String,
        distributionId: m['distribution_id']! as String,
        status: PointageStatus.fromCode(m['status'] as String?),
        mode: ScanMode.fromCode(m['mode'] as String?),
        deviceId: m['device_id']! as String,
        deviceName: m['device_name'] as String?,
        operator: m['operator'] as String?,
        recordedAtUtc: m['recorded_at_utc']! as String,
        recordedAtLocal: m['recorded_at_local']! as String,
        quantity: (m['quantity'] as int?) ?? 1,
        correctionOf: m['correction_of'] as String?,
        correctionReason: m['correction_reason'] as String?,
        syncedOut: ((m['synced_out'] as int?) ?? 0) == 1,
        createdAt: m['created_at']! as String,
        updatedAt: m['updated_at']! as String,
      );
}
