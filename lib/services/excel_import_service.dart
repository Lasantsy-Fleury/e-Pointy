import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;

import '../core/utils.dart';
import '../models/import_report.dart';

/// Lecture et validation d'un fichier Excel d'étudiants.
///
/// Format attendu : deux colonnes fonctionnelles « Matricule » et
/// « Nom et Prénoms ». Si le format n'est pas reconnu, une erreur explicite
/// est levée — jamais d'import silencieux de données incorrectes.
class ExcelImportService {
  ExcelImportService._();

  /// Lit et analyse le fichier, sans rien écrire en base.
  static Future<ImportReport> parseFile(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    return parseBytes(bytes, fallbackName: p.basename(filePath));
  }

  static ImportReport parseBytes(List<int> bytes, {String? fallbackName}) {
    final Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (_) {
      throw const ImportFormatException(
          "Le fichier n'est pas un fichier Excel (.xlsx) lisible.");
    }
    if (excel.tables.isEmpty) {
      throw const ImportFormatException('Le fichier ne contient aucune feuille.');
    }

    // 1. Localiser la ligne d'en-têtes contenant « matricule » et « nom ».
    String? sheetName;
    int headerRow = -1;
    int matriculeCol = -1;
    int nameCol = -1;

    for (final name in excel.tables.keys) {
      final sheet = excel.tables[name]!;
      for (var r = 0; r < sheet.maxRows && r < 30; r++) {
        final row = sheet.row(r);
        var mCol = -1;
        var nCol = -1;
        for (var c = 0; c < row.length; c++) {
          final v = searchKey(cellString1(row[c]) ?? '');
          if (v.isEmpty) continue;
          if (mCol == -1 && v.contains('matricule')) mCol = c;
          if (nCol == -1 && (v.contains('nom'))) nCol = c;
        }
        if (mCol >= 0 && nCol >= 0) {
          sheetName = name;
          headerRow = r;
          matriculeCol = mCol;
          nameCol = nCol;
          break;
        }
      }
      if (sheetName != null) break;
    }

    if (sheetName == null) {
      throw const ImportFormatException(
          "En-têtes introuvables : le fichier doit contenir les colonnes "
          '« Matricule » et « Nom et Prénoms » (une ligne d’en-tête est '
          'reconnue automatiquement). Vérifiez le fichier source.');
    }

    // 2. Lire les lignes de données.
    final sheet = excel.tables[sheetName]!;
    final rows = <ImportRow>[];
    final seen = <String>{};
    for (var r = headerRow + 1; r < sheet.maxRows; r++) {
      final row = sheet.row(r);
      final matricule =
          matriculeFromCell(cellRaw(row, matriculeCol));
      final fullName = normalizeName(cellString(row, nameCol) ?? '');
      // Ligne entièrement vide : ignorée silencieusement.
      if (matricule.isEmpty && fullName.isEmpty) continue;
      final missingMatricule = matricule.isEmpty;
      final missingName = fullName.isEmpty;
      final duplicate = !missingMatricule && !seen.add(matricule);
      rows.add(ImportRow(
        rowNumber: r + 1, // numérotation Excel (1-based)
        matricule: matricule,
        fullName: fullName,
        hasMissingMatricule: missingMatricule,
        hasMissingName: missingName,
        isDuplicateInFile: duplicate,
      ));
    }

    if (rows.isEmpty) {
      throw ImportFormatException(
          'Aucune ligne de données détectée dans « $sheetName ». '
          '(fichier : ${fallbackName ?? 'inconnu'})');
    }

    return ImportReport(
      sheetName: sheetName,
      totalRows: rows.length,
      rows: rows,
      matriculeColumn: _columnName(matriculeCol),
      nameColumn: _columnName(nameCol),
    );
  }

  /// Complète le rapport avec l'état de la liste existante en base.
  static ImportReport attachExisting(
    ImportReport report,
    Map<String, String> existingByMatricule, // matricule -> nom actuel
  ) {
    final enriched = report.rows.map((r) {
      if (r.hasError || r.isDuplicateInFile) return r;
      final existing = existingByMatricule[r.matricule];
      if (existing == null) return r;
      return ImportRow(
        rowNumber: r.rowNumber,
        matricule: r.matricule,
        fullName: r.fullName,
        hasMissingMatricule: r.hasMissingMatricule,
        hasMissingName: r.hasMissingName,
        isDuplicateInFile: r.isDuplicateInFile,
        isNewInSession: false,
        existingName: existing,
      );
    }).toList();
    return ImportReport(
      sheetName: report.sheetName,
      totalRows: report.totalRows,
      rows: enriched,
      matriculeColumn: report.matriculeColumn,
      nameColumn: report.nameColumn,
    );
  }

  static dynamic cellRaw(List<Data?> row, int col) {
    if (col < 0 || col >= row.length) return null;
    return cellValue(row[col]);
  }

  static String? cellString(List<Data?> row, int col) {
    final v = cellRaw(row, col);
    if (v == null) return null;
    if (v is String) return v;
    return v.toString();
  }

  static String? cellString1(Data? cell) {
    final v = cellValue(cell);
    if (v == null) return null;
    if (v is String) return v;
    return v.toString();
  }

  /// Extrait la valeur d'une cellule Excel (excel 4.x : CellValue).
  static dynamic cellValue(Data? data) {
    if (data == null) return null;
    final v = data.value;
    if (v == null) return null;
    if (v is TextCellValue) return v.value;
    if (v is IntCellValue) return v.value;
    if (v is DoubleCellValue) return v.value;
    return v.toString();
  }

  /// Nom de colonne Excel (0 -> « A »).
  static String _columnName(int index) {
    var n = index + 1;
    var name = '';
    while (n > 0) {
      final rem = (n - 1) % 26;
      name = String.fromCharCode(65 + rem) + name;
      n = (n - 1) ~/ 26;
    }
    return name;
  }
}

/// Erreur d'import explicite, destinée à être affichée à l'utilisateur.
class ImportFormatException implements Exception {
  const ImportFormatException(this.message);
  final String message;
  @override
  String toString() => message;
}
