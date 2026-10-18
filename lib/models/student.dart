/// Étudiant inscrit dans une session.
class Student {
  const Student({
    required this.id,
    required this.sessionId,
    required this.matricule,
    required this.fullName,
    required this.qrToken,
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String sessionId;

  /// Matricule unique dans la session, toujours traité comme du texte.
  final String matricule;
  final String fullName;

  /// Token unique par session, inscrit dans le QR code (pas d'infos perso).
  final String qrToken;
  final bool active;
  final String createdAt;
  final String updatedAt;

  Student copyWith({
    String? matricule,
    String? fullName,
    String? qrToken,
    bool? active,
    String? updatedAt,
  }) {
    return Student(
      id: id,
      sessionId: sessionId,
      matricule: matricule ?? this.matricule,
      fullName: fullName ?? this.fullName,
      qrToken: qrToken ?? this.qrToken,
      active: active ?? this.active,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'session_id': sessionId,
        'matricule': matricule,
        'full_name': fullName,
        'qr_token': qrToken,
        'active': active ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory Student.fromMap(Map<String, Object?> m) => Student(
        id: m['id']! as String,
        sessionId: m['session_id']! as String,
        matricule: m['matricule']! as String,
        fullName: m['full_name']! as String,
        qrToken: m['qr_token']! as String,
        active: ((m['active'] as int?) ?? 1) == 1,
        createdAt: m['created_at']! as String,
        updatedAt: m['updated_at']! as String,
      );
}
