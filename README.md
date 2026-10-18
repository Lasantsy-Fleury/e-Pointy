# Mipointy

Application mobile Flutter de **pointage hors ligne des distributions**
(petit-déjeuner, déjeuner, dîner, eau, collations…) destinées aux étudiants
pendant un voyage d'étude.

L'objectif : savoir en temps réel **qui a reçu quoi, quand et pour quelle
distribution**, tout en restant pleinement utilisable **sans connexion
Internet**, et en permettant à plusieurs pointeurs de se relayer sur des
appareils différents sans perdre de données.

---

## 1. Fonctionnalités principales

- **Sessions de voyage** : chaque voyage est une session isolée (étudiants,
  distributions, pointages). Statuts : préparation, en cours, clôturée,
  archivée.
- **Import Excel `.xlsx`** avec deux colonnes fonctionnelles `Matricule` et
  `Nom et Prénoms` (ordre reconnu automatiquement). Aperçu, validation et
  rapport d'erreurs **avant** tout import. Les matricules restent du texte
  (zéros initiaux préservés).
- **Distributions configurables** : rien n'est codé en dur. Types d'éléments
  libres, journées, créneaux horaires indicatifs, modèles de journée
  réutilisables, statuts à venir / ouverte / suspendue / clôturée.
- **QR codes** sans donnée personnelle : `MPT1|<token session>|<token étudiant>`.
  Génération de **planches PDF A4** prêtes à imprimer.
- **Scan et pointage** hors ligne, avec résultats distincts : *enregistré*,
  *déjà servi*, *étudiant inconnu*, *mauvaise session*, *distribution fermée*,
  *QR invalide*, *erreur d'enregistrement*. Recherche **manuelle** de secours.
- **Prévention des doublons** : un seul pointage validé par étudiant et par
  distribution (index unique partiel en base). Les distributions « multi-
  passages » sont configurables (quantité/passages restants affichés).
- **Tableau de bord & suivi** : servis / restants / taux, récapitulatif par
  journée, par distribution, par session ; listes servis / restants / manuels /
  doublons / en attente de synchronisation ; fiche étudiant.
- **Transfert entre appareils** (relais, sauvegarde/restauration) par fichier
  `.mipointy` : fusion **idempotente**, **sans perte de pointages valides**,
  détection explicite des conflits.
- **Exports** `.xlsx` et `.csv` (bilan, détail des pointages, non-servis,
  anomalies) et **sauvegarde/restauration** hors ligne.
- **Traçabilité** : journal d'audit, annulation avec motif obligatoire,
  historique par étudiant et par distribution.

Interface **en français**, gros boutons, statuts signalés par **couleur + icône
+ texte**, confirmations pour les actions risquées.

---

## 2. Prérequis

- Flutter **stable** (développé et testé avec Flutter 3.47 / Dart 3.13).
- Android : SDK Android + un appareil ou émulateur (plateforme prioritaire).
- Windows : pour lancer les tests sur poste, `sqflite_common_ffi` fournit
  SQLite (aucune installation supplémentaire). Construire l'application
  Windows demande Visual Studio (facultatif : Android suffit).

---

## 3. Lancer l'application

```bash
flutter pub get
flutter run            # appareil/émulateur connecté
# ou cibler explicitement :
flutter run -d android
```

Au premier lancement : ouvrez **Réglages** (icône engrenage en haut à droite)
pour définir le nom de l'appareil, le rôle (Responsable / Pointeur /
Consultation) et, si besoin, un code PIN.

---

## 4. Construire l'APK Android

```bash
flutter build apk --release
# APK : build/app/outputs/flutter-apk/app-release.apk
```

Pour un APK plus léger par architecture : `flutter build apk --split-per-abi`.

---

## 5. Fichiers d'exemple

Le dossier `samples/` contient :

| Fichier | Usage |
|---|---|
| `samples/exemple_etudiants_mipointy.xlsx` | Fichier d'import conforme (8 étudiants, zéros initiaux testés). |
| `samples/session_exemple.mipointy` | Session fictive (2 journées, 5 distributions/jour, 8 étudiants, pointages) à **recevoir** depuis l'écran d'accueil → bouton *Recevoir*. |

Régénérer ces fichiers :

```bash
dart run tool/generate_samples.dart
```

Ces fichiers sont validés par les tests (`test/sample_files_test.dart`).

---

## 6. Tests

```bash
flutter test          # 20 tests : services, modèle métier, fichiers d'exemple
flutter analyze       # aucun problème attendu
```

Le détail de la campagne et des résultats se trouve dans
[`docs/TESTS.md`](docs/TESTS.md).

---

## 7. Documentation

- [`docs/UTILISATEUR.md`](docs/UTILISATEUR.md) — guide du responsable et des pointeurs.
- [`docs/SYNCHRONISATION.md`](docs/SYNCHRONISATION.md) — relais entre appareils, fusion, conflits, sauvegarde.
- [`docs/QR.md`](docs/QR.md) — format des QR codes et impression des badges.
- [`docs/TESTS.md`](docs/TESTS.md) — rapport de tests (hors ligne, doublons, relais, exports).
- [`brief.md`](brief.md) — cahier des charges d'origine.

---

## 8. Architecture du code

```
lib/
  core/          constantes, utilitaires (recherche, accents, matricules)
  models/        entités (session, étudiant, journée, distribution, pointage…)
  data/          base SQLite (schéma) + DAO
  services/      import Excel, scan, statistiques, synchronisation, exports, QR
  state/         AppSettings (appareil/rôle), SessionController (état métier)
  ui/            thème, formats, widgets, écrans, parcours
  main.dart      point d'entrée
```

### Choix techniques justifiés

- **SQLite via `sqflite`** : base locale persistante, transactionnelle et
  off-line. `sqflite_common_ffi` sert pour le développement/tests sur poste.
- **Pas de clés étrangères en base** : l'intégrité est gérée au niveau
  applicatif pour que les fusions entre appareils soient **indépendantes de
  l'ordre d'insertion** (le remappage se fait par clés naturelles).
- **Unicité métier** : index unique partiel
  `idx_pointages_unique_valide ON pointages(distribution_id, student_id)
  WHERE status = 'valide'` — impossible d'avoir deux pointages validés pour
  le même couple étudiant/distribution, même en cas de course.
- **Transfert par fichier `.mipointy`** : fonctionne sans Internet, par
  n'importe quel moyen (partage Android, câble, carte SD, messagerie). Format
  JSON versionné + empreinte **SHA-256** pour détecter toute corruption.
- **Idempotence** : chaque pointage possède un identifiant unique stable ; un
  événement déjà connu n'est jamais réappliqué.
- **État** : `provider` + `ChangeNotifier` (`AppSettings`, `SessionController`).

### Modèle de données (tables)

`sessions`, `students`, `item_types`, `days`, `distributions`, `day_templates`,
`pointages`, `conflicts`, `audit_log`.

---

## 9. Règles métier par défaut (à ajuster selon l'organisateur)

1. Matricule unique **au sein d'une session**, toujours traité comme du texte.
2. Un seul pointage **validé** par étudiant et par distribution.
3. Les distributions peuvent autoriser plusieurs passages (quantité max
   configurable) ; les passages restants sont affichés.
4. Pointage **manuel** autorisé en secours (marqué comme tel).
5. Une correction/annulation **conserve la trace** et exige un motif ; elle est
   réservée aux rôles autorisés.
6. Un pointage n'est **réussi** que si son écriture locale est **confirmée**.
7. La liste « servis » ne compte que les étudiants **uniques** validés, jamais
   le nombre d'événements reçus après synchronisation.
8. L'application n'affiche jamais « synchronisé » avant vérification.
