# Rapport de tests

## État
- `flutter analyze` : **aucun problème**.
- `flutter test` : **20 tests, tous réussis** (horodatage 00:10 +20).
- Tests manuels vérifiés : analyse statique, import/export, transfert,
  prévention doublons, idempotence.

## Campagne de tests

### Services & logique
| Test | Intention | Résultat |
|---|---|---|
| `test/excel_import_test.dart` | Analyse Excel (en-têtes, validations, doublons internes, valeurs numériques, normalisation). | OK |
| `test/utils_test.dart` | Normalisation noms, accents, matricule texte, recherche `searchKey`, formatage. | OK |
| `test/qr_test.dart` | `QrService` encode/décode, validation préfixe. | OK |
| `test/stats_test.dart` | Comptage servis/restants/taux à partir de pointages uniques. | OK |
| `test/scan_duplicate_test.dart` | Prévention doublon (index unique), multi-passages (allowMultiple < max). | OK |
| `test/sync_merge_test.dart` | Idempotence (réception répétée), conflit double appareil → `doublon_potentiel` + conflit enregistré. | OK |

### UI (smoke test)
| Test | Intention | Résultat |
|---|---|---|
| `test/widget_test.dart` | Boot app avec DB isolée, écran d'accueil (titre + état vide). | OK |

### End-to-end (fichiers d'exemple)
| Test | Intention | Résultat |
|---|---|---|
| `test/sample_files_test.dart` | Import Excel exemple (8 lignes, sans erreur, matricule `00123` préservé). Réception bundle `.mipointy` (vérification SHA-256, fusion, idempotence). Statistiques correctes. | OK |

## Vérifications critiques

- **Hors ligne** : pas de dépendance réseau ; tests utilisent FFI in-memory DB.
- **Unicité** : index partiel sur `(distribution_id,student_id)` WHERE `status='valide'` testé.
- **Idempotence transfert** : réimporter le même bundle → `pointagesSkipped == pointagesApplied` (aucun nouveau pointage).
- **Conflits** : réception d'un pointage validé pour le même étudiant → conflit + `doublon_potentiel`.
- **Matricules texte** : préservation de `00123` via `matriculeFromCell` (nombres et chaînes). 
- **Fusion indépendante de l'ordre** : remappage par matricule/label/nom (persistence des choix).
- **Aucune perte** : pointages valides ne sont jamais supprimés par fusion ; remplacement protégé.

## Commandes
```bash
flutter analyze
flutter test  # 20 tests
dart run tool/generate_samples.dart  # régénère samples/
```

Dernier passage : 2026-10-17 (compilation/FFI sur Windows).
