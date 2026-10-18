import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/session_controller.dart';
import '../widgets/app_widgets.dart';
import 'student_card_screen.dart';
import 'students_manage_screen.dart';

/// Onglet « Étudiants » : recherche, filtres et suivi de l'état de service.
class StudentsScreen extends StatelessWidget {
  const StudentsScreen({super.key, required this.onGoTo});

  final void Function(int index) onGoTo;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SessionController>();
    final active = controller.activeDistribution;
    final filtered = controller.filteredStudents;
    final search = controller.searchQuery;
    final filter = controller.filter;

    return Column(
      children: [
        // ---------- Barre de recherche ----------
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Rechercher (matricule ou nom)',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: controller.setSearch,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Gérer / importer la liste',
                iconSize: 26,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const StudentsManageScreen()),
                ),
                icon: const Icon(Icons.upload_file_outlined),
              ),
            ],
          ),
        ),

        // ---------- Filtres ----------
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _FilterChip(
                label: 'Tous',
                selected: filter == StudentsFilter.tous,
                onTap: () => controller.setFilter(StudentsFilter.tous),
              ),
              _FilterChip(
                label: 'Servis',
                selected: filter == StudentsFilter.servis,
                onTap: () => controller.setFilter(StudentsFilter.servis),
              ),
              _FilterChip(
                label: 'Restants',
                selected: filter == StudentsFilter.restants,
                onTap: () => controller.setFilter(StudentsFilter.restants),
              ),
              _FilterChip(
                label: 'Inactifs',
                selected: filter == StudentsFilter.inactifs,
                onTap: () => controller.setFilter(StudentsFilter.inactifs),
              ),
            ],
          ),
        ),

        if (active != null && filter != StudentsFilter.inactifs)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Text(
              'Distribution : ${active.name} — servis : '
              '${controller.servedStudents.length} — restants : '
              '${controller.remainingStudents.length}',
              style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),

        // ---------- Liste ----------
        Expanded(
          child: filtered.isEmpty
              ? EmptyState(
                  icon: search.isEmpty ? Icons.people_outline : Icons.search_off,
                  title: search.isEmpty
                      ? 'Aucun étudiant'
                      : 'Aucun résultat',
                  message: search.isEmpty
                      ? 'Importez la liste des étudiants depuis un fichier '
                          'Excel (onglet Réglages → Gérer les étudiants).'
                      : 'Aucun étudiant ne correspond à « $search ».',
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final s = filtered[i];
                    final served =
                        controller.servedForActive.contains(s.id);
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: !s.active
                              ? Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                              : served
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                          child: !s.active
                              ? const Icon(Icons.person_off_outlined, size: 20)
                              : served
                                  ? const Icon(Icons.check, size: 20)
                                  : Text(
                                      s.fullName.isEmpty
                                          ? '?'
                                          : s.fullName[0].toUpperCase(),
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700),
                                    ),
                        ),
                        title: Text(s.fullName,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          'Matricule ${s.matricule}'
                          '${s.active ? '' : ' — désactivé'}',
                        ),
                        trailing: _StatusTag(served: served, active: s.active),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => StudentCardScreen(student: s)),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.served, required this.active});
  final bool served;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!active) {
      return _tag(Icons.person_off_outlined, 'Inactif',
          scheme.surfaceContainerHighest, scheme.onSurfaceVariant);
    }
    if (served) {
      return _tag(Icons.check_circle, 'Servi', scheme.primaryContainer,
          scheme.onPrimaryContainer);
    }
    return _tag(Icons.schedule, 'Restant', scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant);
  }

  Widget _tag(IconData icon, String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
