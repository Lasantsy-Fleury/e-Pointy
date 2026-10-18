import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../state/app_settings.dart';
import '../../state/session_controller.dart';
import '../widgets/app_widgets.dart';
import 'audit_log_screen.dart';
import 'backup_screen.dart';
import 'conflicts_screen.dart';
import 'exports_screen.dart';
import 'plan_screen.dart';
import 'qr_badges_screen.dart';
import 'security_screen.dart';
import 'session_info_screen.dart';
import 'students_manage_screen.dart';
import 'sync_screen.dart';

/// Onglet « Réglages » : configuration de la session, appareil, transferts,
/// exports, sauvegarde et sécurité. Les actions sensibles sont réservées au
/// rôle « responsable ».
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.onGoTo});

  final void Function(int index) onGoTo;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final controller = context.watch<SessionController>();
    final scheme = Theme.of(context).colorScheme;
    final isAdmin = settings.isAdmin;

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        // ---------- Identité de l'appareil ----------
        SectionCard(
          title: 'Appareil et opérateur',
          icon: Icons.smartphone,
          child: Column(
            children: [
              InfoRow('Appareil', settings.deviceName),
              InfoRow('Rôle', settings.roleLabel),
              InfoRow('Opérateur',
                  settings.operatorName.isEmpty ? '—' : settings.operatorName),
              InfoRow('Identifiant', settings.deviceId),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) =>
                                const SecurityScreen(sessionId: null)),
                      ),
                      icon: const Icon(Icons.manage_accounts_outlined),
                      label: const Text('Appareil / rôle'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ---------- Session ----------
        SectionCard(
          title: 'Session en cours',
          icon: Icons.luggage_outlined,
          child: Column(
            children: [
              InfoRow('Nom', controller.session?.name ?? '—'),
              InfoRow('Statut', controller.session?.status.label ?? '—'),
              InfoRow('Étudiants', '${controller.students.length}'),
              InfoRow('Distributions', '${controller.distributions.length}'),
              InfoRow('Journées', '${controller.days.length}'),
              const SizedBox(height: 8),
              _FullButton(
                icon: Icons.info_outline,
                label: 'Informations de la session',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SessionInfoScreen()),
                ),
              ),
            ],
          ),
        ),

        // ---------- Configuration ----------
        if (isAdmin)
          SectionCard(
            title: 'Configuration',
            icon: Icons.tune,
            child: Column(
              children: [
                _FullButton(
                  icon: Icons.edit_calendar_outlined,
                  label: 'Planifier les journées et distributions',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PlanScreen()),
                  ),
                ),
                _FullButton(
                  icon: Icons.upload_file_outlined,
                  label: 'Importer / gérer les étudiants (Excel)',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const StudentsManageScreen()),
                  ),
                ),
                _FullButton(
                  icon: Icons.qr_code_outlined,
                  label: 'QR codes des étudiants (PDF)',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const QrBadgesScreen()),
                  ),
                ),
              ],
            ),
          ),

        // ---------- Transferts ----------
        SectionCard(
          title: 'Transferts entre appareils',
          icon: Icons.sync_alt,
          child: Column(
            children: [
              InfoRow('En attente d’envoi', '${controller.pendingOut}',
                  icon: Icons.cloud_upload_outlined),
              const SizedBox(height: 4),
              Text(
                'Le transfert se fait par un fichier (.mipointy) partagé par '
                'Bluetooth, câble ou carte SD — sans connexion Internet.',
                style:
                    TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              _FullButton(
                icon: Icons.send_outlined,
                label: 'Envoyer mes pointages',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SyncScreen()),
                ),
              ),
            ],
          ),
        ),

        // ---------- Conflits ----------
        SectionCard(
          title: 'Doublons et conflits',
          icon: Icons.rule_outlined,
          child: Column(
            children: [
              InfoRow('À vérifier',
                  '${controller.sessionStats?.totalDuplicates ?? 0}'),
              const SizedBox(height: 8),
              _FullButton(
                icon: Icons.rule_outlined,
                label: 'Ouvrir la résolution des conflits',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ConflictsScreen()),
                ),
              ),
            ],
          ),
        ),

        // ---------- Exports et sauvegarde ----------
        SectionCard(
          title: 'Exports et sauvegarde',
          icon: Icons.folder_outlined,
          child: Column(
            children: [
              _FullButton(
                icon: Icons.download_outlined,
                label: 'Exports Excel / CSV',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ExportsScreen()),
                ),
              ),
              _FullButton(
                icon: Icons.save_alt_outlined,
                label: 'Sauvegarde et restauration',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BackupScreen()),
                ),
              ),
              _FullButton(
                icon: Icons.history,
                label: 'Journal des modifications',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AuditLogScreen()),
                ),
              ),
            ],
          ),
        ),

        // ---------- À propos ----------
        SectionCard(
          title: 'À propos',
          icon: Icons.info_outline,
          child: Column(
            children: [
              InfoRow('Application', AppConstants.appName),
              InfoRow('Version', AppConstants.appVersion),
              InfoRow('Mode', 'Hors ligne (données locales)'),
              const SizedBox(height: 4),
              Text(
                'Toutes les données sont stockées localement sur cet '
                'appareil. Aucune connexion Internet n’est requise pour '
                'pointer.',
                style:
                    TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FullButton extends StatelessWidget {
  const _FullButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label,
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}
