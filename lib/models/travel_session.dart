import 'enums.dart';

/// Session de voyage d'étude (conteneur de toutes les données).
class TravelSession {
  const TravelSession({
    required this.id,
    required this.token,
    required this.name,
    this.school,
    this.startDate,
    this.endDate,
    this.responsible,
    this.notes,
    this.status = SessionStatus.preparation,
    this.configVersion = 1,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;

  /// Token court partagé entre appareils, présent dans les QR codes.
  final String token;
  final String name;
  final String? school;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? responsible;
  final String? notes;
  final SessionStatus status;
  final int configVersion;
  final String createdAt;
  final String updatedAt;

  bool get isOpen => status == SessionStatus.enCours;

  TravelSession copyWith({
    String? name,
    String? school,
    DateTime? startDate,
    DateTime? endDate,
    String? responsible,
    String? notes,
    SessionStatus? status,
    int? configVersion,
    String? updatedAt,
  }) {
    return TravelSession(
      id: id,
      token: token,
      name: name ?? this.name,
      school: school ?? this.school,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      responsible: responsible ?? this.responsible,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      configVersion: configVersion ?? this.configVersion,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'token': token,
        'name': name,
        'school': school,
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'responsible': responsible,
        'notes': notes,
        'status': status.code,
        'config_version': configVersion,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory TravelSession.fromMap(Map<String, Object?> m) => TravelSession(
        id: m['id']! as String,
        token: m['token']! as String,
        name: m['name']! as String,
        school: m['school'] as String?,
        startDate: m['start_date'] != null
            ? DateTime.tryParse(m['start_date']! as String)
            : null,
        endDate: m['end_date'] != null
            ? DateTime.tryParse(m['end_date']! as String)
            : null,
        responsible: m['responsible'] as String?,
        notes: m['notes'] as String?,
        status: SessionStatus.fromCode(m['status'] as String?),
        configVersion: (m['config_version'] as int?) ?? 1,
        createdAt: m['created_at']! as String,
        updatedAt: m['updated_at']! as String,
      );
}
