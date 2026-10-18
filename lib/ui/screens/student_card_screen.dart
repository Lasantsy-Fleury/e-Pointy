import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../models/pointage.dart';
import '../../models/student.dart';
import '../../state/app_settings.dart';
import '../../state/session_controller.dart';
import '../format.dart';
import '../widgets/app_widgets.dart';
import 'qr_badges_screen.dart';

/// Fiche d'un étudiant : identité, QR, historique de pointages et corrections.
class StudentCardScreen extends StatefulWidget {
  const StudentCardScreen({super.key, required this.student});

  final Student student;

  @override
  State<StudentCardScreen> createState() => _StudentCardScreenState();
}

class _StudentCardScreenState extends State<StudentCardScreen> {
  late Student _student;
  List<Pointage> _pointages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _student = widget.student;
    _load();
  }

  Future<void> _load() async {
    final controller = context.read<SessionController>();
    final pointages = await controller.pointagesOfStudent(_student.id);
    final refreshed = await controller.studentDao.getById(_student.id);
    if (!mounted) return;
    setState(() {
      _pointages = pointages;
      if (refreshed != null) _student = refreshed;
      _loading = false;
    });
  }

  Future<void> _toggleActive() async {
    final settings = context.read<AppSettings>();
    if (!settings.canCorrect) {
      showMessage(context, 'Réservé au responsable.', error: true);
      return;
    }
    final next = !_student.active;
    final ok = await confirmAction(
      context,
      title: next ? 'Réactiver cet étudiant ?' : 'Désactiver cet étudiant ?',
      message: next
          ? 'L’étudiant pourra être pointé à nouveau.'
          : 'L’étudiant ne pourra plus être pointé. Ses pointages existants '
              'sont conservés.',
      confirmLabel: next ? 'Réactiver' : 'Désactiver',
      danger: !next,
    );
    if (!ok || !mounted) return;
    final controller = context.read<SessionController>();
    await controller.setStudentActive(_student, next);
    await _load();
  }

  Future<void> _cancel(Pointage p) async {
    final settings = context.read<AppSettings>();
    if (!settings.canCorrect) {
      showMessage(context, 'Réservé au responsable.', error: true);
      return;
    }
    final reason = await promptText(
      context,
      title: 'Annuler ce pointage',
      label: 'Motif de la correction *',
      helper: 'La trace d’origine est conservée dans l’historique.',
    );
    if (reason == null || !mounted) return;
    final controller = context.read<SessionController>();
    await controller.cancelPointage(p, reason);
    await _load();
    if (!mounted) return;
    showMessage(context, 'Pointage annulé — trace conservée.', success: true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fiche étudiant'),
        actions: [
          IconButton(
            tooltip: 'Voir / imprimer les QR',
            icon: const Icon(Icons.qr_code_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const QrBadgesScreen()),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  // ---------- Identité ----------
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: _student.active
                                    ? scheme.primaryContainer
                                    : scheme.surfaceContainerHighest,
                                child: Text(
                                  _student.fullName.isEmpty
                                      ? '?'
                                      : _student.fullName[0].toUpperCase(),
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(_student.fullName,
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    Text('Matricule : ${_student.matricule}',
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: scheme.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _student.active
                                      ? scheme.primaryContainer
                                      : scheme.errorContainer,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _student.active
                                          ? Icons.check_circle_outline
                                          : Icons.person_off_outlined,
                                      size: 16,
                                      color: _student.active
                                          ? scheme.onPrimaryContainer
                                          : scheme.onErrorContainer,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                        _student.active
                                            ? 'Actif'
                                            : 'Désactivé',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: _student.active
                                                ? scheme.onPrimaryContainer
                                                : scheme.onErrorContainer)),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: _toggleActive,
                                icon: Icon(
                                  _student.active
                                      ? Icons.person_off_outlined
                                      : Icons.person_add_outlined,
                                  size: 18,
                                ),
                                label: Text(_student.active
                                    ? 'Désactiver'
                                    : 'Réactiver'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          InfoRow('Token QR', _student.qrToken,
                              icon: Icons.qr_code_outlined),
                          InfoRow(
                              'Créé le', formatIso(_student.createdAt),
                              icon: Icons.schedule),
                          InfoRow(
                              'Mis à jour', formatIso(_student.updatedAt),
                              icon: Icons.update),
                        ],
                      ),
                    ),
                  ),

                  // ---------- Historique ----------
                  SectionCard(
                    title: 'Historique de pointages (${_pointages.length})',
                    icon: Icons.history,
                    child: _pointages.isEmpty
                        ? const Text('Aucun pointage pour cet étudiant.',
                            style: TextStyle(fontSize: 14))
                        : Column(
                            children: [
                              for (final p in _pointages)
                                _PointageTile(
                                  pointage: p,
                                  canCancel: p.isValid,
                                  onCancel: () => _cancel(p),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _PointageTile extends StatelessWidget {
  const _PointageTile({
    required this.pointage,
    required this.canCancel,
    required this.onCancel,
  });

  final Pointage pointage;
  final bool canCancel;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (color, icon, label) = switch (pointage.status) {
      PointageStatus.valide => (
          scheme.primary,
          Icons.check_circle_outline,
          'Validé',
        ),
      PointageStatus.doublonPotentiel => (
          scheme.tertiary,
          Icons.copy_all_outlined,
          'Doublon potentiel',
        ),
      PointageStatus.annule => (
          scheme.error,
          Icons.cancel_outlined,
          'Annulé',
        ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: color)),
                ),
                if (canCancel)
                  IconButton(
                    tooltip: 'Annuler ce pointage',
                    icon: const Icon(Icons.undo_outlined, size: 20),
                    onPressed: onCancel,
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${pointage.mode.label} — quantité ${pointage.quantity}',
              style: const TextStyle(fontSize: 13),
            ),
            Text(
              'Enregistré le ${formatIso(pointage.recordedAtLocal)} '
              '(UTC ${formatIso(pointage.recordedAtUtc)})',
              style: const TextStyle(fontSize: 12.5),
            ),
            if (pointage.deviceName != null || pointage.operator != null)
              Text(
                'Appareil : ${pointage.deviceName ?? pointage.deviceId}'
                '${pointage.operator != null ? ' — opérateur : ${pointage.operator}' : ''}',
                style: TextStyle(
                    fontSize: 12.5, color: scheme.onSurfaceVariant),
              ),
            if (pointage.correctionReason != null)
              Text(
                'Motif : ${pointage.correctionReason}',
                style: TextStyle(fontSize: 12.5, color: scheme.error),
              ),
          ],
        ),
      ),
    );
  }
}
