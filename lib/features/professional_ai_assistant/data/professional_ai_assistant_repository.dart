// ─── Professional AI Assistant Repository ──────────────────────────────────
// Talks to the real `analyzeProfessionalJob` 2nd-gen callable Cloud Function
// only. No Firestore read/write, no manually-attached uid/role/order data —
// the Cloud Functions client SDK automatically attaches the current Firebase
// Authentication session to the callable request. Completely independent
// from AiServiceAssistantRepository (Customer AI): its own exception type,
// its own emulator wiring, its own callable name — never reused, never
// modified together.
import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

import '../models/professional_ai_analysis_result.dart';

/// Stable, localization-agnostic failure code surfaced by
/// [ProfessionalAiAssistantRepository]. The presentation layer maps these
/// codes to user-facing, localized copy — this layer never carries UI text
/// and never exposes a raw stack trace or exception message to the caller.
///
/// [reason] is an optional, additionally-narrowing detail for a subset of
/// codes (the backend's Professional-role and rate-limit reasons). It is
/// populated only from a known, allow-listed set of values — never the raw
/// `details` map — so it is always safe to forward to the UI.
class ProfessionalAiAssistantException implements Exception {
  final String code;
  final String? reason;
  const ProfessionalAiAssistantException(this.code, {this.reason});
}

/// Known, allow-listed values for [ProfessionalAiAssistantException.reason].
/// Any other value received from the backend is treated as absent. Mirrors
/// exactly the Professional AI-specific safe reasons the backend documents —
/// never the Customer AI or Translation reason sets.
const Set<String> _kKnownProfessionalAiExceptionReasons = {
  'professional_only',
  'order_not_found',
  'professional_ai_cooldown',
  'professional_ai_user_daily_limit',
  'professional_ai_global_daily_limit',
  'professional_ai_provider_quota',
};

/// Safely extracts a known reason from a
/// [FirebaseFunctionsException.details] value. Returns null unless [details]
/// is a Map containing a non-empty String under "reason" that exactly
/// matches one of the known reasons — never exposes the rest of the details
/// map, backend messages, counts, timestamps, UID, or document paths.
String? _safeExtractReason(Object? details) {
  if (details is! Map) return null;
  final raw = details['reason'];
  if (raw is! String) return null;
  final trimmed = raw.trim();
  if (!_kKnownProfessionalAiExceptionReasons.contains(trimmed)) return null;
  return trimmed;
}

class ProfessionalAiAssistantRepository {
  ProfessionalAiAssistantRepository({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-central1') {
    _maybeUseEmulator();
  }

  final FirebaseFunctions _functions;
  bool _emulatorConfigured = false;

  // Explicit, compile-time opt-in — the emulator is never used just because
  // a build happens to be Debug. Must be passed at build/run time, e.g.
  // `flutter run -d edge --dart-define=USE_FUNCTIONS_EMULATOR=true`.
  static const bool _useFunctionsEmulator = bool.fromEnvironment(
    'USE_FUNCTIONS_EMULATOR',
    defaultValue: false,
  );

  // One-time emulator wiring, run before the first callable is ever created.
  // Requires BOTH kDebugMode and the explicit _useFunctionsEmulator opt-in —
  // never touches the Auth emulator or any existing Firebase Auth
  // configuration — only this Functions instance is redirected.
  void _maybeUseEmulator() {
    if (_emulatorConfigured || !kDebugMode || !_useFunctionsEmulator) return;
    _emulatorConfigured = true;
    final host =
        kIsWeb ? '127.0.0.1' : (Platform.isAndroid ? '10.0.2.2' : '127.0.0.1');
    _functions.useFunctionsEmulator(host, 5001);
  }

  /// Calls `analyzeProfessionalJob` for [orderId] with the given [locale]
  /// ("en"/"ar"/"he") and [messageIntent] ("confirm_appointment"/
  /// "request_more_info"/"request_photos"). Sends exactly these three
  /// fields — never a UID, role, or any order/customer/provider data; the
  /// backend loads and verifies the order itself from the authenticated
  /// caller's own session.
  Future<ProfessionalAiAnalysisResult> analyzeProfessionalJob({
    required String orderId,
    required String locale,
    required String messageIntent,
  }) async {
    final callable = _functions.httpsCallable(
      'analyzeProfessionalJob',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
    );

    final Map<String, dynamic> requestData = {
      'orderId': orderId,
      'locale': locale,
      'messageIntent': messageIntent,
    };

    final HttpsCallableResult<dynamic> result;
    try {
      result = await callable.call(requestData);
    } on FirebaseFunctionsException catch (e) {
      // Debug-only: the local Functions Emulator surfaces a plain connection
      // failure (emulator stopped, wrong host/port) as 'internal' or
      // 'unknown' — the same codes a genuine backend fault would use. In
      // debug builds only, treat those as the more accurate 'unavailable' so
      // the UI points the developer at "check your local service" instead of
      // a generic error. Release behavior for these codes is unchanged.
      if (kDebugMode && (e.code == 'internal' || e.code == 'unknown')) {
        throw const ProfessionalAiAssistantException('unavailable');
      }
      throw ProfessionalAiAssistantException(
        e.code,
        reason: _safeExtractReason(e.details),
      );
    } on TimeoutException {
      throw const ProfessionalAiAssistantException('deadline-exceeded');
    } on FirebaseException {
      throw const ProfessionalAiAssistantException('unavailable');
    } catch (_) {
      throw const ProfessionalAiAssistantException('unknown');
    }

    try {
      return ProfessionalAiAnalysisResult.fromMap(result.data);
    } on FormatException {
      throw const ProfessionalAiAssistantException('invalid-response');
    }
  }
}
