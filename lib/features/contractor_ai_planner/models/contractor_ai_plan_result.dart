// ─── Contractor AI Plan Result ──────────────────────────────────────────────
// Local, immutable DTOs for the structured result returned by the
// `analyzeContractorJobPlan` callable Cloud Function. Intentionally
// independent from ProfessionalAiAnalysisResult (Professional AI) and
// AiServiceAnalysisResult (Customer AI) — never shared, never modified
// together, never persisted anywhere.
//
// [ContractorAiRankedWorkerFact] carries only a worker id plus deterministic
// facts computed entirely server-side — never a worker name, phone, email,
// wage, image, or any other identity/contact field. The real worker name is
// mapped locally in Flutter from `contractorWorkersStreamProvider` (see
// contractor_ai_planner_screen.dart); Gemini never receives and never
// returns worker names.

/// The only three planning intents the backend accepts, in wire format.
const Set<String> kContractorAiValidPlanningIntents = {
  'prepare_job',
  'plan_crew',
  'request_customer_info',
};

const Set<String> _kContractorAiValidWorkerStatuses = {
  'available',
  'busy',
  'offline',
};

const Set<String> _kContractorAiValidWorkingHoursSignals = {
  'within',
  'unknown',
  'outside',
};

/// One deterministic ranked-worker fact exactly as the backend returns it —
/// a worker id plus facts computed entirely server-side, never a name,
/// phone, email, wage, or any other identity/contact field.
class ContractorAiRankedWorkerFact {
  final String workerId;
  final bool alreadyAssigned;
  final bool specialtyMatch;
  final String status; // 'available' | 'busy' | 'offline'
  final int activeWorkload;
  final bool hasScheduleProximityWarning;
  final String generalWorkingHoursSignal; // 'within' | 'unknown' | 'outside'

  const ContractorAiRankedWorkerFact({
    required this.workerId,
    required this.alreadyAssigned,
    required this.specialtyMatch,
    required this.status,
    required this.activeWorkload,
    required this.hasScheduleProximityWarning,
    required this.generalWorkingHoursSignal,
  });

  static const Set<String> _requiredKeys = {
    'workerId',
    'alreadyAssigned',
    'specialtyMatch',
    'status',
    'activeWorkload',
    'hasScheduleProximityWarning',
    'generalWorkingHoursSignal',
  };

  /// Parses one raw ranked-worker-fact entry. Rejects missing/extra keys,
  /// any wrong type, an unknown `status`/`generalWorkingHoursSignal`
  /// enum value, and a negative or non-integer `activeWorkload`.
  factory ContractorAiRankedWorkerFact.fromMap(dynamic raw) {
    if (raw is! Map) {
      throw const FormatException('Ranked worker fact is not a map.');
    }
    final map = Map<String, dynamic>.from(raw);

    final keys = map.keys.toSet();
    if (keys.length != _requiredKeys.length ||
        !keys.containsAll(_requiredKeys)) {
      throw const FormatException(
          'Ranked worker fact does not contain exactly the expected fields.');
    }

    final rawWorkerId = map['workerId'];
    if (rawWorkerId is! String) {
      throw const FormatException('workerId must be a string.');
    }
    final workerId = rawWorkerId.trim();
    if (workerId.isEmpty) {
      throw const FormatException('workerId must be a non-empty string.');
    }

    final rawAlreadyAssigned = map['alreadyAssigned'];
    if (rawAlreadyAssigned is! bool) {
      throw const FormatException('alreadyAssigned must be a boolean.');
    }

    final rawSpecialtyMatch = map['specialtyMatch'];
    if (rawSpecialtyMatch is! bool) {
      throw const FormatException('specialtyMatch must be a boolean.');
    }

    final rawStatus = map['status'];
    if (rawStatus is! String) {
      throw const FormatException('status must be a string.');
    }
    final status = rawStatus.trim();
    if (!_kContractorAiValidWorkerStatuses.contains(status)) {
      throw const FormatException('status must be a known worker status.');
    }

    final rawActiveWorkload = map['activeWorkload'];
    if (rawActiveWorkload is! num ||
        rawActiveWorkload != rawActiveWorkload.toInt()) {
      throw const FormatException('activeWorkload must be an integer.');
    }
    final activeWorkload = rawActiveWorkload.toInt();
    if (activeWorkload < 0) {
      throw const FormatException('activeWorkload must not be negative.');
    }

    final rawHasProximityWarning = map['hasScheduleProximityWarning'];
    if (rawHasProximityWarning is! bool) {
      throw const FormatException(
          'hasScheduleProximityWarning must be a boolean.');
    }

    final rawWorkingHoursSignal = map['generalWorkingHoursSignal'];
    if (rawWorkingHoursSignal is! String) {
      throw const FormatException(
          'generalWorkingHoursSignal must be a string.');
    }
    final workingHoursSignal = rawWorkingHoursSignal.trim();
    if (!_kContractorAiValidWorkingHoursSignals.contains(workingHoursSignal)) {
      throw const FormatException(
          'generalWorkingHoursSignal must be a known signal.');
    }

    return ContractorAiRankedWorkerFact(
      workerId: workerId,
      alreadyAssigned: rawAlreadyAssigned,
      specialtyMatch: rawSpecialtyMatch,
      status: status,
      activeWorkload: activeWorkload,
      hasScheduleProximityWarning: rawHasProximityWarning,
      generalWorkingHoursSignal: workingHoursSignal,
    );
  }
}

/// The exact, complete validated result of one `analyzeContractorJobPlan`
/// call. Never parses or exposes `sanitizedOrder`/`workerAggregate` — the
/// backend's final response contract does not include them either.
class ContractorAiPlanResult {
  final int schemaVersion;
  final String orderId;
  final String planningIntent;
  final String summary;
  final int recommendedWorkerCount;
  final String crewGuidance;
  final List<String> questions;
  final List<String> toolsAndMaterials;
  final List<String> suggestedSteps;
  final List<String> coordinationNotes;
  final List<String> safetyWarnings;
  final String customerMessage;
  final List<ContractorAiRankedWorkerFact> rankedWorkerFacts;

  const ContractorAiPlanResult({
    required this.schemaVersion,
    required this.orderId,
    required this.planningIntent,
    required this.summary,
    required this.recommendedWorkerCount,
    required this.crewGuidance,
    required this.questions,
    required this.toolsAndMaterials,
    required this.suggestedSteps,
    required this.coordinationNotes,
    required this.safetyWarnings,
    required this.customerMessage,
    required this.rankedWorkerFacts,
  });

  static const Set<String> _requiredKeys = {
    'schemaVersion',
    'orderId',
    'planningIntent',
    'summary',
    'recommendedWorkerCount',
    'crewGuidance',
    'questions',
    'toolsAndMaterials',
    'suggestedSteps',
    'coordinationNotes',
    'safetyWarnings',
    'customerMessage',
    'rankedWorkerFacts',
  };

  /// Parses the raw callable response into a validated result. Every
  /// failure path — wrong shape, wrong types, missing/extra field,
  /// unsupported schemaVersion, out-of-range recommendedWorkerCount, or a
  /// malformed ranked-worker-fact entry — surfaces as a single
  /// [FormatException] so callers only ever handle one "malformed
  /// response" case instead of a grab-bag of runtime type errors. Never
  /// includes the raw response content in the thrown message.
  factory ContractorAiPlanResult.fromMap(dynamic raw) {
    try {
      return _parse(raw);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Malformed Contractor AI plan response.');
    }
  }

  static ContractorAiPlanResult _parse(dynamic raw) {
    if (raw is! Map) {
      throw const FormatException('AI response is not a map.');
    }
    // Callable responses can come back as Map<Object?, Object?> on native
    // platforms — normalize to string keys before reading any field.
    final map = Map<String, dynamic>.from(raw);

    // Must contain exactly the expected keys — no missing field, no extra
    // field (e.g. an accidentally-echoed sanitizedOrder/workerAggregate).
    final keys = map.keys.toSet();
    if (keys.length != _requiredKeys.length ||
        !keys.containsAll(_requiredKeys)) {
      throw const FormatException(
          'Response does not contain exactly the expected fields.');
    }

    final rawSchemaVersion = map['schemaVersion'];
    if (rawSchemaVersion is! num || rawSchemaVersion != 1) {
      throw const FormatException('Unsupported schemaVersion.');
    }

    String requireNonEmptyString(String key) {
      final v = map[key];
      if (v is! String) {
        throw FormatException('$key must be a string.');
      }
      final trimmed = v.trim();
      if (trimmed.isEmpty) {
        throw FormatException('$key must be a non-empty string.');
      }
      return trimmed;
    }

    List<String> requireStringList(String key) {
      final v = map[key];
      if (v is! List) {
        throw FormatException('$key must be a list.');
      }
      final result = <String>[];
      for (final e in v) {
        if (e is! String) {
          throw FormatException('$key must contain only strings.');
        }
        result.add(e.trim());
      }
      return List.unmodifiable(result);
    }

    final planningIntent = requireNonEmptyString('planningIntent');
    if (!kContractorAiValidPlanningIntents.contains(planningIntent)) {
      throw const FormatException('planningIntent must be a known value.');
    }

    final rawRecommendedWorkerCount = map['recommendedWorkerCount'];
    if (rawRecommendedWorkerCount is! num ||
        rawRecommendedWorkerCount != rawRecommendedWorkerCount.toInt()) {
      throw const FormatException('recommendedWorkerCount must be an integer.');
    }
    final recommendedWorkerCount = rawRecommendedWorkerCount.toInt();
    if (recommendedWorkerCount < 0 || recommendedWorkerCount > 5) {
      throw const FormatException(
          'recommendedWorkerCount must be between 0 and 5.');
    }

    final suggestedSteps = requireStringList('suggestedSteps');
    if (suggestedSteps.isEmpty) {
      throw const FormatException('suggestedSteps must not be empty.');
    }

    final rawRankedWorkerFacts = map['rankedWorkerFacts'];
    if (rawRankedWorkerFacts is! List) {
      throw const FormatException('rankedWorkerFacts must be a list.');
    }
    final rankedWorkerFacts = <ContractorAiRankedWorkerFact>[];
    for (final e in rawRankedWorkerFacts) {
      rankedWorkerFacts.add(ContractorAiRankedWorkerFact.fromMap(e));
    }

    return ContractorAiPlanResult(
      schemaVersion: rawSchemaVersion.toInt(),
      orderId: requireNonEmptyString('orderId'),
      planningIntent: planningIntent,
      summary: requireNonEmptyString('summary'),
      recommendedWorkerCount: recommendedWorkerCount,
      crewGuidance: requireNonEmptyString('crewGuidance'),
      questions: requireStringList('questions'),
      toolsAndMaterials: requireStringList('toolsAndMaterials'),
      suggestedSteps: suggestedSteps,
      coordinationNotes: requireStringList('coordinationNotes'),
      safetyWarnings: requireStringList('safetyWarnings'),
      customerMessage: requireNonEmptyString('customerMessage'),
      rankedWorkerFacts: List.unmodifiable(rankedWorkerFacts),
    );
  }
}
