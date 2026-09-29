// ─── AI Service Assistant — Riverpod controller ────────────────────────────
// Feature-local providers (deliberately not added to app_providers.dart).
// Follows the same immutable-state + StateNotifier + copyWith pattern used
// elsewhere in the app (see e.g. HelpCenterNotifier).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/ai_service_assistant_repository.dart';
import '../../models/ai_service_analysis_result.dart';

const int kAiProblemTextMinLength = 10;
const int kAiProblemTextMaxLength = 1000;

/// Local-only validation error codes, kept in the same namespace as the
/// repository's error codes so the UI has a single place to map any code to
/// localized copy. Never sent to / received from the backend.
const String kAiErrorInputTooShort = 'input_too_short';
const String kAiErrorInputTooLong = 'input_too_long';

// Local-only defense-in-depth guard code: the screen never dispatches
// analyze()/refine() when the visible UserModel id and
// FirebaseAuth.instance.currentUser?.uid disagree (or either is null) — see
// AiServiceAssistantScreen's session-mismatch check. Never sent to /
// received from the backend.
const String kAiErrorSessionMismatch = 'session_mismatch';

// Mirrors the backend's followUpAnswers limits exactly (functions/src/index.ts:
// MAX_FOLLOW_UP_ANSWERS / MAX_FOLLOW_UP_ANSWER_QUESTION_LENGTH /
// MAX_FOLLOW_UP_ANSWER_LENGTH / MAX_FOLLOW_UP_ANSWERS_COMBINED_LENGTH) so a
// refinement request is only ever sent once it is guaranteed to pass
// server-side validation.
const int kAiMaxFollowUpAnswers = 3;
const int kAiFollowUpQuestionMaxLength = 300;
const int kAiFollowUpAnswerMaxLength = 300;
const int kAiFollowUpAnswersCombinedMaxLength = 1800;

// Maximum length for the Customer's optional additional notes. Notes are
// kept client-side only in this phase: never appended to problemText, never
// sent to the repository/backend, never sent to Gemini.
const int kAiAdditionalNotesMaxLength = 500;

/// Customer's provider-type preference for the future Matching Providers
/// section. "Both" is the default: Professional and Contractor accounts
/// remain equally eligible unless the Customer explicitly narrows this.
/// Never sent to the repository/backend/Gemini in this phase.
enum AiProviderPreference {
  both,
  professional,
  contractor,
}

/// Customer's location-matching preference. Deliberately named "city", not
/// "area"/"nearby" — the project only has a reliable city field, no GPS/maps.
/// Never sent to the repository/backend/Gemini in this phase.
enum AiLocationPreference {
  anyCity,
  sameCity,
}

/// Customer's budget preference. Does not filter providers in this phase —
/// state only. Never sent to the repository/backend/Gemini in this phase.
enum AiBudgetPreference {
  anyBudget,
  specificBudget,
}

/// Exact-order, exact-string equality for a submitted answer's `options`
/// against the current structured question's `options` — used by
/// [AiServiceAssistantController.refine] so a submitted option list can
/// never silently differ (reordered, truncated, or substituted) from the
/// options the Customer was actually shown.
bool _followUpOptionsMatch(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class AiServiceAssistantState {
  // The exact text the Customer has typed — preserved through errors (both
  // local-validation and backend failures) so a retry never loses input.
  final String problemText;
  final bool isLoading;
  final AiServiceAnalysisResult? result;
  final String? errorCode;
  // Optional, additionally-narrowing detail for a subset of [errorCode]
  // values (currently only the backend's `resource-exhausted` rate-limit
  // reasons). Always cleared together with [errorCode].
  final String? errorReason;

  // Refinement (Follow-up Refinement) state — independent of the fields
  // above so a refinement in flight or its failure never disturbs the
  // already-successful initial [result].
  final bool isRefining;
  final bool hasRefinementAttempted;
  final String? refinementErrorCode;
  // Mirrors [errorReason] for the refinement error code. Always cleared
  // together with [refinementErrorCode].
  final String? refinementErrorReason;

  // ─── Phase 1 — Customer preference form (UI/state only) ─────────────────
  // None of these five fields are ever sent to the repository/backend/
  // Gemini in this phase — they exist purely so the new preference form
  // survives loading, a successful analysis, a refinement, and any error,
  // exactly like [problemText] already does.
  final AiProviderPreference providerPreference;
  final AiLocationPreference locationPreference;
  final AiBudgetPreference budgetPreference;
  // Only meaningful when [budgetPreference] is specificBudget. Always
  // cleared back to null when switching to anyBudget.
  final double? specificBudgetAmount;
  final String additionalNotes;

  const AiServiceAssistantState({
    this.problemText = '',
    this.isLoading = false,
    this.result,
    this.errorCode,
    this.errorReason,
    this.isRefining = false,
    this.hasRefinementAttempted = false,
    this.refinementErrorCode,
    this.refinementErrorReason,
    this.providerPreference = AiProviderPreference.both,
    this.locationPreference = AiLocationPreference.anyCity,
    this.budgetPreference = AiBudgetPreference.anyBudget,
    this.specificBudgetAmount,
    this.additionalNotes = '',
  });

  AiServiceAssistantState copyWith({
    String? problemText,
    bool? isLoading,
    AiServiceAnalysisResult? result,
    bool clearResult = false,
    String? errorCode,
    String? errorReason,
    bool clearError = false,
    bool? isRefining,
    bool? hasRefinementAttempted,
    String? refinementErrorCode,
    String? refinementErrorReason,
    bool clearRefinementError = false,
    AiProviderPreference? providerPreference,
    AiLocationPreference? locationPreference,
    AiBudgetPreference? budgetPreference,
    double? specificBudgetAmount,
    bool clearSpecificBudgetAmount = false,
    String? additionalNotes,
  }) =>
      AiServiceAssistantState(
        problemText: problemText ?? this.problemText,
        isLoading: isLoading ?? this.isLoading,
        result: clearResult ? null : (result ?? this.result),
        errorCode: clearError ? null : (errorCode ?? this.errorCode),
        errorReason: clearError ? null : (errorReason ?? this.errorReason),
        isRefining: isRefining ?? this.isRefining,
        hasRefinementAttempted:
            hasRefinementAttempted ?? this.hasRefinementAttempted,
        refinementErrorCode: clearRefinementError
            ? null
            : (refinementErrorCode ?? this.refinementErrorCode),
        refinementErrorReason: clearRefinementError
            ? null
            : (refinementErrorReason ?? this.refinementErrorReason),
        providerPreference: providerPreference ?? this.providerPreference,
        locationPreference: locationPreference ?? this.locationPreference,
        budgetPreference: budgetPreference ?? this.budgetPreference,
        specificBudgetAmount: clearSpecificBudgetAmount
            ? null
            : (specificBudgetAmount ?? this.specificBudgetAmount),
        additionalNotes: additionalNotes ?? this.additionalNotes,
      );
}

class AiServiceAssistantController
    extends StateNotifier<AiServiceAssistantState> {
  AiServiceAssistantController(this._repository)
      : super(const AiServiceAssistantState());

  final AiServiceAssistantRepository _repository;

  // Bumped on every request started and whenever reset() is called.
  // analyze() captures the value it bumped to *before* awaiting the
  // repository; if that value no longer matches this field once the await
  // resolves, a newer request (or a reset()) has superseded it, so the
  // stale result/error must be dropped instead of overwriting current state.
  int _requestGeneration = 0;

  /// Trims the input, runs local length validation, then calls the
  /// repository exactly once. Never auto-retries. A second call made while
  /// [AiServiceAssistantState.isLoading] is true is a no-op — this is the
  /// single source of truth preventing parallel/duplicate requests; the
  /// screen additionally disables its Analyze button as a second guard.
  Future<void> analyze(String problemText) async {
    if (state.isLoading) return;

    final trimmed = problemText.trim();
    // Keep the raw (untrimmed) text exactly as typed so the field is never
    // silently rewritten out from under the Customer. A fresh initial
    // analysis always starts a new "screen visit" worth of refinement
    // eligibility, so every refinement field is reset here regardless of
    // whether this call ultimately succeeds, fails local validation, or
    // fails on the backend.
    state = state.copyWith(
      problemText: problemText,
      clearError: true,
      isRefining: false,
      hasRefinementAttempted: false,
      clearRefinementError: true,
    );

    if (trimmed.length < kAiProblemTextMinLength) {
      state =
          state.copyWith(clearResult: true, errorCode: kAiErrorInputTooShort);
      return;
    }
    if (trimmed.length > kAiProblemTextMaxLength) {
      state =
          state.copyWith(clearResult: true, errorCode: kAiErrorInputTooLong);
      return;
    }

    final int requestGeneration = ++_requestGeneration;
    state =
        state.copyWith(isLoading: true, clearResult: true, clearError: true);

    try {
      final result = await _repository.analyzeServiceProblem(trimmed);
      if (requestGeneration != _requestGeneration) return;
      state =
          state.copyWith(isLoading: false, result: result, clearError: true);
    } on AiServiceAssistantException catch (e) {
      if (requestGeneration != _requestGeneration) return;
      state = state.copyWith(
          isLoading: false,
          clearResult: true,
          errorCode: e.code,
          errorReason: e.reason);
    } catch (_) {
      if (requestGeneration != _requestGeneration) return;
      state = state.copyWith(
          isLoading: false, clearResult: true, errorCode: 'unknown');
    }
  }

  /// Local-only guard: called by the screen instead of [analyze] when the
  /// visible UserModel id and FirebaseAuth.instance.currentUser?.uid
  /// disagree (or either is null) — e.g. another browser tab is now signed
  /// into a different account and this tab hasn't finished re-synchronizing
  /// yet. Never calls the repository, never consumes AI quota, never
  /// creates/updates a rate-limit counter.
  void rejectAnalyzeSessionMismatch() {
    if (state.isLoading) return;
    state = state.copyWith(clearResult: true, clearError: true);
    state = state.copyWith(errorCode: kAiErrorSessionMismatch);
  }

  /// Sends exactly one refinement request combining the original problem
  /// ([AiServiceAssistantState.problemText]) with [answers] — one answer per
  /// currently-displayed *structured* follow-up question
  /// ([AiServiceAnalysisResult.structuredFollowUpQuestions]), matched
  /// strictly by index against question text, answerType, and options so
  /// the UI can never submit an invented question, an invented answer type,
  /// or a tampered option set. The legacy string array
  /// ([AiServiceAnalysisResult.followUpQuestions]) is never used here.
  ///
  /// At most one refinement is allowed per controller lifetime (one screen
  /// visit): [AiServiceAssistantState.hasRefinementAttempted] is set the
  /// instant a request is dispatched — whether it later succeeds or fails —
  /// and every subsequent call becomes a no-op. A fresh [analyze] call is
  /// the only thing that resets this, since it starts a new visit.
  ///
  /// Unlike [analyze], the current [AiServiceAssistantState.result] is never
  /// cleared here — a failed or in-flight refinement must never hide the
  /// last successful analysis.
  Future<void> refine(List<AiFollowUpAnswer> answers) async {
    if (state.isLoading) return;
    if (state.isRefining) return;
    if (state.hasRefinementAttempted) return;

    final currentResult = state.result;
    if (currentResult == null) return;

    final questions = currentResult.structuredFollowUpQuestions;
    if (questions.isEmpty) return;
    if (questions.length > kAiMaxFollowUpAnswers) return;
    if (answers.length != questions.length) return;

    final List<AiFollowUpAnswer> validated = [];
    int combinedLength = 0;
    for (var i = 0; i < questions.length; i++) {
      final question = questions[i];
      final answer = answers[i];

      // The submitted question/answerType/options must be exactly the
      // current follow-up question at this index — never a different or
      // invented question, a switched answer type, or a tampered option
      // set (same length, same order, exact String equality).
      if (answer.question != question.question) return;
      if (answer.answerType != question.answerType) return;
      if (!_followUpOptionsMatch(answer.options, question.options)) return;

      final trimmedQuestion = answer.question.trim();
      final trimmedAnswer = answer.answer.trim();
      if (trimmedQuestion.isEmpty || trimmedAnswer.isEmpty) return;
      if (trimmedQuestion.length > kAiFollowUpQuestionMaxLength) return;
      if (trimmedAnswer.length > kAiFollowUpAnswerMaxLength) return;

      if (question.answerType == AiFollowUpAnswerType.singleChoice) {
        // Defense in depth: the model's strict parser already guarantees
        // 2–5 options for a singleChoice question, but never trust that
        // invariant blindly here.
        if (question.options.length < 2 || question.options.length > 5) {
          return;
        }
        if (!question.options.contains(trimmedAnswer)) return;
      } else {
        if (question.options.isNotEmpty) return;
        if (answer.options.isNotEmpty) return;
      }

      combinedLength += trimmedQuestion.length + trimmedAnswer.length;
      validated.add(
        AiFollowUpAnswer(
          question: trimmedQuestion,
          answer: trimmedAnswer,
          answerType: question.answerType,
          options: question.options,
        ),
      );
    }
    if (combinedLength > kAiFollowUpAnswersCombinedMaxLength) return;

    final int requestGeneration = ++_requestGeneration;
    state = state.copyWith(
      isRefining: true,
      hasRefinementAttempted: true,
      clearRefinementError: true,
    );

    try {
      final refined = await _repository.analyzeServiceProblem(
        state.problemText.trim(),
        followUpAnswers: validated,
      );
      if (requestGeneration != _requestGeneration) return;
      state = state.copyWith(
        isRefining: false,
        result: refined,
        clearRefinementError: true,
      );
    } on AiServiceAssistantException catch (e) {
      if (requestGeneration != _requestGeneration) return;
      state = state.copyWith(
          isRefining: false,
          refinementErrorCode: e.code,
          refinementErrorReason: e.reason);
    } catch (_) {
      if (requestGeneration != _requestGeneration) return;
      state = state.copyWith(isRefining: false, refinementErrorCode: 'unknown');
    }
  }

  /// Local-only guard: called by the screen instead of [refine] when the
  /// visible UserModel id and FirebaseAuth.instance.currentUser?.uid
  /// disagree (or either is null). Mirrors [rejectAnalyzeSessionMismatch]
  /// for the refinement path — never calls the repository, never consumes
  /// AI quota. Deliberately does not set [AiServiceAssistantState.
  /// hasRefinementAttempted]: no request was ever dispatched, so a manual
  /// retry (never automatic) remains available once the session resyncs.
  void rejectRefineSessionMismatch() {
    if (state.isRefining || state.hasRefinementAttempted) return;
    state = state.copyWith(clearRefinementError: true);
    state = state.copyWith(refinementErrorCode: kAiErrorSessionMismatch);
  }

  // ─── Phase 1 — Customer preference form setters ──────────────────────────
  // Local UI/state only: never call the repository, never trigger a Gemini
  // request, and never invalidate an in-flight request generation — these
  // are plain state edits, same as typing in the problem text field.

  void setProviderPreference(AiProviderPreference preference) {
    state = state.copyWith(providerPreference: preference);
  }

  void setLocationPreference(AiLocationPreference preference) {
    state = state.copyWith(locationPreference: preference);
  }

  /// Switching to [AiBudgetPreference.anyBudget] always clears any
  /// previously-entered [AiServiceAssistantState.specificBudgetAmount], so a
  /// stale amount can never survive under the "price does not matter" choice.
  void setBudgetPreference(AiBudgetPreference preference) {
    state = state.copyWith(
      budgetPreference: preference,
      clearSpecificBudgetAmount: preference == AiBudgetPreference.anyBudget,
    );
  }

  /// Sets the specific budget amount, or clears it when [amount] is null.
  void setSpecificBudgetAmount(double? amount) {
    state = state.copyWith(
      specificBudgetAmount: amount,
      clearSpecificBudgetAmount: amount == null,
    );
  }

  void setAdditionalNotes(String notes) {
    state = state.copyWith(additionalNotes: notes);
  }

  void reset() {
    // Invalidate any request currently in flight so it can never restore a
    // stale result/error after this reset.
    _requestGeneration++;
    state = const AiServiceAssistantState();
  }
}

final aiServiceAssistantRepositoryProvider =
    Provider<AiServiceAssistantRepository>(
  (ref) => AiServiceAssistantRepository(),
);

final aiServiceAssistantControllerProvider = StateNotifierProvider<
    AiServiceAssistantController, AiServiceAssistantState>((ref) {
  return AiServiceAssistantController(
      ref.watch(aiServiceAssistantRepositoryProvider));
});
