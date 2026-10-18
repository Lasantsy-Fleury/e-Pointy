import 'package:flutter/material.dart';

import '../../models/distribution.dart';
import '../../models/enums.dart';
import '../format.dart';

/// Boîte de dialogue de confirmation pour toute action risquée.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmer',
  String cancelLabel = 'Annuler',
  bool danger = false,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: danger
              ? FilledButton.styleFrom(backgroundColor: scheme.error)
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Demande une saisie de texte (motif de correction, nom, matricule…).
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String? label,
  String? initialValue,
  String? helper,
  bool required = true,
  TextInputType keyboardType = TextInputType.text,
}) async {
  final controller = TextEditingController(text: initialValue ?? '');
  final formKey = GlobalKey<FormState>();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: controller,
          autofocus: true,
          keyboardType: keyboardType,
          decoration: InputDecoration(labelText: label, helperText: helper),
          validator: (value) {
            if (required && (value == null || value.trim().isEmpty)) {
              return 'Ce champ est obligatoire';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState?.validate() ?? false) {
              Navigator.pop(context, controller.text.trim());
            }
          },
          child: const Text('Valider'),
        ),
      ],
    ),
  );
  return result;
}

void showMessage(BuildContext context, String message,
    {bool error = false, bool success = false}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? scheme.error : null,
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: error ? 6 : 3),
    ));
}

/// Étiquette de statut : couleur + icône + texte (jamais la couleur seule).
class StatusChip extends StatelessWidget {
  const StatusChip.session(this.status, {super.key})
      : distributionStatus = null;

  const StatusChip.distribution(this.distributionStatus, {super.key})
      : status = null;

  final SessionStatus? status;
  final DistributionStatus? distributionStatus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    late final String label;
    late final IconData icon;
    late final Color background;
    late final Color foreground;

    if (status != null) {
      label = status!.label;
      switch (status!) {
        case SessionStatus.preparation:
          icon = Icons.edit_calendar_outlined;
          background = scheme.surfaceContainerHighest;
          foreground = scheme.onSurfaceVariant;
        case SessionStatus.enCours:
          icon = Icons.play_circle_outline;
          background = scheme.primaryContainer;
          foreground = scheme.onPrimaryContainer;
        case SessionStatus.cloturee:
          icon = Icons.lock_outline;
          background = scheme.tertiaryContainer;
          foreground = scheme.onTertiaryContainer;
        case SessionStatus.archivee:
          icon = Icons.inventory_2_outlined;
          background = scheme.surfaceContainerHighest;
          foreground = scheme.onSurfaceVariant;
      }
    } else {
      label = distributionStatus!.label;
      switch (distributionStatus!) {
        case DistributionStatus.aVenir:
          icon = Icons.schedule;
          background = scheme.surfaceContainerHighest;
          foreground = scheme.onSurfaceVariant;
        case DistributionStatus.ouverte:
          icon = Icons.qr_code_scanner;
          background = scheme.primaryContainer;
          foreground = scheme.onPrimaryContainer;
        case DistributionStatus.suspendue:
          icon = Icons.pause_circle_outline;
          background = scheme.errorContainer;
          foreground = scheme.onErrorContainer;
        case DistributionStatus.cloturee:
          icon = Icons.lock_outline;
          background = scheme.tertiaryContainer;
          foreground = scheme.onTertiaryContainer;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Tuile de compteur (valeur + libellé).
class CounterTile extends StatelessWidget {
  const CounterTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color,
    this.highlight = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? color;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = highlight
        ? (color ?? scheme.primary).withValues(alpha: 0.12)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.5);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: color ?? scheme.primary),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(label,
                    style: const TextStyle(fontSize: 12.5),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: color ?? scheme.onSurface,
              )),
        ],
      ),
    );
  }
}

/// Barre de progression servis / total.
class ProgressLine extends StatelessWidget {
  const ProgressLine({
    super.key,
    required this.served,
    required this.total,
    this.height = 10,
  });

  final int served;
  final int total;
  final double height;

  @override
  Widget build(BuildContext context) {
    final value = total == 0 ? 0.0 : (served / total).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value,
        minHeight: height,
        backgroundColor:
            Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.actions = const [],
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: scheme.primary),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                ...actions,
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.icon});

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: Theme.of(context).colorScheme.outline),
            const SizedBox(width: 8),
          ],
          SizedBox(
            width: 132,
            child: Text(label, style: const TextStyle(fontSize: 14)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: scheme.outline),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant)),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// Carte de synthèse d'une distribution, au format demandé par le brief :
/// « Petit-déjeuner — 126 servis sur 150 — 84 % — 24 restants ».
class DistributionSummary extends StatelessWidget {
  const DistributionSummary({
    super.key,
    required this.distribution,
    required this.served,
    required this.total,
    this.subtitle,
  });

  final Distribution distribution;
  final int served;
  final int total;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final remaining = (total - served).clamp(0, total);
    final percent = total == 0 ? 0 : (served / total * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(distribution.name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            StatusChip.distribution(distribution.status),
          ],
        ),
        const SizedBox(height: 2),
        Text(subtitle ?? distribution.horaires,
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 10),
        Text('$served servis sur $total — $percent % — $remaining restants',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ProgressLine(served: served, total: total),
      ],
    );
  }
}

/// Bandeau d'information sur l'état hors ligne / synchronisation.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.pendingOut});

  final int pendingOut;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ok = pendingOut == 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: ok
          ? scheme.primaryContainer.withValues(alpha: 0.5)
          : scheme.tertiaryContainer.withValues(alpha: 0.6),
      child: Row(
        children: [
          Icon(ok ? Icons.cloud_done_outlined : Icons.cloud_upload_outlined,
              size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ok
                  ? 'Données locales — aucun pointage en attente d’envoi.'
                  : 'Données locales — $pendingOut pointage(s) en attente '
                      'd’envoi vers un autre appareil.',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Affiche la date-heure d'un pointage de façon lisible.
String pointageStamp(String isoLocal) => formatIso(isoLocal);
