import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils.dart';
import '../models/enums.dart';
import '../services/scan_service.dart';

/// Paramètres locaux de l'appareil : identité, rôle, opérateur, PIN,
/// retour sonore. Tout fonctionne hors ligne.
class AppSettings extends ChangeNotifier {
  static const _kDeviceId = 'device_id';
  static const _kDeviceName = 'device_name';
  static const _kRole = 'role';
  static const _kOperator = 'operator_name';
  static const _kPin = 'pin_code';
  static const _kSound = 'sound_enabled';
  static const _kLastSession = 'last_session_id';
  static const _kRetention = 'retention_days';

  SharedPreferences? _prefs;

  String deviceId = '';
  String deviceName = 'Appareil 1';
  UserRole role = UserRole.pointeur;
  String operatorName = '';
  String? pinCode;
  bool soundEnabled = true;
  String? lastSessionId;
  int retentionDays = 90;

  bool get isLoaded => _prefs != null;
  bool get isAdmin => role == UserRole.responsable;
  bool get canCorrect => role == UserRole.responsable;
  bool get canConfigure => role == UserRole.responsable;
  bool get canScan => role != UserRole.lecture;
  bool get hasPin => pinCode != null && pinCode!.isNotEmpty;

  String get roleLabel => role.label;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    deviceId = _prefs!.getString(_kDeviceId) ?? '';
    if (deviceId.isEmpty) {
      deviceId = newId();
      await _prefs!.setString(_kDeviceId, deviceId);
    }
    deviceName = _prefs!.getString(_kDeviceName) ?? 'Appareil 1';
    role = UserRole.fromCode(_prefs!.getString(_kRole));
    operatorName = _prefs!.getString(_kOperator) ?? '';
    pinCode = _prefs!.getString(_kPin);
    soundEnabled = _prefs!.getBool(_kSound) ?? true;
    lastSessionId = _prefs!.getString(_kLastSession);
    retentionDays = _prefs!.getInt(_kRetention) ?? 90;
    notifyListeners();
  }

  Future<void> setDeviceName(String value) async {
    deviceName = value.trim().isEmpty ? 'Appareil 1' : value.trim();
    await _prefs?.setString(_kDeviceName, deviceName);
    notifyListeners();
  }

  Future<void> setOperatorName(String value) async {
    operatorName = value.trim();
    await _prefs?.setString(_kOperator, operatorName);
    notifyListeners();
  }

  Future<void> setRole(UserRole value) async {
    role = value;
    await _prefs?.setString(_kRole, value.code);
    notifyListeners();
  }

  Future<void> setPin(String? value) async {
    pinCode = (value == null || value.trim().isEmpty) ? null : value.trim();
    if (pinCode == null) {
      await _prefs?.remove(_kPin);
    } else {
      await _prefs?.setString(_kPin, pinCode!);
    }
    notifyListeners();
  }

  Future<void> setSoundEnabled(bool value) async {
    soundEnabled = value;
    await _prefs?.setBool(_kSound, value);
    notifyListeners();
  }

  Future<void> setRetentionDays(int value) async {
    retentionDays = value;
    await _prefs?.setInt(_kRetention, value);
    notifyListeners();
  }

  Future<void> setLastSession(String? sessionId) async {
    lastSessionId = sessionId;
    if (sessionId == null) {
      await _prefs?.remove(_kLastSession);
    } else {
      await _prefs?.setString(_kLastSession, sessionId);
    }
  }

  /// Vérifie un code PIN. Sans PIN défini, toute action est autorisée.
  bool verifyPin(String input) {
    if (!hasPin) return true;
    return pinCode == input.trim();
  }

  /// Contexte transmis aux pointages (appareil + opérateur).
  OperatorContext get operatorContext => OperatorContext(
        deviceId: deviceId,
        deviceName: deviceName,
        operator: operatorName,
      );
}
