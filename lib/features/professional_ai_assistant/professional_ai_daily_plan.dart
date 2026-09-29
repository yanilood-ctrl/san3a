// ─── Professional AI Daily Plan — pure deterministic planning logic ───────
// Pure Dart (no Flutter widget/localization dependency) so this file can be
// unit-tested directly with `flutter_test` without pumping any widget.
// Never calls Gemini and never uses ratings, prices, customer identity,
// category popularity, or any inferred/assumed service duration — only the
// real `OrderModel` fields `serviceDate`, `priority`, `status`, `createdAt`,
// and `id`.
//
// KNOWN LIMITATION (inherited from the shared model, not introduced here):
// `OrderModel.fromMap` (lib/shared/models/models.dart) parses `serviceDate`
// as `_parseTs(map['serviceDate']) ?? DateTime.now()` — a document with a
// missing or unparseable `serviceDate` silently gets "right now" as its
// service date instead of null or a sentinel. This file has no way to tell
// such a fallback value apart from a genuinely-stored appointment for today,
// since only the already-parsed `OrderModel` is available here (the raw
// Firestore map is not). Per this feature's scope, `OrderModel` itself is
// not being changed to fix this — the daily plan is therefore only as
// trustworthy as `serviceDate` already is everywhere else this field is
// used in the app today.
import '../../shared/models/models.dart'
    show OrderModel, OrderPriority, OrderStatus;

/// Minutes at or below which two consecutive today's orders' appointment
/// times are close enough to show a non-blocking schedule-proximity
/// warning. A single named constant — never hardcoded inline.
const int kProfessionalAiScheduleProximityMinutes = 30;

/// True when [date] falls on the same real local calendar day (year/month/
/// day) as [now]. Deliberately never a UTC day-key comparison — always the
/// local calendar fields Flutter's `DateTime` already exposes.
bool isProfessionalAiOrderToday(DateTime date, DateTime now) {
  return date.year == now.year && date.month == now.month && date.day == now.day;
}

/// One entry in the deterministic daily plan: the original [order], its
/// 1-based [position] after sorting, and whether [hasProximityWarning]
/// applies (its appointment time is within
/// [kProfessionalAiScheduleProximityMinutes] of the adjacent entry directly
/// before or after it in the sorted plan).
class ProfessionalAiDailyPlanEntry {
  final OrderModel order;
  final int position;
  final bool hasProximityWarning;

  const ProfessionalAiDailyPlanEntry({
    required this.order,
    required this.position,
    required this.hasProximityWarning,
  });
}

DateTime _toMinute(DateTime d) =>
    DateTime(d.year, d.month, d.day, d.hour, d.minute);

int _priorityRank(OrderPriority p) =>
    p == OrderPriority.urgent ? 0 : 1; // urgent sorts first

int _statusRank(OrderStatus s) =>
    s == OrderStatus.inProgress ? 0 : 1; // inProgress sorts first

/// Deterministic comparator implementing, in order:
///  1. Earlier serviceDate first (compared at minute precision — the
///     smallest granularity a real appointment-time picker produces).
///  2. Same appointment minute: `urgent` before `normal`.
///  3. Same appointment minute and priority: `inProgress` before `pending`.
///  4. Then earlier `createdAt`.
///  5. Then lexicographical Firestore order id — the final, always-distinct
///     tie-breaker (no two orders ever share an id), so this comparator is
///     a total order and sorting is fully stable/deterministic.
int compareProfessionalAiDailyOrders(OrderModel a, OrderModel b) {
  final minuteCompare = _toMinute(a.serviceDate).compareTo(_toMinute(b.serviceDate));
  if (minuteCompare != 0) return minuteCompare;

  final priorityCompare =
      _priorityRank(a.priority).compareTo(_priorityRank(b.priority));
  if (priorityCompare != 0) return priorityCompare;

  final statusCompare =
      _statusRank(a.status).compareTo(_statusRank(b.status));
  if (statusCompare != 0) return statusCompare;

  final createdAtCompare = a.createdAt.compareTo(b.createdAt);
  if (createdAtCompare != 0) return createdAtCompare;

  return a.id.compareTo(b.id);
}

/// True when [a] and [b]'s real `serviceDate` values differ by at most
/// [kProfessionalAiScheduleProximityMinutes] — using the real difference
/// between the two timestamps (never truncated to minutes first), so e.g.
/// 30 minutes 0 seconds triggers the warning and 30 minutes 1 second does
/// not. An identical appointment time (zero difference) also triggers it.
bool professionalAiOrdersAreScheduleProximate(DateTime a, DateTime b) {
  final diff = a.difference(b).abs();
  return diff.inSeconds <= kProfessionalAiScheduleProximityMinutes * 60;
}

/// Sorts [todayOrders] (already filtered to orders whose `serviceDate` is
/// today — see [isProfessionalAiOrderToday]) via
/// [compareProfessionalAiDailyOrders] and annotates each with its 1-based
/// position and whether it is schedule-proximate to an adjacent entry.
/// [todayOrders] is never mutated; a new sorted list is returned.
List<ProfessionalAiDailyPlanEntry> buildProfessionalAiDailyPlan(
  List<OrderModel> todayOrders,
) {
  final sorted = List<OrderModel>.from(todayOrders)
    ..sort(compareProfessionalAiDailyOrders);

  final entries = <ProfessionalAiDailyPlanEntry>[];
  for (var i = 0; i < sorted.length; i++) {
    final order = sorted[i];
    final closeToPrevious = i > 0 &&
        professionalAiOrdersAreScheduleProximate(
            sorted[i - 1].serviceDate, order.serviceDate);
    final closeToNext = i < sorted.length - 1 &&
        professionalAiOrdersAreScheduleProximate(
            order.serviceDate, sorted[i + 1].serviceDate);
    entries.add(ProfessionalAiDailyPlanEntry(
      order: order,
      position: i + 1,
      hasProximityWarning: closeToPrevious || closeToNext,
    ));
  }
  return entries;
}
