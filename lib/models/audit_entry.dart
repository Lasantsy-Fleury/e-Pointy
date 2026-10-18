/// Entrée du journal des modifications importantes
/// (imports, corrections, changements de statut, restaurations…).
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.sessionId,
    required this.at,
    required this.actor,
    required this.action,
    required this.details,
  });

  final String id;
  final String sessionId;
  final String at;
  final String actor;
  final String action;
  final String details;

  Map<String, Object?> toMap() => {
        'id': id,
        'session_id': sessionId,
        'at': at,
        'actor': actor,
        'action': action,
        'details': details,
      };

  factory AuditEntry.fromMap(Map<String, Object?> m) => AuditEntry(
        id: m['id']! as String,
        sessionId: m['session_id']! as String,
        at: m['at']! as String,
        actor: m['actor']! as String,
        action: m['action']! as String,
        details: m['details']! as String,
      );
}
