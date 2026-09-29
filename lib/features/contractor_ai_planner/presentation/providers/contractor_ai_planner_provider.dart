// ─── Contractor AI Planner — Riverpod controller ────────────────────────────
// Feature-local providers (deliberately not added to app_providers.dart).
// Follows the same immutable-state + StateNotifier + copyWith pattern used
// by the Professional AI feature
// (professional_ai_assistant_provider.dart), but is a wholly separate,
// independent controller — never shared, never modified together. The
// controller provider uses `.autoDispose` so the AI result and any
// in-flight request are torn down naturally once this feature's screen is
// popped, rather than lingering for the rest of the app session — nothing
// is ever restored on the next visit, and nothing is ever written to
// Firestore.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/contractor_ai_planner_repository.dart';
import '../../models/contractor_ai_plan_result.dart';

/// The three planning intents the backend accepts, in its exact wire
/// format. Mirrors the backend's `planningIntent` enum exactly
/// (functions/src/index.ts: CONTRACTOR_AI_VALID_PLANNING_INTENTS).
enum ContractorAiPlanningIntent {
  prepareJob,
  planCrew,
  requestCustomerInfo,
}

extension ContractorAiPlanningIntentWire on ContractorAiPlanningIntent {
  String get wireValue {
    switch (this) {
      case ContractorAiPlanningIntent.prepareJob:
        return 'prepare_job';
      case ContractorAiPlanningIntent.planCrew:
        return 'plan_crew';
      case ContractorAiPlanningIntent.requestCustomerInfo:
        return 'request_customer_info';
    }
  }
}

/// A reasonable, visibly-selected default — the screen always shows this
/// option pre-selected in the intent selector, so a request is never sent
/// for an intent the Contractor cannot see was chosen.
const ContractorAiPlanningIntent kContractorAiDefaultPlanningIntent =
    ContractorAiPlanningIntent.planCrew;

/// The only three response languages the backend's `locale` field accepts.
/// Wholly independent of the app's own (currently English-only, see
/// AppLocalizations) UI localization — this controls only the language the
/// Contractor AI generates its result in, never the app's UI text. An
/// isolated enum (rather than a free-form locale string in UI state) so an
/// unsupported value can never reach the request.
enum ContractorAiResponseLanguage {
  english,
  arabic,
  hebrew,
}

extension ContractorAiResponseLanguageWire on ContractorAiResponseLanguage {
  /// The exact backend `locale` wire value ("en"/"ar"/"he").
  String get wireValue {
    switch (this) {
      case ContractorAiResponseLanguage.english:
        return 'en';
      case ContractorAiResponseLanguage.arabic:
        return 'ar';
      case ContractorAiResponseLanguage.hebrew:
        return 'he';
    }
  }

  /// Whether AI-generated content in this language reads right-to-left.
  /// Never affects the app's own UI labels, which stay English/LTR.
  bool get isRtl {
    switch (this) {
      case ContractorAiResponseLanguage.english:
        return false;
      case ContractorAiResponseLanguage.arabic:
      case ContractorAiResponseLanguage.hebrew:
        return true;
    }
  }
}

/// English is always selected by default when the screen opens — the
/// screen never derives this from the app's (forced-English) locale or
/// from the order text.
const ContractorAiResponseLanguage kContractorAiDefaultResponseLanguage =
    ContractorAiResponseLanguage.english;

/// The ten fixed result-section headings shown above the AI-generated
/// content. Deliberately its own Contractor-only type — never shared with
/// or imported from the Professional AI feature's title types.
enum ContractorAiResultSection {
  summary,
  recommendedCrewSize,
  crewGuidance,
  questions,
  toolsAndMaterials,
  suggestedSteps,
  coordinationNotes,
  safetyWarnings,
  customerMessage,
  recommendedWorkers,
}

extension ContractorAiResultSectionTitle on ContractorAiResultSection {
  /// The exact, fixed title for this section in [language]. Purely a local
  /// lookup table keyed by the explicitly-selected
  /// [ContractorAiResponseLanguage] — never derived from the generated
  /// text itself, never an AI call, never automatic language detection.
  /// Independent of the app's own (English-only) UI localization.
  String titleFor(ContractorAiResponseLanguage language) {
    switch (this) {
      case ContractorAiResultSection.summary:
        switch (language) {
          case ContractorAiResponseLanguage.english:
            return 'Summary';
          case ContractorAiResponseLanguage.arabic:
            return 'الملخص';
          case ContractorAiResponseLanguage.hebrew:
            return 'סיכום';
        }
      case ContractorAiResultSection.recommendedCrewSize:
        switch (language) {
          case ContractorAiResponseLanguage.english:
            return 'Recommended Crew Size';
          case ContractorAiResponseLanguage.arabic:
            return 'حجم الطاقم المقترح';
          case ContractorAiResponseLanguage.hebrew:
            return 'גודל צוות מומלץ';
        }
      case ContractorAiResultSection.crewGuidance:
        switch (language) {
          case ContractorAiResponseLanguage.english:
            return 'Crew Guidance';
          case ContractorAiResponseLanguage.arabic:
            return 'إرشادات الطاقم';
          case ContractorAiResponseLanguage.hebrew:
            return 'הנחיות לצוות';
        }
      case ContractorAiResultSection.questions:
        switch (language) {
          case ContractorAiResponseLanguage.english:
            return 'Questions to Ask';
          case ContractorAiResponseLanguage.arabic:
            return 'أسئلة للعميل';
          case ContractorAiResponseLanguage.hebrew:
            return 'שאלות ללקוח';
        }
      case ContractorAiResultSection.toolsAndMaterials:
        switch (language) {
          case ContractorAiResponseLanguage.english:
            return 'Tools and Materials';
          case ContractorAiResponseLanguage.arabic:
            return 'الأدوات والمواد';
          case ContractorAiResponseLanguage.hebrew:
            return 'כלים וחומרים';
        }
      case ContractorAiResultSection.suggestedSteps:
        switch (language) {
          case ContractorAiResponseLanguage.english:
            return 'Suggested Steps';
          case ContractorAiResponseLanguage.arabic:
            return 'الخطوات المقترحة';
          case ContractorAiResponseLanguage.hebrew:
            return 'שלבים מוצעים';
        }
      case ContractorAiResultSection.coordinationNotes:
        switch (language) {
          case ContractorAiResponseLanguage.english:
            return 'Coordination Notes';
          case ContractorAiResponseLanguage.arabic:
            return 'ملاحظات التنسيق';
          case ContractorAiResponseLanguage.hebrew:
            return 'הערות תיאום';
        }
      case ContractorAiResultSection.safetyWarnings:
        switch (language) {
          case ContractorAiResponseLanguage.english:
            return 'Safety Warnings';
          case ContractorAiResponseLanguage.arabic:
            return 'تحذيرات السلامة';
          case ContractorAiResponseLanguage.hebrew:
            return 'אזהרות בטיחות';
        }
      case ContractorAiResultSection.customerMessage:
        switch (language) {
          case ContractorAiResponseLanguage.english:
            return 'Customer Message';
          case ContractorAiResponseLanguage.arabic:
            return 'رسالة للعميل';
          case ContractorAiResponseLanguage.hebrew:
            return 'הודעה ללקוח';
        }
      case ContractorAiResultSection.recommendedWorkers:
        switch (language) {
          case ContractorAiResponseLanguage.english:
            return 'Recommended Workers';
          case ContractorAiResponseLanguage.arabic:
            return 'العمال المقترحون';
          case ContractorAiResponseLanguage.hebrew:
            return 'עובדים מומלצים';
        }
    }
  }
}

extension ContractorAiResponseLanguageCaptions on ContractorAiResponseLanguage {
  /// The fixed, local advisory caption shown under the recommended crew
  /// size — purely a lookup keyed by the explicitly-selected response
  /// language, never derived from the generated text.
  String get recommendedCrewSizeAdvisoryCaption {
    switch (this) {
      case ContractorAiResponseLanguage.english:
        return 'An advisory estimate only — you decide the final crew.';
      case ContractorAiResponseLanguage.arabic:
        return 'تقدير استشاري فقط — أنت من يقرر الطاقم النهائي.';
      case ContractorAiResponseLanguage.hebrew:
        return 'הערכה מייעצת בלבד — ההחלטה על הצוות הסופי היא שלך.';
    }
  }

  /// The fixed, local caption shown under Open Order & Assign Workers —
  /// purely a lookup keyed by the explicitly-selected response language,
  /// never derived from the generated text.
  String get manualAssignmentCaption {
    switch (this) {
      case ContractorAiResponseLanguage.english:
        return 'Worker assignment remains manual in Order Details.';
      case ContractorAiResponseLanguage.arabic:
        return 'يبقى تعيين العمال يدويًا من تفاصيل الطلب.';
      case ContractorAiResponseLanguage.hebrew:
        return 'הקצאת העובדים נשארת ידנית בפרטי ההזמנה.';
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
/// [isCurrent] reports whether a previously-captured token is still latest.
class ContractorAiRequestGenerationGuard {
  int _generation = 0;

  int start() => ++_generation;

  void invalidate() {
    _generation++;
  }

  bool isCurrent(int generation) => generation == _generation;
}

class ContractorAiPlannerState {
  // Null until the Contractor explicitly taps an order card.
  final String? selectedOrderId;
  final ContractorAiPlanningIntent selectedPlanningIntent;
  // Defaults to English; never derived from the app locale or order text.
  final ContractorAiResponseLanguage selectedResponseLanguage;
  final bool isLoading;
  final ContractorAiPlanResult? result;
  final String? errorCode;
  // Optional, additionally-narrowing detail for a subset of [errorCode]
  // values (the backend's Contractor-role, ownership, invariant, and
  // rate-limit reasons). Always replaced together with [errorCode] — see
  // copyWith below.
  final String? errorReason;

  const ContractorAiPlannerState({
    this.selectedOrderId,
    this.selectedPlanningIntent = kContractorAiDefaultPlanningIntent,
    this.selectedResponseLanguage = kContractorAiDefaultResponseLanguage,
    this.isLoading = false,
    this.result,
    this.errorCode,
    this.errorReason,
  });

  ContractorAiPlannerState copyWith({
    String? selectedOrderId,
    bool clearSelectedOrderId = false,
    ContractorAiPlanningIntent? selectedPlanningIntent,
    ContractorAiResponseLanguage? selectedResponseLanguage,
    bool? isLoading,
    ContractorAiPlanResult? result,
    bool clearResult = false,
    String? errorCode,
    String? errorReason,
    bool clearError = false,
  }) {
    // Whenever a fresh errorCode is supplied, errorReason always takes
    // exactly the value passed alongside it (even null, meaning "no
    // reason") — it must never fall back to a stale reason left over
    // from a previous, different error.
    final bool settingNewError = errorCode != null;
    return ContractorAiPlannerState(
      selectedOrderId: clearSelectedOrderId
          ? null
          : (selectedOrderId ?? this.selectedOrderId),
      selectedPlanningIntent:
          selectedPlanningIntent ?? this.selectedPlanningIntent,
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
  /// the next state with the previously selected order and planning intent
  /// preserved and the previous result/error cleared. Extracted as a pure
  /// method — independent of the repository/controller — so this exact
  /// contract is directly unit-testable without Firebase.
  ContractorAiPlannerState? withResponseLanguageSelected(
    ContractorAiResponseLanguage language,
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

class ContractorAiPlannerController
    extends StateNotifier<ContractorAiPlannerState> {
  ContractorAiPlannerController(this._repository)
      : super(const ContractorAiPlannerState());

  final ContractorAiPlannerRepository _repository;

  // Guards against a stale in-flight request's result/error overwriting
  // current state. analyze() captures the token [_generationGuard.start]
  // returns *before* awaiting the repository; if [_generationGuard.
  // isCurrent] no longer matches once the await resolves, a newer request
  // (or a response-language change made mid-flight) has superseded it.
  final ContractorAiRequestGenerationGuard _generationGuard =
      ContractorAiRequestGenerationGuard();

  /// Selects [orderId] as the order to plan. A no-op while a request is
  /// loading or if the same order is already selected. Always clears any
  /// previous result/error, so a stale plan for a different order is
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

  /// Selects [intent] as the planning intent to generate. A no-op while a
  /// request is loading or if the same intent is already selected.
  /// Always clears any previous result/error, matching [selectOrder].
  void selectPlanningIntent(ContractorAiPlanningIntent intent) {
    if (state.isLoading) return;
    if (state.selectedPlanningIntent == intent) return;
    state = state.copyWith(
      selectedPlanningIntent: intent,
      clearResult: true,
      clearError: true,
    );
  }

  /// Selects [language] as the response language the Contractor AI should
  /// generate its result in. A no-op while a request is loading or if the
  /// same language is already selected. Always clears any previous
  /// result/error and always preserves the selected order and planning
  /// intent, matching [selectOrder]/[selectPlanningIntent]. Also
  /// invalidates the current request-generation guard so a result from a
  /// request already in flight before this change can never overwrite the
  /// state that follows it — in practice, [analyze] cannot be in flight
  /// here since it also sets `isLoading`, but this keeps the guard
  /// unconditionally correct rather than relying on that ordering.
  void selectResponseLanguage(ContractorAiResponseLanguage language) {
    final next = state.withResponseLanguageSelected(language);
    if (next == null) return;
    _generationGuard.invalidate();
    state = next;
  }

  /// Calls the repository exactly once for the currently-selected order,
  /// planning intent, and response language. Never auto-retries, never
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
      final result = await _repository.analyzeContractorJobPlan(
        orderId: orderId,
        locale: state.selectedResponseLanguage.wireValue,
        planningIntent: state.selectedPlanningIntent.wireValue,
      );
      if (!_generationGuard.isCurrent(requestGeneration)) return;
      state =
          state.copyWith(isLoading: false, result: result, clearError: true);
    } on ContractorAiPlannerException catch (e) {
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

final contractorAiPlannerRepositoryProvider =
    Provider<ContractorAiPlannerRepository>(
  (ref) => ContractorAiPlannerRepository(),
);

/// `.autoDispose`: this feature's state (selected order/intent, in-flight
/// request, last result/error) is deliberately not kept alive once the
/// screen is popped — the next visit always starts fresh, and no AI
/// result is ever persisted anywhere.
final contractorAiPlannerControllerProvider = StateNotifierProvider.autoDispose<
    ContractorAiPlannerController, ContractorAiPlannerState>(
  (ref) => ContractorAiPlannerController(
    ref.watch(contractorAiPlannerRepositoryProvider),
  ),
);
