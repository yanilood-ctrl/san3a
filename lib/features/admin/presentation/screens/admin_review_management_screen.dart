import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/admin_providers.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/shared_widgets.dart' show ProfileAvatarImage;
import 'admin_users_screen.dart' show showAdminUserDetails, showAdminUserModal;
import '../../../auth/presentation/providers/app_providers.dart';
import '../widgets/admin_bottom_nav.dart';

// ─── Review Status / Report Enums ────────────────────────────────────────────
enum ReviewAdminStatus { visible, hidden, deleted }

enum ReviewReportType { fake, offensive, spam, none }

// ─── Admin Review Model (wraps ReviewModel with extra admin fields) ───────────
class AdminReview {
  final ReviewModel review;
  final ReviewAdminStatus status;
  final ReviewReportType reportType;
  final int reportCount;
  final DateTime? reportedAt;
  final List<String> attachments; // image paths / urls

  const AdminReview({
    required this.review,
    this.status = ReviewAdminStatus.visible,
    this.reportType = ReviewReportType.none,
    this.reportCount = 0,
    this.reportedAt,
    this.attachments = const [],
  });

  AdminReview copyWith({
    ReviewAdminStatus? status,
    ReviewReportType? reportType,
    int? reportCount,
    DateTime? reportedAt,
    List<String>? attachments,
  }) =>
      AdminReview(
        review: review,
        status: status ?? this.status,
        reportType: reportType ?? this.reportType,
        reportCount: reportCount ?? this.reportCount,
        reportedAt: reportedAt ?? this.reportedAt,
        attachments: attachments ?? this.attachments,
      );
}

// ─── Providers (Firestore-backed) ──────────────────────────────────────────────
// Review criteria: ReviewCriteriaModel + reviewCriteriaProvider now live in
// app_providers.dart (Firestore `review_criteria` collection) so both this
// screen and the customer Add Review sheet share a single source of truth.

ReviewReportType _reportTypeFromReason(String? reason) {
  if (reason == null || reason.isEmpty) return ReviewReportType.none;
  final r = reason.toLowerCase();
  if (r.contains('fake')) return ReviewReportType.fake;
  if (r.contains('offensive') || r.contains('rude') || r.contains('abuse'))
    return ReviewReportType.offensive;
  return ReviewReportType.spam;
}

AdminReview _toAdminReview(ReviewModel r) {
  final status = r.status == 'deleted'
      ? ReviewAdminStatus.deleted
      : (r.isHidden || r.status == 'hidden')
          ? ReviewAdminStatus.hidden
          : ReviewAdminStatus.visible;
  return AdminReview(
    review: r,
    status: status,
    reportType: r.reportCount > 0
        ? _reportTypeFromReason(r.reportReason)
        : ReviewReportType.none,
    reportCount: r.reportCount,
    reportedAt: r.reportCount > 0 ? r.updatedAt : null,
  );
}

// ─── Shared premium modal shell for Review Management's secondary flows ──────
// Every Review Management overlay that needs more than a snackbar (Hide/
// Unhide confirm, Warn User, Add/Edit Review Criteria) renders into this one
// shell via showAdminUserModal, so they all share the exact same entrance
// direction, backdrop, width strategy and corner language as the redesigned
// Admin Users flows. showAdminUserModal itself (admin_users_screen.dart) is
// reused directly since it's already a safe, public, zero-modification
// shared opener — only the shell widget is duplicated locally, because the
// original _AdminUserModalShell is private to that file. Visual structure
// mirrors it exactly (dark gradient header banner, glass close button, drag
// handle, scrollable body, keyboard-safe padding, constrained width/height)
// so Admin Users stays completely untouched.
class _RevModalShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color accentColor;
  final Widget body;
  final Widget? footer;
  final EdgeInsets bodyPadding;
  const _RevModalShell({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.accentColor,
    required this.body,
    this.footer,
    this.bodyPadding = const EdgeInsets.fromLTRB(20, 18, 20, 8),
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
          // Keeps the sheet from stretching edge-to-edge on wide/Web
          // viewports while still filling narrow mobile widths.
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
              // Header — dark-gradient-banner + drop-shadow + glass close
              // button, tinted per-flow by [accentColor].
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
              // Body — always scrollable so long forms/lists never overflow
              // on narrow mobile or short desktop viewports.
              Flexible(
                child: SingleChildScrollView(
                  padding: bodyPadding,
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

// ─── Shared review-moderation actions ──────────────────────────────────────
// Used by both the review-card action menu and the Review Details page so
// behavior (confirmation, Firestore write, notification) never diverges
// between the two entry points.

Future<bool> _confirmVisibilityChange(BuildContext context,
    {required bool hide}) async {
  // Hide/moderation stays a muted "caution" tone (matching the same
  // AppColors.textSecondary used for the Hidden status badge/menu item
  // elsewhere in this file) rather than Admin lilac; Unhide stays green —
  // same semantic colors as before, just presented in the premium shell.
  final accent = hide ? AppColors.textSecondary : AppColors.success;
  final result = await showAdminUserModal<bool>(
    context: context,
    builder: (_) => _RevModalShell(
      icon: hide ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      title: hide ? 'Hide this review?' : 'Unhide this review?',
      accentColor: accent,
      body: Text(
        hide
            ? 'The review will be removed from the provider\'s public profile and rating stats. Admin keeps it as a historical record.'
            : 'The review will become visible again on the provider\'s public profile and count toward rating stats.',
        style:
            const TextStyle(fontSize: 13, color: AppAdmin.inkMid, height: 1.5),
      ),
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
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 46),
                    padding: EdgeInsets.zero,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: Text(hide ? 'Hide' : 'Unhide',
                    style: const TextStyle(fontWeight: FontWeight.w700)))),
      ]),
    ),
  );
  return result ?? false;
}

// Performs the Firestore visibility write, then best-effort notifies the
// reviewer of the transition. Notification failures are swallowed by
// createReviewNotification itself, so they never roll back the write or
// surface as a false failure here.
Future<void> _setReviewVisibility(WidgetRef ref, ReviewModel r,
    {required bool hide}) async {
  final notifier = ref.read(adminReviewsProvider.notifier);
  if (hide) {
    await notifier.hideReview(r.id);
  } else {
    await notifier.restoreReview(r.id);
  }
  await createReviewNotification(
    userId: r.customerId,
    title: hide ? 'Review Hidden' : 'Review Restored',
    message: hide
        ? 'Your review was hidden by an administrator.'
        : 'Your review is visible again.',
    reviewId: r.id,
  );
}

// Sends a real, awaited warning notification to the reviewer (never the
// reviewed provider). Unlike the visibility notification above, this write
// is the primary action, so failures are NOT swallowed — they propagate so
// the Warn dialog can show an error and let the admin retry. Guards against
// writing a notification with an empty/invalid recipient id — such a
// document would still "succeed" from Firestore's point of view but could
// never match any real user in userNotificationsProvider's userId filter,
// so the admin would see a false-success snackbar while the reviewer gets
// nothing.
Future<void> _sendReviewerWarning(
    WidgetRef ref, ReviewModel r, String message) async {
  if (r.customerId.trim().isEmpty) {
    throw StateError(
        'This review has no valid reviewer id — cannot send warning.');
  }
  final users = ref.read(adminUsersProvider);
  final matches = users.where((u) => u.id == r.customerId).toList();
  if (matches.isNotEmpty) {
    ref.read(adminUsersProvider.notifier).warnUser(matches.first.id, message);
  }
  await addNotificationInFirestore(NotificationModel(
    id: '',
    userId: r.customerId,
    title: 'Warning From Administration',
    message: message,
    type: NotificationType.review,
    relatedReviewId: r.id,
    createdAt: DateTime.now(),
    createdByRole: 'admin',
  ));
}

// Bridges the Firestore `reviews` stream (allReviewsProvider) into a
// StateNotifier so existing UI (`.notifier`.hideReview/restoreReview/...)
// keeps working unchanged, while actions now write through to Firestore.
class AdminReviewsNotifier extends StateNotifier<List<AdminReview>> {
  AdminReviewsNotifier() : super(const []);

  void setReviews(List<ReviewModel> reviews) {
    state = reviews.map(_toAdminReview).toList();
  }

  Future<void> hideReview(String id) => hideReviewInFirestore(id);
  Future<void> restoreReview(String id) => unhideReviewInFirestore(id);
  Future<void> deleteReview(String id) =>
      deleteReviewInFirestore(id); // soft delete
  Future<void> markSafe(String id) => markReviewSafeInFirestore(id);
}

final adminReviewsProvider =
    StateNotifierProvider<AdminReviewsNotifier, List<AdminReview>>((ref) {
  final notifier = AdminReviewsNotifier();
  ref.listen<AsyncValue<List<ReviewModel>>>(allReviewsProvider, (prev, next) {
    next.whenData(notifier.setReviews);
  }, fireImmediately: true);
  return notifier;
});

// ─── Review Management Screen ─────────────────────────────────────────────────
class AdminReviewManagementScreen extends ConsumerStatefulWidget {
  const AdminReviewManagementScreen({super.key});
  @override
  ConsumerState<AdminReviewManagementScreen> createState() =>
      _AdminReviewManagementScreenState();
}

class _AdminReviewManagementScreenState
    extends ConsumerState<AdminReviewManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  // Guards against re-opening details for the same pending-id request across
  // rebuilds (same one-shot pattern as _AdminUsersScreenState/
  // _AdminOrdersScreenState).
  String? _lastHandledPendingReviewId;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Open the review requested by Admin Complaints ("Open Related Page")
    // once the live reviews stream has loaded, then never again for this
    // same request. allReviewsProvider (AsyncValue) gates "loaded"; the
    // actual entity is looked up in adminReviewsProvider, which is kept in
    // sync with it via ref.listen(..., fireImmediately: true).
    final reviewsLoaded = ref.watch(allReviewsProvider).hasValue;
    final adminReviews = ref.watch(adminReviewsProvider);
    final pendingReviewId = ref.watch(adminPendingReviewDetailsIdProvider);
    if (pendingReviewId != null &&
        pendingReviewId != _lastHandledPendingReviewId &&
        reviewsLoaded) {
      _lastHandledPendingReviewId = pendingReviewId;
      final matches =
          adminReviews.where((r) => r.review.id == pendingReviewId).toList();
      final matched = matches.isNotEmpty ? matches.first : null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Reset to null so this is a one-shot signal, not persistent state.
        ref.read(adminPendingReviewDetailsIdProvider.notifier).state = null;
        if (!context.mounted) return;
        if (matched != null) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => _ReviewDetailsPage(adminReview: matched)));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Related review could not be found.'),
              behavior: SnackBarBehavior.floating));
        }
      });
    }

    return Scaffold(
      backgroundColor: AppAdmin.surfaceTint,
      body: Column(children: [
        // ── Header (title / back / rating badge only — status nav lives
        // below it now, as its own elevated component) ──
        const _ReviewHeader(),
        // ── Status navigation — separate premium elevated segmented bar,
        // same visual language as the redesigned Admin Orders/Complaints
        // stepper bar. ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: _ReviewStepperBar(controller: _tab),
        ),
        // ── Tab Content ──
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: const [
              _AllReviewsTab(),
              _ReviewSettingsTab(),
            ],
          ),
        ),
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

// ─── Header ───────────────────────────────────────────────────────────────────
class _ReviewHeader extends StatelessWidget {
  const _ReviewHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            colors: [AppAdmin.darkest, AppAdmin.dark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            child: Row(children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 10),
              const Expanded(
                  child: Text('Review Management',
                      style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          color: Colors.white))),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.star_rounded,
                    color: Colors.amber, size: 16),
              ),
            ]),
          )),
    );
  }
}

// ─── Status navigation — separate premium elevated segmented bar (All
// Reviews / Review Settings), same neumorphic pill-tab language as the
// redesigned Admin Orders/Complaints stepper bars. Purely presentational,
// driven by the screen's own TabController. ──
class _ReviewTabData {
  final String label;
  final IconData icon;
  final Color activeColor;
  final Color darkColor;
  const _ReviewTabData(
      {required this.label,
      required this.icon,
      required this.activeColor,
      required this.darkColor});
}

class _ReviewStepperBar extends StatefulWidget {
  final TabController controller;
  const _ReviewStepperBar({required this.controller});
  @override
  State<_ReviewStepperBar> createState() => _ReviewStepperBarState();
}

class _ReviewStepperBarState extends State<_ReviewStepperBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideCtrl;
  int _prevIndex = 0;

  static const _tabs = [
    _ReviewTabData(
        label: 'All Reviews',
        icon: Icons.star_rounded,
        activeColor: Color(0xFFF59E0B),
        darkColor: Color(0xFFB45309)),
    _ReviewTabData(
        label: 'Review Settings',
        icon: Icons.tune_rounded,
        activeColor: AppAdmin.dark,
        darkColor: AppAdmin.darkest),
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
                    widget.controller.animateTo(i);
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
                        const SizedBox(width: 6),
                        Flexible(
                            child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 220),
                          style: TextStyle(
                            fontSize: isActive ? 12 : 11,
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
                      ]),
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

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1: ALL REVIEWS
// ══════════════════════════════════════════════════════════════════════════════
class _AllReviewsTab extends ConsumerStatefulWidget {
  const _AllReviewsTab();
  @override
  ConsumerState<_AllReviewsTab> createState() => _AllReviewsTabState();
}

class _AllReviewsTabState extends ConsumerState<_AllReviewsTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  int? _starFilter; // null = all
  ReviewAdminStatus? _statusFilter;
  ReviewReportType? _reportFilter;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AdminReview> _apply(List<AdminReview> all) {
    var list = all;
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where((a) =>
              a.review.customerName.toLowerCase().contains(q) ||
              a.review.comment.toLowerCase().contains(q) ||
              (a.review.orderId?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    if (_starFilter != null) {
      list = list
          .where((a) => a.review.overallRating.round() == _starFilter)
          .toList();
    }
    if (_statusFilter != null) {
      list = list.where((a) => a.status == _statusFilter).toList();
    }
    if (_reportFilter != null) {
      list = list.where((a) => a.reportType == _reportFilter).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(adminReviewsProvider);
    final filtered = _apply(all);

    // Stats
    final reported = all.where((a) => a.reportCount > 0).length;
    final hidden =
        all.where((a) => a.status == ReviewAdminStatus.hidden).length;
    final deleted =
        all.where((a) => a.status == ReviewAdminStatus.deleted).length;
    final avg = all.isEmpty
        ? 0.0
        : all.map((a) => a.review.overallRating).reduce((a, b) => a + b) /
            all.length;

    final hasFilter =
        _starFilter != null || _statusFilter != null || _reportFilter != null;

    return Column(children: [
      // ── Search + Filter ──
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Row(children: [
          Expanded(
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
                ],
              ),
              child: Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppAdmin.dark, AppAdmin.darkest],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.search_rounded,
                      color: Colors.white, size: 19),
                ),
                Expanded(
                    child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppAdmin.inkDarkest),
                  decoration: InputDecoration(
                    hintText: 'Search reviews...',
                    hintStyle: TextStyle(
                        color: AppAdmin.inkLight.withOpacity(0.8),
                        fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 13),
                    suffixIcon: _query.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                            child: const Icon(Icons.close_rounded,
                                size: 16, color: AppAdmin.inkLight))
                        : null,
                  ),
                )),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          // Filter button
          _ReviewFilterButton(
            starFilter: _starFilter,
            statusFilter: _statusFilter,
            reportFilter: _reportFilter,
            onChanged: (star, status, report) => setState(() {
              _starFilter = star;
              _statusFilter = status;
              _reportFilter = report;
            }),
          ),
        ]),
      ),

      // ── List ──
      Expanded(
        child: filtered.isEmpty
            ? _EmptyState(
                icon: Icons.star_border_rounded, message: 'No reviews found')
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: filtered.length,
                itemBuilder: (_, i) => _ReviewCard(adminReview: filtered[i]),
              ),
      ),
    ]);
  }
}

// ─── Review Card ──────────────────────────────────────────────────────────────
class _ReviewCard extends ConsumerWidget {
  final AdminReview adminReview;
  const _ReviewCard({required this.adminReview});

  Color _statusColor(ReviewAdminStatus s) {
    switch (s) {
      case ReviewAdminStatus.visible:
        return AppColors.success;
      case ReviewAdminStatus.hidden:
        return AppColors.textSecondary;
      case ReviewAdminStatus.deleted:
        return AppColors.error;
    }
  }

  String _statusLabel(ReviewAdminStatus s) {
    switch (s) {
      case ReviewAdminStatus.visible:
        return 'Visible';
      case ReviewAdminStatus.hidden:
        return 'Hidden';
      case ReviewAdminStatus.deleted:
        return 'Deleted';
    }
  }

  Color _statusBg(ReviewAdminStatus s) {
    switch (s) {
      case ReviewAdminStatus.visible:
        return const Color(0xFFF0FDF4);
      case ReviewAdminStatus.hidden:
        return const Color(0xFFF3F4F6);
      case ReviewAdminStatus.deleted:
        return const Color(0xFFFEE2E2);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = adminReview.review;
    final sc = _statusColor(adminReview.status);
    final sl = _statusLabel(adminReview.status);
    final sbg = _statusBg(adminReview.status);
    final c2 = Color.lerp(sc, Colors.black, 0.35)!;
    final stars = r.overallRating.round();

    return GestureDetector(
      onTap: () => _openDetails(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppAdmin.surfaceTint,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: sc.withOpacity(0.16), width: 1),
          boxShadow: [
            BoxShadow(
                color: sc.withOpacity(0.16),
                blurRadius: 18,
                offset: const Offset(0, 8)),
            const BoxShadow(
                color: AppAdmin.borderSoft,
                blurRadius: 0,
                offset: Offset(0, 5)),
            const BoxShadow(
                color: AppAdmin.borderSoft,
                blurRadius: 14,
                offset: Offset(5, 5)),
            const BoxShadow(
                color: Colors.white, blurRadius: 14, offset: Offset(-4, -4)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Slim semantic top accent strip — same structural language
          // as the redesigned Admin Orders/Complaints cards ──
          Container(
            height: 5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [sc, sc.withOpacity(0.35)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight),
            ),
          ),

          // ── Structured header — 3D rating avatar + name/subtitle +
          // status/report pills + three-dots, on the card's own light
          // surface (no more full-color gradient banner) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [sc, c2],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.6), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                          color: sc.withOpacity(0.40),
                          blurRadius: 0,
                          offset: const Offset(0, 3)),
                      BoxShadow(
                          color: sc.withOpacity(0.20),
                          blurRadius: 10,
                          offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star_rounded, color: Colors.white, size: 16),
                      Text(r.overallRating.toStringAsFixed(1),
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.customerName,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppAdmin.inkDarkest,
                                letterSpacing: -0.2),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(
                                5,
                                (i) => Icon(
                                    i < stars
                                        ? Icons.star_rounded
                                        : Icons.star_border_rounded,
                                    size: 12,
                                    color: const Color(0xFFF59E0B)))),
                        const SizedBox(height: 2),
                        Text(
                            r.relatedService ??
                                (r.orderId != null
                                    ? 'Order: ${r.orderId}'
                                    : 'General review'),
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppAdmin.inkLight,
                                fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ]),
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: sc.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sc.withOpacity(0.30)),
                      ),
                      child: Text(sl,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: sc)),
                    ),
                    if (adminReview.reportCount > 0) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF97316).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFFF97316).withOpacity(0.30)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.flag_rounded,
                              size: 10, color: Color(0xFFF97316)),
                          const SizedBox(width: 2),
                          Text('${adminReview.reportCount}',
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFF97316))),
                        ]),
                      ),
                    ],
                  ],
                ),
                const SizedBox(width: 6),
                _ReviewThreeDotsMenu(adminReview: adminReview, statusColor: sc),
              ],
            ),
          ),

          const SizedBox(height: 12),
          // Gradient divider — separates header from body, tinted by status
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.transparent,
                  sc.withOpacity(0.30),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          // ── Body — tinted with a subtle status accent background ──
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: sbg,
              borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Comment
              Text(r.comment,
                  softWrap: true,
                  style: const TextStyle(
                      fontSize: 12, color: AppAdmin.inkMid, height: 1.45),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              // Chips
              Wrap(spacing: 8, runSpacing: 6, children: [
                _ReviewNeoChip(
                    icon: Icons.calendar_today_outlined,
                    label:
                        '${r.createdAt.day}/${r.createdAt.month}/${r.createdAt.year}',
                    color: const Color(0xFF0EA5E9)),
                _ReviewNeoChip(
                    icon: Icons.receipt_outlined,
                    label: r.orderId != null
                        ? 'Order: ${r.orderId}'
                        : 'General review',
                    color: AppAdmin.dark),
                if (adminReview.reportType != ReviewReportType.none)
                  _ReviewNeoChip(
                      icon: Icons.warning_amber_rounded,
                      label: adminReview.reportType == ReviewReportType.fake
                          ? 'Fake'
                          : adminReview.reportType == ReviewReportType.offensive
                              ? 'Offensive'
                              : 'Spam',
                      color: const Color(0xFFF97316)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  void _openDetails(BuildContext context) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => _ReviewDetailsPage(adminReview: adminReview)));
  }
}

// ─── Review Popup Menu ────────────────────────────────────────────────────────
class _ReviewPopupMenu extends ConsumerWidget {
  final AdminReview adminReview;
  const _ReviewPopupMenu({required this.adminReview});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(adminReviewsProvider.notifier);
    final id = adminReview.review.id;
    final isHidden = adminReview.status == ReviewAdminStatus.hidden;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded,
          color: AppColors.textSecondary, size: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 4,
      onSelected: (val) {
        switch (val) {
          case 'view':
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        _ReviewDetailsPage(adminReview: adminReview)));
            break;
          case 'hide':
            notifier.hideReview(id);
            _snack(context, 'Review hidden', AppColors.textSecondary);
            break;
          case 'restore':
            notifier.restoreReview(id);
            _snack(context, 'Review restored', AppColors.success);
            break;
          case 'delete':
            notifier.deleteReview(id);
            _snack(context, 'Review deleted', AppColors.error);
            break;
          case 'warn':
            _showWarnDialog(context, ref);
            break;
          case 'safe':
            notifier.markSafe(id);
            _snack(context, 'Marked as safe', AppColors.success);
            break;
        }
      },
      itemBuilder: (_) => [
        _mi(
            value: 'view',
            icon: Icons.visibility_outlined,
            label: 'View Details',
            iconColor: AppAdmin.dark),
        if (!isHidden)
          _mi(
              value: 'hide',
              icon: Icons.visibility_off_outlined,
              label: 'Hide Review',
              iconColor: AppColors.textSecondary),
        if (isHidden)
          _mi(
              value: 'restore',
              icon: Icons.visibility_outlined,
              label: 'Restore Review',
              iconColor: AppColors.success),
        _mi(
            value: 'delete',
            icon: Icons.delete_outline_rounded,
            label: 'Delete Review',
            iconColor: AppColors.error),
        const PopupMenuDivider(height: 1),
        _mi(
            value: 'warn',
            icon: Icons.warning_amber_rounded,
            label: 'Warn User',
            iconColor: const Color(0xFFF97316)),
        _mi(
            value: 'safe',
            icon: Icons.shield_outlined,
            label: 'Mark Safe',
            iconColor: AppColors.success),
      ],
    );
  }

  void _showWarnDialog(BuildContext context, WidgetRef ref) {
    showDialog(
        context: context,
        builder: (_) => _WarnDialog(
              userName: adminReview.review.customerName,
              onConfirm: (msg) async {
                final users = ref.read(adminUsersProvider);
                final user = users
                    .where((u) => u.id == adminReview.review.customerId)
                    .toList();
                if (user.isNotEmpty) {
                  ref
                      .read(adminUsersProvider.notifier)
                      .warnUser(user.first.id, msg);
                }
                _snack(
                    context,
                    'Warning sent to ${adminReview.review.customerName}',
                    const Color(0xFFF97316));
              },
            ));
  }

  void _snack(BuildContext context, String msg, Color color) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));

  PopupMenuItem<String> _mi({
    required String value,
    required IconData icon,
    required String label,
    Color iconColor = AppAdmin.dark,
  }) =>
      PopupMenuItem<String>(
        value: value,
        height: 44,
        child: Row(children: [
          Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 16, color: iconColor)),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: iconColor == AppAdmin.dark
                      ? AppAdmin.darkest
                      : iconColor)),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// REVIEW DETAILS PAGE
// ══════════════════════════════════════════════════════════════════════════════
class _ReviewDetailsPage extends ConsumerStatefulWidget {
  final AdminReview adminReview;
  const _ReviewDetailsPage({required this.adminReview});

  @override
  ConsumerState<_ReviewDetailsPage> createState() => _ReviewDetailsPageState();
}

class _ReviewDetailsPageState extends ConsumerState<_ReviewDetailsPage> {
  bool _isSavingVisibility = false;

  Future<void> _toggleVisibility(ReviewModel r, bool hide) async {
    if (_isSavingVisibility) return;
    final confirmed = await _confirmVisibilityChange(context, hide: hide);
    if (!confirmed || !mounted) return;
    setState(() => _isSavingVisibility = true);
    try {
      await _setReviewVisibility(ref, r, hide: hide);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(hide ? 'Review hidden' : 'Review restored'),
          backgroundColor: hide ? AppColors.textSecondary : AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text(
              'Could not update review visibility. Please try again.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    } finally {
      if (mounted) setState(() => _isSavingVisibility = false);
    }
  }

  Color _reportColor(ReviewReportType t) {
    switch (t) {
      case ReviewReportType.fake:
        return AppAdmin.accent;
      case ReviewReportType.offensive:
        return AppColors.error;
      case ReviewReportType.spam:
        return const Color(0xFF0077B6);
      case ReviewReportType.none:
        return AppColors.success;
    }
  }

  String _reportLabel(ReviewReportType t) {
    switch (t) {
      case ReviewReportType.fake:
        return 'Fake Review';
      case ReviewReportType.offensive:
        return 'Offensive';
      case ReviewReportType.spam:
        return 'Spam';
      case ReviewReportType.none:
        return 'No Report';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the live Firestore-backed list so this page reflects Hide/Unhide
    // immediately without popping back to the list; fall back to the
    // snapshot passed in if the review briefly isn't in the loaded list yet.
    final liveList = ref.watch(adminReviewsProvider);
    final adminReview = liveList.firstWhere(
        (a) => a.review.id == widget.adminReview.review.id,
        orElse: () => widget.adminReview);
    final r = adminReview.review;
    final users = ref.watch(adminUsersProvider);
    final customer = users.where((u) => u.id == r.customerId).toList();
    final provider = users.where((u) => u.id == r.providerId).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(children: [
        // ── Header ──
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
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                child: Row(children: [
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints()),
                  const SizedBox(width: 10),
                  const Expanded(
                      child: Text('Review Details',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white))),
                  // Status badge
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        ...List.generate(
                            5,
                            (i) => Icon(
                                i < r.overallRating.round()
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                size: 12,
                                color: Colors.amber)),
                        const SizedBox(width: 4),
                        Text(r.overallRating.toStringAsFixed(1),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ])),
                ]),
              )),
        ),

        // ── Body ──
        Expanded(
            child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Full Review Text ──
            _DetailSection(
              icon: Icons.format_quote_rounded,
              title: 'Review Text',
              color: AppAdmin.dark,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppAdmin.surfaceTint,
                  borderRadius: BorderRadius.circular(16),
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
                child: Text(r.comment,
                    softWrap: true,
                    style: const TextStyle(
                        fontSize: 14, color: AppAdmin.inkDark, height: 1.5)),
              ),
            ),
            const SizedBox(height: 12),

            // ── Reviewer ──
            _DetailSection(
              icon: Icons.person_outline_rounded,
              title: 'Reviewer (Customer)',
              color: AppColors.primary,
              child: _PersonTile(
                name: r.customerName,
                subtitle: 'Customer · ID: ${r.customerId}',
                color: AppColors.primary,
                avatarUrl: customer.isNotEmpty ? customer.first.avatar : null,
                onTap: customer.isNotEmpty
                    ? () => showAdminUserDetails(context, customer.first, ref)
                    : null,
              ),
            ),
            const SizedBox(height: 12),

            // ── Reviewed Person ──
            _DetailSection(
              icon: Icons.engineering_outlined,
              title: r.providerRole == 'contractor'
                  ? 'Reviewed Contractor'
                  : 'Reviewed Professional',
              color: AppColors.success,
              child: _PersonTile(
                name: r.relatedService ?? 'Professional',
                subtitle:
                    '${r.providerRole == 'contractor' ? 'Contractor' : 'Professional'} · ID: ${r.providerId}',
                color: AppColors.success,
                avatarUrl: provider.isNotEmpty ? provider.first.avatar : null,
                onTap: provider.isNotEmpty
                    ? () => showAdminUserDetails(context, provider.first, ref)
                    : null,
              ),
            ),
            const SizedBox(height: 12),

            // ── Linked Order ──
            _DetailSection(
              icon: Icons.receipt_long_outlined,
              title: 'Linked Order',
              color: AppAdmin.dark,
              child: _RevInfoRow(
                icon: Icons.receipt_long_outlined,
                label: 'Order',
                value: r.orderId != null
                    ? '#${r.orderId}'
                    : 'General review (no linked order)',
                color: AppAdmin.dark,
              ),
            ),
            const SizedBox(height: 12),

            // ── Attachments ──
            if (adminReview.attachments.isNotEmpty) ...[
              _DetailSection(
                icon: Icons.photo_library_outlined,
                title: 'Attached Images',
                color: const Color(0xFF0077B6),
                child: SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: adminReview.attachments.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                          color: AppAdmin.lightest,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppAdmin.lightest)),
                      child: const Icon(Icons.image_outlined,
                          color: AppAdmin.dark),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── Status + Report Info ──
            _DetailSection(
              icon: Icons.info_outline_rounded,
              title: 'Review Status & Report',
              color: _reportColor(adminReview.reportType),
              child: Column(children: [
                _RevInfoRow(
                  icon: Icons.visibility_outlined,
                  label: 'Status',
                  color: _reportColor(adminReview.reportType),
                  valueChip: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: adminReview.status == ReviewAdminStatus.visible
                            ? AppColors.success.withOpacity(0.12)
                            : AppColors.error.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      adminReview.status == ReviewAdminStatus.visible
                          ? 'Visible'
                          : adminReview.status == ReviewAdminStatus.hidden
                              ? 'Hidden'
                              : 'Deleted',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: adminReview.status == ReviewAdminStatus.visible
                              ? AppColors.success
                              : AppColors.error),
                    ),
                  ),
                ),
                _RevInfoRow(
                  icon: Icons.flag_outlined,
                  label: 'Report Count',
                  value: '${adminReview.reportCount}',
                  color: _reportColor(adminReview.reportType),
                ),
                if (adminReview.reportType != ReviewReportType.none)
                  _RevInfoRow(
                    icon: Icons.report_gmailerrorred_rounded,
                    label: 'Report Type',
                    color: _reportColor(adminReview.reportType),
                    valueChip: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: _reportColor(adminReview.reportType)
                              .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(_reportLabel(adminReview.reportType),
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _reportColor(adminReview.reportType))),
                    ),
                  ),
                if (adminReview.reportedAt != null)
                  _RevInfoRow(
                    icon: Icons.schedule_rounded,
                    label: 'Reported',
                    value:
                        '${adminReview.reportedAt!.day}/${adminReview.reportedAt!.month}/${adminReview.reportedAt!.year}',
                    color: _reportColor(adminReview.reportType),
                  ),
              ]),
            ),
            const SizedBox(height: 20),

            // ── Admin Actions ──
            // Review Management only manages the review itself (Hide/Unhide,
            // Warn) — complaint decisions live exclusively in Complaints
            // Center, order navigation and user-profile access are handled
            // by the Reviewed Provider/Reviewer cards above.
            const _SectionLabel(label: 'Admin Actions'),
            const SizedBox(height: 10),
            Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (adminReview.status != ReviewAdminStatus.hidden)
                    _ActionBtn(
                      label: 'Hide Review',
                      icon: Icons.visibility_off_outlined,
                      color: AppColors.textSecondary,
                      loading: _isSavingVisibility,
                      onTap: () => _toggleVisibility(r, true),
                    ),
                  if (adminReview.status == ReviewAdminStatus.hidden)
                    _ActionBtn(
                      label: 'Unhide Review',
                      icon: Icons.visibility_outlined,
                      color: AppColors.success,
                      loading: _isSavingVisibility,
                      onTap: () => _toggleVisibility(r, false),
                    ),
                  _ActionBtn(
                    label: 'Warn User',
                    icon: Icons.warning_amber_rounded,
                    color: const Color(0xFFF97316),
                    onTap: () => showAdminUserModal(
                        context: context,
                        builder: (_) => _WarnDialog(
                              userName: r.customerName,
                              onConfirm: (msg) async {
                                await _sendReviewerWarning(ref, r, msg);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'Warning sent to ${r.customerName}'),
                                        backgroundColor:
                                            const Color(0xFFF97316),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12))));
                              },
                            )),
                  ),
                ]),
            const SizedBox(height: 24),
          ]),
        )),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2: REVIEW SETTINGS
// ══════════════════════════════════════════════════════════════════════════════
class _ReviewSettingsTab extends ConsumerStatefulWidget {
  const _ReviewSettingsTab();
  @override
  ConsumerState<_ReviewSettingsTab> createState() => _ReviewSettingsTabState();
}

class _ReviewSettingsTabState extends ConsumerState<_ReviewSettingsTab> {
  bool _showPreview = false;

  @override
  Widget build(BuildContext context) {
    final criteria = ref.watch(reviewCriteriaProvider);
    final active = criteria.where((c) => c.isActive).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header Row ──
        Row(children: [
          const _SectionLabel(label: 'Review Criteria'),
          const Spacer(),
          // Preview toggle
          GestureDetector(
            onTap: () => setState(() => _showPreview = !_showPreview),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _showPreview ? AppAdmin.dark : AppAdmin.surfaceTint,
                borderRadius: BorderRadius.circular(12),
                boxShadow: _showPreview
                    ? [
                        BoxShadow(
                            color: AppAdmin.dark.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4)),
                        BoxShadow(
                            color: AppAdmin.darkest.withOpacity(0.9),
                            blurRadius: 0,
                            offset: const Offset(0, 3)),
                      ]
                    : const [
                        BoxShadow(
                            color: AppAdmin.borderSoft,
                            blurRadius: 0,
                            offset: Offset(0, 3)),
                        BoxShadow(
                            color: AppAdmin.borderSoft,
                            blurRadius: 5,
                            offset: Offset(3, 3)),
                        BoxShadow(
                            color: Colors.white,
                            blurRadius: 5,
                            offset: Offset(-3, -3)),
                      ],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.preview_rounded,
                    size: 14,
                    color: _showPreview ? Colors.white : AppAdmin.dark),
                const SizedBox(width: 5),
                Text('Preview',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _showPreview ? Colors.white : AppAdmin.dark)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 12),

        // ── Preview Section ──
        if (_showPreview) ...[
          _PreviewSection(criteria: active),
          const SizedBox(height: 16),
        ],

        // ── Criteria Cards (reorderable) ──
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: criteria.length,
          onReorder: (o, n) => ref
              .read(reviewCriteriaProvider.notifier)
              .reorder(o, n > o ? n - 1 : n),
          buildDefaultDragHandles: false,
          itemBuilder: (_, i) => _CriteriaCard(
            key: ValueKey(criteria[i].id),
            criteria: criteria[i],
            index: i,
          ),
        ),
        const SizedBox(height: 14),

        // ── Add Button (neo style) ──
        GestureDetector(
          onTap: () => showAdminUserModal(
              context: context, builder: (_) => const _CriteriaFormDialog()),
          child: Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: const LinearGradient(
                  colors: [AppAdmin.dark, AppAdmin.darkest],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              boxShadow: [
                BoxShadow(
                    color: AppAdmin.dark.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4)),
                BoxShadow(
                    color: AppAdmin.darkest.withOpacity(0.9),
                    blurRadius: 0,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Add Review Criteria',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ]),
          ),
        ),
      ]),
    );
  }
}

// ─── Preview Section ──────────────────────────────────────────────────────────
class _PreviewSection extends StatefulWidget {
  final List<ReviewCriteriaModel> criteria;
  const _PreviewSection({required this.criteria});
  @override
  State<_PreviewSection> createState() => _PreviewSectionState();
}

class _PreviewSectionState extends State<_PreviewSection> {
  late Map<String, double> _ratings;

  @override
  void initState() {
    super.initState();
    _ratings = {for (final c in widget.criteria) c.id: 0};
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [AppAdmin.lightest, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppAdmin.dark.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: AppAdmin.darkest.withOpacity(0.06), blurRadius: 10)
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.preview_rounded, size: 16, color: AppAdmin.dark),
          const SizedBox(width: 8),
          const Text('Review Form Preview',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppAdmin.darkest)),
        ]),
        const SizedBox(height: 2),
        const Text('This is how the review form will look to users.',
            style: TextStyle(fontSize: 11, color: AppAdmin.dark)),
        const Divider(height: 20),
        for (final c in widget.criteria) ...[
          Row(children: [
            Text(c.icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Text(c.name,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppAdmin.darkest)),
                    if (c.isRequired) ...[
                      const SizedBox(width: 4),
                      const Text('*',
                          style: TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w900)),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Row(
                      children: List.generate(
                          c.maxRating,
                          (i) => GestureDetector(
                                onTap: () => setState(
                                    () => _ratings[c.id] = (i + 1).toDouble()),
                                child: Icon(
                                    i < (_ratings[c.id] ?? 0)
                                        ? Icons.star_rounded
                                        : Icons.star_border_rounded,
                                    size: 22,
                                    color: const Color(0xFFF59E0B)),
                              ))),
                ])),
          ]),
          const SizedBox(height: 12),
        ],
        // Comment field
        Container(
          height: 70,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppAdmin.lightest)),
          child: const Text('Add your comment here...',
              style: TextStyle(fontSize: 12, color: AppAdmin.mid)),
        ),
      ]),
    );
  }
}

// ─── Criteria Card ────────────────────────────────────────────────────────────
class _CriteriaCard extends ConsumerWidget {
  final ReviewCriteriaModel criteria;
  final int index;
  const _CriteriaCard({super.key, required this.criteria, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(reviewCriteriaProvider.notifier);
    final isActive = criteria.isActive;

    final accentColor =
        isActive ? const Color(0xFF059669) : AppColors.textSecondary;
    final sbg = isActive ? const Color(0xFFF0FDF4) : const Color(0xFFF3F4F6);
    final c2 = Color.lerp(accentColor, Colors.black, 0.35)!;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppAdmin.surfaceTint,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withOpacity(0.16), width: 1),
        boxShadow: [
          BoxShadow(
              color: accentColor.withOpacity(0.16),
              blurRadius: 18,
              offset: const Offset(0, 8)),
          const BoxShadow(
              color: AppAdmin.borderSoft, blurRadius: 0, offset: Offset(0, 5)),
          const BoxShadow(
              color: AppAdmin.borderSoft, blurRadius: 14, offset: Offset(5, 5)),
          const BoxShadow(
              color: Colors.white, blurRadius: 14, offset: Offset(-4, -4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        // ── Slim semantic top accent strip ──
        Container(
          height: 5,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [accentColor, accentColor.withOpacity(0.35)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight),
          ),
        ),

        // ── Structured header — 3D emoji-icon avatar + name/status +
        // required/max-rating pills + three-dots, on the card's own light
        // surface ──
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [accentColor, c2],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.6), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                        color: accentColor.withOpacity(0.40),
                        blurRadius: 0,
                        offset: const Offset(0, 3)),
                    BoxShadow(
                        color: accentColor.withOpacity(0.20),
                        blurRadius: 10,
                        offset: const Offset(0, 6)),
                  ],
                ),
                child: Center(
                    child: Text(criteria.icon,
                        style: const TextStyle(fontSize: 20))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                            child: Text(criteria.name,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppAdmin.inkDarkest,
                                    letterSpacing: -0.2),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis)),
                        if (criteria.isRequired) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: AppAdmin.accent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10)),
                            child: const Text('Required',
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: AppAdmin.accent)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 3),
                      Text(isActive ? 'Active' : 'Disabled',
                          style: TextStyle(
                              fontSize: 11,
                              color: accentColor,
                              fontWeight: FontWeight.w700)),
                    ]),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accentColor.withOpacity(0.30)),
                ),
                child: Text('Max ${criteria.maxRating}★',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: accentColor)),
              ),
              const SizedBox(width: 6),
              _CriteriaThreeDotsMenu(
                  criteria: criteria,
                  index: index,
                  notifier: notifier,
                  accentColor: accentColor),
            ],
          ),
        ),

        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                accentColor.withOpacity(0.30),
                Colors.transparent,
              ]),
            ),
          ),
        ),

        // ── Body — tinted with a subtle status accent background ──
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: sbg,
            borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Drag handle
            ReorderableDragStartListener(
              index: index,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                        color: AppAdmin.borderSoft,
                        blurRadius: 0,
                        offset: Offset(0, 2)),
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
                child: const Icon(Icons.drag_handle_rounded,
                    color: AppAdmin.inkMid, size: 16),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Text(criteria.description,
                    softWrap: true,
                    style: const TextStyle(
                        fontSize: 12, color: AppAdmin.inkMid, height: 1.4),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis)),
          ]),
        ),
      ]),
    );
  }
}

// ─── Criteria Three-Dots Menu (same style as review/complaint cards) ──────────
class _CriteriaThreeDotsMenu extends StatefulWidget {
  final ReviewCriteriaModel criteria;
  final int index;
  final ReviewCriteriaNotifier notifier;
  final Color accentColor;
  const _CriteriaThreeDotsMenu(
      {required this.criteria,
      required this.index,
      required this.notifier,
      required this.accentColor});
  @override
  State<_CriteriaThreeDotsMenu> createState() => _CriteriaThreeDotsMenuState();
}

class _CriteriaThreeDotsMenuState extends State<_CriteriaThreeDotsMenu>
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

  void _open(BuildContext context) {
    HapticFeedback.lightImpact();
    final isActive = widget.criteria.isActive;
    final scaffoldMsg = ScaffoldMessenger.of(context);

    void snack(String msg, Color color) => scaffoldMsg.showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));

    final items = <_ReviewMenuItemData>[
      _ReviewMenuItemData(
          icon: Icons.edit_outlined,
          label: 'Edit',
          color: AppAdmin.dark,
          onTap: () => showAdminUserModal(
              context: context,
              builder: (_) => _CriteriaFormDialog(criteria: widget.criteria))),
      _ReviewMenuItemData(
        icon: isActive
            ? Icons.pause_circle_outline_rounded
            : Icons.play_circle_outline_rounded,
        label: isActive ? 'Disable' : 'Enable',
        color: isActive ? AppColors.textSecondary : AppColors.success,
        onTap: () {
          widget.notifier.toggleActive(widget.criteria.id);
          snack(
              isActive
                  ? '"${widget.criteria.name}" disabled'
                  : '"${widget.criteria.name}" enabled',
              isActive ? AppColors.textSecondary : AppColors.success);
        },
      ),
      _ReviewMenuItemData(
          icon: Icons.delete_outline_rounded,
          label: 'Delete',
          color: AppColors.error,
          onTap: () {
            widget.notifier.deleteCriteria(widget.criteria.id);
            snack('"${widget.criteria.name}" removed', AppColors.error);
          }),
    ];

    final box = context.findRenderObject() as RenderBox?;
    final pos = box?.localToGlobal(Offset.zero) ?? Offset.zero;
    final size = box?.size ?? Size.zero;
    _openMenuPanel(context, pos, size, items);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          _ctrl.forward();
        },
        onTapUp: (_) {
          _ctrl.reverse();
          _open(context);
        },
        onTapCancel: () => _ctrl.reverse(),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.08 * _ctrl.value, child: child),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppAdmin.surfaceTint,
              borderRadius: BorderRadius.circular(10),
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
                    (_) => Container(
                          width: 3.5,
                          height: 3.5,
                          margin: const EdgeInsets.symmetric(vertical: 1.2),
                          decoration: BoxDecoration(
                              color: widget.accentColor.withOpacity(0.75),
                              shape: BoxShape.circle),
                        ))),
          ),
        ),
      );
}

// ─── Criteria Form Dialog ─────────────────────────────────────────────────────
class _CriteriaFormDialog extends ConsumerStatefulWidget {
  final ReviewCriteriaModel? criteria;
  const _CriteriaFormDialog({this.criteria});
  @override
  ConsumerState<_CriteriaFormDialog> createState() =>
      _CriteriaFormDialogState();
}

class _CriteriaFormDialogState extends ConsumerState<_CriteriaFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  String _icon = '⭐';
  int _maxRating = 5;
  bool _required = false;

  static const _iconOptions = [
    '⭐',
    '⚡',
    '🔧',
    '💬',
    '🧹',
    '🦺',
    '💰',
    '👔',
    '🎯',
    '🤝',
    '📋',
    '🏆',
    '✅',
    '🔍'
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.criteria;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _descCtrl = TextEditingController(text: c?.description ?? '');
    _icon = c?.icon ?? '⭐';
    _maxRating = c?.maxRating ?? 5;
    _required = c?.isRequired ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.criteria != null && widget.criteria!.id.isNotEmpty;

    return _RevModalShell(
      icon: isEdit ? Icons.edit_outlined : Icons.add_rounded,
      title: isEdit ? 'Edit Criteria' : 'Add Review Criteria',
      accentColor: AppAdmin.dark,
      bodyPadding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      body: Form(
          key: _formKey,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Icon picker
            const _RevSectionLabel(label: 'Icon'),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _iconOptions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final opt = _iconOptions[i];
                  final selected = _icon == opt;
                  return GestureDetector(
                    onTap: () => setState(() => _icon = opt),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: selected
                            ? const LinearGradient(
                                colors: [AppAdmin.dark, AppAdmin.darkest],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight)
                            : null,
                        color: selected ? null : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                    color: AppAdmin.dark.withOpacity(0.4),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3)),
                              ]
                            : const [
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
                      child: Center(
                          child:
                              Text(opt, style: const TextStyle(fontSize: 20))),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            const _RevSectionLabel(label: 'Name & Description'),
            const SizedBox(height: 10),
            // Name
            TextFormField(
              controller: _nameCtrl,
              decoration: _dec('Criteria Name', Icons.label_outline_rounded),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            // Description
            TextFormField(
              controller: _descCtrl,
              decoration: _dec('Description', Icons.description_outlined),
              maxLines: 2,
            ),
            const SizedBox(height: 18),
            const _RevSectionLabel(label: 'Rating & Requirement'),
            const SizedBox(height: 10),
            // Max Rating slider
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
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
              child: Column(children: [
                Row(children: [
                  const Text('Max Rating',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppAdmin.inkDark)),
                  const Spacer(),
                  Text('$_maxRating ★',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppAdmin.dark)),
                ]),
                Slider(
                  value: _maxRating.toDouble(),
                  min: 3,
                  max: 10,
                  divisions: 7,
                  activeColor: AppAdmin.dark,
                  onChanged: (v) => setState(() => _maxRating = v.round()),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            // Required toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
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
              child: Row(children: [
                const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Required',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppAdmin.inkDark)),
                      Text('Users must fill this criteria',
                          style: TextStyle(fontSize: 11, color: AppAdmin.mid)),
                    ])),
                Switch(
                  value: _required,
                  activeColor: AppAdmin.dark,
                  onChanged: (v) => setState(() => _required = v),
                ),
              ]),
            ),
          ])),
      footer: Row(children: [
        Expanded(
            child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: const [
                BoxShadow(
                    color: AppAdmin.borderSoft,
                    blurRadius: 0,
                    offset: Offset(0, 4)),
                BoxShadow(
                    color: AppAdmin.borderSoft,
                    blurRadius: 6,
                    offset: Offset(4, 4)),
                BoxShadow(
                    color: Colors.white, blurRadius: 6, offset: Offset(-3, -3)),
              ],
            ),
            child: const Center(
                child: Text('Cancel',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppAdmin.inkMid))),
          ),
        )),
        const SizedBox(width: 12),
        Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: () {
                if (!_formKey.currentState!.validate()) return;
                final notifier = ref.read(reviewCriteriaProvider.notifier);
                final all = ref.read(reviewCriteriaProvider);
                if (isEdit) {
                  notifier.updateCriteria(widget.criteria!.copyWith(
                      name: _nameCtrl.text.trim(),
                      description: _descCtrl.text.trim(),
                      icon: _icon,
                      maxRating: _maxRating,
                      isRequired: _required));
                } else {
                  notifier.addCriteria(ReviewCriteriaModel(
                      id: 'c_${DateTime.now().millisecondsSinceEpoch}',
                      name: _nameCtrl.text.trim(),
                      description: _descCtrl.text.trim(),
                      icon: _icon,
                      maxRating: _maxRating,
                      isRequired: _required,
                      sortOrder: all.length));
                }
                Navigator.pop(context);
              },
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  gradient: const LinearGradient(
                      colors: [AppAdmin.dark, AppAdmin.darkest],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  boxShadow: [
                    BoxShadow(
                        color: AppAdmin.dark.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4)),
                    BoxShadow(
                        color: AppAdmin.darkest.withOpacity(0.9),
                        blurRadius: 0,
                        offset: const Offset(0, 3)),
                  ],
                ),
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(isEdit ? Icons.save_outlined : Icons.add_rounded,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(isEdit ? 'Save Changes' : 'Add Criteria',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ]),
              ),
            )),
      ]),
    );
  }

  InputDecoration _dec(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppAdmin.mid, fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: AppAdmin.dark),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppAdmin.dark, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
}

// Small section caption used inside the Add/Edit Criteria dialog to group
// fields — same accent-bar language as _SectionLabel.
class _RevSectionLabel extends StatelessWidget {
  final String label;
  const _RevSectionLabel({required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
                color: AppAdmin.dark, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppAdmin.inkMid,
                letterSpacing: 0.2)),
      ]);
}

// ─── Warn Dialog ──────────────────────────────────────────────────────────────
class _WarnDialog extends StatefulWidget {
  final String userName;
  final Future<void> Function(String msg) onConfirm;
  const _WarnDialog({required this.userName, required this.onConfirm});
  @override
  State<_WarnDialog> createState() => _WarnDialogState();
}

class _WarnDialogState extends State<_WarnDialog> {
  final _ctrl = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onConfirm(text);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e is StateError
            ? e.message
            : 'Could not send warning. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _RevModalShell(
      icon: Icons.warning_amber_rounded,
      title: 'Warn User',
      subtitle: widget.userName,
      accentColor: const Color(0xFFF97316),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Warning message:',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppAdmin.darkest)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
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
            maxLines: 3,
            enabled: !_sending,
            style: const TextStyle(fontSize: 14, color: AppAdmin.inkDark),
            decoration: const InputDecoration(
              hintText: 'Enter warning reason…',
              hintStyle: TextStyle(color: AppAdmin.inkLight, fontSize: 13),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(14),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!,
              style: const TextStyle(color: AppColors.error, fontSize: 12)),
        ],
      ]),
      footer: Row(children: [
        Expanded(
            child: OutlinedButton(
                onPressed: _sending ? null : () => Navigator.pop(context),
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
                onPressed: _sending ? null : _send,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 46),
                    padding: EdgeInsets.zero,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white)))
                    : const Text('Send Warning',
                        style: TextStyle(fontWeight: FontWeight.w700)))),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED SMALL WIDGETS
// ══════════════════════════════════════════════════════════════════════════════
// ─── Review Filter Button ─────────────────────────────────────────────────────
class _ReviewFilterButton extends StatefulWidget {
  final int? starFilter;
  final ReviewAdminStatus? statusFilter;
  final ReviewReportType? reportFilter;
  final void Function(
      int? star, ReviewAdminStatus? status, ReviewReportType? report) onChanged;
  const _ReviewFilterButton(
      {required this.starFilter,
      required this.statusFilter,
      required this.reportFilter,
      required this.onChanged});
  @override
  State<_ReviewFilterButton> createState() => _ReviewFilterButtonState();
}

class _ReviewFilterButtonState extends State<_ReviewFilterButton>
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

  bool get _hasFilter =>
      widget.starFilter != null ||
      widget.statusFilter != null ||
      widget.reportFilter != null;

  void _open() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ReviewFilterSheet(
        starFilter: widget.starFilter,
        statusFilter: widget.statusFilter,
        reportFilter: widget.reportFilter,
        onApply: widget.onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
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
              Transform.scale(scale: 1.0 - 0.05 * _ctrl.value, child: child),
          child: Stack(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _hasFilter ? AppAdmin.dark : AppAdmin.surfaceTint,
                borderRadius: BorderRadius.circular(14),
                boxShadow: _hasFilter
                    ? [
                        BoxShadow(
                            color: AppAdmin.dark.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4)),
                        BoxShadow(
                            color: AppAdmin.darkest.withOpacity(0.9),
                            blurRadius: 0,
                            offset: const Offset(0, 3)),
                      ]
                    : const [
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
                      ],
              ),
              child: Icon(Icons.tune_rounded,
                  color: _hasFilter ? Colors.white : AppAdmin.inkMid, size: 22),
            ),
            if (_hasFilter)
              Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: AppAdmin.accent,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppAdmin.surfaceTint, width: 1.5)))),
          ]),
        ),
      );
}

// ─── Review Filter Sheet ──────────────────────────────────────────────────────
class _ReviewFilterSheet extends StatefulWidget {
  final int? starFilter;
  final ReviewAdminStatus? statusFilter;
  final ReviewReportType? reportFilter;
  final void Function(
      int? star, ReviewAdminStatus? status, ReviewReportType? report) onApply;
  const _ReviewFilterSheet(
      {required this.starFilter,
      required this.statusFilter,
      required this.reportFilter,
      required this.onApply});
  @override
  State<_ReviewFilterSheet> createState() => _ReviewFilterSheetState();
}

class _ReviewFilterSheetState extends State<_ReviewFilterSheet> {
  int? _star;
  ReviewAdminStatus? _status;
  ReviewReportType? _report;
  @override
  void initState() {
    super.initState();
    _star = widget.starFilter;
    _status = widget.statusFilter;
    _report = widget.reportFilter;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppAdmin.surfaceTint,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
              color: AppAdmin.borderSoft, blurRadius: 20, offset: Offset(8, 8)),
          BoxShadow(
              color: Colors.white, blurRadius: 20, offset: Offset(-8, -8)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                  color: AppAdmin.borderSoft,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.white,
                        blurRadius: 2,
                        offset: Offset(-1, -1)),
                    BoxShadow(
                        color: AppAdmin.borderSoft,
                        blurRadius: 2,
                        offset: Offset(1, 1))
                  ]),
            )),
            const SizedBox(height: 20),
            Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppAdmin.surfaceTint,
                    boxShadow: const [
                      BoxShadow(
                          color: AppAdmin.borderSoft,
                          blurRadius: 8,
                          offset: Offset(4, 4)),
                      BoxShadow(
                          color: Colors.white,
                          blurRadius: 8,
                          offset: Offset(-4, -4))
                    ]),
                child: const Icon(Icons.tune_rounded,
                    color: AppAdmin.inkMid, size: 22),
              ),
              const SizedBox(width: 14),
              const Text('Filter Reviews',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppAdmin.inkDark)),
            ]),
            const SizedBox(height: 18),
            Container(
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
                        color: Colors.white,
                        blurRadius: 6,
                        offset: Offset(-3, -3))
                  ]),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppAdmin.inkMid, size: 16),
                const SizedBox(width: 8),
                const Expanded(
                    child: Text(
                        'Filter by star rating, status, or report type.',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppAdmin.inkMid,
                            height: 1.4))),
              ]),
            ),
            const SizedBox(height: 18),
            const Text('Star Rating',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppAdmin.inkMid)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _ReviewNeoFilterChip(
                  label: 'All',
                  icon: Icons.all_inclusive_rounded,
                  selected: _star == null,
                  color: AppAdmin.dark,
                  onTap: () => setState(() => _star = null)),
              for (int s = 5; s >= 1; s--)
                _ReviewNeoFilterChip(
                    label: '${s}★',
                    icon: Icons.star_rounded,
                    selected: _star == s,
                    color: const Color(0xFFF59E0B),
                    onTap: () => setState(() => _star = _star == s ? null : s)),
            ]),
            const SizedBox(height: 16),
            const Text('Status',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppAdmin.inkMid)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _ReviewNeoFilterChip(
                  label: 'All',
                  icon: Icons.all_inclusive_rounded,
                  selected: _status == null,
                  color: AppAdmin.dark,
                  onTap: () => setState(() => _status = null)),
              _ReviewNeoFilterChip(
                  label: 'Visible',
                  icon: Icons.visibility_outlined,
                  selected: _status == ReviewAdminStatus.visible,
                  color: AppColors.success,
                  onTap: () => setState(() => _status =
                      _status == ReviewAdminStatus.visible
                          ? null
                          : ReviewAdminStatus.visible)),
              _ReviewNeoFilterChip(
                  label: 'Hidden',
                  icon: Icons.visibility_off_outlined,
                  selected: _status == ReviewAdminStatus.hidden,
                  color: AppColors.textSecondary,
                  onTap: () => setState(() => _status =
                      _status == ReviewAdminStatus.hidden
                          ? null
                          : ReviewAdminStatus.hidden)),
              _ReviewNeoFilterChip(
                  label: 'Deleted',
                  icon: Icons.delete_outline_rounded,
                  selected: _status == ReviewAdminStatus.deleted,
                  color: AppColors.error,
                  onTap: () => setState(() => _status =
                      _status == ReviewAdminStatus.deleted
                          ? null
                          : ReviewAdminStatus.deleted)),
            ]),
            const SizedBox(height: 16),
            const Text('Report Type',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppAdmin.inkMid)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _ReviewNeoFilterChip(
                  label: 'All',
                  icon: Icons.all_inclusive_rounded,
                  selected: _report == null,
                  color: AppAdmin.dark,
                  onTap: () => setState(() => _report = null)),
              _ReviewNeoFilterChip(
                  label: 'Fake',
                  icon: Icons.warning_amber_rounded,
                  selected: _report == ReviewReportType.fake,
                  color: AppAdmin.accent,
                  onTap: () => setState(() => _report =
                      _report == ReviewReportType.fake
                          ? null
                          : ReviewReportType.fake)),
              _ReviewNeoFilterChip(
                  label: 'Offensive',
                  icon: Icons.block_rounded,
                  selected: _report == ReviewReportType.offensive,
                  color: AppColors.error,
                  onTap: () => setState(() => _report =
                      _report == ReviewReportType.offensive
                          ? null
                          : ReviewReportType.offensive)),
              _ReviewNeoFilterChip(
                  label: 'Spam',
                  icon: Icons.report_outlined,
                  selected: _report == ReviewReportType.spam,
                  color: const Color(0xFFF97316),
                  onTap: () => setState(() => _report =
                      _report == ReviewReportType.spam
                          ? null
                          : ReviewReportType.spam)),
            ]),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                  child: GestureDetector(
                onTap: () {
                  widget.onApply(null, null, null);
                  Navigator.pop(context);
                },
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                      color: AppAdmin.surfaceTint,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: const [
                        BoxShadow(
                            color: AppAdmin.borderSoft,
                            blurRadius: 0,
                            offset: Offset(0, 4)),
                        BoxShadow(
                            color: AppAdmin.borderSoft,
                            blurRadius: 6,
                            offset: Offset(4, 4)),
                        BoxShadow(
                            color: Colors.white,
                            blurRadius: 6,
                            offset: Offset(-3, -3))
                      ]),
                  child: const Center(
                      child: Text('Clear',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppAdmin.inkMid))),
                ),
              )),
              const SizedBox(width: 12),
              Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () {
                      widget.onApply(_star, _status, _report);
                      Navigator.pop(context);
                    },
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        gradient: const LinearGradient(
                            colors: [AppAdmin.dark, AppAdmin.darkest],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                        boxShadow: [
                          BoxShadow(
                              color: AppAdmin.dark.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 4)),
                          BoxShadow(
                              color: AppAdmin.darkest.withOpacity(0.9),
                              blurRadius: 0,
                              offset: const Offset(0, 3))
                        ],
                      ),
                      child: const Center(
                          child: Text('Apply Filters',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white))),
                    ),
                  )),
            ]),
          ]),
    );
  }
}

// ─── Review Neo Filter Chip ───────────────────────────────────────────────────
class _ReviewNeoFilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _ReviewNeoFilterChip(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.color,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color : AppAdmin.surfaceTint,
            borderRadius: BorderRadius.circular(14),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4)),
                    BoxShadow(
                        color: Color.lerp(color, Colors.black, 0.3)!
                            .withOpacity(0.9),
                        blurRadius: 0,
                        offset: const Offset(0, 3)),
                  ]
                : const [
                    BoxShadow(
                        color: AppAdmin.borderSoft,
                        blurRadius: 0,
                        offset: Offset(0, 3)),
                    BoxShadow(
                        color: AppAdmin.borderSoft,
                        blurRadius: 5,
                        offset: Offset(3, 3)),
                    BoxShadow(
                        color: Colors.white,
                        blurRadius: 5,
                        offset: Offset(-3, -3)),
                  ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: selected ? Colors.white : color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppAdmin.inkMid)),
          ]),
        ),
      );
}

// ─── Review Neo Chip ─────────────────────────────────────────────────────────
class _ReviewNeoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _ReviewNeoChip(
      {required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.22), width: 1),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.12),
                blurRadius: 0,
                offset: const Offset(0, 2)),
            BoxShadow(
                color: color.withOpacity(0.10),
                blurRadius: 4,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          // Bounded so a single long label (e.g. an order id) can never
          // make one chip wide enough to push past the card's edge — Wrap
          // only reflows *between* chips, it doesn't constrain an
          // individual child's own width.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color.withOpacity(0.9))),
          ),
        ]),
      );
}

// ─── Review Three-Dots Menu ───────────────────────────────────────────────────
class _ReviewThreeDotsMenu extends StatefulWidget {
  final AdminReview adminReview;
  final Color statusColor;
  const _ReviewThreeDotsMenu(
      {required this.adminReview, required this.statusColor});
  @override
  State<_ReviewThreeDotsMenu> createState() => _ReviewThreeDotsMenuState();
}

class _ReviewThreeDotsMenuState extends State<_ReviewThreeDotsMenu>
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

  void _open(BuildContext context, WidgetRef ref) {
    HapticFeedback.lightImpact();
    final r = widget.adminReview.review;
    final isHidden = widget.adminReview.status == ReviewAdminStatus.hidden;
    final scaffoldMsg = ScaffoldMessenger.of(context);

    void snack(String msg, Color color) => scaffoldMsg.showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));

    // Review Management only manages the review itself: Hide/Unhide + Warn.
    // Complaint decisions, delete, and profile/order navigation are handled
    // elsewhere (Complaints Center / Review Details cards), matching the
    // Review Details action set exactly.
    final items = <_ReviewMenuItemData>[
      if (!isHidden)
        _ReviewMenuItemData(
            icon: Icons.visibility_off_outlined,
            label: 'Hide Review',
            color: AppColors.textSecondary,
            onTap: () async {
              final confirmed =
                  await _confirmVisibilityChange(context, hide: true);
              if (!confirmed) return;
              try {
                await _setReviewVisibility(ref, r, hide: true);
                snack('Review hidden', AppColors.textSecondary);
              } catch (_) {
                snack('Could not hide review. Please try again.',
                    AppColors.error);
              }
            }),
      if (isHidden)
        _ReviewMenuItemData(
            icon: Icons.visibility_outlined,
            label: 'Unhide Review',
            color: AppColors.success,
            onTap: () async {
              final confirmed =
                  await _confirmVisibilityChange(context, hide: false);
              if (!confirmed) return;
              try {
                await _setReviewVisibility(ref, r, hide: false);
                snack('Review restored ✓', AppColors.success);
              } catch (_) {
                snack('Could not restore review. Please try again.',
                    AppColors.error);
              }
            }),
      _ReviewMenuItemData(
          icon: Icons.warning_amber_rounded,
          label: 'Warn User',
          color: const Color(0xFFF97316),
          onTap: () => showAdminUserModal(
              context: context,
              builder: (_) => _WarnDialog(
                    userName: r.customerName,
                    onConfirm: (msg) async {
                      await _sendReviewerWarning(ref, r, msg);
                      snack('Warning sent to ${r.customerName}',
                          const Color(0xFFF97316));
                    },
                  ))),
    ];

    final box = context.findRenderObject() as RenderBox?;
    final pos = box?.localToGlobal(Offset.zero) ?? Offset.zero;
    final size = box?.size ?? Size.zero;
    _openMenuPanel(context, pos, size, items);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
        builder: (context, ref, _) => GestureDetector(
              onTapDown: (_) {
                HapticFeedback.lightImpact();
                _ctrl.forward();
              },
              onTapUp: (_) {
                _ctrl.reverse();
                _open(context, ref);
              },
              onTapCancel: () => _ctrl.reverse(),
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (_, child) => Transform.scale(
                    scale: 1.0 - 0.08 * _ctrl.value, child: child),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppAdmin.surfaceTint,
                    borderRadius: BorderRadius.circular(10),
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
                    ],
                  ),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                          3,
                          (_) => Container(
                                width: 3.5,
                                height: 3.5,
                                margin:
                                    const EdgeInsets.symmetric(vertical: 1.2),
                                decoration: BoxDecoration(
                                    color: widget.statusColor.withOpacity(0.75),
                                    shape: BoxShape.circle),
                              ))),
                ),
              ),
            ));
  }
}

// Viewport-aware floating panel opener shared by the review-card and
// criteria-card three-dots triggers: opens upward when there is not enough
// space below (e.g. near the bottom of the screen / above the Admin bottom
// nav), keeps the panel inside the viewport, and lets the panel's own item
// column scroll internally if neither direction fully fits — same fix
// already applied to Admin Users/Complaints per-card menus.
void _openMenuPanel(BuildContext context, Offset pos, Size size,
    List<_ReviewMenuItemData> items) {
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

  const panelWidth = 60.0;
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
                child:
                    _ReviewMenuPanel(items: items, maxHeight: maxPanelHeight)),
          ),
        ),
      ]);
    },
  );
}

class _ReviewMenuItemData {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ReviewMenuItemData(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
}

class _ReviewMenuPanel extends StatefulWidget {
  final List<_ReviewMenuItemData> items;
  // Set only when the panel wouldn't otherwise fully fit above or below the
  // trigger within the viewport — constrains the item column to the actual
  // available space and makes it scrollable so every action stays reachable
  // instead of being clipped off-screen. Null (the common case) keeps the
  // previous unconstrained, non-scrolling layout unchanged.
  final double? maxHeight;
  const _ReviewMenuPanel({required this.items, this.maxHeight});
  @override
  State<_ReviewMenuPanel> createState() => _ReviewMenuPanelState();
}

class _ReviewMenuPanelState extends State<_ReviewMenuPanel>
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
          curve: Interval(
              (i / n).clamp(0.0, 1.0), ((i + 1) / n).clamp(0.0, 1.0),
              curve: Curves.easeOutBack));
      return AnimatedBuilder(
          animation: anim,
          builder: (_, child) => Opacity(
              opacity: anim.value.clamp(0.0, 1.0),
              child: Transform.scale(
                  scale: 0.6 + 0.4 * anim.value.clamp(0.0, 1.0), child: child)),
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    item.onTap();
                  },
                  child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppAdmin.surfaceTint,
                          boxShadow: const [
                            BoxShadow(
                                color: AppAdmin.borderSoft,
                                blurRadius: 6,
                                offset: Offset(3, 3)),
                            BoxShadow(
                                color: Colors.white,
                                blurRadius: 6,
                                offset: Offset(-3, -3))
                          ]),
                      child: Icon(item.icon, color: item.color, size: 20)))));
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
      width: 60,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: AppAdmin.surfaceTint,
          boxShadow: const [
            BoxShadow(
                color: AppAdmin.borderSoft,
                blurRadius: 16,
                offset: Offset(6, 6)),
            BoxShadow(
                color: Colors.white, blurRadius: 16, offset: Offset(-6, -6))
          ]),
      clipBehavior: Clip.antiAlias,
      child: list,
    );
  }
}

// ─── Bottom Nav Item ──────────────────────────────────────────────────────────
class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _BottomNavItem(
      {required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 22, color: AppAdmin.inkMid),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppAdmin.inkMid)),
        ]),
      );
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatChip(
      {required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.06), blurRadius: 6)
            ]),
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w900, color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: AppAdmin.dark,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

class _FilterChip2 extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _FilterChip2(
      {required this.label,
      required this.selected,
      required this.color,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: selected ? color : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? color : AppAdmin.lightest),
              boxShadow: selected
                  ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 6)]
                  : []),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppAdmin.dark)),
        ),
      );
}

class _MiniAvatar extends StatelessWidget {
  final String name, id;
  final Color color;
  final String? avatarUrl;
  const _MiniAvatar(
      {required this.name, this.id = '', required this.color, this.avatarUrl});
  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppAdmin.surfaceTint,
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.25),
                blurRadius: 6,
                offset: const Offset(3, 3)),
            const BoxShadow(
                color: Colors.white, blurRadius: 6, offset: Offset(-3, -3)),
          ],
        ),
        child: ProfileAvatarImage(
            imageUrl: avatarUrl,
            size: 40,
            fallbackText: name,
            fallbackTextStyle: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: color)),
      );
}

// Premium raised person card — same neo language as Complaint Summary's
// "Parties Involved" card (_CxPartyCard): elevated surface, dual
// borderSoft/white shadow, raised chevron button when tappable.
class _PersonTile extends StatelessWidget {
  final String name, subtitle;
  final Color color;
  final VoidCallback? onTap;
  final String? avatarUrl;
  const _PersonTile(
      {required this.name,
      required this.subtitle,
      required this.color,
      this.onTap,
      this.avatarUrl});
  @override
  Widget build(BuildContext context) => GestureDetector(
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
            _MiniAvatar(name: name, color: color, avatarUrl: avatarUrl),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppAdmin.inkDark)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 11, color: AppAdmin.mid)),
                ])),
            if (onTap != null) ...[
              const SizedBox(width: 8),
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
                    size: 12, color: color),
              ),
            ],
          ]),
        ),
      );
}

// Section label with a raised 3D icon chip — same visual family as
// Complaint Summary's _CxNeoSectionLabel, adapted with a per-section icon
// identifier (kept from the original design) instead of a plain accent bar.
class _DetailSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final Widget child;
  const _DetailSection(
      {required this.icon,
      required this.title,
      required this.color,
      required this.child});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppAdmin.surfaceTint,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(0.25),
                    blurRadius: 5,
                    offset: const Offset(2, 2)),
                const BoxShadow(
                    color: Colors.white, blurRadius: 5, offset: Offset(-2, -2)),
              ],
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppAdmin.inkDark))),
        ]),
        const SizedBox(height: 10),
        child,
      ]);
}

// Inset detail row for the Review Details page — same "icon + label + value"
// raised-card look as Complaint Summary's _CxNeoDetailRow.
class _RevInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? valueChip;
  final Color color;
  const _RevInfoRow({
    required this.icon,
    required this.label,
    this.value,
    this.valueChip,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppAdmin.surfaceTint,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
                color: AppAdmin.borderSoft,
                blurRadius: 4,
                offset: Offset(2, 2)),
            BoxShadow(
                color: Colors.white, blurRadius: 4, offset: Offset(-2, -2)),
          ],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppAdmin.inkMid,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          Flexible(
              child: valueChip ??
                  Text(value ?? '—',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppAdmin.inkDark),
                      textAlign: TextAlign.end)),
        ]),
      );
}

// Premium raised pill action button — same neo elevation as the other
// redesigned Admin per-card action controls (colored shadow, 3D lift).
class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool loading;
  const _ActionBtn(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap,
      this.loading = false});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: loading ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: loading
                ? null
                : LinearGradient(
                    colors: [color, Color.lerp(color, Colors.black, 0.25)!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
            color: loading ? color.withOpacity(0.10) : null,
            boxShadow: loading
                ? []
                : [
                    BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4)),
                    BoxShadow(
                        color: Color.lerp(color, Colors.black, 0.3)!
                            .withOpacity(0.9),
                        blurRadius: 0,
                        offset: const Offset(0, 3)),
                  ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            loading
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child:
                        CircularProgressIndicator(strokeWidth: 2, color: color))
                : Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: loading ? color.withOpacity(0.7) : Colors.white)),
          ]),
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppAdmin.darkest, AppAdmin.accent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter),
                borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppAdmin.darkest,
                letterSpacing: 0.2)),
      ]);
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 60, color: AppAdmin.lightest),
        const SizedBox(height: 12),
        Text(message,
            style: const TextStyle(
                color: AppAdmin.mid, fontWeight: FontWeight.w600)),
      ]));
}
