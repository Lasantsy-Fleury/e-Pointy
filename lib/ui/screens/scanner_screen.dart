import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../models/scan_result.dart';
import '../../state/app_settings.dart';
import '../../state/session_controller.dart';
import '../widgets/app_widgets.dart';
import 'manual_search_sheet.dart';

/// Onglet « Scanner » : lecture du QR code et enregistrement du pointage.
///
/// Affiche le résultat de chaque scan de façon très visible (succès ou
/// refus), avec retour sonore et recherche manuelle de secours.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key, required this.onGoTo});

  final void Function(int index) onGoTo;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    formats: [BarcodeFormat.qrCode],
  );

  bool _paused = false;
  DateTime _lastProcessed = DateTime.fromMillisecondsSinceEpoch(0);
  ScanResult? _lastResult;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _paused = false;
      _controller.start();
    } else {
      _paused = true;
      _controller.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_paused || !mounted) return;
    final now = DateTime.now();
    if (now.difference(_lastProcessed).inMilliseconds < 1200) return;
    final value = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (value == null || value.isEmpty) return;
    _lastProcessed = now;

    final controller = context.read<SessionController>();
    final settings = context.read<AppSettings>();
    if (!settings.canScan) return;

    final result = await controller.scanRaw(value);
    if (!mounted) return;
    setState(() => _lastResult = result);
    _feedback(result);
  }

  void _feedback(ScanResult result) {
    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              result.isSuccess
                  ? Icons.check_circle
                  : result.outcome == ScanOutcome.dejaServi
                      ? Icons.info_outline
                      : Icons.error_outline,
              color: result.isSuccess
                  ? scheme.primary
                  : result.outcome == ScanOutcome.dejaServi
                      ? scheme.tertiary
                      : scheme.error,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(result.message,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (result.student != null)
                    Text(result.student!.fullName,
                        style: const TextStyle(fontSize: 13)),
                  if (result.detail != null)
                    Text(result.detail!,
                        style: const TextStyle(fontSize: 12.5)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: result.isSuccess
            ? scheme.primaryContainer
            : result.outcome == ScanOutcome.dejaServi
                ? scheme.tertiaryContainer
                : scheme.errorContainer,
        duration: Duration(seconds: result.isSuccess ? 2 : 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
    // Succès : bref retour visuel. Pas de son natif intégré au projet.
  }

  Future<void> _openManualSearch() async {
    await showManualSearchSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SessionController>();
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    final active = controller.activeDistribution;
    final session = controller.session;
    final stats = controller.activeStats;

    if (!settings.canScan) {
      return EmptyState(
        icon: Icons.lock_outline,
        title: 'Scanner indisponible',
        message: 'Le rôle « ${settings.roleLabel} » ne permet pas de '
            'pointer. Contactez le responsable.',
        action: OutlinedButton.icon(
          onPressed: () => widget.onGoTo(3),
          icon: const Icon(Icons.insights_outlined),
          label: const Text('Voir le suivi'),
        ),
      );
    }

    return Column(
      children: [
        // ---------- Contexte ----------
        Container(
          width: double.infinity,
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session?.name ?? 'Session',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                active == null
                    ? 'Aucune distribution active — choisissez-en une.'
                    : 'Distribution : ${active.name} — ${active.horaires}',
                style: TextStyle(
                    fontSize: 13.5,
                    color: active == null ? scheme.error : scheme.onSurfaceVariant),
              ),
              if (active != null && stats != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    _MiniStat('Servis', '${stats.served}'),
                    const SizedBox(width: 12),
                    _MiniStat('Restants', '${stats.remaining}'),
                    const SizedBox(width: 12),
                    _MiniStat('Total', '${stats.totalStudents}'),
                  ],
                ),
              ],
            ],
          ),
        ),

        // ---------- Caméra ----------
        Expanded(
          child: active == null
              ? EmptyState(
                  icon: Icons.restaurant_menu,
                  title: 'Choisissez une distribution',
                  message: 'Le pointage n’est possible que pour une '
                      'distribution ouverte. Retournez à l’onglet '
                      '« Distribution » pour la sélectionner.',
                  action: FilledButton.icon(
                    onPressed: () => widget.onGoTo(0),
                    icon: const Icon(Icons.restaurant_outlined),
                    label: const Text('Choisir la distribution'),
                  ),
                )
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    MobileScanner(
                      controller: _controller,
                      onDetect: _onDetect,
                      errorBuilder: (context, error) {
                        return EmptyState(
                          icon: Icons.no_photography_outlined,
                          title: 'Caméra indisponible',
                          message: 'Impossible d’accéder à la caméra : '
                              '${error.errorCode.name}. Utilisez la recherche '
                              'manuelle ci-dessous.',
                          action: FilledButton.icon(
                            onPressed: _openManualSearch,
                            icon: const Icon(Icons.search),
                            label: const Text('Recherche manuelle'),
                          ),
                        );
                      },
                    ),
                    // Cadre de visée.
                    Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: scheme.primary.withValues(alpha: 0.8),
                            width: 3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    Positioned(
                      bottom: 24,
                      left: 24,
                      right: 24,
                      child: _lastResult == null
                          ? const SizedBox.shrink()
                          : _ResultBanner(result: _lastResult!),
                    ),
                  ],
                ),
        ),

        // ---------- Actions ----------
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openManualSearch,
                    icon: const Icon(Icons.search),
                    label: const Text('Recherche manuelle'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  tooltip: _torchOn ? 'Éteindre la lampe' : 'Allumer la lampe',
                  onPressed: () async {
                    _torchOn = !_torchOn;
                    await _controller.toggleTorch();
                    if (mounted) setState(() {});
                  },
                  icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
                  iconSize: 28,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$value ',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

/// Bannière de résultat superposée à la caméra.
class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.result});
  final ScanResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (result.outcome) {
      ScanOutcome.enregistre => (scheme.primaryContainer, scheme.onPrimaryContainer),
      ScanOutcome.dejaServi => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      _ => (scheme.errorContainer, scheme.onErrorContainer),
    };
    final icon = switch (result.outcome) {
      ScanOutcome.enregistre => Icons.check_circle,
      ScanOutcome.dejaServi => Icons.info_outline,
      _ => Icons.error_outline,
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 32, color: fg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(result.message,
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700, color: fg)),
                if (result.student != null)
                  Text(result.student!.fullName,
                      style: TextStyle(fontSize: 14, color: fg)),
                if (result.detail != null)
                  Text(result.detail!,
                      style: TextStyle(fontSize: 12.5, color: fg)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Convertit une date en heure locale courte (utilisé par la recherche).
String shortTime(DateTime? d) =>
    d == null ? '—' : '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
