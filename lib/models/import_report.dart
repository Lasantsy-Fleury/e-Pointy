/// Rapport de prévisualisation d'un import Excel.
class ImportReport {
  ImportReport({
    required this.sheetName,
    required this.totalRows,
    required this.rows,
    required this.matriculeColumn,
    required this.nameColumn,
  });

  final String sheetName;
  final int totalRows;
  final List<ImportRow> rows;
  final String matriculeColumn;
  final String nameColumn;

  List<ImportRow> get validRows => rows.where((r) => r.willBeImported).toList();
  List<ImportRow> get missingMatriculeRows =>
      rows.where((r) => r.hasMissingMatricule).toList();
  List<ImportRow> get missingNameRows =>
      rows.where((r) => r.hasMissingName).toList();
  List<ImportRow> get duplicateRows =>
      rows.where((r) => r.isDuplicateInFile).toList();
  List<ImportRow> get invalidRows => rows.where((r) => r.hasError).toList();
  List<ImportRow> get errorRows =>
      rows.where((r) => r.hasError || r.isDuplicateInFile).toList();

  int get validCount => rows.length - invalidRows.length;
  int get toAddCount =>
      rows.where((r) => r.willBeImported && r.isNewInSession).length;
  int get toUpdateCount =>
      rows.where((r) => r.willBeImported && !r.isNewInSession).length;
  int get renamedCount => rows
      .where((r) => r.willBeImported && !r.isNewInSession && r.hasNameChange)
      .length;
  int get ignoredCount =>
      rows.where((r) => !r.willBeImported).length;
}

/// Ligne détectée dans le fichier Excel, avec les erreurs associées.
class ImportRow {
  ImportRow({
    required this.rowNumber,
    required this.matricule,
    required this.fullName,
    this.hasMissingMatricule = false,
    this.hasMissingName = false,
    this.isDuplicateInFile = false,
    this.isNewInSession = true,
    this.existingName,
  });

  final int rowNumber;
  final String matricule;
  final String fullName;
  final bool hasMissingMatricule;
  final bool hasMissingName;

  /// Matricule déjà présent plus haut dans le fichier importé.
  final bool isDuplicateInFile;

  /// false = matricule déjà connu dans la session (mise à jour possible).
  final bool isNewInSession;
  final String? existingName;

  bool get hasError => hasMissingMatricule || hasMissingName;
  bool get hasNameChange =>
      !isNewInSession && existingName != null && existingName != fullName;
  bool get willBeImported => !hasError && !isDuplicateInFile;
}
