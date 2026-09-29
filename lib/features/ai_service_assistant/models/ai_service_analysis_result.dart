// ─── AI Service Analysis Result ────────────────────────────────────────────
// Local, immutable DTO for the structured result returned by the
// `analyzeServiceProblem` callable Cloud Function (Phase 1 — mock only).
// This type is intentionally separate from UserModel/CategoryModel/OrderModel
// in shared/models/models.dart and is never persisted anywhere.

/// A structured follow-up question's answer shape (Phase 6B — mirrors the
/// backend's `AiFollowUpAnswerType`).
enum AiFollowUpAnswerType {
  singleChoice,
  freeText,
}

/// One structured follow-up question from `structuredFollowUpQuestions`.
/// `options` is always empty for [AiFollowUpAnswerType.freeText] and
/// 2–5 unique trimmed strings for [AiFollowUpAnswerType.singleChoice].
class AiFollowUpQuestion {
  final String question;
  final AiFollowUpAnswerType answerType;
  final List<String> options;

  const AiFollowUpQuestion({
    required this.question,
    required this.answerType,
    required this.options,
  });
}

class AiServiceAnalysisResult {
  final int schemaVersion;
  final bool isMock;
  final String detectedLanguage;
  final String suggestedCategoryId;
  final String suggestedCategoryName;
  final String suggestedCategoryNameKey;
  final String suggestedProviderRole;
  final String title;
  final String description;
  final String categoryReason;
  final String priority;
  final List<String> keywords;
  // Legacy field: kept for backward compatibility (Phase 6A backend
  // bridge). Not read by the UI in this phase — see
  // [structuredFollowUpQuestions] instead — but still strictly parsed and
  // cross-checked against it below.
  final List<String> followUpQuestions;
  final List<AiFollowUpQuestion> structuredFollowUpQuestions;

  const AiServiceAnalysisResult({
    required this.schemaVersion,
    required this.isMock,
    required this.detectedLanguage,
    required this.suggestedCategoryId,
    required this.suggestedCategoryName,
    required this.suggestedCategoryNameKey,
    required this.suggestedProviderRole,
    required this.title,
    required this.description,
    required this.categoryReason,
    required this.priority,
    required this.keywords,
    required this.followUpQuestions,
    required this.structuredFollowUpQuestions,
  });

  static const Set<String> _validProviderRoles = {'professional', 'contractor'};
  static const Set<String> _validPriorities = {'normal', 'urgent'};
  static const int _maxCategoryReasonLength = 300;

  // ─── Structured follow-up questions (Phase 6B) — mirrors the backend's
  // MAX_FOLLOW_UP_QUESTIONS / MAX_FOLLOW_UP_QUESTION_LENGTH /
  // MIN_FOLLOW_UP_OPTIONS / MAX_FOLLOW_UP_OPTIONS /
  // MAX_FOLLOW_UP_OPTION_LENGTH / MAX_FOLLOW_UP_QUESTIONS_PAYLOAD_LENGTH
  // exactly (functions/src/index.ts).
  static const Set<String> _validAnswerTypes = {'singleChoice', 'freeText'};
  static const int _maxFollowUpQuestions = 3;
  static const int _maxFollowUpQuestionLength = 300;
  static const int _minFollowUpOptions = 2;
  static const int _maxFollowUpOptions = 5;
  static const int _maxFollowUpOptionLength = 80;
  static const int _maxFollowUpQuestionsPayloadLength = 1800;

  /// Parses the raw callable response into a validated result. Every failure
  /// path — wrong shape, wrong types, unsupported enum value, missing field —
  /// surfaces as a [FormatException] so callers only ever handle one
  /// "malformed response" case instead of a grab-bag of runtime type errors.
  factory AiServiceAnalysisResult.fromMap(dynamic raw) {
    try {
      return _parse(raw);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Malformed AI service analysis response.');
    }
  }

  static AiServiceAnalysisResult _parse(dynamic raw) {
    if (raw is! Map) {
      throw const FormatException('AI response is not a map.');
    }
    // Callable responses can come back as Map<Object?, Object?> on native
    // platforms — normalize to string keys before reading any field.
    final map = Map<String, dynamic>.from(raw);

    final rawSchemaVersion = map['schemaVersion'];
    if (rawSchemaVersion is! num || rawSchemaVersion != 1) {
      throw const FormatException('Unsupported schemaVersion.');
    }

    final rawIsMock = map['isMock'];
    if (rawIsMock is! bool) {
      throw const FormatException('isMock must be a bool.');
    }

    String requireNonEmptyString(String key) {
      final v = map[key];
      if (v is! String || v.trim().isEmpty) {
        throw FormatException('$key must be a non-empty string.');
      }
      return v;
    }

    List<String> requireStringList(String key) {
      final v = map[key];
      if (v is! List) {
        throw FormatException('$key must be a list.');
      }
      for (final e in v) {
        if (e is! String) {
          throw FormatException('$key must contain only strings.');
        }
      }
      return v.cast<String>().toList();
    }

    String requireCategoryReason() {
      final v = map['categoryReason'];
      if (v is! String) {
        throw const FormatException('categoryReason must be a string.');
      }
      final trimmed = v.trim();
      if (trimmed.isEmpty) {
        throw const FormatException(
            'categoryReason must be a non-empty string.');
      }
      if (trimmed.length > _maxCategoryReasonLength) {
        throw const FormatException('categoryReason exceeds maximum length.');
      }
      return trimmed;
    }

    List<AiFollowUpQuestion> requireStructuredFollowUpQuestions() {
      final v = map['structuredFollowUpQuestions'];
      if (v is! List) {
        throw const FormatException(
            'structuredFollowUpQuestions must be a list.');
      }
      if (v.length > _maxFollowUpQuestions) {
        throw const FormatException('Too many structuredFollowUpQuestions.');
      }

      final questions = <AiFollowUpQuestion>[];
      var payloadLength = 0;

      for (final item in v) {
        if (item is! Map) {
          throw const FormatException(
              'Each structured follow-up question must be a map.');
        }
        final q = Map<String, dynamic>.from(item);
        final keys = q.keys.toList()..sort();
        if (keys.length != 3 ||
            keys[0] != 'answerType' ||
            keys[1] != 'options' ||
            keys[2] != 'question') {
          throw const FormatException(
              'Each structured follow-up question must contain exactly '
              'question, answerType, and options.');
        }

        final rawQuestion = q['question'];
        if (rawQuestion is! String) {
          throw const FormatException('question must be a string.');
        }
        final questionText = rawQuestion.trim();
        if (questionText.isEmpty) {
          throw const FormatException('question must be a non-empty string.');
        }
        if (questionText.length > _maxFollowUpQuestionLength) {
          throw const FormatException('question exceeds maximum length.');
        }

        final rawAnswerType = q['answerType'];
        if (rawAnswerType is! String ||
            !_validAnswerTypes.contains(rawAnswerType)) {
          throw const FormatException(
              'answerType must be singleChoice or freeText.');
        }
        final answerType = rawAnswerType == 'singleChoice'
            ? AiFollowUpAnswerType.singleChoice
            : AiFollowUpAnswerType.freeText;

        final rawOptions = q['options'];
        if (rawOptions is! List) {
          throw const FormatException('options must be a list.');
        }

        final options = <String>[];
        final seenNormalized = <String>{};
        for (final o in rawOptions) {
          if (o is! String) {
            throw const FormatException('Each option must be a string.');
          }
          final trimmedOption = o.trim();
          if (trimmedOption.isEmpty) {
            throw const FormatException('Each option must be non-empty.');
          }
          if (trimmedOption.length > _maxFollowUpOptionLength) {
            throw const FormatException('Option exceeds maximum length.');
          }
          final normalized = trimmedOption.toLowerCase();
          if (!seenNormalized.add(normalized)) {
            throw const FormatException('Duplicate options are not allowed.');
          }
          options.add(trimmedOption);
          payloadLength += trimmedOption.length;
        }

        if (answerType == AiFollowUpAnswerType.singleChoice) {
          if (options.length < _minFollowUpOptions ||
              options.length > _maxFollowUpOptions) {
            throw const FormatException(
                'singleChoice options must contain between 2 and 5 items.');
          }
        } else {
          if (options.isNotEmpty) {
            throw const FormatException('freeText options must be empty.');
          }
        }

        payloadLength += questionText.length;

        questions.add(AiFollowUpQuestion(
          question: questionText,
          answerType: answerType,
          options: List.unmodifiable(options),
        ));
      }

      if (payloadLength > _maxFollowUpQuestionsPayloadLength) {
        throw const FormatException(
            'structuredFollowUpQuestions combined length is too long.');
      }

      return List.unmodifiable(questions);
    }

    final suggestedProviderRole =
        requireNonEmptyString('suggestedProviderRole');
    if (!_validProviderRoles.contains(suggestedProviderRole)) {
      throw const FormatException('Unsupported suggestedProviderRole.');
    }

    final priority = requireNonEmptyString('priority');
    if (!_validPriorities.contains(priority)) {
      throw const FormatException('Unsupported priority.');
    }

    final legacyFollowUpQuestions = requireStringList('followUpQuestions');
    final structuredFollowUpQuestions = requireStructuredFollowUpQuestions();

    // Bridge consistency check (Phase 6A backend): the deployed backend
    // always generates the legacy array from the structured array
    // (`analysis.followUpQuestions.map((q) => q.question)`), so the two
    // must always agree in count and per-index question text. A mismatch
    // means a malformed/tampered response — never silently prefer one
    // field over the other.
    if (legacyFollowUpQuestions.length != structuredFollowUpQuestions.length) {
      throw const FormatException(
          'followUpQuestions and structuredFollowUpQuestions length '
          'mismatch.');
    }
    for (var i = 0; i < legacyFollowUpQuestions.length; i++) {
      if (legacyFollowUpQuestions[i] !=
          structuredFollowUpQuestions[i].question) {
        throw const FormatException(
            'followUpQuestions and structuredFollowUpQuestions content '
            'mismatch.');
      }
    }

    return AiServiceAnalysisResult(
      schemaVersion: rawSchemaVersion.toInt(),
      isMock: rawIsMock,
      detectedLanguage: requireNonEmptyString('detectedLanguage'),
      suggestedCategoryId: requireNonEmptyString('suggestedCategoryId'),
      suggestedCategoryName: requireNonEmptyString('suggestedCategoryName'),
      suggestedCategoryNameKey:
          requireNonEmptyString('suggestedCategoryNameKey'),
      suggestedProviderRole: suggestedProviderRole,
      title: requireNonEmptyString('title'),
      description: requireNonEmptyString('description'),
      categoryReason: requireCategoryReason(),
      priority: priority,
      keywords: requireStringList('keywords'),
      followUpQuestions: legacyFollowUpQuestions,
      structuredFollowUpQuestions: structuredFollowUpQuestions,
    );
  }
}
