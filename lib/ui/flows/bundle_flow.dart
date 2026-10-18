import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants.dart';
import '../../data/app_database.dart';
import '../../models/enums.dart';
import '../../models/merge_report.dart';
import '../../services/file_output.dart';
import '../../services/sync_service.dart';
import '../format.dart';
import '../screens/merge_report_screen.dart';
import '../widgets/app_widgets.dart';

/// Flux complet de réception d'un fichier de transfert ou de sauvegarde :
/// sélection du fichier, vérification de l'empreinte, aperçu, confirmation,
/// fusion ou remplacement, puis rapport.
Future<MergeReport?> importBundleFlow(
  BuildContext context, {
  required String actor,
  bool allowReplaceChoice = false,
  String title = 'Recevoir des données',
}) async {
  final path = await FileOutput.pickFile(
      extensions: [AppConstants.bundleExtension, 'json']);
  if (path == null) return null;
  if (!context.mounted) return null;

  final service = SyncService(AppDatabase.instance);
  final BundleEnvelope envelope;
  try {
    envelope = await service.readBundleFile(path);
  } catch (e) {
    if (context.mounted) {
      showMessage(context, '$e', error: true);
    }
    return null;
  }
  if (!context.mounted) return null;

  final preview = await service.previewFor(envelope);
  if (!context.mounted) return null;

  if (!preview.checksumOk) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fichier corrompu'),
        content: const Text(
            'L’empreinte de vérification ne correspond pas : le fichier est '
            'incomplet ou a été modifié. Aucune donnée n’a été importée.\n\n'
            'Relancez le transfert depuis l’appareil source.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
    return null;
  }

  var mode = MergeMode.fusionner;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              InfoRow('Type', preview.kind == AppConstants.bundleKindBackup
                  ? 'Sauvegarde' : 'Transfert'),
              InfoRow('Session(s)', preview.sessionNames.join(', ')),
              InfoRow('Appareil source', preview.sourceDevice),
              InfoRow('Généré le', formatIso(preview.generatedAt)),
              InfoRow('Étudiants', '${preview.studentCount}'),
              InfoRow('Distributions', '${preview.distributionCount}'),
              InfoRow('Pointages', '${preview.pointageCount}'),
              InfoRow('Empreinte', preview.checksumOk ? 'Vérifiée ✓' : 'Invalide'),
              if (!preview.isNewSession)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Cette session existe déjà sur cet appareil : les données '
                    'seront fusionnées sans supprimer les pointages existants.',
                    style: TextStyle(fontSize: 13),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Nouvelle session : l’ensemble de la session sera créé sur '
                    'cet appareil (mode hors ligne).',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              if (allowReplaceChoice) ...[
                const SizedBox(height: 14),
                const Text('Mode de restauration',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                RadioGroup<MergeMode>(
                  groupValue: mode,
                  onChanged: (v) => setState(() => mode = v!),
                  child: Column(
                    children: [
                      RadioListTile<MergeMode>(
                        value: MergeMode.fusionner,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Fusionner (conservateur)'),
                        subtitle: const Text(
                            'Ajoute et complète sans rien supprimer'),
                      ),
                      RadioListTile<MergeMode>(
                        value: MergeMode.remplacer,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Remplacer les données locales'),
                        subtitle: const Text(
                            'Supprime les données locales de la session puis '
                            'installe la sauvegarde'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(mode == MergeMode.remplacer
                ? 'Remplacer…'
                : 'Fusionner maintenant'),
          ),
        ],
      ),
    ),
  );
  if (confirmed != true || !context.mounted) return null;

  if (mode == MergeMode.remplacer) {
    final again = await confirmAction(
      context,
      title: 'Remplacer les données locales ?',
      message: 'Les étudiants, distributions et pointages locaux de cette '
          'session seront supprimés et remplacés par la sauvegarde. '
          'Cette action est irréversible.',
      confirmLabel: 'Remplacer définitivement',
      danger: true,
    );
    if (!again || !context.mounted) return null;
  }

  MergeReport report;
  try {
    report = await service.mergeBundle(envelope, mode: mode);
  } catch (e) {
    if (context.mounted) {
      showMessage(context, 'Échec de la fusion : $e', error: true);
    }
    return null;
  }
  if (!context.mounted) return report;
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => MergeReportScreen(report: report)),
  );
  return report;
}

/// Résultat d'un envoi : fichier créé et état du partage.
class BundleExportResult {
  const BundleExportResult({required this.path, required this.shared});
  final String path;

  /// true uniquement si la plateforme a confirmé que le partage a abouti.
  final bool shared;
}

/// Flux d'envoi : construit le bundle, écrit le fichier et ouvre le partage.
/// Retourne null si la préparation a échoué.
Future<BundleExportResult?> exportBundleFlow(
  BuildContext context, {
  required String sessionId,
  required String deviceId,
  required String deviceName,
  required String kind,
}) async {
  final service = SyncService(AppDatabase.instance);
  final Map<String, dynamic> bundle;
  try {
    bundle = await service.buildBundle(
      sessionId: sessionId,
      kind: kind,
      deviceId: deviceId,
      deviceName: deviceName,
    );
  } catch (e) {
    if (context.mounted) {
      showMessage(context, 'Échec de préparation : $e', error: true);
    }
    return null;
  }

  final now = DateTime.now();
  final stamp = '${now.year}${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}_'
      '${now.hour.toString().padLeft(2, '0')}'
      '${now.minute.toString().padLeft(2, '0')}';
  final file = await service.writeBundleFile(
    bundle,
    '${kind == AppConstants.bundleKindBackup ? 'sauvegarde' : 'transfert'}_'
        '${sessionId.substring(0, 8)}_$stamp.${AppConstants.bundleExtension}',
  );

  if (!context.mounted) {
    return BundleExportResult(path: file.path, shared: false);
  }
  final result = await FileOutput.shareFile(
    file.path,
    text: kind == AppConstants.bundleKindBackup
        ? 'Sauvegarde Mipointy de la session. Conservez ce fichier en lieu sûr.'
        : 'Transfert Mipointy : ouvrez ce fichier sur l’autre appareil '
            '(Transfert → Recevoir des données).',
  );
  return BundleExportResult(
    path: file.path,
    shared: result.status == ShareResultStatus.success,
  );
}
