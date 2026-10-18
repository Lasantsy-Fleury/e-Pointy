import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/day_template.dart';
import '../../models/distribution.dart';
import '../../models/item_type.dart';
import '../../models/trip_day.dart';
import '../../core/utils.dart';
import '../../state/app_settings.dart';
import '../../state/session_controller.dart';
import '../format.dart';
import '../widgets/app_widgets.dart';
import 'distribution_edit_screen.dart';

/// Écran de planification : journées, distributions, types d'éléments et
/// modèles de journée réutilisables.
class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SessionController>();
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    final canEdit = settings.canConfigure;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planifier'),
        actions: [
          if (canEdit)
            IconButton(
              tooltip: 'Ajouter une journée',
              icon: const Icon(Icons.add),
              onPressed: () => _addDay(context),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (!canEdit)
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Consultation seule : la modification du plan est '
                      'réservée au responsable.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          if (controller.days.isEmpty)
            EmptyState(
              icon: Icons.edit_calendar_outlined,
              title: 'Aucune journée',
              message: 'Créez une première journée, puis ajoutez les '
                  'distributions (repas, eau, collations…).',
              action: canEdit
                  ? FilledButton.icon(
                      onPressed: () => _addDay(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter une journée'),
                    )
                  : null,
            )
          else
            for (final day in controller.days)
              _DayCard(day: day, canEdit: canEdit, controller: controller),

          // ---------- Types d'éléments ----------
          SectionCard(
            title: 'Types d’éléments (${controller.itemTypes.length})',
            icon: Icons.category_outlined,
            actions: [
              if (canEdit)
                IconButton(
                  tooltip: 'Ajouter un type',
                  icon: const Icon(Icons.add),
                  onPressed: () => _addItemType(context),
                ),
            ],
            child: controller.itemTypes.isEmpty
                ? const Text('Aucun type d’élément.',
                    style: TextStyle(fontSize: 14))
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in controller.itemTypes)
                        Chip(
                          avatar: const Icon(Icons.local_dining, size: 16),
                          label: Text(item.unit == null
                              ? item.name
                              : '${item.name} (${item.unit})'),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: canEdit
                              ? () => controller.planDao
                                  .deleteItemType(item.id)
                                  .then((_) => controller.refresh())
                              : null,
                        ),
                    ],
                  ),
          ),

          // ---------- Modèles de journée ----------
          SectionCard(
            title: 'Modèles de journée (${controller.templates.length})',
            icon: Icons.bookmarks_outlined,
            child: controller.templates.isEmpty
                ? const Text(
                    'Aucun modèle. Enregistrez une journée comme modèle pour '
                    'la réutiliser sur d’autres jours.',
                    style: TextStyle(fontSize: 14))
                : Column(
                    children: [
                      for (final t in controller.templates)
                        _TemplateTile(
                          template: t,
                          canEdit: canEdit,
                          controller: controller,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _addDay(BuildContext context) async {
    final controller = context.read<SessionController>();
    final label = await promptText(
      context,
      title: 'Ajouter une journée',
      label: 'Libellé',
      initialValue: 'Jour ${controller.days.length + 1}',
    );
    if (label == null || !context.mounted) return;
    await controller.addDay(label);
  }

  Future<void> _addItemType(BuildContext context) async {
    final controller = context.read<SessionController>();
    final name = await promptText(
      context,
      title: 'Ajouter un type d’élément',
      label: 'Nom',
      helper: 'Ex. Petit-déjeuner, Eau, Collation, Kit',
    );
    if (name == null || !context.mounted) return;
    final unit = await promptText(
      context,
      title: 'Unité (facultatif)',
      label: 'Unité',
      helper: 'Ex. bouteille, portion, sachet',
      required: false,
    );
    if (!context.mounted) return;
    final now = nowUtcIso();
    await controller.planDao.insertItemType(ItemType(
      id: newId(),
      sessionId: controller.sessionId!,
      name: name,
      unit: unit,
      createdAt: now,
      updatedAt: now,
    ));
    await controller.refresh();
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.canEdit,
    required this.controller,
  });

  final TripDay day;
  final bool canEdit;
  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dists = controller.distributions
        .where((d) => d.dayId == day.id)
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_note_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(day.label,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      if (day.dayDate != null)
                        Text(formatDate(day.dayDate),
                            style: TextStyle(
                                fontSize: 13,
                                color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (canEdit)
                  PopupMenuButton<String>(
                    tooltip: 'Actions',
                    onSelected: (value) async {
                      switch (value) {
                        case 'rename':
                          final label = await promptText(context,
                              title: 'Renommer la journée',
                              label: 'Libellé',
                              initialValue: day.label);
                          if (label != null) {
                            await controller.updateDay(day.copyWith(
                                label: label, updatedAt: _now()));
                          }
                        case 'date':
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: day.dayDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            await controller.updateDay(
                                day.copyWith(dayDate: picked, updatedAt: _now()));
                          }
                        case 'template':
                          final name = await promptText(context,
                              title: 'Enregistrer comme modèle',
                              label: 'Nom du modèle',
                              initialValue: day.label);
                          if (name != null) {
                            await controller.saveDayAsTemplate(day.id, name);
                          }
                        case 'duplicate':
                          final target = await _chooseOtherDay(context);
                          if (target != null) {
                            await controller.duplicateDayDistributions(
                                day.id, target.id);
                          }
                        case 'delete':
                          final ok = await confirmAction(context,
                              title: 'Supprimer la journée ?',
                              message:
                                  'Les ${dists.length} distribution(s) de cette '
                                  'journée et leurs pointages seront supprimés. '
                                  'Action irréversible.',
                              confirmLabel: 'Supprimer',
                              danger: true);
                          if (ok) await controller.deleteDay(day);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                          value: 'rename', child: Text('Renommer')),
                      const PopupMenuItem(
                          value: 'date', child: Text('Définir la date')),
                      const PopupMenuItem(
                          value: 'template', child: Text('Enregistrer comme modèle')),
                      const PopupMenuItem(
                          value: 'duplicate',
                          child: Text('Copier les distributions vers…')),
                      const PopupMenuItem(
                          value: 'delete', child: Text('Supprimer la journée')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (dists.isEmpty)
              Text('Aucune distribution pour cette journée.',
                  style: TextStyle(fontSize: 13.5, color: scheme.onSurfaceVariant))
            else
              for (final d in dists) _DistributionRow(distribution: d, canEdit: canEdit, controller: controller),
            if (canEdit) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            DistributionEditScreen(dayId: day.id),
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter une distribution'),
                  ),
                  if (controller.templates.isNotEmpty)
                    TextButton.icon(
                      onPressed: () =>
                          _applyTemplate(context, day),
                      icon: const Icon(Icons.bookmarks_outlined),
                      label: const Text('Appliquer un modèle'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<TripDay?> _chooseOtherDay(BuildContext context) async {
    final others = controller.days.where((d) => d.id != day.id).toList();
    if (others.isEmpty) {
      if (context.mounted) {
        showMessage(context, 'Aucune autre journée disponible.', error: true);
      }
      return null;
    }
    return showModalBottomSheet<TripDay>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Copier vers…',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          for (final d in others)
            ListTile(
              leading: const Icon(Icons.event_note_outlined),
              title: Text(d.label),
              onTap: () => Navigator.pop(context, d),
            ),
        ],
      ),
    );
  }

  Future<void> _applyTemplate(BuildContext context, TripDay day) async {
    final template = await showModalBottomSheet<DayTemplate>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Appliquer un modèle',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          for (final t in controller.templates)
            ListTile(
              leading: const Icon(Icons.bookmarks_outlined),
              title: Text(t.name),
              subtitle: Text('${t.items.length} distribution(s)'),
              onTap: () => Navigator.pop(context, t),
            ),
        ],
      ),
    );
    if (template == null || !context.mounted) return;
    final count = await controller.applyTemplate(template, day.id);
    if (context.mounted) {
      showMessage(context, '$count distribution(s) ajoutée(s).', success: true);
    }
  }

  String _now() => DateTime.now().toUtc().toIso8601String();
}

class _DistributionRow extends StatelessWidget {
  const _DistributionRow({
    required this.distribution,
    required this.canEdit,
    required this.controller,
  });

  final Distribution distribution;
  final bool canEdit;
  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            distribution.acceptsPointage
                ? Icons.check_circle_outline
                : Icons.schedule,
            size: 18,
            color: distribution.acceptsPointage ? scheme.primary : scheme.outline,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(distribution.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '${distribution.horaires} — ${distribution.status.label}'
                  '${distribution.allowMultiple ? ' — ${distribution.maxPassages} passages' : ''}',
                  style: TextStyle(
                      fontSize: 12.5, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (canEdit)
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) =>
                        DistributionEditScreen(distribution: distribution)),
              ),
              child: const Text('Modifier'),
            ),
        ],
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({
    required this.template,
    required this.canEdit,
    required this.controller,
  });

  final DayTemplate template;
  final bool canEdit;
  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.bookmarks_outlined),
      title: Text(template.name),
      subtitle: Text('${template.items.length} distribution(s)'),
      trailing: canEdit
          ? IconButton(
              tooltip: 'Supprimer le modèle',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => controller.deleteTemplate(template),
            )
          : null,
    );
  }
}
