// ─── Service Content Translation Result ─────────────────────────────────────
// Local, immutable DTO for the structured result returned by the
// `translateProviderContent` callable Cloud Function when called with
// `contentType: "service_content"` — a combined service name + description
// translation. Intentionally separate from TranslationResult (the
// single-field response shape used by provider_about / service_name /
// service_description / review_comment) and from
// shared/models/models.dart — never persisted anywhere, no Firestore
// serialization.

class ServiceContentTranslationResult {
  final int schemaVersion;
  final String translatedName;
  final String translatedDescription;
  final String detectedNameLanguage;
  final String detectedDescriptionLanguage;
  final String targetLanguage;
  final bool nameSameLanguage;
  final bool descriptionSameLanguage;

  const ServiceContentTranslationResult({
    required this.schemaVersion,
    required this.translatedName,
    required this.translatedDescription,
    required this.detectedNameLanguage,
    required this.detectedDescriptionLanguage,
    required this.targetLanguage,
    required this.nameSameLanguage,
    required this.descriptionSameLanguage,
  });

  static const Set<String> _validDetectedLanguages = {
    'ar',
    'he',
    'en',
    'other',
  };
  static const Set<String> _validTargetLanguages = {'ar', 'he', 'en'};

  /// Parses the raw callable response into a validated result. Every failure
  /// path — wrong shape, wrong types, unsupported enum value, an empty
  /// translatedName, a non-bool same-language flag — surfaces as a
  /// [FormatException] so callers only ever handle one "malformed response"
  /// case. Never substitutes a fake default for a missing/invalid field.
  /// [translatedDescription] is the only field allowed to be empty (an empty
  /// source description is valid — see `service_content`'s backend
  /// contract).
  factory ServiceContentTranslationResult.fromMap(dynamic raw) {
    try {
      return _parse(raw);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
          'Malformed service content translation response.');
    }
  }

  static ServiceContentTranslationResult _parse(dynamic raw) {
    if (raw is! Map) {
      throw const FormatException(
          'Service content translation response is not a map.');
    }
    // Callable responses can come back as Map<Object?, Object?> on native
    // platforms — normalize to string keys before reading any field.
    final map = Map<String, dynamic>.from(raw);

    final rawSchemaVersion = map['schemaVersion'];
    if (rawSchemaVersion is! num || rawSchemaVersion != 1) {
      throw const FormatException('Unsupported schemaVersion.');
    }

    final rawTranslatedName = map['translatedName'];
    if (rawTranslatedName is! String) {
      throw const FormatException('translatedName must be a string.');
    }
    final translatedName = rawTranslatedName.trim();
    if (translatedName.isEmpty) {
      throw const FormatException('translatedName must be non-empty.');
    }

    final rawTranslatedDescription = map['translatedDescription'];
    if (rawTranslatedDescription is! String) {
      throw const FormatException('translatedDescription must be a string.');
    }
    final translatedDescription = rawTranslatedDescription.trim();

    final rawDetectedNameLanguage = map['detectedNameLanguage'];
    if (rawDetectedNameLanguage is! String ||
        !_validDetectedLanguages.contains(rawDetectedNameLanguage)) {
      throw const FormatException('Unsupported detectedNameLanguage.');
    }

    final rawDetectedDescriptionLanguage = map['detectedDescriptionLanguage'];
    if (rawDetectedDescriptionLanguage is! String ||
        !_validDetectedLanguages.contains(rawDetectedDescriptionLanguage)) {
      throw const FormatException('Unsupported detectedDescriptionLanguage.');
    }

    final rawTargetLanguage = map['targetLanguage'];
    if (rawTargetLanguage is! String ||
        !_validTargetLanguages.contains(rawTargetLanguage)) {
      throw const FormatException('Unsupported targetLanguage.');
    }

    final rawNameSameLanguage = map['nameSameLanguage'];
    if (rawNameSameLanguage is! bool) {
      throw const FormatException('nameSameLanguage must be a bool.');
    }

    final rawDescriptionSameLanguage = map['descriptionSameLanguage'];
    if (rawDescriptionSameLanguage is! bool) {
      throw const FormatException('descriptionSameLanguage must be a bool.');
    }

    return ServiceContentTranslationResult(
      schemaVersion: rawSchemaVersion.toInt(),
      translatedName: translatedName,
      translatedDescription: translatedDescription,
      detectedNameLanguage: rawDetectedNameLanguage,
      detectedDescriptionLanguage: rawDetectedDescriptionLanguage,
      targetLanguage: rawTargetLanguage,
      nameSameLanguage: rawNameSameLanguage,
      descriptionSameLanguage: rawDescriptionSameLanguage,
    );
  }
}
