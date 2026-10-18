/// Type d'élément distribué, librement défini par le responsable.
/// Exemples : petit-déjeuner, déjeuner, dîner, eau, collation, kit…
class ItemType {
  const ItemType({
    required this.id,
    required this.sessionId,
    required this.name,
    this.category,
    this.unit,
    this.description,
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String sessionId;
  final String name;

  /// Catégorie libre : repas | eau | collation | kit | autre.
  final String? category;
  final String? unit;
  final String? description;
  final bool active;
  final String createdAt;
  final String updatedAt;

  ItemType copyWith({
    String? name,
    String? category,
    String? unit,
    String? description,
    bool? active,
    String? updatedAt,
  }) {
    return ItemType(
      id: id,
      sessionId: sessionId,
      name: name ?? this.name,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      description: description ?? this.description,
      active: active ?? this.active,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'session_id': sessionId,
        'name': name,
        'category': category,
        'unit': unit,
        'description': description,
        'active': active ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory ItemType.fromMap(Map<String, Object?> m) => ItemType(
        id: m['id']! as String,
        sessionId: m['session_id']! as String,
        name: m['name']! as String,
        category: m['category'] as String?,
        unit: m['unit'] as String?,
        description: m['description'] as String?,
        active: ((m['active'] as int?) ?? 1) == 1,
        createdAt: m['created_at']! as String,
        updatedAt: m['updated_at']! as String,
      );
}
