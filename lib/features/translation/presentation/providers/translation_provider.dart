// ─── Translation — Riverpod controller ─────────────────────────────────────
// Feature-local providers (deliberately not added to app_providers.dart),
// following the same pattern used elsewhere in the app — see e.g.
// AiServiceAssistantController — but deliberately independent: no shared
// state, no shared helpers, no import of anything under
// lib/features/ai_service_assistant/**.
//
// A single screen may show many translatable items at once (an About
// section, several services, many reviews), so state is intentionally
// per-item rather than one global loading flag: each distinct
// (contentType, sourceDocId, serviceId?, targetLanguage, current source
// text) combination gets its own independent [TranslationItemController]
// instance via `.family`, so one item loading/erroring never affects any
// other item's state.
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/translation_repository.dart';
import '../../models/service_content_translation_result.dart';
import '../../models/translation_result.dart';

/// A stable cache/request key for one translatable item in one target
/// language. [sourceTextFingerprint] is the trimmed current source text (or
/// a fingerprint of it) captured purely for client-side cache invalidation —
/// it is never sent to the backend (see [TranslationRepository]'s request,
/// which only ever carries contentType/sourceDocId/serviceId/targetLanguage).
/// A different key (e.g. because the underlying About/service/review text
/// was edited, or a different target language was requested) always maps to
/// a distinct provider instance with its own fresh [TranslationItemState] —
/// this is what makes an edit to the source content produce a cache miss
/// instead of silently showing a stale translation, and what makes Arabic
/// and Hebrew translations of the same content cache independently.
@immutable
class TranslationRequestKey {
  final TranslationContentType contentType;
  final String sourceDocId;
  final String? serviceId;
  final TranslationTargetLanguage targetLanguage;
  final String sourceTextFingerprint;

  const TranslationRequestKey({
    required this.contentType,
    required this.sourceDocId,
    this.serviceId,
    required this.targetLanguage,
    required this.sourceTextFingerprint,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TranslationRequestKey &&
          other.contentType == contentType &&
          other.sourceDocId == sourceDocId &&
          other.serviceId == serviceId &&
          other.targetLanguage == targetLanguage &&
          other.sourceTextFingerprint == sourceTextFingerprint);

  @override
  int get hashCode => Object.hash(
        contentType,
        sourceDocId,
        serviceId,
        targetLanguage,
        sourceTextFingerprint,
      );
}

enum TranslationItemStatus { idle, loading, success, error }

@immutable
class TranslationItemState {
  final TranslationItemStatus status;
  final TranslationResult? result;
  // Mirrors TranslationException.code/.reason exactly — never invented,
  // renamed, or coerced here.
  final String? errorCode;
  final String? errorReason;
  // Whether the UI may reasonably offer a Retry action for this error.
  // Daily/global-limit, invalid-input, and permission-style failures are
  // not immediately retryable (retrying the identical request would fail
  // the same way); network/availability failures may be.
  final bool isRetryable;

  const TranslationItemState({
    this.status = TranslationItemStatus.idle,
    this.result,
    this.errorCode,
    this.errorReason,
    this.isRetryable = false,
  });

  bool get isIdle => status == TranslationItemStatus.idle;
  bool get isLoading => status == TranslationItemStatus.loading;
  bool get isSuccess => status == TranslationItemStatus.success;
  bool get isError => status == TranslationItemStatus.error;

  /// A stable, non-localized fallback key for a future UI layer to map to
  /// user-facing copy — this is a machine-readable identifier, never actual
  /// display text (this layer never carries UI strings or localization).
  String? get errorFallbackKey => isError ? (errorReason ?? errorCode) : null;
}

/// Daily/global-limit reasons and every invalid-input/permission-style
/// reason are not immediately retryable — the identical request would fail
/// again for the same reason until something external changes (a new UTC
/// day, an edit to the source content, re-authentication). `cooldown_active`
/// is the one resource-exhausted reason left out: it clears itself within
/// seconds, so it is treated as retryable below.
const Set<String> _kNonRetryableTranslationReasons = {
  'invalid_user',
  'invalid_target_language',
  'invalid_content_type',
  'invalid_source_reference',
  'source_not_found',
  'content_not_translatable',
  'text_empty',
  'text_too_long',
  'user_daily_limit',
  'global_daily_limit',
  'provider_quota',
  'invalid_provider_response',
};

/// Classifies whether a translation failure may reasonably be retried
/// immediately. `reason` (when present) always takes precedence over
/// `code`, since a single code (`resource-exhausted`) covers both a
/// short-lived cooldown (retryable) and a daily/global/provider quota
/// (not retryable).
bool _isTranslationErrorRetryable(String code, String? reason) {
  if (reason != null && _kNonRetryableTranslationReasons.contains(reason)) {
    return false;
  }
  switch (code) {
    case 'unauthenticated':
    case 'invalid-argument':
    case 'permission-denied':
    case 'not-found':
    case 'internal':
      return false;
    case 'resource-exhausted':
      // Only reachable here for 'cooldown_active' or an unrecognized
      // reason — daily/global/provider-quota reasons are already excluded
      // above. Treat an unrecognized resource-exhausted reason the same as
      // a short-lived cooldown rather than silently blocking retry forever.
      return true;
    case 'unavailable':
    case 'deadline-exceeded':
    case 'unknown':
    case 'invalid-response':
      return true;
    default:
      return false;
  }
}

class TranslationItemController extends StateNotifier<TranslationItemState> {
  TranslationItemController(this._repository, this._key)
      : super(const TranslationItemState());

  final TranslationRepository _repository;
  final TranslationRequestKey _key;

  /// Requests a translation for this exact key. A no-op while [state] is
  /// already loading — this, together with the family provider giving every
  /// distinct [TranslationRequestKey] its own controller instance, is what
  /// prevents duplicate in-flight requests for the same cache key. Also a
  /// no-op once [state] already holds a successful result for this exact
  /// key: repeated taps for the same current source content and target
  /// language reuse the in-memory result instead of calling the backend
  /// again. Calling this again from an error state re-attempts the request —
  /// the caller decides whether to surface that as "Retry" based on
  /// [TranslationItemState.isRetryable]; this method itself never retries
  /// automatically.
  ///
  /// Validates `sourceDocId`/`serviceId` locally first — using the same
  /// `invalid_source_reference` reason the backend itself would use — so an
  /// obviously-invalid reference never reaches the network. `contentType`
  /// and `targetLanguage` need no such runtime check: both are Dart enums,
  /// so an invalid value cannot exist in the first place. Client-side
  /// checks are never treated as a substitute for the backend's own
  /// authoritative length/content validation.
  Future<void> translate() async {
    if (state.isLoading || state.isSuccess) return;

    final sourceDocId = _key.sourceDocId.trim();
    if (sourceDocId.isEmpty) {
      state = const TranslationItemState(
        status: TranslationItemStatus.error,
        errorCode: 'invalid-argument',
        errorReason: 'invalid_source_reference',
      );
      return;
    }
    if (_key.contentType.requiresServiceId &&
        (_key.serviceId == null || _key.serviceId!.trim().isEmpty)) {
      state = const TranslationItemState(
        status: TranslationItemStatus.error,
        errorCode: 'invalid-argument',
        errorReason: 'invalid_source_reference',
      );
      return;
    }

    state = const TranslationItemState(status: TranslationItemStatus.loading);

    try {
      final result = await _repository.translateProviderContent(
        contentType: _key.contentType,
        sourceDocId: sourceDocId,
        serviceId: _key.serviceId,
        targetLanguage: _key.targetLanguage,
      );
      state = TranslationItemState(
        status: TranslationItemStatus.success,
        result: result,
      );
    } on TranslationException catch (e) {
      state = TranslationItemState(
        status: TranslationItemStatus.error,
        errorCode: e.code,
        errorReason: e.reason,
        isRetryable: _isTranslationErrorRetryable(e.code, e.reason),
      );
    } catch (_) {
      state = const TranslationItemState(
        status: TranslationItemStatus.error,
        errorCode: 'unknown',
        isRetryable: true,
      );
    }
  }
}

final translationRepositoryProvider = Provider<TranslationRepository>((ref) {
  return TranslationRepository();
});

/// One independent [TranslationItemController] per distinct
/// [TranslationRequestKey] — see the key's own doc comment for why this is
/// what makes per-item state, in-memory-only success caching, and
/// edit-invalidation all fall out of Riverpod's own family-provider identity
/// instead of needing a hand-rolled cache map.
final translationItemControllerProvider = StateNotifierProvider.family<
    TranslationItemController, TranslationItemState, TranslationRequestKey>(
  (ref, key) => TranslationItemController(
    ref.watch(translationRepositoryProvider),
    key,
  ),
);

// ─── Combined service_content translation (name + description together) ───
// A fully separate key/state/controller/provider family from everything
// above — About and (future) review translation keep using
// TranslationRequestKey / TranslationItemController /
// translationItemControllerProvider completely unchanged. This section only
// adds a second, independent family for the one-request/one-quota combined
// service name+description translation.

/// A stable cache/request key for one service's combined name+description
/// translation in one target language. Deliberately separate from
/// [TranslationRequestKey] (keyed to a single content field) — a
/// service_content translation combines two source fields in one request, so
/// its key carries two independent fingerprints
/// ([serviceNameFingerprint] / [serviceDescriptionFingerprint]) instead of
/// one. Neither fingerprint is ever sent to the backend — see
/// [TranslationRepository.translateServiceContent], which only ever carries
/// sourceDocId/serviceId/targetLanguage. Editing either the service's name or
/// its description changes this key (a cache miss); Arabic and Hebrew still
/// cache independently, exactly as [TranslationRequestKey] already does.
@immutable
class ServiceContentTranslationRequestKey {
  final String sourceDocId;
  final String serviceId;
  final TranslationTargetLanguage targetLanguage;
  final String serviceNameFingerprint;
  final String serviceDescriptionFingerprint;

  const ServiceContentTranslationRequestKey({
    required this.sourceDocId,
    required this.serviceId,
    required this.targetLanguage,
    required this.serviceNameFingerprint,
    required this.serviceDescriptionFingerprint,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ServiceContentTranslationRequestKey &&
          other.sourceDocId == sourceDocId &&
          other.serviceId == serviceId &&
          other.targetLanguage == targetLanguage &&
          other.serviceNameFingerprint == serviceNameFingerprint &&
          other.serviceDescriptionFingerprint == serviceDescriptionFingerprint);

  @override
  int get hashCode => Object.hash(
        sourceDocId,
        serviceId,
        targetLanguage,
        serviceNameFingerprint,
        serviceDescriptionFingerprint,
      );
}

enum ServiceContentTranslationItemStatus { idle, loading, success, error }

@immutable
class ServiceContentTranslationItemState {
  final ServiceContentTranslationItemStatus status;
  final ServiceContentTranslationResult? result;
  // Mirrors TranslationException.code/.reason exactly — never invented,
  // renamed, or coerced here.
  final String? errorCode;
  final String? errorReason;
  // Same retryability contract as TranslationItemState.isRetryable: daily/
  // global/provider-quota and invalid-input/permission-style failures are
  // not immediately retryable; cooldown/network/availability failures may
  // be — see _isTranslationErrorRetryable below, reused unchanged.
  final bool isRetryable;

  const ServiceContentTranslationItemState({
    this.status = ServiceContentTranslationItemStatus.idle,
    this.result,
    this.errorCode,
    this.errorReason,
    this.isRetryable = false,
  });

  bool get isIdle => status == ServiceContentTranslationItemStatus.idle;
  bool get isLoading => status == ServiceContentTranslationItemStatus.loading;
  bool get isSuccess => status == ServiceContentTranslationItemStatus.success;
  bool get isError => status == ServiceContentTranslationItemStatus.error;

  /// A stable, non-localized fallback key for a future UI layer to map to
  /// user-facing copy — never actual display text.
  String? get errorFallbackKey => isError ? (errorReason ?? errorCode) : null;
}

class ServiceContentTranslationItemController
    extends StateNotifier<ServiceContentTranslationItemState> {
  ServiceContentTranslationItemController(this._repository, this._key)
      : super(const ServiceContentTranslationItemState());

  final TranslationRepository _repository;
  final ServiceContentTranslationRequestKey _key;

  /// Requests a combined name+description translation for this exact key.
  /// Mirrors [TranslationItemController.translate] exactly: a no-op while
  /// already loading (prevents duplicate in-flight requests for the same
  /// key) or already successful (repeated taps reuse the in-memory result —
  /// no repeat network call), local `sourceDocId`/`serviceId` validation
  /// before ever reaching the network using the same `invalid_source_
  /// reference` reason the backend itself would use, and no automatic
  /// retry — calling this again from an error state is the only way a
  /// retry ever happens, and the caller decides whether to surface that as
  /// "Retry" based on [ServiceContentTranslationItemState.isRetryable].
  Future<void> translate() async {
    if (state.isLoading || state.isSuccess) return;

    final sourceDocId = _key.sourceDocId.trim();
    if (sourceDocId.isEmpty) {
      state = const ServiceContentTranslationItemState(
        status: ServiceContentTranslationItemStatus.error,
        errorCode: 'invalid-argument',
        errorReason: 'invalid_source_reference',
      );
      return;
    }
    final serviceId = _key.serviceId.trim();
    if (serviceId.isEmpty) {
      state = const ServiceContentTranslationItemState(
        status: ServiceContentTranslationItemStatus.error,
        errorCode: 'invalid-argument',
        errorReason: 'invalid_source_reference',
      );
      return;
    }

    state = const ServiceContentTranslationItemState(
      status: ServiceContentTranslationItemStatus.loading,
    );

    try {
      final result = await _repository.translateServiceContent(
        sourceDocId: sourceDocId,
        serviceId: serviceId,
        targetLanguage: _key.targetLanguage,
      );
      state = ServiceContentTranslationItemState(
        status: ServiceContentTranslationItemStatus.success,
        result: result,
      );
    } on TranslationException catch (e) {
      state = ServiceContentTranslationItemState(
        status: ServiceContentTranslationItemStatus.error,
        errorCode: e.code,
        errorReason: e.reason,
        isRetryable: _isTranslationErrorRetryable(e.code, e.reason),
      );
    } catch (_) {
      state = const ServiceContentTranslationItemState(
        status: ServiceContentTranslationItemStatus.error,
        errorCode: 'unknown',
        isRetryable: true,
      );
    }
  }
}

/// One independent [ServiceContentTranslationItemController] per distinct
/// [ServiceContentTranslationRequestKey] — same family-provider identity
/// pattern as [translationItemControllerProvider] above (one instance per
/// key, in-memory only, no autoDispose), kept as a fully separate family so
/// a failure for one service, or About/review translation elsewhere, can
/// never affect this one.
final serviceContentTranslationItemControllerProvider =
    StateNotifierProvider.family<
        ServiceContentTranslationItemController,
        ServiceContentTranslationItemState,
        ServiceContentTranslationRequestKey>(
  (ref, key) => ServiceContentTranslationItemController(
    ref.watch(translationRepositoryProvider),
    key,
  ),
);

// ─── Chat message translation (translateChatMessage) ──────────────────────
// A third, fully independent family from everything above — About/service/
// review translation keep using TranslationRequestKey /
// TranslationItemController / translationItemControllerProvider and
// ServiceContentTranslationRequestKey / ServiceContentTranslationItemController
// / serviceContentTranslationItemControllerProvider completely unchanged.
// This section only adds a new family for on-demand chat-message
// translation, calling TranslationRepository.translateChatMessage (which
// talks to the deployed `translateChatMessage` callable, never
// `translateProviderContent`).

/// A stable cache/request key for one chat message's translation into one
/// target language. [sourceTextFingerprint] is the trimmed current message
/// text (or a fingerprint of it) captured purely for client-side cache
/// invalidation when a message is edited — it is never sent to the backend
/// (see [TranslationRepository.translateChatMessage], which only ever
/// carries conversationId/messageId/targetLanguage). A different key (a
/// different message, a different target language, or the same message
/// after its text was edited) always maps to a distinct provider instance
/// with its own fresh [ChatMessageTranslationItemState] — this is what makes
/// an edit to the message text produce a cache miss instead of silently
/// showing a stale translation, what makes Arabic/Hebrew/English
/// translations of the same message cache independently, and what keeps two
/// different messages' state from ever influencing one another.
@immutable
class ChatMessageTranslationRequestKey {
  final String conversationId;
  final String messageId;
  final TranslationTargetLanguage targetLanguage;
  final String sourceTextFingerprint;

  const ChatMessageTranslationRequestKey({
    required this.conversationId,
    required this.messageId,
    required this.targetLanguage,
    required this.sourceTextFingerprint,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatMessageTranslationRequestKey &&
          other.conversationId == conversationId &&
          other.messageId == messageId &&
          other.targetLanguage == targetLanguage &&
          other.sourceTextFingerprint == sourceTextFingerprint);

  @override
  int get hashCode => Object.hash(
        conversationId,
        messageId,
        targetLanguage,
        sourceTextFingerprint,
      );
}

enum ChatMessageTranslationItemStatus { idle, loading, success, error }

@immutable
class ChatMessageTranslationItemState {
  final ChatMessageTranslationItemStatus status;
  final TranslationResult? result;
  // Mirrors TranslationException.code/.reason exactly — never invented,
  // renamed, or coerced here.
  final String? errorCode;
  final String? errorReason;
  // Same retryability contract as TranslationItemState.isRetryable —
  // computed via the same shared _isTranslationErrorRetryable classifier
  // below, unchanged.
  final bool isRetryable;

  const ChatMessageTranslationItemState({
    this.status = ChatMessageTranslationItemStatus.idle,
    this.result,
    this.errorCode,
    this.errorReason,
    this.isRetryable = false,
  });

  bool get isIdle => status == ChatMessageTranslationItemStatus.idle;
  bool get isLoading => status == ChatMessageTranslationItemStatus.loading;
  bool get isSuccess => status == ChatMessageTranslationItemStatus.success;
  bool get isError => status == ChatMessageTranslationItemStatus.error;

  /// A stable, non-localized fallback key for a future UI layer to map to
  /// user-facing copy — never actual display text.
  String? get errorFallbackKey => isError ? (errorReason ?? errorCode) : null;
}

class ChatMessageTranslationItemController
    extends StateNotifier<ChatMessageTranslationItemState> {
  ChatMessageTranslationItemController(this._repository, this._key)
      : super(const ChatMessageTranslationItemState());

  final TranslationRepository _repository;
  final ChatMessageTranslationRequestKey _key;

  /// Requests a translation for this exact key. Mirrors
  /// [TranslationItemController.translate] exactly: a no-op while [state] is
  /// already loading (prevents a duplicate in-flight request for the same
  /// key) or already holds a success result for this exact key (repeated
  /// taps reuse the in-memory result instead of calling the backend again).
  /// Calling this again from an error state re-attempts the request — the
  /// caller decides whether to surface that as "Retry" based on
  /// [ChatMessageTranslationItemState.isRetryable]; this method itself never
  /// retries automatically.
  ///
  /// Validates `conversationId`/`messageId` locally first — using the same
  /// `invalid_request` reason the backend itself would use for a malformed
  /// request — so an obviously-invalid reference never reaches the network.
  /// `targetLanguage` needs no such runtime check: it is a Dart enum, so an
  /// invalid value cannot exist in the first place. This client-side check
  /// is never a substitute for the backend's own authoritative
  /// participant/message/content validation.
  Future<void> translate() async {
    if (state.isLoading || state.isSuccess) return;

    final conversationId = _key.conversationId.trim();
    final messageId = _key.messageId.trim();
    if (conversationId.isEmpty || messageId.isEmpty) {
      state = const ChatMessageTranslationItemState(
        status: ChatMessageTranslationItemStatus.error,
        errorCode: 'invalid-argument',
        errorReason: 'invalid_request',
      );
      return;
    }

    state = const ChatMessageTranslationItemState(
      status: ChatMessageTranslationItemStatus.loading,
    );

    try {
      final result = await _repository.translateChatMessage(
        conversationId: conversationId,
        messageId: messageId,
        targetLanguage: _key.targetLanguage,
      );
      state = ChatMessageTranslationItemState(
        status: ChatMessageTranslationItemStatus.success,
        result: result,
      );
    } on TranslationException catch (e) {
      state = ChatMessageTranslationItemState(
        status: ChatMessageTranslationItemStatus.error,
        errorCode: e.code,
        errorReason: e.reason,
        isRetryable: _isTranslationErrorRetryable(e.code, e.reason),
      );
    } catch (_) {
      state = const ChatMessageTranslationItemState(
        status: ChatMessageTranslationItemStatus.error,
        errorCode: 'unknown',
        isRetryable: true,
      );
    }
  }
}

/// One independent [ChatMessageTranslationItemController] per distinct
/// [ChatMessageTranslationRequestKey] — same family-provider identity
/// pattern as [translationItemControllerProvider] /
/// [serviceContentTranslationItemControllerProvider] above (one instance per
/// key, in-memory only, no autoDispose): a given message's translation state
/// in a given target language can never leak into another message's state,
/// another target language's state, or an About/service/review
/// translation's state elsewhere in the app.
final chatMessageTranslationItemControllerProvider =
    StateNotifierProvider.family<ChatMessageTranslationItemController,
        ChatMessageTranslationItemState, ChatMessageTranslationRequestKey>(
  (ref, key) => ChatMessageTranslationItemController(
    ref.watch(translationRepositoryProvider),
    key,
  ),
);
