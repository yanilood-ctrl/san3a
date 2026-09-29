// ─── AI Service Assistant Repository ───────────────────────────────────────
// Talks to the mock `analyzeServiceProblem` 2nd-gen callable Cloud Function
// only. No Firestore read/write, no firebase-admin, no AI provider call, no
// manually-attached token/uid/password — the Cloud Functions client SDK
// automatically attaches the current Firebase Authentication session to the
// callable request. The submitted problem text is never logged or persisted
// here.
import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

import '../models/ai_service_analysis_result.dart';

/// Stable, localization-agnostic failure code surfaced by
/// [AiServiceAssistantRepository]. The presentation layer maps these codes to
/// user-facing, localized copy — this layer never carries UI text and never
/// exposes a raw stack trace or exception message to the caller.
///
/// [reason] is an optional, additionally-narrowing detail for a subset of
/// codes (currently only the backend's `resource-exhausted` rate-limit
/// reasons). It is populated only from a known, allow-listed set of values —
/// never the raw `details` map — so it is always safe to forward to the UI.
class AiServiceAssistantException implements Exception {
  final String code;
  final String? reason;
  const AiServiceAssistantException(this.code, {this.reason});
}

/// Known, allow-listed values for [AiServiceAssistantException.reason].
/// Any other value received from the backend is treated as absent.
const Set<String> _kKnownAiExceptionReasons = {
  'cooldown_active',
  'user_daily_limit',
  'global_daily_limit',
  'provider_quota',
};

/// Safely extracts a known rate-limit reason from a
/// [FirebaseFunctionsException.details] value. Returns null unless [details]
/// is a Map containing a non-empty String under "reason" that exactly matches
/// one of the known reasons — never exposes the rest of the details map,
/// backend messages, counts, timestamps, UID, or document paths.
String? _safeExtractReason(Object? details) {
  if (details is! Map) return null;
  final raw = details['reason'];
  if (raw is! String) return null;
  final trimmed = raw.trim();
  if (!_kKnownAiExceptionReasons.contains(trimmed)) return null;
  return trimmed;
}

/// One structured question/answer pair the Customer supplied for a
/// refinement request, matching the deployed backend's structured
/// refinement-answer contract exactly. Serializes only `question`,
/// `answer`, `answerType`, and `options` — never any other field (no UID,
/// profile, provider data, city, budget, notes, or Order data) — and is
/// never persisted anywhere.
class AiFollowUpAnswer {
  final String question;
  final String answer;
  final AiFollowUpAnswerType answerType;
  final List<String> options;
  const AiFollowUpAnswer({
    required this.question,
    required this.answer,
    required this.answerType,
    required this.options,
  });

  Map<String, dynamic> toMap() => {
        'question': question,
        'answer': answer,
        'answerType': answerType.name,
        'options': options,
      };
}

class AiServiceAssistantRepository {
  AiServiceAssistantRepository({FirebaseFunctions? functions})
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
  // kDebugMode alone is no longer sufficient, and kDebugMode is still
  // required so this stays compiled out entirely in release/profile builds
  // (both are compile-time constants there) even if USE_FUNCTIONS_EMULATOR
  // were accidentally passed to a release build. Never touches the Auth
  // emulator or any existing Firebase Auth configuration — only this
  // Functions instance is redirected.
  void _maybeUseEmulator() {
    if (_emulatorConfigured || !kDebugMode || !_useFunctionsEmulator) return;
    _emulatorConfigured = true;
    final host =
        kIsWeb ? '127.0.0.1' : (Platform.isAndroid ? '10.0.2.2' : '127.0.0.1');
    _functions.useFunctionsEmulator(host, 5001);
  }

  Future<AiServiceAnalysisResult> analyzeServiceProblem(
    String trimmedProblemText, {
    List<AiFollowUpAnswer>? followUpAnswers,
  }) async {
    final callable = _functions.httpsCallable(
      'analyzeServiceProblem',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
    );

    final Map<String, dynamic> requestData = {
      'problemText': trimmedProblemText,
      if (followUpAnswers != null && followUpAnswers.isNotEmpty)
        'followUpAnswers': followUpAnswers.map((a) => a.toMap()).toList(),
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
        throw const AiServiceAssistantException('unavailable');
      }
      throw AiServiceAssistantException(
        e.code,
        reason: _safeExtractReason(e.details),
      );
    } on TimeoutException {
      throw const AiServiceAssistantException('deadline-exceeded');
    } on FirebaseException {
      throw const AiServiceAssistantException('unavailable');
    } catch (_) {
      throw const AiServiceAssistantException('unknown');
    }

    try {
      return AiServiceAnalysisResult.fromMap(result.data);
    } on FormatException {
      throw const AiServiceAssistantException('invalid-response');
    }
  }
}
