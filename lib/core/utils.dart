import 'dart:math';

import 'package:uuid/uuid.dart';

/// Génère un identifiant unique (UUID v4).
String newId() => const Uuid().v4();

/// Génère un court code aléatoire lisible (sans caractères ambiguïs).
/// Utilisé pour les tokens de session et les tokens QR étudiants.
String newToken(int length) {
  const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  final rand = Random.secure();
  return List.generate(length, (_) => chars[rand.nextInt(chars.length)])
      .join();
}

/// Date-heure courante en UTC au format ISO 8601.
String nowUtcIso() => DateTime.now().toUtc().toIso8601String();

/// Normalise un nom : suppression des espaces superflus, sans altérer le nom.
String normalizeName(String value) => value.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Supprime les diacritiques pour des comparaisons robustes.
String removeDiacritics(String input) {
  const map = {
    'a': 'àâäáãå', 'e': 'éèêë', 'i': 'íìîï', 'o': 'óòôöõ',
    'u': 'úùûü', 'n': 'ñ', 'c': 'ç', 'y': 'ýÿ',
    'A': 'ÀÂÄÁÃÅ', 'E': 'ÉÈÊË', 'I': 'ÍÌÎÏ', 'O': 'ÓÒÔÖÕ',
    'U': 'ÚÙÛÜ', 'N': 'Ñ', 'C': 'Ç',
  };
  var result = input;
  map.forEach((plain, accents) {
    for (final c in accents.split('')) {
      result = result.replaceAll(c, plain);
    }
  });
  return result;
}

/// Clé de recherche insensible à la casse et aux accents.
String searchKey(String input) => removeDiacritics(input.trim()).toLowerCase();

/// Convertit une valeur de cellule Excel en matricule texte.
/// Préserve les zéros initiaux (12.0 -> « 12 » ; « 00123 » reste « 00123 »).
String matriculeFromCell(dynamic value) {
  if (value == null) return '';
  if (value is String) return value.trim();
  if (value is num) {
    if (value is double && value == value.roundToDouble() && !value.isInfinite) {
      return value.truncate().toString();
    }
    return value.toString();
  }
  return value.toString().trim();
}

/// Nettoie un nom de fichier pour un usage sûr sur Android / Windows.
String sanitizeFileName(String input) {
  final cleaned = removeDiacritics(input)
      .replaceAll(RegExp(r'[^A-Za-z0-9 _.-]'), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), '_');
  return cleaned.isEmpty ? 'export' : cleaned;
}

/// Formatte un pourcentage entier.
String percentLabel(int value) => '$value %';

/// Extension locale : premier élément ou null (sans dépendance externe).
extension IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
