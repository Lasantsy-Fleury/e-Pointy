import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Écriture de fichiers locaux et partage (aucune connexion Internet requise).
class FileOutput {
  FileOutput._();

  /// Répertoire de travail des exports et sauvegardes.
  static Future<Directory> workDir() async {
    final dir = await getTemporaryDirectory();
    final sub = Directory(p.join(dir.path, 'epointy'));
    if (!await sub.exists()) {
      await sub.create(recursive: true);
    }
    return sub;
  }

  static Future<File> writeBytes(String fileName, List<int> bytes) async {
    final dir = await workDir();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<File> writeText(String fileName, String content) async {
    final dir = await workDir();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(content, flush: true);
    return file;
  }

  /// Ouvre le partage natif (Android : partage de fichier, Bluetooth, SD…).
  static Future<ShareResult> shareFile(String path,
      {String? text, String? subject}) async {
    return SharePlus.instance.share(ShareParams(
      files: [XFile(path)],
      text: text,
      subject: subject,
    ));
  }

  /// Sélectionne un fichier sur l'appareil (lecture seule, hors ligne).
  static Future<String?> pickFile({List<String>? extensions}) async {
    final file = await FilePicker.pickFile(
      type: extensions == null ? FileType.any : FileType.custom,
      allowedExtensions: extensions,
    );
    return file?.path;
  }
}
