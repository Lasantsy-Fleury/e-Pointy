import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../core/utils.dart';
import '../data/app_database.dart';
import '../data/audit_dao.dart';
import '../data/conflict_dao.dart';
import '../data/plan_dao.dart';
import '../data/pointage_dao.dart';
import '../data/session_dao.dart';
import '../data/student_dao.dart';
import '../models/conflict.dart';
import '../models/day_template.dart';
import '../models/distribution.dart';
import '../models/enums.dart';
import '../models/import_report.dart';
import '../models/item_type.dart';
import '../models/pointage.dart';
import '../models/scan_result.dart';
import '../models/student.dart';
import '../models/travel_session.dart';
import '../models/trip_day.dart';
import '../services/excel_import_service.dart';
import '../services/scan_service.dart';
import '../services/stats_service.dart';
import 'app_settings.dart';

/// Filtre d'affichage de la liste des étudiants.
enum StudentsFilter { tous, servis, restants, inactifs }

/// Mode d'application d'un import Excel.
enum ImportMode {
  fusionner('Fusionner (ajouter et mettre à jour)'),
  ajouterNouveaux('Ajouter uniquement les nouveaux'),
  remplacer('Remplacer la liste (protégé)');

  const ImportMode(this.label);
  final String label;
}

/// Résultat de l'application d'un import.
class ImportApplyResult {
  ImportApplyResult({
    required this.added,
    required this.updated,
    required this.renamed,
    required this.deactivated,
    required this.deleted,
    required this.ignored,
    this.nameWarnings = const [],
  });

  final int added;
  final int updated;
  final int renamed;
  final int deactivated;
  final int deleted;
  final int ignored;

  /// Matricules connus dont le nom proposé diffère (avertissements).
  final List<String> nameWarnings;

  String get summary =>
      'Ajoutés : $added — mis à jour : $updated — désactivés : $deactivated — '
      'supprimés : $deleted — ignorés : $ignored';
}

/// État central de la session ouverte : configuration, étudiants, pointages,
/// sélection courante et compteurs. Toutes les données proviennent de la base
/// locale : aucune opération ne dépend d'Internet.
class SessionController extends ChangeNotifier {
  SessionController({required AppSettings settings, AppDatabase? db})
      : _settings = settings, // ignore: prefer_initializing_formals
        _db = db ?? AppDatabase.instance {
    _sessions = SessionDao(_db);
    _students = StudentDao(_db);
    _plan = PlanDao(_db);
    _pointages = PointageDao(_db);
    _conflicts = ConflictDao(_db);
    _audit = AuditDao(_db);
  }

  final AppSettings _settings;
  final AppDatabase _db;
  late final SessionDao _sessions;
  late final StudentDao _students;
  late final PlanDao _plan;
  late final PointageDao _pointages;
  late final ConflictDao _conflicts;
  late final AuditDao _audit;

  String? sessionId;
  TravelSession? session;
  List<TripDay> days = [];
  List<Distribution> distributions = [];
  List<ItemType> itemTypes = [];
  List<Student> students = [];
  List<DayTemplate> templates = [];

  String? selectedDayId;
  String? activeDistributionId;
  String searchQuery = '';
  StudentsFilter filter = StudentsFilter.tous;

  Set<String> servedForActive = {};
  DistributionStats? activeStats;
  SessionStats? sessionStats;
  int pendingOut = 0;

  bool loading = true;

  // ------------------------------------------------------------- accès

  ScanService get scanService => ScanService(_db);
  AuditDao get auditDao => _audit;
  PlanDao get planDao => _plan;
  StudentDao get studentDao => _students;
  PointageDao get pointageDao => _pointages;
  ConflictDao get conflictDao => _conflicts;
  SessionDao get sessionDao => _sessions;

  StatsService get statsService =>
      StatsService(_db, deviceId: _settings.deviceId);

  TripDay? get selectedDay {
    if (selectedDayId == null) return days.isEmpty ? null : days.first;
    return days.where((d) => d.id == selectedDayId).firstOrNull ??
        (days.isEmpty ? null : days.first);
  }

  Distribution? get activeDistribution {
    if (activeDistributionId == null) return null;
    return distributions
        .where((d) => d.id == activeDistributionId)
        .firstOrNull;
  }

  List<Distribution> get distributionsOfSelectedDay {
    final day = selectedDay;
    if (day == null) return [];
    return distributions.where((d) => d.dayId == day.id).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
  }

  List<Distribution> get openDistributions =>
      distributionsOfSelectedDay.where((d) => d.acceptsPointage).toList();

  bool get sessionClosed =>
      session?.status == SessionStatus.cloturee ||
      session?.status == SessionStatus.archivee;

  /// Étudiants filtrés pour l'affichage.
  List<Student> get filteredStudents {
    Iterable<Student> list = students;
    final active = activeDistribution;
    switch (filter) {
      case StudentsFilter.tous:
        list = list.where((s) => s.active);
        break;
      case StudentsFilter.servis:
        if (active == null) return [];
        list = list.where(
            (s) => s.active && servedForActive.contains(s.id));
        break;
      case StudentsFilter.restants:
        if (active == null) return [];
        list = list.where(
            (s) => s.active && !servedForActive.contains(s.id));
        break;
      case StudentsFilter.inactifs:
        list = list.where((s) => !s.active);
        break;
    }
    final q = searchKey(searchQuery);
    if (q.isNotEmpty) {
      list = list.where((s) =>
          s.matricule.toLowerCase().contains(q) ||
          searchKey(s.fullName).contains(q));
    }
    return list.toList();
  }

  List<Student> get remainingStudents {
    final active = activeDistribution;
    if (active == null) return [];
    return students
        .where((s) => s.active && !servedForActive.contains(s.id))
        .toList();
  }

  List<Student> get servedStudents {
    final active = activeDistribution;
    if (active == null) return [];
    return students
        .where((s) => s.active && servedForActive.contains(s.id))
        .toList();
  }

  // ------------------------------------------------------------- cycle

  Future<void> open(String id) async {
    sessionId = id;
    loading = true;
    notifyListeners();
    await _settings.setLastSession(id);
    await refresh(selectDefaults: true);
  }

  /// Recharge toutes les données de la session.
  Future<void> refresh({bool selectDefaults = false}) async {
    final id = sessionId;
    if (id == null) return;
    session = await _sessions.getById(id);
    days = await _plan.days(id);
    distributions = await _plan.distributions(id);
    itemTypes = await _plan.itemTypes(id);
    students = await _students.getBySession(id);
    templates = await _loadTemplates(id);

    if (selectDefaults || selectedDayId == null ||
        !days.any((d) => d.id == selectedDayId)) {
      selectedDayId = _defaultDayId();
    }
    if (selectDefaults ||
        activeDistributionId == null ||
        !distributions.any((d) => d.id == activeDistributionId)) {
      activeDistributionId = _defaultDistributionId();
    }
    await refreshCounters();
    loading = false;
    notifyListeners();
  }

  /// Recharge uniquement les compteurs (appelé après chaque scan).
  Future<void> refreshCounters() async {
    final id = sessionId;
    final dist = activeDistribution;
    if (id == null) return;
    if (dist != null) {
      servedForActive = await _pointages.servedStudentIds(dist.id);
      activeStats = await statsService.forDistribution(id, dist);
    } else {
      servedForActive = {};
      activeStats = null;
    }
    sessionStats = await statsService.sessionStats(id);
    pendingOut = await _pointages.pendingOutCount(id, _settings.deviceId);
    notifyListeners();
  }

  String? _defaultDayId() {
    if (days.isEmpty) return null;
    final today = DateTime.now();
    for (final day in days) {
      final d = day.dayDate;
      if (d != null &&
          d.year == today.year &&
          d.month == today.month &&
          d.day == today.day) {
        return day.id;
      }
    }
    return days.first.id;
  }

  String? _defaultDistributionId() {
    final ofDay = distributionsOfSelectedDay;
    if (ofDay.isEmpty) return null;
    // Priorité : distribution ouverte, sinon la première.
    final open = ofDay.where((d) => d.acceptsPointage);
    return open.isNotEmpty ? open.first.id : ofDay.first.id;
  }

  // ------------------------------------------------------- sélections

  void selectDay(String id) {
    selectedDayId = id;
    // Réinitialise la distribution active sur la nouvelle journée.
    final ofDay = distributionsOfSelectedDay;
    activeDistributionId = ofDay
            .where((d) => d.acceptsPointage)
            .firstOrNull
            ?.id ??
        (ofDay.isEmpty ? null : ofDay.first.id);
    refreshCounters();
  }

  void selectDistribution(String id) {
    activeDistributionId = id;
    refreshCounters();
  }

  void setSearch(String value) {
    searchQuery = value;
    notifyListeners();
  }

  void setFilter(StudentsFilter value) {
    filter = value;
    notifyListeners();
  }

  // ------------------------------------------------------- pointages

  Future<ScanResult> scanRaw(String raw) async {
    final id = sessionId;
    if (id == null) {
      return ScanResult.failure(
          ScanOutcome.erreurEnregistrement, 'Aucune session ouverte');
    }
    final result = await scanService.processRaw(
      raw: raw,
      activeSessionId: id,
      activeDistribution: activeDistribution,
      ctx: _settings.operatorContext,
    );
    await refreshCounters();
    return result;
  }

  Future<ScanResult> manualPointage(Student student, Distribution distribution) async {
    final result = await scanService.recordForStudent(
      student: student,
      distribution: distribution,
      mode: ScanMode.manuel,
      ctx: _settings.operatorContext,
    );
    await refreshCounters();
    return result;
  }

  Future<void> cancelPointage(Pointage pointage, String reason) async {
    await scanService.cancelPointage(
      pointage: pointage,
      reason: reason,
      ctx: _settings.operatorContext,
    );
    await refreshCounters();
  }

  /// Résout un conflit de fusion.
  ///
  /// [keepImported] = true  → on conserve le pointage reçu d'un autre
  /// appareil : le pointage local validé est d'abord annulé (motif
  /// obligatoire) afin de libérer l'index unique partiel, puis le pointage
  /// importé passe en « validé ».
  /// [keepImported] = false → on garde le pointage local ; le pointage reçu
  /// reste en « doublon potentiel » (traçabilité intacte).
  Future<void> resolveConflict(
    Conflict conflict,
    bool keepImported, {
    String? note,
  }) async {
    final actor = _settings.operatorName.isEmpty
        ? _settings.deviceName
        : _settings.operatorName;
    if (keepImported) {
      final local = await _pointages.getById(conflict.keptPointageId);
      if (local != null && local.isValid) {
        // Ordre important : annuler d'abord pour libérer l'index unique,
        // puis valider l'importé.
        await _pointages.cancel(
          id: local.id,
          sessionId: local.sessionId,
          reason: 'Remplacé par le pointage reçu d’un autre appareil '
              '(résolution de conflit).',
          actor: actor,
        );
      }
      final imported =
          await _pointages.getById(conflict.conflictingPointageId);
      if (imported != null) {
        await _pointages.update(imported.copyWith(
          status: PointageStatus.valide,
          updatedAt: nowUtcIso(),
        ));
      }
    }
    await _conflicts.resolve(
      conflict.id,
      keepImported ? 'garde_importe' : 'garde_existant',
      actor,
      note: note,
    );
    await refreshCounters();
  }

  // --------------------------------------------------- transfert

  /// Marque les pointages locaux de la session comme transmis après un envoi
  /// réussi (ils ne seront plus comptés « en attente d'envoi »).
  Future<void> markSyncedOut(String targetSessionId) async {
    await _pointages.markSyncedOut(targetSessionId);
    await refreshCounters();
  }

  // --------------------------------------------------- sessions CRUD

  Future<TravelSession> createSession({
    required String name,
    String? school,
    DateTime? startDate,
    DateTime? endDate,
    String? responsible,
    String? notes,
    bool withDefaultPlan = true,
  }) async {
    final now = nowUtcIso();
    final session = TravelSession(
      id: newId(),
      token: newToken(8),
      name: name.trim(),
      school: school?.trim().isEmpty ?? true ? null : school!.trim(),
      startDate: startDate,
      endDate: endDate,
      responsible: responsible?.trim().isEmpty ?? true ? null : responsible!.trim(),
      notes: notes?.trim().isEmpty ?? true ? null : notes!.trim(),
      status: SessionStatus.preparation,
      createdAt: now,
      updatedAt: now,
    );
    await _sessions.insert(session);
    await _audit.log(
      sessionId: session.id,
      actor: _settings.operatorName.isEmpty ? 'Responsable' : _settings.operatorName,
      action: 'creation_session',
      details: 'Session « ${session.name} » créée.',
    );
    if (withDefaultPlan) {
      await createDefaultPlan(session.id);
    }
    return session;
  }

  Future<List<TravelSession>> allSessions() => _sessions.getAll();

  Future<void> updateSession(TravelSession updated) async {
    await _sessions.update(updated.copyWith(updatedAt: nowUtcIso()));
    if (updated.id == sessionId) await refresh();
  }

  Future<void> setSessionStatus(SessionStatus status) async {
    final id = sessionId;
    if (id == null) return;
    await _sessions.setStatus(id, status, nowUtcIso());
    await _audit.log(
      sessionId: id,
      actor: _settings.operatorName.isEmpty ? 'Responsable' : _settings.operatorName,
      action: 'statut_session',
      details: 'Statut de la session : ${status.label}.',
    );
    await refresh();
  }

  Future<void> deleteSessionCascade(String id) async {
    await _sessions.deleteAllData(id);
    if (id == sessionId) {
      sessionId = null;
      session = null;
      notifyListeners();
    }
  }

  // --------------------------------------------------- plan par défaut

  /// Crée un plan de départ : 3 repas + 2 distributions d'eau sur « Jour 1 ».
  /// Rien n'est codé en dur : ces éléments sont de simples enregistrements
  /// modifiables et supprimables par le responsable.
  Future<void> createDefaultPlan(String targetSessionId) async {
    final now = nowUtcIso();
    final items = <ItemType>[
      ItemType(
        id: newId(),
        sessionId: targetSessionId,
        name: 'Petit-déjeuner',
        category: 'repas',
        createdAt: now,
        updatedAt: now,
      ),
      ItemType(
        id: newId(),
        sessionId: targetSessionId,
        name: 'Déjeuner',
        category: 'repas',
        createdAt: now,
        updatedAt: now,
      ),
      ItemType(
        id: newId(),
        sessionId: targetSessionId,
        name: 'Dîner',
        category: 'repas',
        createdAt: now,
        updatedAt: now,
      ),
      ItemType(
        id: newId(),
        sessionId: targetSessionId,
        name: 'Eau',
        category: 'eau',
        unit: 'bouteille',
        createdAt: now,
        updatedAt: now,
      ),
    ];
    for (final item in items) {
      await _plan.insertItemType(item);
    }

    final day = TripDay(
      id: newId(),
      sessionId: targetSessionId,
      label: AppConstants.defaultFirstDayLabel,
      position: 0,
      createdAt: now,
      updatedAt: now,
    );
    await _plan.insertDay(day);

    final definitions = <List<String>>[
      ['Petit-déjeuner', '06:30', '08:00'],
      ['Eau du matin', '08:00', '10:00'],
      ['Déjeuner', '11:30', '13:30'],
      ['Eau de l’après-midi', '15:00', '17:00'],
      ['Dîner', '18:30', '20:30'],
    ];
    var position = 0;
    for (final def in definitions) {
      final item = items
          .where((i) => i.name == def[0])
          .firstOrNull ??
          items.firstWhere((i) => i.category == 'eau');
      await _plan.insertDistribution(Distribution(
        id: newId(),
        sessionId: targetSessionId,
        dayId: day.id,
        itemTypeId: item.id,
        name: def[0],
        startTime: def[1],
        endTime: def[2],
        position: position++,
        createdAt: now,
        updatedAt: now,
      ));
    }

    // Modèle réutilisable correspondant.
    final template = DayTemplate(
      id: newId(),
      sessionId: targetSessionId,
      name: 'Journée type : 3 repas + 2 eaux',
      items: [
        for (final def in definitions)
          {
            'name': def[0],
            'startTime': def[1],
            'endTime': def[2],
            'category': def[0].startsWith('Eau') ? 'eau' : 'repas',
            'allowMultiple': false,
            'maxPassages': 1,
          },
      ],
      createdAt: now,
      updatedAt: now,
    );
    await _plan.insertDayTemplate(template);
  }

  // --------------------------------------------------- journées / distrib

  Future<TripDay> addDay(String label, {DateTime? date}) async {
    final id = sessionId!;
    final now = nowUtcIso();
    final day = TripDay(
      id: newId(),
      sessionId: id,
      label: label.trim().isEmpty ? 'Jour ${days.length + 1}' : label.trim(),
      dayDate: date,
      position: days.length,
      createdAt: now,
      updatedAt: now,
    );
    await _plan.insertDay(day);
    await refresh();
    return day;
  }

  Future<void> updateDay(TripDay day) async {
    await _plan.updateDay(day.copyWith(updatedAt: nowUtcIso()));
    await refresh();
  }

  Future<void> deleteDay(TripDay day) async {
    // Les distributions et pointages liés sont supprimés en cascade douce.
    final dists = distributions.where((d) => d.dayId == day.id).toList();
    for (final d in dists) {
      await deleteDistribution(d);
    }
    await _plan.deleteDay(day.id);
    await refresh();
  }

  Future<Distribution> addDistribution({
    required String dayId,
    required String name,
    String? itemTypeId,
    String? startTime,
    String? endTime,
    bool allowMultiple = false,
    int maxPassages = 1,
    bool trackQuantity = false,
    String? instructions,
  }) async {
    final id = sessionId!;
    final now = nowUtcIso();
    final position = distributions.where((d) => d.dayId == dayId).length;
    final dist = Distribution(
      id: newId(),
      sessionId: id,
      dayId: dayId,
      itemTypeId: itemTypeId,
      name: name.trim(),
      startTime: startTime,
      endTime: endTime,
      allowMultiple: allowMultiple,
      maxPassages: allowMultiple ? maxPassages : 1,
      trackQuantity: trackQuantity,
      instructions: instructions?.trim().isEmpty ?? true ? null : instructions,
      position: position,
      createdAt: now,
      updatedAt: now,
    );
    await _plan.insertDistribution(dist);
    await refresh();
    return dist;
  }

  Future<void> updateDistribution(Distribution dist) async {
    await _plan.updateDistribution(dist.copyWith(updatedAt: nowUtcIso()));
    await refreshCounters();
    notifyListeners();
  }

  Future<void> deleteDistribution(Distribution dist) async {
    await _plan.deleteDistribution(dist.id);
    await refresh();
  }

  Future<void> setDistributionStatus(
      Distribution dist, DistributionStatus status) async {
    await _plan.updateDistribution(
        dist.copyWith(status: status, updatedAt: nowUtcIso()));
    await _audit.log(
      sessionId: dist.sessionId,
      actor: _settings.operatorName.isEmpty ? 'Pointeur' : _settings.operatorName,
      action: 'statut_distribution',
      details: '« ${dist.name} » : ${status.label}.',
    );
    await refresh();
  }

  /// Applique un modèle de journée à une journée (crée les distributions).
  Future<int> applyTemplate(DayTemplate template, String dayId) async {
    var count = 0;
    for (final item in template.items) {
      await addDistribution(
        dayId: dayId,
        name: (item['name'] ?? 'Distribution').toString(),
        startTime: item['startTime'] as String?,
        endTime: item['endTime'] as String?,
        allowMultiple: item['allowMultiple'] == true,
        maxPassages: (item['maxPassages'] as num?)?.toInt() ?? 1,
        instructions: item['instructions'] as String?,
      );
      count++;
    }
    await refresh();
    return count;
  }

  /// Duplique les distributions d'une journée vers une autre.
  Future<int> duplicateDayDistributions(String fromDayId, String toDayId) async {
    final source =
        distributions.where((d) => d.dayId == fromDayId).toList()
          ..sort((a, b) => a.position.compareTo(b.position));
    for (final d in source) {
      await addDistribution(
        dayId: toDayId,
        name: d.name,
        itemTypeId: d.itemTypeId,
        startTime: d.startTime,
        endTime: d.endTime,
        allowMultiple: d.allowMultiple,
        maxPassages: d.maxPassages,
        trackQuantity: d.trackQuantity,
        instructions: d.instructions,
      );
    }
    await refresh();
    return source.length;
  }

  Future<void> saveDayAsTemplate(String dayId, String name) async {
    final id = sessionId!;
    final ofDay = distributions.where((d) => d.dayId == dayId).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    final now = nowUtcIso();
    await _plan.insertDayTemplate(DayTemplate(
      id: newId(),
      sessionId: id,
      name: name.trim().isEmpty ? 'Modèle' : name.trim(),
      items: [
        for (final d in ofDay)
          {
            'name': d.name,
            'startTime': d.startTime,
            'endTime': d.endTime,
            'allowMultiple': d.allowMultiple,
            'maxPassages': d.maxPassages,
            'instructions': d.instructions,
          },
      ],
      createdAt: now,
      updatedAt: now,
    ));
    templates = await _loadTemplates(id);
    notifyListeners();
  }

  Future<void> deleteTemplate(DayTemplate template) async {
    await _plan.deleteDayTemplate(template.id);
    templates = await _loadTemplates(sessionId!);
    notifyListeners();
  }

  Future<List<DayTemplate>> _loadTemplates(String sessionId) async {
    try {
      return await _plan.dayTemplates(sessionId);
    } catch (_) {
      return [];
    }
  }

  // --------------------------------------------------- étudiants

  Future<void> addStudent(String matricule, String fullName) async {
    final id = sessionId!;
    final now = nowUtcIso();
    await _students.insert(Student(
      id: newId(),
      sessionId: id,
      matricule: matricule.trim(),
      fullName: normalizeName(fullName),
      qrToken: newToken(10),
      createdAt: now,
      updatedAt: now,
    ));
    await auditDao.log(
      sessionId: id,
      actor: _settings.operatorName.isEmpty ? 'Responsable' : _settings.operatorName,
      action: 'ajout_etudiant',
      details: 'Étudiant ajouté manuellement : $matricule — $fullName',
    );
    await refresh();
  }

  Future<void> updateStudent(Student student) async {
    await _students.update(student.copyWith(updatedAt: nowUtcIso()));
    await auditDao.log(
      sessionId: student.sessionId,
      actor: _settings.operatorName.isEmpty ? 'Responsable' : _settings.operatorName,
      action: 'modification_etudiant',
      details: 'Fiche modifiée : ${student.matricule} — ${student.fullName}',
    );
    await refresh();
  }

  Future<void> setStudentActive(Student student, bool active) async {
    await _students.update(
        student.copyWith(active: active, updatedAt: nowUtcIso()));
    await auditDao.log(
      sessionId: student.sessionId,
      actor: _settings.operatorName.isEmpty ? 'Responsable' : _settings.operatorName,
      action: active ? 'reactivation_etudiant' : 'desactivation_etudiant',
      details: '${student.matricule} — ${student.fullName}',
    );
    await refresh();
  }

  Future<List<Pointage>> pointagesOfStudent(String studentId) =>
      _pointages.forStudent(studentId);

  // --------------------------------------------------- import Excel

  /// Analyse un fichier `.xlsx` et le croise avec la liste existante.
  Future<ImportReport> analyzeImportFile(String filePath) async {
    final report = await ExcelImportService.parseFile(filePath);
    final existing = {
      for (final s in students) s.matricule: s.fullName,
    };
    return ExcelImportService.attachExisting(report, existing);
  }

  /// Analyse des octets (tests et partage direct).
  Future<ImportReport> analyzeImportBytes(List<int> bytes) async {
    final report = ExcelImportService.parseBytes(bytes);
    final existing = {
      for (final s in students) s.matricule: s.fullName,
    };
    return ExcelImportService.attachExisting(report, existing);
  }

  /// Applique un import selon le mode choisi. Un nouvel import n'efface
  /// jamais les pointages existants ; le remplacement est protégé et
  /// désactive (plutôt que supprime) les étudiants déjà pointés.
  Future<ImportApplyResult> applyImport(
      ImportReport report, ImportMode mode) async {
    final id = sessionId!;
    final now = nowUtcIso();
    final existingByMatricule = {
      for (final s in students) s.matricule: s,
    };
    final activeIds = await _pointages.studentIdsWithPointages(id);
    final inFile = <String>{};
    final warnings = <String>[];
    var added = 0;
    var updated = 0;
    var renamed = 0;
    var deactivated = 0;
    var deleted = 0;
    var ignored = 0;

    for (final row in report.rows) {
      if (!row.willBeImported) {
        ignored++;
        continue;
      }
      inFile.add(row.matricule);
      final existing = existingByMatricule[row.matricule];
      if (existing == null) {
        await _students.insert(Student(
          id: newId(),
          sessionId: id,
          matricule: row.matricule,
          fullName: row.fullName,
          qrToken: newToken(10),
          createdAt: now,
          updatedAt: now,
        ));
        added++;
        continue;
      }
      if (mode == ImportMode.ajouterNouveaux) {
        ignored++;
        continue;
      }
      if (existing.fullName != row.fullName) {
        warnings.add(
            '${row.matricule} : « ${existing.fullName} » → « ${row.fullName} »');
        renamed++;
      }
      await _students.update(existing.copyWith(
        fullName: row.fullName,
        active: true,
        updatedAt: now,
      ));
      updated++;
    }

    if (mode == ImportMode.remplacer) {
      for (final student in students) {
        if (inFile.contains(student.matricule)) continue;
        if (activeIds.contains(student.id)) {
          // Conserve la trace et l'historique : désactivation.
          if (student.active) {
            await _students.update(
                student.copyWith(active: false, updatedAt: now));
            deactivated++;
          }
        } else {
          await _students.delete(student.id);
          deleted++;
        }
      }
    }

    await _audit.log(
      sessionId: id,
      actor: _settings.operatorName.isEmpty
          ? 'Responsable'
          : _settings.operatorName,
      action: 'import_excel',
      details:
          'Import « ${report.sheetName} » — ${mode.label} — ajoutés : $added, '
          'mis à jour : $updated, désactivés : $deactivated, supprimés : $deleted, '
          'ignorés : $ignored.',
    );
    await refresh();
    return ImportApplyResult(
      added: added,
      updated: updated,
      renamed: renamed,
      deactivated: deactivated,
      deleted: deleted,
      ignored: ignored,
      nameWarnings: warnings,
    );
  }
}
