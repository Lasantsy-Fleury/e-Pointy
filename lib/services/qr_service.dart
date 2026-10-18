import '../core/constants.dart';

/// Encodage / décodage des QR codes.
///
/// Le QR code ne contient jamais de nom ni de matricule : uniquement deux
/// tokens courts (session + étudiant), vérifiables hors ligne.
class QrService {
  QrService._();

  /// Encode le QR d'un étudiant : `MPT1|<sessionToken>|<studentQrToken>`.
  static String encodeForStudent({
    required String sessionToken,
    required String studentQrToken,
  }) =>
      '${AppConstants.qrPrefix}|$sessionToken|$studentQrToken';

  /// Décode un contenu QR. Retourne null si le format est invalide.
  static QrPayload? decode(String raw) {
    final parts = raw.trim().split('|');
    if (parts.length != 3) return null;
    if (parts[0] != AppConstants.qrPrefix) return null;
    final sessionToken = parts[1].trim();
    final studentToken = parts[2].trim();
    if (sessionToken.isEmpty || studentToken.isEmpty) return null;
    return QrPayload(sessionToken: sessionToken, studentToken: studentToken);
  }
}

class QrPayload {
  const QrPayload({required this.sessionToken, required this.studentToken});
  final String sessionToken;
  final String studentToken;
}
