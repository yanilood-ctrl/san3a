// ─── Help Center Translate Actions (Phase 3 — predefined, static) ──────────
// Compact, on-demand "Translate" affordances for the (static) Help Center
// screen. Visually these mirror the existing
// shared/widgets/provider_content_translate_action.dart pattern (compact
// entry button -> Arabic/Hebrew choice row -> separate panel below the
// original English text, with a "Hide translation" toggle) so the San3a
// translate affordance reads the same everywhere in the app.
//
// Unlike that widget, nothing here calls translateProviderContent or any
// other backend: every translated string is a compile-time constant from
// HelpCenterTranslations, resolved instantly and locally. There is
// therefore no loading state (no request is ever in flight) and no error/
// retry state (a local map lookup cannot fail). Arabic and Hebrew are both
// rendered right-to-left.
import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../data/help_center_translations.dart';

const Color _kHelpTranslateColor = Color(0xFF6D28D9);

// ── Shared chrome: entry button, language chip row, panel frame ───────────

class _HelpTranslateEntryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _HelpTranslateEntryButton({required this.label, required this.onTap});

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
                  size: 15, color: _kHelpTranslateColor),
              const SizedBox(width: 5),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _kHelpTranslateColor)),
            ],
          ),
        ),
      );
}

class _HelpLanguageChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _HelpLanguageChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: selected
                ? _kHelpTranslateColor
                : _kHelpTranslateColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : _kHelpTranslateColor)),
        ),
      );
}

class _HelpLanguageChoiceRow extends StatelessWidget {
  final String label;
  final String arabicLabel;
  final String hebrewLabel;
  final HelpTranslationLanguage? selected;
  final VoidCallback onSelectArabic;
  final VoidCallback onSelectHebrew;

  const _HelpLanguageChoiceRow({
    required this.label,
    required this.arabicLabel,
    required this.hebrewLabel,
    required this.selected,
    required this.onSelectArabic,
    required this.onSelectHebrew,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF9999BB))),
          const SizedBox(width: 8),
          _HelpLanguageChip(
            label: arabicLabel,
            selected: selected == HelpTranslationLanguage.ar,
            onTap: onSelectArabic,
          ),
          const SizedBox(width: 6),
          _HelpLanguageChip(
            label: hebrewLabel,
            selected: selected == HelpTranslationLanguage.he,
            onTap: onSelectHebrew,
          ),
        ],
      );
}

/// Small uppercase "Arabic translation" / "Hebrew translation" label, a
/// right-to-left content area, and a "Hide translation" toggle underneath —
/// the common frame every translated panel below uses.
class _HelpTranslationFrame extends StatelessWidget {
  final HelpTranslationLanguage language;
  final AppLocalizations l;
  final bool isDark;
  final VoidCallback onHide;
  final Widget child;

  const _HelpTranslationFrame({
    required this.language,
    required this.l,
    required this.isDark,
    required this.onHide,
    required this.child,
  });

  String get _label => language == HelpTranslationLanguage.ar
      ? l.get('arabic_translation')
      : l.get('hebrew_translation');

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white38 : const Color(0xFF9999BB),
                  letterSpacing: 0.4)),
          const SizedBox(height: 4),
          Directionality(textDirection: TextDirection.rtl, child: child),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: onHide,
            behavior: HitTestBehavior.opaque,
            child: Text(l.get('hide_translation'),
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _kHelpTranslateColor)),
          ),
        ],
      );
}

// ── Single-block translate action (About San3a general / role summary) ────

class HelpTranslateAction extends StatefulWidget {
  final Map<HelpTranslationLanguage, String> translations;
  final bool isDark;
  final String entryLabelKey;

  const HelpTranslateAction({
    super.key,
    required this.translations,
    required this.isDark,
    this.entryLabelKey = 'translate',
  });

  @override
  State<HelpTranslateAction> createState() => _HelpTranslateActionState();
}

class _HelpTranslateActionState extends State<HelpTranslateAction> {
  bool _open = false;
  HelpTranslationLanguage? _selected;

  void _hide() => setState(() {
        _open = false;
        _selected = null;
      });

  @override
  Widget build(BuildContext context) {
    if (widget.translations.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);

    if (!_open) {
      return _HelpTranslateEntryButton(
          label: l.get(widget.entryLabelKey),
          onTap: () => setState(() => _open = true));
    }

    final selected = _selected;
    final text = selected == null ? null : widget.translations[selected];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _HelpLanguageChoiceRow(
          label: l.get('translate_to'),
          arabicLabel: l.get('arabic'),
          hebrewLabel: l.get('hebrew'),
          selected: selected,
          onSelectArabic: () =>
              setState(() => _selected = HelpTranslationLanguage.ar),
          onSelectHebrew: () =>
              setState(() => _selected = HelpTranslationLanguage.he),
        ),
        if (selected != null && text != null) ...[
          const SizedBox(height: 8),
          _HelpTranslationFrame(
            language: selected,
            l: l,
            isDark: widget.isDark,
            onHide: _hide,
            child: Text(
              text,
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color:
                      widget.isDark ? Colors.white70 : const Color(0xFF2D2D4E)),
            ),
          ),
        ],
      ],
    );
  }
}

// ── How to Use translate action (steps + role summary, one logical unit) ──

class HelpHowToTranslateAction extends StatefulWidget {
  final Map<HelpTranslationLanguage, List<String>> stepsByLanguage;
  final Map<HelpTranslationLanguage, String> summaryByLanguage;
  final Color color;
  final bool isDark;

  const HelpHowToTranslateAction({
    super.key,
    required this.stepsByLanguage,
    required this.summaryByLanguage,
    required this.color,
    required this.isDark,
  });

  @override
  State<HelpHowToTranslateAction> createState() =>
      _HelpHowToTranslateActionState();
}

class _HelpHowToTranslateActionState extends State<HelpHowToTranslateAction> {
  bool _open = false;
  HelpTranslationLanguage? _selected;

  void _hide() => setState(() {
        _open = false;
        _selected = null;
      });

  @override
  Widget build(BuildContext context) {
    if (widget.stepsByLanguage.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);

    if (!_open) {
      return _HelpTranslateEntryButton(
          label: l.get('translate'), onTap: () => setState(() => _open = true));
    }

    final selected = _selected;
    final steps = selected == null ? null : widget.stepsByLanguage[selected];
    final summary =
        selected == null ? null : widget.summaryByLanguage[selected];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _HelpLanguageChoiceRow(
          label: l.get('translate_to'),
          arabicLabel: l.get('arabic'),
          hebrewLabel: l.get('hebrew'),
          selected: selected,
          onSelectArabic: () =>
              setState(() => _selected = HelpTranslationLanguage.ar),
          onSelectHebrew: () =>
              setState(() => _selected = HelpTranslationLanguage.he),
        ),
        if (selected != null && steps != null) ...[
          const SizedBox(height: 8),
          _HelpTranslationFrame(
            language: selected,
            l: l,
            isDark: widget.isDark,
            onHide: _hide,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: widget.color.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text('${i + 1}',
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: widget.color)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            steps[i],
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                fontWeight: FontWeight.w500,
                                color: widget.isDark
                                    ? Colors.white70
                                    : const Color(0xFF2D2D4E)),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (summary != null && summary.trim().isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          widget.color.withOpacity(widget.isDark ? 0.08 : 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: widget.color.withOpacity(0.2)),
                    ),
                    child: Text(
                      summary,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 12.5,
                          height: 1.5,
                          color: widget.isDark
                              ? Colors.white70
                              : const Color(0xFF2D2D4E)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── FAQ translate action (question + answer, one logical item) ───────────

class HelpFaqTranslateAction extends StatefulWidget {
  final Map<HelpTranslationLanguage, HelpFaqTranslation> translations;
  final bool isDark;

  const HelpFaqTranslateAction({
    super.key,
    required this.translations,
    required this.isDark,
  });

  @override
  State<HelpFaqTranslateAction> createState() => _HelpFaqTranslateActionState();
}

class _HelpFaqTranslateActionState extends State<HelpFaqTranslateAction> {
  bool _open = false;
  HelpTranslationLanguage? _selected;

  void _hide() => setState(() {
        _open = false;
        _selected = null;
      });

  @override
  Widget build(BuildContext context) {
    if (widget.translations.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);

    if (!_open) {
      return _HelpTranslateEntryButton(
          label: l.get('translate'), onTap: () => setState(() => _open = true));
    }

    final selected = _selected;
    final translation = selected == null ? null : widget.translations[selected];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _HelpLanguageChoiceRow(
          label: l.get('translate_to'),
          arabicLabel: l.get('arabic'),
          hebrewLabel: l.get('hebrew'),
          selected: selected,
          onSelectArabic: () =>
              setState(() => _selected = HelpTranslationLanguage.ar),
          onSelectHebrew: () =>
              setState(() => _selected = HelpTranslationLanguage.he),
        ),
        if (selected != null && translation != null) ...[
          const SizedBox(height: 8),
          _HelpTranslationFrame(
            language: selected,
            l: l,
            isDark: widget.isDark,
            onHide: _hide,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  translation.question,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: widget.isDark
                          ? Colors.white
                          : const Color(0xFF1A1A2E)),
                ),
                const SizedBox(height: 6),
                Text(
                  translation.answer,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: widget.isDark
                          ? Colors.white60
                          : const Color(0xFF4A4A6A)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
