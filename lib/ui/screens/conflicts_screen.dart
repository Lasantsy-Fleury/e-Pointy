import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/conflict.dart';
import '../../models/pointage.dart';
import '../../state/app_settings.dart';
import '../../state/session_controller.dart';
import '../format.dart';
import '../widgets/app_widgets.dart';

/// Résolution des doublons entre appareils (conflits de fusion).
///
/// Chaque conflit oppose le pointage local conservé et un pointage reçu
/// d'un autre appareil. Le responsable tranche explicitement : jamais de
/// double comptage.
class ConflictsScreen extends StatefulWidget {
  const ConflictsScreen({super.key});

  @override
  State<ConflictsScreen> createState() => _ConflictsScreenState();
}

class _ConflictsScreenState extends State<ConflictsScreen> {
  bool _showResolved = false;
  bool _loading = true;
  List<Conflict> _conflicts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final controller = context.read<SessionController>();
    final id = controller.sessionId;
    if (id == null) return;
    final conflicts = await controller.conflictDao.forSession(id);
    if (!mounted) return;
    setState(() {
      _conflicts = conflicts;
      _loading = false;
    });
  }

  Future<void> _resolve(Conflict conflict, bool keepImported) async {
    final settings = context.read<AppSettings>();
    if (!settings.canCorrect) {
      showMessage(context, 'Réservé au responsable.', error: true);
      return;
    }
    final ok = await confirmAction(
      context,
      title: keepImported
          ? 'Conserver le pointage importé ?'
          : 'Conserver le pointage local ?',
      message: keepImported
          ? 'Le pointage local sera annulé (trace et motif conservés) et le '
              'pointage reçu deviendra le pointage validé.'
          : 'Le pointage local reste validé. Le pointage reçu reste '
              '« doublon potentiel » à titre d’historique. Dans les deux cas, '
              'aucun double comptage.',
      confirmLabel: 'Confirmer',
      danger: keepImported,
    );
    if (!ok || !mounted) return;
    final controller = context.read<SessionController>();
    await controller.resolveConflict(conflict, keepImported);
    await _load();
    if (mounted) {
      showMessage(context, 'Conflit résolu.', success: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = _conflicts
        .where((c) => _showResolved || !c.resolved)
        .toList();
    final unresolved = _conflicts.where((c) => !c.resolved).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doublons et conflits'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Card(
                  color: unresolved == 0
                      ? scheme.primaryContainer.withValues(alpha: 0.5)
                      : scheme.errorContainer.withValues(alpha: 0.5),
                  child: ListTile(
                    leading: Icon(
                      unresolved == 0
                          ? Icons.verified_outlined
                          : Icons.warning_amber_outlined,
                      size: 32,
                    ),
                    title: Text(
                      unresolved == 0
                          ? 'Aucun doublon à vérifier'
                          : '$unresolved doublon(s) à vérifier',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                        'Ces situations surviennent quand deux appareils '
                        'pointent le même étudiant pour la même distribution. '
                        'Le nombre de servis n’est jamais gonflé.'),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Afficher aussi les conflits résolus'),
                  value: _showResolved,
                  onChanged: (v) => setState(() => _showResolved = v),
                ),
                if (shown.isEmpty)
                  const EmptyState(
                    icon: Icons.rule_outlined,
                    title: 'Rien à afficher',
                    message: 'Aucun conflit enregistré pour cette session.',
                  )
                else
                  for (final c in shown) _ConflictCard(conflict: c, onResolve: _resolve),
              ],
            ),
    );
  }
}

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({required this.conflict, required this.onResolve});

  final Conflict conflict;
  final Future<void> Function(Conflict, bool) onResolve;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<SessionController>();
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder(
      future: _resolveNames(controller),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final studentLabel = data?.$1 ?? 'Étudiant inconnu';
        final distLabel = data?.$2 ?? 'Distribution inconnue';

        return Card(
          color: conflict.resolved
              ? scheme.surfaceContainerHighest.withValues(alpha: 0.4)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(studentLabel,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: conflict.resolved
                            ? scheme.primaryContainer
                            : scheme.errorContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            conflict.resolved
                                ? Icons.check_circle_outline
                                : Icons.warning_amber_outlined,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            conflict.resolved ? 'Résolu' : 'À vérifier',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                InfoRow('Distribution', distLabel),
                InfoRow('Détecté le', formatIso(conflict.detectedAt)),
                if (conflict.resolved) ...[
                  InfoRow(
                    'Décision',
                    conflict.resolution == 'garde_importe'
                        ? 'Pointage importé conservé'
                        : 'Pointage local conservé',
                  ),
                  if (conflict.resolvedAt != null)
                    InfoRow('Résolu le', formatIso(conflict.resolvedAt)),
                  if (conflict.note != null) InfoRow('Note', conflict.note!),
                ] else ...[
                  const SizedBox(height: 4),
                  Text(
                    'Le pointage local est validé ; le pointage reçu d’un '
                    'autre appareil est enregistré en « doublon potentiel ».',
                    style: TextStyle(
                        fontSize: 12.5, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => onResolve(conflict, false),
                          icon: const Icon(Icons.home_outlined, size: 18),
                          label: const Text('Garder le local'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => onResolve(conflict, true),
                          icon: const Icon(Icons.download_outlined, size: 18),
                          label: const Text('Garder l’importé'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<(String, String)?> _resolveNames(SessionController controller) async {
    final student = await controller.studentDao.getById(conflict.studentId);
    final dist = await controller.planDao.distributionById(conflict.distributionId);
    final kept = await controller.pointageDao.getById(conflict.keptPointageId);
    final imported =
        await controller.pointageDao.getById(conflict.conflictingPointageId);
    final studentLabel = student == null
        ? 'Étudiant inconnu'
        : '${student.fullName} (${student.matricule})';
    final distLabel = dist?.name ?? 'Distribution inconnue';
    return (
      '$studentLabel${_deviceHint(kept, imported)}',
      distLabel,
    );
  }

  String _deviceHint(Pointage? kept, Pointage? imported) {
    if (imported?.deviceName == null) return '';
    return ' — reçu de ${imported!.deviceName}';
  }
}
