// ─── Provider Service Translate Action ──────────────────────────────────────
// Reusable "Translate service" affordance that translates a single service's
// name AND description together, in one backend request / one Gemini call,
// via `translateProviderContent`'s `service_content` content type. San3a
// itself stays English-only; this widget only ever offers translating the
// one service it wraps, on demand, into Arabic or Hebrew. The original name
// and description are never replaced — they stay visible exactly as passed
// in, unchanged, and the translated name/description (when shown) render in
// a small separate block underneath.
//
// Built entirely on the existing translation data layer
// (TranslationRepository.translateServiceContent /
// ServiceContentTranslationResult / ServiceContentTranslationRequestKey /
// serviceContentTranslationItemControllerProvider /
// ServiceContentTranslationItemState) — this file adds no new backend call,
// no new repository, and no Firestore read/write of its own. Deliberately
// separate from ProviderContentTranslateAction (which still handles About
// translation, and generically supports service_name/service_description
// individually) — this widget is the Customer service row's single combined
// action. It has no dependency on, and is never used by, the AI Service
// Assistant feature.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_localizations.dart';
import '../../features/translation/data/translation_repository.dart'
    show TranslationTargetLanguage;
import '../../features/translation/presentation/providers/translation_provider.dart';

class ProviderServiceTranslateAction extends ConsumerStatefulWidget {
  final String sourceDocId;
  final String serviceId;
  // Client-only: used for display context and to build the
  // ServiceContentTranslationRequestKey's cache-invalidation fingerprints.
  // Never sent to the translateProviderContent callable — the repository
  // call only ever carries sourceDocId/serviceId/targetLanguage (see
  // TranslationRepository.translateServiceContent).
  final String currentServiceName;
  final String currentServiceDescription;

  const ProviderServiceTranslateAction({
    super.key,
    required this.sourceDocId,
    required this.serviceId,
    required this.currentServiceName,
    required this.currentServiceDescription,
  });

  @override
  ConsumerState<ProviderServiceTranslateAction> createState() =>
      _ProviderServiceTranslateActionState();
}

class _ProviderServiceTranslateActionState
    extends ConsumerState<ProviderServiceTranslateAction> {
  // Local, ephemeral UI state only — which of the two language choices (if
  // any) the user has opened for this widget instance. The actual
  // translation result/loading/error state lives in the shared, keyed
  // serviceContentTranslationItemControllerProvider below, not here, so it
  // survives this widget collapsing back to its compact entry state.
  bool _showLanguageChoices = false;
  TranslationTargetLanguage? _selectedLanguage;

  ServiceContentTranslationRequestKey _keyFor(
    TranslationTargetLanguage language,
  ) =>
      ServiceContentTranslationRequestKey(
        sourceDocId: widget.sourceDocId,
        serviceId: widget.serviceId,
        targetLanguage: language,
        serviceNameFingerprint: widget.currentServiceName,
        serviceDescriptionFingerprint: widget.currentServiceDescription,
      );

  void _openLanguageChoices() {
    setState(() => _showLanguageChoices = true);
  }

  void _selectLanguage(TranslationTargetLanguage language) {
    setState(() => _selectedLanguage = language);
    // A no-op when this exact key is already loading or already holds a
    // success result — see ServiceContentTranslationItemController.
    // translate(). This is what makes reopening the same translation during
    // the same session reuse the in-memory result instead of calling the
    // backend again, and what prevents a duplicate in-flight request.
    ref
        .read(serviceContentTranslationItemControllerProvider(_keyFor(language))
            .notifier)
        .translate();
  }

  void _retry(TranslationTargetLanguage language) {
    ref
        .read(serviceContentTranslationItemControllerProvider(_keyFor(language))
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
    // Never shown when there is no service name at all — the name is the
    // one field guaranteed to carry real content; an empty description
    // alone must never hide this action (the name can still be translated).
    if (widget.currentServiceName.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final l = AppLocalizations.of(context);

    if (!_showLanguageChoices) {
      return _TranslateServiceEntryButton(
          label: l.get('translate_service'), onTap: _openLanguageChoices);
    }

    final selectedLanguage = _selectedLanguage;
    final itemState = selectedLanguage == null
        ? null
        : ref.watch(serviceContentTranslationItemControllerProvider(
            _keyFor(selectedLanguage)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _ServiceLanguageChoiceRow(
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
          _ServiceTranslationPanel(
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

// ── Compact entry button ("Translate service") ──────────────────────────────
class _TranslateServiceEntryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _TranslateServiceEntryButton(
      {required this.label, required this.onTap});

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
class _ServiceLanguageChoiceRow extends StatelessWidget {
  final String label;
  final String arabicLabel;
  final String hebrewLabel;
  final String englishLabel;
  final TranslationTargetLanguage? selectedLanguage;
  final VoidCallback onSelectArabic;
  final VoidCallback onSelectHebrew;
  final VoidCallback onSelectEnglish;

  const _ServiceLanguageChoiceRow({
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
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF9999BB))),
          _ServiceLanguageChip(
            label: arabicLabel,
            selected: selectedLanguage == TranslationTargetLanguage.ar,
            onTap: onSelectArabic,
          ),
          _ServiceLanguageChip(
            label: hebrewLabel,
            selected: selectedLanguage == TranslationTargetLanguage.he,
            onTap: onSelectHebrew,
          ),
          _ServiceLanguageChip(
            label: englishLabel,
            selected: selectedLanguage == TranslationTargetLanguage.en,
            onTap: onSelectEnglish,
          ),
        ],
      );
}

class _ServiceLanguageChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ServiceLanguageChip(
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
// language's ServiceContentTranslationItemState ─────────────────────────────
class _ServiceTranslationPanel extends StatelessWidget {
  final TranslationTargetLanguage language;
  final ServiceContentTranslationItemState state;
  final AppLocalizations l;
  final VoidCallback onHide;
  final VoidCallback onRetry;

  const _ServiceTranslationPanel({
    required this.language,
    required this.state,
    required this.l,
    required this.onHide,
    required this.onRetry,
  });

  String get _translationLabel {
    switch (language) {
      case TranslationTargetLanguage.ar:
        return l.get('service_arabic_translation');
      case TranslationTargetLanguage.he:
        return l.get('service_hebrew_translation');
      case TranslationTargetLanguage.en:
        return l.get('service_english_translation');
    }
  }

  String get _alreadyInLabel {
    switch (language) {
      case TranslationTargetLanguage.ar:
        return l.get('service_already_in_arabic');
      case TranslationTargetLanguage.he:
        return l.get('service_already_in_hebrew');
      case TranslationTargetLanguage.en:
        return l.get('service_already_in_english');
    }
  }

  bool get _isLtr => language == TranslationTargetLanguage.en;

  /// Maps a failure to one of the compact, English-only fallback keys —
  /// never the raw backend message. A small, deliberately coarse mapping
  /// (three specific messages plus one generic fallback), matching
  /// ProviderContentTranslateAction's mapping exactly.
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
      case ServiceContentTranslationItemStatus.idle:
        return const SizedBox.shrink();

      case ServiceContentTranslationItemStatus.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Color(0xFF6D28D9)),
          ),
        );

      case ServiceContentTranslationItemStatus.error:
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

      case ServiceContentTranslationItemStatus.success:
        final result = state.result;
        if (result == null) return const SizedBox.shrink();

        if (result.nameSameLanguage && result.descriptionSameLanguage) {
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
                result.translatedName,
                textAlign: _isLtr ? TextAlign.left : TextAlign.right,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF44445A)),
              ),
            ),
            if (result.translatedDescription.isNotEmpty) ...[
              const SizedBox(height: 3),
              Directionality(
                textDirection: _isLtr ? TextDirection.ltr : TextDirection.rtl,
                child: Text(
                  result.translatedDescription,
                  textAlign: _isLtr ? TextAlign.left : TextAlign.right,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF44445A), height: 1.5),
                ),
              ),
            ],
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
