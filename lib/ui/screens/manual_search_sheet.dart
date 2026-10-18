import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../models/scan_result.dart';
import '../../models/student.dart';
import '../../state/app_settings.dart';
import '../../state/session_controller.dart';
import '../widgets/app_widgets.dart';

/// Recherche manuelle d'un étudiant (secours quand le QR est illisible).
///
/// Le pointage manuel est autorisé pour les rôles « pointeur » et
/// « responsable » ; le rôle « lecture » ne peut que consulter.
Future<void> showManualSearchSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => const _ManualSearchSheet(),
  );
}

class _ManualSearchSheet extends StatefulWidget {
  const _ManualSearchSheet();

  @override
  State<_ManualSearchSheet> createState() => _ManualSearchSheetState();
}

class _ManualSearchSheetState extends State<_ManualSearchSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _point(Student student) async {
    final controller = context.read<SessionController>();
    final settings = context.read<AppSettings>();
    final active = controller.activeDistribution;
    if (active == null) {
      showMessage(context, 'Choisissez d’abord une distribution.', error: true);
      return;
    }
    if (!settings.canScan) {
      showMessage(context,
          'Le rôle « ${settings.roleLabel} » ne permet pas de pointer.',
          error: true);
      return;
    }
    final confirmed = await confirmAction(
      context,
      title: 'Pointer ${student.fullName} ?',
      message: 'Distribution : ${active.name}. Un seul pointage validé est '
          'autorisé par étudiant et par distribution.',
      confirmLabel: 'Pointer',
    );
    if (!confirmed || !mounted) return;
    final result = await controller.manualPointage(student, active);
    if (!mounted) return;
    _showResult(result);
    if (result.isSuccess) Navigator.of(context).pop();
  }

  void _showResult(ScanResult result) {
    if (!mounted) return;
    showMessage(
      context,
      result.detail == null
          ? result.message
          : '${result.message} — ${result.detail}',
      error: !result.isSuccess && result.outcome != ScanOutcome.dejaServi,
      success: result.isSuccess,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SessionController>();
    final settings = context.watch<AppSettings>();
    final active = controller.activeDistribution;
    final all = controller.students;
    final q = _query.trim().toLowerCase();
    final results = q.isEmpty
        ? <Student>[]
        : all
            .where((s) =>
                s.matricule.toLowerCase().contains(q) ||
                _norm(s.fullName).contains(_norm(q)))
            .take(50)
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Recherche manuelle',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  active == null
                      ? 'Aucune distribution active.'
                      : 'Distribution : ${active.name} — ${active.horaires}',
                  style: TextStyle(
                      fontSize: 13.5,
                      color: active == null
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchController,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    labelText: 'Matricule ou nom',
                    hintText: 'Ex. 2024001 ou RAKOTO',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: q.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Saisissez un matricule ou un nom pour trouver '
                        'l’étudiant, puis pointez-le.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  )
                : results.isEmpty
                    ? const Center(
                        child: Text('Aucun étudiant trouvé.',
                            style: TextStyle(fontSize: 15)),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: results.length,
                        itemBuilder: (context, i) {
                          final s = results[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: s.active
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                              child: Text(
                                s.fullName.isEmpty
                                    ? '?'
                                    : s.fullName[0].toUpperCase(),
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer),
                              ),
                            ),
                            title: Text(s.fullName),
                            subtitle: Text('Matricule ${s.matricule}'),
                            trailing: s.active
                                ? FilledButton.tonal(
                                    onPressed: () => _point(s),
                                    child: const Text('Pointer'),
                                  )
                                : const Chip(label: Text('Désactivé')),
                            onTap: s.active && settings.canScan
                                ? () => _point(s)
                                : null,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  String _norm(String input) => input
      .toLowerCase()
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('ë', 'e')
      .replaceAll('î', 'i')
      .replaceAll('ï', 'i')
      .replaceAll('ô', 'o')
      .replaceAll('ö', 'o')
      .replaceAll('û', 'u')
      .replaceAll('ù', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ç', 'c');
}
