import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/audit_entry.dart';
import '../../state/session_controller.dart';
import '../format.dart';
import '../widgets/app_widgets.dart';

/// Journal des modifications importantes : imports, corrections, changements
/// de statut, restaurations, résolutions de conflits.
class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  bool _loading = true;
  List<AuditEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final controller = context.read<SessionController>();
    final id = controller.sessionId;
    if (id == null) return;
    final entries = await controller.auditDao.forSession(id, limit: 1000);
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Journal des modifications')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? const EmptyState(
                  icon: Icons.history,
                  title: 'Journal vide',
                  message: 'Les actions importantes (imports, corrections, '
                      'changements de statut…) apparaîtront ici.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: _entries.length,
                    itemBuilder: (context, i) {
                      final e = _entries[i];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                scheme.primaryContainer.withValues(alpha: 0.6),
                            child: Icon(_iconFor(e.action), size: 20),
                          ),
                          title: Text(_labelFor(e.action),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(e.details, style: const TextStyle(fontSize: 13)),
                              const SizedBox(height: 2),
                              Text(
                                '${formatIso(e.at)} — ${e.actor}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  IconData _iconFor(String action) {
    if (action.contains('import')) return Icons.upload_file_outlined;
    if (action.contains('annulation') || action.contains('correction')) {
      return Icons.undo_outlined;
    }
    if (action.contains('statut')) return Icons.toggle_on_outlined;
    if (action.contains('etudiant')) return Icons.people_alt_outlined;
    if (action.contains('conflit')) return Icons.rule_outlined;
    if (action.contains('scan')) return Icons.qr_code_scanner;
    return Icons.info_outline;
  }

  String _labelFor(String action) {
    switch (action) {
      case 'creation_session':
        return 'Création de session';
      case 'statut_session':
        return 'Changement de statut de la session';
      case 'statut_distribution':
        return 'Changement de statut d’une distribution';
      case 'import_excel':
        return 'Import Excel';
      case 'ajout_etudiant':
        return 'Ajout d’un étudiant';
      case 'modification_etudiant':
        return 'Modification d’un étudiant';
      case 'desactivation_etudiant':
        return 'Désactivation d’un étudiant';
      case 'reactivation_etudiant':
        return 'Réactivation d’un étudiant';
      case 'annulation_pointage':
        return 'Annulation d’un pointage';
      case 'correction_pointage':
        return 'Correction d’un pointage';
      case 'resolution_conflit':
        return 'Résolution d’un conflit';
      default:
        if (action.startsWith('scan_')) return 'Scan';
        return action;
    }
  }
}
