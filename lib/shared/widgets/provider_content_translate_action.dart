// ─── Provider Content Translate Action ─────────────────────────────────────
// Reusable, optional "Translate" affordance for a single piece of dynamic,
// provider-related content (About bio / service name / service description /
// review comment — see TranslationContentType). San3a itself stays
// English-only; this widget only ever offers translating the one piece of
// content it wraps, on demand, into Arabic or Hebrew. The original text is
// never replaced — it stays visible exactly as passed in, unchanged, and the
// translated text (when shown) renders in a small separate block underneath.
//
// Built entirely on the existing Phase 2 translation data layer
// (TranslationRepository / TranslationResult / TranslationRequestKey /
// translationItemControllerProvider / TranslationItemState) — this file adds
// no new backend call, no new repository, and no Firestore read/write of its
// own. It has no dependency on, and is never used by, the AI Service
// Assistant feature.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_localizations.dart';
import '../../features/translation/data/translation_repository.dart'
    show TranslationContentType, TranslationTargetLanguage;
import '../../features/translation/presentation/providers/translation_provider.dart';

class ProviderContentTranslateAction extends ConsumerStatefulWidget {
  final TranslationContentType contentType;
  final String sourceDocId;
  final String? serviceId;
  // Client-only: used for display context and to build the
  // TranslationRequestKey's cache-invalidation fingerprint. Never sent to
  // the translateProviderContent callable — the repository call only ever
  // carries contentType/sourceDocId/serviceId/targetLanguage (see
  // TranslationRepository.translateProviderContent).
  final String currentSourceText;
  // Optional override for the compact entry button's localization key.
  // Defaults to 'translate' — the exact label the About section already
  // uses — so every existing call site is unaffected. Lets two of these
  // widgets sitting close together in the same row (e.g. a service's name
  // and its description) read as distinct actions instead of two identical
  // "Translate" buttons.
  final String entryLabelKey;

  const ProviderContentTranslateAction({
    super.key,
    required this.contentType,
    required this.sourceDocId,
    this.serviceId,
    required this.currentSourceText,
    this.entryLabelKey = 'translate',
  });

  @override
  ConsumerState<ProviderContentTranslateAction> createState() =>
      _ProviderContentTranslateActionState();
}

class _ProviderContentTranslateActionState
    extends ConsumerState<ProviderContentTranslateAction> {
  // Local, ephemeral UI state only — which of the two language choices (if
  // any) the user has opened for this widget instance. The actual
  // translation result/loading/error state lives in the shared, keyed
  // translationItemControllerProvider below, not here, so it survives this
  // widget collapsing back to its compact entry state.
  bool _showLanguageChoices = false;
  TranslationTargetLanguage? _selectedLanguage;

  TranslationRequestKey _keyFor(TranslationTargetLanguage language) =>
      TranslationRequestKey(
        contentType: widget.contentType,
        sourceDocId: widget.sourceDocId,
        serviceId: widget.serviceId,
        targetLanguage: language,
        sourceTextFingerprint: widget.currentSourceText,
      );

  void _openLanguageChoices() {
    setState(() => _showLanguageChoices = true);
  }

  void _selectLanguage(TranslationTargetLanguage language) {
    setState(() => _selectedLanguage = language);
    // A no-op when this exact key is already loading or already holds a
    // success result — see TranslationItemController.translate(). This is
    // what makes reopening the same translation during the same session
    // reuse the in-memory result instead of calling the backend again, and
    // what prevents a duplicate in-flight request for the same key.
    ref
        .read(translationItemControllerProvider(_keyFor(language)).notifier)
        .translate();
  }

  void _retry(TranslationTargetLanguage language) {
    ref
        .read(translationItemControllerProvider(_keyFor(language)).notifier)
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
    // Never shown for empty/whitespace-only content — mirrors the same
    // isNotEmpty gating already used for the About section itself.
    if (widget.currentSourceText.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final l = AppLocalizations.of(context);

    if (!_showLanguageChoices) {
      return _TranslateEntryButton(
          label: l.get(widget.entryLabelKey), onTap: _openLanguageChoices);
    }

    final selectedLanguage = _selectedLanguage;
    final itemState = selectedLanguage == null
        ? null
        : ref.watch(
            translationItemControllerProvider(_keyFor(selectedLanguage)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _LanguageChoiceRow(
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
          _TranslationPanel(
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

// ── Compact entry button ("Translate") ──────────────────────────────────────
class _TranslateEntryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _TranslateEntryButton({required this.label, required this.onTap});

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
              Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6D28D9))),
            ],
          ),
        ),
      );
}

// ── Arabic / Hebrew / English choice row ─────────────────────────────────────
class _LanguageChoiceRow extends StatelessWidget {
  final String label;
  final String arabicLabel;
  final String hebrewLabel;
  final String englishLabel;
  final TranslationTargetLanguage? selectedLanguage;
  final VoidCallback onSelectArabic;
  final VoidCallback onSelectHebrew;
  final VoidCallback onSelectEnglish;

  const _LanguageChoiceRow({
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
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF9999BB))),
          const SizedBox(width: 8),
          _LanguageChip(
            label: arabicLabel,
            selected: selectedLanguage == TranslationTargetLanguage.ar,
            onTap: onSelectArabic,
          ),
          const SizedBox(width: 6),
          _LanguageChip(
            label: hebrewLabel,
            selected: selectedLanguage == TranslationTargetLanguage.he,
            onTap: onSelectHebrew,
          ),
          const SizedBox(width: 6),
          _LanguageChip(
            label: englishLabel,
            selected: selectedLanguage == TranslationTargetLanguage.en,
            onTap: onSelectEnglish,
          ),
        ],
      );
}

class _LanguageChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LanguageChip(
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
// language's TranslationItemState ───────────────────────────────────────────
class _TranslationPanel extends StatelessWidget {
  final TranslationTargetLanguage language;
  final TranslationItemState state;
  final AppLocalizations l;
  final VoidCallback onHide;
  final VoidCallback onRetry;

  const _TranslationPanel({
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

  bool get _isLtr => language == TranslationTargetLanguage.en;

  /// Maps a failure to one of the compact, English-only fallback keys —
  /// never the raw backend message. This is a small, deliberately coarse
  /// mapping (three specific messages plus one generic fallback), not a
  /// one-to-one mapping of every backend reason.
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
      case TranslationItemStatus.idle:
        return const SizedBox.shrink();

      case TranslationItemStatus.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Color(0xFF6D28D9)),
          ),
        );

      case TranslationItemStatus.error:
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

      case TranslationItemStatus.success:
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
