import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../state/app_settings.dart';
import '../../state/session_controller.dart';
import '../flows/bundle_flow.dart';
import '../widgets/app_widgets.dart';

/// Sauvegarde et restauration hors ligne (fichier unique `.mipointy`).
///
/// Une sauvegarde contient toute la session : étudiants, configuration,
/// pointages et journal. La restauration est vérifiée par empreinte et
/// propose un mode « fusionner » (conservateur) ou « remplacer » (protégé).
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;

  Future<void> _createBackup() async {
    final settings = context.read<AppSettings>();
    final controller = context.read<SessionController>();
    final sessionId = controller.sessionId;
    if (sessionId == null) return;
    setState(() => _busy = true);
    try {
      final result = await exportBundleFlow(
        context,
        sessionId: sessionId,
        deviceId: settings.deviceId,
        deviceName: settings.deviceName,
        kind: AppConstants.bundleKindBackup,
      );
      if (!mounted || result == null) return;
      showMessage(
        context,
        result.shared
            ? 'Sauvegarde transmise. Conservez le fichier en lieu sûr.'
            : 'Sauvegarde créée : ${result.path}',
        success: true,
      );
    } catch (e) {
      if (mounted) showMessage(context, 'Échec : $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final settings = context.read<AppSettings>();
    final controller = context.read<SessionController>();
    setState(() => _busy = true);
    try {
      final report = await importBundleFlow(
        context,
        actor: settings.operatorName.isEmpty
            ? settings.deviceName
            : settings.operatorName,
        allowReplaceChoice: true,
        title: 'Restaurer une sauvegarde',
      );
      if (!mounted || report == null) return;
      await controller.refresh();
      if (!mounted) return;
      showMessage(context, 'Restauration terminée : ${report.summary}',
          success: true);
    } catch (e) {
      if (mounted) showMessage(context, 'Échec : $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SessionController>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Sauvegarde et restauration')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Card(
                color: scheme.primaryContainer.withValues(alpha: 0.4),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 32),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'La sauvegarde est un fichier unique contenant toute '
                          'la session. Elle fonctionne entièrement hors ligne.',
                          style: TextStyle(fontSize: 13.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SectionCard(
                title: 'Créer une sauvegarde',
                icon: Icons.save_alt_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Génère un fichier .mipointy et propose son partage. '
                      'Conservez-le sur un support sûr (clé USB, carte SD, '
                      'ordinateur).',
                      style: TextStyle(
                          fontSize: 13, color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _createBackup,
                        icon: const Icon(Icons.save_alt_outlined),
                        label: const Text('Sauvegarder maintenant'),
                      ),
                    ),
                  ],
                ),
              ),

              SectionCard(
                title: 'Restaurer / fusionner',
                icon: Icons.restore_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choisissez un fichier .mipointy. L’empreinte est '
                      'vérifiée, puis vous choisissez : fusionner '
                      '(conservateur) ou remplacer les données locales.',
                      style: TextStyle(
                          fontSize: 13, color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_outlined,
                              size: 18, color: scheme.error),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Le mode « remplacer » supprime les données '
                              'locales de la session concernée. Il est '
                              'toujours confirmé.',
                              style: TextStyle(fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: _busy ? null : _restore,
                        icon: const Icon(Icons.restore_outlined),
                        label: const Text('Restaurer une sauvegarde'),
                      ),
                    ),
                  ],
                ),
              ),

              SectionCard(
                title: 'État actuel',
                icon: Icons.info_outline,
                child: Column(
                  children: [
                    InfoRow('Étudiants', '${controller.students.length}'),
                    InfoRow('Distributions', '${controller.distributions.length}'),
                    InfoRow('Pointages', '${controller.sessionStats?.totalPointages ?? 0}'),
                    InfoRow('En attente d’envoi', '${controller.pendingOut}'),
                  ],
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
}
