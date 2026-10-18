import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mipointy/core/utils.dart';
import 'package:mipointy/services/excel_import_service.dart';

void main() {
  group('ExcelImportService', () {
    List<int> buildValidXlsx() {
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];
      sheet.appendRow(
          [TextCellValue('Matricule'), TextCellValue('Nom et Prénoms')]);
      sheet.appendRow([TextCellValue('001'), TextCellValue('Rakoto Jean')]);
      sheet.appendRow([TextCellValue('002'), TextCellValue('Rasoanaivo Marie')]);
      sheet.appendRow([TextCellValue('003'), TextCellValue('Andry Razafy')]);
      return excel.encode()!;
    }

    List<int> buildWithIssues() {
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];
      sheet.appendRow(
          [TextCellValue('Matricule'), TextCellValue('Nom et Prénoms')]);
      sheet.appendRow([TextCellValue('001'), TextCellValue('Rakoto Jean')]);
      sheet.appendRow([TextCellValue('001'), TextCellValue('Doublon')]); // duplicate
      sheet.appendRow([TextCellValue(''), TextCellValue('Sans matricule')]); // missing matricule
      sheet.appendRow([TextCellValue('004'), TextCellValue('')]); // missing name
      sheet.appendRow([TextCellValue('005'), TextCellValue('Valide')]);
      return excel.encode()!;
    }

    test('parses valid file with header detection', () {
      final bytes = buildValidXlsx();
      final report = ExcelImportService.parseBytes(bytes);
      expect(report.totalRows, 3);
      expect(report.validRows.length, 3);
      expect(report.invalidRows, isEmpty);
    });

    test('detects duplicates and missing fields', () {
      final bytes = buildWithIssues();
      final report = ExcelImportService.parseBytes(bytes);
      expect(report.totalRows, 5);
      expect(report.duplicateRows.length, 1);
      expect(report.missingMatriculeRows.length, 1);
      expect(report.missingNameRows.length, 1);
      expect(report.validRows.length, 2);
      // invalidRows = lignes en erreur (matricule ou nom manquant).
      expect(report.invalidRows.length, 2);
      // errorRows = erreurs + doublons internes au fichier.
      expect(report.errorRows.length, 3);
    });

    test('throws when no headers', () {
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];
      sheet.appendRow([TextCellValue('A'), TextCellValue('B')]);
      sheet.appendRow([TextCellValue('1'), TextCellValue('2')]);
      final bytes = excel.encode()!;
      expect(() => ExcelImportService.parseBytes(bytes),
          throwsA(isA<ImportFormatException>()));
    });

    test('normalizeName and matriculeFromCell work together', () {
      expect(normalizeName('  Test   '), 'Test');
      expect(matriculeFromCell('0123'), '0123');
    });
  });
}
