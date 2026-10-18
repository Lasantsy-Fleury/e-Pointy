import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/distribution.dart';
import '../../models/trip_day.dart';
import '../../state/app_settings.dart';
import '../../state/session_controller.dart';
import '../format.dart';
import '../widgets/app_widgets.dart';
import 'distribution_edit_screen.dart';
import 'plan_screen.dart';
import 'session_info_screen.dart';

/// Onglet « Distribution » : sélection de la journée et de la distribution,
/// compteurs en direct et actions de gestion.
class DistributionScreen extends StatelessWidget {
  const DistributionScreen({super.key, required this.onGoTo});

  final void Function(int index) onGoTo;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SessionController>();
    final settings = context.watch<AppSettings>();
    final session = controller.session;
    if (session == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final days = controller.days;
    final selectedDay = controller.selectedDay;
    final distributions = controller.distributionsOfSelectedDay;
    final active = controller.activeDistribution;
    final stats = controller.activeStats;

    return RefreshIndicator(
      onRefresh: () => controller.refresh(),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          // ---------- En-tête de session ----------
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SessionInfoScreen()),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(session.name,
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w700)),
                        ),
                        StatusChip.session(session.status),
                      ],
                    ),
                    if (session.school != null)
                      Text(session.school!,
                          style: TextStyle(
                              fontSize: 13.5,
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.people_outline,
                            size: 16,
                            color: Theme.of(context).colorScheme.outline),
                        const SizedBox(width: 6),
                        Text('${controller.students.length} étudiants inscrits',
                            style: const TextStyle(fontSize: 13.5)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ---------- Sélecteur de journée ----------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.event_note_outlined, size: 18),
                const SizedBox(width: 8),
                const Text('Journée',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const Spacer(),
                if (settings.canConfigure)
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PlanScreen()),
                    ),
                    icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                    label: const Text('Planifier'),
                  ),
              ],
            ),
          ),
          if (days.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Aucune journée. Ouvrez « Planifier » pour en créer.',
                style: TextStyle(fontSize: 14),
              ),
            )
          else
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: days.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final day = days[i];
                  final selected = day.id == selectedDay?.id;
                  return ChoiceChip(
                    label: Text(_dayLabel(day)),
                    selected: selected,
                    onSelected: (_) => controller.selectDay(day.id),
                  );
                },
              ),
            ),

          // ---------- Sélecteur de distribution ----------
          if (distributions.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Row(
                children: [
                  const Icon(Icons.restaurant_menu, size: 18),
                  const SizedBox(width: 8),
                  const Text('Distribution',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: distributions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final d = distributions[i];
                  final selected = d.id == active?.id;
                  return FilterChip(
                    selected: selected,
                    onSelected: (_) => controller.selectDistribution(d.id),
                    avatar: Icon(
                      d.acceptsPointage
                          ? Icons.check_circle_outline
                          : Icons.schedule,
                      size: 18,
                      color: d.acceptsPointage
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                    ),
                    label: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(d.name,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        Text(d.horaires,
                            style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],

          // ---------- Compteurs ----------
          if (active != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SectionCard(
                title: 'Compteurs en direct',
                icon: Icons.speed_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DistributionSummary(
                      distribution: active,
                      served: stats?.served ?? 0,
                      total: stats?.totalStudents ?? 0,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: CounterTile(
                            label: 'Servis',
                            value: '${stats?.served ?? 0}',
                            icon: Icons.check_circle_outline,
                            color: Theme.of(context).colorScheme.primary,
                            highlight: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CounterTile(
                            label: 'Restants',
                            value: '${stats?.remaining ?? 0}',
                            icon: Icons.pending_actions_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: CounterTile(
                            label: 'Doublons à vérifier',
                            value: '${stats?.duplicates ?? 0}',
                            icon: Icons.copy_all_outlined,
                            color: (stats?.duplicates ?? 0) > 0
                                ? Theme.of(context).colorScheme.error
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CounterTile(
                            label: 'Saisies manuelles',
                            value: '${stats?.manual ?? 0}',
                            icon: Icons.edit_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: settings.canScan
                                ? () => onGoTo(1)
                                : null,
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text('Pointer'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => onGoTo(2),
                            icon: const Icon(Icons.people_alt_outlined),
                            label: const Text('Étudiants'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // ---------- Liste des distributions du jour ----------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            child: Text('Programme du jour (${distributions.length})',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
          if (distributions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Aucune distribution pour cette journée.',
                  style: TextStyle(fontSize: 14)),
            )
          else
            for (final d in distributions)
              _DistributionTile(
                distribution: d,
                isActive: d.id == active?.id,
                onTap: () => controller.selectDistribution(d.id),
                onEdit: settings.canConfigure
                    ? () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  DistributionEditScreen(distribution: d)),
                        )
                    : null,
              ),
        ],
      ),
    );
  }

  String _dayLabel(TripDay day) {
    if (day.dayDate == null) return day.label;
    return '${day.label} · ${formatDate(day.dayDate)}';
  }
}

class _DistributionTile extends StatelessWidget {
  const _DistributionTile({
    required this.distribution,
    required this.isActive,
    required this.onTap,
    this.onEdit,
  });

  final Distribution distribution;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: isActive ? scheme.primaryContainer.withValues(alpha: 0.4) : null,
      child: ListTile(
        onTap: onTap,
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
        subtitle: Text(distribution.horaires),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusChip.distribution(distribution.status),
            if (onEdit != null)
              IconButton(
                tooltip: 'Modifier',
                icon: const Icon(Icons.edit_outlined),
                onPressed: onEdit,
              ),
          ],
        ),
      ),
    );
  }
}
