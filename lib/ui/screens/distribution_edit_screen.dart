import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/distribution.dart';
import '../../models/enums.dart';
import '../../state/session_controller.dart';
import '../widgets/app_widgets.dart';

/// Création ou modification d'une distribution (créneau d'un élément).
///
/// Tous les paramètres sont modifiables : nom, horaires, statut, règle de
/// passage multiple, suivi de quantité et instructions.
class DistributionEditScreen extends StatefulWidget {
  const DistributionEditScreen({super.key, this.distribution, this.dayId});

  /// Distribution à modifier (null = création).
  final Distribution? distribution;

  /// Journée cible lors d'une création directe.
  final String? dayId;

  @override
  State<DistributionEditScreen> createState() => _DistributionEditScreenState();
}

class _DistributionEditScreenState extends State<DistributionEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.distribution?.name ?? '');
  late final TextEditingController _instructions =
      TextEditingController(text: widget.distribution?.instructions ?? '');
  late String? _dayId = widget.distribution?.dayId ?? widget.dayId;
  late String? _itemTypeId = widget.distribution?.itemTypeId;
  late String? _start = widget.distribution?.startTime;
  late String? _end = widget.distribution?.endTime;
  late DistributionStatus _status =
      widget.distribution?.status ?? DistributionStatus.aVenir;
  late bool _allowMultiple = widget.distribution?.allowMultiple ?? false;
  late int _maxPassages = widget.distribution?.maxPassages ?? 1;
  late bool _trackQuantity = widget.distribution?.trackQuantity ?? false;
  bool _saving = false;

  bool get _isEdit => widget.distribution != null;

  @override
  void dispose() {
    _name.dispose();
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool isStart}) async {
    final current = isStart ? _start : _end;
    final initial = _parseTime(current) ?? const TimeOfDay(hour: 8, minute: 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      final value =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      if (isStart) {
        _start = value;
      } else {
        _end = value;
      }
    });
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null || !value.contains(':')) return null;
    final parts = value.split(':');
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0');
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_dayId == null) {
      showMessage(context, 'Choisissez une journée.', error: true);
      return;
    }
    setState(() => _saving = true);
    final controller = context.read<SessionController>();
    try {
      if (_isEdit) {
        await controller.updateDistribution(widget.distribution!.copyWith(
          name: _name.text.trim(),
          startTime: _start,
          endTime: _end,
          status: _status,
          allowMultiple: _allowMultiple,
          maxPassages: _allowMultiple ? _maxPassages : 1,
          trackQuantity: _trackQuantity,
          instructions:
              _instructions.text.trim().isEmpty ? null : _instructions.text.trim(),
        ));
      } else {
        await controller.addDistribution(
          dayId: _dayId!,
          name: _name.text,
          itemTypeId: _itemTypeId,
          startTime: _start,
          endTime: _end,
          allowMultiple: _allowMultiple,
          maxPassages: _maxPassages,
          trackQuantity: _trackQuantity,
          instructions: _instructions.text.trim().isEmpty
              ? null
              : _instructions.text,
        );
        // Applique le statut choisi dès la création.
        if (_status != DistributionStatus.aVenir) {
          final created = controller.distributions
              .where((d) => d.name == _name.text.trim())
              .toList();
          if (created.isNotEmpty) {
            await controller
                .setDistributionStatus(created.last, _status);
          }
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      showMessage(context, 'Échec : $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmAction(
      context,
      title: 'Supprimer cette distribution ?',
      message: 'Les pointages liés à « ${widget.distribution!.name} » seront '
          'supprimés. Action irréversible.',
      confirmLabel: 'Supprimer',
      danger: true,
    );
    if (!ok || !mounted) return;
    final controller = context.read<SessionController>();
    await controller.deleteDistribution(widget.distribution!);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SessionController>();
    final scheme = Theme.of(context).colorScheme;
    final days = controller.days;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Modifier la distribution' : 'Nouvelle distribution'),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: 'Supprimer',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nom de la distribution *',
                hintText: 'Ex. Petit-déjeuner, Distribution d’eau',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nom obligatoire' : null,
            ),
            const SizedBox(height: 14),

            // ---------- Journée ----------
            DropdownButtonFormField<String>(
              initialValue: _dayId,
              decoration: const InputDecoration(labelText: 'Journée *'),
              items: [
                for (final d in days)
                  DropdownMenuItem(value: d.id, child: Text(d.label)),
              ],
              onChanged: _isEdit ? null : (v) => setState(() => _dayId = v),
              validator: (v) => v == null ? 'Journée obligatoire' : null,
            ),
            const SizedBox(height: 14),

            // ---------- Type d'élément ----------
            DropdownButtonFormField<String?>(
              initialValue: _itemTypeId,
              decoration: const InputDecoration(
                  labelText: 'Type d’élément (facultatif)'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Aucun')),
                for (final t in controller.itemTypes)
                  DropdownMenuItem(value: t.id, child: Text(t.name)),
              ],
              onChanged: (v) => setState(() => _itemTypeId = v),
            ),
            const SizedBox(height: 14),

            // ---------- Horaires ----------
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickTime(isStart: true),
                    icon: const Icon(Icons.schedule),
                    label: Text(_start ?? 'Début'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickTime(isStart: false),
                    icon: const Icon(Icons.schedule),
                    label: Text(_end ?? 'Fin'),
                  ),
                ),
              ],
            ),
            if (_start != null || _end != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() {
                    _start = null;
                    _end = null;
                  }),
                  child: const Text('Effacer les horaires'),
                ),
              ),
            const SizedBox(height: 10),

            // ---------- Statut ----------
            const Text('Statut',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in DistributionStatus.values)
                  ChoiceChip(
                    label: Text(s.label),
                    selected: _status == s,
                    avatar: Icon(
                      switch (s) {
                        DistributionStatus.aVenir => Icons.schedule,
                        DistributionStatus.ouverte => Icons.qr_code_scanner,
                        DistributionStatus.suspendue =>
                          Icons.pause_circle_outline,
                        DistributionStatus.cloturee => Icons.lock_outline,
                      },
                      size: 16,
                    ),
                    onSelected: (_) => setState(() => _status = s),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Seule une distribution « Ouverte » accepte des pointages.',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),

            // ---------- Règles ----------
            const Text('Règle de pointage',
                style: TextStyle(fontWeight: FontWeight.w700)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _allowMultiple,
              onChanged: (v) => setState(() => _allowMultiple = v),
              title: const Text('Autoriser plusieurs passages'),
              subtitle: const Text(
                  'Par défaut : un seul passage validé par étudiant.'),
            ),
            if (_allowMultiple)
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 8),
                child: Row(
                  children: [
                    const Text('Nombre maximal de passages'),
                    const Spacer(),
                    IconButton(
                      onPressed: _maxPassages > 1
                          ? () => setState(() => _maxPassages--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('$_maxPassages',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    IconButton(
                      onPressed: _maxPassages < 20
                          ? () => setState(() => _maxPassages++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _trackQuantity,
              onChanged: (v) => setState(() => _trackQuantity = v),
              title: const Text('Suivre une quantité remise'),
              subtitle: const Text(
                  'Distingue « dotation reçue » et « quantité remise ».'),
            ),
            const SizedBox(height: 10),

            TextFormField(
              controller: _instructions,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Instructions pour les pointeurs (facultatif)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_isEdit ? 'Enregistrer' : 'Créer la distribution'),
            ),
          ],
        ),
      ),
    );
  }
}
