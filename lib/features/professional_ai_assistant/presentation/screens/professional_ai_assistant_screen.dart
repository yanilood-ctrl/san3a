// ─── Professional AI Job Assistant Screen ───────────────────────────────────
// First complete Flutter flow for the Professional AI Job Assistant: pick one
// of the Professional's own eligible (pending/in-progress) orders — grouped
// into a deterministic "Today's Order Plan" and a secondary "Other Eligible
// Orders" section (see professional_ai_daily_plan.dart for the pure
// sorting/proximity logic) — pick one message intent, call
// `analyzeProfessionalJob`, and show the validated result. The generated
// customer message can be copied to the clipboard, or used to open the real
// Professional Chat screen with that same text prefilled as an editable
// draft — in both cases nothing is ever sent automatically and no AI result
// is ever written to Firestore. The daily plan never calls Gemini and never
// stores anything — it is pure, re-derived UI presentation over the same
// live `OrderModel` stream.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../professional/presentation/theme/professional_design.dart';
import '../../../../shared/models/models.dart'
    show OrderModel, OrderStatus, OrderPriority, UserModel, UserRole;
import '../../../auth/presentation/providers/app_providers.dart'
    show professionalFirestoreOrdersProvider, conversationsProvider;
import '../../../professional/presentation/screens/professional_chat_screen.dart';
import '../../models/professional_ai_analysis_result.dart';
import '../../professional_ai_daily_plan.dart';
import '../providers/professional_ai_assistant_provider.dart';

String _responseLanguageLabel(
  AppLocalizations l,
  ProfessionalAiResponseLanguage language,
) {
  switch (language) {
    case ProfessionalAiResponseLanguage.english:
      return l.get('professional_ai_language_english');
    case ProfessionalAiResponseLanguage.arabic:
      return l.get('professional_ai_language_arabic');
    case ProfessionalAiResponseLanguage.hebrew:
      return l.get('professional_ai_language_hebrew');
  }
}

/// The smallest reusable helper for AI-generated-content direction: wraps
/// one piece of text returned by `analyzeProfessionalJob` (summary,
/// questions, toolsAndMaterials, suggestedSteps, safetyWarnings,
/// customerMessage) with explicit RTL/right-aligned presentation when
/// [isRtl] is true, else normal LTR. Never used for the app's own UI
/// labels, which stay English/LTR via a plain [Text] widget instead.
Widget _aiGeneratedText(String text, TextStyle style, bool isRtl) => Text(
      text,
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      textAlign: isRtl ? TextAlign.right : TextAlign.start,
      style: style,
    );

/// Wraps a non-list AI-generated paragraph (summary, customerMessage) in a
/// full-width box before handing it to [_aiGeneratedText]. Without this, the
/// surrounding Column's `crossAxisAlignment: CrossAxisAlignment.start` sizes
/// the Text to its own intrinsic (shrink-wrapped) width under the app's
/// ambient LTR Directionality, so an RTL paragraph's `textAlign: right` has
/// no free space to align into and the text still reads as pinned to the
/// left edge. Giving it `width: double.infinity` first gives the alignment
/// somewhere to go. Never used for `_aiListItemRow`'s text, which already
/// gets full width from its own `Expanded`.
Widget _aiGeneratedParagraph(String text, TextStyle style, bool isRtl) =>
    SizedBox(
      width: double.infinity,
      child: _aiGeneratedText(text, style, isRtl),
    );

/// Shared row layout for one AI-generated bullet-list item — [bullet] is
/// the leading marker widget, [text] the AI-generated line rendered via
/// [_aiGeneratedText]. Setting the [Row]'s own `textDirection` (rather than
/// reordering `children`) is what makes the bullet follow the text's
/// direction: with `textDirection: TextDirection.rtl`, Flutter mirrors the
/// child order itself — bullet on the right, text flowing from the right,
/// wrapped lines included — while English/LTR output keeps the original
/// order unchanged. Shared by every bullet-list AI section (Questions,
/// Tools and Materials, Suggested Steps, Safety Warnings) so the fix lives
/// in one place.
Widget _aiListItemRow(
        Widget bullet, String text, TextStyle style, bool isRtl) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bullet,
          const SizedBox(width: 8),
          Expanded(child: _aiGeneratedText(text, style, isRtl)),
        ],
      ),
    );

/// Maps a stable failure code (plus an optional, already-allow-listed
/// [reason]) to safe, fixed, localized copy. Never interpolates the
/// underlying exception/message, backend details, counts, or timestamps.
String _localizedProfessionalAiErrorMessage(
  AppLocalizations l,
  String code, [
  String? reason,
]) {
  switch (code) {
    case 'permission-denied':
      return reason == 'professional_only'
          ? l.get('professional_ai_error_professional_only')
          : l.get('professional_ai_error_unknown');
    case 'not-found':
      return reason == 'order_not_found'
          ? l.get('professional_ai_error_order_not_found')
          : l.get('professional_ai_error_unknown');
    case 'resource-exhausted':
      switch (reason) {
        case 'professional_ai_cooldown':
          return l.get('professional_ai_error_cooldown');
        case 'professional_ai_user_daily_limit':
          return l.get('professional_ai_error_user_daily_limit');
        case 'professional_ai_global_daily_limit':
          return l.get('professional_ai_error_global_daily_limit');
        case 'professional_ai_provider_quota':
          return l.get('professional_ai_error_provider_quota');
        default:
          return l.get('professional_ai_error_unavailable');
      }
    case 'deadline-exceeded':
    case 'unavailable':
    case 'internal':
      return l.get('professional_ai_error_unavailable');
    case 'invalid-response':
    case 'unauthenticated':
    case 'invalid-argument':
    case 'unknown':
    default:
      return l.get('professional_ai_error_unknown');
  }
}

String _statusLabel(OrderStatus s, AppLocalizations l) {
  switch (s) {
    case OrderStatus.pending:
      return l.get('pending');
    case OrderStatus.inProgress:
      return l.get('in_progress');
    case OrderStatus.completed:
      return l.get('completed');
    case OrderStatus.cancelled:
      return l.get('cancelled');
  }
}

Color _statusColor(OrderStatus s) {
  switch (s) {
    case OrderStatus.pending:
      return const Color(0xFFF59E0B);
    case OrderStatus.inProgress:
      return const Color(0xFF26A69A);
    case OrderStatus.completed:
      return const Color(0xFF22C55E);
    case OrderStatus.cancelled:
      return const Color(0xFFEF4444);
  }
}

/// A short, safe summary line for an order card: the selected services'
/// names when present, else the legacy single-service name, else the
/// category's localized label. Never includes price, ids, or customer data.
String _categoryOrServiceSummary(OrderModel order, AppLocalizations l) {
  if (order.selectedServices.isNotEmpty) {
    final names = order.selectedServices
        .map((s) => s.name.trim())
        .where((n) => n.isNotEmpty)
        .toList();
    if (names.isNotEmpty) {
      return names.length <= 2
          ? names.join(', ')
          : '${names.take(2).join(', ')} +${names.length - 2}';
    }
  }
  final legacyName = order.selectedServiceName?.trim();
  if (legacyName != null && legacyName.isNotEmpty) return legacyName;
  final categoryNameKey = order.categoryNameKey?.trim();
  if (categoryNameKey != null && categoryNameKey.isNotEmpty) {
    return l.translateSpecialty(categoryNameKey);
  }
  return '';
}

String _formatTime(DateTime d) {
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${pad(d.hour)}:${pad(d.minute)}';
}

/// Finds the order with [id] inside [orders], or null if none matches —
/// used to prove a previously-selected order id is still present in the
/// currently-loaded eligible-order list before allowing Open Chat to
/// navigate.
OrderModel? _findOrderById(List<OrderModel> orders, String id) {
  for (final order in orders) {
    if (order.id == id) return order;
  }
  return null;
}

/// Picks one of the four deterministic, code-generated ordering-reason
/// templates for `entries[index]`, using only real appointment time,
/// priority, status, and position — never Gemini, never invented duration,
/// never a "confirmed" claim.
///
/// - Position 1 (earliest appointment today) always gets the "earliest"
///   reason.
/// - Otherwise, if this entry shares its appointment minute with the very
///   next entry and is the reason it precedes it (urgent vs. normal, or —
///   when priority is tied — inProgress vs. pending), that specific reason
///   is shown.
/// - Every other case falls back to the generic "placed after earlier
///   appointments today" reason, which is always truthful regardless of the
///   exact tie-break that produced this order's position.
String _professionalAiOrderReason(
  AppLocalizations l,
  List<ProfessionalAiDailyPlanEntry> entries,
  int index,
) {
  if (index == 0) return l.get('professional_ai_reason_earliest');

  final current = entries[index].order;
  if (index < entries.length - 1) {
    final next = entries[index + 1].order;
    final sameMinute = current.serviceDate.year == next.serviceDate.year &&
        current.serviceDate.month == next.serviceDate.month &&
        current.serviceDate.day == next.serviceDate.day &&
        current.serviceDate.hour == next.serviceDate.hour &&
        current.serviceDate.minute == next.serviceDate.minute;
    if (sameMinute) {
      final currentUrgent = current.priority == OrderPriority.urgent;
      final nextUrgent = next.priority == OrderPriority.urgent;
      if (currentUrgent && !nextUrgent) {
        return l
            .get('professional_ai_reason_urgent')
            .replaceAll('{time}', _formatTime(current.serviceDate));
      }
      if (currentUrgent == nextUrgent &&
          current.status == OrderStatus.inProgress &&
          next.status != OrderStatus.inProgress) {
        return l.get('professional_ai_reason_in_progress');
      }
    }
  }
  return l.get('professional_ai_reason_after_earlier');
}

/// Screen-local section header — a small teal icon badge plus the label
/// text, mirroring the Professional Profile screen's own
/// `_ProfSectionTitle`/`_ProfNeoSectionHead` pattern (icon-in-tinted-circle
/// + bold title). Purely presentational chrome for this screen's own
/// English UI headings (Today's Order Plan / Other Eligible Orders /
/// Message Intent / Response Language); never used for AI-generated
/// content, which keeps its own RTL-aware presentation via [_sectionTitle]
/// in [_ProfessionalAiResultView].
class _ProfAiSectionHead extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ProfAiSectionHead(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: ProfessionalColors.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: ProfessionalColors.primaryDark, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: ProfessionalColors.titleText,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ]);
}

/// Screen-local "dashboard module" card — a white rounded surface with a
/// subtle teal-tinted border and soft shadow, mirroring the Professional
/// Profile screen's own `_ProfInfoCard` surface language. Used to group the
/// Message Intent and Response Language controls into their own polished
/// section, and (via [_ProfAiResultCard] below) each AI result section.
class _ProfAiCard extends StatelessWidget {
  final Widget child;
  const _ProfAiCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ProfessionalRadii.lg),
          border:
              Border.all(color: ProfessionalColors.primary.withOpacity(0.16)),
          boxShadow: ProfessionalShadows.soft,
        ),
        child: child,
      );
}

/// One AI result "dashboard module": the same [_ProfAiCard] surface, with a
/// small fixed icon badge beside the section content. The badge is purely
/// decorative and physically left-aligned — it never participates in the
/// RTL/LTR direction of the AI-generated title or body text next to it,
/// which is rendered exactly as before by the unmodified `_section` /
/// `_bulletSection` / `_customerMessageSection` methods this wraps.
class _ProfAiResultCard extends StatelessWidget {
  final IconData icon;
  final Widget child;
  const _ProfAiResultCard({required this.icon, required this.child});

  @override
  Widget build(BuildContext context) => _ProfAiCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: ProfessionalColors.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  Icon(icon, color: ProfessionalColors.primaryDark, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(child: child),
          ],
        ),
      );
}

class ProfessionalAiAssistantScreen extends ConsumerWidget {
  const ProfessionalAiAssistantScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(professionalAiAssistantControllerProvider);
    final notifier =
        ref.read(professionalAiAssistantControllerProvider.notifier);
    final ordersAsync = ref.watch(professionalFirestoreOrdersProvider);

    return Scaffold(
      backgroundColor: ProfessionalColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 3,
        shadowColor: ProfessionalColors.primaryDark,
        foregroundColor: Colors.white,
        // Explicit icon/title colors — the app's global AppBarTheme sets a
        // dark titleTextStyle/iconTheme that would otherwise win over
        // foregroundColor and render the back arrow and title invisible
        // against this teal gradient background (same reasoning as
        // AiServiceAssistantScreen's own AppBar).
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 17,
        ),
        flexibleSpace: const DecoratedBox(
          decoration:
              BoxDecoration(gradient: ProfessionalColors.primaryGradient),
        ),
        title: Text(l.get('professional_ai_assistant_title')),
      ),
      body: _buildBody(context, ref, l, state, notifier, ordersAsync),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    ProfessionalAiAssistantState state,
    ProfessionalAiAssistantController notifier,
    AsyncValue<List<OrderModel>> ordersAsync,
  ) {
    if (ordersAsync.isLoading && !ordersAsync.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    if (ordersAsync.hasError && !ordersAsync.hasValue) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l.get('professional_ai_orders_error'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: ProfessionalColors.secondaryText),
          ),
        ),
      );
    }

    final orders = ordersAsync.valueOrNull ?? const <OrderModel>[];
    final eligible = orders
        .where((o) =>
            o.status == OrderStatus.pending ||
            o.status == OrderStatus.inProgress)
        .toList();

    if (eligible.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inbox_outlined,
                  size: 48, color: ProfessionalColors.light),
              const SizedBox(height: 12),
              Text(
                l.get('professional_ai_no_eligible_orders'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: ProfessionalColors.secondaryText),
              ),
            ],
          ),
        ),
      );
    }

    final canAnalyze = state.selectedOrderId != null && !state.isLoading;

    // Re-resolved on every build from the currently-loaded eligible list —
    // null whenever selectedOrderId is unset OR no longer present among
    // eligible orders (e.g. its status changed after the AI result was
    // produced). Passed to _ProfessionalAiResultView so its Open Chat action
    // can prove the selection is still valid before navigating.
    final selectedOrderId = state.selectedOrderId;
    final selectedOrder = selectedOrderId == null
        ? null
        : _findOrderById(eligible, selectedOrderId);

    // Today's orders are grouped and deterministically sorted into a plan;
    // every other eligible order stays available, unsorted, under its own
    // section — see professional_ai_daily_plan.dart for the pure logic and
    // its documented serviceDate limitation.
    final now = DateTime.now();
    final todayOrders = eligible
        .where((o) => isProfessionalAiOrderToday(o.serviceDate, now))
        .toList();
    final otherOrders = eligible
        .where((o) => !isProfessionalAiOrderToday(o.serviceDate, now))
        .toList();
    final dailyPlan = buildProfessionalAiDailyPlan(todayOrders);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _ProfAiSectionHead(
            Icons.event_available_rounded, l.get('professional_ai_today_plan')),
        const SizedBox(height: 10),
        if (dailyPlan.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l.get('professional_ai_no_orders_today'),
              style: const TextStyle(color: ProfessionalColors.secondaryText),
            ),
          )
        else
          ...dailyPlan.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ProfessionalAiOrderCard(
                  order: e.value.order,
                  selected: state.selectedOrderId == e.value.order.id,
                  onTap: () => notifier.selectOrder(e.value.order.id),
                  dailyPlanPosition: e.value.position,
                  dailyPlanReason:
                      _professionalAiOrderReason(l, dailyPlan, e.key),
                  showProximityWarning: e.value.hasProximityWarning,
                ),
              )),
        if (otherOrders.isNotEmpty) ...[
          const SizedBox(height: 16),
          _ProfAiSectionHead(Icons.list_alt_rounded,
              l.get('professional_ai_other_eligible_orders')),
          const SizedBox(height: 10),
          ...otherOrders.map((order) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ProfessionalAiOrderCard(
                  order: order,
                  selected: state.selectedOrderId == order.id,
                  onTap: () => notifier.selectOrder(order.id),
                ),
              )),
        ],
        const SizedBox(height: 20),
        // Message Intent — polished control card (icon/title header, chips
        // inside), matching Profile's info-card language. Intent values,
        // order, and onSelected are unchanged.
        _ProfAiCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProfAiSectionHead(
                  Icons.forum_rounded, l.get('professional_ai_message_intent')),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ProfessionalAiMessageIntent.values.map((intent) {
                  final selected = state.selectedMessageIntent == intent;
                  return ChoiceChip(
                    label: Text(_intentLabel(l, intent)),
                    selected: selected,
                    onSelected: (_) => notifier.selectMessageIntent(intent),
                    selectedColor: ProfessionalColors.primary,
                    backgroundColor: ProfessionalColors.background,
                    elevation: 0,
                    pressElevation: 0,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    labelStyle: TextStyle(
                      color: selected
                          ? Colors.white
                          : ProfessionalColors.primaryDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: selected
                            ? Colors.transparent
                            : ProfessionalColors.primary.withOpacity(0.35),
                        width: 1.3,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Response Language — same control-card treatment. Language values,
        // order, onSelected guard (state.isLoading), and RTL behavior driven
        // by the selection are all unchanged.
        _ProfAiCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProfAiSectionHead(Icons.language_rounded,
                  l.get('professional_ai_response_language')),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ProfessionalAiResponseLanguage.values.map((language) {
                  final selected = state.selectedResponseLanguage == language;
                  return ChoiceChip(
                    label: Text(_responseLanguageLabel(l, language)),
                    selected: selected,
                    onSelected: state.isLoading
                        ? null
                        : (_) => notifier.selectResponseLanguage(language),
                    selectedColor: ProfessionalColors.primary,
                    backgroundColor: ProfessionalColors.background,
                    elevation: 0,
                    pressElevation: 0,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    labelStyle: TextStyle(
                      color: selected
                          ? Colors.white
                          : ProfessionalColors.primaryDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: selected
                            ? Colors.transparent
                            : ProfessionalColors.primary.withOpacity(0.35),
                        width: 1.3,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                l.get('professional_ai_language_request_note'),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic,
                  color: ProfessionalColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Premium Professional-teal CTA — enable/disable condition and the
        // analyze() call are unchanged from the previous ElevatedButton,
        // only the visual presentation (gradient container instead of a
        // flat Material button) changed.
        GestureDetector(
          onTap: canAnalyze ? () => notifier.analyze() : null,
          child: Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              gradient: canAnalyze
                  ? ProfessionalColors.primaryGradient
                  : const LinearGradient(
                      colors: [Color(0xFFC7D6D3), Color(0xFFA9BAB6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(ProfessionalRadii.md),
              boxShadow:
                  canAnalyze ? ProfessionalShadows.primaryButton : const [],
            ),
            child: Center(
              child: state.isLoading
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(l.get('professional_ai_analyzing'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800)),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome_rounded,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          l.get('professional_ai_analyze'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        if (state.errorCode != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ProfessionalColors.error.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: ProfessionalColors.error.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: ProfessionalColors.error, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _localizedProfessionalAiErrorMessage(
                      l,
                      state.errorCode!,
                      state.errorReason,
                    ),
                    style: const TextStyle(color: ProfessionalColors.error),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (state.result != null) ...[
          const SizedBox(height: 20),
          _ProfessionalAiResultView(
            result: state.result!,
            selectedOrder: selectedOrder,
            // Safe because a response-language change always clears
            // `state.result` first (see
            // ProfessionalAiAssistantState.withResponseLanguageSelected) —
            // by the time a result exists, the currently-selected language
            // is guaranteed to be the one it was generated in.
            isRtl: state.selectedResponseLanguage.isRtl,
            language: state.selectedResponseLanguage,
          ),
        ],
      ],
    );
  }

  String _intentLabel(AppLocalizations l, ProfessionalAiMessageIntent intent) {
    switch (intent) {
      case ProfessionalAiMessageIntent.confirmAppointment:
        return l.get('professional_ai_intent_confirm_appointment');
      case ProfessionalAiMessageIntent.requestMoreInfo:
        return l.get('professional_ai_intent_request_more_info');
      case ProfessionalAiMessageIntent.requestPhotos:
        return l.get('professional_ai_intent_request_photos');
    }
  }
}

class _ProfessionalAiOrderCard extends StatelessWidget {
  final OrderModel order;
  final bool selected;
  final VoidCallback onTap;
  // Daily-plan annotation — all null/false for a plain eligible-order card
  // (the "Other Eligible Orders" section), so that section's appearance and
  // behavior is byte-for-byte identical to before this feature existed.
  final int? dailyPlanPosition;
  final String? dailyPlanReason;
  final bool showProximityWarning;

  const _ProfessionalAiOrderCard({
    required this.order,
    required this.selected,
    required this.onTap,
    this.dailyPlanPosition,
    this.dailyPlanReason,
    this.showProximityWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final statusColor = _statusColor(order.status);
    final summary = _categoryOrServiceSummary(order, l);
    final isDailyPlanEntry = dailyPlanPosition != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ProfessionalRadii.lg),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected ? ProfessionalColors.surfaceCard : Colors.white,
          borderRadius: BorderRadius.circular(ProfessionalRadii.lg),
          border: Border.all(
            color: selected
                ? ProfessionalColors.primary
                : ProfessionalColors.border.withOpacity(0.6),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: ProfessionalColors.primary.withOpacity(0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : ProfessionalShadows.soft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isDailyPlanEntry) ...[
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: ProfessionalColors.mid,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$dailyPlanPosition',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ] else ...[
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 22,
                    color: selected
                        ? ProfessionalColors.mid
                        : ProfessionalColors.hintText,
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.title.isNotEmpty ? order.title : summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ProfessionalColors.titleText,
                        ),
                      ),
                      if (summary.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: ProfessionalColors.secondaryText,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (isDailyPlanEntry)
                            _miniChip(
                              Icons.access_time_rounded,
                              _formatTime(order.serviceDate),
                              ProfessionalColors.secondaryText,
                            )
                          else
                            _miniChip(
                              Icons.calendar_today_outlined,
                              '${order.serviceDate.day}/${order.serviceDate.month}/${order.serviceDate.year}',
                              ProfessionalColors.secondaryText,
                            ),
                          _miniChip(
                            Icons.circle,
                            _statusLabel(order.status, l),
                            statusColor,
                          ),
                          if (order.priority == OrderPriority.urgent)
                            _miniChip(
                              Icons.priority_high_rounded,
                              l.get('urgent'),
                              ProfessionalColors.error,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isDailyPlanEntry && dailyPlanReason != null) ...[
              const SizedBox(height: 8),
              Text(
                dailyPlanReason!,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic,
                  color: ProfessionalColors.secondaryText,
                ),
              ),
            ],
            if (isDailyPlanEntry && showProximityWarning) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFF59E0B).withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 14, color: Color(0xFFB45309)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l.get('professional_ai_schedule_proximity_warning'),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF7C5300),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _miniChip(IconData icon, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      );
}

class _ProfessionalAiResultView extends ConsumerStatefulWidget {
  final ProfessionalAiAnalysisResult result;
  // The currently-selected OrderModel re-resolved from the live eligible
  // list by the parent screen — null when nothing is selected or the
  // previous selection is no longer eligible. Open Chat is only ever
  // enabled/attempted when this is non-null and matches [result.orderId].
  final OrderModel? selectedOrder;
  // Whether `result`'s generated text was produced in a right-to-left
  // language (Arabic/Hebrew). Only ever applied to AI-generated content
  // below — never to this screen's own English UI labels.
  final bool isRtl;
  // The explicitly-selected response language the result was generated in.
  // Used only to look up the fixed, local result-section titles via
  // ProfessionalAiResultSectionTitle.titleFor — never to alter the
  // generated content, never to trigger a translation or a second AI
  // request, never to affect this screen's own English UI labels.
  final ProfessionalAiResponseLanguage language;
  const _ProfessionalAiResultView({
    required this.result,
    required this.selectedOrder,
    required this.isRtl,
    required this.language,
  });

  @override
  ConsumerState<_ProfessionalAiResultView> createState() =>
      _ProfessionalAiResultViewState();
}

class _ProfessionalAiResultViewState
    extends ConsumerState<_ProfessionalAiResultView> {
  // Local, screen-only navigation guard — never added to the AI controller,
  // since this only protects against duplicate Open Chat taps and has
  // nothing to do with the AI request lifecycle.
  bool _openingChat = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final result = widget.result;
    // Each result section is its own "dashboard module" card (per the
    // Professional Profile visual reference) instead of one large shared
    // white document — content/order/RTL behavior of every section below
    // is unchanged, only the outer presentation is split apart.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProfAiResultCard(
          icon: Icons.info_outline_rounded,
          child: _section(
            ProfessionalAiResultSection.summary.titleFor(widget.language),
            result.summary,
          ),
        ),
        if (result.questions.isNotEmpty) ...[
          const SizedBox(height: 14),
          _ProfAiResultCard(
            icon: Icons.help_outline_rounded,
            child: _bulletSection(
              ProfessionalAiResultSection.questions.titleFor(widget.language),
              result.questions,
            ),
          ),
        ],
        if (result.toolsAndMaterials.isNotEmpty) ...[
          const SizedBox(height: 14),
          _ProfAiResultCard(
            icon: Icons.build_rounded,
            child: _bulletSection(
              ProfessionalAiResultSection.toolsAndMaterials
                  .titleFor(widget.language),
              result.toolsAndMaterials,
            ),
          ),
        ],
        const SizedBox(height: 14),
        _ProfAiResultCard(
          icon: Icons.checklist_rounded,
          child: _bulletSection(
            ProfessionalAiResultSection.suggestedSteps
                .titleFor(widget.language),
            result.suggestedSteps,
          ),
        ),
        if (result.safetyWarnings.isNotEmpty) ...[
          const SizedBox(height: 14),
          _safetyWarningsSection(result.safetyWarnings),
        ],
        const SizedBox(height: 14),
        _ProfAiResultCard(
          icon: Icons.forum_rounded,
          child: _customerMessageSection(context, l),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SizedBox(
          width: double.infinity,
          child: Text(
            title,
            textDirection: widget.isRtl ? TextDirection.rtl : TextDirection.ltr,
            textAlign: widget.isRtl ? TextAlign.right : TextAlign.start,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: ProfessionalColors.primaryDark,
              letterSpacing: 0.2,
            ),
          ),
        ),
      );

  // Spacing between sections is now provided by the parent's per-card
  // SizedBox gaps (see build() above), so these no longer carry their own
  // bottom margin — a pure spacing-value change, RTL/content untouched.
  Widget _section(String title, String body) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(title),
          _aiGeneratedParagraph(
            body,
            const TextStyle(fontSize: 13.5, height: 1.4),
            widget.isRtl,
          ),
        ],
      );

  Widget _bulletSection(String title, List<String> items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(title),
          ...items.map((item) => _aiListItemRow(
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(Icons.circle,
                      size: 5, color: ProfessionalColors.mid),
                ),
                item,
                const TextStyle(fontSize: 13.5, height: 1.4),
                widget.isRtl,
              )),
        ],
      );

  /// Visually noticeable (amber, warning icon) but not alarming — no red,
  /// no blinking, no dialog interruption.
  Widget _safetyWarningsSection(List<String> warnings) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7E6),
          borderRadius: BorderRadius.circular(ProfessionalRadii.lg),
          border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
          boxShadow: ProfessionalShadows.soft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              // Mirrors the icon/title order for RTL the same way
              // _aiListItemRow mirrors bullet/text — setting the Row's own
              // textDirection (not reordering children) so the warning
              // icon sits at the right-side start for Arabic/Hebrew while
              // staying icon-left for English.
              textDirection:
                  widget.isRtl ? TextDirection.rtl : TextDirection.ltr,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFB45309), size: 18),
                const SizedBox(width: 8),
                Text(
                  ProfessionalAiResultSection.safetyWarnings
                      .titleFor(widget.language),
                  textDirection:
                      widget.isRtl ? TextDirection.rtl : TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFB45309),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...warnings.map((w) => _aiListItemRow(
                  const Text(
                    '•',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Color(0xFF7C5300),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  w,
                  const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF7C5300),
                    height: 1.4,
                  ),
                  widget.isRtl,
                )),
          ],
        ),
      );

  Widget _customerMessageSection(BuildContext context, AppLocalizations l) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            ProfessionalAiResultSection.customerMessage
                .titleFor(widget.language),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ProfessionalColors.surfaceCard,
              borderRadius: BorderRadius.circular(ProfessionalRadii.md),
              border: Border.all(
                  color: ProfessionalColors.primary.withOpacity(0.25)),
            ),
            child: _aiGeneratedParagraph(
              widget.result.customerMessage,
              const TextStyle(fontSize: 13.5, height: 1.4),
              widget.isRtl,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copyMessage(context, l),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: Text(l.get('professional_ai_copy_message')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ProfessionalColors.primaryDark,
                    side: const BorderSide(
                        color: ProfessionalColors.primary, width: 1.4),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ProfessionalRadii.md),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      _openingChat ? null : () => _handleOpenChat(context, l),
                  icon: _openingChat
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: Text(
                    _openingChat
                        ? l.get('professional_ai_opening_chat')
                        : l.get('professional_ai_open_chat'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ProfessionalColors.primary,
                    disabledBackgroundColor:
                        ProfessionalColors.light.withOpacity(0.6),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ProfessionalRadii.md),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );

  // Copies the generated customer message to the clipboard only — never
  // sends it, never opens Chat, never writes anything to Firestore.
  void _copyMessage(BuildContext context, AppLocalizations l) {
    Clipboard.setData(ClipboardData(text: widget.result.customerMessage));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.get('professional_ai_message_copied'))),
    );
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Verifies the selection is still valid, then constructs the same
  /// synthetic customer [UserModel] the existing Professional Chat
  /// navigation already builds elsewhere (see
  /// professional_order_detail_screen.dart's/professional_home_screen.dart's
  /// own `_openChat`), starts the conversation the same way, and opens
  /// [ProfessionalChatScreen] with a plain, empty message input — never
  /// prefilled with `result.customerMessage`, the summary, questions,
  /// tools, warnings, or any other part of the AI result, and never sent
  /// automatically. The Professional can still use the generated customer
  /// message manually via Copy Message + paste. Guarded by [_openingChat]
  /// against duplicate taps; never navigates when the selection is stale or
  /// the customer id is missing.
  Future<void> _handleOpenChat(BuildContext context, AppLocalizations l) async {
    if (_openingChat) return;

    final order = widget.selectedOrder;
    final result = widget.result;
    if (order == null || result.orderId != order.id) {
      _showSnack(context, l.get('professional_ai_chat_order_changed'));
      return;
    }
    final customerId = order.customerId.trim();
    if (customerId.isEmpty) {
      _showSnack(context, l.get('professional_ai_chat_customer_unavailable'));
      return;
    }

    setState(() => _openingChat = true);
    try {
      final customer = UserModel(
        id: customerId,
        fullName:
            order.customerName.isNotEmpty ? order.customerName : 'Customer',
        email: '',
        phone: '',
        city: order.area,
        role: UserRole.customer,
      );
      ref.read(conversationsProvider.notifier).startConversation(customer);
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfessionalChatScreen(
            otherUser: customer,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }
}
