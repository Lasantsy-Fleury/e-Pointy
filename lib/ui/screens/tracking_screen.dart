import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/distribution.dart';
import '../../state/session_controller.dart';
import '../widgets/app_widgets.dart';
import 'conflicts_screen.dart';
import 'exports_screen.dart';

/// Onglet « Suivi » : bilan de la session, récapitulatif par distribution,
/// point d'accès aux conflits et aux exports.
class TrackingScreen extends StatelessWidget {
  const TrackingScreen({super.key, required this.onGoTo});

  final void Function(int index) onGoTo;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SessionController>();
    final stats = controller.sessionStats;
    final session = controller.session;
    final scheme = Theme.of(context).colorScheme;

    if (stats == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Récapitulatif par distribution de la journée sélectionnée.
    final day = controller.selectedDay;
    final ofDay = controller.distributionsOfSelectedDay;

    return RefreshIndicator(
      onRefresh: () => controller.refresh(),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          // ---------- Bilan global ----------
          Card(
            color: scheme.primaryContainer.withValues(alpha: 0.5),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bilan — ${session?.name ?? ''}',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: CounterTile(
                          label: 'Étudiants actifs',
                          value: '${stats.activeStudents}',
                          icon: Icons.people_alt_outlined,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: CounterTile(
                          label: 'Pointages validés',
                          value: '${stats.totalPointages}',
                          icon: Icons.check_circle_outline,
                          highlight: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: CounterTile(
                          label: 'Distributions',
                          value:
                              '${stats.totalDistributions} (${stats.distributionsCloses} clôturées)',
                          icon: Icons.restaurant_menu,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: CounterTile(
                          label: 'Taux moyen',
                          value: '${stats.averageRatePercent} %',
                          icon: Icons.insights_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: CounterTile(
                          label: 'Saisies manuelles',
                          value: '${stats.totalManual}',
                          icon: Icons.edit_outlined,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: CounterTile(
                          label: 'Doublons à vérifier',
                          value: '${stats.totalDuplicates}',
                          icon: Icons.copy_all_outlined,
                          color: stats.totalDuplicates > 0
                              ? scheme.error
                              : null,
                          highlight: stats.totalDuplicates > 0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ---------- Conflits ----------
          if (stats.totalDuplicates > 0)
            Card(
              color: scheme.errorContainer.withValues(alpha: 0.6),
              child: ListTile(
                leading:
                    Icon(Icons.warning_amber_outlined, color: scheme.error),
                title: Text(
                    '${stats.totalDuplicates} doublon(s) entre appareils',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text(
                    'Des pointages reçus d’un autre appareil correspondent à '
                    'un étudiant déjà servi. Vérifiez-les pour trancher.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ConflictsScreen()),
                ),
              ),
            ),

          // ---------- Récap de la journée ----------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Récapitulatif — ${day?.label ?? 'Journée'}',
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          if (ofDay.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Aucune distribution pour cette journée.',
                  style: TextStyle(fontSize: 14)),
            )
          else
            for (final d in ofDay)
              _RecapTile(
                dayLabel: day?.label ?? '',
                distribution: d,
              ),

          // ---------- Actions ----------
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ConflictsScreen()),
                  ),
                  icon: const Icon(Icons.rule_outlined),
                  label: const Text('Doublons et conflits'),
                ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ExportsScreen()),
                  ),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Exports (Excel / CSV)'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => onGoTo(2),
                  icon: const Icon(Icons.people_alt_outlined),
                  label: const Text('Liste des étudiants'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne de récapitulatif : « 126 servis sur 150 — 84 % — 24 restants ».
class _RecapTile extends StatelessWidget {
  const _RecapTile({required this.dayLabel, required this.distribution});

  final String dayLabel;
  final Distribution distribution;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SessionController>();
    // Calcule les compteurs via le service de stats pour cette distribution.
    return FutureBuilder(
      future: controller.statsService
          .forDistribution(controller.sessionId!, distribution),
      builder: (context, snapshot) {
        final stats = snapshot.data;
        final served = stats?.served ?? 0;
        final total = stats?.totalStudents ?? 0;
        final remaining = stats?.remaining ?? 0;
        final percent = stats?.ratePercent ?? 0;
        final scheme = Theme.of(context).colorScheme;
        return Card(
          child: ListTile(
            leading: Icon(
              distribution.acceptsPointage
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: distribution.acceptsPointage
                  ? scheme.primary
                  : scheme.outline,
            ),
            title: Text(distribution.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(distribution.horaires),
                const SizedBox(height: 4),
                Text(
                  '$served servis sur $total — $percent % — $remaining restants',
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                ProgressLine(served: served, total: total, height: 6),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}
