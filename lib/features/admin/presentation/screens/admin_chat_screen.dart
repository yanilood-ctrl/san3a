import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/models.dart';
import '../providers/admin_providers.dart';
import '../../../auth/presentation/providers/app_providers.dart'
    show
        adminConversationsProvider,
        adminChatTimelineForConversationProvider,
        AdminChatTimelineEntry,
        AdminChatEntrySource,
        sendAdminWarningMessage,
        adminQuickRepliesProvider,
        createQuickReplyInFirestore,
        updateQuickReplyInFirestore,
        deleteQuickReplyInFirestore,
        ensureDefaultQuickRepliesSeeded,
        adminChatReportsProvider,
        updateChatReportStatusInFirestore,
        markChatReportsSeenByAdmin,
        conversationByIdProvider,
        adminHideMessageInFirestore,
        adminHideAdminWarningInFirestore,
        adminBlockConversationInFirestore,
        adminUnblockConversationInFirestore,
        userByIdProvider,
        authProvider;
import '../../../../shared/widgets/shared_widgets.dart' show ProfileAvatarImage;
import 'admin_users_screen.dart' show showAdminUserDetails;
import '../widgets/admin_bottom_nav.dart';

// ─── Admin Chat Management Screen ─────────────────────────────────────────────
class AdminChatScreen extends ConsumerStatefulWidget {
  const AdminChatScreen({super.key});
  @override
  ConsumerState<AdminChatScreen> createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends ConsumerState<AdminChatScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reportsAsync = ref.watch(adminChatReportsProvider);
    final reports = reportsAsync.value ?? const <ChatReportModel>[];
    final convsAsync = ref.watch(adminConversationsProvider);
    final convs = convsAsync.value ?? const <ConversationModel>[];
    final unseenRequestsCount = reports.where((r) => !r.isSeenByAdmin).length;
    final q = _query.trim().toLowerCase();
    final filteredConvs = q.isEmpty
        ? convs
        : convs.where((c) {
            final names = c.participantNames.values.join(' ').toLowerCase();
            return names.contains(q) ||
                c.lastMessage.toLowerCase().contains(q) ||
                c.id.toLowerCase().contains(q);
          }).toList();

    return Scaffold(
      backgroundColor: AppAdmin.surfaceTint,
      body: Column(children: [
        // ── Header — same premium lilac/3D depth language as the redesigned
        // Admin Orders/Admin Users header (3-stop gradient, 32px rounded
        // bottom corners, tinted drop shadow). The segmented tab bar no
        // longer lives inside this header; the Requests action moved in as
        // a compact glass trigger, same navigation as before. ───────────────
        Container(
          decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [
                AppAdmin.inkDarkest,
                AppAdmin.darkest,
                AppAdmin.dark
              ], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32)),
              boxShadow: [
                BoxShadow(
                    color: Color(0x60321143),
                    blurRadius: 28,
                    offset: Offset(0, 12)),
              ]),
          child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 16, 18),
                child: Row(children: [
                  GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white, size: 18))),
                  const SizedBox(width: 12),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppAdmin.accent, AppAdmin.dark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [
                        BoxShadow(
                            color: AppAdmin.accent.withOpacity(0.45),
                            blurRadius: 10,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: const Icon(Icons.forum_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                      child: Text('Chat Management',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: Colors.white))),
                  const SizedBox(width: 10),
                  // Requests — premium glass action button, same interaction
                  // language as the Orders/Users header three-dots trigger.
                  // Same unseen-count badge and the same direct navigation
                  // to AdminChatRequestsScreen as before.
                  _RequestsActionButton(
                    unseenCount: unseenRequestsCount,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AdminChatRequestsScreen())),
                  ),
                ]),
              )),
        ),

        // ── Status Tabs — moved outside/below the purple header, as its own
        // separate elevated component on the light page background (matches
        // the redesigned Admin Orders/Admin Users layout). Same
        // _ChatStepperBar widget, same TabController and counts — tab
        // switching/filtering behavior unchanged.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: _ChatStepperBar(
            controller: _tab,
            convsCount: convs.length,
            onTabChanged: (i) => setState(() => _tab.animateTo(i)),
          ),
        ),

        Expanded(
            child: TabBarView(controller: _tab, children: [
          // Tab 1: Conversations
          Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                    color: AppAdmin.surfaceTint,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                          color: AppAdmin.borderSoft,
                          blurRadius: 0,
                          offset: Offset(0, 4)),
                      BoxShadow(
                          color: AppAdmin.borderSoft,
                          blurRadius: 8,
                          offset: Offset(4, 4)),
                      BoxShadow(
                          color: Colors.white,
                          blurRadius: 8,
                          offset: Offset(-3, -3)),
                    ]),
                child: Row(children: [
                  Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [AppAdmin.dark, AppAdmin.darkest],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.search_rounded,
                          color: Colors.white, size: 20)),
                  Expanded(
                      child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppAdmin.inkDarkest),
                    decoration: InputDecoration(
                        hintText:
                            'Search by name, message, or conversation id...',
                        hintStyle:
                            const TextStyle(color: AppAdmin.mid, fontSize: 13),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 14),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    size: 16, color: AppAdmin.dark),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _query = '');
                                })
                            : null),
                  )),
                ]),
              ),
            ),
            Expanded(
                child: convsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) {
                debugPrint('ADMIN_CHAT_LOAD_ERROR [AdminChatScreen]: $e');
                return const Center(
                    child: Text('Error loading conversations',
                        style: TextStyle(color: Colors.red, fontSize: 13)));
              },
              data: (_) => _ConvsTab(convs: filteredConvs),
            )),
          ]),

          // Tab 2: Quick Replies
          const _QuickRepliesTab(),
        ])),
      ]),
      // ── Bottom Nav Bar (shared Admin bottom nav — same widget as Admin Home) ──
      bottomNavigationBar: AdminBottomNav(
        selectedIndex:
            -1, // sub-page, not one of Home's own tabs — no highlight
        totalBadge: adminTotalBadgeCount(ref),
        onHomeTap: () => goToAdminHomeTab(context, ref),
        onPlusTap: () => showAdminSectionsMenu(context, ref),
        onProfileTap: () => goToAdminProfileTab(context, ref),
      ),
    );
  }
}

// ─── Chat Requests Tab (Phase 6I: Firestore-backed chat_reports) ─────────────
const Map<String, List<Color>> _reportStatusGrad = {
  'open': [Color(0xFFF59E0B), Color(0xFFB45309)],
  'in_review': [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
  'resolved': [Color(0xFF10B981), Color(0xFF065F46)],
  'rejected': [Color(0xFFEF4444), Color(0xFF991B1B)],
};
const Map<String, String> _reportStatusLabels = {
  'open': 'Open',
  'in_review': 'In Review',
  'resolved': 'Resolved',
  'rejected': 'Rejected',
};
const Map<String, Color> _reportPriorityColors = {
  'low': Color(0xFF10B981),
  'medium': Color(0xFFF59E0B),
  'high': Color(0xFFEF4444),
};

class _ChatRequestsTab extends ConsumerStatefulWidget {
  const _ChatRequestsTab();
  @override
  ConsumerState<_ChatRequestsTab> createState() => _ChatRequestsTabState();
}

class _ChatRequestsTabState extends ConsumerState<_ChatRequestsTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reportsAsync = ref.watch(adminChatReportsProvider);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Container(
          decoration: BoxDecoration(
              color: AppAdmin.surfaceTint,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                    color: AppAdmin.borderSoft,
                    blurRadius: 0,
                    offset: Offset(0, 3)),
                BoxShadow(
                    color: AppAdmin.borderSoft,
                    blurRadius: 6,
                    offset: Offset(3, 3)),
                BoxShadow(
                    color: Colors.white, blurRadius: 6, offset: Offset(-3, -3)),
              ]),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppAdmin.inkDarkest),
            decoration: InputDecoration(
                hintText: 'Search by reporter, reason, or conversation id...',
                hintStyle: const TextStyle(color: AppAdmin.mid, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppAdmin.mid, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            size: 16, color: AppAdmin.dark),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        })
                    : null),
          ),
        ),
      ),
      Expanded(
          child: reportsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) {
          debugPrint('CHAT_REPORTS_LOAD_ERROR [AdminChatRequestsTab]: $e');
          return const Center(
              child: Text('Failed to load chat reports',
                  style: TextStyle(color: Colors.red, fontSize: 13)));
        },
        data: (all) {
          final q = _query.trim().toLowerCase();
          final reports = q.isEmpty
              ? all
              : all.where((r) {
                  return r.reporterName.toLowerCase().contains(q) ||
                      (r.reportedUserName ?? '').toLowerCase().contains(q) ||
                      r.reason.toLowerCase().contains(q) ||
                      (r.description ?? '').toLowerCase().contains(q) ||
                      r.conversationId.toLowerCase().contains(q);
                }).toList();

          if (reports.isEmpty) {
            return const Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Icon(Icons.chat_bubble_outline_rounded,
                      size: 56, color: AppAdmin.lightest),
                  SizedBox(height: 12),
                  Text('No chat reports yet',
                      style: TextStyle(
                          color: AppAdmin.mid,
                          fontSize: 14,
                          fontWeight: FontWeight.w600))
                ]));
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: reports.length,
            itemBuilder: (ctx, i) => _ChatReportCard(report: reports[i]),
          );
        },
      )),
    ]);
  }
}

class _ChatReportCard extends StatelessWidget {
  final ChatReportModel report;
  const _ChatReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final sg = _reportStatusGrad[report.status] ?? _reportStatusGrad['open']!;
    final sc = sg[0];
    final rg = _roleColors(report.reporterRole);
    final priorityColor = _reportPriorityColors[report.priority] ??
        _reportPriorityColors['medium']!;

    return GestureDetector(
      onTap: () => showChatReportDetails(context, report),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppAdmin.surfaceTint,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: sc.withOpacity(0.18),
                blurRadius: 14,
                offset: const Offset(0, 6)),
            const BoxShadow(
                color: AppAdmin.borderSoft,
                blurRadius: 0,
                offset: Offset(0, 4)),
            const BoxShadow(
                color: AppAdmin.borderSoft,
                blurRadius: 10,
                offset: Offset(4, 4)),
            const BoxShadow(
                color: Colors.white, blurRadius: 10, offset: Offset(-4, -4)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Top gradient accent bar ──
          Container(
            height: 5,
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: sg,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight),
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                      color: sc.withOpacity(0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ]),
          ),
          Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Reporter row ──
                    Row(children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                colors: rg,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                  color: rg[0].withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4)),
                              BoxShadow(
                                  color: rg[1],
                                  blurRadius: 0,
                                  offset: const Offset(0, 3)),
                            ]),
                        child: Consumer(builder: (context, ref, _) {
                          final reporter = report.reporterId.isNotEmpty
                              ? ref
                                  .watch(userByIdProvider(report.reporterId))
                                  .valueOrNull
                              : null;
                          return ProfileAvatarImage(
                            imageUrl: reporter?.avatar,
                            size: 48,
                            borderRadius: 13,
                            fallbackText: report.reporterName,
                            fallbackTextStyle: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.white),
                          );
                        }),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(report.reporterName,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppAdmin.inkDarkest)),
                            const SizedBox(height: 4),
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: rg),
                                    borderRadius: BorderRadius.circular(20)),
                                child: Text(_roleLabel(report.reporterRole),
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                              ),
                              const SizedBox(width: 8),
                              if (report.createdAt != null)
                                Text(_fmtConvTime(report.createdAt!),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppAdmin.inkLight)),
                            ]),
                          ])),
                      // Status badge 3D
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                colors: sg,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color: sc.withOpacity(0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3)),
                              BoxShadow(
                                  color: sg[1],
                                  blurRadius: 0,
                                  offset: const Offset(0, 2)),
                            ]),
                        child: Text(
                            _reportStatusLabels[report.status] ?? report.status,
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      const Icon(Icons.report_gmailerrorred_outlined,
                          size: 14, color: AppAdmin.mid),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(report.reason,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppAdmin.inkDarkest))),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: priorityColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10)),
                        child: Text(report.priority.toUpperCase(),
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: priorityColor)),
                      ),
                    ]),
                    if (report.reportedUserName != null &&
                        report.reportedUserName!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('Regarding: ${report.reportedUserName}',
                          style: const TextStyle(
                              fontSize: 11, color: AppAdmin.mid)),
                    ],
                    // ── Description preview ──
                    if (report.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: AppAdmin.surfaceTint,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                  color: AppAdmin.borderSoft,
                                  blurRadius: 0,
                                  offset: Offset(0, 3)),
                              BoxShadow(
                                  color: AppAdmin.borderSoft,
                                  blurRadius: 6,
                                  offset: Offset(3, 3)),
                              BoxShadow(
                                  color: Colors.white,
                                  blurRadius: 6,
                                  offset: Offset(-3, -3)),
                            ]),
                        child: Text(report.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppAdmin.inkDarkest,
                                height: 1.4)),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text('Conversation: ${report.conversationId}',
                        style:
                            const TextStyle(fontSize: 10, color: AppAdmin.mid)),
                  ])),
        ]),
      ),
    );
  }
}

// ─── Chat Report Details Sheet ────────────────────────────────────────────────
void showChatReportDetails(BuildContext context, ChatReportModel report) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ChatReportDetailsSheet(report: report),
  );
}

class _ChatReportDetailsSheet extends ConsumerStatefulWidget {
  final ChatReportModel report;
  const _ChatReportDetailsSheet({required this.report});
  @override
  ConsumerState<_ChatReportDetailsSheet> createState() =>
      _ChatReportDetailsSheetState();
}

// ─── Parties Involved card (Chat Report/Request details) ──────────────────────
// Same neo card language as Admin Complaint Summary's own Parties Involved
// cards (light rounded card, role-colored avatar, role label above the
// name, trailing chevron only when tappable) — kept as a local copy here
// (rather than importing that private widget) so Complaint Center stays
// untouched. Role gradient/label come from this file's own existing
// _roleColors/_roleLabel (String-keyed, matching ChatReportModel's own
// role fields) so the color scheme is identical to _ChatReportCard's.
class _ChatPartyCard extends StatelessWidget {
  final String label;
  final List<Color> roleGrad;
  final String name;
  final String? avatarUrl;
  final String? subtitle;
  final VoidCallback? onTap;
  const _ChatPartyCard({
    required this.label,
    required this.roleGrad,
    required this.name,
    this.avatarUrl,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final roleColor = roleGrad.first;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppAdmin.surfaceTint,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: AppAdmin.borderSoft,
                blurRadius: 6,
                offset: Offset(3, 3)),
            BoxShadow(
                color: Colors.white, blurRadius: 6, offset: Offset(-3, -3)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: roleGrad,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                    color: roleColor.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: ProfileAvatarImage(
              imageUrl: avatarUrl,
              size: 42,
              borderRadius: 13,
              fallbackText: name,
              fallbackTextStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        color: roleColor,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppAdmin.inkDarkest)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppAdmin.inkLight,
                          fontStyle: FontStyle.italic)),
                ],
              ])),
          if (onTap != null)
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: AppAdmin.surfaceTint,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: AppAdmin.borderSoft,
                      blurRadius: 4,
                      offset: Offset(2, 2)),
                  BoxShadow(
                      color: Colors.white,
                      blurRadius: 4,
                      offset: Offset(-2, -2)),
                ],
              ),
              child: Icon(Icons.arrow_forward_ios_rounded,
                  size: 12, color: roleColor),
            ),
        ]),
      ),
    );
  }
}

class _ChatReportDetailsSheetState
    extends ConsumerState<_ChatReportDetailsSheet> {
  late final TextEditingController _noteCtrl;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController(text: widget.report.adminNote ?? '');
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.fixed));
  }

  Future<void> _setStatus(String status) async {
    setState(() => _busy = true);
    try {
      await updateChatReportStatusInFirestore(
          reportId: widget.report.id,
          status: status,
          adminNote:
              _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim());
      if (mounted) {
        Navigator.pop(context);
        _snack('Report marked as ${_reportStatusLabels[status] ?? status}',
            AppAdmin.dark);
      }
    } catch (e) {
      _snack('Failed to update report', AppColors.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveNote() async {
    setState(() => _busy = true);
    try {
      await updateChatReportStatusInFirestore(
          reportId: widget.report.id,
          status: widget.report.status,
          adminNote: _noteCtrl.text.trim());
      _snack('Admin note saved', AppAdmin.dark);
    } catch (e) {
      _snack('Failed to save admin note', AppColors.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openConversation() async {
    setState(() => _busy = true);
    try {
      final conv = await ref
          .read(conversationByIdProvider(widget.report.conversationId).future);
      if (!mounted) return;
      if (conv == null) {
        _snack('Conversation not found', AppColors.error);
        return;
      }
      Navigator.pop(context);
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => MonitorChatScreen(conv: conv)));
    } catch (e) {
      _snack('Failed to open conversation', AppColors.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _hideReportedMessage() async {
    final messageId = widget.report.messageId;
    if (messageId == null || messageId.isEmpty) return;
    final confirmed = await _confirmModerationAction(context,
        title: 'Hide Message',
        message:
            'Hide this message? This will replace it with a deleted-message placeholder.',
        confirmLabel: 'Hide',
        confirmColor: AppColors.error);
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await adminHideMessageInFirestore(
          conversationId: widget.report.conversationId,
          messageId: messageId,
          adminId: _adminIdOf(ref),
          adminName: _adminNameOf(ref));
      if (mounted) _snack('Reported message hidden', AppAdmin.dark);
    } catch (e) {
      if (mounted) _snack('Failed to hide message', AppColors.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleBlockConversation(bool block) async {
    final confirmed = await _confirmModerationAction(context,
        title: block ? 'Block Conversation' : 'Unblock Conversation',
        message: block
            ? 'Participants will no longer be able to send messages in this conversation.'
            : 'Participants will be able to send messages again.',
        confirmLabel: block ? 'Block' : 'Unblock',
        confirmColor: block ? AppColors.error : AppColors.success);
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      if (block) {
        await adminBlockConversationInFirestore(
            conversationId: widget.report.conversationId,
            adminId: _adminIdOf(ref),
            adminName: _adminNameOf(ref));
      } else {
        await adminUnblockConversationInFirestore(
            conversationId: widget.report.conversationId,
            adminId: _adminIdOf(ref),
            adminName: _adminNameOf(ref));
      }
      if (mounted)
        _snack(block ? 'Conversation blocked' : 'Conversation unblocked',
            block ? AppColors.error : AppColors.success);
    } catch (e) {
      if (mounted) _snack('Failed to update conversation', AppColors.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyToClipboard(String value, String successMessage) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    _snack(successMessage, AppAdmin.dark);
  }

  Widget _copyButton(String value, String successMessage) => GestureDetector(
        onTap: () => _copyToClipboard(value, successMessage),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: AppAdmin.dark.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.copy_rounded, size: 14, color: AppAdmin.dark),
        ),
      );

  // Builds one "Parties Involved" card, resolving [userId]/[storedName]/
  // [storedRole] via the safe id-first (never name-guessing on a failed id
  // lookup) rule in _resolveChatParty. When nothing resolves, the card
  // stays read-only (no onTap, no chevron) and shows the stored name/role
  // plus a "User unavailable" subtitle — never inventing a user.
  Widget _buildPartyCard({
    required List<UserModel> users,
    required String? userId,
    required String storedName,
    required String? storedRole,
  }) {
    final resolved = _resolveChatParty(
        users: users,
        userId: userId,
        storedName: storedName,
        storedRoleRaw: storedRole);
    final roleKey =
        resolved != null ? _roleKeyOfUserRole(resolved.role) : storedRole;
    final name = storedName.trim().isNotEmpty
        ? storedName.trim()
        : (resolved?.fullName.isNotEmpty == true ? resolved!.fullName : '—');
    return _ChatPartyCard(
      label: _roleLabel(roleKey),
      roleGrad: _roleColors(roleKey),
      name: name,
      avatarUrl: resolved?.avatar,
      subtitle: resolved == null ? 'User unavailable' : null,
      onTap: resolved != null
          ? () => showAdminUserDetails(context, resolved, ref)
          : null,
    );
  }

  Widget _detailRow(String label, String value, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppAdmin.mid)),
          const SizedBox(height: 2),
          Row(children: [
            Expanded(
                child: Text(value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: AppAdmin.inkDarkest))),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing,
            ],
          ]),
        ]),
      );

  Widget _statusBtn(String status, String label, Color color) {
    final isCurrent = widget.report.status == status;
    return ElevatedButton(
      onPressed: (_busy || isCurrent) ? null : () => _setStatus(status),
      style: ElevatedButton.styleFrom(
          backgroundColor: isCurrent ? Colors.grey.shade300 : color,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      child: Text(label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final isBlocked = ref
            .watch(conversationByIdProvider(report.conversationId))
            .value
            ?.isBlocked ??
        false;
    // Already-loaded live Admin users list — same provider _viewReportedUser
    // Profile used to read from, now watched so party cards resolve/update
    // reactively without a duplicate Firestore query.
    final adminUsers = ref.watch(adminUsersProvider);
    final hasReportedAgainst =
        (report.reportedUserId?.trim().isNotEmpty ?? false) ||
            (report.reportedUserName?.trim().isNotEmpty ?? false);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(24))),
      child: SingleChildScrollView(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                    color: AppAdmin.dark.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.report_gmailerrorred_rounded,
                    color: AppAdmin.dark, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Chat Report',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppAdmin.inkDarkest)),
                    Text('ID: ${report.id}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                  ])),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: AppAdmin.mid)),
            ]),
          ),
          Divider(color: Colors.grey.shade100, height: 20),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow('Chat Report ID', report.id,
                      trailing:
                          _copyButton(report.id, 'Chat Report ID copied')),
                  const SizedBox(height: 4),
                  const Text('Parties Involved',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppAdmin.inkDarkest)),
                  const SizedBox(height: 10),
                  _buildPartyCard(
                      users: adminUsers,
                      userId: report.reporterId,
                      storedName: report.reporterName,
                      storedRole: report.reporterRole),
                  if (hasReportedAgainst) ...[
                    const SizedBox(height: 10),
                    _buildPartyCard(
                        users: adminUsers,
                        userId: report.reportedUserId,
                        storedName: report.reportedUserName ?? '',
                        storedRole: report.reportedUserRole),
                  ],
                  const SizedBox(height: 14),
                  _detailRow('Conversation ID', report.conversationId,
                      trailing: _copyButton(
                          report.conversationId, 'Conversation ID copied')),
                  _detailRow('Reason', report.reason),
                  if (report.description?.isNotEmpty == true)
                    _detailRow('Description', report.description!),
                  _detailRow('Status',
                      _reportStatusLabels[report.status] ?? report.status),
                  _detailRow('Priority', report.priority.toUpperCase()),
                  if (report.createdAt != null)
                    _detailRow('Created', _fmtConvTime(report.createdAt!)),
                  if (report.updatedAt != null)
                    _detailRow('Updated', _fmtConvTime(report.updatedAt!)),
                  const SizedBox(height: 8),
                  const Text('Admin Note',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppAdmin.inkDarkest)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _noteCtrl,
                    maxLines: 3,
                    minLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Add an internal note...',
                      hintStyle:
                          TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade200)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade200)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: AppAdmin.dark, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                          onPressed: _busy ? null : _saveNote,
                          child: const Text('Save Note',
                              style: TextStyle(fontWeight: FontWeight.w700)))),
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _openConversation,
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('Open Conversation'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppAdmin.dark,
                        side: const BorderSide(color: AppAdmin.dark),
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                  ),
                  if (report.messageId != null &&
                      report.messageId!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _hideReportedMessage,
                      icon: const Icon(Icons.visibility_off_outlined, size: 16),
                      label: const Text('Hide Reported Message'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          minimumSize: const Size(double.infinity, 44),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                    ),
                  ],
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _toggleBlockConversation(!isBlocked),
                    icon: Icon(
                        isBlocked
                            ? Icons.lock_open_rounded
                            : Icons.block_rounded,
                        size: 16),
                    label: Text(isBlocked
                        ? 'Unblock Conversation'
                        : 'Block Conversation'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor:
                            isBlocked ? AppColors.success : AppColors.error,
                        side: BorderSide(
                            color: isBlocked
                                ? AppColors.success
                                : AppColors.error),
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                  ),
                  const SizedBox(height: 16),
                  const Text('Update Status',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppAdmin.inkDarkest)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                        child: _statusBtn(
                            'in_review', 'In Review', const Color(0xFF3B82F6))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _statusBtn(
                            'resolved', 'Resolved', const Color(0xFF10B981))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _statusBtn(
                            'rejected', 'Rejected', const Color(0xFFEF4444))),
                  ]),
                  const SizedBox(height: 20),
                ],
              )),
        ]),
      ),
    );
  }
}

// ─── Requests Action Button — premium glass trigger living inside the
// purple header, same interaction/animation language as the redesigned
// Admin Orders/Admin Users header three-dots trigger (tap-scale, glass
// gradient, dual shadow). Same unseen-count badge and same direct
// navigation to AdminChatRequestsScreen as before — presentation only.
class _RequestsActionButton extends StatefulWidget {
  final int unseenCount;
  final VoidCallback onTap;
  const _RequestsActionButton({required this.unseenCount, required this.onTap});

  @override
  State<_RequestsActionButton> createState() => _RequestsActionButtonState();
}

class _RequestsActionButtonState extends State<_RequestsActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badgeLabel =
        widget.unseenCount > 99 ? '99+' : '${widget.unseenCount}';
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        _ctrl.forward();
      },
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) =>
            Transform.scale(scale: 1.0 - 0.08 * _ctrl.value, child: child),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.white.withOpacity(0.22),
              Colors.white.withOpacity(0.10)
            ], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.30), width: 1),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 4)),
              BoxShadow(
                  color: Colors.white.withOpacity(0.12),
                  blurRadius: 6,
                  offset: const Offset(-2, -2)),
            ],
          ),
          child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                const Icon(Icons.mark_chat_unread_rounded,
                    color: Colors.white, size: 19),
                if (widget.unseenCount > 0)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 16),
                      decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: AppAdmin.darkest, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                                color: AppColors.error.withOpacity(0.5),
                                blurRadius: 4,
                                offset: const Offset(0, 2)),
                          ]),
                      child: Text(badgeLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
              ]),
        ),
      ),
    );
  }
}

// ─── Admin Chat Requests Screen (dedicated page; reuses _ChatRequestsTab) ─────
class AdminChatRequestsScreen extends ConsumerStatefulWidget {
  const AdminChatRequestsScreen({super.key});
  @override
  ConsumerState<AdminChatRequestsScreen> createState() =>
      _AdminChatRequestsScreenState();
}

class _AdminChatRequestsScreenState
    extends ConsumerState<AdminChatRequestsScreen> {
  bool _didMarkInitialRequestsSeen = false;

  void _maybeMarkRequestsSeen(List<ChatReportModel> reports) {
    if (_didMarkInitialRequestsSeen) return;
    _didMarkInitialRequestsSeen = true;
    final unseenIds =
        reports.where((r) => !r.isSeenByAdmin).map((r) => r.id).toList();
    if (unseenIds.isEmpty) return;
    markChatReportsSeenByAdmin(unseenIds).catchError((e) {
      debugPrint('CHAT_REQUESTS_MARK_SEEN_ERROR: $e');
    });
  }

  @override
  Widget build(BuildContext context) {
    final reportsAsync = ref.watch(adminChatReportsProvider);
    reportsAsync.whenData((reports) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _maybeMarkRequestsSeen(reports));
    });

    return Scaffold(
      backgroundColor: AppAdmin.surfaceTint,
      body: Column(children: [
        Container(
          decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [AppAdmin.darkest, AppAdmin.dark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28))),
          child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 16, 18),
                child: Row(children: [
                  GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white, size: 18))),
                  const SizedBox(width: 14),
                  const Expanded(
                      child: Text('Chat Requests',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white))),
                ]),
              )),
        ),
        const Expanded(child: _ChatRequestsTab()),
      ]),
    );
  }
}

// ─── Conversations Tab (Phase 6G: Firestore-backed, read-only) ────────────────
const Map<String, String> _roleLabels = {
  'customer': 'Customer',
  'professional': 'Professional',
  'contractor': 'Contractor',
  'admin': 'Admin',
};

const Map<String, List<Color>> _roleGrads = {
  'customer': [AppAdmin.accent, AppAdmin.dark],
  'professional': [Color(0xFF10B981), Color(0xFF065F46)],
  'contractor': [Color(0xFF7C3AED), Color(0xFF4C1D95)],
  'admin': [AppAdmin.dark, AppAdmin.darkest],
};

String _roleLabel(String? role) =>
    _roleLabels[role] ?? (role == null || role.isEmpty ? 'Unknown' : role);

List<Color> _roleColors(String? role) =>
    _roleGrads[role] ?? [AppAdmin.mid, AppAdmin.dark];

String _roleKeyOfUserRole(UserRole r) {
  switch (r) {
    case UserRole.customer:
      return 'customer';
    case UserRole.professional:
      return 'professional';
    case UserRole.contractor:
      return 'contractor';
    case UserRole.admin:
      return 'admin';
  }
}

UserRole? _parseChatPartyRole(String? raw) {
  switch (raw?.trim().toLowerCase()) {
    case 'customer':
      return UserRole.customer;
    case 'professional':
      return UserRole.professional;
    case 'contractor':
      return UserRole.contractor;
    case 'admin':
      return UserRole.admin;
    default:
      return null;
  }
}

// Safe party resolution for Chat Report/Request "Parties Involved" cards:
// prefer the exact stored user id (never falling back to a name match when
// a non-blank id simply fails to resolve — that's a genuinely missing/
// deleted user, not a name-matching problem). Only when the id itself is
// blank does a legacy name fallback kick in, and only as an exact
// (trimmed, lowercased) full-name match — never substring/contains — also
// requiring the stored role to match when that role string is valid, and
// only ever resolving when exactly one user matches. Zero or multiple
// matches means "unresolved", never a guess.
UserModel? _resolveChatParty({
  required List<UserModel> users,
  required String? userId,
  required String storedName,
  required String? storedRoleRaw,
}) {
  final id = userId?.trim();
  if (id != null && id.isNotEmpty) {
    for (final u in users) {
      if (u.id == id) return u;
    }
    return null;
  }
  final needle = storedName.trim().toLowerCase();
  if (needle.isEmpty) return null;
  final storedRole = _parseChatPartyRole(storedRoleRaw);
  final matches = users.where((u) {
    if (u.fullName.trim().toLowerCase() != needle) return false;
    if (storedRole != null && u.role != storedRole) return false;
    return true;
  }).toList();
  return matches.length == 1 ? matches.first : null;
}

// ─── Admin Moderation Helpers (Phase 6J) ──────────────────────────────────────
// Fixed (non-floating) SnackBar for use inside nested admin screens/sheets
// (MonitorChatScreen, report details sheet) where a floating SnackBar can
// visually clash with the bottom "monitor mode" bar or the sheet's own chrome.
void _showModerationSnack(BuildContext context, String msg, Color color) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.fixed));
}

// ─── Premium modal shell (Chat screen) ─────────────────────────────────────
// Same bottom-sheet chrome/visual language as the redesigned Admin Users
// modal shell (_AdminUserModalShell / showAdminUserModal): rounded-top
// surfaceTint sheet, drag handle, gradient header with icon badge/title/
// subtitle/close button, scrollable body, footer slot. Mirrored locally
// since that widget is private to admin_users_screen.dart — used here to
// upgrade Block/Unblock Conversation, Send Warning and Add/Edit Quick
// Reply from plain AlertDialog/Dialog to this shared premium chrome
// without changing any of their callback/business logic.
Future<T?> showAdminChatModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: builder,
  );
}

class _ChatModalShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color accentColor;
  final Widget body;
  final Widget? footer;
  const _ChatModalShell({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.accentColor,
    required this.body,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final headerDeep = Color.lerp(AppAdmin.darkest, accentColor, 0.20)!;
    final headerMid = Color.lerp(AppAdmin.darkest, accentColor, 0.55)!;
    return Padding(
      // Keeps the sheet above the keyboard.
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.88),
            decoration: const BoxDecoration(
              color: AppAdmin.surfaceTint,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                    color: AppAdmin.borderSoft,
                    blurRadius: 24,
                    offset: Offset(0, -8)),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                      color: AppAdmin.borderSoft,
                      borderRadius: BorderRadius.circular(3)),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [headerDeep, headerMid],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  boxShadow: [
                    BoxShadow(
                        color: headerDeep.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 5)),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.25))),
                    child: Icon(icon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(title,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        if (subtitle != null)
                          Text(subtitle!,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white70),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                      ])),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(11),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.25)),
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ]),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: body,
                ),
              ),
              if (footer != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: footer!,
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

// Same signature/return type as before (Future<bool>, same named params) —
// only the presentation changed, from a plain AlertDialog to the premium
// _ChatModalShell bottom sheet. Every existing call site (Block/Unblock
// Conversation, Hide Message/Warning) keeps working unmodified.
Future<bool> _confirmModerationAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  Color confirmColor = AppAdmin.dark,
}) async {
  final icon = confirmColor == AppColors.success
      ? Icons.check_circle_outline_rounded
      : Icons.warning_amber_rounded;
  final result = await showAdminChatModal<bool>(
    context: context,
    builder: (_) => _ChatModalShell(
      icon: icon,
      title: title,
      accentColor: confirmColor,
      body: Text(message,
          style: const TextStyle(
              fontSize: 13.5, color: AppAdmin.inkDark, height: 1.4)),
      footer: Row(children: [
        Expanded(
            child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppAdmin.dark,
                    side: const BorderSide(color: AppAdmin.lightest),
                    minimumSize: const Size(0, 46),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: const Text('Cancel',
                    style: TextStyle(fontWeight: FontWeight.w700)))),
        const SizedBox(width: 10),
        Expanded(
            child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: confirmColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 46),
                    padding: EdgeInsets.zero,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: Text(confirmLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700)))),
      ]),
    ),
  );
  return result ?? false;
}

String _adminIdOf(WidgetRef ref) => ref.read(authProvider)?.id ?? '';
String _adminNameOf(WidgetRef ref) =>
    ref.read(authProvider)?.fullName ?? 'Admin';

String _fmtConvTime(DateTime dt) {
  final now = DateTime.now();
  final sameDay =
      dt.year == now.year && dt.month == now.month && dt.day == now.day;
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  if (sameDay) return '$hh:$mm';
  return '${dt.day}/${dt.month}  $hh:$mm';
}

class _ConvsTab extends StatelessWidget {
  final List<ConversationModel> convs;
  const _ConvsTab({required this.convs});

  @override
  Widget build(BuildContext context) {
    if (convs.isEmpty)
      return const Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.forum_outlined, size: 56, color: AppAdmin.lightest),
        SizedBox(height: 12),
        Text('No conversations found',
            style: TextStyle(
                color: AppAdmin.mid, fontSize: 14, fontWeight: FontWeight.w600))
      ]));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
      itemCount: convs.length,
      itemBuilder: (ctx, i) => _ConvCard(conv: convs[i]),
    );
  }
}

class _ConvCard extends ConsumerWidget {
  final ConversationModel conv;
  const _ConvCard({required this.conv});

  void _openConversation(BuildContext context) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => MonitorChatScreen(conv: conv)));
  }

  Future<void> _blockConversation(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirmModerationAction(context,
        title: 'Block Conversation',
        message:
            'Participants will no longer be able to send messages in this conversation.',
        confirmLabel: 'Block',
        confirmColor: AppColors.error);
    if (!confirmed) return;
    try {
      await adminBlockConversationInFirestore(
          conversationId: conv.id,
          adminId: _adminIdOf(ref),
          adminName: _adminNameOf(ref));
      if (context.mounted)
        _showModerationSnack(context, 'Conversation blocked', AppColors.error);
    } catch (e) {
      if (context.mounted)
        _showModerationSnack(
            context, 'Failed to block conversation', AppColors.error);
    }
  }

  Future<void> _unblockConversation(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirmModerationAction(context,
        title: 'Unblock Conversation',
        message: 'Participants will be able to send messages again.',
        confirmLabel: 'Unblock',
        confirmColor: AppColors.success);
    if (!confirmed) return;
    try {
      await adminUnblockConversationInFirestore(
          conversationId: conv.id,
          adminId: _adminIdOf(ref),
          adminName: _adminNameOf(ref));
      if (context.mounted)
        _showModerationSnack(
            context, 'Conversation unblocked', AppColors.success);
    } catch (e) {
      if (context.mounted)
        _showModerationSnack(
            context, 'Failed to unblock conversation', AppColors.error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names =
        conv.participantNames.values.where((n) => n.isNotEmpty).toList();
    final title = names.isEmpty
        ? (conv.id.isEmpty ? 'Unknown participants' : conv.id)
        : names.join(' & ');
    final roles = conv.participantRoles.values.toSet().toList();
    final primaryRole = roles.isNotEmpty ? roles.first : null;
    final rg = _roleColors(primaryRole);
    final totalUnread =
        conv.unreadCounts.values.fold<int>(0, (sum, v) => sum + v);
    // Two-participant conversation summary — show the non-admin participant's
    // photo (falls back to the first participant if the admin isn't one).
    final adminId = _adminIdOf(ref);
    final otherParticipantId = conv.participantIds.firstWhere(
        (id) => id != adminId,
        orElse: () =>
            conv.participantIds.isNotEmpty ? conv.participantIds.first : '');
    final otherParticipant = otherParticipantId.isNotEmpty
        ? ref.watch(userByIdProvider(otherParticipantId)).valueOrNull
        : null;

    final accentColor = conv.isBlocked ? AppColors.error : rg[0];

    // Premium 3D card shell — same structured language as the redesigned
    // Admin Orders/Admin Users cards: tinted border, tri-shadow stack keyed
    // to the accent color (with a white "highlight" shadow on the opposite
    // corner), a slim top accent bar, and Material/InkWell ripple feedback.
    // Same tap destination and same block/unblock actions as before.
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppAdmin.surfaceTint,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withOpacity(0.16), width: 1),
        boxShadow: conv.isBlocked
            ? [
                BoxShadow(
                    color: AppColors.error.withOpacity(0.34),
                    blurRadius: 0,
                    offset: const Offset(0, 6)),
                BoxShadow(
                    color: AppColors.error.withOpacity(0.20),
                    blurRadius: 20,
                    offset: const Offset(0, 10)),
                BoxShadow(
                    color: Colors.white.withOpacity(0.9),
                    blurRadius: 8,
                    offset: const Offset(-4, -4)),
              ]
            : [
                BoxShadow(
                    color: accentColor.withOpacity(0.22),
                    blurRadius: 0,
                    offset: const Offset(0, 6)),
                BoxShadow(
                    color: accentColor.withOpacity(0.14),
                    blurRadius: 20,
                    offset: const Offset(0, 10)),
                BoxShadow(
                    color: Colors.white.withOpacity(0.9),
                    blurRadius: 8,
                    offset: const Offset(-4, -4)),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => _openConversation(context),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Top accent bar — same slim gradient-strip treatment as the
              // redesigned Admin Orders/Admin Users cards.
              Container(
                height: 5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [accentColor, accentColor.withOpacity(0.35)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar 3D
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                colors: rg,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                  color: rg[0].withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4)),
                              BoxShadow(
                                  color: rg[1],
                                  blurRadius: 0,
                                  offset: const Offset(0, 3)),
                            ]),
                        child: Stack(children: [
                          if (otherParticipant?.avatar == null ||
                              otherParticipant!.avatar!.trim().isEmpty)
                            Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                    height: 22,
                                    decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(14),
                                            topRight: Radius.circular(14)),
                                        gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.white.withOpacity(0.25),
                                              Colors.transparent
                                            ])))),
                          ProfileAvatarImage(
                            imageUrl: otherParticipant?.avatar,
                            size: 50,
                            borderRadius: 14,
                            fallbackText: title,
                            fallbackTextStyle: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.white),
                          ),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Row(children: [
                              Expanded(
                                  child: Text(title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: AppAdmin.inkDarkest))),
                              if (conv.isBlocked)
                                Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                        gradient: const LinearGradient(colors: [
                                          Color(0xFFEF4444),
                                          Color(0xFF991B1B)
                                        ]),
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: const [
                                          BoxShadow(
                                              color: Color(0x44EF4444),
                                              blurRadius: 4,
                                              offset: Offset(0, 2)),
                                          BoxShadow(
                                              color: Color(0xFF991B1B),
                                              blurRadius: 0,
                                              offset: Offset(0, 2)),
                                        ]),
                                    child: const Text('Blocked',
                                        style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white))),
                            ]),
                            const SizedBox(height: 4),
                            Text(
                                conv.lastMessage.isEmpty
                                    ? 'No messages yet'
                                    : conv.lastMessage,
                                style: const TextStyle(
                                    fontSize: 12, color: AppAdmin.inkLight),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 6),
                            // Role/unread chips wrap instead of a rigid Row so a
                            // conversation with several role chips never risks a
                            // RenderFlex overflow on narrow cards; the timestamp stays
                            // pinned to the trailing edge, same content as before.
                            Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          for (final role in roles)
                                            Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 7,
                                                        vertical: 3),
                                                decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                        colors:
                                                            _roleColors(role)),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    boxShadow: [
                                                      BoxShadow(
                                                          color: _roleColors(
                                                                  role)[0]
                                                              .withOpacity(
                                                                  0.35),
                                                          blurRadius: 3,
                                                          offset: const Offset(
                                                              0, 2)),
                                                      BoxShadow(
                                                          color: _roleColors(
                                                              role)[1],
                                                          blurRadius: 0,
                                                          offset: const Offset(
                                                              0, 2)),
                                                    ]),
                                                child: Text(_roleLabel(role),
                                                    style: const TextStyle(
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: Colors.white))),
                                          if (totalUnread > 0)
                                            Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 7,
                                                        vertical: 3),
                                                decoration: BoxDecoration(
                                                    color: AppAdmin.accent,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10)),
                                                child: Text(
                                                    '$totalUnread unread',
                                                    style: const TextStyle(
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: Colors.white))),
                                        ]),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                      _fmtConvTime(conv.updatedAt ??
                                          conv.lastMessageTime),
                                      style: const TextStyle(
                                          fontSize: 10, color: AppAdmin.mid)),
                                ]),
                          ])),
                      const SizedBox(width: 6),
                      // Three-dots trigger — same premium neumorphic
                      // trigger/floating-panel language as the redesigned Admin
                      // Orders/Admin Users per-card menu, viewport-aware so it
                      // never gets clipped off-screen. Same two actions (Block /
                      // Unblock Conversation) and same handlers as before.
                      _ConvThreeDotsMenu(
                        isBlocked: conv.isBlocked,
                        onBlock: () => _blockConversation(context, ref),
                        onUnblock: () => _unblockConversation(context, ref),
                      ),
                    ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ConvActionItemData {
  final IconData icon;
  final String label;
  final List<Color> iconColors;
  final Color labelColor;
  final VoidCallback onTap;
  const _ConvActionItemData({
    required this.icon,
    required this.label,
    required this.iconColors,
    required this.labelColor,
    required this.onTap,
  });
}

// ─── Per-conversation three-dots menu — same premium neumorphic
// trigger/floating-panel language as the redesigned Admin Orders/Admin
// Users per-card three-dots menu (raised 3D trigger, staggered pop-in
// panel, viewport-aware direction flip + scroll clamp so the panel is
// never clipped off-screen). Same two actions (Block/Unblock
// Conversation) and same handlers dispatched by _ConvCard as before —
// presentation only. ───────────────────────────────────────────────────
class _ConvThreeDotsMenu extends StatelessWidget {
  final bool isBlocked;
  final VoidCallback onBlock;
  final VoidCallback onUnblock;
  const _ConvThreeDotsMenu({
    required this.isBlocked,
    required this.onBlock,
    required this.onUnblock,
  });

  void _open(BuildContext context) {
    HapticFeedback.lightImpact();
    final items = [
      isBlocked
          ? _ConvActionItemData(
              icon: Icons.lock_open_rounded,
              label: 'Unblock Conversation',
              iconColors: [AppColors.success, const Color(0xFF065F46)],
              labelColor: AppColors.success,
              onTap: onUnblock)
          : _ConvActionItemData(
              icon: Icons.block_rounded,
              label: 'Block Conversation',
              iconColors: [const Color(0xFFEA580C), const Color(0xFF9A3412)],
              labelColor: const Color(0xFFEA580C),
              onTap: onBlock),
    ];

    final box = context.findRenderObject() as RenderBox?;
    final pos = box?.localToGlobal(Offset.zero) ?? Offset.zero;
    final size = box?.size ?? Size.zero;

    // Viewport-aware direction/height so the panel never renders below the
    // screen, underneath the Admin bottom navigation, or above the safe
    // top area — same approach as the redesigned Admin Users per-card menu.
    final mq = MediaQuery.of(context);
    const edgeMargin = 14.0;
    const bottomNavSafetyMargin = 84.0;
    final topSafeBound = mq.padding.top + edgeMargin;
    final bottomSafeBound =
        mq.size.height - mq.padding.bottom - bottomNavSafetyMargin - edgeMargin;

    const panelVerticalPadding = 20.0;
    const itemRowHeight = 56.0;
    final estimatedPanelHeight =
        panelVerticalPadding + items.length * itemRowHeight;

    final spaceBelow = bottomSafeBound - (pos.dy + size.height);
    final spaceAbove = pos.dy - topSafeBound;

    final bool openDownward;
    double? maxPanelHeight;
    if (spaceBelow >= estimatedPanelHeight) {
      openDownward = true;
    } else if (spaceAbove >= estimatedPanelHeight) {
      openDownward = false;
    } else {
      openDownward = spaceBelow >= spaceAbove;
      final available = openDownward ? spaceBelow : spaceAbove;
      maxPanelHeight = available.clamp(0.0, estimatedPanelHeight);
    }

    const panelWidth = 216.0;
    const rightInset = 14.0;
    final wouldOverflowLeft =
        mq.size.width - rightInset - panelWidth < edgeMargin;
    final rightOffset = wouldOverflowLeft ? edgeMargin : rightInset;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.18),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return Stack(children: [
          Positioned.fill(
              child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(color: Colors.transparent))),
          Positioned(
            right: rightOffset,
            top: openDownward ? pos.dy + size.height - 20 : null,
            bottom: openDownward ? null : mq.size.height - pos.dy - 20,
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: Offset(0.3, openDownward ? -0.2 : 0.2),
                      end: Offset.zero)
                  .animate(curved),
              child: FadeTransition(
                  opacity: anim,
                  child: _ConvActionMenuPanel(
                      items: items, maxHeight: maxPanelHeight)),
            ),
          ),
        ]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ConvThreeDotsTrigger(isBlocked: isBlocked, onOpen: _open);
  }
}

// ─── Per-conversation three-dots trigger (raised neumorphic, same 3D
// quality as the redesigned Admin Orders/Admin Users per-card trigger) ──
class _ConvThreeDotsTrigger extends StatefulWidget {
  final bool isBlocked;
  final void Function(BuildContext triggerContext) onOpen;
  const _ConvThreeDotsTrigger({required this.isBlocked, required this.onOpen});
  @override
  State<_ConvThreeDotsTrigger> createState() => _ConvThreeDotsTriggerState();
}

class _ConvThreeDotsTriggerState extends State<_ConvThreeDotsTrigger>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        _ctrl.forward();
      },
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onOpen(context);
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) =>
            Transform.scale(scale: 1.0 - 0.08 * _ctrl.value, child: child),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppAdmin.surfaceTint,
            borderRadius: BorderRadius.circular(11),
            boxShadow: const [
              BoxShadow(
                  color: AppAdmin.borderSoft,
                  blurRadius: 0,
                  offset: Offset(0, 3)),
              BoxShadow(
                  color: AppAdmin.borderSoft,
                  blurRadius: 6,
                  offset: Offset(3, 3)),
              BoxShadow(
                  color: Colors.white, blurRadius: 6, offset: Offset(-3, -3)),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
                3,
                (i) => Container(
                      width: 3.5,
                      height: 3.5,
                      margin: const EdgeInsets.symmetric(vertical: 1.2),
                      decoration: BoxDecoration(
                          color: (widget.isBlocked
                                  ? AppColors.error
                                  : AppAdmin.inkMid)
                              .withOpacity(0.75),
                          shape: BoxShape.circle),
                    )),
          ),
        ),
      ),
    );
  }
}

// ─── Per-conversation Action Menu Panel (floating, staggered animation,
// neo-3D) — same panel shell/row language as the redesigned Admin Users
// per-card action panel, including the optional scroll-clamped [maxHeight]
// for viewport safety. ────────────────────────────────────────────────
class _ConvActionMenuPanel extends StatefulWidget {
  final List<_ConvActionItemData> items;
  final double? maxHeight;
  const _ConvActionMenuPanel({required this.items, this.maxHeight});
  @override
  State<_ConvActionMenuPanel> createState() => _ConvActionMenuPanelState();
}

class _ConvActionMenuPanelState extends State<_ConvActionMenuPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320))
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<Widget> _buildItems() {
    return List.generate(widget.items.length, (i) {
      final item = widget.items[i];
      final n = widget.items.length;
      final anim = CurvedAnimation(
        parent: _ctrl,
        curve: Interval((i / n).clamp(0.0, 1.0), ((i + 1) / n).clamp(0.0, 1.0),
            curve: Curves.easeOutBack),
      );
      final c2 =
          item.iconColors.length > 1 ? item.iconColors[1] : item.iconColors[0];
      return AnimatedBuilder(
        animation: anim,
        builder: (_, child) => Opacity(
          opacity: anim.value.clamp(0.0, 1.0),
          child: Transform.scale(
              scale: 0.6 + 0.4 * anim.value.clamp(0.0, 1.0), child: child),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: GestureDetector(
            onTap: () {
              Navigator.pop(context);
              item.onTap();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: AppAdmin.surfaceTint,
                boxShadow: const [
                  BoxShadow(
                      color: AppAdmin.borderSoft,
                      blurRadius: 6,
                      offset: Offset(3, 3)),
                  BoxShadow(
                      color: Colors.white,
                      blurRadius: 6,
                      offset: Offset(-3, -3)),
                ],
              ),
              child: Row(children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: item.iconColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                          color: item.iconColors[0].withOpacity(0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 3)),
                      BoxShadow(
                          color: c2.withOpacity(0.9),
                          blurRadius: 0,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Stack(children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 15,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(11),
                              topRight: Radius.circular(11)),
                          gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withOpacity(0.22),
                                Colors.transparent
                              ]),
                        ),
                      ),
                    ),
                    Center(
                        child: Icon(item.icon, color: Colors.white, size: 16)),
                  ]),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(item.label,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: item.labelColor))),
              ]),
            ),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget list = widget.maxHeight == null
        ? Column(mainAxisSize: MainAxisSize.min, children: _buildItems())
        : ConstrainedBox(
            constraints: BoxConstraints(maxHeight: widget.maxHeight!),
            child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min, children: _buildItems()),
            ),
          );

    return Container(
      width: 216,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: AppAdmin.surfaceTint,
        boxShadow: const [
          BoxShadow(
              color: AppAdmin.borderSoft, blurRadius: 18, offset: Offset(7, 7)),
          BoxShadow(
              color: Colors.white, blurRadius: 18, offset: Offset(-7, -7)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: list,
    );
  }
}

// ─── Monitor Chat Screen (Full Page) — Phase 6G: Firestore-backed, read-only ──
class MonitorChatScreen extends ConsumerWidget {
  final ConversationModel conv;
  const MonitorChatScreen({super.key, required this.conv});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Phase 4D2: combined chronological timeline (messages, including any
    // legacy adminWarning docs left in place, merged with new adminWarnings)
    // — see adminChatTimelineForConversationProvider.
    final messagesAsync =
        ref.watch(adminChatTimelineForConversationProvider(conv.id));
    final messages = messagesAsync.value ?? const <AdminChatTimelineEntry>[];

    final names =
        conv.participantNames.values.where((n) => n.isNotEmpty).toList();
    final title = names.isEmpty
        ? (conv.id.isEmpty ? 'Unknown participants' : conv.id)
        : names.join(' & ');
    final roles = conv.participantRoles.values.toSet().toList();
    final primaryRole = roles.isNotEmpty ? roles.first : null;
    final rg = _roleColors(primaryRole);
    // Two-participant conversation summary — show the non-admin participant's
    // photo (falls back to the first participant if the admin isn't one).
    final adminId = _adminIdOf(ref);
    final otherParticipantId = conv.participantIds.firstWhere(
        (id) => id != adminId,
        orElse: () =>
            conv.participantIds.isNotEmpty ? conv.participantIds.first : '');
    final otherParticipant = otherParticipantId.isNotEmpty
        ? ref.watch(userByIdProvider(otherParticipantId)).valueOrNull
        : null;

    return Scaffold(
      backgroundColor: AppAdmin.surfaceTint,
      body: Column(children: [
        // ── Header — same premium lilac/3D depth language as the redesigned
        // Admin Orders/Admin Users/Chat Management header (3-stop gradient,
        // tinted drop shadow). All chips/actions below are laid out with
        // Wrap instead of a rigid Row so nothing can overflow the header's
        // bounds on narrow widths — same actions/behavior as before. ───────
        Container(
          decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [
                AppAdmin.inkDarkest,
                AppAdmin.darkest,
                AppAdmin.dark
              ], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                    color: Color(0x60321143),
                    blurRadius: 24,
                    offset: Offset(0, 10)),
              ]),
          child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                child: Column(children: [
                  Row(children: [
                    // Back button
                    GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.2))),
                            child: const Icon(Icons.arrow_back_ios_new_rounded,
                                color: Colors.white, size: 17))),
                    const SizedBox(width: 12),
                    // Avatar 3D
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: rg,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: rg[0].withOpacity(0.5),
                                blurRadius: 10,
                                offset: const Offset(0, 4)),
                            BoxShadow(
                                color: rg[1],
                                blurRadius: 0,
                                offset: const Offset(0, 3)),
                          ]),
                      child: ProfileAvatarImage(
                        imageUrl: otherParticipant?.avatar,
                        size: 44,
                        fallbackText: title,
                        fallbackTextStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white)),
                          const SizedBox(height: 6),
                          // Role/Monitor Mode/Blocked chips wrap instead of a
                          // rigid Row so they never overflow the header's
                          // bounds on narrow widths — same chips, same
                          // conditions as before.
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              for (final role in roles)
                                Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                            colors: _roleColors(role)),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                              color: _roleColors(role)[0]
                                                  .withOpacity(0.4),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2)),
                                          BoxShadow(
                                              color: _roleColors(role)[1],
                                              blurRadius: 0,
                                              offset: const Offset(0, 2)),
                                        ]),
                                    child: Text(_roleLabel(role),
                                        style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white))),
                              Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color:
                                              Colors.white.withOpacity(0.25))),
                                  child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.visibility_outlined,
                                            size: 10, color: Colors.white70),
                                        SizedBox(width: 4),
                                        Text('Monitor Mode',
                                            style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white70)),
                                      ])),
                              if (conv.isBlocked)
                                Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                        gradient: const LinearGradient(colors: [
                                          Color(0xFFEF4444),
                                          Color(0xFF991B1B)
                                        ]),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: const [
                                          BoxShadow(
                                              color: Color(0x55EF4444),
                                              blurRadius: 4,
                                              offset: Offset(0, 2)),
                                          BoxShadow(
                                              color: Color(0xFF991B1B),
                                              blurRadius: 0,
                                              offset: Offset(0, 2)),
                                        ]),
                                    child: const Text('BLOCKED',
                                        style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white))),
                            ],
                          ),
                        ])),
                  ]),
                  const SizedBox(height: 14),
                  // ── Stats strip — info chips and actions each wrap in
                  // their own row instead of a single fixed Row+Spacer, so
                  // "Send Warning"/"Admin View" reflow onto their own line
                  // rather than overflowing the header on narrow widths.
                  // Same content, same actions/behavior as before.
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.18))),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 14,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _monitorStatChip(
                                  icon: Icons.message_outlined,
                                  label: '${messages.length} Messages'),
                              _monitorStatChip(
                                  icon: Icons.visibility_outlined,
                                  label: 'Read Only'),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // Admin moderation action — only inside this
                              // single-conversation monitor view (see
                              // _showSendWarningDialog).
                              GestureDetector(
                                onTap: () =>
                                    _showSendWarningDialog(context, ref, conv),
                                child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                        gradient: const LinearGradient(colors: [
                                          Color(0xFFF59E0B),
                                          Color(0xFFB45309)
                                        ]),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: const [
                                          BoxShadow(
                                              color: Color(0x55B45309),
                                              blurRadius: 4,
                                              offset: Offset(0, 2)),
                                        ]),
                                    child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.warning_amber_rounded,
                                              size: 13, color: Colors.white),
                                          SizedBox(width: 5),
                                          Text('Send Warning',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w800)),
                                        ])),
                              ),
                              Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color:
                                              Colors.white.withOpacity(0.25))),
                                  child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.shield_outlined,
                                            size: 11, color: Colors.white70),
                                        SizedBox(width: 4),
                                        Text('Admin View',
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700)),
                                      ])),
                            ],
                          ),
                        ]),
                  ),
                ]),
              )),
        ),

        // ── Messages List ──
        Expanded(
            child: messagesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) {
            debugPrint('ADMIN_CHAT_LOAD_ERROR [MonitorChatScreen]: $e');
            return const Center(
                child: Text('Error loading messages',
                    style: TextStyle(color: Colors.red, fontSize: 13)));
          },
          data: (msgs) => msgs.isEmpty
              ? const Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      Icon(Icons.chat_bubble_outline_rounded,
                          size: 56, color: AppAdmin.lightest),
                      SizedBox(height: 12),
                      Text('No messages in this conversation',
                          style: TextStyle(
                              color: AppAdmin.mid,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ]))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  itemCount: msgs.length,
                  itemBuilder: (ctx, i) => _MessageBubble(
                      message: msgs[i].message,
                      source: msgs[i].source,
                      conv: conv),
                ),
        )),

        // ── Bottom Bar (monitor notice) ──
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          decoration:
              BoxDecoration(color: AppAdmin.surfaceTint, boxShadow: const [
            BoxShadow(
                color: AppAdmin.borderSoft,
                blurRadius: 0,
                offset: Offset(0, -3)),
            BoxShadow(
                color: AppAdmin.borderSoft,
                blurRadius: 10,
                offset: Offset(0, -6)),
            BoxShadow(
                color: Colors.white, blurRadius: 10, offset: Offset(0, 4)),
          ]),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            decoration: BoxDecoration(
                color: AppAdmin.surfaceTint,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                      color: AppAdmin.borderSoft,
                      blurRadius: 0,
                      offset: Offset(0, 3)),
                  BoxShadow(
                      color: AppAdmin.borderSoft,
                      blurRadius: 6,
                      offset: Offset(3, 3)),
                  BoxShadow(
                      color: Colors.white,
                      blurRadius: 6,
                      offset: Offset(-3, -3)),
                ]),
            child: Row(children: [
              Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [AppAdmin.dark, AppAdmin.darkest]),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x44000000),
                            blurRadius: 4,
                            offset: Offset(0, 2)),
                      ]),
                  child: const Icon(Icons.lock_outline_rounded,
                      size: 14, color: Colors.white)),
              const SizedBox(width: 10),
              const Text('You are in monitor mode — read only',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppAdmin.mid)),
            ]),
          ),
        ),
      ]),
    );
  }
}

// Opens the Send Warning dialog for the currently-monitored conversation.
// Admin-only moderation action, scoped to this one open conversation.
void _showSendWarningDialog(
    BuildContext context, WidgetRef ref, ConversationModel conv) {
  showAdminChatModal(
    context: context,
    builder: (_) => _SendWarningDialog(conv: conv),
  );
}

// ─── Send Warning Dialog ────────────────────────────────────────────────────
// Recipient targeting always uses conv.participantIds (real Firestore UIDs)
// — never name/email lookup. "Both Participants" targets every id in that
// list; a single choice targets only that one real UID.
class _SendWarningDialog extends ConsumerStatefulWidget {
  final ConversationModel conv;
  const _SendWarningDialog({required this.conv});
  @override
  ConsumerState<_SendWarningDialog> createState() => _SendWarningDialogState();
}

class _SendWarningDialogState extends ConsumerState<_SendWarningDialog> {
  final _ctrl = TextEditingController();
  // null = Both Participants; otherwise one real participant UID from
  // conv.participantIds.
  String? _selectedId;
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.fixed));
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _busy) return;
    final admin = ref.read(authProvider);
    if (admin == null) return;

    final targets =
        _selectedId == null ? widget.conv.participantIds : [_selectedId!];
    if (targets.isEmpty) {
      _snack('No valid recipient for this conversation.', AppColors.error);
      return;
    }

    setState(() => _busy = true);
    try {
      final ok = await sendAdminWarningMessage(
        conversationId: widget.conv.id,
        adminId: admin.id,
        text: text,
        targetUserIds: targets,
      );
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context);
        _snack('Warning sent successfully.', AppAdmin.dark);
      } else {
        _snack('Failed to send warning. Please try again.', AppColors.error);
      }
    } catch (e) {
      if (mounted) {
        _snack('Failed to send warning. Please try again.', AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conv = widget.conv;
    final choices = <_WarningRecipientChoice>[
      const _WarningRecipientChoice(id: null, label: 'Both Participants'),
      for (final pid in conv.participantIds)
        _WarningRecipientChoice(
          id: pid,
          label: (conv.participantNames[pid]?.isNotEmpty ?? false)
              ? conv.participantNames[pid]!
              : 'Unknown User',
          role: conv.participantRoles[pid],
        ),
    ];
    final canSend = !_busy && _ctrl.text.trim().isNotEmpty;

    // Same premium bottom-sheet chrome as _ChatModalShell (Block/Unblock
    // Conversation) and the Admin Users modal shell — content/logic below
    // (recipient targeting, validation, send handling) is unchanged.
    return _ChatModalShell(
      icon: Icons.warning_amber_rounded,
      title: 'Send Warning',
      subtitle:
          conv.participantNames.values.where((n) => n.isNotEmpty).join(' & '),
      accentColor: const Color(0xFFF59E0B),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Warning Message',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppAdmin.darkest)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                  color: AppAdmin.borderSoft,
                  blurRadius: 6,
                  offset: Offset(3, 3)),
              BoxShadow(
                  color: Colors.white, blurRadius: 6, offset: Offset(-3, -3)),
            ],
          ),
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            maxLines: 4,
            minLines: 3,
            enabled: !_busy,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 14, color: AppAdmin.inkDark),
            decoration: InputDecoration(
                hintText: 'Enter the warning message...',
                hintStyle: TextStyle(
                    color: AppAdmin.mid.withOpacity(0.8), fontSize: 13),
                filled: true,
                fillColor: AppAdmin.warm,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppAdmin.dark, width: 1.6))),
          ),
        ),
        const SizedBox(height: 18),
        const Text('Send To',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppAdmin.darkest)),
        const SizedBox(height: 8),
        for (final c in choices)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: _busy ? null : () => setState(() => _selectedId = c.id),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedId == c.id
                      ? AppAdmin.dark.withOpacity(0.08)
                      : AppAdmin.surfaceTint,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: _selectedId == c.id
                          ? AppAdmin.dark
                          : Colors.transparent,
                      width: 1.6),
                  boxShadow: _selectedId == c.id
                      ? null
                      : const [
                          BoxShadow(
                              color: AppAdmin.borderSoft,
                              blurRadius: 5,
                              offset: Offset(2, 2)),
                          BoxShadow(
                              color: Colors.white,
                              blurRadius: 5,
                              offset: Offset(-2, -2)),
                        ],
                ),
                child: Row(children: [
                  Icon(
                      _selectedId == c.id
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      size: 18,
                      color:
                          _selectedId == c.id ? AppAdmin.dark : AppAdmin.mid),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(c.label,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppAdmin.darkest)),
                        if (c.role != null && c.role!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(_roleLabel(c.role),
                                style: const TextStyle(
                                    fontSize: 11, color: AppAdmin.mid)),
                          ),
                      ])),
                ]),
              ),
            ),
          ),
      ]),
      footer: Row(children: [
        Expanded(
            child: OutlinedButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppAdmin.dark,
                    side: const BorderSide(color: AppAdmin.lightest),
                    minimumSize: const Size(0, 46),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: const Text('Cancel',
                    style: TextStyle(fontWeight: FontWeight.w700)))),
        const SizedBox(width: 10),
        Expanded(
            child: ElevatedButton.icon(
                onPressed: canSend ? _send : null,
                icon: _busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.warning_amber_rounded, size: 15),
                label: Text(_busy ? 'Sending...' : 'Send Warning',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB45309),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        const Color(0xFFB45309).withOpacity(0.5),
                    minimumSize: const Size(0, 46),
                    padding: EdgeInsets.zero,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))))),
      ]),
    );
  }
}

class _WarningRecipientChoice {
  final String? id;
  final String label;
  final String? role;
  const _WarningRecipientChoice(
      {required this.id, required this.label, this.role});
}

Widget _monitorStatChip({required IconData icon, required String label}) {
  return Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 12, color: Colors.white70),
    const SizedBox(width: 5),
    Text(label,
        style: const TextStyle(
            fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600)),
  ]);
}

// ─── Stat Chip (used in Monitor header) ──────────────────────────────────────
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: Colors.white70),
      const SizedBox(width: 4),
      Text(label,
          style: const TextStyle(
              fontSize: 11,
              color: Colors.white70,
              fontWeight: FontWeight.w500)),
    ]);
  }
}

// ─── Message Bubble — Phase 6G: real MessageModel, read-only ─────────────────
class _MessageBubble extends ConsumerWidget {
  final MessageModel message;
  // Phase 4D2: which collection this entry actually came from — never
  // inferred from `message.type` alone, since a legacy type=='adminWarning'
  // document left inside messages (Phase 4D1 6b) and a new one in
  // adminWarnings are otherwise indistinguishable. Determines which
  // Firestore Rules-governed collection the Hide action must update.
  final AdminChatEntrySource source;
  final ConversationModel conv;
  const _MessageBubble(
      {required this.message, required this.source, required this.conv});

  Future<void> _hideMessage(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirmModerationAction(context,
        title: 'Hide Message',
        message:
            'Hide this message? This will replace it with a deleted-message placeholder.',
        confirmLabel: 'Hide',
        confirmColor: AppColors.error);
    if (!confirmed) return;
    try {
      if (source == AdminChatEntrySource.adminWarning) {
        await adminHideAdminWarningInFirestore(
            conversationId: conv.id,
            warningId: message.id,
            adminId: _adminIdOf(ref),
            adminName: _adminNameOf(ref));
      } else {
        await adminHideMessageInFirestore(
            conversationId: conv.id,
            messageId: message.id,
            adminId: _adminIdOf(ref),
            adminName: _adminNameOf(ref));
      }
      if (context.mounted)
        _showModerationSnack(context, 'Message hidden', AppAdmin.dark);
    } catch (e) {
      if (context.mounted)
        _showModerationSnack(
            context, 'Failed to hide message', AppColors.error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final senderName =
        conv.participantNames[message.senderId] ?? message.senderId;
    final senderRole = conv.participantRoles[message.senderId];
    final roleColor = _roleColors(senderRole)[0];
    final del = message.isDeleted;
    final sender = message.senderId.isNotEmpty
        ? ref.watch(userByIdProvider(message.senderId)).valueOrNull
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.15), shape: BoxShape.circle),
              child: ProfileAvatarImage(
                  imageUrl: sender?.avatar,
                  size: 34,
                  fallbackText: senderName,
                  fallbackTextStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: roleColor))),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(senderName,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppAdmin.darkest)),
                      const SizedBox(width: 6),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: roleColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6)),
                          child: Text(_roleLabel(senderRole),
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: roleColor))),
                    ],
                  ),
                ),
                // Bubble
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                          bottomLeft: Radius.circular(4),
                          bottomRight: Radius.circular(16)),
                      border: Border.all(color: AppAdmin.lightest),
                      boxShadow: [
                        BoxShadow(
                            color: AppAdmin.darkest.withOpacity(0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2))
                      ]),
                  child: _buildContent(del),
                ),
                // Time
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                      '${message.sentAt.hour.toString().padLeft(2, '0')}:'
                      '${message.sentAt.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 9, color: AppAdmin.mid)),
                ),
              ],
            ),
          ),
          if (!del)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  size: 16, color: AppAdmin.mid),
              padding: EdgeInsets.zero,
              onSelected: (val) {
                if (val == 'hide') _hideMessage(context, ref);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'hide', child: Text('Hide Message')),
              ],
            ),
        ],
      ),
    );
  }

  // "Sent to both participants" when targetUserIds covers more than one
  // recipient, otherwise the single targeted participant's real name/role
  // from conv.participantNames/participantRoles (never name/email lookup).
  String _warningRecipientLabel() {
    final targets = message.targetUserIds;
    if (targets.length > 1) return 'Sent to both participants';
    if (targets.length == 1) {
      final id = targets.first;
      final name = conv.participantNames[id];
      final label = (name != null && name.isNotEmpty) ? name : 'Unknown User';
      final role = conv.participantRoles[id];
      return (role != null && role.isNotEmpty)
          ? 'Sent to $label — ${_roleLabel(role)}'
          : 'Sent to $label';
    }
    return 'Sent to unknown recipient';
  }

  Widget _buildContent(bool del) {
    if (del) {
      return const Text('This message was deleted',
          style: TextStyle(
              fontSize: 13, fontStyle: FontStyle.italic, color: AppAdmin.mid));
    }
    if (message.type == MessageType.adminWarning) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.warning_amber_rounded, size: 15, color: Color(0xFFB45309)),
          SizedBox(width: 6),
          Text('Admin Warning',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFB45309))),
        ]),
        const SizedBox(height: 6),
        Text(message.text,
            style: const TextStyle(
                fontSize: 13, color: AppAdmin.darkest, height: 1.4)),
        const SizedBox(height: 6),
        Text(_warningRecipientLabel(),
            style: const TextStyle(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: AppAdmin.mid)),
      ]);
    }
    if (message.type == MessageType.image) {
      final url = message.imageUrl ?? message.mediaUrl;
      return _ImagePreview(url: url, caption: message.text);
    }
    if (message.type == MessageType.voice) {
      return _VoiceBubble(message: message);
    }
    return Text(message.text,
        style: const TextStyle(
            fontSize: 13, color: AppAdmin.darkest, height: 1.4));
  }
}

class _ImagePreview extends StatelessWidget {
  final String? url;
  final String caption;
  const _ImagePreview({required this.url, required this.caption});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return const Text('[Image unavailable]',
          style: TextStyle(
              fontSize: 12, color: AppAdmin.mid, fontStyle: FontStyle.italic));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          url!,
          width: 200,
          height: 150,
          fit: BoxFit.cover,
          loadingBuilder: (ctx, child, progress) => progress == null
              ? child
              : const SizedBox(
                  width: 200,
                  height: 150,
                  child:
                      Center(child: CircularProgressIndicator(strokeWidth: 2))),
          errorBuilder: (ctx, err, st) => const SizedBox(
              width: 200,
              height: 150,
              child: Center(
                  child:
                      Icon(Icons.broken_image_outlined, color: AppAdmin.mid))),
        ),
      ),
      if (caption.isNotEmpty && caption != 'Photo' && caption != '[Image]') ...[
        const SizedBox(height: 6),
        Text(caption,
            style: const TextStyle(fontSize: 12, color: AppAdmin.darkest)),
      ],
    ]);
  }
}

class _VoiceBubble extends StatefulWidget {
  final MessageModel message;
  const _VoiceBubble({required this.message});
  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble> {
  final _player = AudioPlayer();
  bool _playing = false;
  bool _failed = false;

  String? get _url {
    final m = widget.message;
    if (m.voiceUrl != null && m.voiceUrl!.isNotEmpty) return m.voiceUrl;
    if (m.audioUrl != null && m.audioUrl!.isNotEmpty) return m.audioUrl;
    if (m.mediaUrl != null && m.mediaUrl!.isNotEmpty) return m.mediaUrl;
    return null;
  }

  Future<void> _toggle() async {
    final url = _url;
    if (url == null) return;
    if (_playing) {
      await _player.pause();
      if (mounted) setState(() => _playing = false);
      return;
    }
    try {
      await _player.setUrl(url);
      _player.play();
      if (mounted)
        setState(() {
          _playing = true;
          _failed = false;
        });
      _player.playerStateStream.listen((s) {
        if (s.processingState == ProcessingState.completed && mounted) {
          setState(() => _playing = false);
        }
      });
    } catch (e) {
      debugPrint('ADMIN_CHAT_VOICE_PLAY_ERROR: $e');
      if (mounted)
        setState(() {
          _playing = false;
          _failed = true;
        });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dur = widget.message.voiceDurationSec;
    final durLabel = dur != null
        ? '${(dur ~/ 60).toString().padLeft(2, '0')}:${(dur % 60).toString().padLeft(2, '0')}'
        : '--:--';

    if (_url == null) {
      return const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.mic_none_rounded, size: 16, color: AppAdmin.mid),
        SizedBox(width: 6),
        Text('Voice message',
            style: TextStyle(
                fontSize: 12,
                color: AppAdmin.mid,
                fontStyle: FontStyle.italic)),
      ]);
    }

    return Row(mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(
        onTap: _toggle,
        child: Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
              gradient:
                  LinearGradient(colors: [AppAdmin.dark, AppAdmin.darkest]),
              shape: BoxShape.circle),
          child: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white, size: 18),
        ),
      ),
      const SizedBox(width: 10),
      Text(_failed ? 'Playback failed' : durLabel,
          style: TextStyle(
              fontSize: 12,
              color: _failed ? AppColors.error : AppAdmin.mid,
              fontWeight: FontWeight.w600)),
    ]);
  }
}

// ─── Quick Replies Tab ────────────────────────────────────────────────────────
class _QuickRepliesTab extends ConsumerStatefulWidget {
  const _QuickRepliesTab();
  @override
  ConsumerState<_QuickRepliesTab> createState() => _QuickRepliesTabState();
}

class _QuickRepliesTabState extends ConsumerState<_QuickRepliesTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Seeds the 12 shipped defaults the first time an admin opens this tab.
    // ensureDefaultQuickRepliesSeeded only creates documents whose stable ids
    // are missing, so this is safe to call on every open: it never duplicates
    // a default, never overwrites an edited one, never resurrects a deleted
    // one, and never touches admin-created replies. Deliberately not awaited —
    // adminQuickRepliesProvider is a live snapshot listener, so the seeded
    // replies appear on their own as soon as the write lands.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ensureDefaultQuickRepliesSeeded(createdBy: ref.read(authProvider)?.id);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _snack(BuildContext context, String msg, Color color) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  void _addReply(BuildContext context) {
    showAdminChatModal(
        context: context,
        builder: (_) => _QuickReplyDialog(onSave: (text) async {
              try {
                await createQuickReplyInFirestore(
                    text: text, createdBy: ref.read(authProvider)?.id);
                _snack(context, 'Quick reply added', AppAdmin.dark);
              } catch (e) {
                _snack(context, 'Failed to add quick reply', AppColors.error);
              }
            }));
  }

  void _editReply(BuildContext context, QuickReplyModel reply) {
    showAdminChatModal(
        context: context,
        builder: (_) => _QuickReplyDialog(
            initial: reply.text,
            onSave: (text) async {
              try {
                await updateQuickReplyInFirestore(
                    replyId: reply.id, text: text);
                _snack(context, 'Quick reply updated', AppAdmin.dark);
              } catch (e) {
                _snack(
                    context, 'Failed to update quick reply', AppColors.error);
              }
            }));
  }

  Future<void> _toggleActive(
      BuildContext context, QuickReplyModel reply) async {
    try {
      if (reply.isActive) {
        await deleteQuickReplyInFirestore(reply.id);
      } else {
        await updateQuickReplyInFirestore(replyId: reply.id, isActive: true);
      }
      _snack(
          context,
          reply.isActive
              ? 'Quick reply deactivated'
              : 'Quick reply reactivated',
          reply.isActive ? AppColors.error : AppColors.success);
    } catch (e) {
      _snack(context, 'Failed to update quick reply', AppColors.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repliesAsync = ref.watch(adminQuickRepliesProvider);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Row(children: [
          const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Quick Replies',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppAdmin.inkDarkest)),
                Text('These appear in chat for all user roles',
                    style: TextStyle(fontSize: 11, color: AppAdmin.mid)),
              ])),
          // Add Reply button 3D
          GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _addReply(context);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppAdmin.dark, AppAdmin.darkest],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: AppAdmin.dark.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4)),
                      const BoxShadow(
                          color: AppAdmin.darkest,
                          blurRadius: 0,
                          offset: Offset(0, 3)),
                    ]),
                child: Stack(children: [
                  Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                          height: 14,
                          decoration: BoxDecoration(
                              borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                  topRight: Radius.circular(20)),
                              gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withOpacity(0.2),
                                    Colors.transparent
                                  ])))),
                  const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 5),
                    Text('Add Reply',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                  ]),
                ]),
              )),
        ]),
      ),
      // ── Search field ──
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: Container(
          decoration: BoxDecoration(
              color: AppAdmin.surfaceTint,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                    color: AppAdmin.borderSoft,
                    blurRadius: 0,
                    offset: Offset(0, 3)),
                BoxShadow(
                    color: AppAdmin.borderSoft,
                    blurRadius: 6,
                    offset: Offset(3, 3)),
                BoxShadow(
                    color: Colors.white, blurRadius: 6, offset: Offset(-3, -3)),
              ]),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppAdmin.inkDarkest),
            decoration: InputDecoration(
                hintText: 'Search quick replies...',
                hintStyle: const TextStyle(color: AppAdmin.mid, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppAdmin.mid, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            size: 16, color: AppAdmin.dark),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        })
                    : null),
          ),
        ),
      ),
      Expanded(
          child: repliesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) {
          debugPrint('QUICK_REPLIES_LOAD_ERROR [AdminQuickRepliesTab]: $e');
          return const Center(
              child: Text('Failed to load quick replies',
                  style: TextStyle(color: Colors.red, fontSize: 13)));
        },
        data: (all) {
          final q = _query.trim().toLowerCase();
          final replies = q.isEmpty
              ? all
              : all.where((r) => r.text.toLowerCase().contains(q)).toList();
          if (replies.isEmpty) {
            return const Center(
                child: Text('No quick replies yet.',
                    style: TextStyle(color: AppAdmin.mid)));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: replies.length,
            itemBuilder: (ctx, i) {
              final r = replies[i];
              // Premium 3D card shell — same structured language as the
              // redesigned Admin Orders/Conversation cards (tinted border,
              // tri-shadow stack, slim top accent bar), replacing the old
              // flat card. Same displayed info (text + Inactive label,
              // dimmed via Opacity when inactive) as before.
              return Opacity(
                opacity: r.isActive ? 1 : 0.55,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppAdmin.surfaceTint,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFF10B981).withOpacity(0.16),
                        width: 1),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x2610B981),
                          blurRadius: 0,
                          offset: Offset(0, 5)),
                      BoxShadow(
                          color: Color(0x1A10B981),
                          blurRadius: 16,
                          offset: Offset(0, 8)),
                      BoxShadow(
                          color: Colors.white,
                          blurRadius: 8,
                          offset: Offset(-4, -4)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 4,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF10B981),
                                    Color(0x5510B981)
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Icon 3D
                                  Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF10B981),
                                                Color(0xFF065F46)
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          boxShadow: const [
                                            BoxShadow(
                                                color: Color(0x5510B981),
                                                blurRadius: 6,
                                                offset: Offset(0, 3)),
                                            BoxShadow(
                                                color: Color(0xFF065F46),
                                                blurRadius: 0,
                                                offset: Offset(0, 2)),
                                          ]),
                                      child: Stack(children: [
                                        Positioned(
                                            top: 0,
                                            left: 0,
                                            right: 0,
                                            child: Container(
                                                height: 16,
                                                decoration: BoxDecoration(
                                                    borderRadius:
                                                        const BorderRadius.only(
                                                            topLeft:
                                                                Radius.circular(
                                                                    12),
                                                            topRight:
                                                                Radius.circular(
                                                                    12)),
                                                    gradient: LinearGradient(
                                                        begin:
                                                            Alignment.topCenter,
                                                        end: Alignment
                                                            .bottomCenter,
                                                        colors: [
                                                          Colors.white
                                                              .withOpacity(
                                                                  0.22),
                                                          Colors.transparent
                                                        ])))),
                                        const Center(
                                            child: Icon(
                                                Icons.quickreply_rounded,
                                                size: 17,
                                                color: Colors.white)),
                                      ])),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(r.text,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: AppAdmin.inkDarkest)),
                                        if (!r.isActive) ...[
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                                color: AppColors.error
                                                    .withOpacity(0.10),
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                            child: const Text('Inactive',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.error)),
                                          ),
                                        ],
                                      ])),
                                  const SizedBox(width: 6),
                                  // Three-dots trigger/panel — same premium
                                  // neumorphic language and viewport-safe
                                  // behavior as the redesigned Conversation
                                  // per-card menu. Same two actions (Edit /
                                  // Deactivate-Reactivate) and handlers.
                                  _QuickReplyThreeDotsMenu(
                                    isActive: r.isActive,
                                    onEdit: () {
                                      HapticFeedback.lightImpact();
                                      _editReply(context, r);
                                    },
                                    onToggle: () {
                                      HapticFeedback.lightImpact();
                                      _toggleActive(context, r);
                                    },
                                  ),
                                ]),
                          ),
                        ]),
                  ),
                ),
              );
            },
          );
        },
      )),
    ]);
  }
}

// ─── Per-quick-reply three-dots menu — reuses the same premium trigger
// (_ConvThreeDotsTrigger), floating panel (_ConvActionMenuPanel) and item
// data (_ConvActionItemData) classes built for the redesigned Conversation
// per-card menu, since none of them reference conversation-specific state.
// Same two actions (Edit / Deactivate-Reactivate) and same handlers
// dispatched by _QuickRepliesTabState as before — presentation only. ─────
class _QuickReplyThreeDotsMenu extends StatelessWidget {
  final bool isActive;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  const _QuickReplyThreeDotsMenu({
    required this.isActive,
    required this.onEdit,
    required this.onToggle,
  });

  void _open(BuildContext context) {
    HapticFeedback.lightImpact();
    final items = [
      _ConvActionItemData(
        icon: Icons.edit_outlined,
        label: 'Edit',
        iconColors: [AppAdmin.dark, AppAdmin.darkest],
        labelColor: AppAdmin.inkDarkest,
        onTap: onEdit,
      ),
      _ConvActionItemData(
        icon: isActive
            ? Icons.visibility_off_outlined
            : Icons.visibility_outlined,
        label: isActive ? 'Deactivate' : 'Reactivate',
        iconColors: isActive
            ? [const Color(0xFFEF4444), const Color(0xFF991B1B)]
            : [const Color(0xFF10B981), const Color(0xFF065F46)],
        labelColor: isActive ? AppColors.error : AppColors.success,
        onTap: onToggle,
      ),
    ];

    final box = context.findRenderObject() as RenderBox?;
    final pos = box?.localToGlobal(Offset.zero) ?? Offset.zero;
    final size = box?.size ?? Size.zero;

    // Same viewport-aware direction/height logic as _ConvThreeDotsMenu._open.
    final mq = MediaQuery.of(context);
    const edgeMargin = 14.0;
    const bottomNavSafetyMargin = 84.0;
    final topSafeBound = mq.padding.top + edgeMargin;
    final bottomSafeBound =
        mq.size.height - mq.padding.bottom - bottomNavSafetyMargin - edgeMargin;

    const panelVerticalPadding = 20.0;
    const itemRowHeight = 56.0;
    final estimatedPanelHeight =
        panelVerticalPadding + items.length * itemRowHeight;

    final spaceBelow = bottomSafeBound - (pos.dy + size.height);
    final spaceAbove = pos.dy - topSafeBound;

    final bool openDownward;
    double? maxPanelHeight;
    if (spaceBelow >= estimatedPanelHeight) {
      openDownward = true;
    } else if (spaceAbove >= estimatedPanelHeight) {
      openDownward = false;
    } else {
      openDownward = spaceBelow >= spaceAbove;
      final available = openDownward ? spaceBelow : spaceAbove;
      maxPanelHeight = available.clamp(0.0, estimatedPanelHeight);
    }

    const panelWidth = 216.0;
    const rightInset = 14.0;
    final wouldOverflowLeft =
        mq.size.width - rightInset - panelWidth < edgeMargin;
    final rightOffset = wouldOverflowLeft ? edgeMargin : rightInset;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.18),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return Stack(children: [
          Positioned.fill(
              child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(color: Colors.transparent))),
          Positioned(
            right: rightOffset,
            top: openDownward ? pos.dy + size.height - 20 : null,
            bottom: openDownward ? null : mq.size.height - pos.dy - 20,
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: Offset(0.3, openDownward ? -0.2 : 0.2),
                      end: Offset.zero)
                  .animate(curved),
              child: FadeTransition(
                  opacity: anim,
                  child: _ConvActionMenuPanel(
                      items: items, maxHeight: maxPanelHeight)),
            ),
          ),
        ]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ConvThreeDotsTrigger(isBlocked: false, onOpen: _open);
  }
}

// ─── Quick Reply Add/Edit Dialog ──────────────────────────────────────────────
class _QuickReplyDialog extends StatefulWidget {
  final String? initial;
  final void Function(String) onSave;
  const _QuickReplyDialog({this.initial, required this.onSave});
  @override
  State<_QuickReplyDialog> createState() => _QuickReplyDialogState();
}

class _QuickReplyDialogState extends State<_QuickReplyDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Same premium bottom-sheet chrome as _ChatModalShell (Block/Unblock
    // Conversation, Send Warning) — validation/save logic below unchanged.
    return _ChatModalShell(
      icon: Icons.quickreply_rounded,
      title: widget.initial != null ? 'Edit Quick Reply' : 'Add Quick Reply',
      accentColor: AppAdmin.accent,
      body: Form(
          key: _formKey,
          child: TextFormField(
              controller: _ctrl,
              autofocus: true,
              maxLines: 3,
              minLines: 1,
              style: const TextStyle(fontSize: 14, color: AppAdmin.inkDark),
              decoration: InputDecoration(
                  labelText: 'Quick Reply Text',
                  labelStyle: const TextStyle(
                      color: AppAdmin.dark,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                  prefixIcon: const Icon(Icons.chat_bubble_outline_rounded,
                      color: AppAdmin.dark, size: 18),
                  filled: true,
                  fillColor: AppAdmin.warm,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: AppAdmin.dark, width: 1.6)),
                  errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: AppColors.error, width: 1.5))),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null)),
      footer: Row(children: [
        Expanded(
            child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppAdmin.dark,
                    side: const BorderSide(color: AppAdmin.lightest),
                    minimumSize: const Size(0, 46),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: const Text('Cancel',
                    style: TextStyle(fontWeight: FontWeight.w700)))),
        const SizedBox(width: 10),
        Expanded(
            child: ElevatedButton.icon(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    widget.onSave(_ctrl.text.trim());
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.save_outlined, size: 15),
                label: const Text('Save',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppAdmin.darkest,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 46),
                    padding: EdgeInsets.zero,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))))),
      ]),
    );
  }
}

// ─── Chat Stepper Bar (identical 3D design to Orders stepper) ─────────────────
class _ChatTabData {
  final String label;
  final IconData icon;
  final Color activeColor, darkColor;
  const _ChatTabData(
      {required this.label,
      required this.icon,
      required this.activeColor,
      required this.darkColor});
}

class _ChatStepperBar extends StatefulWidget {
  final TabController controller;
  final int convsCount;
  final ValueChanged<int> onTabChanged;
  const _ChatStepperBar({
    required this.controller,
    required this.convsCount,
    required this.onTabChanged,
  });
  @override
  State<_ChatStepperBar> createState() => _ChatStepperBarState();
}

class _ChatStepperBarState extends State<_ChatStepperBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideCtrl;
  int _prevIndex = 0;

  static const _tabs = [
    _ChatTabData(
        label: 'Conversations',
        icon: Icons.forum_rounded,
        activeColor: AppAdmin.accent,
        darkColor: AppAdmin.dark),
    _ChatTabData(
        label: 'Quick Replies',
        icon: Icons.quickreply_rounded,
        activeColor: Color(0xFF10B981),
        darkColor: Color(0xFF065F46)),
  ];

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final current = widget.controller.index;
        if (_prevIndex != current) {
          _prevIndex = current;
          _slideCtrl.forward(from: 0);
        }
        final counts = [widget.convsCount, 0];

        return Container(
          height: 56,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: AppAdmin.surfaceTint,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                  color: AppAdmin.borderSoft,
                  blurRadius: 0,
                  offset: Offset(0, 5)),
              BoxShadow(
                  color: AppAdmin.borderSoft,
                  blurRadius: 14,
                  offset: Offset(6, 6)),
              BoxShadow(
                  color: Colors.white, blurRadius: 14, offset: Offset(-6, -6)),
            ],
          ),
          child: Row(
            children: List.generate(_tabs.length, (i) {
              final isActive = current == i;
              final tab = _tabs[i];
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onTabChanged(i);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      color: isActive ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(23),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                  color: tab.activeColor.withOpacity(0.18),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4)),
                              const BoxShadow(
                                  color: AppAdmin.borderSoft,
                                  blurRadius: 4,
                                  offset: Offset(2, 2)),
                              const BoxShadow(
                                  color: Colors.white,
                                  blurRadius: 4,
                                  offset: Offset(-2, -2)),
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 260),
                            width: isActive ? 26 : 20,
                            height: isActive ? 26 : 20,
                            decoration: BoxDecoration(
                              gradient: isActive
                                  ? LinearGradient(
                                      colors: [tab.activeColor, tab.darkColor],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight)
                                  : null,
                              color: isActive ? null : Colors.transparent,
                              borderRadius:
                                  BorderRadius.circular(isActive ? 9 : 7),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                          color:
                                              tab.activeColor.withOpacity(0.45),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3)),
                                      BoxShadow(
                                          color: tab.darkColor,
                                          blurRadius: 0,
                                          offset: const Offset(0, 2)),
                                    ]
                                  : [],
                            ),
                            child: Center(
                                child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Icon(tab.icon,
                                  key: ValueKey(isActive),
                                  size: isActive ? 14 : 12,
                                  color: isActive
                                      ? Colors.white
                                      : AppAdmin.inkLight),
                            )),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                              child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 220),
                            style: TextStyle(
                              fontSize: isActive ? 11 : 10,
                              fontWeight:
                                  isActive ? FontWeight.w800 : FontWeight.w600,
                              color: isActive
                                  ? AppAdmin.inkDarkest
                                  : AppAdmin.inkLight,
                              letterSpacing: -0.2,
                            ),
                            child: Text(tab.label,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          )),
                          if (counts[i] > 0) ...[
                            const SizedBox(width: 4),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 260),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? tab.activeColor
                                    : AppAdmin.borderSoft,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: isActive
                                    ? [
                                        BoxShadow(
                                            color: tab.activeColor
                                                .withOpacity(0.4),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2)),
                                        BoxShadow(
                                            color: tab.darkColor,
                                            blurRadius: 0,
                                            offset: const Offset(0, 2)),
                                      ]
                                    : [],
                              ),
                              child: Text('${counts[i]}',
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: isActive
                                          ? Colors.white
                                          : AppAdmin.inkMid)),
                            ),
                          ],
                        ]),
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
