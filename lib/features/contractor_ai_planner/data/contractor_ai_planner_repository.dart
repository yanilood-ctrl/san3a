// ─── Contractor AI Planner Repository ───────────────────────────────────────
// Talks to the real `analyzeContractorJobPlan` 2nd-gen callable Cloud
// Function only. No Firestore read/write, no manually-attached uid/role/
// order/worker data — the Cloud Functions client SDK automatically attaches
// the current Firebase Authentication session to the callable request.
// Completely independent from ProfessionalAiAssistantRepository
// (Professional AI) and AiServiceAssistantRepository (Customer AI): its own
// exception type, its own emulator wiring, its own callable name — never
// reused, never modified together.
import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

import '../models/contractor_ai_plan_result.dart';

/// Stable, localization-agnostic failure code surfaced by
/// [ContractorAiPlannerRepository]. The presentation layer maps these codes
/// to user-facing, localized copy — this layer never carries UI text and
/// never exposes a raw stack trace or exception message to the caller.
///
/// [reason] is an optional, additionally-narrowing detail for a subset of
/// codes (the backend's Contractor-role, ownership, invariant, and
/// rate-limit reasons). It is populated only from a known, allow-listed set
/// of values — never the raw `details` map — so it is always safe to
/// forward to the UI.
class ContractorAiPlannerException implements Exception {
  final String code;
  final String? reason;
  const ContractorAiPlannerException(this.code, {this.reason});
}

/// Known, allow-listed values for [ContractorAiPlannerException.reason].
/// Any other value received from the backend is treated as absent. Mirrors
/// exactly the Contractor AI-specific safe reasons the backend documents —
/// never the Customer AI, Professional AI, or Translation reason sets.
const Set<String> _kKnownContractorAiExceptionReasons = {
  'contractor_only',
  'order_not_found',
  'contractor_ai_invalid_planning_state',
  'contractor_ai_cooldown',
  'contractor_ai_user_daily_limit',
  'contractor_ai_global_daily_limit',
  'contractor_ai_provider_quota',
  'contractor_ai_unavailable',
  'contractor_ai_invalid_response',
};

/// Safely extracts a known reason from a
/// [FirebaseFunctionsException.details] value. Returns null unless
/// [details] is a Map containing a non-empty String under "reason" that
/// exactly matches one of the known reasons — never exposes the rest of
/// the details map, backend messages, counts, timestamps, UID, or document
/// paths.
String? _safeExtractReason(Object? details) {
  if (details is! Map) return null;
  final raw = details['reason'];
  if (raw is! String) return null;
  final trimmed = raw.trim();
  if (!_kKnownContractorAiExceptionReasons.contains(trimmed)) return null;
  return trimmed;
}

class ContractorAiPlannerRepository {
  ContractorAiPlannerRepository({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-central1') {
    _maybeUseEmulator();
  }

  final FirebaseFunctions _functions;
  bool _emulatorConfigured = false;

  // Explicit, compile-time opt-in — the emulator is never used just
  // because a build happens to be Debug. Must be passed at build/run
  // time, e.g. `flutter run -d edge --dart-define=USE_FUNCTIONS_EMULATOR=true`.
  static const bool _useFunctionsEmulator = bool.fromEnvironment(
    'USE_FUNCTIONS_EMULATOR',
    defaultValue: false,
  );

  // One-time emulator wiring, run before the first callable is ever
  // created. Requires BOTH kDebugMode and the explicit
  // _useFunctionsEmulator opt-in — never touches the Auth emulator or any
  // existing Firebase Auth configuration — only this Functions instance
  // is redirected.
  void _maybeUseEmulator() {
    if (_emulatorConfigured || !kDebugMode || !_useFunctionsEmulator) return;
    _emulatorConfigured = true;
    final host =
        kIsWeb ? '127.0.0.1' : (Platform.isAndroid ? '10.0.2.2' : '127.0.0.1');
    _functions.useFunctionsEmulator(host, 5001);
  }

  /// Calls `analyzeContractorJobPlan` for [orderId] with the given
  /// [locale] ("en"/"ar"/"he") and [planningIntent] ("prepare_job"/
  /// "plan_crew"/"request_customer_info"). Sends exactly these three
  /// fields — never a UID, role, or any order/customer/provider/worker
  /// data; the backend loads and verifies the order and the Contractor's
  /// own workers itself from the authenticated caller's own session.
  Future<ContractorAiPlanResult> analyzeContractorJobPlan({
    required String orderId,
    required String locale,
    required String planningIntent,
  }) async {
    final callable = _functions.httpsCallable(
      'analyzeContractorJobPlan',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
    );

    final Map<String, dynamic> requestData = {
      'orderId': orderId,
      'locale': locale,
      'planningIntent': planningIntent,
    };

    final HttpsCallableResult<dynamic> result;
    try {
      result = await callable.call(requestData);
    } on FirebaseFunctionsException catch (e) {
      final reason = _safeExtractReason(e.details);
      // Debug-only: the local Functions Emulator surfaces a plain
      // connection failure (emulator stopped, wrong host/port) as
      // 'internal' or 'unknown' — the same codes a genuine backend
      // fault would use. Unlike Professional AI, a Contractor AI
      // 'internal' error CAN legitimately carry a real reason
      // (contractor_ai_invalid_response), so this debug-only remap is
      // deliberately narrowed to only apply when no known reason was
      // present — i.e. it really does look like nothing answered
      // locally, not a genuine validated backend failure.
      if (kDebugMode &&
          (e.code == 'internal' || e.code == 'unknown') &&
          reason == null) {
        throw const ContractorAiPlannerException('unavailable');
      }
      throw ContractorAiPlannerException(e.code, reason: reason);
    } on TimeoutException {
      throw const ContractorAiPlannerException('deadline-exceeded');
    } on FirebaseException {
      throw const ContractorAiPlannerException('unavailable');
    } catch (_) {
      throw const ContractorAiPlannerException('unknown');
    }

    try {
      return ContractorAiPlanResult.fromMap(result.data);
    } on FormatException {
      throw const ContractorAiPlannerException('invalid-response');
    }
  }
}
