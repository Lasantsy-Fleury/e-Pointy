import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../state/app_settings.dart';
import '../widgets/app_widgets.dart';

/// Identité de l'appareil, rôle et code PIN local.
///
/// Tout est local : le rôle gate les actions sensibles (configuration,
/// corrections). Un changement de rôle peut demander le PIN s'il est défini.
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key, this.sessionId});

  /// Session courante (informatif) ; conservé pour compatibilité d'appel.
  final String? sessionId;

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _nameController = TextEditingController();
  final _operatorController = TextEditingController();
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final settings = context.read<AppSettings>();
      _nameController.text = settings.deviceName;
      _operatorController.text = settings.operatorName;
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _operatorController.dispose();
    super.dispose();
  }

  Future<bool> _verifyIfNeeded(AppSettings settings) async {
    if (!settings.hasPin) return true;
    final pin = await promptText(
      context,
      title: 'Code PIN requis',
      label: 'PIN',
      keyboardType: TextInputType.number,
    );
    if (pin == null) return false;
    if (!settings.verifyPin(pin)) {
      if (mounted) showMessage(context, 'PIN incorrect.', error: true);
      return false;
    }
    return true;
  }

  Future<void> _setRole(AppSettings settings, UserRole role) async {
    if (role == settings.role) return;
    if (role == UserRole.responsable && !settings.isAdmin) {
      final unlock = await _verifyIfNeeded(settings);
      if (!unlock) return;
    }
    await settings.setRole(role);
    if (mounted) {
      showMessage(context, 'Rôle : ${role.label}', success: true);
    }
  }

  Future<void> _editPin(AppSettings settings) async {
    final current = await promptText(
      context,
      title: settings.hasPin ? 'PIN actuel' : 'Définir un PIN',
      label: settings.hasPin ? 'PIN actuel' : 'Nouveau PIN',
      helper: settings.hasPin
          ? 'Saisissez le PIN actuel pour le modifier.'
          : 'Choisissez 4 à 6 chiffres. Le PIN protège les actions sensibles.',
      keyboardType: TextInputType.number,
      required: false,
    );
    if (current == null || !mounted) return;
    if (settings.hasPin && !settings.verifyPin(current)) {
      if (mounted) showMessage(context, 'PIN actuel incorrect.', error: true);
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.password),
              title: const Text('Définir / changer le PIN'),
              onTap: () => Navigator.pop(context, 'set'),
            ),
            if (settings.hasPin)
              ListTile(
                leading: const Icon(Icons.lock_open_outlined),
                title: const Text('Supprimer le PIN'),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    if (action == 'remove') {
      await settings.setPin(null);
      if (mounted) showMessage(context, 'PIN supprimé.', success: true);
      return;
    }
    final pin = await promptText(
      context,
      title: 'Nouveau PIN',
      label: 'PIN (4 à 6 chiffres)',
      keyboardType: TextInputType.number,
    );
    if (pin == null || !mounted) return;
    if (pin.length < 4) {
      showMessage(context, 'Le PIN doit contenir au moins 4 caractères.',
          error: true);
      return;
    }
    await settings.setPin(pin);
    if (mounted) showMessage(context, 'PIN enregistré.', success: true);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Appareil, rôle et sécurité')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          SectionCard(
            title: 'Identité de l’appareil',
            icon: Icons.smartphone,
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom de l’appareil',
                    helperText:
                        'Ce nom apparaît comme « Appareil source » lors des transferts.',
                  ),
                  onSubmitted: (v) => settings.setDeviceName(v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _operatorController,
                  decoration: const InputDecoration(
                    labelText: 'Nom de l’opérateur (facultatif)',
                    helperText:
                        'Enregistré avec chaque pointage pour la traçabilité.',
                  ),
                  onSubmitted: (v) => settings.setOperatorName(v),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      await settings.setDeviceName(_nameController.text);
                      await settings.setOperatorName(_operatorController.text);
                      if (context.mounted) {
                        showMessage(context, 'Identité enregistrée.',
                            success: true);
                      }
                    },
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Enregistrer'),
                  ),
                ),
                const SizedBox(height: 6),
                InfoRow('Identifiant technique', settings.deviceId),
              ],
            ),
          ),

          SectionCard(
            title: 'Rôle sur cet appareil',
            icon: Icons.badge_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Le rôle détermine les actions autorisées : configuration du '
                  'plan, corrections de pointage, exports sensibles.',
                  style: TextStyle(
                      fontSize: 13, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                RadioGroup<UserRole>(
                  groupValue: settings.role,
                  onChanged: (v) => _setRole(settings, v!),
                  child: Column(
                    children: [
                      for (final role in UserRole.values)
                        RadioListTile<UserRole>(
                          value: role,
                          contentPadding: EdgeInsets.zero,
                          title: Text(role.label),
                          subtitle: Text(_roleHint(role),
                              style: const TextStyle(fontSize: 12.5)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SectionCard(
            title: 'Code PIN (facultatif)',
            icon: Icons.lock_outline,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settings.hasPin
                      ? 'Un PIN est défini : il est demandé pour les actions '
                          'sensibles (passage au rôle responsable).'
                      : 'Aucun PIN défini : toute action est autorisée sur cet '
                          'appareil.',
                  style: const TextStyle(fontSize: 13.5),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _editPin(settings),
                    icon: const Icon(Icons.password),
                    label: Text(settings.hasPin
                        ? 'Modifier ou supprimer le PIN'
                        : 'Définir un PIN'),
                  ),
                ),
              ],
            ),
          ),

          SectionCard(
            title: 'Préférences',
            icon: Icons.tune,
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: settings.soundEnabled,
                  onChanged: settings.setSoundEnabled,
                  title: const Text('Retour sonore au scan'),
                  subtitle: const Text(
                      'Indique le résultat d’un scan par un signal sonore.'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Durée de conservation des données'),
                  subtitle: Text('${settings.retentionDays} jours'),
                ),
                Slider(
                  value: settings.retentionDays.toDouble(),
                  min: 30,
                  max: 730,
                  divisions: 14,
                  label: '${settings.retentionDays} j',
                  onChanged: (v) =>
                      settings.setRetentionDays(v.round()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _roleHint(UserRole role) => switch (role) {
        UserRole.responsable =>
          'Accès complet : configuration, corrections, exports, conflits.',
        UserRole.pointeur =>
          'Peut pointer et consulter ; pas de configuration ni de correction.',
        UserRole.lecture =>
          'Consultation seule : aucun pointage possible.',
      };
}
