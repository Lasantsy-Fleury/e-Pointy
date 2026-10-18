import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Affichage d'un QR code Mipointy (aperçu à l'écran).
///
/// Le contenu est un payload `MPT1|<sessionToken>|<studentQrToken>` :
/// aucune donnée personnelle n'y figure.
class StudentQrView extends StatelessWidget {
  const StudentQrView({
    super.key,
    required this.data,
    this.size = 120,
  });

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    return QrImageView(
      data: data,
      version: QrVersions.auto,
      size: size,
      backgroundColor: Colors.white,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Colors.black,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Colors.black,
      ),
    );
  }
}
