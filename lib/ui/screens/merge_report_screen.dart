import 'package:flutter/material.dart';

import '../../models/merge_report.dart';
import '../widgets/app_widgets.dart';

/// Rapport de fin de transfert : n'affiche « terminé » qu'après vérification.
class MergeReportScreen extends StatelessWidget {
  const MergeReportScreen({super.key, required this.report});

  final MergeReport report;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasAnomalies = report.anomalies.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bilan du transfert'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Card(
            color: scheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.verified_outlined,
                      size: 36, color: scheme.onPrimaryContainer),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(report.replaced
                                ? 'Données remplacées et vérifiées'
                                : 'Transfert vérifié et terminé',
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                          report.sessionNames.isEmpty
                              ? 'Session'
                              : report.sessionNames.join(', '),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SectionCard(
            title: 'Données traitées',
            icon: Icons.summarize_outlined,
            child: Column(
              children: [
                InfoRow('Sessions ajoutées', '${report.sessionsAdded}'),
                InfoRow('Sessions mises à jour', '${report.sessionsUpdated}'),
                InfoRow('Étudiants ajoutés', '${report.studentsAdded}'),
                InfoRow('Étudiants mis à jour', '${report.studentsUpdated}'),
                InfoRow('Journées ajoutées', '${report.daysAdded}'),
                InfoRow('Distributions ajoutées', '${report.distributionsAdded}'),
                InfoRow('Distributions mises à jour',
                    '${report.distributionsUpdated}'),
                InfoRow('Pointages appliqués', '${report.pointagesApplied}'),
                InfoRow('Pointages déjà connus (ignorés)',
                    '${report.pointagesSkipped}'),
                InfoRow('Doublons potentiels détectés',
                    '${report.pointagesConflicts}'),
              ],
            ),
          ),
          if (report.infos.isNotEmpty)
            SectionCard(
              title: 'Informations',
              icon: Icons.info_outline,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final info in report.infos)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text('• $info', style: const TextStyle(fontSize: 14)),
                    ),
                ],
              ),
            ),
          if (hasAnomalies)
            SectionCard(
              title: 'Anomalies à vérifier',
              icon: Icons.warning_amber_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final anomaly in report.anomalies)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text('• $anomaly',
                          style: TextStyle(
                              fontSize: 14, color: scheme.error)),
                    ),
                ],
              ),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              'Les pointages déjà envoyés ne sont jamais dupliqués ni '
              'supprimés : un même événement reçu plusieurs fois n’est '
              'appliqué qu’une seule fois.',
              style: TextStyle(fontSize: 13),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(report),
                icon: const Icon(Icons.check),
                label: const Text('Terminer'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
