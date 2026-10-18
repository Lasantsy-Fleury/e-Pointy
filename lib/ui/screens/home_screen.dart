import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../models/travel_session.dart';
import '../../state/app_settings.dart';
import '../../state/session_controller.dart';
import '../flows/bundle_flow.dart';
import '../format.dart';
import '../widgets/app_widgets.dart';
import 'security_screen.dart';
import 'session_form_screen.dart';
import 'session_shell.dart';

/// Écran d'accueil : liste des sessions de voyage de cet appareil.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<TravelSession> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final controller = context.read<SessionController>();
    setState(() => _loading = true);
    final sessions = await controller.allSessions();
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _loading = false;
    });
  }

  Future<void> _open(TravelSession session) async {
    final controller = context.read<SessionController>();
    await controller.open(session.id);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SessionShell()),
    );
    await _load();
  }

  Future<void> _createSession() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SessionFormScreen()),
    );
    await _load();
  }

  Future<void> _receiveTransfer() async {
    final settings = context.read<AppSettings>();
    final report = await importBundleFlow(
      context,
      actor: settings.operatorName.isEmpty ? settings.deviceName : settings.operatorName,
      title: 'Recevoir une session',
    );
    if (report != null && mounted) {
      await _load();
      if (!mounted) return;
      showMessage(context, 'Données reçues : ${report.summary}', success: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/logo.png', height: 40, fit: BoxFit.contain),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('e-Pointy'),
                  Text('Pointage des distributions — hors ligne',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Appareil et rôle',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const SecurityScreen(sessionId: null)),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? EmptyState(
                  icon: Icons.luggage_outlined,
                  title: 'Aucune session de voyage',
                  message:
                      'Créez une session pour importer la liste des étudiants, '
                      'configurer les distributions (repas, eau, collations…) '
                      'et pointer hors ligne.',
                  action: FilledButton.icon(
                    onPressed: _createSession,
                    icon: const Icon(Icons.add),
                    label: const Text('Créer une session'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.only(top: 6, bottom: 90),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Text(
                          'Appareil : ${settings.deviceName} — rôle : '
                          '${settings.roleLabel}',
                          style: TextStyle(
                              fontSize: 13, color: scheme.onSurfaceVariant),
                        ),
                      ),
                      for (final session in _sessions)
                        _SessionCard(
                          session: session,
                          onOpen: () => _open(session),
                          onChanged: _load,
                        ),
                    ],
                  ),
                ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'receive',
            tooltip: 'Recevoir un transfert ou une sauvegarde',
            onPressed: _receiveTransfer,
            child: const Icon(Icons.download_outlined),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'create',
            onPressed: _createSession,
            icon: const Icon(Icons.add),
            label: const Text('Nouvelle session'),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.onOpen,
    required this.onChanged,
  });

  final TravelSession session;
  final VoidCallback onOpen;
  final Future<void> Function() onChanged;

  Future<void> _changeStatus(BuildContext context, SessionStatus status) async {
    final controller = context.read<SessionController>();
    if (controller.sessionId != session.id) {
      await controller.open(session.id);
    }
    if (!context.mounted) return;
    switch (status) {
      case SessionStatus.enCours:
        await confirmAction(
          context,
          title: 'Démarrer la session ?',
          message: 'La session « ${session.name} » passera « En cours ». '
              'Le pointage restera possible hors ligne.',
          confirmLabel: 'Démarrer',
        );
      case SessionStatus.cloturee:
        final ok = await confirmAction(
          context,
          title: 'Clôturer la session ?',
          message: 'La session deviendra consultable mais le pointage sera '
              'bloqué jusqu’à réouverture volontaire.',
          confirmLabel: 'Clôturer',
        );
        if (!ok) return;
      case SessionStatus.preparation:
      case SessionStatus.archivee:
        break;
    }
    await controller.setSessionStatus(status);
    await onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final start = session.startDate;
    final end = session.endDate;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(session.name,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                  StatusChip.session(session.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${start != null ? formatDate(start) : 'Début non défini'} — '
                '${end != null ? formatDate(end) : 'Fin non définie'}',
                style: TextStyle(fontSize: 13.5, color: scheme.onSurfaceVariant),
              ),
              if (session.school != null)
                Text(session.school!,
                    style: TextStyle(
                        fontSize: 13.5, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 10),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Ouvrir'),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    tooltip: 'Actions',
                    onSelected: (value) async {
                      switch (value) {
                        case 'edit':
                          await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => SessionFormScreen(session: session),
                          ));
                          await onChanged();
                        case 'start':
                          await _changeStatus(context, SessionStatus.enCours);
                        case 'close':
                          await _changeStatus(context, SessionStatus.cloturee);
                        case 'reopen':
                          await _changeStatus(context, SessionStatus.enCours);
                        case 'archive':
                          await _changeStatus(context, SessionStatus.archivee);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Modifier les informations'),
                      ),
                      if (session.status != SessionStatus.enCours)
                        const PopupMenuItem(
                          value: 'start',
                          child: Text('Démarrer la session'),
                        ),
                      if (session.status == SessionStatus.enCours)
                        const PopupMenuItem(
                          value: 'close',
                          child: Text('Clôturer la session'),
                        ),
                      const PopupMenuItem(
                        value: 'archive',
                        child: Text('Archiver'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
