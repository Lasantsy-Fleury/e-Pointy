import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/utils.dart';
import '../data/app_database.dart';
import '../data/session_dao.dart';
import '../data/student_dao.dart';
import '../models/student.dart';
import '../models/travel_session.dart';
import 'file_output.dart';
import 'qr_service.dart';

/// Génération des planches de QR codes prêtes à imprimer (PDF A4).
/// Le QR ne contient que deux tokens courts : aucune donnée personnelle.
class QrBadgesService {
  QrBadgesService(AppDatabase db)
      : _sessions = SessionDao(db),
        _students = StudentDao(db);

  final SessionDao _sessions;
  final StudentDao _students;

  /// Construit un PDF (3 colonnes par page) et retourne son chemin.
  Future<String> buildBadgesPdf({
    required String sessionId,
    bool activeOnly = true,
    bool includeNames = true,
  }) async {
    final session = await _sessions.getById(sessionId);
    if (session == null) throw StateError('Session introuvable');
    var students = await _students.getBySession(sessionId);
    if (activeOnly) {
      students = students.where((s) => s.active).toList();
    }
    if (students.isEmpty) {
      throw StateError('Aucun étudiant à imprimer pour cette session.');
    }

    final doc = pw.Document(
      title: 'QR codes — ${session.name}',
      author: 'e-Pointy',
    );
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(session.name,
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Text('QR codes étudiants — ${students.length} badge(s)',
                  style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
        ),
        build: (context) => [
          pw.Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final s in students) _badge(session, s, includeNames),
            ],
          ),
        ],
      ),
    );
    final bytes = await doc.save();
    final file = await FileOutput.writeBytes(
      'QR_${sanitizeFileName(session.name)}.pdf',
      bytes,
    );
    return file.path;
  }

  pw.Widget _badge(TravelSession session, Student student, bool includeNames) {
    return pw.Container(
      width: 160,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey500, width: 0.6),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (includeNames) ...[
            pw.Text(
              student.fullName,
              textAlign: pw.TextAlign.center,
              maxLines: 2,
              style: pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 2),
          ],
          pw.Text('Matricule : ${student.matricule}',
              style: const pw.TextStyle(fontSize: 8)),
          pw.SizedBox(height: 6),
          pw.BarcodeWidget(
            data: QrService.encodeForStudent(
              sessionToken: session.token,
              studentQrToken: student.qrToken,
            ),
            barcode: pw.Barcode.qrCode(),
            width: 96,
            height: 96,
          ),
          pw.SizedBox(height: 4),
          pw.Text(session.name,
              textAlign: pw.TextAlign.center,
              maxLines: 1,
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
          if (student.active == false)
            pw.Text('DÉSACTIVÉ',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.red)),
        ],
      ),
    );
  }
}
