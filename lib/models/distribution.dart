import 'enums.dart';

/// Distribution planifiée : un créneau de distribution d'un élément.
class Distribution {
  const Distribution({
    required this.id,
    required this.sessionId,
    required this.dayId,
    this.itemTypeId,
    required this.name,
    this.startTime,
    this.endTime,
    this.status = DistributionStatus.aVenir,
    this.allowMultiple = false,
    this.maxPassages = 1,
    this.trackQuantity = false,
    this.instructions,
    this.position = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String sessionId;
  final String dayId;
  final String? itemTypeId;
  final String name;

  /// Heures indicatives au format « HH:mm ».
  final String? startTime;
  final String? endTime;
  final DistributionStatus status;

  /// Règle de pointage : un seul passage par défaut.
  final bool allowMultiple;
  final int maxPassages;

  /// Distingue « dotation reçue » et « quantité remise ».
  final bool trackQuantity;
  final String? instructions;
  final int position;
  final String createdAt;
  final String updatedAt;

  bool get acceptsPointage => status == DistributionStatus.ouverte;

  String get horaires {
    if (startTime == null && endTime == null) return 'Horaires libres';
    if (endTime == null) return 'À partir de $startTime';
    if (startTime == null) return "Jusqu'à $endTime";
    return '$startTime – $endTime';
  }

  Distribution copyWith({
    String? itemTypeId,
    String? name,
    String? startTime,
    String? endTime,
    DistributionStatus? status,
    bool? allowMultiple,
    int? maxPassages,
    bool? trackQuantity,
    String? instructions,
    int? position,
    String? updatedAt,
  }) {
    return Distribution(
      id: id,
      sessionId: sessionId,
      dayId: dayId,
      itemTypeId: itemTypeId ?? this.itemTypeId,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      allowMultiple: allowMultiple ?? this.allowMultiple,
      maxPassages: maxPassages ?? this.maxPassages,
      trackQuantity: trackQuantity ?? this.trackQuantity,
      instructions: instructions ?? this.instructions,
      position: position ?? this.position,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'session_id': sessionId,
        'day_id': dayId,
        'item_type_id': itemTypeId,
        'name': name,
        'start_time': startTime,
        'end_time': endTime,
        'status': status.code,
        'allow_multiple': allowMultiple ? 1 : 0,
        'max_passages': maxPassages,
        'track_quantity': trackQuantity ? 1 : 0,
        'instructions': instructions,
        'position': position,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory Distribution.fromMap(Map<String, Object?> m) => Distribution(
        id: m['id']! as String,
        sessionId: m['session_id']! as String,
        dayId: m['day_id']! as String,
        itemTypeId: m['item_type_id'] as String?,
        name: m['name']! as String,
        startTime: m['start_time'] as String?,
        endTime: m['end_time'] as String?,
        status: DistributionStatus.fromCode(m['status'] as String?),
        allowMultiple: ((m['allow_multiple'] as int?) ?? 0) == 1,
        maxPassages: (m['max_passages'] as int?) ?? 1,
        trackQuantity: ((m['track_quantity'] as int?) ?? 0) == 1,
        instructions: m['instructions'] as String?,
        position: (m['position'] as int?) ?? 0,
        createdAt: m['created_at']! as String,
        updatedAt: m['updated_at']! as String,
      );
}
