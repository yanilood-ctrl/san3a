// ─── Translation Repository ─────────────────────────────────────────────────
// Talks to the deployed `translateProviderContent` callable Cloud Function
// only. No Firestore read/write, no firebase-admin, no Gemini key/secret in
// Flutter — the callable itself resolves the source text server-side from a
// (contentType, sourceDocId, serviceId?) reference; this repository only
// ever sends that reference plus targetLanguage, never source text. The
// Cloud Functions client SDK automatically attaches the current Firebase
// Authentication session to the callable request.
//
// Deliberately independent from AiServiceAssistantRepository: its own
// FirebaseFunctions instance, its own emulator gating, its own exception
// type. Nothing here is shared with, extracted from, or coupled to the AI
// Service Assistant feature.
import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

import '../models/service_content_translation_result.dart';
import '../models/translation_result.dart';

/// Stable, localization-agnostic failure code surfaced by
/// [TranslationRepository]. The presentation layer maps these codes (and
/// [reason], when present) to user-facing, localized copy — this layer never
/// carries UI text and never exposes a raw stack trace or exception message
/// to the caller.
///
/// [reason] mirrors `translateProviderContent`'s `HttpsError.details.reason`
/// exactly, unmodified, restricted to the documented allow-list below —
/// never the raw `details` map, and never renamed/coerced.
class TranslationException implements Exception {
  final String code;
  final String? reason;
  const TranslationException(this.code, {this.reason});
}

/// Known, allow-listed values for [TranslationException.reason]. Any other
/// value received from the backend is treated as absent. This is its own
/// independent set — never merged with or shared with the AI Assistant's
/// known reasons.
///
/// The last seven entries are specific to the `translateChatMessage`
/// callable (see [TranslationRepository.translateChatMessage]) — its own
/// auth/authorization/message-resolution reasons, mirrored here exactly from
/// the deployed backend's `ChatTranslateErrorReason` union. Everything above
/// them is unchanged and still describes `translateProviderContent` only;
/// `translateChatMessage` also reuses several of those same entries
/// (`invalid_target_language`, `text_empty`, `text_too_long`,
/// `cooldown_active`, `user_daily_limit`, `global_daily_limit`,
/// `provider_quota`, `provider_unavailable`, `invalid_provider_response`) for
/// the pieces of backend logic it shares with `translateProviderContent`.
const Set<String> _kKnownTranslationExceptionReasons = {
  'unauthenticated',
  'invalid_user',
  'invalid_target_language',
  'invalid_content_type',
  'invalid_source_reference',
  'source_not_found',
  'content_not_translatable',
  'text_empty',
  'text_too_long',
  'cooldown_active',
  'user_daily_limit',
  'global_daily_limit',
  'provider_quota',
  'provider_unavailable',
  'invalid_provider_response',
  'invalid_role',
  'invalid_request',
  'conversation_not_found',
  'not_a_participant',
  'message_not_found',
  'message_not_translatable',
  'conversation_mismatch',
};

/// Safely extracts a known reason from a
/// [FirebaseFunctionsException.details] value. Returns null unless [details]
/// is a Map containing a non-empty String under "reason" that exactly
/// matches one of the known reasons — never exposes the rest of the details
/// map, backend messages, counts, timestamps, UID, or document paths.
String? _safeExtractTranslationReason(Object? details) {
  if (details is! Map) return null;
  final raw = details['reason'];
  if (raw is! String) return null;
  final trimmed = raw.trim();
  if (!_kKnownTranslationExceptionReasons.contains(trimmed)) return null;
  return trimmed;
}

/// The four dynamic content surfaces `translateProviderContent` may
/// translate — mirrors the backend's `TranslationContentType` exactly.
enum TranslationContentType {
  providerAbout,
  serviceName,
  serviceDescription,
  reviewComment,
}

extension TranslationContentTypeWire on TranslationContentType {
  /// The exact wire string the backend expects for `contentType`.
  String get wireValue {
    switch (this) {
      case TranslationContentType.providerAbout:
        return 'provider_about';
      case TranslationContentType.serviceName:
        return 'service_name';
      case TranslationContentType.serviceDescription:
        return 'service_description';
      case TranslationContentType.reviewComment:
        return 'review_comment';
    }
  }

  /// True for the two content types that require a `serviceId` alongside
  /// `sourceDocId` (the service is looked up inside the provider's
  /// `servicesList`).
  bool get requiresServiceId =>
      this == TranslationContentType.serviceName ||
      this == TranslationContentType.serviceDescription;
}

/// The only three languages San3a translates into — mirrors the backend's
/// `TranslationTargetLanguage` exactly. The app itself remains English-only;
/// this is strictly the translation target, never a UI locale.
enum TranslationTargetLanguage { ar, he, en }

extension TranslationTargetLanguageWire on TranslationTargetLanguage {
  /// The exact wire string the backend expects for `targetLanguage`.
  String get wireValue {
    switch (this) {
      case TranslationTargetLanguage.ar:
        return 'ar';
      case TranslationTargetLanguage.he:
        return 'he';
      case TranslationTargetLanguage.en:
        return 'en';
    }
  }
}

class TranslationRepository {
  TranslationRepository({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-central1') {
    _maybeUseEmulator();
  }

  final FirebaseFunctions _functions;
  bool _emulatorConfigured = false;

  // Explicit, compile-time opt-in — the emulator is never used just because
  // a build happens to be Debug. Must be passed at build/run time, e.g.
  // `flutter run -d edge --dart-define=USE_FUNCTIONS_EMULATOR=true`. Reading
  // the same `--dart-define` key as the AI Assistant repository is
  // intentional (it is one build-time flag for the whole app's Functions
  // emulator use, not a shared code path) — this constant and the gating
  // logic below are an independent copy, not extracted from or coupled to
  // that other repository.
  static const bool _useFunctionsEmulator = bool.fromEnvironment(
    'USE_FUNCTIONS_EMULATOR',
    defaultValue: false,
  );

  // One-time emulator wiring, run before the first callable is ever created.
  // Requires BOTH kDebugMode and the explicit _useFunctionsEmulator opt-in —
  // kDebugMode alone is never sufficient, and kDebugMode is still required
  // so this stays compiled out entirely in release/profile builds (both are
  // compile-time constants there) even if USE_FUNCTIONS_EMULATOR were
  // accidentally passed to a release build. Never touches the Auth emulator
  // or any existing Firebase Auth configuration — only this Functions
  // instance is redirected.
  void _maybeUseEmulator() {
    if (_emulatorConfigured || !kDebugMode || !_useFunctionsEmulator) return;
    _emulatorConfigured = true;
    final host =
        kIsWeb ? '127.0.0.1' : (Platform.isAndroid ? '10.0.2.2' : '127.0.0.1');
    _functions.useFunctionsEmulator(host, 5001);
  }

  /// Calls `translateProviderContent`. Sends only a source *reference*
  /// (contentType + sourceDocId + optional serviceId) and targetLanguage —
  /// never the source text itself. The backend re-reads the current
  /// Firestore value and is the sole source of truth for what gets
  /// translated.
  Future<TranslationResult> translateProviderContent({
    required TranslationContentType contentType,
    required String sourceDocId,
    String? serviceId,
    required TranslationTargetLanguage targetLanguage,
  }) async {
    final callable = _functions.httpsCallable(
      'translateProviderContent',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
    );

    final Map<String, dynamic> requestData = {
      'contentType': contentType.wireValue,
      'sourceDocId': sourceDocId,
      if (serviceId != null) 'serviceId': serviceId,
      'targetLanguage': targetLanguage.wireValue,
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
        throw const TranslationException('unavailable');
      }
      throw TranslationException(
        e.code,
        reason: _safeExtractTranslationReason(e.details),
      );
    } on TimeoutException {
      throw const TranslationException('deadline-exceeded');
    } on FirebaseException {
      throw const TranslationException('unavailable');
    } catch (_) {
      throw const TranslationException('unknown');
    }

    try {
      return TranslationResult.fromMap(result.data);
    } on FormatException {
      throw const TranslationException('invalid-response');
    }
  }

  /// Calls the same `translateProviderContent` callable with
  /// `contentType: "service_content"` — a combined service name +
  /// description translation in one request/one Gemini call. Sends only
  /// `{contentType, sourceDocId, serviceId, targetLanguage}`; the service's
  /// current `name`/`description` text is never sent — the backend re-reads
  /// both fields itself from `users/{sourceDocId}.servicesList` and is the
  /// sole source of truth for what gets translated. A fully independent
  /// method from [translateProviderContent] above (its own request/response
  /// shape) but reusing the exact same [_functions] instance, region,
  /// timeout, emulator gating, and [TranslationException] error mapping.
  Future<ServiceContentTranslationResult> translateServiceContent({
    required String sourceDocId,
    required String serviceId,
    required TranslationTargetLanguage targetLanguage,
  }) async {
    final callable = _functions.httpsCallable(
      'translateProviderContent',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
    );

    final Map<String, dynamic> requestData = {
      'contentType': 'service_content',
      'sourceDocId': sourceDocId,
      'serviceId': serviceId,
      'targetLanguage': targetLanguage.wireValue,
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
        throw const TranslationException('unavailable');
      }
      throw TranslationException(
        e.code,
        reason: _safeExtractTranslationReason(e.details),
      );
    } on TimeoutException {
      throw const TranslationException('deadline-exceeded');
    } on FirebaseException {
      throw const TranslationException('unavailable');
    } catch (_) {
      throw const TranslationException('unknown');
    }

    try {
      return ServiceContentTranslationResult.fromMap(result.data);
    } on FormatException {
      throw const TranslationException('invalid-response');
    }
  }

  /// Calls the deployed `translateChatMessage` callable (region
  /// `us-central1`, same [_functions] instance/emulator gating as every
  /// other method above) to translate exactly one ordinary Firestore chat
  /// text message on demand. Sends only `{conversationId, messageId,
  /// targetLanguage}` — never the message's text. The backend re-reads the
  /// current Firestore message itself, after verifying the caller is an
  /// authenticated participant of that conversation, and is the sole source
  /// of truth for what gets translated. A fully independent method from
  /// [translateProviderContent]/[translateServiceContent] above (its own
  /// request/response shape, its own backend function), reusing only the
  /// exact same [_functions] instance, region, timeout,
  /// [_maybeUseEmulator]-configured emulator gating, [TranslationException]
  /// error mapping, and [TranslationResult.fromMap] response parsing.
  Future<TranslationResult> translateChatMessage({
    required String conversationId,
    required String messageId,
    required TranslationTargetLanguage targetLanguage,
  }) async {
    final callable = _functions.httpsCallable(
      'translateChatMessage',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
    );

    final Map<String, dynamic> requestData = {
      'conversationId': conversationId,
      'messageId': messageId,
      'targetLanguage': targetLanguage.wireValue,
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
        throw const TranslationException('unavailable');
      }
      throw TranslationException(
        e.code,
        reason: _safeExtractTranslationReason(e.details),
      );
    } on TimeoutException {
      throw const TranslationException('deadline-exceeded');
    } on FirebaseException {
      throw const TranslationException('unavailable');
    } catch (_) {
      throw const TranslationException('unknown');
    }

    try {
      return TranslationResult.fromMap(result.data);
    } on FormatException {
      throw const TranslationException('invalid-response');
    }
  }
}
