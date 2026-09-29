import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/admin_providers.dart';
import '../../../auth/presentation/providers/app_providers.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/shared_widgets.dart' show ProfileAvatarImage;
import 'admin_users_screen.dart' show showAdminUserDetails;
import 'admin_complaints_screen.dart' show showAdminComplaintSummary;
import 'admin_screens.dart' show showAdminOrderDetails;

// ─── Neo-3D surface tokens (same recipe as the Admin Profile screen) ─────────
const _adminBg = AppAdmin.surfaceTint;
const _adminShadowDark = AppAdmin.borderSoft;
const _adminShadowLight = Colors.white;

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  void _showNotificationsPanel(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AdminNotificationsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final firestoreState = ref.watch(firestoreUsersStreamProvider);
    final users = ref.watch(adminUsersProvider);
    final categories = ref.watch(adminCategoriesProvider);
    final complaints = ref.watch(adminComplaintsProvider);
    final blocked = ref.watch(blockedUsersProvider);

    // Order counts from Firestore (Phase 5C)
    final statsAsync = ref.watch(adminOrderStatsProvider);
    final stats = statsAsync.valueOrNull ?? AdminOrderStats.empty;
    final orderStatsLoading = statsAsync.isLoading;
    final recentOrdersAsync = ref.watch(adminFirestoreOrdersProvider);
    final recentOrders = (recentOrdersAsync.valueOrNull ?? []).take(4).toList();

    final customers = users.where((u) => u.role == UserRole.customer).length;
    final professionals =
        users.where((u) => u.role == UserRole.professional).length;
    final contractors =
        users.where((u) => u.role == UserRole.contractor).length;
    final pendingOrders = stats.pending;
    final completedOrders = stats.completed;
    final openComplaints =
        complaints.where((c) => c.status == ComplaintStatus.open).length;
    final recentUsers = users.reversed.take(4).toList();
    final recentComplaints = complaints
        .where((c) => c.status == ComplaintStatus.open)
        .take(3)
        .toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : _adminBg,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Premium Lilac Header ───────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppAdmin.inkDarkest,
                      AppAdmin.darkest,
                      AppAdmin.dark
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(36),
                    bottomRight: Radius.circular(36),
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: Color(0x60321143),
                        blurRadius: 28,
                        offset: Offset(0, 12))
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        // Glossy 3D brand-mark (same gradient/gloss recipe
                        // as the avatar container on Admin Profile)
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppAdmin.accent, AppAdmin.dark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                  color: AppAdmin.accent.withOpacity(0.45),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6)),
                            ],
                          ),
                          child: Stack(children: [
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 24,
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                      topRight: Radius.circular(16)),
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
                            const Center(
                              child: Icon(Icons.admin_panel_settings_rounded,
                                  color: Colors.white, size: 26),
                            ),
                          ]),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              const Text('Dashboard',
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: -0.5)),
                              Text('San3a Admin Panel',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.7))),
                            ])),
                        // "Live" glass pill with a glowing status dot
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.24)),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3)),
                            ],
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: const Color(0xFF00D97E),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                      color: const Color(0xFF00D97E)
                                          .withOpacity(0.7),
                                      blurRadius: 6),
                                ],
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text('Live',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ]),
                        ),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          onSelected: (val) {
                            if (val == 'notifications') {
                              _showNotificationsPanel(context, ref);
                            } else if (val == 'logout') {
                              ref.read(authProvider.notifier).logout();
                              Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const LoginScreen()),
                                  (r) => false);
                            }
                          },
                          color: Colors.white,
                          elevation: 8,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          offset: const Offset(0, 48),
                          itemBuilder: (_) {
                            final unread = ref.watch(adminUnreadCountProvider);
                            return [
                              PopupMenuItem(
                                  value: 'notifications',
                                  child: Row(children: [
                                    Stack(clipBehavior: Clip.none, children: [
                                      const Icon(Icons.notifications_outlined,
                                          color: AppAdmin.dark, size: 20),
                                      if (unread > 0)
                                        Positioned(
                                            right: -4,
                                            top: -4,
                                            child: Container(
                                                padding:
                                                    const EdgeInsets.all(3),
                                                decoration: const BoxDecoration(
                                                    color: AppAdmin.accent,
                                                    shape: BoxShape.circle),
                                                child: Text(
                                                    unread > 9
                                                        ? '9+'
                                                        : '$unread',
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 7,
                                                        fontWeight:
                                                            FontWeight.w700)))),
                                    ]),
                                    const SizedBox(width: 12),
                                    const Text('Notifications',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    if (unread > 0) ...[
                                      const Spacer(),
                                      Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                              color: AppAdmin.accent
                                                  .withOpacity(0.15),
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                          child: Text('$unread',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppAdmin.dark))),
                                    ],
                                  ])),
                              PopupMenuItem(
                                  value: 'logout',
                                  child: Row(children: [
                                    Icon(Icons.logout_rounded,
                                        color: AppColors.error, size: 20),
                                    const SizedBox(width: 12),
                                    Text('Logout',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.error)),
                                  ])),
                            ];
                          },
                          child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.more_vert_rounded,
                                  color: Colors.white, size: 20)),
                        ),
                      ]),
                      const SizedBox(height: 22),
                      // 3 clickable glass stat tiles in header
                      Row(children: [
                        _HeaderStat(
                            value: firestoreState.isLoading
                                ? '…'
                                : '${users.length}',
                            label: 'Users',
                            icon: Icons.people_rounded,
                            badge: blocked.isNotEmpty ? blocked.length : 0,
                            onTap: () => ref
                                .read(adminNavIndexProvider.notifier)
                                .state = 1),
                        const SizedBox(width: 10),
                        _HeaderStat(
                            value: orderStatsLoading ? '…' : '${stats.total}',
                            label: 'Orders',
                            icon: Icons.receipt_long_rounded,
                            badge: pendingOrders,
                            onTap: () => ref
                                .read(adminNavIndexProvider.notifier)
                                .state = 2),
                        const SizedBox(width: 10),
                        _HeaderStat(
                            value: '$openComplaints',
                            label: 'Open Complaints',
                            icon: Icons.report_rounded,
                            badge: openComplaints,
                            onTap: () => ref
                                .read(adminNavIndexProvider.notifier)
                                .state = 4),
                      ]),
                    ]),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ── Users breakdown ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _AdminSecTitle(title: 'Users Breakdown'),
                        const SizedBox(height: 12),
                        Row(children: [
                          _StatCard(
                              value:
                                  firestoreState.isLoading ? '…' : '$customers',
                              label: 'Customers',
                              icon: Icons.person_rounded,
                              color: const Color(0xFF052659)),
                          const SizedBox(width: 10),
                          _StatCard(
                              value: firestoreState.isLoading
                                  ? '…'
                                  : '$professionals',
                              label: 'Professionals',
                              icon: Icons.build_rounded,
                              color: const Color(0xFF235347)),
                          const SizedBox(width: 10),
                          _StatCard(
                              value: firestoreState.isLoading
                                  ? '…'
                                  : '$contractors',
                              label: 'Contractors',
                              icon: Icons.engineering_rounded,
                              color: AppAdmin.dark),
                        ]),
                      ])),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 22)),

            // ── Orders breakdown ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _AdminSecTitle(title: 'Orders Breakdown'),
                        const SizedBox(height: 12),
                        Row(children: [
                          _StatCard(
                              value: orderStatsLoading ? '…' : '$pendingOrders',
                              label: 'Pending',
                              icon: Icons.schedule_rounded,
                              color: const Color(0xFFF59E0B)),
                          const SizedBox(width: 10),
                          _StatCard(
                              value: orderStatsLoading
                                  ? '…'
                                  : '${stats.inProgress}',
                              label: 'In Progress',
                              icon: Icons.sync_rounded,
                              color: AppAdmin.dark),
                          const SizedBox(width: 10),
                          _StatCard(
                              value:
                                  orderStatsLoading ? '…' : '$completedOrders',
                              label: 'Completed',
                              icon: Icons.check_circle_rounded,
                              color: const Color(0xFF059669)),
                        ]),
                      ])),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 22)),

            // ── Summary tiles ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(children: [
                    Expanded(
                        child: GestureDetector(
                      onTap: () =>
                          ref.read(adminNavIndexProvider.notifier).state = 3,
                      child: _SummaryTile(
                          icon: Icons.category_rounded,
                          label: 'Categories',
                          value: '${categories.length}',
                          color: AppAdmin.dark),
                    )),
                    const SizedBox(width: 10),
                    Expanded(
                        child: GestureDetector(
                      onTap: () =>
                          ref.read(adminNavIndexProvider.notifier).state = 4,
                      child: _SummaryTile(
                          icon: Icons.report_rounded,
                          label: 'Complaints',
                          value: '${complaints.length}',
                          color: AppAdmin.accent),
                    )),
                  ])),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ── Recent Users ──────────────────────────────────────────────
            if (recentUsers.isNotEmpty) ...[
              SliverToBoxAdapter(
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const _AdminSecTitle(title: 'Recent Users'),
                            _ViewAllBtn(
                                onTap: () => ref
                                    .read(adminNavIndexProvider.notifier)
                                    .state = 1),
                          ]))),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                  (_, i) => _RecentUserCard(user: recentUsers[i], ref: ref),
                  childCount: recentUsers.length,
                )),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],

            // ── Recent Complaints ─────────────────────────────────────────
            if (recentComplaints.isNotEmpty) ...[
              SliverToBoxAdapter(
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const _AdminSecTitle(title: 'Open Complaints'),
                            _ViewAllBtn(
                                onTap: () => ref
                                    .read(adminNavIndexProvider.notifier)
                                    .state = 4),
                          ]))),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                  (_, i) => _RecentComplaintCard(
                      complaint: recentComplaints[i], ref: ref, users: users),
                  childCount: recentComplaints.length,
                )),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],

            // ── Recent Orders ─────────────────────────────────────────────
            SliverToBoxAdapter(
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const _AdminSecTitle(title: 'Recent Orders'),
                          _ViewAllBtn(
                              onTap: () => ref
                                  .read(adminNavIndexProvider.notifier)
                                  .state = 2),
                        ]))),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                (_, i) => _RecentOrderCard(order: recentOrders[i], ref: ref),
                childCount: recentOrders.length,
              )),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 36)),
          ],
        ),
      ),
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

// Glass stat tile used inside the header (frosted surface over the gradient,
// same glossy top-highlight treatment as the Neo-3D icon containers below).
class _HeaderStat extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final int badge;
  final VoidCallback onTap;
  const _HeaderStat(
      {required this.value,
      required this.label,
      required this.icon,
      required this.badge,
      required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.22)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Stack(children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 26,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18)),
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.14),
                          Colors.transparent
                        ]),
                  ),
                ),
              ),
              Column(children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(height: 6),
                Text(value,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
                Text(label,
                    style: TextStyle(
                        fontSize: 10, color: Colors.white.withOpacity(0.8)),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ]),
              if (badge > 0)
                Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppAdmin.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                              color: AppAdmin.accent.withOpacity(0.6),
                              blurRadius: 6,
                              offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Text('$badge',
                          style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                    )),
            ]),
          ),
        ),
      );
}

// Section label — same gradient bar + uppercase letter-spaced recipe as
// Admin Profile's _AdminSectionLabel.
class _AdminSecTitle extends StatelessWidget {
  final String title;
  const _AdminSecTitle({required this.title});
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppAdmin.accent, AppAdmin.darkest],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                  color: AppAdmin.accent.withOpacity(0.5),
                  blurRadius: 6,
                  offset: const Offset(0, 2)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(title.toUpperCase(),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppAdmin.inkDark,
                letterSpacing: 1.5)),
      ]);
}

class _ViewAllBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _ViewAllBtn({required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppAdmin.lightest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppAdmin.mid.withOpacity(0.35)),
            boxShadow: [
              BoxShadow(
                  color: AppAdmin.mid.withOpacity(0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: const Text('View All',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppAdmin.dark)),
        ),
      );
}

// Neo-3D breakdown stat card — same dual-shadow surface + glossy gradient
// icon box as Admin Profile's _AdminNeo3DStatCard. `color` stays whatever
// semantic status color the caller passes in (amber/blue/green/etc.).
class _StatCard extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  const _StatCard(
      {required this.value,
      required this.label,
      required this.icon,
      required this.color});
  @override
  Widget build(BuildContext context) {
    final c2 = Color.lerp(color, Colors.black, 0.35)!;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: const BoxDecoration(
          color: _adminBg,
          borderRadius: BorderRadius.all(Radius.circular(20)),
          boxShadow: [
            BoxShadow(
                color: _adminShadowDark, blurRadius: 0, offset: Offset(0, 5)),
            BoxShadow(
                color: _adminShadowDark, blurRadius: 12, offset: Offset(5, 5)),
            BoxShadow(
                color: _adminShadowLight,
                blurRadius: 12,
                offset: Offset(-5, -5)),
          ],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [color, c2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(0.45),
                    blurRadius: 10,
                    offset: const Offset(0, 5)),
                BoxShadow(
                    color: c2.withOpacity(0.9),
                    blurRadius: 0,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: Stack(children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 21,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(14),
                        topRight: Radius.circular(14)),
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
              Center(child: Icon(icon, color: Colors.white, size: 20)),
            ]),
          ),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                foreground: Paint()
                  ..shader = LinearGradient(colors: [color, c2])
                      .createShader(const Rect.fromLTWH(0, 0, 80, 30)),
              )),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: AppAdmin.inkMid,
                  fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

// Neo-3D summary tile — same recipe as _StatCard plus the small neumorphic
// chevron button used throughout Admin Profile's tappable rows.
class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _SummaryTile(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});
  @override
  Widget build(BuildContext context) {
    final c2 = Color.lerp(color, Colors.black, 0.35)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: const BoxDecoration(
        color: _adminBg,
        borderRadius: BorderRadius.all(Radius.circular(18)),
        boxShadow: [
          BoxShadow(
              color: _adminShadowDark, blurRadius: 0, offset: Offset(0, 5)),
          BoxShadow(
              color: _adminShadowDark, blurRadius: 14, offset: Offset(5, 5)),
          BoxShadow(
              color: _adminShadowLight, blurRadius: 14, offset: Offset(-5, -5)),
        ],
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [color, c2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                  color: color.withOpacity(0.45),
                  blurRadius: 8,
                  offset: const Offset(0, 4)),
              BoxShadow(
                  color: c2.withOpacity(0.9),
                  blurRadius: 0,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Stack(children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 20,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(13),
                      topRight: Radius.circular(13)),
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.2),
                        Colors.transparent
                      ]),
                ),
              ),
            ),
            Center(child: Icon(icon, color: Colors.white, size: 20)),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900, color: color)),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppAdmin.inkMid,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
        Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            color: _adminBg,
            borderRadius: BorderRadius.all(Radius.circular(10)),
            boxShadow: [
              BoxShadow(
                  color: _adminShadowDark, blurRadius: 0, offset: Offset(0, 3)),
              BoxShadow(
                  color: _adminShadowDark, blurRadius: 5, offset: Offset(3, 3)),
              BoxShadow(
                  color: _adminShadowLight,
                  blurRadius: 5,
                  offset: Offset(-3, -3)),
            ],
          ),
          child: const Icon(Icons.arrow_forward_ios_rounded,
              size: 12, color: AppAdmin.inkMid),
        ),
      ]),
    );
  }
}

class _RecentUserCard extends StatelessWidget {
  final UserModel user;
  final WidgetRef ref;
  const _RecentUserCard({required this.user, required this.ref});
  static const _roleColors = {
    UserRole.customer: Color(0xFF052659),
    UserRole.professional: Color(0xFF235347),
    UserRole.contractor: Color(0xFF7C3AED),
    UserRole.admin: AppAdmin.dark
  };
  static const _roleLabels = {
    UserRole.customer: 'Customer',
    UserRole.professional: 'Professional',
    UserRole.contractor: 'Contractor',
    UserRole.admin: 'Admin'
  };
  @override
  Widget build(BuildContext context) {
    final color = _roleColors[user.role] ?? AppAdmin.dark;
    final c2 = Color.lerp(color, Colors.black, 0.35)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: const BoxDecoration(
        color: _adminBg,
        borderRadius: BorderRadius.all(Radius.circular(18)),
        boxShadow: [
          BoxShadow(
              color: _adminShadowDark, blurRadius: 0, offset: Offset(0, 4)),
          BoxShadow(
              color: _adminShadowDark, blurRadius: 10, offset: Offset(4, 4)),
          BoxShadow(
              color: _adminShadowLight, blurRadius: 10, offset: Offset(-4, -4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => showAdminUserDetails(context, user, ref),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [color, c2],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: color.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4)),
                        BoxShadow(
                            color: c2.withOpacity(0.9),
                            blurRadius: 0,
                            offset: const Offset(0, 3)),
                      ]),
                  child: ProfileAvatarImage(
                    imageUrl: user.avatar,
                    size: 44,
                    borderRadius: 14,
                    fallbackText:
                        user.fullName.isNotEmpty ? user.fullName : '?',
                    fallbackTextStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800),
                  )),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(user.fullName,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppAdmin.inkDarkest)),
                    const SizedBox(height: 2),
                    Text(user.email,
                        style: const TextStyle(
                            fontSize: 12, color: AppAdmin.inkLight)),
                  ])),
              const SizedBox(width: 8),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        color.withOpacity(0.14),
                        color.withOpacity(0.06)
                      ]),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color.withOpacity(0.25))),
                  child: Text(_roleLabels[user.role] ?? 'Admin',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: color))),
              const SizedBox(width: 6),
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: _adminBg,
                  borderRadius: BorderRadius.all(Radius.circular(9)),
                  boxShadow: [
                    BoxShadow(
                        color: _adminShadowDark,
                        blurRadius: 0,
                        offset: Offset(0, 2)),
                    BoxShadow(
                        color: _adminShadowDark,
                        blurRadius: 4,
                        offset: Offset(2, 2)),
                    BoxShadow(
                        color: _adminShadowLight,
                        blurRadius: 4,
                        offset: Offset(-2, -2)),
                  ],
                ),
                child: const Icon(Icons.chevron_right_rounded,
                    size: 16, color: AppAdmin.inkMid),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _RecentComplaintCard extends StatelessWidget {
  final ComplaintModel complaint;
  final WidgetRef ref;
  final List<UserModel> users;
  const _RecentComplaintCard(
      {required this.complaint, required this.ref, required this.users});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: const BoxDecoration(
          color: _adminBg,
          borderRadius: BorderRadius.all(Radius.circular(16)),
          boxShadow: [
            BoxShadow(
                color: _adminShadowDark, blurRadius: 0, offset: Offset(0, 3)),
            BoxShadow(
                color: _adminShadowDark, blurRadius: 8, offset: Offset(3, 3)),
            BoxShadow(
                color: _adminShadowLight,
                blurRadius: 8,
                offset: Offset(-3, -3)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () =>
                showAdminComplaintSummary(context, complaint, ref, users),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Row(children: [
                Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                        color: AppAdmin.accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: AppAdmin.accent.withOpacity(0.5),
                              blurRadius: 5),
                        ])),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(complaint.reason,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppAdmin.inkDarkest)),
                      Text(complaint.userName,
                          style: const TextStyle(
                              fontSize: 11, color: AppAdmin.inkLight)),
                    ])),
                const SizedBox(width: 8),
                Text('${complaint.createdAt.day}/${complaint.createdAt.month}',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppAdmin.inkLight,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: _adminBg,
                    borderRadius: BorderRadius.all(Radius.circular(9)),
                    boxShadow: [
                      BoxShadow(
                          color: _adminShadowDark,
                          blurRadius: 0,
                          offset: Offset(0, 2)),
                      BoxShadow(
                          color: _adminShadowDark,
                          blurRadius: 4,
                          offset: Offset(2, 2)),
                      BoxShadow(
                          color: _adminShadowLight,
                          blurRadius: 4,
                          offset: Offset(-2, -2)),
                    ],
                  ),
                  child: const Icon(Icons.chevron_right_rounded,
                      size: 16, color: AppAdmin.inkMid),
                ),
              ]),
            ),
          ),
        ),
      );
}

class _RecentOrderCard extends StatelessWidget {
  final OrderModel order;
  final WidgetRef ref;
  const _RecentOrderCard({required this.order, required this.ref});
  @override
  Widget build(BuildContext context) {
    Color sc;
    switch (order.status) {
      case OrderStatus.pending:
        sc = const Color(0xFFF59E0B);
        break;
      case OrderStatus.inProgress:
        sc = AppAdmin.dark;
        break;
      case OrderStatus.completed:
        sc = const Color(0xFF059669);
        break;
      case OrderStatus.cancelled:
        sc = AppColors.error;
        break;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: const BoxDecoration(
        color: _adminBg,
        borderRadius: BorderRadius.all(Radius.circular(16)),
        boxShadow: [
          BoxShadow(
              color: _adminShadowDark, blurRadius: 0, offset: Offset(0, 3)),
          BoxShadow(
              color: _adminShadowDark, blurRadius: 8, offset: Offset(3, 3)),
          BoxShadow(
              color: _adminShadowLight, blurRadius: 8, offset: Offset(-3, -3)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showAdminOrderDetails(context, order, ref),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(children: [
              Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                      color: sc,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: sc.withOpacity(0.5), blurRadius: 5),
                      ])),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(order.title,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppAdmin.inkDarkest))),
              const SizedBox(width: 8),
              Text('${order.serviceDate.day}/${order.serviceDate.month}',
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppAdmin.inkLight,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: _adminBg,
                  borderRadius: BorderRadius.all(Radius.circular(9)),
                  boxShadow: [
                    BoxShadow(
                        color: _adminShadowDark,
                        blurRadius: 0,
                        offset: Offset(0, 2)),
                    BoxShadow(
                        color: _adminShadowDark,
                        blurRadius: 4,
                        offset: Offset(2, 2)),
                    BoxShadow(
                        color: _adminShadowLight,
                        blurRadius: 4,
                        offset: Offset(-2, -2)),
                  ],
                ),
                child: const Icon(Icons.chevron_right_rounded,
                    size: 16, color: AppAdmin.inkMid),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── Admin Notifications Sheet ───────────────────────────────────────────────
class _AdminNotificationsSheet extends ConsumerWidget {
  const _AdminNotificationsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(authProvider);
    final notificationsAsync = admin == null
        ? const AsyncValue<List<UserNotificationView>>.data(
            <UserNotificationView>[])
        : ref.watch(userNotificationsProvider(
            (userId: admin.id, role: UserRole.admin)));
    final notifications =
        notificationsAsync.valueOrNull ?? const <UserNotificationView>[];
    final unreadCount = notifications.where((n) => !n.isRead).length;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppAdmin.lightest,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [AppAdmin.darkest, AppAdmin.dark]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.notifications_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Notifications',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppAdmin.darkest)),
              const Spacer(),
              if (unreadCount > 0)
                TextButton(
                  onPressed: admin == null
                      ? null
                      : () => markAllNotificationsReadInFirestore(
                          admin.id, UserRole.admin),
                  child: const Text('Mark all read',
                      style: TextStyle(
                          color: AppAdmin.dark, fontWeight: FontWeight.w700)),
                ),
            ]),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: notificationsAsync.isLoading && !notificationsAsync.hasValue
                ? const Center(child: CircularProgressIndicator())
                : notificationsAsync.hasError && !notificationsAsync.hasValue
                    ? const Center(
                        child: Text('Failed to load notifications',
                            style: TextStyle(color: AppAdmin.mid)))
                    : notifications.isEmpty
                        ? const Center(
                            child: Text('No notifications yet',
                                style: TextStyle(color: AppAdmin.mid)))
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            itemCount: notifications.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) {
                              final n = notifications[i];
                              return _AdminNotificationTile(view: n);
                            },
                          ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _AdminNotificationTile extends ConsumerWidget {
  final UserNotificationView view;
  const _AdminNotificationTile({required this.view});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notification = view.notification;
    IconData icon;
    Color color;
    switch (notification.type) {
      case NotificationType.complaint:
        icon = Icons.report_problem_rounded;
        color = AppAdmin.accent;
        break;
      case NotificationType.orderUpdate:
        icon = Icons.receipt_long_rounded;
        color = AppAdmin.dark;
        break;
      case NotificationType.categoryRequest:
        icon = Icons.category_rounded;
        color = const Color(0xFF235347);
        break;
      case NotificationType.broadcast:
        icon = Icons.campaign_rounded;
        color = AppAdmin.mid;
        break;
      case NotificationType.chat:
        icon = Icons.chat_bubble_rounded;
        color = const Color(0xFF0EA5E9);
        break;
      case NotificationType.review:
        icon = Icons.star_rounded;
        color = const Color(0xFFF59E0B);
        break;
      case NotificationType.system:
        icon = Icons.settings_rounded;
        color = AppAdmin.mid;
        break;
      case NotificationType.general:
        icon = Icons.info_rounded;
        color = AppAdmin.mid;
        break;
    }

    return GestureDetector(
      onTap: () {
        final uid = ref.read(authProvider)?.id;
        if (!view.isRead && uid != null && uid.isNotEmpty) {
          markNotificationReadInFirestore(uid, notification.id);
        }
        // Navigate based on type, reusing the existing admin tab-switch pattern.
        if (notification.type == NotificationType.complaint ||
            notification.relatedComplaintId != null) {
          ref.read(adminNavIndexProvider.notifier).state = 4;
          Navigator.pop(context);
        } else if (notification.type == NotificationType.orderUpdate ||
            notification.relatedOrderId != null) {
          ref.read(adminNavIndexProvider.notifier).state = 2;
          Navigator.pop(context);
        } else if (notification.type == NotificationType.categoryRequest) {
          ref.read(adminNavIndexProvider.notifier).state = 3;
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('No related page available'),
              backgroundColor: Color(0xFF334155),
              behavior: SnackBarBehavior.floating));
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:
              view.isRead ? Colors.white : AppAdmin.lightest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: view.isRead
                  ? AppAdmin.lightest
                  : AppAdmin.dark.withOpacity(0.2)),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(notification.title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppAdmin.darkest)),
                const SizedBox(height: 2),
                Text(notification.message,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ])),
          if (!view.isRead)
            Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: AppAdmin.accent, shape: BoxShape.circle)),
        ]),
      ),
    );
  }
}
