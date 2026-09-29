// ─── Professional AI Assistant — Riverpod controller ───────────────────────
// Feature-local providers (deliberately not added to app_providers.dart).
// Follows the same immutable-state + StateNotifier + copyWith pattern used
// by the Customer AI feature (ai_service_assistant_provider.dart), but is a
// wholly separate, independent controller — never shared, never modified
// together. The controller provider uses `.autoDispose` so the AI result and
// any in-flight request are torn down naturally once this feature's screen
// is popped, rather than lingering for the rest of the app session.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/professional_ai_assistant_repository.dart';
import '../../models/professional_ai_analysis_result.dart';

/// The three message intents the backend accepts, in its exact wire format.
/// Mirrors the backend's `messageIntent` enum exactly
/// (functions/src/index.ts: PROFESSIONAL_AI_VALID_MESSAGE_INTENTS).
enum ProfessionalAiMessageIntent {
  confirmAppointment,
  requestMoreInfo,
  requestPhotos,
}

extension ProfessionalAiMessageIntentWire on ProfessionalAiMessageIntent {
  String get wireValue {
    switch (this) {
      case ProfessionalAiMessageIntent.confirmAppointment:
        return 'confirm_appointment';
      case ProfessionalAiMessageIntent.requestMoreInfo:
        return 'request_more_info';
      case ProfessionalAiMessageIntent.requestPhotos:
        return 'request_photos';
    }
  }
}

/// A reasonable, visibly-selected default — the screen always shows this
/// option pre-selected in the intent selector, so a request is never sent
/// for an intent the Professional cannot see was chosen.
const ProfessionalAiMessageIntent kProfessionalAiDefaultMessageIntent =
    ProfessionalAiMessageIntent.requestMoreInfo;

/// The only three response languages the backend's `locale` field accepts.
/// Wholly independent of the app's own (currently English-only, see
/// AppLocalizations) UI localization — this controls only the language the
/// Professional AI generates its result in, never the app's UI text. An
/// isolated enum (rather than a free-form locale string in UI state) so an
/// unsupported value can never reach the request. Deliberately its own type
/// — never the Contractor AI feature's `ContractorAiResponseLanguage` —
/// so Professional AI stays a wholly independent feature.
enum ProfessionalAiResponseLanguage {
  english,
  arabic,
  hebrew,
}

extension ProfessionalAiResponseLanguageWire on ProfessionalAiResponseLanguage {
  /// The exact backend `locale` wire value ("en"/"ar"/"he").
  String get wireValue {
    switch (this) {
      case ProfessionalAiResponseLanguage.english:
        return 'en';
      case ProfessionalAiResponseLanguage.arabic:
        return 'ar';
      case ProfessionalAiResponseLanguage.hebrew:
        return 'he';
    }
  }

  /// Whether AI-generated content in this language reads right-to-left.
  /// Never affects the app's own UI labels, which stay English/LTR.
  bool get isRtl {
    switch (this) {
      case ProfessionalAiResponseLanguage.english:
        return false;
      case ProfessionalAiResponseLanguage.arabic:
      case ProfessionalAiResponseLanguage.hebrew:
        return true;
    }
  }
}

/// English is always selected by default when the screen opens — the
/// screen never derives this from the app's (forced-English) locale or
/// from the order text.
const ProfessionalAiResponseLanguage kProfessionalAiDefaultResponseLanguage =
    ProfessionalAiResponseLanguage.english;

/// The six fixed result-section headings shown above the AI-generated
/// content. Deliberately its own Professional-only type — never shared
/// with or imported from the Contractor AI feature's title types.
enum ProfessionalAiResultSection {
  summary,
  questions,
  toolsAndMaterials,
  suggestedSteps,
  safetyWarnings,
  customerMessage,
}

extension ProfessionalAiResultSectionTitle on ProfessionalAiResultSection {
  /// The exact, fixed title for this section in [language]. Purely a local
  /// lookup table keyed by the explicitly-selected
  /// [ProfessionalAiResponseLanguage] — never derived from the generated
  /// text itself, never an AI call, never automatic language detection.
  /// Independent of the app's own (English-only) UI localization.
  String titleFor(ProfessionalAiResponseLanguage language) {
    switch (this) {
      case ProfessionalAiResultSection.summary:
        switch (language) {
          case ProfessionalAiResponseLanguage.english:
            return 'Summary';
          case ProfessionalAiResponseLanguage.arabic:
            return 'الملخص';
          case ProfessionalAiResponseLanguage.hebrew:
            return 'סיכום';
        }
      case ProfessionalAiResultSection.questions:
        switch (language) {
          case ProfessionalAiResponseLanguage.english:
            return 'Questions to Ask';
          case ProfessionalAiResponseLanguage.arabic:
            return 'أسئلة للعميل';
          case ProfessionalAiResponseLanguage.hebrew:
            return 'שאלות ללקוח';
        }
      case ProfessionalAiResultSection.toolsAndMaterials:
        switch (language) {
          case ProfessionalAiResponseLanguage.english:
            return 'Tools and Materials';
          case ProfessionalAiResponseLanguage.arabic:
            return 'الأدوات والمواد';
          case ProfessionalAiResponseLanguage.hebrew:
            return 'כלים וחומרים';
        }
      case ProfessionalAiResultSection.suggestedSteps:
        switch (language) {
          case ProfessionalAiResponseLanguage.english:
            return 'Suggested Steps';
          case ProfessionalAiResponseLanguage.arabic:
            return 'الخطوات المقترحة';
          case ProfessionalAiResponseLanguage.hebrew:
            return 'שלבים מוצעים';
        }
      case ProfessionalAiResultSection.safetyWarnings:
        switch (language) {
          case ProfessionalAiResponseLanguage.english:
            return 'Safety Warnings';
          case ProfessionalAiResponseLanguage.arabic:
            return 'تحذيرات السلامة';
          case ProfessionalAiResponseLanguage.hebrew:
            return 'אזהרות בטיחות';
        }
      case ProfessionalAiResultSection.customerMessage:
        switch (language) {
          case ProfessionalAiResponseLanguage.english:
            return 'Customer Message';
          case ProfessionalAiResponseLanguage.arabic:
            return 'رسالة للعميل';
          case ProfessionalAiResponseLanguage.hebrew:
            return 'הודעה ללקוח';
        }
    }
  }
}

/// Pure request-generation guard extracted out of the controller so its
/// invalidate-on-change contract — "an old in-flight request's result must
/// never overwrite state once superseded" — can be unit tested directly,
/// without a repository, Firebase, or Riverpod. [start] begins a new
/// request and returns the token to compare later; [invalidate] marks the
/// current generation as superseded (called whenever a change, e.g. the
/// response language, must prevent an in-flight result from landing);
/// [isCurrent] tells the caller whether a previously-captured token is
/// still the latest one. A Professional-specific type — deliberately never
/// the Contractor AI feature's `ContractorAiRequestGenerationGuard`.
class ProfessionalAiRequestGenerationGuard {
  int _generation = 0;

  int start() => ++_generation;

  void invalidate() {
    _generation++;
  }

  bool isCurrent(int generation) => generation == _generation;
}

class ProfessionalAiAssistantState {
  // Null until the Professional explicitly taps an order card.
  final String? selectedOrderId;
  final ProfessionalAiMessageIntent selectedMessageIntent;
  // Defaults to English; never derived from the app locale or order text.
  final ProfessionalAiResponseLanguage selectedResponseLanguage;
  final bool isLoading;
  final ProfessionalAiAnalysisResult? result;
  final String? errorCode;
  // Optional, additionally-narrowing detail for a subset of [errorCode]
  // values (the backend's Professional-role and rate-limit reasons). Always
  // replaced together with [errorCode] — see copyWith below.
  final String? errorReason;

  const ProfessionalAiAssistantState({
    this.selectedOrderId,
    this.selectedMessageIntent = kProfessionalAiDefaultMessageIntent,
    this.selectedResponseLanguage = kProfessionalAiDefaultResponseLanguage,
    this.isLoading = false,
    this.result,
    this.errorCode,
    this.errorReason,
  });

  ProfessionalAiAssistantState copyWith({
    String? selectedOrderId,
    bool clearSelectedOrderId = false,
    ProfessionalAiMessageIntent? selectedMessageIntent,
    ProfessionalAiResponseLanguage? selectedResponseLanguage,
    bool? isLoading,
    ProfessionalAiAnalysisResult? result,
    bool clearResult = false,
    String? errorCode,
    String? errorReason,
    bool clearError = false,
  }) {
    // Whenever a fresh errorCode is supplied, errorReason always takes
    // exactly the value passed alongside it (even null, meaning "no
    // reason") — it must never fall back to a stale reason left over from a
    // previous, different error.
    final bool settingNewError = errorCode != null;
    return ProfessionalAiAssistantState(
      selectedOrderId: clearSelectedOrderId
          ? null
          : (selectedOrderId ?? this.selectedOrderId),
      selectedMessageIntent:
          selectedMessageIntent ?? this.selectedMessageIntent,
      selectedResponseLanguage:
          selectedResponseLanguage ?? this.selectedResponseLanguage,
      isLoading: isLoading ?? this.isLoading,
      result: clearResult ? null : (result ?? this.result),
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      errorReason: clearError
          ? null
          : (settingNewError ? errorReason : this.errorReason),
    );
  }

  /// Pure state-transition for selecting a new response language: null
  /// (no-op) while loading or when [language] is already selected, else
  /// the next state with the previously selected order and message intent
  /// preserved and the previous result/error cleared. Extracted as a pure
  /// method — independent of the repository/controller — so this exact
  /// contract is directly unit-testable without Firebase.
  ProfessionalAiAssistantState? withResponseLanguageSelected(
    ProfessionalAiResponseLanguage language,
  ) {
    if (isLoading) return null;
    if (selectedResponseLanguage == language) return null;
    return copyWith(
      selectedResponseLanguage: language,
      clearResult: true,
      clearError: true,
    );
  }
}

class ProfessionalAiAssistantController
    extends StateNotifier<ProfessionalAiAssistantState> {
  ProfessionalAiAssistantController(this._repository)
      : super(const ProfessionalAiAssistantState());

  final ProfessionalAiAssistantRepository _repository;

  // Guards against a stale in-flight request's result/error overwriting
  // current state. analyze() captures the token [_generationGuard.start]
  // returns *before* awaiting the repository; if [_generationGuard.
  // isCurrent] no longer matches once the await resolves, a newer request
  // (or a response-language change made mid-flight) has superseded it.
  final ProfessionalAiRequestGenerationGuard _generationGuard =
      ProfessionalAiRequestGenerationGuard();

  /// Selects [orderId] as the order to analyze. A no-op while a request is
  /// loading or if the same order is already selected. Always clears any
  /// previous result/error, so a stale analysis for a different order is
  /// never shown against the newly-selected one.
  void selectOrder(String orderId) {
    if (state.isLoading) return;
    if (state.selectedOrderId == orderId) return;
    state = state.copyWith(
      selectedOrderId: orderId,
      clearResult: true,
      clearError: true,
    );
  }

  /// Selects [intent] as the message intent to generate. A no-op while a
  /// request is loading or if the same intent is already selected. Always
  /// clears any previous result/error, matching [selectOrder].
  void selectMessageIntent(ProfessionalAiMessageIntent intent) {
    if (state.isLoading) return;
    if (state.selectedMessageIntent == intent) return;
    state = state.copyWith(
      selectedMessageIntent: intent,
      clearResult: true,
      clearError: true,
    );
  }

  /// Selects [language] as the response language the Professional AI should
  /// generate its result in. A no-op while a request is loading or if the
  /// same language is already selected. Always clears any previous
  /// result/error and always preserves the selected order and message
  /// intent, matching [selectOrder]/[selectMessageIntent]. Also invalidates
  /// the current request-generation guard so a result from a request
  /// already in flight before this change can never overwrite the state
  /// that follows it — in practice, [analyze] cannot be in flight here
  /// since it also sets `isLoading`, but this keeps the guard
  /// unconditionally correct rather than relying on that ordering.
  void selectResponseLanguage(ProfessionalAiResponseLanguage language) {
    final next = state.withResponseLanguageSelected(language);
    if (next == null) return;
    _generationGuard.invalidate();
    state = next;
  }

  /// Calls the repository exactly once for the currently-selected order,
  /// message intent, and response language. Never auto-retries, never
  /// derives the language from the order text or the app's own UI locale.
  /// A no-op if no order is selected or a request is already loading —
  /// this is the single source of truth preventing parallel/duplicate
  /// requests; the screen additionally disables its Analyze button as a
  /// second guard.
  Future<void> analyze() async {
    if (state.isLoading) return;
    final orderId = state.selectedOrderId;
    if (orderId == null || orderId.isEmpty) return;

    final int requestGeneration = _generationGuard.start();
    state = state.copyWith(
      isLoading: true,
      clearResult: true,
      clearError: true,
    );

    try {
      final result = await _repository.analyzeProfessionalJob(
        orderId: orderId,
        locale: state.selectedResponseLanguage.wireValue,
        messageIntent: state.selectedMessageIntent.wireValue,
      );
      if (!_generationGuard.isCurrent(requestGeneration)) return;
      state = state.copyWith(isLoading: false, result: result, clearError: true);
    } on ProfessionalAiAssistantException catch (e) {
      if (!_generationGuard.isCurrent(requestGeneration)) return;
      state = state.copyWith(
        isLoading: false,
        clearResult: true,
        errorCode: e.code,
        errorReason: e.reason,
      );
    } catch (_) {
      if (!_generationGuard.isCurrent(requestGeneration)) return;
      state = state.copyWith(
        isLoading: false,
        clearResult: true,
        errorCode: 'unknown',
      );
    }
  }
}

final professionalAiAssistantRepositoryProvider =
    Provider<ProfessionalAiAssistantRepository>(
  (ref) => ProfessionalAiAssistantRepository(),
);

/// `.autoDispose`: this feature's state (selected order/intent, in-flight
/// request, last result/error) is deliberately not kept alive once the
/// screen is popped — the next visit always starts fresh, and no AI result
/// is ever persisted anywhere.
final professionalAiAssistantControllerProvider = StateNotifierProvider
    .autoDispose<ProfessionalAiAssistantController, ProfessionalAiAssistantState>(
  (ref) => ProfessionalAiAssistantController(
    ref.watch(professionalAiAssistantRepositoryProvider),
  ),
);
