// ─── AI Service Assistant Screen (Phase 2 — mock-backed) ───────────────────
// Flutter-only integration screen for the mock `analyzeServiceProblem`
// callable. Deliberately does not implement provider matching, provider
// cards, match percentage, profile navigation, New Order navigation, or any
// Firestore write — this phase only submits problem text and displays the
// structured mock result it gets back.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/models/models.dart'
    show UserModel, UserRole, ServiceModel;
import '../../../auth/presentation/providers/app_providers.dart'
    show categoryProvidersStreamProvider, authProvider, liveCurrentUserProvider;
import '../../../customer/presentation/screens/new_order_screen.dart';
import '../../../customer/presentation/screens/provider_profile_screen.dart';
import '../../../customer/presentation/theme/customer_design.dart';
import '../../../customer/presentation/widgets/customer_provider_card.dart';
import '../../data/ai_service_assistant_repository.dart' show AiFollowUpAnswer;
import '../../models/ai_service_analysis_result.dart';
import '../providers/ai_service_assistant_provider.dart';

const _nBg = Color(0xFFEEEEF5);
const _nDark = Color(0xFFBEBECF);
const _nLight = Colors.white;
const _accent = Color(0xFF7C3AED);

/// Maps a stable error code (local-validation or backend) plus an optional,
/// already-allow-listed [reason] to localized, user-facing copy. Never
/// interpolates the underlying exception/message, backend details, numeric
/// limits, or reset time — only fixed, pre-translated strings are ever shown.
///
/// [unknownFallbackKey] lets each call site choose its own generic copy for
/// an unrecognized/`internal`/`unknown` code — the initial-analysis card and
/// the refinement card have always used different generic messages, and this
/// mapper preserves that rather than forcing one shared string.
String _localizedAiErrorMessage(
  AppLocalizations l,
  String code, [
  String? reason,
  String unknownFallbackKey = 'something_went_wrong',
]) {
  switch (code) {
    case kAiErrorInputTooShort:
      return l.get('ai_assistant_error_input_too_short');
    case kAiErrorInputTooLong:
      return l.get('ai_assistant_error_input_too_long');
    case kAiErrorSessionMismatch:
      return l.get('ai_assistant_error_session_mismatch');
    case 'unauthenticated':
      return l.get('ai_assistant_error_unauthenticated');
    case 'invalid-argument':
      return l.get('ai_assistant_error_invalid_argument');
    case 'resource-exhausted':
      switch (reason) {
        case 'cooldown_active':
          return l.get('ai_assistant_error_cooldown');
        case 'user_daily_limit':
          return l.get('ai_assistant_error_user_daily_limit');
        case 'global_daily_limit':
          return l.get('ai_assistant_error_global_daily_limit');
        case 'provider_quota':
          return l.get('ai_assistant_error_provider_quota');
        default:
          return l.get('ai_assistant_error_unavailable');
      }
    case 'deadline-exceeded':
    case 'unavailable':
      return l.get('ai_assistant_error_unavailable');
    case 'invalid-response':
      return l.get('ai_assistant_error_invalid_response');
    case 'internal':
    case 'unknown':
    default:
      return l.get(unknownFallbackKey);
  }
}

/// Defense-in-depth guard, checked immediately before both the Analyze and
/// Refine network calls: compares the visible UserModel id this screen is
/// actually showing (same resolution the screen already uses for
/// `customerUser`/`customerCity`) against the real signed-in Firebase Auth
/// identity. A mismatch (or either side being null) means the browser's
/// shared Firebase Auth session changed — e.g. another tab signed into a
/// different account — and authProvider/liveCurrentUserProvider may not
/// have caught up yet; the callable must never be dispatched in that
/// window, since it would silently authenticate as whichever identity
/// FirebaseAuth.instance.currentUser now holds, not the one on screen.
bool _aiSessionUidMismatch(WidgetRef ref) {
  final visibleId = ref.read(liveCurrentUserProvider).valueOrNull?.id ??
      ref.read(authProvider)?.id;
  final realUid = FirebaseAuth.instance.currentUser?.uid;
  return visibleId == null || realUid == null || visibleId != realUid;
}

class AiServiceAssistantScreen extends ConsumerStatefulWidget {
  const AiServiceAssistantScreen({super.key});

  @override
  ConsumerState<AiServiceAssistantScreen> createState() =>
      _AiServiceAssistantScreenState();
}

String _formatBudgetAmount(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toString();

class _AiServiceAssistantScreenState
    extends ConsumerState<AiServiceAssistantScreen> {
  late final TextEditingController _textCtrl;
  // Phase 1 preference-form controllers — created once here and reused for
  // the lifetime of this screen (never recreated on Riverpod rebuilds), same
  // pattern as [_textCtrl].
  late final TextEditingController _budgetCtrl;
  late final TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    // Restore whatever text is already in the controller's state (e.g. after
    // navigating back to this screen following an error) so nothing typed is
    // ever silently lost.
    final initial = ref.read(aiServiceAssistantControllerProvider);
    _textCtrl = TextEditingController(text: initial.problemText);
    _budgetCtrl = TextEditingController(
      text: initial.specificBudgetAmount != null
          ? _formatBudgetAmount(initial.specificBudgetAmount!)
          : '',
    );
    _notesCtrl = TextEditingController(text: initial.additionalNotes);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _budgetCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    // No automatic call happens on open — this is the only place analyze()
    // is invoked, and only on an explicit tap.
    FocusScope.of(context).unfocus();
    final notifier = ref.read(aiServiceAssistantControllerProvider.notifier);
    if (_aiSessionUidMismatch(ref)) {
      notifier.rejectAnalyzeSessionMismatch();
      return;
    }
    notifier.analyze(_textCtrl.text);
  }

  void _onBudgetPreferenceChanged(AiBudgetPreference preference) {
    final notifier = ref.read(aiServiceAssistantControllerProvider.notifier);
    notifier.setBudgetPreference(preference);
    if (preference == AiBudgetPreference.anyBudget) {
      _budgetCtrl.clear();
    }
  }

  void _onBudgetAmountChanged(String text) {
    final parsed = double.tryParse(text.trim());
    final valid = parsed != null && parsed.isFinite && parsed > 0;
    ref
        .read(aiServiceAssistantControllerProvider.notifier)
        .setSpecificBudgetAmount(valid ? parsed : null);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(aiServiceAssistantControllerProvider);

    final customerUser = ref.watch(liveCurrentUserProvider).valueOrNull ??
        ref.watch(authProvider);
    final customerCity = (customerUser?.city ?? '').trim();
    final cityAvailable = customerCity.isNotEmpty;

    final trimmedProblemLength = _textCtrl.text.trim().length;
    final problemValid = trimmedProblemLength >= kAiProblemTextMinLength &&
        trimmedProblemLength <= kAiProblemTextMaxLength;
    final budgetAmount = state.specificBudgetAmount;
    final budgetInvalid = state.budgetPreference ==
            AiBudgetPreference.specificBudget &&
        !(budgetAmount != null && budgetAmount.isFinite && budgetAmount > 0);
    final canAnalyze = problemValid && !budgetInvalid && !state.isLoading;

    return Scaffold(
      backgroundColor: _nBg,
      appBar: AppBar(
        backgroundColor: CustomerColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        // Explicit icon/title colors — the app's global AppBarTheme sets a
        // dark titleTextStyle/iconTheme that would otherwise win over
        // foregroundColor and render the back arrow and title invisible
        // against this dark-blue background.
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 17,
        ),
        title: Text(l.get('ai_assistant_title')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.get('ai_assistant_intro'),
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B6B85),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              _SectionLabel(l.get('ai_assistant_problem_label')),
              const SizedBox(height: 8),
              _ProblemTextField(
                controller: _textCtrl,
                hint: l.get('ai_assistant_problem_hint'),
                enabled: !state.isLoading,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              _ProviderPreferenceSection(
                l: l,
                state: state,
                enabled: !state.isLoading,
                onSelect: (pref) => ref
                    .read(aiServiceAssistantControllerProvider.notifier)
                    .setProviderPreference(pref),
              ),
              const SizedBox(height: 20),
              _LocationPreferenceSection(
                l: l,
                state: state,
                enabled: !state.isLoading,
                cityAvailable: cityAvailable,
                onSelect: (pref) => ref
                    .read(aiServiceAssistantControllerProvider.notifier)
                    .setLocationPreference(pref),
              ),
              const SizedBox(height: 20),
              _BudgetPreferenceSection(
                l: l,
                state: state,
                enabled: !state.isLoading,
                budgetInvalid: budgetInvalid,
                budgetCtrl: _budgetCtrl,
                onSelect: _onBudgetPreferenceChanged,
                onAmountChanged: _onBudgetAmountChanged,
              ),
              const SizedBox(height: 20),
              _AdditionalNotesSection(
                l: l,
                enabled: !state.isLoading,
                notesCtrl: _notesCtrl,
                onChanged: (text) => ref
                    .read(aiServiceAssistantControllerProvider.notifier)
                    .setAdditionalNotes(text),
              ),
              const SizedBox(height: 20),
              _AnalyzeButton(
                loading: state.isLoading,
                enabled: canAnalyze,
                label: l.get('ai_assistant_analyze'),
                loadingLabel: l.get('ai_assistant_analyzing'),
                onTap: _submit,
              ),
              if (state.errorCode != null) ...[
                const SizedBox(height: 16),
                _ErrorCard(
                  message: _localizedAiErrorMessage(
                      l, state.errorCode!, state.errorReason),
                  retryLabel: l.get('ai_assistant_retry'),
                  // user_daily_limit/global_daily_limit are non-retryable —
                  // waiting or tapping Retry cannot succeed before the quota
                  // resets, so the action is hidden entirely rather than
                  // merely disabled (unlike the isLoading/!canAnalyze cases
                  // below, which stay visible-but-disabled since retrying
                  // becomes possible again without waiting on a quota).
                  showRetry: state.errorReason != 'user_daily_limit' &&
                      state.errorReason != 'global_daily_limit',
                  onRetry: (state.isLoading || !canAnalyze) ? null : _submit,
                ),
              ],
              if (state.result != null) ...[
                const SizedBox(height: 20),
                _ResultView(
                  result: state.result!,
                  l: l,
                  providerPreference: state.providerPreference,
                  locationPreference: state.locationPreference,
                  customerCity: customerCity,
                  budgetPreference: state.budgetPreference,
                  specificBudgetAmount: state.specificBudgetAmount,
                  additionalNotes: state.additionalNotes,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Section label (mirrors the Neo section-label pattern used elsewhere) ──
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 4,
          height: 15,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_accent, Color(0xFF4C1D95)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF444466),
            letterSpacing: 1.2,
          ),
        ),
      ]);
}

// ─── Neo card wrapper (reused visual language from provider/order screens) ─
class _NeoCard extends StatelessWidget {
  final Widget child;
  const _NeoCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: _nBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: _nDark, blurRadius: 0, offset: Offset(0, 5)),
            BoxShadow(color: _nDark, blurRadius: 14, offset: Offset(6, 6)),
            BoxShadow(color: _nLight, blurRadius: 14, offset: Offset(-6, -6)),
          ],
        ),
        child: child,
      );
}

// ─── Problem text field with a built-in, always-visible character counter ──
class _ProblemTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  const _ProblemTextField({
    required this.controller,
    required this.hint,
    required this.enabled,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => _NeoCard(
        child: TextField(
          controller: controller,
          enabled: enabled,
          onChanged: onChanged,
          maxLines: 6,
          maxLength: kAiProblemTextMaxLength,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF22224A),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9999BB), fontSize: 13),
            filled: true,
            fillColor: _nBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: _accent, width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      );
}

// ─── Analyze button — disabled + spinner while loading ─────────────────────
class _AnalyzeButton extends StatelessWidget {
  final bool loading;
  // Whether the button may be tapped at all right now (separate from
  // [loading]): false while the problem text fails local validation or a
  // selected specific budget amount is invalid.
  final bool enabled;
  final String label;
  final String loadingLabel;
  final VoidCallback onTap;
  const _AnalyzeButton({
    required this.loading,
    required this.enabled,
    required this.label,
    required this.loadingLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tappable = !loading && enabled;
    return GestureDetector(
      onTap: tappable ? onTap : null,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: tappable
                ? [const Color(0xFF052659), const Color(0xFF0A3D7A)]
                : [const Color(0xFF7A88A0), const Color(0xFF5C6B85)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
                color: Color(0xFF021024), blurRadius: 0, offset: Offset(0, 5)),
            BoxShadow(
                color: Color(0x66052659), blurRadius: 14, offset: Offset(0, 8)),
          ],
        ),
        child: Center(
          child: loading
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(loadingLabel,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800)),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─── Phase 1 — Customer preference form (local, compact, chip-style) ───────
// Local-only widgets: no shared component (ProviderCard, etc.) is modified.
// None of these preferences are ever sent to the repository/backend/Gemini —
// see AiServiceAssistantState/Controller in ai_service_assistant_provider.dart.

/// A compact single-select chip. Purely local to this screen — does not
/// touch shared_widgets.dart.
class _PreferenceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;
  const _PreferenceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final tappable = enabled && onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        onTap: tappable ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? _accent : _nBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: selected
                ? null
                : const [
                    BoxShadow(
                        color: _nDark, blurRadius: 0, offset: Offset(0, 3)),
                    BoxShadow(
                        color: _nDark, blurRadius: 5, offset: Offset(3, 3)),
                    BoxShadow(
                        color: _nLight, blurRadius: 5, offset: Offset(-3, -3)),
                  ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFF22224A),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProviderPreferenceSection extends StatelessWidget {
  final AppLocalizations l;
  final AiServiceAssistantState state;
  final bool enabled;
  final ValueChanged<AiProviderPreference> onSelect;
  const _ProviderPreferenceSection({
    required this.l,
    required this.state,
    required this.enabled,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(l.get('ai_assistant_provider_preference')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _PreferenceChip(
              label: l.get('ai_assistant_provider_both'),
              selected: state.providerPreference == AiProviderPreference.both,
              enabled: enabled,
              onTap: () => onSelect(AiProviderPreference.both),
            ),
            _PreferenceChip(
              label: l.get('ai_assistant_provider_professional'),
              selected:
                  state.providerPreference == AiProviderPreference.professional,
              enabled: enabled,
              onTap: () => onSelect(AiProviderPreference.professional),
            ),
            _PreferenceChip(
              label: l.get('ai_assistant_provider_contractor'),
              selected:
                  state.providerPreference == AiProviderPreference.contractor,
              enabled: enabled,
              onTap: () => onSelect(AiProviderPreference.contractor),
            ),
          ],
        ),
      ],
    );
  }
}

class _LocationPreferenceSection extends StatelessWidget {
  final AppLocalizations l;
  final AiServiceAssistantState state;
  final bool enabled;
  final bool cityAvailable;
  final ValueChanged<AiLocationPreference> onSelect;
  const _LocationPreferenceSection({
    required this.l,
    required this.state,
    required this.enabled,
    required this.cityAvailable,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final sameCityEnabled = enabled && cityAvailable;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(l.get('ai_assistant_location_preference')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _PreferenceChip(
              label: l.get('ai_assistant_location_any'),
              selected:
                  state.locationPreference == AiLocationPreference.anyCity,
              enabled: enabled,
              onTap: () => onSelect(AiLocationPreference.anyCity),
            ),
            _PreferenceChip(
              label: l.get('ai_assistant_location_same_city'),
              selected:
                  state.locationPreference == AiLocationPreference.sameCity,
              enabled: sameCityEnabled,
              onTap: sameCityEnabled
                  ? () => onSelect(AiLocationPreference.sameCity)
                  : null,
            ),
          ],
        ),
        if (!cityAvailable) ...[
          const SizedBox(height: 6),
          Text(
            l.get('ai_assistant_location_city_missing'),
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF9999BB)),
          ),
        ],
      ],
    );
  }
}

class _BudgetPreferenceSection extends StatelessWidget {
  final AppLocalizations l;
  final AiServiceAssistantState state;
  final bool enabled;
  final bool budgetInvalid;
  final TextEditingController budgetCtrl;
  final ValueChanged<AiBudgetPreference> onSelect;
  final ValueChanged<String> onAmountChanged;
  const _BudgetPreferenceSection({
    required this.l,
    required this.state,
    required this.enabled,
    required this.budgetInvalid,
    required this.budgetCtrl,
    required this.onSelect,
    required this.onAmountChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSpecific =
        state.budgetPreference == AiBudgetPreference.specificBudget;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(l.get('ai_assistant_budget_preference')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _PreferenceChip(
              label: l.get('ai_assistant_budget_any'),
              selected: state.budgetPreference == AiBudgetPreference.anyBudget,
              enabled: enabled,
              onTap: () => onSelect(AiBudgetPreference.anyBudget),
            ),
            _PreferenceChip(
              label: l.get('ai_assistant_budget_specific'),
              selected: isSpecific,
              enabled: enabled,
              onTap: () => onSelect(AiBudgetPreference.specificBudget),
            ),
          ],
        ),
        if (isSpecific) ...[
          const SizedBox(height: 10),
          _NeoCard(
            child: TextField(
              controller: budgetCtrl,
              enabled: enabled,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              onChanged: onAmountChanged,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF22224A),
              ),
              decoration: InputDecoration(
                hintText: l.get('ai_assistant_budget_amount'),
                hintStyle:
                    const TextStyle(color: Color(0xFF9999BB), fontSize: 13),
                filled: true,
                fillColor: _nBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: _accent, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          if (budgetInvalid) ...[
            const SizedBox(height: 6),
            Text(
              l.get('ai_assistant_budget_invalid'),
              style: const TextStyle(fontSize: 11.5, color: Color(0xFFDC2626)),
            ),
          ],
        ],
      ],
    );
  }
}

class _AdditionalNotesSection extends StatelessWidget {
  final AppLocalizations l;
  final bool enabled;
  final TextEditingController notesCtrl;
  final ValueChanged<String> onChanged;
  const _AdditionalNotesSection({
    required this.l,
    required this.enabled,
    required this.notesCtrl,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(l.get('ai_assistant_additional_notes')),
        const SizedBox(height: 8),
        _NeoCard(
          child: TextField(
            controller: notesCtrl,
            enabled: enabled,
            onChanged: onChanged,
            maxLines: 3,
            maxLength: kAiAdditionalNotesMaxLength,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF22224A),
            ),
            decoration: InputDecoration(
              hintText: l.get('ai_assistant_additional_notes_hint'),
              hintStyle:
                  const TextStyle(color: Color(0xFF9999BB), fontSize: 13),
              filled: true,
              fillColor: _nBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: _accent, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Controlled error card with a retry action ──────────────────────────────
class _ErrorCard extends StatelessWidget {
  final String message;
  final String retryLabel;
  final VoidCallback? onRetry;
  // When false, the Retry action is omitted entirely (not merely disabled)
  // — used for non-retryable errors such as the daily quota being reached,
  // where no amount of tapping or waiting a moment can change the outcome.
  final bool showRetry;
  const _ErrorCard({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
    this.showRetry = true,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFECDD3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Color(0xFFDC2626), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF991B1B),
                  height: 1.4,
                ),
              ),
            ),
            if (showRetry) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onRetry,
                child: Text(
                  retryLabel,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFDC2626),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
}

// ─── Result view ────────────────────────────────────────────────────────────
// Stateful (Phase 5) so the selected Matching Provider — local UI state only,
// never added to AiServiceAssistantState — survives ordinary rebuilds while
// this result is on screen, and is cleared whenever a new/refined result
// replaces it or the selection is no longer part of the currently visible
// eligible top-provider list.
class _ResultView extends StatefulWidget {
  final AiServiceAnalysisResult result;
  final AppLocalizations l;
  final AiProviderPreference providerPreference;
  final AiLocationPreference locationPreference;
  final String customerCity;
  final AiBudgetPreference budgetPreference;
  final double? specificBudgetAmount;
  final String additionalNotes;
  const _ResultView({
    required this.result,
    required this.l,
    required this.providerPreference,
    required this.locationPreference,
    required this.customerCity,
    required this.budgetPreference,
    required this.specificBudgetAmount,
    required this.additionalNotes,
  });

  @override
  State<_ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<_ResultView> {
  UserModel? _selectedProvider;
  bool _navigating = false;
  bool _clearSelectionScheduled = false;

  // A refined result is always a freshly parsed AiServiceAnalysisResult
  // instance (see AiServiceAnalysisResult.fromMap), so identity is a safe,
  // cheap way to detect "this is a new/refined result" without giving the
  // model an equality override it doesn't otherwise need.
  @override
  void didUpdateWidget(covariant _ResultView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.result, widget.result)) {
      _selectedProvider = null;
      _navigating = false;
    }
  }

  void _onSelectProvider(UserModel provider) {
    setState(() {
      _selectedProvider =
          _selectedProvider?.id == provider.id ? null : provider;
    });
  }

  // Called (synchronously, during build) by _SuggestedProvidersSection each
  // time it computes a fresh visible top-provider list. Never calls setState
  // directly here — only schedules a guarded post-frame callback, so this is
  // safe to invoke from a descendant's build method.
  void _onVisibleProvidersChanged(List<UserModel> visible) {
    final selected = _selectedProvider;
    if (selected == null) return;
    if (visible.any((p) => p.id == selected.id)) return;
    if (_clearSelectionScheduled) return;
    _clearSelectionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _clearSelectionScheduled = false;
      if (!mounted) return;
      if (_selectedProvider != null && _selectedProvider!.id == selected.id) {
        setState(() => _selectedProvider = null);
      }
    });
  }

  // Starts from the AI's organized description, then appends the Customer's
  // additional notes as a clearly labeled, blank-line-separated section.
  // Specific budget is used only for Matching Providers ranking (see
  // _SuggestedProvidersSection) and is never appended here. Never appends
  // provider/location preference, city, UID, provider role, categoryReason,
  // keywords, or follow-up Q&A.
  String _composeDescription(AppLocalizations l) {
    final parts = <String>[widget.result.description.trim()];

    final notes = widget.additionalNotes.trim();
    if (notes.isNotEmpty) {
      parts.add('${l.get('ai_assistant_additional_notes')}: $notes');
    }

    return parts.join('\n\n');
  }

  // Only ever navigates to the existing NewOrderScreen — never writes to
  // Firestore, never creates an Order, never calls Gemini. Order creation
  // remains exclusively NewOrderScreen's existing submit action.
  void _onCreateServiceRequest(BuildContext context, AppLocalizations l) {
    final provider = _selectedProvider;
    if (provider == null || _navigating) return;
    setState(() => _navigating = true);
    final description = _composeDescription(l);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewOrderScreen(
          provider: provider,
          categoryId: widget.result.suggestedCategoryId,
          categoryNameKey: widget.result.suggestedCategoryNameKey,
          initialTitle: widget.result.title,
          initialDescription: description,
          matchedCategoryId: widget.result.suggestedCategoryId,
        ),
      ),
    ).then((_) {
      if (mounted) setState(() => _navigating = false);
    });
  }

  Widget _buildCreateServiceRequestButton(
      BuildContext context, AppLocalizations l) {
    final enabled = _selectedProvider != null && !_navigating;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: enabled ? () => _onCreateServiceRequest(context, l) : null,
          child: Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: enabled
                    ? [_accent, const Color(0xFF4C1D95)]
                    : [const Color(0xFFB9B9CC), const Color(0xFFA0A0B8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                l.get('ai_assistant_create_service_request'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        if (_selectedProvider == null) ...[
          const SizedBox(height: 8),
          Text(
            l.get('ai_assistant_select_provider_to_continue'),
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF9999BB)),
          ),
        ],
      ],
    );
  }

  // suggestedProviderRole and priority are intentionally never surfaced in
  // the main visible result in this phase; title/description remain
  // unchanged on [widget.result] and are only used for the Create Service
  // Request prefill above.
  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    final result = widget.result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (result.isMock) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: [
                const Icon(Icons.science_outlined,
                    color: Color(0xFFB45309), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${l.get('ai_assistant_mock_result')} — '
                    '${l.get('ai_assistant_mock_result_hint')}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        _CategorySummaryCard(result: result, l: l),
        if (result.structuredFollowUpQuestions.isNotEmpty) ...[
          const SizedBox(height: 16),
          _FollowUpRefinementSection(result: result, l: l),
        ],
        const SizedBox(height: 20),
        _SuggestedProvidersSection(
          result: result,
          l: l,
          providerPreference: widget.providerPreference,
          locationPreference: widget.locationPreference,
          customerCity: widget.customerCity,
          budgetPreference: widget.budgetPreference,
          specificBudgetAmount: widget.specificBudgetAmount,
          selectedProviderId: _selectedProvider?.id,
          onSelectProvider: _onSelectProvider,
          onVisibleProvidersChanged: _onVisibleProvidersChanged,
        ),
        if (result.keywords.isNotEmpty) ...[
          const SizedBox(height: 20),
          _MoreDetailsSection(keywords: result.keywords, l: l),
        ],
        const SizedBox(height: 20),
        _buildCreateServiceRequestButton(context, l),
      ],
    );
  }
}

// ─── Category summary card ──────────────────────────────────────────────────
// Replaces the old separate Suggested Title / Description / Category /
// Priority fields with one compact Customer-facing summary: the suggested
// Category name plus categoryReason directly below it. Neither field has a
// line/character cap here — categoryReason wraps naturally up to the
// backend's 300-character limit and is never truncated.
class _CategorySummaryCard extends StatelessWidget {
  final AiServiceAnalysisResult result;
  final AppLocalizations l;
  const _CategorySummaryCard({required this.result, required this.l});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(l.get('ai_assistant_suggested_category')),
        const SizedBox(height: 8),
        _NeoCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.suggestedCategoryName,
                  softWrap: true,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF22224A),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l.get('ai_assistant_why_category'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _accent,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  result.categoryReason,
                  softWrap: true,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B6B85),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── More details (collapsed Keywords) ──────────────────────────────────────
// Collapsed by default; only rendered by the caller when result.keywords is
// non-empty. Uses a local Theme override to drop ExpansionTile's default
// divider lines, which otherwise conflict with the Neo card's own border/
// shadow styling — this does not touch the app's global theme.
class _MoreDetailsSection extends StatelessWidget {
  final List<String> keywords;
  final AppLocalizations l;
  const _MoreDetailsSection({required this.keywords, required this.l});

  @override
  Widget build(BuildContext context) {
    return _NeoCard(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          maintainState: true,
          initiallyExpanded: false,
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
          iconColor: _accent,
          collapsedIconColor: _accent,
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            l.get('ai_assistant_more_details'),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF444466),
              letterSpacing: 1.0,
            ),
          ),
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: keywords.map((k) => _KeywordChip(k)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Follow-up Refinement section ───────────────────────────────────────────
// Renders the *current* result's structured follow-up questions
// (structuredFollowUpQuestions — the legacy string array is never used here,
// only for the model's own bridge consistency check) either as an editable
// answer form (before any refinement attempt, and while one is in flight or
// has just failed) or as the original read-only list (once a refinement has
// succeeded — the refined result's own follow-up questions are shown
// read-only because a second refinement is never allowed in this phase).
// A TextEditingController is created once per freeText question only, and a
// nullable selected-option slot per singleChoice question — both created
// once in [initState] and reused for the lifetime of this widget, so
// selections/typed answers survive every ordinary Riverpod rebuild,
// including a failed refinement attempt.
class _FollowUpRefinementSection extends ConsumerStatefulWidget {
  final AiServiceAnalysisResult result;
  final AppLocalizations l;
  const _FollowUpRefinementSection({required this.result, required this.l});

  @override
  ConsumerState<_FollowUpRefinementSection> createState() =>
      _FollowUpRefinementSectionState();
}

class _FollowUpRefinementSectionState
    extends ConsumerState<_FollowUpRefinementSection> {
  late final List<String?> _selectedChoices;
  late final Map<int, TextEditingController> _freeTextControllers;

  @override
  void initState() {
    super.initState();
    final questions = widget.result.structuredFollowUpQuestions;
    _selectedChoices = List<String?>.filled(questions.length, null);
    _freeTextControllers = {
      for (var i = 0; i < questions.length; i++)
        if (questions[i].answerType == AiFollowUpAnswerType.freeText)
          i: TextEditingController(),
    };
  }

  @override
  void dispose() {
    for (final controller in _freeTextControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _isAnswered(int i, AiFollowUpQuestion question) {
    if (question.answerType == AiFollowUpAnswerType.singleChoice) {
      return _selectedChoices[i] != null;
    }
    final trimmed = _freeTextControllers[i]!.text.trim();
    return trimmed.isNotEmpty && trimmed.length <= kAiFollowUpAnswerMaxLength;
  }

  bool get _allAnswered {
    final questions = widget.result.structuredFollowUpQuestions;
    for (var i = 0; i < questions.length; i++) {
      if (!_isAnswered(i, questions[i])) return false;
    }
    return true;
  }

  void _submit(AiServiceAssistantState state) {
    // Mirrors the same guards as AiServiceAssistantController.refine() so a
    // stray tap right at a state transition can never fire a second request
    // — the controller itself is the final source of truth either way.
    if (state.isLoading || state.isRefining || state.hasRefinementAttempted) {
      return;
    }
    if (!_allAnswered) return;

    final notifier = ref.read(aiServiceAssistantControllerProvider.notifier);
    if (_aiSessionUidMismatch(ref)) {
      notifier.rejectRefineSessionMismatch();
      return;
    }

    final questions = widget.result.structuredFollowUpQuestions;
    final answers = List.generate(questions.length, (i) {
      final question = questions[i];
      if (question.answerType == AiFollowUpAnswerType.singleChoice) {
        return AiFollowUpAnswer(
          question: question.question,
          answer: _selectedChoices[i]!,
          answerType: question.answerType,
          options: question.options,
        );
      }
      return AiFollowUpAnswer(
        question: question.question,
        answer: _freeTextControllers[i]!.text,
        answerType: question.answerType,
        options: const [],
      );
    });
    FocusScope.of(context).unfocus();
    notifier.refine(answers);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiServiceAssistantControllerProvider);
    final questions = widget.result.structuredFollowUpQuestions;
    if (questions.isEmpty) return const SizedBox.shrink();

    final refinementSucceeded = state.hasRefinementAttempted &&
        !state.isRefining &&
        state.refinementErrorCode == null;

    if (refinementSucceeded) {
      // A refinement just succeeded — the whole Follow-up Questions section
      // (including the refined result's own new questions) is hidden rather
      // than shown read-only, since a second refinement is never offered in
      // this phase.
      return const SizedBox.shrink();
    }

    final fieldsEnabled = !state.isRefining && !state.hasRefinementAttempted;
    final canSubmit = fieldsEnabled && _allAnswered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(widget.l.get('ai_assistant_follow_up_questions')),
        const SizedBox(height: 8),
        _NeoCard(
          child: Column(
            children: List.generate(questions.length, (i) {
              final isLast = i == questions.length - 1;
              final question = questions[i];
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.help_outline_rounded,
                            size: 16, color: _accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            question.question,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF22224A),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: question.answerType ==
                            AiFollowUpAnswerType.singleChoice
                        ? _SingleChoiceAnswerInput(
                            options: question.options,
                            selected: _selectedChoices[i],
                            enabled: fieldsEnabled,
                            hintLabel:
                                widget.l.get('ai_assistant_select_an_answer'),
                            onSelect: (option) => setState(() {
                              _selectedChoices[i] = option;
                            }),
                          )
                        : TextField(
                            controller: _freeTextControllers[i],
                            enabled: fieldsEnabled,
                            maxLines: 3,
                            maxLength: kAiFollowUpAnswerMaxLength,
                            maxLengthEnforcement: MaxLengthEnforcement.enforced,
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF22224A),
                            ),
                            decoration: InputDecoration(
                              hintText: widget.l
                                  .get('ai_assistant_refinement_answer_label'),
                              hintStyle: const TextStyle(
                                color: Color(0xFF9999BB),
                                fontSize: 12.5,
                              ),
                              filled: true,
                              fillColor: _nBg,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: _accent, width: 1.2),
                              ),
                              contentPadding: const EdgeInsets.all(12),
                            ),
                          ),
                  ),
                  if (!isLast)
                    Container(
                      height: 1,
                      margin: const EdgeInsets.only(left: 16, right: 16),
                      color: _nDark.withOpacity(0.4),
                    ),
                ],
              );
            }),
          ),
        ),
        if (fieldsEnabled && !_allAnswered) ...[
          const SizedBox(height: 8),
          Text(
            widget.l.get('ai_assistant_refinement_incomplete'),
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF9999BB)),
          ),
        ],
        if (state.refinementErrorCode != null) ...[
          const SizedBox(height: 12),
          _RefinementErrorCard(
            message: _localizedAiErrorMessage(
              widget.l,
              state.refinementErrorCode!,
              state.refinementErrorReason,
              'ai_assistant_refinement_error',
            ),
          ),
        ],
        const SizedBox(height: 12),
        _RefineButton(
          enabled: canSubmit,
          refining: state.isRefining,
          label: widget.l.get('ai_assistant_refine_analysis'),
          refiningLabel: widget.l.get('ai_assistant_refining'),
          onTap: () => _submit(state),
        ),
      ],
    );
  }
}

// ─── singleChoice answer input — touch chips, exactly one selected ────────
// Local, purely presentational: reuses the existing local _PreferenceChip
// (already used for the provider/location/budget preference chips above)
// inside a Wrap so options reflow on narrow width instead of overflowing.
// Rendering depends only on answerType — never on question wording.
class _SingleChoiceAnswerInput extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final bool enabled;
  final String hintLabel;
  final ValueChanged<String> onSelect;
  const _SingleChoiceAnswerInput({
    required this.options,
    required this.selected,
    required this.enabled,
    required this.hintLabel,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selected == null) ...[
          Text(
            hintLabel,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF9999BB)),
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options
              .map(
                (option) => _PreferenceChip(
                  label: option,
                  selected: selected == option,
                  enabled: enabled,
                  onTap: enabled ? () => onSelect(option) : null,
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

// ─── Refine Analysis button — disabled + spinner while refining ────────────
class _RefineButton extends StatelessWidget {
  final bool enabled;
  final bool refining;
  final String label;
  final String refiningLabel;
  final VoidCallback onTap;
  const _RefineButton({
    required this.enabled,
    required this.refining,
    required this.label,
    required this.refiningLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: enabled
                  ? [_accent, const Color(0xFF4C1D95)]
                  : [const Color(0xFFB9B9CC), const Color(0xFFA0A0B8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: refining
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(refiningLabel,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800)),
                    ],
                  )
                : Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
          ),
        ),
      );
}

// ─── Compact inline refinement error — never echoes backend/Gemini detail ──
class _RefinementErrorCard extends StatelessWidget {
  final String message;
  const _RefinementErrorCard({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFECDD3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Color(0xFFDC2626), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF991B1B),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
}

// ─── Suggested Providers section ────────────────────────────────────────────
// Client-side only: reuses categoryProvidersStreamProvider — the exact same
// provider CategoryProvidersScreen already reads — keyed off the AI's
// suggested category. suggestedProviderRole is never read here: Professional
// and Contractor accounts are both fully and equally eligible, since a
// Contractor represents a coordinated team rather than a competing role.
class _SuggestedProvidersSection extends ConsumerWidget {
  final AiServiceAnalysisResult result;
  final AppLocalizations l;
  // Customer's explicit provider-role and location preferences from the
  // Phase 1 form, plus the current Customer's own city — passed in as plain
  // values rather than read from Riverpod here, since the caller already has
  // them and this keeps the section a pure function of its inputs.
  final AiProviderPreference providerPreference;
  final AiLocationPreference locationPreference;
  final String customerCity;
  // Phase 2 (AI Budget Matching) — Customer's budget preference from the
  // Phase 1 form, passed in as plain values rather than read from Riverpod
  // here, same as providerPreference/locationPreference/customerCity above.
  // Used only to rank already-eligible providers below; never sent to
  // Gemini/the backend and never used as an eligibility filter.
  final AiBudgetPreference budgetPreference;
  final double? specificBudgetAmount;
  // Phase 5 — provider selection: local UI state owned by _ResultViewState,
  // passed in as plain values/callbacks rather than read from Riverpod here.
  final String? selectedProviderId;
  final ValueChanged<UserModel> onSelectProvider;
  // Invoked with the freshly computed visible top-provider list every time
  // the stream emits data, so the owner can clear an out-of-view selection.
  final ValueChanged<List<UserModel>> onVisibleProvidersChanged;
  const _SuggestedProvidersSection({
    required this.result,
    required this.l,
    required this.providerPreference,
    required this.locationPreference,
    required this.customerCity,
    required this.budgetPreference,
    required this.specificBudgetAmount,
    required this.selectedProviderId,
    required this.onSelectProvider,
    required this.onVisibleProvidersChanged,
  });

  bool _isEligible(UserModel p) =>
      p.id.trim().isNotEmpty &&
      !p.isDeleted &&
      !p.isBlocked &&
      !p.isActivelySuspended &&
      (p.role == UserRole.professional || p.role == UserRole.contractor);

  bool _matchesRolePreference(UserModel p) {
    switch (providerPreference) {
      case AiProviderPreference.both:
        return true;
      case AiProviderPreference.professional:
        return p.role == UserRole.professional;
      case AiProviderPreference.contractor:
        return p.role == UserRole.contractor;
    }
  }

  // Phase 2 (AI Budget Matching) — the smallest absolute distance between
  // the Customer's budget and one of this provider's own service prices,
  // considering only services reliably linked to the AI-suggested category:
  // service.categoryId must be non-null/non-empty and, trimmed+lowercased,
  // exactly equal result.suggestedCategoryId (also trimmed+lowercased); the
  // price must be finite and > 0. Never matches by service name or
  // description, never falls back to an unrelated/legacy (categoryId ==
  // null) service, and never guesses a category. Returns null when the
  // provider has no such service — the caller treats that provider as a
  // fallback result, never excluded.
  double? _budgetDistance(UserModel p, double budget) {
    final normSuggestedCategoryId =
        result.suggestedCategoryId.trim().toLowerCase();
    double? minDistance;
    for (final ServiceModel service in p.servicesList) {
      final categoryId = service.categoryId;
      if (categoryId == null) continue;
      final normCategoryId = categoryId.trim().toLowerCase();
      if (normCategoryId.isEmpty || normCategoryId != normSuggestedCategoryId) {
        continue;
      }
      final price = service.price;
      if (!price.isFinite || price <= 0) continue;
      final distance = (price - budget).abs();
      if (minDistance == null || distance < minDistance) {
        minDistance = distance;
      }
    }
    return minDistance;
  }

  // Deterministic: same-city priority (only when locationPreference is
  // sameCity and the Customer has a city) → when a valid Specific budget is
  // set, providers with a relevant linked-service price first, ranked by
  // smallest budget distance → rating desc → experienceYears desc (null as
  // 0) → fullName (case-insensitive) asc → id asc. Provider role is never a
  // sort key — Professional and Contractor stay equally ranked whenever
  // both remain eligible. Same-city and budget are ranking priorities, not
  // filters: other-city providers and providers without a relevant price
  // remain eligible fallback candidates.
  List<UserModel> _topEligible(List<UserModel> providers) {
    final eligible =
        providers.where(_isEligible).where(_matchesRolePreference).toList();

    final normalizedCustomerCity = customerCity.trim().toLowerCase();
    final effectiveLocationPreference = normalizedCustomerCity.isEmpty
        ? AiLocationPreference.anyCity
        : locationPreference;

    bool isSameCity(UserModel p) {
      final providerCity = p.city.trim().toLowerCase();
      return providerCity.isNotEmpty && providerCity == normalizedCustomerCity;
    }

    final budget = specificBudgetAmount;
    final budgetActive =
        budgetPreference == AiBudgetPreference.specificBudget &&
            budget != null &&
            budget.isFinite &&
            budget > 0;

    // Computed once per provider up front (never role-dependent) so the
    // comparator below never re-scans servicesList on every comparison.
    final Map<String, double?> distanceById = !budgetActive
        ? const {}
        : {for (final p in eligible) p.id: _budgetDistance(p, budget)};

    eligible.sort((a, b) {
      if (effectiveLocationPreference == AiLocationPreference.sameCity) {
        final aSameCity = isSameCity(a);
        final bSameCity = isSameCity(b);
        if (aSameCity != bSameCity) return aSameCity ? -1 : 1;
      }
      if (budgetActive) {
        final aDistance = distanceById[a.id];
        final bDistance = distanceById[b.id];
        final aHasPrice = aDistance != null;
        final bHasPrice = bDistance != null;
        if (aHasPrice != bHasPrice) return aHasPrice ? -1 : 1;
        if (aHasPrice && bHasPrice) {
          final byDistance = aDistance.compareTo(bDistance);
          if (byDistance != 0) return byDistance;
        }
      }
      final byRating = b.rating.compareTo(a.rating);
      if (byRating != 0) return byRating;
      final byExperience =
          (b.experienceYears ?? 0).compareTo(a.experienceYears ?? 0);
      if (byExperience != 0) return byExperience;
      final byName =
          a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
      if (byName != 0) return byName;
      return a.id.compareTo(b.id);
    });
    return eligible.take(3).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providersAsync = ref.watch(
      categoryProvidersStreamProvider(
        (result.suggestedCategoryNameKey, result.suggestedCategoryId),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(l.get('ai_assistant_matching_providers')),
        const SizedBox(height: 8),
        providersAsync.when(
          data: (providers) {
            final top = _topEligible(providers);
            // Reports the current visible list so the owner can clear a
            // selection that fell out of it (role preference change,
            // stream update, or the provider becoming ineligible) — this
            // only schedules a guarded post-frame callback on the receiving
            // end, so calling it here during build is safe.
            onVisibleProvidersChanged(top);
            if (top.isEmpty) {
              return _SuggestedProvidersMessage(
                text: providerPreference == AiProviderPreference.both
                    ? l.get('ai_assistant_suggested_providers_empty')
                    : l.get('ai_assistant_no_providers_matching_preferences'),
              );
            }
            return Column(
              children: top
                  .map(
                    (provider) => _SelectableProviderTile(
                      provider: provider,
                      isSelected: selectedProviderId == provider.id,
                      l: l,
                      onOpenProfile: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProviderProfileScreen(
                            provider: provider,
                            categoryId: result.suggestedCategoryId,
                            categoryNameKey: result.suggestedCategoryNameKey,
                          ),
                        ),
                      ),
                      onSelect: () => onSelectProvider(provider),
                    ),
                  )
                  .toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: _accent,
                ),
              ),
            ),
          ),
          error: (_, __) => _SuggestedProvidersMessage(
            text: l.get('ai_assistant_suggested_providers_error'),
          ),
        ),
      ],
    );
  }
}

class _SuggestedProvidersMessage extends StatelessWidget {
  final String text;
  const _SuggestedProvidersMessage({required this.text});

  @override
  Widget build(BuildContext context) => _NeoCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B6B85),
              height: 1.5,
            ),
          ),
        ),
      );
}

// ─── Selectable provider tile (Phase 5) ─────────────────────────────────────
// Wraps the shared ProviderCard, unmodified, purely with local markup: a
// purple border highlight when selected, and a small Select/Selected action
// below the card that is entirely separate from the card's own tap target —
// tapping the card still only opens ProviderProfileScreen; tapping Select
// only toggles local selection and never opens the profile.
class _SelectableProviderTile extends StatelessWidget {
  final UserModel provider;
  final bool isSelected;
  final AppLocalizations l;
  final VoidCallback onOpenProfile;
  final VoidCallback onSelect;
  const _SelectableProviderTile({
    required this.provider,
    required this.isSelected,
    required this.l,
    required this.onOpenProfile,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: isSelected ? Border.all(color: _accent, width: 2) : null,
      ),
      child: Column(
        children: [
          CustomerProviderCard(provider: provider, onTap: onOpenProfile),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: GestureDetector(
                onTap: onSelect,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? _accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _accent, width: 1.4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 15,
                        color: isSelected ? Colors.white : _accent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isSelected
                            ? l.get('ai_assistant_provider_selected')
                            : l.get('ai_assistant_select_provider'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.white : _accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeywordChip extends StatelessWidget {
  final String label;
  const _KeywordChip(this.label);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _nBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: _nDark, blurRadius: 0, offset: Offset(0, 3)),
            BoxShadow(color: _nDark, blurRadius: 5, offset: Offset(3, 3)),
            BoxShadow(color: _nLight, blurRadius: 5, offset: Offset(-3, -3)),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF22224A),
          ),
        ),
      );
}
