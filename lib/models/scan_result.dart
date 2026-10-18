import 'enums.dart';
import 'distribution.dart';
import 'pointage.dart';
import 'student.dart';

/// Résultat complet d'un scan ou d'un pointage manuel.
class ScanResult {
  const ScanResult({
    required this.outcome,
    this.student,
    this.distribution,
    required this.message,
    this.detail,
    this.existingPointage,
    this.quantity,
  });

  final ScanOutcome outcome;
  final Student? student;
  final Distribution? distribution;

  /// Message principal affiché au pointeur.
  final String message;

  /// Détail complémentaire (heure, appareil, quantité…).
  final String? detail;
  final Pointage? existingPointage;
  final int? quantity;

  bool get isSuccess => outcome == ScanOutcome.enregistre;

  factory ScanResult.failure(
    ScanOutcome outcome,
    String message, {
    Student? student,
    Distribution? distribution,
    String? detail,
    Pointage? existingPointage,
  }) {
    return ScanResult(
      outcome: outcome,
      student: student,
      distribution: distribution,
      message: message,
      detail: detail,
      existingPointage: existingPointage,
    );
  }
}
