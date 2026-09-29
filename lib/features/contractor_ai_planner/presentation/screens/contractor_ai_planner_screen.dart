// ─── Contractor AI Crew & Order Planner Screen ──────────────────────────────
// First complete Flutter flow for the Contractor AI Crew & Order Planner:
// pick one of the Contractor's own eligible (pending/in-progress) orders,
// pick one planning intent, call `analyzeContractorJobPlan`, and show the
// validated result. The generated customer message can be copied to the
// clipboard, or opened as an editable draft in the existing
// ContractorChatScreen (see `_openChat` below) — this screen itself never
// sends a message, never assigns a worker, and never writes anything to
// Firestore beyond the same in-memory-only `startConversation` call the
// rest of the Contractor feature already makes before opening Chat.
// Deterministic ranked-worker facts are keyed by workerId only; the real
// worker name shown here is always mapped locally from
// `contractorWorkersStreamProvider` — Gemini never receives and never
// returns a worker name.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/models/models.dart'
    show
        OrderModel,
        OrderStatus,
        OrderPriority,
        WorkerModel,
        UserModel,
        UserRole;
import '../../../auth/presentation/providers/app_providers.dart'
    show
        contractorFirestoreOrdersProvider,
        contractorWorkersStreamProvider,
        conversationsProvider;
import '../../../contractor/presentation/screens/contractor_chat_screen.dart'
    show ContractorChatScreen;
import '../../../contractor/presentation/screens/contractor_home_screen.dart'
    show AppBrown;
import '../../../contractor/presentation/screens/contractor_order_detail_screen.dart'
    show ContractorOrderDetailScreen;
import '../../../contractor/presentation/theme/contractor_design.dart';
import '../../models/contractor_ai_plan_result.dart';
import '../providers/contractor_ai_planner_provider.dart';

/// Maps a stable failure code (plus an optional, already-allow-listed
/// [reason]) to safe, fixed, localized copy. Never interpolates the
/// underlying exception/message, backend details, counts, or timestamps.
String _localizedContractorAiErrorMessage(
  AppLocalizations l,
  String code, [
  String? reason,
]) {
  switch (code) {
    case 'permission-denied':
      return reason == 'contractor_only'
          ? l.get('contractor_ai_error_contractor_only')
          : l.get('contractor_ai_error_unknown');
    case 'not-found':
      return reason == 'order_not_found'
          ? l.get('contractor_ai_error_order_not_found')
          : l.get('contractor_ai_error_unknown');
    case 'failed-precondition':
      return reason == 'contractor_ai_invalid_planning_state'
          ? l.get('contractor_ai_error_invalid_planning_state')
          : l.get('contractor_ai_error_unknown');
    case 'resource-exhausted':
      switch (reason) {
        case 'contractor_ai_cooldown':
          return l.get('contractor_ai_error_cooldown');
        case 'contractor_ai_user_daily_limit':
          return l.get('contractor_ai_error_user_daily_limit');
        case 'contractor_ai_global_daily_limit':
          return l.get('contractor_ai_error_global_daily_limit');
        case 'contractor_ai_provider_quota':
          return l.get('contractor_ai_error_provider_quota');
        default:
          return l.get('contractor_ai_error_unavailable');
      }
    case 'deadline-exceeded':
    case 'unavailable':
      return l.get('contractor_ai_error_unavailable');
    case 'internal':
      return reason == 'contractor_ai_invalid_response'
          ? l.get('contractor_ai_error_invalid_response')
          : l.get('contractor_ai_error_unavailable');
    case 'invalid-response':
      return l.get('contractor_ai_error_invalid_response');
    case 'unauthenticated':
    case 'invalid-argument':
    case 'unknown':
    default:
      return l.get('contractor_ai_error_unknown');
  }
}

String _orderStatusLabel(OrderStatus s, AppLocalizations l) {
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

Color _orderStatusColor(OrderStatus s) {
  switch (s) {
    case OrderStatus.pending:
      return const Color(0xFFF59E0B);
    case OrderStatus.inProgress:
      return AppBrown.mid;
    case OrderStatus.completed:
      return const Color(0xFF22C55E);
    case OrderStatus.cancelled:
      return const Color(0xFFEF4444);
  }
}

/// A short, safe summary line for an order card: the selected services'
/// names when present, else the legacy single-service name, else the
/// category's localized label. Never includes price, ids, or customer
/// data.
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

/// The order's existing assigned-worker count only — the modern
/// multi-worker snapshot list when present, else 1 when only the legacy
/// single `assignedWorkerId` is set, else 0. Never exposes a worker id or
/// name.
int _assignedWorkerCount(OrderModel order) {
  if (order.assignedWorkers.isNotEmpty) return order.assignedWorkers.length;
  final legacyId = order.assignedWorkerId?.trim();
  return (legacyId != null && legacyId.isNotEmpty) ? 1 : 0;
}

String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

/// Finds the order with [id] inside [orders], or null if none matches —
/// used to prove a previously-selected order id is still present in the
/// currently-loaded eligible-order list before treating a result as
/// current.
OrderModel? _findOrderById(List<OrderModel> orders, String id) {
  for (final order in orders) {
    if (order.id == id) return order;
  }
  return null;
}

String _intentLabel(AppLocalizations l, ContractorAiPlanningIntent intent) {
  switch (intent) {
    case ContractorAiPlanningIntent.prepareJob:
      return l.get('contractor_ai_intent_prepare_job');
    case ContractorAiPlanningIntent.planCrew:
      return l.get('contractor_ai_intent_plan_crew');
    case ContractorAiPlanningIntent.requestCustomerInfo:
      return l.get('contractor_ai_intent_request_customer_info');
  }
}

String _responseLanguageLabel(
  AppLocalizations l,
  ContractorAiResponseLanguage language,
) {
  switch (language) {
    case ContractorAiResponseLanguage.english:
      return l.get('contractor_ai_language_english');
    case ContractorAiResponseLanguage.arabic:
      return l.get('contractor_ai_language_arabic');
    case ContractorAiResponseLanguage.hebrew:
      return l.get('contractor_ai_language_hebrew');
  }
}

/// The smallest reusable helper for AI-generated-content direction: wraps
/// one piece of text returned by `analyzeContractorJobPlan` (summary,
/// crewGuidance, questions, toolsAndMaterials, suggestedSteps,
/// coordinationNotes, safetyWarnings, customerMessage) with explicit
/// RTL/right-aligned presentation when [isRtl] is true, else normal LTR.
/// Never used for the app's own UI labels, which stay English/LTR via a
/// plain [Text] widget instead.
Widget _aiGeneratedText(String text, TextStyle style, bool isRtl) => Text(
      text,
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      textAlign: isRtl ? TextAlign.right : TextAlign.start,
      style: style,
    );

/// Wraps a non-list AI-generated paragraph (summary, crewGuidance,
/// customerMessage) in a full-width box before handing it to
/// [_aiGeneratedText]. Without this, the surrounding Column's
/// `crossAxisAlignment: CrossAxisAlignment.start` sizes the Text to its own
/// intrinsic (shrink-wrapped) width under the app's ambient LTR
/// Directionality, so an RTL paragraph's `textAlign: right` has no free
/// space to align into and the text still reads as pinned to the left
/// edge. Giving it `width: double.infinity` first gives the alignment
/// somewhere to go. Never used for `_aiListItemRow`'s text, which already
/// gets full width from its own `Expanded`.
Widget _aiGeneratedParagraph(String text, TextStyle style, bool isRtl) =>
    SizedBox(
      width: double.infinity,
      child: _aiGeneratedText(text, style, isRtl),
    );

/// Shared row layout for one AI-generated bullet-list item — [bullet] is
/// the leading marker widget, [text] the AI-generated line rendered via
/// [_aiGeneratedText]. Setting the [Row]'s own `textDirection` (rather
/// than reordering `children`) is what actually fixes the reported bug:
/// the row previously always defaulted to the ambient (LTR) Directionality,
/// so the bullet stayed pinned to the left even when the text next to it
/// was already shaped/aligned RTL. With `textDirection: TextDirection.rtl`,
/// Flutter mirrors the child order itself — bullet on the right, text
/// flowing from the right, wrapped lines included — while English/LTR
/// output keeps the original order unchanged. Shared by every bullet-list
/// AI section (Questions, Tools and Materials, Suggested Steps,
/// Coordination Notes, Safety Warnings) so the fix lives in one place.
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

String _workerStatusLabel(String status, AppLocalizations l) {
  switch (status) {
    case 'busy':
      return l.get('contractor_ai_worker_status_busy');
    case 'offline':
      return l.get('contractor_ai_worker_status_offline');
    case 'available':
    default:
      return l.get('contractor_ai_worker_status_available');
  }
}

Color _workerStatusColor(String status) {
  switch (status) {
    case 'busy':
      return const Color(0xFFF59E0B);
    case 'offline':
      return const Color(0xFF9CA3AF);
    case 'available':
    default:
      return const Color(0xFF22C55E);
  }
}

String _workingHoursSignalLabel(String signal, AppLocalizations l) {
  switch (signal) {
    case 'within':
      return l.get('contractor_ai_hours_within');
    case 'outside':
      return l.get('contractor_ai_hours_outside');
    case 'unknown':
    default:
      return l.get('contractor_ai_hours_unknown');
  }
}

/// Generates one short, deterministic "why ranked here" caption entirely
/// from real ranked facts — never attributed to Gemini, never inferring a
/// license, certification, travel time, or service duration. Follows the
/// documented priority cascade: already assigned, then specialty match,
/// then a non-default stored status (busy/offline — "available" alone is
/// the neutral default and adds no distinguishing information, since it is
/// already shown as its own chip), then active workload, then schedule
/// proximity, then the general working-hours signal.
String _contractorAiWorkerReason(
  AppLocalizations l,
  ContractorAiRankedWorkerFact fact,
) {
  if (fact.alreadyAssigned) {
    return l.get('contractor_ai_reason_already_assigned');
  }
  if (fact.specialtyMatch) {
    return l.get('contractor_ai_reason_specialty_match');
  }
  if (fact.status != 'available') {
    return fact.status == 'busy'
        ? l.get('contractor_ai_reason_busy')
        : l.get('contractor_ai_reason_offline');
  }
  if (fact.activeWorkload > 0) {
    return l
        .get('contractor_ai_reason_active_workload')
        .replaceAll('{count}', '${fact.activeWorkload}');
  }
  if (fact.hasScheduleProximityWarning) {
    return l.get('contractor_ai_reason_schedule_proximity');
  }
  switch (fact.generalWorkingHoursSignal) {
    case 'within':
      return l.get('contractor_ai_reason_hours_within');
    case 'outside':
      return l.get('contractor_ai_reason_hours_outside');
    default:
      return l.get('contractor_ai_reason_hours_unknown');
  }
}

/// The result of resolving [ContractorAiRankedWorkerFact] entries against
/// the Contractor's own currently-loaded local worker list. Extracted as a
/// standalone, pure, publicly-testable function (rather than inlined in the
/// result widget's build method) so the "preserve server rank order" and
/// "never invent/expose a raw id for a stale worker" guarantees can be unit
/// tested directly, without spinning up widgets, Riverpod, or Firestore.
class ContractorAiVisibleWorkerFacts {
  final List<ContractorAiRankedWorkerFact> visible;
  final bool hasMissingWorkers;
  const ContractorAiVisibleWorkerFacts(this.visible, this.hasMissingWorkers);
}

/// Filters [rankedWorkerFacts] down to only the entries whose `workerId` is
/// still present in [workersById], preserving the server's exact order.
/// Any fact whose worker id is no longer present locally is simply omitted
/// — never shown with the raw id, never invented, never remapped to a
/// different worker. [hasMissingWorkers] is true only when at least one
/// fact was actually dropped (an empty, non-empty-input list is a "some
/// were dropped" signal; an empty input list is not).
ContractorAiVisibleWorkerFacts resolveContractorAiVisibleWorkerFacts(
  List<ContractorAiRankedWorkerFact> rankedWorkerFacts,
  Map<String, WorkerModel> workersById,
) {
  final visible = <ContractorAiRankedWorkerFact>[];
  for (final fact in rankedWorkerFacts) {
    if (workersById.containsKey(fact.workerId)) {
      visible.add(fact);
    }
  }
  final hasMissingWorkers = rankedWorkerFacts.isNotEmpty &&
      visible.length != rankedWorkerFacts.length;
  return ContractorAiVisibleWorkerFacts(visible, hasMissingWorkers);
}

/// The set of worker ids [order] currently has assigned — the modern
/// multi-worker snapshot list's ids when present, else a single-entry set
/// built from the legacy `assignedWorkerId` when that is set, else empty.
/// Blank ids are dropped; duplicates collapse naturally via [Set].
Set<String> contractorAiLiveAssignedWorkerIds(OrderModel order) {
  if (order.assignedWorkers.isNotEmpty) {
    return order.assignedWorkers
        .map((w) => w.id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
  }
  final legacyId = order.assignedWorkerId?.trim();
  return (legacyId != null && legacyId.isNotEmpty) ? {legacyId} : <String>{};
}

/// True only when the set of worker ids marked `alreadyAssigned` in
/// [rankedWorkerFacts] (a snapshot captured at analysis time) differs from
/// [liveOrder]'s current assigned-worker ids — the smallest safe signal
/// that worker assignments may have changed since the AI plan was
/// generated. Both sides are compared as sets, so duplicate ids never
/// produce a false difference. This is a best-effort, non-authoritative
/// signal only — it never triggers a write, a re-analyze call, or any
/// other side effect by itself.
bool contractorAiAssignedWorkersMayHaveChanged(
  List<ContractorAiRankedWorkerFact> rankedWorkerFacts,
  OrderModel liveOrder,
) {
  final resultAssignedIds = <String>{
    for (final fact in rankedWorkerFacts)
      if (fact.alreadyAssigned) fact.workerId,
  };
  final liveAssignedIds = contractorAiLiveAssignedWorkerIds(liveOrder);
  if (resultAssignedIds.length != liveAssignedIds.length) return true;
  return !resultAssignedIds.containsAll(liveAssignedIds);
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

Widget _warningBanner(String message) => Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(ContractorRadii.sm),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 16, color: Color(0xFFB45309)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: Color(0xFF7C5300)),
            ),
          ),
        ],
      ),
    );

/// Screen-local section header — a small orange icon badge plus the label
/// text, mirroring the Professional AI Job Assistant's own
/// `_ProfAiSectionHead` pattern (icon-in-tinted-circle + bold title), using
/// Contractor design tokens. Purely presentational chrome for this screen's
/// own English UI headings (Select an Order / Planning Intent / Response
/// Language); never used for AI-generated content, which keeps its own
/// RTL-aware presentation via `_sectionTitle` in `_ContractorAiResultView`.
class _ContractorAiSectionHead extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ContractorAiSectionHead(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: ContractorColors.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: ContractorColors.primaryDark, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: ContractorColors.titleText,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ]);
}

/// Screen-local "dashboard module" card — a white rounded surface with a
/// subtle orange-tinted border and soft shadow, using the same Contractor
/// design tokens as the rest of the Contractor UI. Used to group the
/// Planning Intent and Response Language controls into their own polished
/// section, and (via [_ContractorAiResultCard] below) each AI result
/// section.
class _ContractorAiCard extends StatelessWidget {
  final Widget child;
  const _ContractorAiCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ContractorRadii.lg),
          border: Border.all(color: ContractorColors.primary.withOpacity(0.16)),
          boxShadow: ContractorShadows.soft,
        ),
        child: child,
      );
}

/// One AI result "dashboard module": the same [_ContractorAiCard] surface,
/// with a small fixed icon badge beside the section content. The badge is
/// purely decorative and physically left-aligned — it never participates in
/// the RTL/LTR direction of the AI-generated title or body text next to it,
/// which is rendered exactly as before by the unmodified `_section` /
/// `_bulletSection` / `_customerMessageSection` methods this wraps.
class _ContractorAiResultCard extends StatelessWidget {
  final IconData icon;
  final Widget child;
  const _ContractorAiResultCard({required this.icon, required this.child});

  @override
  Widget build(BuildContext context) => _ContractorAiCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: ContractorColors.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: ContractorColors.primaryDark, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(child: child),
          ],
        ),
      );
}

class ContractorAiPlannerScreen extends ConsumerWidget {
  const ContractorAiPlannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(contractorAiPlannerControllerProvider);
    final notifier = ref.read(contractorAiPlannerControllerProvider.notifier);
    final ordersAsync = ref.watch(contractorFirestoreOrdersProvider);
    final workersAsync = ref.watch(contractorWorkersStreamProvider);

    return Scaffold(
      backgroundColor: ContractorColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 3,
        shadowColor: AppBrown.darkest,
        foregroundColor: Colors.white,
        // Explicit icon/title colors — the app's global AppBarTheme sets a
        // dark titleTextStyle/iconTheme that would otherwise win over
        // foregroundColor and render the back arrow and title invisible
        // against this deep-orange gradient background.
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 17,
        ),
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppBrown.darkest, AppBrown.dark, Color(0xFFDC7D4E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(l.get('contractor_ai_planner_title')),
      ),
      body: _buildBody(context, l, state, notifier, ordersAsync, workersAsync),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l,
    ContractorAiPlannerState state,
    ContractorAiPlannerController notifier,
    AsyncValue<List<OrderModel>> ordersAsync,
    AsyncValue<List<WorkerModel>> workersAsync,
  ) {
    if (ordersAsync.isLoading && !ordersAsync.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    if (ordersAsync.hasError && !ordersAsync.hasValue) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l.get('contractor_ai_orders_error'),
            textAlign: TextAlign.center,
            style: TextStyle(color: AppBrown.dark),
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

    final workers = workersAsync.valueOrNull ?? const <WorkerModel>[];
    final workersById = <String, WorkerModel>{
      for (final w in workers) w.id: w,
    };

    final selectedOrderId = state.selectedOrderId;
    final selectedOrder = selectedOrderId == null
        ? null
        : _findOrderById(eligible, selectedOrderId);
    // Previously selected but no longer present in the eligible stream
    // (status changed, deleted, or reassigned away from this Contractor).
    final selectionIsStale = selectedOrderId != null && selectedOrder == null;

    final canAnalyze =
        selectedOrder != null && !state.isLoading && eligible.isNotEmpty;

    // Only ever treated as current when it matches the still-eligible
    // selected order — a stale result (e.g. the selection disappeared
    // from the live stream) is never shown.
    final showResult = state.result != null &&
        selectedOrder != null &&
        state.result!.orderId == selectedOrder.id;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _ContractorAiSectionHead(
          Icons.assignment_outlined,
          l.get('contractor_ai_select_order'),
        ),
        const SizedBox(height: 10),
        if (eligible.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_outlined, size: 48, color: AppBrown.light),
                  const SizedBox(height: 12),
                  Text(
                    l.get('contractor_ai_no_eligible_orders'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppBrown.dark),
                  ),
                ],
              ),
            ),
          )
        else
          ...eligible.map((order) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ContractorAiOrderCard(
                  order: order,
                  selected: state.selectedOrderId == order.id,
                  onTap: state.isLoading
                      ? null
                      : () => notifier.selectOrder(order.id),
                ),
              )),
        if (selectionIsStale) ...[
          const SizedBox(height: 10),
          _warningBanner(l.get('contractor_ai_order_no_longer_available')),
        ],
        const SizedBox(height: 16),
        // Planning Intent — polished control card (icon/title header, chips
        // inside), matching the Contractor dashboard card language. Intent
        // values, order, and onSelected are unchanged.
        _ContractorAiCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ContractorAiSectionHead(
                Icons.forum_rounded,
                l.get('contractor_ai_planning_intent'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ContractorAiPlanningIntent.values.map((intent) {
                  final selected = state.selectedPlanningIntent == intent;
                  return ChoiceChip(
                    label: Text(_intentLabel(l, intent)),
                    selected: selected,
                    onSelected: state.isLoading
                        ? null
                        : (_) => notifier.selectPlanningIntent(intent),
                    selectedColor: ContractorColors.primary,
                    backgroundColor: ContractorColors.background,
                    elevation: 0,
                    pressElevation: 0,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    labelStyle: TextStyle(
                      // onBrand ink on the selected #DC7D4E fill — a white
                      // label would sit at roughly 3:1 against it.
                      color: selected
                          ? ContractorColors.onBrand
                          : ContractorColors.primaryDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: selected
                            ? Colors.transparent
                            : ContractorColors.primary.withOpacity(0.35),
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
        _ContractorAiCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ContractorAiSectionHead(
                Icons.language_rounded,
                l.get('contractor_ai_response_language'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ContractorAiResponseLanguage.values.map((language) {
                  final selected = state.selectedResponseLanguage == language;
                  return ChoiceChip(
                    label: Text(_responseLanguageLabel(l, language)),
                    selected: selected,
                    onSelected: state.isLoading
                        ? null
                        : (_) => notifier.selectResponseLanguage(language),
                    selectedColor: ContractorColors.primary,
                    backgroundColor: ContractorColors.background,
                    elevation: 0,
                    pressElevation: 0,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    labelStyle: TextStyle(
                      // onBrand ink on the selected #DC7D4E fill — a white
                      // label would sit at roughly 3:1 against it.
                      color: selected
                          ? ContractorColors.onBrand
                          : ContractorColors.primaryDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: selected
                            ? Colors.transparent
                            : ContractorColors.primary.withOpacity(0.35),
                        width: 1.3,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                l.get('contractor_ai_language_request_note'),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic,
                  color: ContractorColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Premium Contractor orange CTA — enable/disable condition and the
        // analyze() call are unchanged, only the visual presentation
        // (gradient container instead of a flat Material button) changed.
        GestureDetector(
          onTap: canAnalyze ? () => notifier.analyze() : null,
          child: Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              gradient: canAnalyze
                  ? const LinearGradient(
                      colors: [AppBrown.dark, AppBrown.darkest],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFFEBD9C4), Color(0xFFC7B29C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(ContractorRadii.md),
              boxShadow:
                  canAnalyze ? ContractorShadows.primaryButton : const [],
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
                        Text(l.get('contractor_ai_analyzing'),
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
                          l.get('contractor_ai_analyze'),
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
              color: ContractorColors.error.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: ContractorColors.error.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: ContractorColors.error, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _localizedContractorAiErrorMessage(
                      l,
                      state.errorCode!,
                      state.errorReason,
                    ),
                    style: const TextStyle(color: ContractorColors.error),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (showResult) ...[
          const SizedBox(height: 20),
          _ContractorAiResultView(
            result: state.result!,
            workersById: workersById,
            order: selectedOrder,
            // Safe because a response-language change always clears
            // `state.result` first (see
            // ContractorAiPlannerState.withResponseLanguageSelected) — by
            // the time a result exists, the currently-selected language is
            // guaranteed to be the one it was generated in.
            isRtl: state.selectedResponseLanguage.isRtl,
            language: state.selectedResponseLanguage,
          ),
        ],
      ],
    );
  }
}

class _ContractorAiOrderCard extends StatelessWidget {
  final OrderModel order;
  final bool selected;
  final VoidCallback? onTap;

  const _ContractorAiOrderCard({
    required this.order,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final statusColor = _orderStatusColor(order.status);
    final summary = _categoryOrServiceSummary(order, l);
    final assignedCount = _assignedWorkerCount(order);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ContractorRadii.lg),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? ContractorColors.surfaceCard : Colors.white,
          borderRadius: BorderRadius.circular(ContractorRadii.lg),
          border: Border.all(
            color: selected
                ? ContractorColors.primary
                : ContractorColors.border.withOpacity(0.25),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: ContractorColors.primary.withOpacity(0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : ContractorShadows.soft,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? AppBrown.mid : AppBrown.dark.withOpacity(0.5),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.title.isNotEmpty
                        ? order.title
                        : (summary.isNotEmpty
                            ? summary
                            : l.get('contractor_ai_untitled_order')),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppBrown.darkest,
                    ),
                  ),
                  if (summary.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: AppBrown.dark),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _miniChip(
                        Icons.calendar_today_outlined,
                        _formatDate(order.serviceDate),
                        AppBrown.dark,
                      ),
                      _miniChip(
                        Icons.circle,
                        _orderStatusLabel(order.status, l),
                        statusColor,
                      ),
                      if (order.priority == OrderPriority.urgent)
                        _miniChip(
                          Icons.priority_high_rounded,
                          l.get('urgent'),
                          ContractorColors.error,
                        ),
                      if (assignedCount > 0)
                        _miniChip(
                          Icons.group_rounded,
                          '$assignedCount',
                          AppBrown.mid,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContractorAiResultView extends ConsumerWidget {
  final ContractorAiPlanResult result;
  // The Contractor's own real, currently-loaded workers, keyed by
  // WorkerModel.id — the only source ever used to resolve a real worker
  // name for a rankedWorkerFacts entry.
  final Map<String, WorkerModel> workersById;
  // The currently selected, still-eligible (pending/inProgress) real order
  // this result belongs to — guaranteed non-null and orderId-matching by
  // the caller before this widget is ever built. Used only to open the
  // existing, authoritative Order Details screen / Chat; never mutated here.
  final OrderModel order;
  // Whether `result`'s generated text was produced in a right-to-left
  // language (Arabic/Hebrew). Only ever applied to AI-generated content
  // below — never to this screen's own English UI labels.
  final bool isRtl;
  // The explicitly-selected response language the result was generated in.
  // Used only to look up the fixed, local result-section titles and
  // captions via ContractorAiResultSectionTitle.titleFor /
  // ContractorAiResponseLanguageCaptions — never to alter the generated
  // content, never to trigger a translation or a second AI request, never
  // to affect this screen's own English UI labels.
  final ContractorAiResponseLanguage language;

  const _ContractorAiResultView({
    required this.result,
    required this.workersById,
    required this.order,
    required this.isRtl,
    required this.language,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);

    // Preserve the server's exact ranked order. A fact whose worker id is
    // no longer present locally is simply omitted — never shown with the
    // raw id, never invented, never remapped to a different worker, and
    // never allowed to affect the order of the entries that do resolve.
    final resolved = resolveContractorAiVisibleWorkerFacts(
      result.rankedWorkerFacts,
      workersById,
    );
    final visibleFacts = resolved.visible;
    final hasMissingWorkers = resolved.hasMissingWorkers;

    // Each result section is its own "dashboard module" card (matching the
    // Professional AI Job Assistant's visual reference) instead of one
    // large shared white document — content/order/RTL behavior of every
    // section below is unchanged, only the outer presentation is split
    // apart.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ContractorAiResultCard(
          icon: Icons.info_outline_rounded,
          child: _section(
            ContractorAiResultSection.summary.titleFor(language),
            result.summary,
          ),
        ),
        const SizedBox(height: 14),
        _ContractorAiResultCard(
          icon: Icons.groups_rounded,
          child: _recommendedCrewSizeSection(),
        ),
        const SizedBox(height: 14),
        _ContractorAiResultCard(
          icon: Icons.engineering_rounded,
          child: _section(
            ContractorAiResultSection.crewGuidance.titleFor(language),
            result.crewGuidance,
          ),
        ),
        if (result.questions.isNotEmpty) ...[
          const SizedBox(height: 14),
          _ContractorAiResultCard(
            icon: Icons.help_outline_rounded,
            child: _bulletSection(
              ContractorAiResultSection.questions.titleFor(language),
              result.questions,
            ),
          ),
        ],
        if (result.toolsAndMaterials.isNotEmpty) ...[
          const SizedBox(height: 14),
          _ContractorAiResultCard(
            icon: Icons.build_rounded,
            child: _bulletSection(
              ContractorAiResultSection.toolsAndMaterials.titleFor(language),
              result.toolsAndMaterials,
            ),
          ),
        ],
        const SizedBox(height: 14),
        _ContractorAiResultCard(
          icon: Icons.checklist_rounded,
          child: _bulletSection(
            ContractorAiResultSection.suggestedSteps.titleFor(language),
            result.suggestedSteps,
          ),
        ),
        if (result.coordinationNotes.isNotEmpty) ...[
          const SizedBox(height: 14),
          _ContractorAiResultCard(
            icon: Icons.groups_2_rounded,
            child: _bulletSection(
              ContractorAiResultSection.coordinationNotes.titleFor(language),
              result.coordinationNotes,
            ),
          ),
        ],
        if (result.safetyWarnings.isNotEmpty) ...[
          const SizedBox(height: 14),
          _safetyWarningsSection(result.safetyWarnings),
        ],
        const SizedBox(height: 14),
        _ContractorAiResultCard(
          icon: Icons.forum_rounded,
          child: _customerMessageSection(context, ref, l),
        ),
        const SizedBox(height: 14),
        _ContractorAiResultCard(
          icon: Icons.assignment_ind_rounded,
          child: _openOrderAssignmentSection(context, l),
        ),
        if (result.rankedWorkerFacts.isNotEmpty) ...[
          const SizedBox(height: 14),
          _ContractorAiResultCard(
            icon: Icons.groups_rounded,
            child: _rankedWorkersSection(l, visibleFacts, hasMissingWorkers),
          ),
        ],
      ],
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SizedBox(
          width: double.infinity,
          child: Text(
            title,
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
            textAlign: isRtl ? TextAlign.right : TextAlign.start,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: ContractorColors.primaryDark,
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
            isRtl,
          ),
        ],
      );

  Widget _recommendedCrewSizeSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            ContractorAiResultSection.recommendedCrewSize.titleFor(language),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: ContractorColors.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${result.recommendedWorkerCount}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: ContractorColors.primaryDark,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  language.recommendedCrewSizeAdvisoryCaption,
                  textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                  textAlign: isRtl ? TextAlign.right : TextAlign.start,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                    color: ContractorColors.secondaryText,
                  ),
                ),
              ),
            ],
          ),
        ],
      );

  Widget _bulletSection(String title, List<String> items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(title),
          ...items.map((item) => _aiListItemRow(
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child:
                      Icon(Icons.circle, size: 5, color: ContractorColors.mid),
                ),
                item,
                const TextStyle(fontSize: 13.5, height: 1.4),
                isRtl,
              )),
        ],
      );

  /// Visually noticeable (amber, warning icon) but not alarming — no red,
  /// no blinking, no dialog interruption. Kept as its own distinctly-styled
  /// block (not wrapped in the icon-badge `_ContractorAiResultCard`) so the
  /// warning semantics stay visually unmistakable, matching the Professional
  /// AI Job Assistant's own safety-warnings treatment.
  Widget _safetyWarningsSection(List<String> warnings) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7E6),
          borderRadius: BorderRadius.circular(ContractorRadii.lg),
          border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
          boxShadow: ContractorShadows.soft,
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
              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFB45309), size: 18),
                const SizedBox(width: 8),
                Text(
                  ContractorAiResultSection.safetyWarnings.titleFor(language),
                  textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
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
                  isRtl,
                )),
          ],
        ),
      );

  // Copy Message and Open Chat are laid out as a single matched-height row
  // (secondary outlined Copy + primary filled Open Chat), matching the
  // Professional AI Job Assistant's control styling. Open Chat keeps the
  // exact same "hide, don't guess" convention as before — it simply isn't
  // added to the Row when the order has no real customer id — and still
  // calls the same unmodified `_openChat` below with a plain, empty Chat
  // input; Copy Message still only copies via the unmodified `_copyMessage`.
  Widget _customerMessageSection(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
  ) {
    final showOpenChat = order.customerId.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          ContractorAiResultSection.customerMessage.titleFor(language),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ContractorColors.surfaceCard,
            borderRadius: BorderRadius.circular(ContractorRadii.md),
            border:
                Border.all(color: ContractorColors.primary.withOpacity(0.25)),
          ),
          child: _aiGeneratedParagraph(
            result.customerMessage,
            const TextStyle(fontSize: 13.5, height: 1.4),
            isRtl,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _copyMessage(context, l),
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: Text(l.get('contractor_ai_copy_message')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ContractorColors.primaryDark,
                  side: const BorderSide(
                      color: ContractorColors.primary, width: 1.4),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ContractorRadii.md),
                  ),
                ),
              ),
            ),
            if (showOpenChat) ...[
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openChat(context, ref, l),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: Text(l.get('contractor_ai_open_chat')),
                  style: ElevatedButton.styleFrom(
                    // primaryDark, not primary: a white label on #DC7D4E sits
                    // at roughly 3:1, which is too low for button text.
                    backgroundColor: ContractorColors.primaryDark,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ContractorRadii.md),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // Read-only navigation only: opens the existing, authoritative
  // ContractorOrderDetailScreen for this same real order (never AI result
  // data, never a preselected worker). Worker assignment itself stays
  // entirely inside that screen's existing manual "Accept & Assign
  // Worker" / "Manage Assigned Workers" actions — this button never
  // assigns, unassigns, writes assignedWorkers, or changes order status.
  Widget _openOrderAssignmentSection(BuildContext context, AppLocalizations l) {
    final assignmentsMayHaveChanged = contractorAiAssignedWorkersMayHaveChanged(
      result.rankedWorkerFacts,
      order,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (assignmentsMayHaveChanged) ...[
          _warningBanner(l.get('contractor_ai_assignment_data_changed')),
          const SizedBox(height: 10),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ContractorOrderDetailScreen(order: order),
              ),
            ),
            icon: const Icon(Icons.engineering_rounded, size: 16),
            label: Text(l.get('contractor_ai_open_order_assignment')),
            style: ElevatedButton.styleFrom(
              // primaryDark, not primary — see note above on label contrast.
              backgroundColor: ContractorColors.primaryDark,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ContractorRadii.md),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: Text(
            language.manualAssignmentCaption,
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
            textAlign: isRtl ? TextAlign.right : TextAlign.start,
            style: const TextStyle(
              fontSize: 11.5,
              fontStyle: FontStyle.italic,
              color: ContractorColors.secondaryText,
            ),
          ),
        ),
      ],
    );
  }

  // Read-only navigation only: opens the existing ContractorChatScreen for
  // the real customer of this same real order, with a plain, empty message
  // input — never prefilled with `result.customerMessage` or any other AI
  // result field, and never sent automatically. The Contractor can still
  // use the generated customer message manually via Copy Message + paste.
  // Re-reads the freshest provider state right before navigating (rather
  // than trusting this widget's own build-time `result`/`order` fields) so
  // a stale/mismatched selection can never be used to open the wrong
  // customer's chat.
  void _openChat(BuildContext context, WidgetRef ref, AppLocalizations l) {
    void showSafeSnack(String messageKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.get(messageKey))),
      );
    }

    final freshState = ref.read(contractorAiPlannerControllerProvider);
    final freshResult = freshState.result;
    final freshOrders =
        ref.read(contractorFirestoreOrdersProvider).valueOrNull ??
            const <OrderModel>[];
    final freshEligible = freshOrders
        .where((o) =>
            o.status == OrderStatus.pending ||
            o.status == OrderStatus.inProgress)
        .toList();
    final freshOrder = freshState.selectedOrderId == null
        ? null
        : _findOrderById(freshEligible, freshState.selectedOrderId!);

    final staleOrMismatched = freshResult == null ||
        freshOrder == null ||
        freshResult.orderId != freshOrder.id;
    if (staleOrMismatched) {
      showSafeSnack('contractor_ai_chat_order_changed');
      return;
    }

    final customerId = freshOrder.customerId.trim();
    if (customerId.isEmpty) {
      showSafeSnack('contractor_ai_chat_customer_unavailable');
      return;
    }

    // Reuses the exact synthetic-customer pattern already established by
    // ContractorOrderDetailScreen/ContractorHomeScreen's own "send_message"
    // actions — never a new Firestore query.
    final customer = UserModel(
      id: freshOrder.customerId,
      fullName: freshOrder.customerName.isNotEmpty
          ? freshOrder.customerName
          : 'Customer',
      email: '',
      phone: '',
      city: freshOrder.area,
      role: UserRole.customer,
    );
    ref.read(conversationsProvider.notifier).startConversation(customer);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContractorChatScreen(
          otherUser: customer,
        ),
      ),
    );
  }

  Widget _rankedWorkersSection(
    AppLocalizations l,
    List<ContractorAiRankedWorkerFact> visibleFacts,
    bool hasMissingWorkers,
  ) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            ContractorAiResultSection.recommendedWorkers.titleFor(language),
          ),
          if (hasMissingWorkers) ...[
            _warningBanner(l.get('contractor_ai_stale_worker_warning')),
            const SizedBox(height: 10),
          ],
          ...visibleFacts.asMap().entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ContractorAiWorkerCard(
                  rank: entry.key + 1,
                  worker: workersById[entry.value.workerId]!,
                  fact: entry.value,
                ),
              )),
        ],
      );

  // Copies the generated customer message to the clipboard only — never
  // sends it, never opens Chat, never writes anything to Firestore, never
  // changes order status or assigned workers.
  void _copyMessage(BuildContext context, AppLocalizations l) {
    Clipboard.setData(ClipboardData(text: result.customerMessage));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.get('contractor_ai_message_copied'))),
    );
  }
}

class _ContractorAiWorkerCard extends StatelessWidget {
  final int rank;
  final WorkerModel worker;
  final ContractorAiRankedWorkerFact fact;

  const _ContractorAiWorkerCard({
    required this.rank,
    required this.worker,
    required this.fact,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final statusColor = _workerStatusColor(fact.status);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ContractorColors.surfaceCard,
        borderRadius: BorderRadius.circular(ContractorRadii.md),
        border: Border.all(color: ContractorColors.primary.withOpacity(0.15)),
        boxShadow: ContractorShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    color: ContractorColors.primary, shape: BoxShape.circle),
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  worker.name.trim().isNotEmpty
                      ? worker.name
                      : l.get('contractor_ai_worker_unnamed'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: ContractorColors.titleText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _miniChip(
                Icons.circle,
                _workerStatusLabel(fact.status, l),
                statusColor,
              ),
              _miniChip(
                Icons.work_outline_rounded,
                l
                    .get('contractor_ai_worker_active_workload')
                    .replaceAll('{count}', '${fact.activeWorkload}'),
                ContractorColors.secondaryText,
              ),
              if (fact.alreadyAssigned)
                _miniChip(
                  Icons.check_circle_outline_rounded,
                  l.get('contractor_ai_worker_already_assigned'),
                  ContractorColors.primary,
                ),
              if (fact.specialtyMatch)
                _miniChip(
                  Icons.star_outline_rounded,
                  l.get('contractor_ai_worker_specialty_match'),
                  ContractorColors.primary,
                ),
              if (fact.hasScheduleProximityWarning)
                _miniChip(
                  Icons.warning_amber_rounded,
                  l.get('contractor_ai_worker_schedule_proximity_warning'),
                  const Color(0xFFB45309),
                ),
              _miniChip(
                Icons.schedule_outlined,
                _workingHoursSignalLabel(fact.generalWorkingHoursSignal, l),
                ContractorColors.secondaryText,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _contractorAiWorkerReason(l, fact),
            style: const TextStyle(
              fontSize: 11.5,
              fontStyle: FontStyle.italic,
              color: ContractorColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}
