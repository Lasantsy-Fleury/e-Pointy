import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/travel_session.dart';
import '../../state/session_controller.dart';
import '../format.dart';
import '../widgets/app_widgets.dart';

/// Création ou modification d'une session de voyage.
class SessionFormScreen extends StatefulWidget {
  const SessionFormScreen({super.key, this.session});

  final TravelSession? session;

  @override
  State<SessionFormScreen> createState() => _SessionFormScreenState();
}

class _SessionFormScreenState extends State<SessionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.session?.name ?? '');
  late final TextEditingController _school =
      TextEditingController(text: widget.session?.school ?? '');
  late final TextEditingController _responsible =
      TextEditingController(text: widget.session?.responsible ?? '');
  late final TextEditingController _notes =
      TextEditingController(text: widget.session?.notes ?? '');
  late DateTime? _start;
  late DateTime? _end;
  bool _saving = false;

  bool get _isEdit => widget.session != null;

  @override
  void initState() {
    super.initState();
    _start = widget.session?.startDate;
    _end = widget.session?.endDate;
  }

  @override
  void dispose() {
    _name.dispose();
    _school.dispose();
    _responsible.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = (isStart ? _start : _end) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_start != null && _end != null && _end!.isBefore(_start!)) {
      showMessage(context, 'La date de fin précède la date de début.',
          error: true);
      return;
    }
    setState(() => _saving = true);
    final controller = context.read<SessionController>();
    try {
      if (_isEdit) {
        await controller.updateSession(widget.session!.copyWith(
          name: _name.text.trim(),
          school: _school.text.trim().isEmpty ? null : _school.text.trim(),
          startDate: _start,
          endDate: _end,
          responsible: _responsible.text.trim().isEmpty
              ? null
              : _responsible.text.trim(),
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        ));
      } else {
        await controller.createSession(
          name: _name.text,
          school: _school.text.trim().isEmpty ? null : _school.text,
          startDate: _start,
          endDate: _end,
          responsible:
              _responsible.text.trim().isEmpty ? null : _responsible.text,
          notes: _notes.text.trim().isEmpty ? null : _notes.text,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      showMessage(context, 'Échec de l’enregistrement : $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Modifier la session' : 'Nouvelle session'),
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
                labelText: 'Nom de la session *',
                hintText: 'Ex. Voyage d’étude — Antananarivo 2026',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nom obligatoire' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _school,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Établissement / groupe',
                hintText: 'Ex. Université d’Antananarivo',
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _responsible,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Responsable du voyage',
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(isStart: true),
                    icon: const Icon(Icons.event),
                    label: Text(_start == null
                        ? 'Date de début'
                        : 'Début : ${formatDate(_start)}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(isStart: false),
                    icon: const Icon(Icons.event),
                    label: Text(_end == null
                        ? 'Date de fin'
                        : 'Fin : ${formatDate(_end)}'),
                  ),
                ),
              ],
            ),
            if (_start != null || _end != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    _start = null;
                    _end = null;
                  }),
                  icon: const Icon(Icons.clear),
                  label: const Text('Effacer les dates'),
                ),
              ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notes (facultatif)',
                alignLabelWithHint: true,
              ),
            ),
            if (!_isEdit)
              const Padding(
                padding: EdgeInsets.only(top: 14),
                child: Text(
                  'Un plan de départ sera généré automatiquement '
                  '(3 repas et 2 distributions d’eau sur « Jour 1 »). '
                  'Vous pourrez le modifier librement par la suite.',
                  style: TextStyle(fontSize: 13),
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
              label: Text(_isEdit ? 'Enregistrer' : 'Créer la session'),
            ),
          ],
        ),
      ),
    );
  }
}
