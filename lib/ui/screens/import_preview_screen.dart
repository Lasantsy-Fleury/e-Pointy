import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/import_report.dart';
import '../../state/app_settings.dart';
import '../../state/session_controller.dart';
import '../widgets/app_widgets.dart';

/// Aperçu et validation d'un import Excel avant toute écriture.
///
/// Rien n'est importé tant que le responsable n'a pas confirmé : les lignes
/// en erreur et les doublons de fichier sont signalés explicitement.
class ImportPreviewScreen extends StatefulWidget {
  const ImportPreviewScreen({super.key, required this.report});

  final ImportReport report;

  @override
  State<ImportPreviewScreen> createState() => _ImportPreviewScreenState();
}

class _ImportPreviewScreenState extends State<ImportPreviewScreen> {
  ImportMode _mode = ImportMode.fusionner;
  bool _applying = false;
  bool _showAllRows = false;

  Future<void> _apply() async {
    final settings = context.read<AppSettings>();
    if (!settings.canConfigure) {
      showMessage(context, 'Réservé au responsable.', error: true);
      return;
    }
    final report = widget.report;
    final summary = 'Ajoutés : ${report.toAddCount} — mis à jour : '
        '${report.toUpdateCount} — inchangés/ignorés : ${report.ignoredCount}';
    final isReplace = _mode == ImportMode.remplacer;
    final ok = await confirmAction(
      context,
      title: isReplace ? 'Remplacer la liste ?' : 'Appliquer l’import ?',
      message: isReplace
          ? 'La liste locale sera alignée sur le fichier. Les étudiants '
              'absents du fichier seront désactivés (jamais supprimés s’ils '
              'ont des pointages).\n\n$summary'
          : '$summary\n\nLes pointages existants ne sont jamais effacés.',
      confirmLabel: isReplace ? 'Remplacer la liste' : 'Importer',
      danger: isReplace,
    );
    if (!ok || !mounted) return;

    setState(() => _applying = true);
    final controller = context.read<SessionController>();
    try {
      final result = await controller.applyImport(report, _mode);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import terminé'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                InfoRow('Ajoutés', '${result.added}'),
                InfoRow('Mis à jour', '${result.updated}'),
                InfoRow('Renommés', '${result.renamed}'),
                InfoRow('Désactivés', '${result.deactivated}'),
                InfoRow('Supprimés', '${result.deleted}'),
                InfoRow('Ignorés', '${result.ignored}'),
                if (result.nameWarnings.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('Noms modifiés :',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  for (final w in result.nameWarnings.take(20))
                    Text('• $w', style: const TextStyle(fontSize: 13)),
                ],
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showMessage(context, 'Échec de l’import : $e', error: true);
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final scheme = Theme.of(context).colorScheme;
    final rows = _showAllRows
        ? report.rows
        : report.rows.where((r) => r.hasError || r.isDuplicateInFile).toList();
    final problemRows = report.errorRows;

    return Scaffold(
      appBar: AppBar(title: const Text('Aperçu de l’import')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          // ---------- Résumé ----------
          SectionCard(
            title: 'Résumé du fichier',
            icon: Icons.summarize_outlined,
            child: Column(
              children: [
                InfoRow('Feuille', report.sheetName),
                InfoRow('Colonnes',
                    'matricule : ${report.matriculeColumn} — nom : ${report.nameColumn}'),
                InfoRow('Lignes lues', '${report.totalRows}'),
                InfoRow(
                    'À importer', '${report.validCount}', icon: Icons.check_circle_outline),
                InfoRow('Nouveaux', '${report.toAddCount}',
                    icon: Icons.person_add_outlined),
                InfoRow('Mises à jour', '${report.toUpdateCount}',
                    icon: Icons.update),
                InfoRow('Noms modifiés', '${report.renamedCount}',
                    icon: Icons.drive_file_rename_outline),
                InfoRow('Lignes en erreur', '${report.invalidRows.length}',
                    icon: Icons.error_outline),
                InfoRow('Doublons dans le fichier',
                    '${report.duplicateRows.length}',
                    icon: Icons.copy_all_outlined),
              ],
            ),
          ),

          // ---------- Lignes en erreur ----------
          if (problemRows.isNotEmpty)
            SectionCard(
              title: 'Lignes à corriger (${problemRows.length})',
              icon: Icons.warning_amber_outlined,
              child: Column(
                children: [
                  Text(
                    'Ces lignes ne seront pas importées. Corrigez le fichier '
                    'Excel puis relancez l’import si nécessaire.',
                    style:
                        TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  for (final r in problemRows.take(60))
                    _ErrorRow(row: r),
                ],
              ),
            ),

          // ---------- Détail ----------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                const Text('Détail des lignes',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton(
                  onPressed: () =>
                      setState(() => _showAllRows = !_showAllRows),
                  child: Text(_showAllRows
                      ? 'Voir seulement les problèmes'
                      : 'Voir toutes les lignes'),
                ),
              ],
            ),
          ),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Aucune ligne à signaler.', style: TextStyle(fontSize: 14)),
            )
          else
            for (final r in rows.take(300)) _RowTile(row: r),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surface,
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ---------- Mode ----------
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Mode d’application',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant)),
              ),
              RadioGroup<ImportMode>(
                groupValue: _mode,
                onChanged: (v) => setState(() => _mode = v!),
                child: Column(
                  children: [
                    for (final mode in ImportMode.values)
                      RadioListTile<ImportMode>(
                        value: mode,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(mode.label),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _applying ? null : _apply,
                  icon: _applying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(_applying
                      ? 'Import en cours…'
                      : 'Importer ${report.validCount} étudiant(s)'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.row});
  final ImportRow row;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reasons = <String>[
      if (row.hasMissingMatricule) 'matricule manquant',
      if (row.hasMissingName) 'nom manquant',
      if (row.isDuplicateInFile) 'doublon dans le fichier',
    ];
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: scheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ligne ${row.rowNumber} : '
              '« ${row.matricule.isEmpty ? '(vide)' : row.matricule} » — '
              '« ${row.fullName.isEmpty ? '(vide)' : row.fullName} » — '
              '${reasons.join(', ')}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({required this.row});
  final ImportRow row;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color, tag) = row.hasError
        ? (Icons.error_outline, scheme.error, 'Erreur')
        : row.isDuplicateInFile
            ? (Icons.copy_all_outlined, scheme.tertiary, 'Doublon')
            : row.isNewInSession
                ? (Icons.person_add_outlined, scheme.primary, 'Nouveau')
                : row.hasNameChange
                    ? (
                        Icons.drive_file_rename_outline,
                        scheme.tertiary,
                        'Renommé'
                      )
                    : (Icons.sync_outlined, scheme.outline, 'Inchangé');

    return ListTile(
      dense: true,
      leading: Icon(icon, color: color, size: 20),
      title: Text('${row.matricule.isEmpty ? '(vide)' : row.matricule} — '
          '${row.fullName.isEmpty ? '(vide)' : row.fullName}'),
      subtitle: Text(
        'Ligne ${row.rowNumber}'
        '${row.existingName != null && row.existingName != row.fullName ? ' — avant : « ${row.existingName} »' : ''}',
        style: const TextStyle(fontSize: 12.5),
      ),
      trailing: Text(tag,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
