import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_settings.dart';
import '../../state/session_controller.dart';
import '../widgets/app_widgets.dart';
import 'distribution_screen.dart';
import 'scanner_screen.dart';
import 'settings_screen.dart';
import 'students_screen.dart';
import 'tracking_screen.dart';

/// Navigation principale d'une session ouverte : 5 onglets.
///
/// Onglets masqués selon le rôle :
/// - « Scanner » et « Réglages » uniquement pour les rôles autorisés ;
/// - le rôle « lecture » n'accède pas au scanner.
class SessionShell extends StatefulWidget {
  const SessionShell({super.key});

  @override
  State<SessionShell> createState() => _SessionShellState();
}

class _SessionShellState extends State<SessionShell> {
  int _index = 0;

  /// Navigue vers un onglet (utilisé par les boutons des écrans enfants).
  void _goTo(int index) {
    if (index == _index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final controller = context.watch<SessionController>();

    final destinations = <_Destination>[
      _Destination(Icons.restaurant_outlined, Icons.restaurant, 'Distribution'),
      _Destination(Icons.qr_code_scanner_outlined, Icons.qr_code_scanner,
          'Scanner'),
      _Destination(Icons.people_alt_outlined, Icons.people_alt, 'Étudiants'),
      _Destination(Icons.insights_outlined, Icons.insights, 'Suivi'),
      _Destination(Icons.settings_outlined, Icons.settings, 'Réglages'),
    ];

    // Filtrage selon le rôle.
    final allowed = <int>[2, 3]; // Étudiants + Suivi toujours visibles.
    if (settings.canScan) {
      allowed.add(0); // Distribution (accès au scan)
      allowed.add(1); // Scanner
    }
    if (settings.canConfigure) allowed.add(4); // Réglages

    final visibleIndices = allowed.toList()..sort();
    final pages = <int, Widget>{
      0: DistributionScreen(onGoTo: _goTo),
      1: ScannerScreen(onGoTo: _goTo),
      2: StudentsScreen(onGoTo: _goTo),
      3: TrackingScreen(onGoTo: _goTo),
      4: SettingsScreen(onGoTo: _goTo),
    };

    // L'onglet courant peut devenir interdit après un changement de rôle.
    if (!visibleIndices.contains(_index)) {
      _index = visibleIndices.first;
    }

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: visibleIndices.indexOf(_index),
          children: [for (final i in visibleIndices) pages[i]!],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: visibleIndices.indexOf(_index).clamp(
            0, visibleIndices.length - 1),
        onDestinationSelected: (vi) => _goTo(visibleIndices[vi]),
        destinations: [
          for (final i in visibleIndices)
            NavigationDestination(
              icon: Icon(destinations[i].outline),
              selectedIcon: Icon(destinations[i].filled),
              label: destinations[i].label,
            ),
        ],
      ),
      bottomSheet: controller.pendingOut > 0
          ? OfflineBanner(pendingOut: controller.pendingOut)
          : null,
    );
  }
}

class _Destination {
  const _Destination(this.outline, this.filled, this.label);
  final IconData outline;
  final IconData filled;
  final String label;
}
