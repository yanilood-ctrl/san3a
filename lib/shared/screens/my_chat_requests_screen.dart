// ─────────────────────────────────────────────────────────────────────────────
// My Chat Requests — shared user-side screen (Customer/Professional/
// Contractor) showing only chat_reports docs created by the current user
// (Firebase Auth uid == reporterId). One screen, themed per role via
// ChatTheme — no duplicated Firestore logic per role.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/chat_theme.dart';
import '../../features/auth/presentation/providers/app_providers.dart';
import '../models/models.dart';

const List<String> _statusOrder = ['open', 'in_review', 'resolved', 'rejected'];

// Main top filter navigation shows only these three — Rejected is presented
// separately as its own icon action (see _RejectedIconAction) rather than as
// a fourth tab. Filtering logic/status values/counts are unchanged: this
// list only controls what renders in the main TabBar/TabBarView.
const List<String> _mainStatusOrder = ['open', 'in_review', 'resolved'];

const Map<String, String> _statusLabels = {
  'open': 'Open',
  'in_review': 'In Review',
  'resolved': 'Resolved',
  'rejected': 'Rejected',
};

const Map<String, Color> _statusColors = {
  'open': Color(0xFFF59E0B),
  'in_review': Color(0xFF3B82F6),
  'resolved': Color(0xFF10B981),
  'rejected': Color(0xFFEF4444),
};

const Map<String, IconData> _statusIcons = {
  'open': Icons.hourglass_top_rounded,
  'in_review': Icons.rate_review_rounded,
  'resolved': Icons.check_circle_rounded,
  'rejected': Icons.block_rounded,
};

const Map<String, String> _emptyMessages = {
  'open': 'No pending chat requests',
  'in_review': 'No requests in review',
  'resolved': 'No resolved chat requests',
  'rejected': 'No rejected chat requests',
};

const List<_RequestType> _editTypes = [
  _RequestType(
      icon: Icons.edit_outlined,
      label: 'Edit a Message',
      color: Color(0xFF3B82F6)),
  _RequestType(
      icon: Icons.delete_outline,
      label: 'Delete a Message',
      color: AppColors.error),
  _RequestType(
      icon: Icons.report_gmailerrorred_outlined,
      label: 'Inappropriate Messages',
      color: Colors.orange),
  _RequestType(
      icon: Icons.help_outline_rounded,
      label: 'Other Issue',
      color: Color(0xFF7B2FBE)),
];

class _RequestType {
  final IconData icon;
  final String label;
  final Color color;
  const _RequestType(
      {required this.icon, required this.label, required this.color});
}

// Looks up the icon/color already defined for a request's reason (matches
// the same categories used by the Edit Request sheet) so the card can show a
// meaningful icon without inventing a second reason taxonomy. Falls back to a
// neutral icon for any legacy/free-text reason that doesn't match.
_RequestType _reasonVisual(String reason, ChatTheme theme) {
  for (final t in _editTypes) {
    if (t.label == reason) return t;
  }
  return _RequestType(
      icon: Icons.forum_outlined, label: '', color: theme.primary);
}

class MyChatRequestsScreen extends ConsumerStatefulWidget {
  final ChatTheme theme;
  const MyChatRequestsScreen({super.key, required this.theme});

  @override
  ConsumerState<MyChatRequestsScreen> createState() =>
      _MyChatRequestsScreenState();
}

class _MyChatRequestsScreenState extends ConsumerState<MyChatRequestsScreen>
    with SingleTickerProviderStateMixin {
  // Main top navigation now covers only Open / In Review / Resolved —
  // Rejected moved to its own icon action beside the bar (see
  // _RejectedIconAction). The underlying byStatus filtering (all 4
  // statuses) and counts are unchanged; this only changes what's presented
  // in the tab bar itself.
  late final TabController _tabController =
      TabController(length: _mainStatusOrder.length, vsync: this);
  bool _showRejected = false;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _selectMainTab(int index) {
    setState(() => _showRejected = false);
    _tabController.animateTo(index);
  }

  void _toggleRejected() => setState(() => _showRejected = !_showRejected);

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reportsAsync = ref.watch(myChatReportsProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : theme.bgPage,
      appBar: PreferredSize(
        // Same header footprint/quality as the Customer Orders page
        // (SliverAppBar expandedHeight: 130) — reused as a static
        // (non-collapsing) Container since this screen has no long
        // scroll-away list to justify a collapsing header. Height, corner
        // radius and shadow strength are matched 1:1; the gradient stays on
        // theme.primaryDark → theme.primary since ChatTheme has no navy
        // alias, preserving this role's own color identity.
        preferredSize: const Size.fromHeight(130),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.primaryDark, theme.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
            boxShadow: [
              BoxShadow(
                  color: theme.primaryDark.withOpacity(0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 10)),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 20, 0),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.forum_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('My Chat Requests',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3)),
                      const SizedBox(height: 6),
                      Text(
                        reportsAsync.maybeWhen(
                          data: (all) =>
                              '${all.length} requests • ${all.where((r) => r.status == 'open').length} open',
                          orElse: () => ' ',
                        ),
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
      body: reportsAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: theme.primary)),
        error: (e, st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Failed to load your chat requests. Please try again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.error,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ),
        ),
        data: (all) {
          final byStatus = <String, List<ChatReportModel>>{
            for (final s in _statusOrder)
              s: all.where((r) => r.status == s).toList(),
          };
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _ChatStatusFilterBar(
                      controller: _tabController,
                      counts: {
                        for (final s in _mainStatusOrder) s: byStatus[s]!.length
                      },
                      theme: theme,
                      isDark: isDark,
                      onTap: _selectMainTab,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _RejectedIconAction(
                    count: byStatus['rejected']!.length,
                    selected: _showRejected,
                    isDark: isDark,
                    onTap: _toggleRejected,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _showRejected
                  ? _RequestsList(
                      reports: byStatus['rejected']!,
                      emptyMessage: _emptyMessages['rejected']!,
                      theme: theme,
                      isDark: isDark,
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        for (final s in _mainStatusOrder)
                          _RequestsList(
                            reports: byStatus[s]!,
                            emptyMessage: _emptyMessages[s]!,
                            theme: theme,
                            isDark: isDark,
                          ),
                      ],
                    ),
            ),
          ]);
        },
      ),
    );
  }
}

// ── Main status filter bar (Open / In Review / Resolved) ─────────────────
// Mirrors CustomerOrdersScreen's _OrderStepperBar neumorphic tokens exactly
// in light mode (same 0xFFEEEEF5 track / 0xFFBEBECF+white layered shadow
// palette, same growing gradient icon badge on the active tab) so this
// reads as clearly part of the same design system, not merely "similar".
// Dark mode keeps a flat dark-surface equivalent, since the neumorphic
// light-gray treatment doesn't translate to a dark background. Scoped to
// only the three statuses that remain in the main navigation.
class _ChatStatusFilterBar extends StatelessWidget {
  final TabController controller;
  final Map<String, int> counts;
  final ChatTheme theme;
  final bool isDark;
  final ValueChanged<int> onTap;
  const _ChatStatusFilterBar({
    required this.controller,
    required this.counts,
    required this.theme,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final current = controller.index;
        return Container(
          height: 56,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: isDark ? _LK2.trackDark : const Color(0xFFEEEEF5),
            borderRadius: BorderRadius.circular(28),
            boxShadow: isDark
                ? [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 14,
                        offset: const Offset(0, 6)),
                  ]
                : const [
                    BoxShadow(
                        color: Color(0xFFBEBECF),
                        blurRadius: 0,
                        offset: Offset(0, 5)),
                    BoxShadow(
                        color: Color(0xFFBEBECF),
                        blurRadius: 14,
                        offset: Offset(6, 6)),
                    BoxShadow(
                        color: Colors.white,
                        blurRadius: 14,
                        offset: Offset(-6, -6)),
                  ],
          ),
          child: Row(
            children: List.generate(_mainStatusOrder.length, (i) {
              final status = _mainStatusOrder[i];
              final isActive = current == i;
              final color = _statusColors[status]!;
              final count = counts[status] ?? 0;
              final inactiveText =
                  isDark ? Colors.white60 : const Color(0xFF9999BB);
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onTap(i);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      color: isActive
                          ? (isDark ? _LK2.cardBgDark : Colors.white)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(23),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                  color: color.withOpacity(0.18),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4)),
                            ]
                          : const [],
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 260),
                              width: isActive ? 26 : 20,
                              height: isActive ? 26 : 20,
                              decoration: BoxDecoration(
                                gradient: isActive
                                    ? LinearGradient(
                                        colors: [color, color.withOpacity(0.7)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                color: isActive ? null : Colors.transparent,
                                borderRadius:
                                    BorderRadius.circular(isActive ? 9 : 7),
                                boxShadow: isActive
                                    ? [
                                        BoxShadow(
                                            color: color.withOpacity(0.45),
                                            blurRadius: 6,
                                            offset: const Offset(0, 3)),
                                      ]
                                    : const [],
                              ),
                              child: Center(
                                child: Icon(
                                  _statusIcons[status],
                                  size: isActive ? 14 : 12,
                                  color: isActive ? Colors.white : inactiveText,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(_statusLabels[status]!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: isActive ? 12 : 11,
                                      fontWeight: isActive
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: isActive
                                          ? (isDark
                                              ? Colors.white
                                              : _LK2.textPrimary)
                                          : inactiveText,
                                      letterSpacing: -0.2)),
                            ),
                            if (count > 0) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? color
                                      : (isDark
                                          ? Colors.white24
                                          : const Color(0xFFBEBECF)),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text('$count',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: isActive
                                            ? Colors.white
                                            : inactiveText)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

// ── Rejected — standalone premium icon action, presentation-only ─────────
// Rejected is no longer a tab in the main status navigation. It now sits
// beside the filter bar as its own compact neumorphic icon action — the
// same circular/rounded-square floating-button treatment used by
// CustomerOrdersScreen's per-card three-dots menu trigger/panel — rather
// than a full-width strip, so it clearly reads as a standalone premium
// action. Tapping it toggles showing the exact same rejected requests
// (byStatus['rejected']) that the old fourth tab rendered — no change to
// what gets filtered.
class _RejectedIconAction extends StatelessWidget {
  final int count;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;
  const _RejectedIconAction({
    required this.count,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _statusColors['rejected']!;
    return Tooltip(
      message: 'Rejected',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Stack(clipBehavior: Clip.none, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: selected
                  ? color
                  : (isDark ? _LK2.cardBgDark : const Color(0xFFEEEEF5)),
              borderRadius: BorderRadius.circular(19),
              boxShadow: selected
                  ? [
                      BoxShadow(
                          color: color.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 5)),
                    ]
                  : isDark
                      ? [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4)),
                        ]
                      : const [
                          BoxShadow(
                              color: Color(0xFFBEBECF),
                              blurRadius: 0,
                              offset: Offset(0, 4)),
                          BoxShadow(
                              color: Color(0xFFBEBECF),
                              blurRadius: 10,
                              offset: Offset(4, 4)),
                          BoxShadow(
                              color: Colors.white,
                              blurRadius: 10,
                              offset: Offset(-4, -4)),
                        ],
            ),
            child: Icon(Icons.block_rounded,
                color: selected ? Colors.white : color, size: 22),
          ),
          if (count > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text('$count',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ),
            ),
        ]),
      ),
    );
  }
}

// Small local color tokens for the new filter bar/rejected card only — kept
// separate from any other _LK-named palette elsewhere in the app so this
// file's presentation-only additions don't collide with unrelated screens.
class _LK2 {
  _LK2._();
  static const cardBgDark = Color(0xFF1E293B);
  static const trackDark = Color(0xFF0F172A);
  static const textPrimary = Color(0xFF1F2937);
}

class _RequestsList extends StatelessWidget {
  final List<ChatReportModel> reports;
  final String emptyMessage;
  final ChatTheme theme;
  final bool isDark;
  const _RequestsList({
    required this.reports,
    required this.emptyMessage,
    required this.theme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  theme.primaryLight,
                  theme.primaryLight.withOpacity(0.5)
                ]),
                shape: BoxShape.circle),
            child: Icon(Icons.forum_outlined, size: 42, color: theme.primary),
          ),
          const SizedBox(height: 16),
          Text(emptyMessage,
              style: TextStyle(
                  color: theme.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      itemCount: reports.length,
      itemBuilder: (ctx, i) =>
          _RequestCard(report: reports[i], theme: theme, isDark: isDark),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final ChatReportModel report;
  final ChatTheme theme;
  final bool isDark;
  const _RequestCard(
      {required this.report, required this.theme, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColors[report.status] ?? _statusColors['open']!;
    final statusIcon =
        _statusIcons[report.status] ?? Icons.info_outline_rounded;
    final reasonVisual = _reasonVisual(report.reason, theme);
    final editable = report.status == 'open';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: isDark
                ? AppColors.darkBorder
                : theme.primaryLight.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Top status accent bar
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [statusColor, statusColor.withOpacity(0.4)]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: reasonVisual.color.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(reasonVisual.icon,
                      color: reasonVisual.color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(report.reason,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : const Color(0xFF1A1A1A))),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(statusIcon, size: 11, color: statusColor),
                    const SizedBox(width: 4),
                    Text(_statusLabels[report.status] ?? report.status,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusColor)),
                  ]),
                ),
                if (editable)
                  _RequestCardMenuButton(
                    theme: theme,
                    isDark: isDark,
                    onEdit: () => _openEditSheet(context, report),
                    onDelete: () => _confirmDelete(context, report),
                  ),
              ]),
              if (report.reportedUserName != null) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Icon(Icons.person_outline_rounded,
                      size: 14,
                      color: isDark ? Colors.white60 : Colors.grey.shade500),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Regarding: ${report.reportedUserName}'
                      '${report.reportedUserRole != null ? ' (${report.reportedUserRole})' : ''}',
                      style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? Colors.white70 : Colors.grey.shade600,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
              ],
              if ((report.description ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(report.description!,
                    style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                        height: 1.35)),
              ],
              const SizedBox(height: 12),
              Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.transparent,
                      isDark ? AppColors.darkBorder : Colors.grey.shade200,
                      Colors.transparent
                    ]),
                  )),
              const SizedBox(height: 10),
              Row(children: [
                Icon(Icons.access_time_rounded,
                    size: 13, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(_fmtDate(report.createdAt),
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500)),
                if (report.updatedAt != null &&
                    report.createdAt != null &&
                    report.updatedAt!
                            .difference(report.createdAt!)
                            .inMinutes
                            .abs() >
                        1) ...[
                  const SizedBox(width: 10),
                  Icon(Icons.edit_note_rounded,
                      size: 13, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text('Updated ${_fmtDate(report.updatedAt)}',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500)),
                ],
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  static String _fmtDate(DateTime? t) {
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

  void _openEditSheet(BuildContext context, ChatReportModel report) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _EditRequestSheet(report: report, theme: theme),
    );
  }

  // "Delete Request" is not a hard delete — it moves the request to Rejected
  // using the exact same status-update path Admin already uses
  // (updateChatReportStatusInFirestore), so it shows up identically on the
  // Admin side. Firestore rules gate this to the report's own owner while
  // status is still 'open', mirroring the Edit gate above.
  void _confirmDelete(BuildContext context, ChatReportModel report) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Delete Request?',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
        content: Text(
            'This request will be moved to Rejected. You can still find it under the Rejected section.',
            style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey.shade700,
                height: 1.35)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel',
                style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await updateChatReportStatusInFirestore(
                    reportId: report.id, status: 'rejected');
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content:
                          Text('Failed to delete request. Please try again.'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating));
                }
              }
            },
            child: const Text('Delete',
                style: TextStyle(
                    color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── Card actions trigger + floating menu ──────────────────────────────────
// Mirrors CustomerOrdersScreen's _CardThreeDotsMenu / _CardMenuPanel
// neumorphic floating-action-button treatment (same neutral shadow tokens,
// same tap-to-open positioned overlay near the trigger) so the request
// card's actions read as clearly part of the same premium design system.
class _RequestCardMenuButton extends StatefulWidget {
  final ChatTheme theme;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _RequestCardMenuButton({
    required this.theme,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_RequestCardMenuButton> createState() => _RequestCardMenuButtonState();
}

class _RequestCardMenuButtonState extends State<_RequestCardMenuButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 100));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _open() {
    HapticFeedback.lightImpact();
    final items = <_CardMenuItemData>[
      _CardMenuItemData(
          icon: Icons.edit_outlined,
          label: 'Edit',
          color: widget.theme.primary,
          onTap: widget.onEdit),
      _CardMenuItemData(
          icon: Icons.block_rounded,
          label: 'Delete Request',
          color: AppColors.error,
          onTap: widget.onDelete),
    ];

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.20),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        final box = context.findRenderObject() as RenderBox?;
        final pos = box?.localToGlobal(Offset.zero) ?? Offset.zero;
        final size = box?.size ?? Size.zero;
        return Stack(children: [
          Positioned.fill(
              child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(color: Colors.transparent))),
          Positioned(
            right: 16,
            top: pos.dy + size.height + 4,
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(0.1, -0.2), end: Offset.zero)
                  .animate(curved),
              child: FadeTransition(
                  opacity: anim,
                  child: _CardMenuPanel(items: items, isDark: widget.isDark)),
            ),
          ),
        ]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? _LK2.cardBgDark : const Color(0xFFEEEEF5);
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        _ctrl.forward();
      },
      onTapUp: (_) {
        _ctrl.reverse();
        _open();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) =>
            Transform.scale(scale: 1.0 - 0.08 * _ctrl.value, child: child),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            boxShadow: widget.isDark
                ? [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 3)),
                  ]
                : const [
                    BoxShadow(
                        color: Color(0xFFBEBECF),
                        blurRadius: 0,
                        offset: Offset(0, 3)),
                    BoxShadow(
                        color: Color(0xFFBEBECF),
                        blurRadius: 6,
                        offset: Offset(3, 3)),
                    BoxShadow(
                        color: Colors.white,
                        blurRadius: 6,
                        offset: Offset(-3, -3)),
                  ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
                3,
                (i) => Container(
                      width: 3.2,
                      height: 3.2,
                      margin: const EdgeInsets.symmetric(vertical: 1.1),
                      decoration: BoxDecoration(
                          color: widget.theme.primary.withOpacity(0.7),
                          shape: BoxShape.circle),
                    )),
          ),
        ),
      ),
    );
  }
}

class _CardMenuItemData {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _CardMenuItemData(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
}

class _CardMenuPanel extends StatefulWidget {
  final List<_CardMenuItemData> items;
  final bool isDark;
  const _CardMenuPanel({required this.items, required this.isDark});

  @override
  State<_CardMenuPanel> createState() => _CardMenuPanelState();
}

class _CardMenuPanelState extends State<_CardMenuPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 320))
    ..forward();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? _LK2.cardBgDark : const Color(0xFFEEEEF5);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: bg,
        boxShadow: widget.isDark
            ? [
                BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6)),
              ]
            : const [
                BoxShadow(
                    color: Color(0xFFBEBECF),
                    blurRadius: 16,
                    offset: Offset(6, 6)),
                BoxShadow(
                    color: Colors.white,
                    blurRadius: 16,
                    offset: Offset(-6, -6)),
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(widget.items.length, (i) {
          final item = widget.items[i];
          final n = widget.items.length;
          final anim = CurvedAnimation(
            parent: _ctrl,
            curve: Interval(
                (i / n).clamp(0.0, 1.0), ((i + 1) / n).clamp(0.0, 1.0),
                curve: Curves.easeOutBack),
          );
          return AnimatedBuilder(
            animation: anim,
            builder: (_, child) => Opacity(
              opacity: anim.value.clamp(0.0, 1.0),
              child: Transform.scale(
                  scale: 0.6 + 0.4 * anim.value.clamp(0.0, 1.0), child: child),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  item.onTap();
                },
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: bg,
                      boxShadow: widget.isDark
                          ? [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3)),
                            ]
                          : const [
                              BoxShadow(
                                  color: Color(0xFFBEBECF),
                                  blurRadius: 6,
                                  offset: Offset(3, 3)),
                              BoxShadow(
                                  color: Colors.white,
                                  blurRadius: 6,
                                  offset: Offset(-3, -3)),
                            ],
                    ),
                    child: Icon(item.icon, color: item.color, size: 19),
                  ),
                  const SizedBox(width: 10),
                  Text(item.label,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: item.color)),
                ]),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _EditRequestSheet extends ConsumerStatefulWidget {
  final ChatReportModel report;
  final ChatTheme theme;
  const _EditRequestSheet({required this.report, required this.theme});

  @override
  ConsumerState<_EditRequestSheet> createState() => _EditRequestSheetState();
}

class _EditRequestSheetState extends ConsumerState<_EditRequestSheet> {
  late int _selectedType =
      _editTypes.indexWhere((t) => t.label == widget.report.reason);
  late final _descCtrl =
      TextEditingController(text: widget.report.description ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _selectedType < 0) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await updateChatReportRequestFieldsInFirestore(
        reportId: widget.report.id,
        reason: _editTypes[_selectedType].label,
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      );
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(const SnackBar(
        content: Text('Your request was updated.'),
        backgroundColor: Color(0xFF7B2FBE),
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12))),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(
        content: const Text('Failed to update your request. Please try again.'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 4),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                  color: widget.theme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.edit_rounded,
                  color: widget.theme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
                child: Text('Edit Request',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Color(0xFF1A1A2E)))),
          ]),
        ),
        Divider(color: Colors.grey.shade100, height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('What do you need help with?',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E))),
            const SizedBox(height: 10),
            ..._editTypes.asMap().entries.map((e) => InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _saving
                      ? null
                      : () => setState(() => _selectedType = e.key),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: _selectedType == e.key
                          ? e.value.color.withOpacity(0.07)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedType == e.key
                            ? e.value.color
                            : Colors.grey.shade200,
                        width: _selectedType == e.key ? 1.5 : 1,
                      ),
                    ),
                    child: Row(children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                            color: e.value.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10)),
                        child:
                            Icon(e.value.icon, color: e.value.color, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(e.value.label,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedType == e.key
                                      ? e.value.color
                                      : const Color(0xFF1A1A2E)))),
                      if (_selectedType == e.key)
                        Icon(Icons.check_circle_rounded,
                            color: e.value.color, size: 18),
                    ]),
                  ),
                )),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: TextField(
            controller: _descCtrl,
            enabled: !_saving,
            maxLines: 3,
            minLines: 2,
            decoration: InputDecoration(
              hintText: 'Describe the issue (optional)...',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      BorderSide(color: widget.theme.primary, width: 1.5)),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Row(children: [
            Expanded(
                child: OutlinedButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: const Text('Cancel',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
            )),
            const SizedBox(width: 12),
            Expanded(
                child: ElevatedButton.icon(
              onPressed: (_saving || _selectedType < 0) ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded, size: 16),
              label: Text(_saving ? 'Saving...' : 'Save Changes',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: (_selectedType >= 0 && !_saving)
                    ? widget.theme.primary
                    : Colors.grey.shade300,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            )),
          ]),
        ),
      ]),
    );
  }
}
