/// Rapport de fusion après un transfert ou une restauration.
class MergeReport {
  MergeReport({
    required this.sessionNames,
    this.sessionsAdded = 0,
    this.sessionsUpdated = 0,
    this.studentsAdded = 0,
    this.studentsUpdated = 0,
    this.daysAdded = 0,
    this.daysUpdated = 0,
    this.distributionsAdded = 0,
    this.distributionsUpdated = 0,
    this.pointagesApplied = 0,
    this.pointagesSkipped = 0,
    this.pointagesConflicts = 0,
    this.conflictsRecorded = 0,
    this.replaced = false,
    List<String>? anomalies,
    List<String>? infos,
  })  : anomalies = anomalies ?? <String>[],
        infos = infos ?? <String>[];

  final List<String> sessionNames;
  int sessionsAdded;
  int sessionsUpdated;
  int studentsAdded;
  int studentsUpdated;
  int daysAdded;
  int daysUpdated;
  int distributionsAdded;
  int distributionsUpdated;

  /// Pointages nouvellement appliqués sur cet appareil.
  int pointagesApplied;

  /// Événements déjà présents (idempotence : répétition sans doublon).
  int pointagesSkipped;

  /// Pointages entrants enregistrés comme doublons potentiels.
  int pointagesConflicts;
  int conflictsRecorded;
  bool replaced;

  /// Problèmes rencontrés (incompatibilités, données orphelines…).
  final List<String> anomalies;

  /// Informations de contexte pour l'utilisateur.
  final List<String> infos;

  int get totalEntities =>
      sessionsAdded +
      sessionsUpdated +
      studentsAdded +
      studentsUpdated +
      daysAdded +
      daysUpdated +
      distributionsAdded +
      distributionsUpdated +
      pointagesApplied;

  /// Résumé lisible (français) destiné à l'utilisateur.
  String get summary {
    final parts = <String>[];
    if (sessionsAdded > 0) parts.add('$sessionsAdded session(s) ajoutée(s)');
    if (sessionsUpdated > 0) parts.add('$sessionsUpdated mise(s) à jour');
    if (studentsAdded > 0) parts.add('$studentsAdded étudiant(s) ajouté(s)');
    if (studentsUpdated > 0) {
      parts.add('$studentsUpdated étudiant(s) mis à jour');
    }
    if (daysAdded > 0) parts.add('$daysAdded jour(s) ajouté(s)');
    if (distributionsAdded > 0) {
      parts.add('$distributionsAdded distribution(s) ajoutée(s)');
    }
    if (pointagesApplied > 0) parts.add('$pointagesApplied pointage(s)');
    if (pointagesSkipped > 0) {
      parts.add('$pointagesSkipped déjà connu(s)');
    }
    if (pointagesConflicts > 0) {
      parts.add('$pointagesConflicts doublon(s) à vérifier');
    }
    if (parts.isEmpty) return 'aucun changement';
    return parts.join(', ');
  }
}

/// Aperçu d'un bundle lu avant de lancer une fusion.
class BundlePreview {
  const BundlePreview({
    required this.kind,
    required this.sessionNames,
    required this.generatedAt,
    required this.sourceDevice,
    required this.studentCount,
    required this.distributionCount,
    required this.pointageCount,
    required this.checksumOk,
    required this.isNewSession,
    required this.version,
  });

  final String kind;
  final List<String> sessionNames;
  final String generatedAt;
  final String sourceDevice;
  final int studentCount;
  final int distributionCount;
  final int pointageCount;
  final bool checksumOk;

  /// true si aucune session du bundle n'existe encore sur cet appareil.
  final bool isNewSession;
  final int version;
}
