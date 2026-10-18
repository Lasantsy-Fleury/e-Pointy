import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_database.dart';
import '../../models/student.dart';
import '../../services/export_service.dart';
import '../../services/file_output.dart';
import '../../state/app_settings.dart';
import '../../state/session_controller.dart';
import '../widgets/app_widgets.dart';
import 'import_preview_screen.dart';
import 'student_card_screen.dart';

/// Gestion de la liste des étudiants : import Excel, ajout manuel, activer
/// ou désactiver, suppression (protégée).
class StudentsManageScreen extends StatefulWidget {
  const StudentsManageScreen({super.key});

  @override
  State<StudentsManageScreen> createState() => _StudentsManageScreenState();
}

class _StudentsManageScreenState extends State<StudentsManageScreen> {
  bool _busy = false;

  Future<void> _importExcel() async {
    final controller = context.read<SessionController>();
    setState(() => _busy = true);
    try {
      final path = await FileOutput.pickFile(extensions: ['xlsx']);
      if (path == null || !mounted) return;
      final report = await controller.analyzeImportFile(path);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ImportPreviewScreen(report: report),
      ));
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addStudent() async {
    final settings = context.read<AppSettings>();
    if (!settings.canConfigure) {
      showMessage(context, 'Réservé au responsable.', error: true);
      return;
    }
    final matricule = await promptText(
      context,
      title: 'Ajouter un étudiant',
      label: 'Matricule *',
      keyboardType: TextInputType.number,
    );
    if (matricule == null || !mounted) return;
    final name = await promptText(
      context,
      title: 'Ajouter un étudiant',
      label: 'Nom et Prénoms *',
      helper: 'Ex. RAKOTO Jean',
    );
    if (name == null || !mounted) return;
    final controller = context.read<SessionController>();
    try {
      await controller.addStudent(matricule, name);
      if (mounted) showMessage(context, 'Étudiant ajouté.', success: true);
    } catch (e) {
      if (mounted) {
        showMessage(context,
            'Impossible d’ajouter (matricule déjà présent ?) : $e',
            error: true);
      }
    }
  }

  Future<void> _open(Student student) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StudentCardScreen(student: student)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final controller = context.watch<SessionController>();
    final students = controller.students;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gérer les étudiants'),
        actions: [
          if (settings.canConfigure)
            IconButton(
              tooltip: 'Ajouter manuellement',
              icon: const Icon(Icons.person_add_outlined),
              onPressed: _addStudent,
            ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              Card(
                color: scheme.primaryContainer.withValues(alpha: 0.4),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Importer depuis Excel',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(
                        'Fichier .xlsx avec les colonnes « Matricule » et '
                        '« Nom et Prénoms ». La liste est analysée et '
                        'vérifiée avant tout import.',
                        style: TextStyle(
                            fontSize: 13, color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _importExcel,
                          icon: const Icon(Icons.upload_file_outlined),
                          label: const Text('Choisir un fichier Excel'),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _generateSample,
                          icon: const Icon(Icons.file_download_outlined),
                          label: const Text('Créer un exemple de fichier'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text('Étudiants (${students.length})',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              if (students.isEmpty)
                const EmptyState(
                  icon: Icons.people_outline,
                  title: 'Aucun étudiant',
                  message: 'Importez un fichier Excel ou ajoutez un étudiant '
                      'manuellement.',
                )
              else
                for (final s in students)
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: s.active
                            ? scheme.primaryContainer
                            : scheme.surfaceContainerHighest,
                        child: Text(
                          s.fullName.isEmpty
                              ? '?'
                              : s.fullName[0].toUpperCase(),
                        ),
                      ),
                      title: Text(s.fullName),
                      subtitle: Text('Matricule ${s.matricule}'),
                      trailing: s.active
                          ? const Icon(Icons.check_circle_outline)
                          : const Chip(label: Text('Désactivé')),
                      onTap: () => _open(s),
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
    );
  }

  Future<void> _generateSample() async {
    setState(() => _busy = true);
    try {
      final service = ExportService(AppDatabase.instance);
      final path = await service.writeSampleImportFile();
      if (!mounted) return;
      showMessage(
        context,
        'Exemple créé :$path — partagez-le puis importez-le.',
        success: true,
      );
    } catch (e) {
      if (mounted) showMessage(context, 'Échec : $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
