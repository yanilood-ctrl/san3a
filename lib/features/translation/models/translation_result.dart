// ─── Translation Result ─────────────────────────────────────────────────────
// Local, immutable DTO for the structured result returned by the
// `translateProviderContent` callable Cloud Function (Phase 2). Intentionally
// separate from AiServiceAnalysisResult and from shared/models/models.dart —
// never persisted anywhere, no Firestore serialization.

class TranslationResult {
  final int schemaVersion;
  final String translatedText;
  final String detectedSourceLanguage;
  final String targetLanguage;
  final bool sameLanguage;

  const TranslationResult({
    required this.schemaVersion,
    required this.translatedText,
    required this.detectedSourceLanguage,
    required this.targetLanguage,
    required this.sameLanguage,
  });

  static const Set<String> _validDetectedLanguages = {
    'ar',
    'he',
    'en',
    'other',
  };
  static const Set<String> _validTargetLanguages = {'ar', 'he', 'en'};

  /// Parses the raw callable response into a validated result. Every failure
  /// path — wrong shape, wrong types, unsupported enum value, missing or
  /// empty field — surfaces as a [FormatException] so callers only ever
  /// handle one "malformed response" case instead of a grab-bag of runtime
  /// type errors. Never substitutes a fake default for a missing/invalid
  /// field.
  factory TranslationResult.fromMap(dynamic raw) {
    try {
      return _parse(raw);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Malformed translation response.');
    }
  }

  static TranslationResult _parse(dynamic raw) {
    if (raw is! Map) {
      throw const FormatException('Translation response is not a map.');
    }
    // Callable responses can come back as Map<Object?, Object?> on native
    // platforms — normalize to string keys before reading any field.
    final map = Map<String, dynamic>.from(raw);

    final rawSchemaVersion = map['schemaVersion'];
    if (rawSchemaVersion is! num || rawSchemaVersion != 1) {
      throw const FormatException('Unsupported schemaVersion.');
    }

    final rawTranslatedText = map['translatedText'];
    if (rawTranslatedText is! String) {
      throw const FormatException('translatedText must be a string.');
    }
    final translatedText = rawTranslatedText.trim();
    if (translatedText.isEmpty) {
      throw const FormatException('translatedText must be non-empty.');
    }

    final rawDetectedSourceLanguage = map['detectedSourceLanguage'];
    if (rawDetectedSourceLanguage is! String ||
        !_validDetectedLanguages.contains(rawDetectedSourceLanguage)) {
      throw const FormatException('Unsupported detectedSourceLanguage.');
    }

    final rawTargetLanguage = map['targetLanguage'];
    if (rawTargetLanguage is! String ||
        !_validTargetLanguages.contains(rawTargetLanguage)) {
      throw const FormatException('Unsupported targetLanguage.');
    }

    final rawSameLanguage = map['sameLanguage'];
    if (rawSameLanguage is! bool) {
      throw const FormatException('sameLanguage must be a bool.');
    }

    return TranslationResult(
      schemaVersion: rawSchemaVersion.toInt(),
      translatedText: translatedText,
      detectedSourceLanguage: rawDetectedSourceLanguage,
      targetLanguage: rawTargetLanguage,
      sameLanguage: rawSameLanguage,
    );
  }
}
