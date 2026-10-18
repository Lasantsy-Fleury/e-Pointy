# Guide de synchronisation (relais entre appareils)

## Principe
Transfert par **fichier `.mipointy`** (JSON, versionné `format: mipointy-bundle`).
Aucune connexion Internet nécessaire. Le fichier peut être transféré par tout
moyen disponible sur les appareils.

## Données transférées
- Session, étudiants (avec remappage par matricule si IDs diffèrent).
- Types d'éléments, journées (remappage par libellé), distributions
  (remappage par jour+nom).
- **Pointages** (idempotents) et **conflits** existants.
- Journal et configuration nécessaire à la lecture.

## Sécurité du fichier
- **SHA-256** calculé sur le `payload` et vérifié à l'import (`checksumOk`).
- Le fichier est rejeté si l'empreinte ne correspond pas.
- Aucune donnée inutile étrangère à la session n'est supposée ; le fichier est
  un bundle auto-contenu de la session concernée.

## Envoi
1. Appareil d'origine : `Réglages > Transferts entre appareils > Envoyer mes pointages`.
2. Choisir la session si nécessaire, générer le fichier.
3. Partager (Bluetooth, câble, Android Share, fichiers, messagerie hors-ligne...).

## Réception
1. Appareil cible : `Accueil > Recevoir une session` (ou `Réglages > Transferts > Recevoir...` selon parcours).
2. Sélectionner le fichier `.mipointy`.
3. Aperçu : nom de la session, générateur, date, nombre d'étudiants/
   distributions/pointages, `Nouvelle session` ou existante, intégrité.
4. Confirmer fusion (`Fusionner`) : ajoute, remappe, déclare les conflits si
   des pointages valides existent déjà pour le même étudiant+distribution.
5. Rapport : sessions/étudiants/journées/distributions/pointages ajoutés/mis à
   jour, pointages ignorés (déjà connus), conflits créés, anomalies.

## Fusion et remappage
- **Idempotence** : un pointage avec le même `id` n'est jamais réappliqué.
- **Sessions** : si ID inconnu mais même `token` → incompatible (ignorer).
- **Étudiants** : correspondance par `matricule` si ID différent.
- **Journées** : correspondance par `label` (normalisé).
- **Distributions** : correspondance par (jour mappé + `name` normalisé).
- **Pointages** : si un **pointage validé** existe déjà localement pour
  (étudiant mappé, distribution mappée), le pointage entrant devient
  `doublon_potentiel` et un **conflit** est créé (pas de double-comptage).

## Résolution des conflits
`Réglages > Doublons et conflits` → pour chaque conflit :
- **Garder le pointage local** : le pointage entrant reste en
  `doublon_potentiel`, aucun changement aux compteurs.
- **Garder le pointage reçu** : annuler d'abord le pointage local **validé**
  (avec motif obligatoire, libérant l'index unique) puis passer le pointage
  importé en `valide`.

La trace complète reste consultable (journal, historique étudiant).

## Sauvegarde / Restauration
- **Sauvegarder** : `Réglages > Sauvegarde et restauration > Sauvegarder
  la session` → génère un `.mipointy` complet (toutes les données).
- **Restaurer** : même écran → sélectionner un fichier. Deux modes :
  - **Fusionner** : ajoute sans supprimer de pointages existants.
  - **Remplacer** : nettoie les données de la session concernée dans le bundle
    avant d'importer (action protégée par confirmation). À utiliser avec
    précaution.

## Bonnes pratiques
- Lors d'un **relais** : envoyer un bundle **après** avoir terminé ses scans,
  réceptionner avant de reprendre. Puis envoyer à nouveau si d'autres scans
  ont eu lieu (idempotent).
- Ne jamais supposer l'heure comme unique critère de tri : l'identifiant
  d'événement (`id`) prime.
- Si un transfert est interrompu ou répété : **aucun doublon** n'est créé.
- Toujours vérifier que `Empreinte vérifiée` apparaît à l'aperçu.
