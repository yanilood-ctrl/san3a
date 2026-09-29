// ─── Professional AI Analysis Result ────────────────────────────────────────
// Local, immutable DTO for the structured result returned by the
// `analyzeProfessionalJob` callable Cloud Function. Intentionally separate
// from AiServiceAnalysisResult (Customer AI) in the ai_service_assistant
// feature — never shared, never modified together, never persisted anywhere.
// Never parses or exposes raw order fields (title/description/category/
// selectedServices) — the backend's final response contract does not
// include them either.
class ProfessionalAiAnalysisResult {
  final int schemaVersion;
  final String orderId;
  final String summary;
  final List<String> questions;
  final List<String> toolsAndMaterials;
  final List<String> suggestedSteps;
  final List<String> safetyWarnings;
  final String customerMessage;

  const ProfessionalAiAnalysisResult({
    required this.schemaVersion,
    required this.orderId,
    required this.summary,
    required this.questions,
    required this.toolsAndMaterials,
    required this.suggestedSteps,
    required this.safetyWarnings,
    required this.customerMessage,
  });

  static const Set<String> _requiredKeys = {
    'schemaVersion',
    'orderId',
    'summary',
    'questions',
    'toolsAndMaterials',
    'suggestedSteps',
    'safetyWarnings',
    'customerMessage',
  };

  /// Parses the raw callable response into a validated result. Every failure
  /// path — wrong shape, wrong types, missing/extra field, unsupported
  /// schemaVersion — surfaces as a [FormatException] so callers only ever
  /// handle one "malformed response" case instead of a grab-bag of runtime
  /// type errors.
  factory ProfessionalAiAnalysisResult.fromMap(dynamic raw) {
    try {
      return _parse(raw);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
          'Malformed Professional AI analysis response.');
    }
  }

  static ProfessionalAiAnalysisResult _parse(dynamic raw) {
    if (raw is! Map) {
      throw const FormatException('AI response is not a map.');
    }
    // Callable responses can come back as Map<Object?, Object?> on native
    // platforms — normalize to string keys before reading any field.
    final map = Map<String, dynamic>.from(raw);

    // Must contain exactly the eight expected keys — no missing field, no
    // extra field (e.g. an accidentally-echoed raw order field).
    final keys = map.keys.toSet();
    if (keys.length != _requiredKeys.length || !keys.containsAll(_requiredKeys)) {
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

    return ProfessionalAiAnalysisResult(
      schemaVersion: rawSchemaVersion.toInt(),
      orderId: requireNonEmptyString('orderId'),
      summary: requireNonEmptyString('summary'),
      questions: requireStringList('questions'),
      toolsAndMaterials: requireStringList('toolsAndMaterials'),
      suggestedSteps: requireStringList('suggestedSteps'),
      safetyWarnings: requireStringList('safetyWarnings'),
      customerMessage: requireNonEmptyString('customerMessage'),
    );
  }
}
