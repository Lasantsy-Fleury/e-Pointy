import 'dart:convert';

/// Modèle de journée réutilisable (ex. « 3 repas + 2 eaux »).
/// Le modèle reste indépendant des journées déjà préparées.
class DayTemplate {
  const DayTemplate({
    required this.id,
    required this.sessionId,
    required this.name,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String sessionId;
  final String name;

  /// Liste de [{name, startTime, endTime, category, instructions,
  /// allowMultiple, maxPassages}]
  final List<Map<String, dynamic>> items;
  final String createdAt;
  final String updatedAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'session_id': sessionId,
        'name': name,
        'items_json': jsonEncode(items),
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory DayTemplate.fromMap(Map<String, Object?> m) => DayTemplate(
        id: m['id']! as String,
        sessionId: m['session_id']! as String,
        name: m['name']! as String,
        items: (jsonDecode(m['items_json']! as String) as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        createdAt: m['created_at']! as String,
        updatedAt: m['updated_at']! as String,
      );
}
