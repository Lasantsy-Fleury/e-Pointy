/// Énumérations partagées par toute l'application.
library;

/// Statut d'une session de voyage.
enum SessionStatus {
  preparation('preparation', 'Préparation'),
  enCours('en_cours', 'En cours'),
  cloturee('cloturee', 'Clôturée'),
  archivee('archivee', 'Archivée');

  const SessionStatus(this.code, this.label);
  final String code;
  final String label;

  static SessionStatus fromCode(String? code) => values.firstWhere(
        (s) => s.code == code,
        orElse: () => SessionStatus.preparation,
      );
}

/// Statut d'une distribution.
enum DistributionStatus {
  aVenir('a_venir', 'À venir'),
  ouverte('ouverte', 'Ouverte'),
  suspendue('suspendue', 'Suspendue'),
  cloturee('cloturee', 'Clôturée');

  const DistributionStatus(this.code, this.label);
  final String code;
  final String label;

  static DistributionStatus fromCode(String? code) => values.firstWhere(
        (s) => s.code == code,
        orElse: () => DistributionStatus.aVenir,
      );
}

/// Statut d'un pointage.
enum PointageStatus {
  valide('valide', 'Validé'),
  doublonPotentiel('doublon_potentiel', 'Doublon potentiel'),
  annule('annule', 'Annulé');

  const PointageStatus(this.code, this.label);
  final String code;
  final String label;

  static PointageStatus fromCode(String? code) => values.firstWhere(
        (s) => s.code == code,
        orElse: () => PointageStatus.valide,
      );
}

/// Mode de saisie d'un pointage.
enum ScanMode {
  qr('qr', 'QR code'),
  manuel('manuel', 'Manuel');

  const ScanMode(this.code, this.label);
  final String code;
  final String label;

  static ScanMode fromCode(String? code) => values.firstWhere(
        (s) => s.code == code,
        orElse: () => ScanMode.qr,
      );
}

/// Rôle fonctionnel de l'utilisateur sur cet appareil.
enum UserRole {
  responsable('responsable', 'Responsable'),
  pointeur('pointeur', 'Pointeur'),
  lecture('lecture', 'Consultation seule');

  const UserRole(this.code, this.label);
  final String code;
  final String label;

  static UserRole fromCode(String? code) => values.firstWhere(
        (s) => s.code == code,
        orElse: () => UserRole.pointeur,
      );
}

/// Résultats possibles d'un scan ou d'un pointage manuel.
enum ScanOutcome {
  enregistre('Pointage enregistré'),
  dejaServi('Déjà servi'),
  etudiantInconnu('Étudiant inconnu'),
  mauvaiseSession('Mauvaise session'),
  distributionFermee('Distribution fermée'),
  erreurEnregistrement("Erreur d'enregistrement"),
  qrInvalide('QR invalide'),
  sansDistribution('Aucune distribution active'),
  desactive('Étudiant désactivé');

  const ScanOutcome(this.label);
  final String label;
}

/// Mode de fusion lors de la restauration d'une sauvegarde.
enum MergeMode { fusionner, remplacer }
