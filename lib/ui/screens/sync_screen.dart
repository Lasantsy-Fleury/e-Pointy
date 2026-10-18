import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../state/app_settings.dart';
import '../../state/session_controller.dart';
import '../flows/bundle_flow.dart';
import '../widgets/app_widgets.dart';

/// Transfert de données entre appareils (fichier `.mipointy`, hors ligne).
class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  bool _busy = false;
  String? _lastMessage;
  bool _lastOk = true;

  Future<void> _send({required bool backup}) async {
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
        kind: backup
            ? AppConstants.bundleKindBackup
            : AppConstants.bundleKindSync,
      );
      if (!mounted || result == null) return;
      // En cas d'envoi réussi, on marque les pointages comme transmis.
      if (result.shared && !backup) {
        await controller.markSyncedOut(sessionId);
      }
      setState(() {
        _lastOk = result.shared;
        _lastMessage = result.shared
            ? 'Fichier prêt et transmis. En attente d’envoi : '
                '${controller.pendingOut}.'
            : 'Fichier créé mais le partage n’a pas été confirmé. '
                'Les pointages restent marqués « non transmis ».';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastOk = false;
          _lastMessage = 'Échec : $e';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _receive() async {
    final settings = context.read<AppSettings>();
    final controller = context.read<SessionController>();
    setState(() => _busy = true);
    try {
      final report = await importBundleFlow(
        context,
        actor: settings.operatorName.isEmpty
            ? settings.deviceName
            : settings.operatorName,
        title: 'Recevoir des données',
      );
      if (!mounted || report == null) return;
      await controller.refresh();
      setState(() {
        _lastOk = true;
        _lastMessage = 'Réception terminée : ${report.summary}';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastOk = false;
          _lastMessage = 'Échec : $e';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SessionController>();
    final scheme = Theme.of(context).colorScheme;
    final pending = controller.pendingOut;

    return Scaffold(
      appBar: AppBar(title: const Text('Transfert entre appareils')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Card(
                color: pending == 0
                    ? scheme.primaryContainer.withValues(alpha: 0.5)
                    : scheme.tertiaryContainer.withValues(alpha: 0.6),
                child: ListTile(
                  leading: Icon(
                    pending == 0
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_upload_outlined,
                    size: 32,
                  ),
                  title: Text(
                    pending == 0
                        ? 'Aucun pointage en attente d’envoi'
                        : '$pending pointage(s) en attente d’envoi',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                      'Les pointages sont toujours enregistrés localement, '
                      'même s’ils ne sont pas encore transmis.'),
                ),
              ),

              SectionCard(
                title: 'Envoyer',
                icon: Icons.send_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Un fichier de transfert est créé et proposé au partage '
                      '(Bluetooth, câble, carte SD, messagerie…). Aucune '
                      'connexion Internet n’est nécessaire.',
                      style: TextStyle(
                          fontSize: 13, color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _send(backup: false),
                        icon: const Icon(Icons.send_outlined),
                        label: const Text('Envoyer mes pointages'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _send(backup: true),
                        icon: const Icon(Icons.save_alt_outlined),
                        label: const Text('Créer une sauvegarde'),
                      ),
                    ),
                  ],
                ),
              ),

              SectionCard(
                title: 'Recevoir',
                icon: Icons.download_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choisissez un fichier reçu d’un autre appareil '
                      '(.mipointy). L’empreinte est vérifiée et un aperçu '
                      's’affiche avant toute fusion.',
                      style: TextStyle(
                          fontSize: 13, color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: _busy ? null : _receive,
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('Recevoir des données'),
                      ),
                    ),
                  ],
                ),
              ),

              SectionCard(
                title: 'Comment ça marche',
                icon: Icons.help_outline,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '1. L’appareil qui a pointé crée un fichier et le '
                      'partage.',
                      style: TextStyle(fontSize: 13.5),
                    ),
                    const Text(
                      '2. L’appareil qui reçoit ouvre le fichier '
                      '(« Recevoir des données »).',
                      style: TextStyle(fontSize: 13.5),
                    ),
                    const Text(
                      '3. Un aperçu vérifie l’empreinte, puis la fusion. Un '
                      'même événement reçu deux fois n’est jamais compté en '
                      'double.',
                      style: TextStyle(fontSize: 13.5),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Un pointage n’est considéré comme transmis qu’après '
                      'confirmation du partage.',
                      style: TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),

              if (_lastMessage != null)
                Card(
                  color: _lastOk
                      ? scheme.primaryContainer.withValues(alpha: 0.5)
                      : scheme.errorContainer.withValues(alpha: 0.6),
                  child: ListTile(
                    leading: Icon(_lastOk
                        ? Icons.check_circle_outline
                        : Icons.error_outline),
                    title: Text(_lastMessage!,
                        style: const TextStyle(fontSize: 13.5)),
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
