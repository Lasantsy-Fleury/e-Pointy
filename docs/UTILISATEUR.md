# Guide utilisateur (résumé)

## Vue d'ensemble
Mipointy fonctionne **hors ligne**. Tout est stocké localement sur l'appareil.
Le relais entre pointeurs se fait par un fichier `.mipointy` à recevoir/envoyer.

## Démarrage
1. Créer une session (Accueil > Nouvelle session).
2. Importer le fichier Excel (`.xlsx`) dans **Réglages > Gérer les étudiants**.
3. Vérifier le rapport d'erreurs avant confirmation (matricules/noms
   manquants, doublons internes au fichier).
4. Configurer les journées et distributions (Réglages > Planifier...).
5. Générer ou imprimer les QR codes (Réglages > QR codes des étudiants).
6. Ouvrir la session → aller dans **Distribution** et sélectionner la
   distribution active.

## Onglets d'une session
| Onglet | Description |
|---|---|
| Distribution | Sélection de la journée/distribution, compteur servis/restants, accès au scan. |
| Scanner | Lecture des QR codes (accessible depuis Distribution ou directement si visible selon rôle). |
| Étudiants | Liste avec recherche (matricule/nom), filtres « tous/servis/restants/inactifs », fiche étudiant. |
| Suivi | Récapitulatif par jour/distribution, bilan session, doublons à vérifier. |
| Réglages | Configuration, transferts, exports/sauvegarde, journal, sécurité.

## Rôles
- **Responsable** : configuration, import Excel, QR, clôtures/corrections (selon l'audit), sauvegarde/restauration.
- **Pointeur** : scan, recherche manuelle, consultation ; selon configuration d'un code PIN.
- **Consultation seule** : uniquement consultation, pas de pointage.

## Pointage
- Scanner un QR conforme à `MPT1|sessionToken|studentToken`.
- Résultats : *Pointage enregistré*, *Déjà servi*, *Étudiant inconnu*,
  *Mauvaise session*, *Distribution clôturée*, *Erreur d'enregistrement*,
  *QR invalide*, *Aucune distribution active*.
- Recherche manuelle (Étudiants → rechercher → pointer).
- **Un seul pointage validé** par étudiant et par distribution (multi-passages si configuré).
- La trace est conservée (aucune suppression silencieuse). Une annulation exige un motif.

## Relais entre appareils
1. Appareil A (qui a pointé) → **Réglages > Transferts > Envoyer mes pointages** : crée un fichier `.mipointy`.
2. Partager ce fichier (Bluetooth, câble, share Android, carte SD).
3. Appareil B → **Accueil > Recevoir** (ou **Réglages > Envoyer mes pointages** dans certains parcours) puis choisir le fichier.
4. Prévisualiser → Fusionner. Les conflits (même étudiant pointé sur les deux appareils) sont listés dans **Réglages > Doublons et conflits** avec résolution explicite.
5. Idempotent : réimporter le même fichier n'ajoute rien.

## Exports & sauvegarde
- **Exports Excel/CSV** : liste étudiants, récap distribution, détail pointages, non-servis, bilan, anomalies. Matricules préservés au format texte.
- **Sauvegarde** : génère un `.mipointy` complet (préconisé avant clôture / pour archivage).
- **Restauration** : mode *Remplacer* (protégé par confirmation) ou *Fusionner* selon cas.

## Conseils
- Toujours vérifier le **rapport d'import Excel** avant de confirmer.
- Les **doubles pointages** ne gonflent jamais les compteurs : seuls les pointages **validés** uniques sont comptés.
- Le **QR ne contient aucune donnée personnelle**.
- Après transfert, vérifier la bannière « En attente d'envoi ».
