// ─── Chat Message Translate Action ──────────────────────────────────────────
// Reusable, optional "Translate message" affordance for a single ordinary
// Firestore chat text message. San3a itself stays English-only; this widget
// only ever offers translating the one message it wraps, on demand, into
// Arabic, Hebrew, or English. The original message text is never replaced —
// it stays rendered by the chat bubble exactly as it already is, and the
// translated text (when shown) renders in a small separate block underneath,
// owned entirely by this widget. This widget never writes to Firestore and
// never persists a translated string anywhere; every translation lives only
// in this widget's in-memory Riverpod state for the current session.
//
// Built entirely on the existing translation data layer
// (TranslationRepository.translateChatMessage / TranslationResult /
// ChatMessageTranslationRequestKey / chatMessageTranslationItemControllerProvider
// / ChatMessageTranslationItemState) — this file adds no new backend call, no
// new repository, and no Firestore read/write of its own. Deliberately
// independent from ProviderContentTranslateAction / ProviderServiceTranslateAction
// (which still handle About/service/review translation via
// translateProviderContent, completely untouched by this file) — this widget
// calls the separate `translateChatMessage` callable instead. It has no
// dependency on, and is never used by, the AI Service Assistant feature.
//
// Eligibility (which messages should even show this action — e.g. only
// received text messages, never the sender's own bubble, never
// image/voice/adminWarning bubbles) is deliberately NOT decided here: that is
// the chat bubble's responsibility at its own call site. This widget only
// ever renders the translate affordance for whatever (conversationId,
// messageId, sourceText) it is given.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_localizations.dart';
import '../../features/translation/data/translation_repository.dart'
    show TranslationTargetLanguage;
import '../../features/translation/presentation/providers/translation_provider.dart';

class ChatMessageTranslateAction extends ConsumerStatefulWidget {
  final String conversationId;
  final String messageId;
  // Client-only: used to build the ChatMessageTranslationRequestKey's
  // cache-invalidation fingerprint (and to decide whether this action
  // renders at all). Never sent to the translateChatMessage callable — the
  // repository call only ever carries conversationId/messageId/
  // targetLanguage (see TranslationRepository.translateChatMessage). The
  // backend re-reads the message's current text itself from Firestore.
  final String sourceText;

  const ChatMessageTranslateAction({
    super.key,
    required this.conversationId,
    required this.messageId,
    required this.sourceText,
  });

  @override
  ConsumerState<ChatMessageTranslateAction> createState() =>
      _ChatMessageTranslateActionState();
}

class _ChatMessageTranslateActionState
    extends ConsumerState<ChatMessageTranslateAction> {
  // Local, ephemeral UI state only — which of the three language choices (if
  // any) the user has opened for this widget instance. The actual
  // translation result/loading/error state lives in the shared, keyed
  // chatMessageTranslationItemControllerProvider below, not here, so it
  // survives this widget collapsing back to its compact entry state.
  bool _showLanguageChoices = false;
  TranslationTargetLanguage? _selectedLanguage;

  ChatMessageTranslationRequestKey _keyFor(
          TranslationTargetLanguage language) =>
      ChatMessageTranslationRequestKey(
        conversationId: widget.conversationId,
        messageId: widget.messageId,
        targetLanguage: language,
        sourceTextFingerprint: widget.sourceText,
      );

  void _openLanguageChoices() {
    setState(() => _showLanguageChoices = true);
  }

  void _selectLanguage(TranslationTargetLanguage language) {
    setState(() => _selectedLanguage = language);
    // A no-op when this exact key is already loading or already holds a
    // success result — see ChatMessageTranslationItemController.translate().
    // This is what makes reopening the same translation during the same
    // session reuse the in-memory result instead of calling the backend
    // again, and what prevents a duplicate in-flight request for the same
    // key.
    ref
        .read(chatMessageTranslationItemControllerProvider(_keyFor(language))
            .notifier)
        .translate();
  }

  void _retry(TranslationTargetLanguage language) {
    ref
        .read(chatMessageTranslationItemControllerProvider(_keyFor(language))
            .notifier)
        .translate();
  }

  void _hideTranslation() {
    setState(() {
      _showLanguageChoices = false;
      _selectedLanguage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Never shown for empty/whitespace-only text — there is nothing for the
    // backend to translate, and the message bubble itself already handles
    // rendering the (unchanged) original text regardless of this widget.
    if (widget.sourceText.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final l = AppLocalizations.of(context);

    if (!_showLanguageChoices) {
      return _ChatTranslateEntryButton(
          label: l.get('translate_message'), onTap: _openLanguageChoices);
    }

    final selectedLanguage = _selectedLanguage;
    final itemState = selectedLanguage == null
        ? null
        : ref.watch(chatMessageTranslationItemControllerProvider(
            _keyFor(selectedLanguage)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _ChatLanguageChoiceRow(
          label: l.get('translate_to'),
          arabicLabel: l.get('arabic'),
          hebrewLabel: l.get('hebrew'),
          englishLabel: l.get('english'),
          selectedLanguage: selectedLanguage,
          onSelectArabic: () => _selectLanguage(TranslationTargetLanguage.ar),
          onSelectHebrew: () => _selectLanguage(TranslationTargetLanguage.he),
          onSelectEnglish: () => _selectLanguage(TranslationTargetLanguage.en),
        ),
        if (selectedLanguage != null && itemState != null) ...[
          const SizedBox(height: 8),
          _ChatTranslationPanel(
            language: selectedLanguage,
            state: itemState,
            l: l,
            onHide: _hideTranslation,
            onRetry: () => _retry(selectedLanguage),
          ),
        ],
      ],
    );
  }
}

// ── Compact entry button ("Translate message") ──────────────────────────────
class _ChatTranslateEntryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ChatTranslateEntryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.translate_rounded,
                  size: 15, color: Color(0xFF6D28D9)),
              const SizedBox(width: 5),
              // Flexible so a long localized label shrinks/wraps inside a
              // narrow chat bubble instead of overflowing the bubble's
              // 70%-of-screen width constraint on small phones.
              Flexible(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6D28D9))),
              ),
            ],
          ),
        ),
      );
}

// ── Arabic / Hebrew / English choice row ─────────────────────────────────────
// Laid out with a Wrap rather than a Row: the chat bubble constrains this
// widget to 70% of the screen width (see the chat screens' _Bubble
// ConstrainedBox), and on narrower phones "Translate to" + the three language
// chips do not fit on one line — a Row overflowed to the right ("RIGHT
// OVERFLOWED BY N PIXELS"). Wrap keeps every chip fully visible and simply
// moves the ones that don't fit onto the next line, so nothing is clipped or
// hidden and the layout adapts to any available width.
class _ChatLanguageChoiceRow extends StatelessWidget {
  final String label;
  final String arabicLabel;
  final String hebrewLabel;
  final String englishLabel;
  final TranslationTargetLanguage? selectedLanguage;
  final VoidCallback onSelectArabic;
  final VoidCallback onSelectHebrew;
  final VoidCallback onSelectEnglish;

  const _ChatLanguageChoiceRow({
    required this.label,
    required this.arabicLabel,
    required this.hebrewLabel,
    required this.englishLabel,
    required this.selectedLanguage,
    required this.onSelectArabic,
    required this.onSelectHebrew,
    required this.onSelectEnglish,
  });

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Padding(
            // Keeps the original 8px gap between the label and the first chip
            // when they share a line, without needing a fixed-width SizedBox
            // that Wrap would treat as its own wrappable child.
            padding: const EdgeInsets.only(right: 2),
            child: Text(label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF9999BB))),
          ),
          _ChatLanguageChip(
            label: arabicLabel,
            selected: selectedLanguage == TranslationTargetLanguage.ar,
            onTap: onSelectArabic,
          ),
          _ChatLanguageChip(
            label: hebrewLabel,
            selected: selectedLanguage == TranslationTargetLanguage.he,
            onTap: onSelectHebrew,
          ),
          _ChatLanguageChip(
            label: englishLabel,
            selected: selectedLanguage == TranslationTargetLanguage.en,
            onTap: onSelectEnglish,
          ),
        ],
      );
}

class _ChatLanguageChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ChatLanguageChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF6D28D9)
                : const Color(0xFF6D28D9).withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : const Color(0xFF6D28D9))),
        ),
      );
}

// ── Loading / success / same-language / error panel for one selected
// language's ChatMessageTranslationItemState ────────────────────────────────
class _ChatTranslationPanel extends StatelessWidget {
  final TranslationTargetLanguage language;
  final ChatMessageTranslationItemState state;
  final AppLocalizations l;
  final VoidCallback onHide;
  final VoidCallback onRetry;

  const _ChatTranslationPanel({
    required this.language,
    required this.state,
    required this.l,
    required this.onHide,
    required this.onRetry,
  });

  String get _translationLabel {
    switch (language) {
      case TranslationTargetLanguage.ar:
        return l.get('arabic_translation');
      case TranslationTargetLanguage.he:
        return l.get('hebrew_translation');
      case TranslationTargetLanguage.en:
        return l.get('english_translation');
    }
  }

  String get _alreadyInLabel {
    switch (language) {
      case TranslationTargetLanguage.ar:
        return l.get('already_in_arabic');
      case TranslationTargetLanguage.he:
        return l.get('already_in_hebrew');
      case TranslationTargetLanguage.en:
        return l.get('already_in_english');
    }
  }

  // Arabic and Hebrew both render RTL and right-aligned; English renders LTR
  // and left-aligned — matches ProviderContentTranslateAction's directionality
  // exactly.
  bool get _isLtr => language == TranslationTargetLanguage.en;

  /// Maps a failure to one of the compact, English-only fallback keys —
  /// never the raw backend message. Matches
  /// ProviderContentTranslateAction/ProviderServiceTranslateAction's mapping
  /// exactly: a small, deliberately coarse mapping (daily/global/provider
  /// quota, text-too-long, and one generic fallback that also covers this
  /// callable's own auth/authorization/message-state reasons — e.g.
  /// not_a_participant, message_not_found, message_not_translatable,
  /// conversation_mismatch — none of which need distinct chat-specific copy
  /// since the chat bubble's own eligibility rules should make them
  /// practically unreachable in normal use).
  String get _errorMessage {
    final reason = state.errorReason;
    if (reason == 'user_daily_limit' ||
        reason == 'global_daily_limit' ||
        reason == 'provider_quota') {
      return l.get('translation_daily_limit');
    }
    if (reason == 'text_too_long') {
      return l.get('translation_text_too_long');
    }
    return l.get('translation_unavailable');
  }

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case ChatMessageTranslationItemStatus.idle:
        return const SizedBox.shrink();

      case ChatMessageTranslationItemStatus.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Color(0xFF6D28D9)),
          ),
        );

      case ChatMessageTranslationItemStatus.error:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage,
                style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C))),
            if (state.isRetryable) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: onRetry,
                behavior: HitTestBehavior.opaque,
                child: Text(l.get('retry'),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6D28D9))),
              ),
            ],
          ],
        );

      case ChatMessageTranslationItemStatus.success:
        final result = state.result;
        if (result == null) return const SizedBox.shrink();

        if (result.sameLanguage) {
          return Text(_alreadyInLabel,
              style: const TextStyle(fontSize: 12, color: Color(0xFF9999BB)));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_translationLabel,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9999BB),
                    letterSpacing: 0.4)),
            const SizedBox(height: 4),
            Directionality(
              textDirection: _isLtr ? TextDirection.ltr : TextDirection.rtl,
              child: Text(
                result.translatedText,
                textAlign: _isLtr ? TextAlign.left : TextAlign.right,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF44445A), height: 1.55),
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: onHide,
              behavior: HitTestBehavior.opaque,
              child: Text(l.get('hide_translation'),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6D28D9))),
            ),
          ],
        );
    }
  }
}
