import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../state/app_settings.dart';
import '../../state/session_controller.dart';
import '../format.dart';
import '../widgets/app_widgets.dart';
import 'session_form_screen.dart';

/// Informations détaillées d'une session et changements de statut.
class SessionInfoScreen extends StatelessWidget {
  const SessionInfoScreen({super.key});

  Future<void> _changeStatus(BuildContext context, SessionStatus status) async {
    final controller = context.read<SessionController>();
    final session = controller.session;
    if (session == null) return;
    if (status == SessionStatus.cloturee || status == SessionStatus.archivee) {
      final ok = await confirmAction(
        context,
        title: status == SessionStatus.archivee
            ? 'Archiver la session ?'
            : 'Clôturer la session ?',
        message: status == SessionStatus.archivee
            ? 'La session sera classée. Le pointage restera bloqué.'
            : 'Le pointage sera bloqué jusqu’à réouverture volontaire. Les '
                'données restent consultables et exportables.',
        confirmLabel: status == SessionStatus.archivee ? 'Archiver' : 'Clôturer',
        danger: true,
      );
      if (!ok || !context.mounted) return;
    }
    await controller.setSessionStatus(status);
    if (!context.mounted) return;
    showMessage(context, 'Statut mis à jour : ${status.label}', success: true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SessionController>();
    final settings = context.watch<AppSettings>();
    final session = controller.session;
    if (session == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final stats = controller.sessionStats;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Informations de la session'),
        actions: [
          if (settings.isAdmin)
            IconButton(
              tooltip: 'Modifier',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => SessionFormScreen(session: session)),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(session.name,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                      ),
                      StatusChip.session(session.status),
                    ],
                  ),
                  const SizedBox(height: 10),
                  InfoRow('Établissement / groupe',
                      session.school ?? '—', icon: Icons.school_outlined),
                  InfoRow('Responsable', session.responsible ?? '—',
                      icon: Icons.person_outline),
                  InfoRow(
                    'Période',
                    '${session.startDate != null ? formatDate(session.startDate) : '—'} '
                        'au ${session.endDate != null ? formatDate(session.endDate) : '—'}',
                    icon: Icons.event,
                  ),
                  InfoRow('Token de session', session.token,
                      icon: Icons.qr_code_outlined),
                  InfoRow('Créée le', formatIso(session.createdAt),
                      icon: Icons.schedule),
                  InfoRow('Mise à jour', formatIso(session.updatedAt),
                      icon: Icons.update),
                  if (session.notes != null) ...[
                    const SizedBox(height: 8),
                    const Text('Notes',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(session.notes!),
                  ],
                ],
              ),
            ),
          ),

          if (stats != null)
            SectionCard(
              title: 'Aperçu',
              icon: Icons.insights_outlined,
              child: Column(
                children: [
                  InfoRow('Étudiants inscrits', '${stats.totalStudents}'),
                  InfoRow('Étudiants actifs', '${stats.activeStudents}'),
                  InfoRow('Distributions', '${stats.totalDistributions}'),
                  InfoRow('Pointages validés', '${stats.totalPointages}'),
                  InfoRow('Taux moyen', '${stats.averageRatePercent} %'),
                  InfoRow('Doublons à vérifier', '${stats.totalDuplicates}'),
                ],
              ),
            ),

          if (settings.canCorrect)
            SectionCard(
              title: 'Statut de la session',
              icon: Icons.toggle_on_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Le pointage n’est possible que lorsque la session est '
                    '« En cours ».',
                    style: TextStyle(
                        fontSize: 13, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  if (session.status != SessionStatus.enCours)
                    _StatusButton(
                      label: 'Démarrer la session',
                      icon: Icons.play_arrow,
                      onPressed: () =>
                          _changeStatus(context, SessionStatus.enCours),
                    ),
                  if (session.status == SessionStatus.enCours)
                    _StatusButton(
                      label: 'Clôturer la session',
                      icon: Icons.lock_outline,
                      onPressed: () =>
                          _changeStatus(context, SessionStatus.cloturee),
                    ),
                  if (session.status != SessionStatus.archivee)
                    _StatusButton(
                      label: 'Archiver la session',
                      icon: Icons.inventory_2_outlined,
                      danger: true,
                      onPressed: () =>
                          _changeStatus(context, SessionStatus.archivee),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, color: danger ? scheme.error : null),
          label: Text(label,
              style: TextStyle(color: danger ? scheme.error : null)),
        ),
      ),
    );
  }
}
