/// Journée du voyage (conteneur de distributions).
class TripDay {
  const TripDay({
    required this.id,
    required this.sessionId,
    required this.label,
    this.dayDate,
    this.position = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String sessionId;

  /// Libellé affiché, par exemple « Jour 1 ».
  final String label;

  /// Date civile optionnelle de la journée.
  final DateTime? dayDate;
  final int position;
  final String createdAt;
  final String updatedAt;

  TripDay copyWith({
    String? label,
    DateTime? dayDate,
    int? position,
    String? updatedAt,
  }) {
    return TripDay(
      id: id,
      sessionId: sessionId,
      label: label ?? this.label,
      dayDate: dayDate ?? this.dayDate,
      position: position ?? this.position,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'session_id': sessionId,
        'label': label,
        'day_date': dayDate?.toIso8601String(),
        'position': position,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory TripDay.fromMap(Map<String, Object?> m) => TripDay(
        id: m['id']! as String,
        sessionId: m['session_id']! as String,
        label: m['label']! as String,
        dayDate:
            m['day_date'] != null ? DateTime.tryParse(m['day_date']! as String) : null,
        position: (m['position'] as int?) ?? 0,
        createdAt: m['created_at']! as String,
        updatedAt: m['updated_at']! as String,
      );
}
