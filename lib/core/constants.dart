/// Constantes globales de l'application Mipointy.
library;

class AppConstants {
  AppConstants._();

  static const String appName = 'e-Pointy';
  static const String appVersion = '1.0.0';

  /// Nom du fichier de base de données locale.
  static const String dbFileName = 'epointy.db';

  /// Format et version des fichiers de transfert / sauvegarde.
  static const String bundleFormat = 'epointy-bundle';
  static const int bundleVersion = 1;

  /// Types de contenu d'un bundle.
  static const String bundleKindSync = 'sync';
  static const String bundleKindBackup = 'backup';

  /// Extension des fichiers de transfert et sauvegarde.
  static const String bundleExtension = 'epointy';

  /// Préfixe des QR codes générés par l'application.
  /// Format complet : `MPT1|<sessionToken>|<studentQrToken>`.
  static const String qrPrefix = 'MPT1';

  /// Date de la première distribution utilisée par défaut.
  static const String defaultFirstDayLabel = 'Jour 1';
}
