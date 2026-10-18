import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/app_database.dart';
import '../../services/export_service.dart';
import '../../services/file_output.dart';
import '../../state/session_controller.dart';
import '../widgets/app_widgets.dart';

/// Exports `.xlsx` et `.csv` : liste des étudiants, récapitulatifs,
/// bilan, étudiants non servis, anomalies.
class ExportsScreen extends StatefulWidget {
  const ExportsScreen({super.key});

  @override
  State<ExportsScreen> createState() => _ExportsScreenState();
}

class _ExportsScreenState extends State<ExportsScreen> {
  ExportKind _kind = ExportKind.etudiants;
  bool _asCsv = false;
  bool _busy = false;

  Future<void> _export() async {
    final controller = context.read<SessionController>();
    final sessionId = controller.sessionId;
    if (sessionId == null) return;
    setState(() => _busy = true);
    try {
      final service = ExportService(AppDatabase.instance);
      final path = await service.export(
        sessionId: sessionId,
        kind: _kind,
        asCsv: _asCsv,
      );
      if (!mounted) return;
      final result = await FileOutput.shareFile(
        path,
        text: 'Export Mipointy — ${_kind.label}',
      );
      if (!mounted) return;
      showMessage(
        context,
        result.status == ShareResultStatus.success
            ? 'Export transmis.'
            : 'Export créé : $path',
        success: true,
      );
    } catch (e) {
      if (mounted) showMessage(context, 'Échec de l’export : $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SessionController>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Exports')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Text('Contenu à exporter',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant)),
              ),
              RadioGroup<ExportKind>(
                groupValue: _kind,
                onChanged: (v) => setState(() => _kind = v!),
                child: Column(
                  children: [
                    for (final kind in ExportKind.values)
                      RadioListTile<ExportKind>(
                        value: kind,
                        title: Text(kind.label),
                        subtitle: Text(_description(kind),
                            style: const TextStyle(fontSize: 12.5)),
                      ),
                  ],
                ),
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('Format CSV (au lieu d’Excel)'),
                subtitle: const Text(
                    'Le CSV est encodé en UTF-8 avec BOM : les accents sont '
                    'reconnus par Excel et libreoffice.'),
                value: _asCsv,
                onChanged: (v) => setState(() => _asCsv = v),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Les matricules restent au format texte : les zéros '
                  'initiaux (ex. 00123) sont préservés.',
                  style: TextStyle(fontSize: 12.5),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FilledButton.icon(
                  onPressed: _busy ? null : _export,
                  icon: const Icon(Icons.download_outlined),
                  label: Text(
                      'Générer le fichier ${_asCsv ? '.csv' : '.xlsx'}'),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed: controller.sessionId == null
                      ? null
                      : () async {
                          final service =
                              ExportService(AppDatabase.instance);
                          final path = await service.writeSampleImportFile();
                          if (!context.mounted) return;
                          await FileOutput.shareFile(path,
                              text: 'Exemple de fichier d’import Mipointy');
                        },
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('Exemple de fichier d’import Excel'),
                ),
              ),
            ],
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black26,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  String _description(ExportKind kind) => switch (kind) {
        ExportKind.etudiants =>
          'Matricule, nom, statut et nombre de distributions reçues.',
        ExportKind.etudiantsAvecQr =>
          'Liste des étudiants avec leurs QR codes (Excel). PDF disponible via génération de badges.',
        ExportKind.recapDistributions =>
          'Une ligne par distribution : inscrits, servis, restants, taux, doublons.',
        ExportKind.detailPointages =>
          'Tous les pointages : statut, mode, horodatages, appareil, opérateur.',
        ExportKind.nonServis =>
          'Étudiants n’ayant pas reçu une distribution (clôturée ou choisie).',
        ExportKind.bilanGlobal =>
          'Synthèse du voyage et récapitulatif par journée.',
        ExportKind.anomalies =>
          'Doublons, pointages manuels/annulés et journal des modifications.',
      };
}
