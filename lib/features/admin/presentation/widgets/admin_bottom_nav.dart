// ─── Shared Admin bottom navigation ───────────────────────────────────────────
// Single source of truth for the Home / "+" / Profile bottom bar used by
// every top-level Admin screen. Extracted from AdminHomeScreen's original
// private _AdminBottomNav/_showPlusMenu so Review Management and Chat
// Management (both pushed on top of AdminHomeScreen, not tabs inside it) can
// reuse the exact same design and behavior instead of a second, divergent
// implementation.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/models.dart';
import '../providers/admin_providers.dart';
import '../../../auth/presentation/providers/app_providers.dart'
    show adminOrderStatsProvider, AdminOrderStats, adminChatReportsProvider;
import '../screens/admin_review_management_screen.dart';
import '../screens/admin_chat_screen.dart';

// ─── Navigation helpers ───────────────────────────────────────────────────────
// Both helpers select the tab on the one existing AdminHomeScreen instance
// (root of the admin navigator stack — see main.dart) and pop back to it,
// rather than pushing a second Home/Profile screen. From AdminHomeScreen's
// own bottom nav there is nothing to pop, so popUntil(isFirst) is a no-op;
// from a pushed screen (Review Management, Chat Management) it cleans up the
// stack down to that single Home instance first.
void goToAdminHomeTab(BuildContext context, WidgetRef ref) {
  HapticFeedback.selectionClick();
  ref.read(adminNavIndexProvider.notifier).state = 0;
  Navigator.popUntil(context, (route) => route.isFirst);
}

void goToAdminProfileTab(BuildContext context, WidgetRef ref) {
  HapticFeedback.selectionClick();
  ref.read(adminNavIndexProvider.notifier).state = 5;
  Navigator.popUntil(context, (route) => route.isFirst);
}

/// Sum of open complaints + pending orders — the same figure Admin Home's
/// own "+" button already badges, computed here once so every screen that
/// reuses [AdminBottomNav] shows an identical count. Uses `ref.watch` (not
/// `ref.read`) so it stays live wherever it's called from inside `build()`,
/// and reads live Firestore order stats rather than the in-memory dummy
/// `ordersProvider` so it agrees with the Dashboard/Orders tab.
int adminTotalBadgeCount(WidgetRef ref) {
  final complaints = ref.watch(adminComplaintsProvider);
  final orderStats =
      ref.watch(adminOrderStatsProvider).valueOrNull ?? AdminOrderStats.empty;
  final openComplaints =
      complaints.where((c) => c.status == ComplaintStatus.open).length;
  return openComplaints + orderStats.pending;
}

// ─── Admin Sections sheet (center "+" button) ─────────────────────────────────
void showAdminSectionsMenu(BuildContext context, WidgetRef ref) {
  HapticFeedback.mediumImpact();
  final complaints = ref.read(adminComplaintsProvider);
  final orderStats =
      ref.read(adminOrderStatsProvider).valueOrNull ?? AdminOrderStats.empty;
  final openComplaints =
      complaints.where((c) => c.status == ComplaintStatus.open).length;
  final pendingOrders = orderStats.pending;
  final catRequests = ref.read(categoryRequestsProvider.notifier).unreadCount;
  final chatReports = ref.read(adminChatReportsProvider).valueOrNull ??
      const <ChatReportModel>[];
  final chatRequests = chatReports.where((r) => !r.isSeenByAdmin).length;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppAdmin.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.grid_view_rounded,
                            color: AppAdmin.dark, size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Text('Admin Sections',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3)),
                    ]),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  controller: scrollController,
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
                  children: [
                    _PlusMenuItem(
                      icon: Icons.people_rounded,
                      label: 'Users',
                      color: const Color(0xFF052659),
                      badge: 0,
                      onTap: () {
                        Navigator.pop(context);
                        ref.read(adminNavIndexProvider.notifier).state = 1;
                        Navigator.popUntil(context, (route) => route.isFirst);
                      },
                    ),
                    _PlusMenuItem(
                      icon: Icons.receipt_long_rounded,
                      label: 'Orders',
                      color: AppAdmin.dark,
                      badge: pendingOrders,
                      onTap: () {
                        Navigator.pop(context);
                        ref.read(adminNavIndexProvider.notifier).state = 2;
                        Navigator.popUntil(context, (route) => route.isFirst);
                      },
                    ),
                    _PlusMenuItem(
                      icon: Icons.shield_rounded,
                      label: 'Complaints Center',
                      color: AppColors.error,
                      badge: openComplaints,
                      onTap: () {
                        Navigator.pop(context);
                        ref.read(adminNavIndexProvider.notifier).state = 4;
                        Navigator.popUntil(context, (route) => route.isFirst);
                      },
                    ),
                    _PlusMenuItem(
                      icon: Icons.star_rounded,
                      label: 'Review Management',
                      color: const Color(0xFFF59E0B),
                      badge: 0,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.popUntil(context, (route) => route.isFirst);
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const AdminReviewManagementScreen()));
                      },
                    ),
                    _PlusMenuItem(
                      icon: Icons.chat_rounded,
                      label: 'Chat Management',
                      color: const Color(0xFF0077B6),
                      badge: chatRequests,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.popUntil(context, (route) => route.isFirst);
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AdminChatScreen()));
                      },
                    ),
                    _PlusMenuItem(
                      icon: Icons.category_rounded,
                      label: 'Categories',
                      color: const Color(0xFF235347),
                      badge: catRequests,
                      onTap: () {
                        Navigator.pop(context);
                        ref.read(adminNavIndexProvider.notifier).state = 3;
                        Navigator.popUntil(context, (route) => route.isFirst);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ─── Admin Bottom Navigation Bar ─────────────────────────────────────────────
class AdminBottomNav extends StatelessWidget {
  final int selectedIndex;
  final int totalBadge;
  final VoidCallback onHomeTap;
  final VoidCallback onPlusTap;
  final VoidCallback onProfileTap;

  const AdminBottomNav({
    super.key,
    required this.selectedIndex,
    required this.totalBadge,
    required this.onHomeTap,
    required this.onPlusTap,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Home
            _NavItem(
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard_rounded,
              label: 'Home',
              isSelected: selectedIndex == 0,
              badge: 0,
              onTap: onHomeTap,
            ),

            // Center Plus Button
            Builder(
                builder: (ctx) => GestureDetector(
                      onTap: onPlusTap,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppAdmin.accent, AppAdmin.dark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppAdmin.accent.withOpacity(0.45),
                              blurRadius: 16,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Center(
                              child: Icon(Icons.add_rounded,
                                  color: Colors.white, size: 28),
                            ),
                            if (totalBadge > 0)
                              Positioned(
                                top: -2,
                                right: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF3B30),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 1.5),
                                  ),
                                  constraints: const BoxConstraints(
                                      minWidth: 18, minHeight: 18),
                                  child: Text(
                                    totalBadge > 99 ? '99+' : '$totalBadge',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    )),

            // Profile
            _NavItem(
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'Profile',
              isSelected: selectedIndex == 2,
              badge: 0,
              onTap: onProfileTap,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Nav Item (same style as customer) ───────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final bool isSelected;
  final int badge;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppAdmin.accent.withOpacity(0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    isSelected ? activeIcon : icon,
                    key: ValueKey(isSelected),
                    color:
                        isSelected ? AppAdmin.accent : const Color(0xFFBDBDBD),
                    size: 24,
                  ),
                ),
                if (badge > 0)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF3B30),
                        shape: BoxShape.circle,
                      ),
                      constraints:
                          const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        badge > 9 ? '9+' : '$badge',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppAdmin.accent : const Color(0xFFBDBDBD),
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Plus Menu Item (Admin Sections sheet row) ────────────────────────────────
class _PlusMenuItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final int badge;
  final VoidCallback onTap;
  const _PlusMenuItem(
      {required this.icon,
      required this.label,
      required this.color,
      required this.badge,
      required this.onTap});
  @override
  State<_PlusMenuItem> createState() => _PlusMenuItemState();
}

class _PlusMenuItemState extends State<_PlusMenuItem>
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
    final c2 = Color.lerp(widget.color, Colors.black, 0.35)!;
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
            Transform.scale(scale: 1.0 - 0.02 * _ctrl.value, child: child),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: AppAdmin.surfaceTint,
            borderRadius: BorderRadius.circular(18),
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
                  color: Colors.white, blurRadius: 8, offset: Offset(-3, -3)),
            ],
          ),
          child: Row(children: [
            // 3D icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [widget.color, c2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(13),
                boxShadow: [
                  BoxShadow(
                      color: widget.color.withOpacity(0.4),
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
                    height: 21,
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
                Center(child: Icon(widget.icon, color: Colors.white, size: 20)),
              ]),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(widget.label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppAdmin.inkDarkest)),
            ),
            if (widget.badge > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20)),
                child: Text('${widget.badge}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: widget.color)),
              ),
            const SizedBox(width: 8),
            // Neo-3D arrow button
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: AppAdmin.surfaceTint,
                borderRadius: BorderRadius.all(Radius.circular(9)),
                boxShadow: [
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
              child: const Icon(Icons.arrow_forward_ios_rounded,
                  size: 12, color: AppAdmin.inkMid),
            ),
          ]),
        ),
      ),
    );
  }
}
