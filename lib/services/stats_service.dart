import '../data/app_database.dart';
import '../data/conflict_dao.dart';
import '../data/pointage_dao.dart';
import '../data/plan_dao.dart';
import '../data/student_dao.dart';
import '../models/distribution.dart';
import '../models/enums.dart';
import '../models/trip_day.dart';

/// Compteurs d'une distribution.
class DistributionStats {
  const DistributionStats({
    required this.distributionId,
    required this.totalStudents,
    required this.served,
    required this.duplicates,
    required this.manual,
    required this.quantityTotal,
    required this.pendingOut,
  });

  final String distributionId;
  final int totalStudents;
  final int served;
  final int duplicates;
  final int manual;
  final int quantityTotal;
  final int pendingOut;

  int get remaining => (totalStudents - served).clamp(0, totalStudents);

  double get rate => totalStudents == 0 ? 0 : served / totalStudents;

  int get ratePercent => (rate * 100).round();

  /// Exemple : « 126 servis sur 150 — 84 % — 24 restants ».
  String get summary =>
      '$served servis sur $totalStudents — $ratePercent % — $remaining restants';
}

/// Statistiques d'ensemble d'une session.
class SessionStats {
  const SessionStats({
    required this.totalStudents,
    required this.activeStudents,
    required this.totalDistributions,
    required this.distributionsCloses,
    required this.totalPointages,
    required this.totalDuplicates,
    required this.totalManual,
    required this.pendingOut,
    required this.averageRate,
  });

  final int totalStudents;
  final int activeStudents;
  final int totalDistributions;
  final int distributionsCloses;
  final int totalPointages;
  final int totalDuplicates;
  final int totalManual;
  final int pendingOut;
  final double averageRate;

  int get averageRatePercent => (averageRate * 100).round();
}

/// Calculs toujours basés sur les pointages validés uniques.
class StatsService {
  StatsService(AppDatabase db, {this.deviceId = ''})
      : _students = StudentDao(db),
        _plan = PlanDao(db),
        _pointages = PointageDao(db),
        _conflicts = ConflictDao(db);

  final String deviceId;
  final StudentDao _students;
  final PlanDao _plan;
  final PointageDao _pointages;
  final ConflictDao _conflicts;

  Future<DistributionStats> forDistribution(
      String sessionId, Distribution distribution) async {
    final students = await _students.getBySession(sessionId,
        includeInactive: false);
    final served = await _pointages.servedStudentIds(distribution.id);
    final manual = await _pointages.manualValidCount(distribution.id);
    final duplicates =
        await _conflicts.countUnresolvedForDistribution(distribution.id);
    final all = await _pointages.forDistribution(distribution.id);
    final quantity = all
        .where((p) => p.isValid)
        .fold<int>(0, (sum, p) => sum + p.quantity);
    final pending = deviceId.isEmpty
        ? 0
        : await _pointages.pendingOutCount(sessionId, deviceId);
    return DistributionStats(
      distributionId: distribution.id,
      totalStudents: students.length,
      served: served.length,
      duplicates: duplicates,
      manual: manual,
      quantityTotal: quantity,
      pendingOut: pending,
    );
  }

  /// Récapitulatif d'une journée : une ligne par distribution.
  Future<List<MapEntry<Distribution, DistributionStats>>> dayRecap(
    String sessionId,
    TripDay day,
  ) async {
    final all = await _plan.distributions(sessionId);
    final ofDay =
        all.where((d) => d.dayId == day.id).toList()
          ..sort((a, b) => a.position.compareTo(b.position));
    final result = <MapEntry<Distribution, DistributionStats>>[];
    for (final d in ofDay) {
      result.add(MapEntry(d, await forDistribution(sessionId, d)));
    }
    return result;
  }

  Future<SessionStats> sessionStats(String sessionId) async {
    final students = await _students.getBySession(sessionId);
    final activeStudents = students.where((s) => s.active).length;
    final distributions = await _plan.distributions(sessionId);
    final pointages = await _pointages.forSession(sessionId);
    final valid = pointages.where((p) => p.isValid).toList();
    final duplicates = await _conflicts.countUnresolved(sessionId);
    final manual = valid.where((p) => p.mode == ScanMode.manuel).length;
    final pending = deviceId.isEmpty
        ? 0
        : await _pointages.pendingOutCount(sessionId, deviceId);

    var rateSum = 0.0;
    for (final d in distributions) {
      final stats = await forDistribution(sessionId, d);
      rateSum += stats.rate;
    }
    return SessionStats(
      totalStudents: students.length,
      activeStudents: activeStudents,
      totalDistributions: distributions.length,
      distributionsCloses: distributions
          .where((d) => d.status == DistributionStatus.cloturee)
          .length,
      totalPointages: valid.length,
      totalDuplicates: duplicates,
      totalManual: manual,
      pendingOut: pending,
      averageRate:
          distributions.isEmpty ? 0 : rateSum / distributions.length,
    );
  }
}
