# QR codes et badges

## Format
Le QR code contient uniquement deux tokens courts, sans données personnelles :

```text
MPT1|<sessionToken>|<studentQrToken>
```

- `MPT1` = préfixe de l'application (constante `AppConstants.qrPrefix`)
- `sessionToken` = token court de la session (généré à la création de la session)
- `studentQrToken` = token unique par étudiant dans la session (généré à
  l'import ou à la création manuelle)

**Principe :** identification hors ligne vérifiable (session + étudiant). Le nom
et le matricule ne sont pas exposés dans le QR.

## Génération des badges (PDF)
`Réglages > QR codes des étudiants (PDF)` : génère une planche A4 (3 colonnes)
avec pour chaque badge :

- Nom complet (optionnel, configurable).
- Matricule.
- QR code (taille 96×96).
- Nom de la session.
- Statut « DÉSACTIVÉ » si étudiant désactivé.

Le fichier est enregistré et peut être partagé/imprimé.

## Validation à la lecture
`ScanService.decode(raw)` vérifie :
- 3 parties séparées par `|`
- préfixe == `MPT1`
- tokens non vides

Résultats possibles après scan (voir guide utilisateur) :
`enregistre`, `dejaServi`, `etudiantInconnu`, `mauvaiseSession`,
`distributionFermee`, `erreurEnregistrement`, `qrInvalide`, `sansDistribution`,
`desactive`.

## Tests associés
- `test/qr_test.dart` : encode/décode aller-retour, formats invalides.
