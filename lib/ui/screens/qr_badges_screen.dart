import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/app_database.dart';
import '../../models/student.dart';
import '../../services/file_output.dart';
import '../../services/qr_badges_service.dart';
import '../../services/qr_service.dart';
import '../../state/session_controller.dart';
import '../widgets/app_widgets.dart';
import 'qr_flutter_widgets.dart';

/// Génération et aperçu des QR codes étudiants (PDF imprimable A4).
///
/// Le QR ne contient que deux tokens courts : aucune donnée personnelle.
class QrBadgesScreen extends StatefulWidget {
  const QrBadgesScreen({super.key});

  @override
  State<QrBadgesScreen> createState() => _QrBadgesScreenState();
}

class _QrBadgesScreenState extends State<QrBadgesScreen> {
  bool _activeOnly = true;
  bool _includeNames = true;
  bool _busy = false;

  Future<void> _generate() async {
    final controller = context.read<SessionController>();
    final sessionId = controller.sessionId;
    if (sessionId == null) return;
    setState(() => _busy = true);
    try {
      final service = QrBadgesService(AppDatabase.instance);
      final path = await service.buildBadgesPdf(
        sessionId: sessionId,
        activeOnly: _activeOnly,
        includeNames: _includeNames,
      );
      if (!mounted) return;
      final result = await FileOutput.shareFile(
        path,
        text: 'QR codes étudiants — Mipointy (à imprimer)',
      );
      if (!mounted) return;
      showMessage(
        context,
        result.status == ShareResultStatus.success
            ? 'Planche PDF transmise.'
            : 'Planche PDF créée : $path',
        success: true,
      );
    } catch (e) {
      if (mounted) showMessage(context, 'Échec : $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SessionController>();
    final scheme = Theme.of(context).colorScheme;
    final session = controller.session;
    final students = _activeOnly
        ? controller.students.where((s) => s.active).toList()
        : controller.students;

    return Scaffold(
      appBar: AppBar(title: const Text('QR codes des étudiants')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              Card(
                color: scheme.primaryContainer.withValues(alpha: 0.4),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.privacy_tip_outlined, size: 32),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Le QR code ne contient aucune donnée personnelle : '
                          'uniquement un token de session et un token '
                          'étudiant, vérifiables hors ligne.',
                          style: TextStyle(fontSize: 13.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SwitchListTile(
                title: const Text('Étudiants actifs seulement'),
                value: _activeOnly,
                onChanged: (v) => setState(() => _activeOnly = v),
              ),
              SwitchListTile(
                title: const Text('Afficher le nom sur le badge'),
                value: _includeNames,
                onChanged: (v) => setState(() => _includeNames = v),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('Aperçu (${students.length} badge(s))',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              if (students.isEmpty)
                const EmptyState(
                  icon: Icons.qr_code_outlined,
                  title: 'Aucun étudiant',
                  message: 'Importez ou ajoutez des étudiants pour générer '
                      'leurs QR codes.',
                )
              else
                for (final s in students.take(50))
                  _StudentQrTile(
                    student: s,
                    sessionToken: session?.token ?? '',
                    includeName: _includeNames,
                  ),
              if (students.length > 50)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Aperçu limité à 50 badges. Le PDF contiendra les '
                    '${students.length} étudiants.',
                    style: TextStyle(
                        fontSize: 12.5, color: scheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black26,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: _busy || students.isEmpty ? null : _generate,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Générer la planche PDF'),
          ),
        ),
      ),
    );
  }
}

class _StudentQrTile extends StatelessWidget {
  const _StudentQrTile({
    required this.student,
    required this.sessionToken,
    required this.includeName,
  });

  final Student student;
  final String sessionToken;
  final bool includeName;

  @override
  Widget build(BuildContext context) {
    final data = QrService.encodeForStudent(
      sessionToken: sessionToken,
      studentQrToken: student.qrToken,
    );
    return Card(
      child: ListTile(
        leading: SizedBox(
          width: 52,
          height: 52,
          child: StudentQrView(data: data, size: 48),
        ),
        title: Text(includeName ? student.fullName : 'Badge étudiant'),
        subtitle: Text('Matricule ${student.matricule}'),
        trailing: student.active
            ? null
            : const Chip(label: Text('Désactivé')),
      ),
    );
  }
}
