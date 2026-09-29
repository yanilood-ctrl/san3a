import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/presentation/providers/app_providers.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../../shared/helpers/calendar_helper.dart';
import '../../../../shared/helpers/notification_navigation_helper.dart';
import '../../../professional/presentation/screens/professional_messages_screen.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import 'contractor_chat_screen.dart';
import 'contractor_messages_list_screen.dart';
import 'contractor_order_detail_screen.dart';
import 'contractor_suppliers_screen.dart';
import 'contractor_profile_screen.dart';
import '../../../help/presentation/screens/help_center_screen.dart';
import '../../../contractor_ai_planner/presentation/screens/contractor_ai_planner_screen.dart';
import '../theme/contractor_design.dart';

const _cColor =
    ContractorColors.dark; // Navy secondary — contractor identity color

// ── Contractor Navy/Blue Palette ──────────────────────────────────────────────
class AppBrown {
  static const darkest = ContractorColors.darkest; // header start, deep text
  static const dark = ContractorColors.dark; // header end, secondary
  static const mid = ContractorColors.mid; // buttons, time highlight, borders
  static const light = ContractorColors.light; // card backgrounds
  static const lightest =
      ContractorColors.lightest; // subtle schedule bg, lighter tint
  static const warm = ContractorColors.warm; // page / card bg (warmest)
}

// ─── Nav Shell ────────────────────────────────────────────────────────────────
class ContractorHomeScreen extends ConsumerWidget {
  const ContractorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navIndex = ref.watch(navIndexProvider);
    final l = AppLocalizations.of(context);
    final currentUser = ref.watch(authProvider);
    final firestoreConvsAsync = ref.watch(currentUserConversationsProvider);
    final unread = currentUser == null
        ? 0
        : (firestoreConvsAsync.valueOrNull ?? const <ConversationModel>[])
            .fold<int>(0, (s, c) => s + c.unreadCountFor(currentUser.id));

    final List<Widget> screens = [
      const ContractorDashboard(),
      const ContractorMessagesScreen(),
      ContractorSuppliersScreen(),
      ContractorProfileScreen(),
    ];

    final navItems = [
      {
        'icon': Icons.dashboard_outlined,
        'active': Icons.dashboard_rounded,
        'label': l.get('home'),
        'badge': 0
      },
      {
        'icon': Icons.chat_bubble_outline_rounded,
        'active': Icons.chat_bubble_rounded,
        'label': l.get('messages'),
        'badge': unread
      },
      {
        'icon': Icons.group_outlined,
        'active': Icons.group_rounded,
        'label': l.get('suppliers'),
        'badge': 0
      },
      {
        'icon': Icons.person_outline_rounded,
        'active': Icons.person_rounded,
        'label': l.get('profile'),
        'badge': 0
      },
    ];

    return Scaffold(
      body: IndexedStack(index: navIndex, children: screens),
      extendBody: true,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: SizedBox(
          height: 72,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // White pill background
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                top: 20,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(36),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFDC7D4E).withOpacity(0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.07),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              // Nav items
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                top: 0,
                child: Row(
                  children: List.generate(navItems.length, (i) {
                    final item = navItems[i];
                    final sel = navIndex == i;
                    final badge = item['badge'] as int;
                    return Expanded(
                      child: _ContractorNavItem(
                        icon: item['icon'] as IconData,
                        activeIcon: item['active'] as IconData,
                        label: item['label'] as String,
                        selected: sel,
                        badge: badge,
                        onTap: () =>
                            ref.read(navIndexProvider.notifier).state = i,
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Contractor Nav Item (matches professional style) ─────────────────────────
class _ContractorNavItem extends StatefulWidget {
  final IconData icon, activeIcon;
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;
  const _ContractorNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.badge,
    required this.onTap,
  });
  @override
  State<_ContractorNavItem> createState() => _ContractorNavItemState();
}

class _ContractorNavItemState extends State<_ContractorNavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brownMid = ContractorColors.mid;
    final brownDark = ContractorColors.dark;

    if (widget.selected && _ctrl.status != AnimationStatus.completed)
      _ctrl.forward();
    if (!widget.selected && _ctrl.status != AnimationStatus.dismissed)
      _ctrl.reverse();

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            // Active bubble
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              width: widget.selected ? 48 : 36,
              height: widget.selected ? 36 : 28,
              // Selected: the Contractor brand gradient pill. Its icon uses
              // onBrand ink, since the gradient's gold end is too light for a
              // white glyph. Unselected stays neutral warm-gray.
              decoration: widget.selected
                  ? BoxDecoration(
                      gradient: ContractorColors.brandGradient,
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [
                        BoxShadow(
                            color: brownMid.withOpacity(0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4)),
                        const BoxShadow(
                            color: Color(0xFFD9C6B2),
                            blurRadius: 0,
                            offset: Offset(0, 3)),
                        const BoxShadow(
                            color: Colors.white,
                            blurRadius: 6,
                            offset: Offset(-3, -3)),
                      ],
                    )
                  : null,
              child: Center(
                child: Stack(clipBehavior: Clip.none, children: [
                  Icon(
                    widget.selected ? widget.activeIcon : widget.icon,
                    color: widget.selected
                        ? ContractorColors.onBrand
                        : const Color(0xFFC7B29C),
                    size: widget.selected ? 20 : 22,
                  ),
                  if (widget.badge > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                            color: Color(0xFFFF4444), shape: BoxShape.circle),
                        child: Text(widget.badge > 9 ? '9+' : '${widget.badge}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: TextStyle(
                fontSize: 10,
                fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
                color: widget.selected ? brownDark : const Color(0xFFC7B29C),
              ),
              child: Text(widget.label),
            ),
          ]);
        },
      ),
    );
  }
}

// ─── Dashboard ────────────────────────────────────────────────────────────────
class ContractorDashboard extends ConsumerStatefulWidget {
  const ContractorDashboard({super.key});
  @override
  ConsumerState<ContractorDashboard> createState() =>
      _ContractorDashboardState();
}

class _ContractorDashboardState extends ConsumerState<ContractorDashboard> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _filter = 'all';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showNotificationsSheet(BuildContext context, int pendingCount) {
    final user = ref.read(authProvider);
    // Captured before the modal sheet's own (shadowed) context gets popped —
    // review lookup is async, so navigation/snackbars after the await must
    // use a context that outlives the sheet, not the sheet's own context.
    final homeContext = context;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Consumer(
        builder: (context, ref, __) {
          final models = user == null
              ? const <UserNotificationView>[]
              : ref
                      .watch(userNotificationsProvider(
                          (userId: user.id, role: UserRole.contractor)))
                      .valueOrNull ??
                  const <UserNotificationView>[];
          final notifs = models.map(_cNotifFromModel).toList();
          final unreadCount = models.where((m) => !m.isRead).length;
          return Container(
            height: MediaQuery.of(context).size.height * 0.72,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFDF6EC),
              borderRadius: BorderRadius.circular(36),
              boxShadow: [
                BoxShadow(
                    color: AppBrown.mid.withOpacity(0.3),
                    blurRadius: 24,
                    offset: const Offset(10, 10)),
                const BoxShadow(
                    color: Colors.white,
                    blurRadius: 24,
                    offset: Offset(-10, -10)),
              ],
            ),
            child: Column(children: [
              const SizedBox(height: 14),
              Center(
                  child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppBrown.mid.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.white,
                              blurRadius: 2,
                              offset: Offset(-1, -1)),
                          BoxShadow(
                              color: Color(0xFFD9C6B2),
                              blurRadius: 2,
                              offset: Offset(1, 1))
                        ],
                      ))),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [AppBrown.darkest, AppBrown.dark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: AppBrown.darkest.withOpacity(0.3),
                              blurRadius: 0,
                              offset: const Offset(0, 4)),
                          BoxShadow(
                              color: AppBrown.darkest.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 6)),
                        ],
                      ),
                      child: const Icon(Icons.notifications_rounded,
                          color: Colors.white, size: 22)),
                  const SizedBox(width: 14),
                  const Text('Notifications',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppBrown.darkest,
                          letterSpacing: -0.4)),
                  const Spacer(),
                  if (unreadCount > 0) ...[
                    TextButton(
                      onPressed: () {
                        if (user != null) {
                          markAllNotificationsReadInFirestore(
                              user.id, UserRole.contractor);
                        }
                      },
                      child: const Text('Mark all read',
                          style: TextStyle(
                              color: AppBrown.dark,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDF6EC),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0xFFD9C6B2),
                              blurRadius: 0,
                              offset: Offset(0, 3)),
                          BoxShadow(
                              color: Color(0xFFD9C6B2),
                              blurRadius: 6,
                              offset: Offset(3, 3)),
                          BoxShadow(
                              color: Colors.white,
                              blurRadius: 6,
                              offset: Offset(-3, -3)),
                        ],
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Text('$unreadCount new',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFEF4444))),
                      ]),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 16),
              // Gradient divider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                      Colors.transparent,
                      AppBrown.mid.withOpacity(0.3),
                      Colors.transparent
                    ]))),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: notifs.isEmpty
                    ? const Center(
                        child: Text('No notifications yet',
                            style: TextStyle(color: AppBrown.dark)))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: notifs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final n = notifs[i];
                          return GestureDetector(
                            onTap: () {
                              Navigator.pop(context); // close sheet first
                              // models[i] is the full NotificationModel that
                              // notifs[i] (_CNotif) was derived from — pass
                              // it straight through so no related-id field
                              // the notification was created with gets
                              // dropped before routing.
                              handleNotificationTap(homeContext, ref, models[i],
                                  UserRole.contractor);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDF6EC),
                                borderRadius: BorderRadius.circular(18),
                                border: n.isNew
                                    ? Border.all(
                                        color: AppBrown.mid.withOpacity(0.4),
                                        width: 1.2)
                                    : null,
                                boxShadow: n.isNew
                                    ? [
                                        BoxShadow(
                                            color:
                                                AppBrown.mid.withOpacity(0.22),
                                            blurRadius: 0,
                                            offset: const Offset(0, 4)),
                                        BoxShadow(
                                            color:
                                                AppBrown.mid.withOpacity(0.14),
                                            blurRadius: 10,
                                            offset: const Offset(4, 4)),
                                        const BoxShadow(
                                            color: Colors.white,
                                            blurRadius: 10,
                                            offset: Offset(-4, -4)),
                                      ]
                                    : [
                                        BoxShadow(
                                            color:
                                                AppBrown.mid.withOpacity(0.12),
                                            blurRadius: 0,
                                            offset: const Offset(0, 3)),
                                        BoxShadow(
                                            color:
                                                AppBrown.mid.withOpacity(0.08),
                                            blurRadius: 8,
                                            offset: const Offset(3, 3)),
                                        const BoxShadow(
                                            color: Colors.white,
                                            blurRadius: 8,
                                            offset: Offset(-3, -3)),
                                      ],
                              ),
                              child: Row(children: [
                                // Icon circle
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFDF6EC),
                                    borderRadius: BorderRadius.circular(15),
                                    boxShadow: [
                                      BoxShadow(
                                          color: AppBrown.mid.withOpacity(0.28),
                                          blurRadius: 5,
                                          offset: const Offset(3, 3)),
                                      const BoxShadow(
                                          color: Colors.white,
                                          blurRadius: 5,
                                          offset: Offset(-3, -3)),
                                    ],
                                  ),
                                  child: Icon(n.icon,
                                      color: n.iconColor, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Row(children: [
                                        Expanded(
                                            child: Text(n.title,
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w800,
                                                    color: AppBrown.darkest))),
                                        if (n.isNew)
                                          Container(
                                            width: 8,
                                            height: 8,
                                            margin:
                                                const EdgeInsets.only(left: 6),
                                            decoration: const BoxDecoration(
                                                color: Color(0xFFEF4444),
                                                shape: BoxShape.circle),
                                          ),
                                      ]),
                                      const SizedBox(height: 4),
                                      Text(n.subtitle,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: AppBrown.dark
                                                  .withOpacity(0.75))),
                                      const SizedBox(height: 5),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFDF6EC),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          boxShadow: [
                                            BoxShadow(
                                                color: AppBrown.mid
                                                    .withOpacity(0.2),
                                                blurRadius: 3,
                                                offset: const Offset(1, 1)),
                                            const BoxShadow(
                                                color: Colors.white,
                                                blurRadius: 3,
                                                offset: Offset(-1, -1)),
                                          ],
                                        ),
                                        child: Text(n.time,
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: AppBrown.dark
                                                    .withOpacity(0.65),
                                                fontWeight: FontWeight.w600)),
                                      ),
                                    ])),
                                const SizedBox(width: 8),
                                // Arrow
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFDF6EC),
                                    borderRadius: BorderRadius.circular(9),
                                    boxShadow: [
                                      BoxShadow(
                                          color: AppBrown.mid.withOpacity(0.2),
                                          blurRadius: 0,
                                          offset: const Offset(0, 3)),
                                      BoxShadow(
                                          color: AppBrown.mid.withOpacity(0.12),
                                          blurRadius: 5,
                                          offset: const Offset(2, 2)),
                                      const BoxShadow(
                                          color: Colors.white,
                                          blurRadius: 5,
                                          offset: Offset(-2, -2)),
                                    ],
                                  ),
                                  child: Icon(Icons.chevron_right_rounded,
                                      size: 16,
                                      color: AppBrown.dark.withOpacity(0.5)),
                                ),
                              ]),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 20),
            ]),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final user = ref.watch(liveCurrentUserProvider).valueOrNull ??
        ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.background;
    final surf = isDark ? AppColors.darkSurface : AppColors.surface;
    final txtPri = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final txtSec =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    // Real Firestore worker count (contractor_workers), not the DummyData-
    // seeded workersProvider — see _AssignWorkerSheet below, which already
    // reads the same live stream. A loading/error state here must never
    // block the rest of Home (orders), so it only ever falls back to the
    // latest known list or an empty one.
    final workersAsync = ref.watch(contractorWorkersStreamProvider);
    if (workersAsync.hasError) {
      debugPrint(
          'WORKERS_LOAD_ERROR [ContractorHomeScreen]: ${workersAsync.error}');
    }
    final workers = workersAsync.valueOrNull ?? const <WorkerModel>[];
    final ordersAsync = ref.watch(contractorFirestoreOrdersProvider);
    if (ordersAsync.isLoading && !ordersAsync.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (ordersAsync.hasError && !ordersAsync.hasValue) {
      debugPrint(
          'ORDERS_LOAD_ERROR [ContractorHomeScreen]: ${ordersAsync.error}');
      debugPrint(
          'ORDERS_LOAD_STACK [ContractorHomeScreen]: ${ordersAsync.stackTrace}');
      return const Scaffold(body: Center(child: Text('Error loading orders')));
    }
    final orders = ordersAsync.valueOrNull ?? [];

    final pending =
        orders.where((o) => o.status == OrderStatus.pending).toList();
    final inProgress =
        orders.where((o) => o.status == OrderStatus.inProgress).toList();
    final completed =
        orders.where((o) => o.status == OrderStatus.completed).toList();
    final cancelled =
        orders.where((o) => o.status == OrderStatus.cancelled).toList();

    final unreadNotifications = user == null
        ? 0
        : ref.watch(unreadNotificationsCountProvider(
            (userId: user.id, role: UserRole.contractor)));

    List<OrderModel> filtered = orders;
    if (_filter == 'pending') filtered = pending;
    if (_filter == 'inProgress') filtered = inProgress;
    if (_filter == 'completed') filtered = completed;
    if (_filter == 'cancelled') filtered = cancelled;
    if (_query.isNotEmpty) {
      filtered = filtered
          .where((o) =>
              o.title.toLowerCase().contains(_query.toLowerCase()) ||
              o.customerName.toLowerCase().contains(_query.toLowerCase()) ||
              o.area.toLowerCase().contains(_query.toLowerCase()) ||
              (o.selectedServiceName
                      ?.toLowerCase()
                      .contains(_query.toLowerCase()) ??
                  false) ||
              (o.serviceType?.toLowerCase().contains(_query.toLowerCase()) ??
                  false))
          .toList();
    }

    final today = DateTime.now();
    // Show pending + inProgress always (active orders), regardless of date
    final todayOrders = orders
        .where((o) =>
            o.status == OrderStatus.pending ||
            o.status == OrderStatus.inProgress)
        .toList();

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppBrown.darkest,
                      AppBrown.dark,
                      Color(0xFFDC7D4E)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: [0.0, 0.5, 1.0],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: Color(0x607A3E1E),
                        blurRadius: 24,
                        offset: Offset(0, 10))
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header row ─────────────────────────────────────────
                      Row(children: [
                        // Circular avatar
                        GestureDetector(
                          onTap: () =>
                              ref.read(navIndexProvider.notifier).state = 3,
                          child: Stack(children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: (user?.avatar?.isNotEmpty ?? false)
                                    ? null
                                    : LinearGradient(
                                        colors: [
                                          _cColor,
                                          _cColor.withOpacity(0.6)
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.5),
                                    width: 2),
                                boxShadow: [
                                  BoxShadow(
                                      color: AppBrown.darkest.withOpacity(0.30),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4))
                                ],
                              ),
                              child: ProfileAvatarImage(
                                imageUrl: user?.avatar,
                                size: 48,
                                fallbackText: user?.fullName.isNotEmpty == true
                                    ? user!.fullName
                                    : 'C',
                                fallbackTextStyle: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900),
                              ),
                            ),
                            Positioned(
                                bottom: 1,
                                right: 1,
                                child: Container(
                                    width: 13,
                                    height: 13,
                                    decoration: BoxDecoration(
                                        color: const Color(0xFF00D97E),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: AppBrown.darkest,
                                            width: 2)))),
                          ]),
                        ), // end GestureDetector
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(
                                  '${l.get('hello')}, ${user?.fullName.split(' ').first ?? ''} 👋',
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: -0.5)),
                              const SizedBox(height: 4),
                              Row(children: [
                                Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color:
                                                Colors.white.withOpacity(0.2))),
                                    child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.verified_rounded,
                                              color: Colors.white, size: 12),
                                          const SizedBox(width: 4),
                                          Text(l.get('contractor'),
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white)),
                                        ])),
                                const SizedBox(width: 8),
                                GestureDetector(
                                    onTap: () => ref
                                        .read(navIndexProvider.notifier)
                                        .state = 2,
                                    child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.12),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: Colors.white
                                                    .withOpacity(0.2))),
                                        child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.group_rounded,
                                                  size: 12,
                                                  color: Colors.white70),
                                              const SizedBox(width: 4),
                                              Text(
                                                  '${workers.length} ${l.get("worker_count")}',
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Colors.white70)),
                                            ]))),
                              ]),
                            ])),
                        // Professional-style 3-dots header menu
                        _ContrHeaderDotsMenu(
                          pendingCount: unreadNotifications,
                          completedOrders: completed,
                          cancelledOrders: cancelled,
                          onNotifications: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const ContractorNotificationsScreen())),
                          onOpenAiPlanner: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const ContractorAiPlannerScreen())),
                          onHelp: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const HelpCenterScreen(
                                        userRole: UserRole.contractor,
                                        accentColor: AppBrown.dark,
                                        gradientStart: AppBrown.darkest,
                                        gradientEnd: AppBrown.dark,
                                      ))),
                          onLogout: () {
                            ref.read(authProvider.notifier).logout();
                            Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const LoginScreen()),
                                (r) => false);
                          },
                        ),
                      ]),
                      const SizedBox(height: 18),

                      // ── Contractor Search Bar ──────────────────────────────
                      _ContrCurvedSearchBar(
                        controller: _searchCtrl,
                        query: _query,
                        isDark: isDark,
                        hintText: l.get('search_customer_service'),
                        onChanged: (v) => setState(() => _query = v),
                        onClear: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      ),
                    ]),
              ),
            ),

            // ── Standalone Contractor AI entry card — same UX concept as
            // the Professional Home AI card: outside the header, above the
            // filter bar. Opens the exact same ContractorAiPlannerScreen
            // already reachable from the header's three-dot menu.
            const SliverToBoxAdapter(child: SizedBox(height: 18)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _ContrAiAssistantHomeEntry(
                  title: l.get('contractor_ai_planner_menu_label'),
                  subtitle: 'Plan your crew and next order with AI',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ContractorAiPlannerScreen())),
                ),
              ),
            ),
            // ── Filter/segment bar — lives in the normal page content,
            // outside the top header gradient panel (matches the
            // Professional Home layout; Contractor tokens/colors kept).
            const SliverToBoxAdapter(child: SizedBox(height: 18)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _ContrStepperBar(
                  allCount: orders.length,
                  pendingCount: pending.length,
                  inProgressCount: inProgress.length,
                  selected: _filter,
                  onSelect: (v) => setState(() => _filter = v),
                ),
              ),
            ),

            // ── Daily Schedule Section ─────────────────────────────
            const SliverToBoxAdapter(child: SizedBox(height: 22)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                          color: AppBrown.dark,
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 8),
                  Text(l.get('today_schedule'),
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppBrown.darkest)),
                  const Spacer(),
                  if (todayOrders.length > 2)
                    _ContrNeoScheduleMoreButton(
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => _ContrAllSchedulesScreen(
                                  orders: todayOrders, isDark: isDark))),
                    ),
                ]),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            if (todayOrders.isEmpty)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding:
                      const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppBrown.darkest.withOpacity(0.3)
                        : AppBrown.warm,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: isDark
                            ? AppBrown.dark.withOpacity(0.3)
                            : AppBrown.mid.withOpacity(0.25)),
                  ),
                  child: Row(children: [
                    Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                            color: AppBrown.light,
                            borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.event_available_rounded,
                            color: AppBrown.dark, size: 22)),
                    const SizedBox(width: 14),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.get('no_tasks_today'),
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white70
                                      : AppBrown.darkest)),
                          const SizedBox(height: 3),
                          Text(l.get('enjoy_quiet_day'),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white38
                                      : AppBrown.dark.withOpacity(0.7))),
                        ]),
                  ]),
                ),
              )
            else
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _ContrScheduleTimeline(
                    orders: todayOrders.take(2).toList(),
                    onTap: (o) => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) =>
                          _ScheduleDetailSheet(order: o, l: l, isDark: isDark),
                    ),
                    onCustomerTap: (o) =>
                        _showCustomerDetailsSheet(context, ref, o),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverToBoxAdapter(
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _SecTitle(
                        title: '${l.get('orders_count')} (${filtered.length})',
                        color: isDark ? Colors.white : AppBrown.darkest))),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),

            filtered.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                            child: Column(children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 52, color: txtSec),
                          const SizedBox(height: 10),
                          Text(l.get('no_orders'),
                              style: TextStyle(
                                  color: txtSec,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                        ]))))
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _ContrOrderCard3D(
                            orderId: filtered[i].id, isDark: isDark),
                        childCount: filtered.length,
                      ),
                    ),
                  ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

// ── Contractor Search Bar ───────────────────────────────────────────────────
// A single coherent rounded pill: a small primary-gradient search icon,
// the text field, and an optional clear button — Contractor-themed
// counterpart of the refined Professional/Customer search treatment.
// Same TextEditingController/onChanged/onClear contract as before; visuals
// only.
class _ContrCurvedSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final String query;
  final bool isDark;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _ContrCurvedSearchBar({
    required this.controller,
    required this.query,
    required this.isDark,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<_ContrCurvedSearchBar> createState() => _ContrCurvedSearchBarState();
}

class _ContrCurvedSearchBarState extends State<_ContrCurvedSearchBar> {
  bool _focused = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    final fieldBg = isDark ? AppBrown.darkest.withOpacity(0.85) : Colors.white;
    final borderC = _focused
        ? _cColor
        : (isDark ? _cColor.withOpacity(0.35) : _cColor.withOpacity(0.18));
    final textC = isDark ? Colors.white : AppColors.textPrimary;
    final hintC =
        isDark ? Colors.white.withOpacity(0.40) : AppColors.textSecondary;

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: borderC, width: 1.3),
        boxShadow: [
          BoxShadow(
            color: AppBrown.darkest.withOpacity(isDark ? 0.35 : 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 6),
          Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.all(7),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient:
                  LinearGradient(colors: [AppBrown.dark, AppBrown.darkest]),
            ),
            child:
                const Icon(Icons.search_rounded, color: Colors.white, size: 18),
          ),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              onChanged: widget.onChanged,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textC,
              ),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: TextStyle(
                  color: hintC,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 2),
              ),
            ),
          ),
          if (widget.query.isNotEmpty)
            GestureDetector(
              onTap: widget.onClear,
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.12)
                      : AppBrown.darkest.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close_rounded,
                    color: isDark
                        ? Colors.white.withOpacity(0.65)
                        : AppBrown.darkest.withOpacity(0.55),
                    size: 14),
              ),
            )
          else
            const SizedBox(width: 14),
        ],
      ),
    );
  }
}

// ── Contractor AI Home Entry Card ───────────────────────────────────────────
// Standalone AI feature card shown between the header and the filter bar —
// same layout/quality reference as the approved Professional Home AI card
// (_ProfAiAssistantHomeEntry), using Contractor orange/gold tokens. Navigates to
// the exact same ContractorAiPlannerScreen already reachable from the
// header's three-dot menu; introduces no new screen, provider, or
// controller.
class _ContrAiAssistantHomeEntry extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ContrAiAssistantHomeEntry({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppBrown.mid.withOpacity(0.25),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppBrown.darkest.withOpacity(0.10),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient:
                    LinearGradient(colors: [AppBrown.dark, AppBrown.darkest]),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppBrown.darkest,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppBrown.dark.withOpacity(0.75),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppBrown.warm,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_rounded,
                  color: AppBrown.darkest, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Customer Details Sheet (for schedule cards) ──────────────────────────────
void _showCustomerDetailsSheet(
    BuildContext context, WidgetRef ref, OrderModel order) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final allOrders =
      ref.read(contractorFirestoreOrdersProvider).valueOrNull ?? [];
  final customerOrders =
      allOrders.where((o) => o.customerId == order.customerId).toList();
  final totalOrders = customerOrders.length;
  final contactVisible = order.status == OrderStatus.inProgress ||
      order.status == OrderStatus.completed;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      decoration: BoxDecoration(
          color: isDark ? const Color(0xFF7A3E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppBrown.light,
                    borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        // Avatar
        Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                    colors: [AppBrown.darkest, AppBrown.dark]),
                border: Border.all(
                    color: AppBrown.mid.withOpacity(0.3), width: 2.5)),
            child: Consumer(builder: (context, ref, _) {
              final customerUser = order.customerId.isNotEmpty
                  ? ref.watch(userByIdProvider(order.customerId)).valueOrNull
                  : null;
              return ProfileAvatarImage(
                imageUrl: customerUser?.avatar,
                size: 72,
                fallbackText:
                    order.customerName.isNotEmpty ? order.customerName : 'C',
                fallbackTextStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900),
              );
            })),
        const SizedBox(height: 12),
        Text(order.customerName.isNotEmpty ? order.customerName : 'Customer',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppBrown.darkest)),
        const SizedBox(height: 4),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: AppBrown.dark.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('Customer',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppBrown.dark,
                      fontWeight: FontWeight.w700))),
          const SizedBox(width: 8),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: const Color(0xFFE9A76B).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.receipt_long_rounded,
                    size: 12, color: Color(0xFFDC7D4E)),
                const SizedBox(width: 4),
                Text('$totalOrders orders',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFDC7D4E),
                        fontWeight: FontWeight.w700)),
              ])),
        ]),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? AppBrown.dark.withOpacity(0.15) : AppBrown.warm,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppBrown.mid.withOpacity(0.15)),
          ),
          child: Column(children: [
            _CustomerInfoTile(
                icon: Icons.location_on_outlined,
                label: 'Location',
                value: order.area,
                isDark: isDark),
            Divider(
                height: 1,
                color: isDark ? Colors.white10 : Colors.grey.shade100),
            _CustomerInfoTile(
                icon: Icons.email_outlined,
                label: 'Email',
                value: contactVisible ? 'customer@example.com' : '••••••••••',
                isDark: isDark,
                locked: !contactVisible),
            Divider(
                height: 1,
                color: isDark ? Colors.white10 : Colors.grey.shade100),
            _CustomerInfoTile(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: contactVisible ? '+972 50 000 0000' : '••••••••••',
                isDark: isDark,
                locked: !contactVisible),
            Divider(
                height: 1,
                color: isDark ? Colors.white10 : Colors.grey.shade100),
            _CustomerInfoTile(
                icon: Icons.receipt_long_rounded,
                label: 'Total Orders',
                value: '$totalOrders order${totalOrders != 1 ? 's' : ''}',
                isDark: isDark),
          ]),
        ),
        if (!contactVisible) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppBrown.warm,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppBrown.mid.withOpacity(0.2)),
            ),
            child: Row(children: [
              Icon(Icons.lock_outline_rounded, size: 15, color: AppBrown.dark),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                      'Contact details available after accepting the order.',
                      style: TextStyle(fontSize: 12, color: AppBrown.dark))),
            ]),
          ),
        ],
      ]),
    ),
  );
}

class _CustomerInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final bool locked;
  const _CustomerInfoTile(
      {required this.icon,
      required this.label,
      required this.value,
      required this.isDark,
      this.locked = false});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: AppBrown.light.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: AppBrown.dark)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.grey.shade500)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : const Color(0xFF7A3E1E))),
        ])),
        if (locked)
          Icon(Icons.lock_outline_rounded,
              size: 16, color: isDark ? Colors.white38 : Colors.grey.shade400),
      ]),
    );
  }
}

// ─── Order Card ───────────────────────────────────────────────────────────────
class _ContractorOrderCard2 extends StatelessWidget {
  final OrderModel order;
  final WidgetRef ref;
  final bool isDark;
  const _ContractorOrderCard2(
      {required this.order, required this.ref, required this.isDark});

  Color get _statusColor {
    switch (order.status) {
      case OrderStatus.pending:
        return AppColors.warning;
      case OrderStatus.inProgress:
        return AppBrown.mid;
      case OrderStatus.completed:
        return AppColors.accent;
      case OrderStatus.cancelled:
        return AppColors.error;
    }
  }

  void _goToDetail(BuildContext context) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ContractorOrderDetailScreen(order: order)));
  }

  void _openChat(BuildContext context) {
    final customer = UserModel(
        id: order.customerId,
        fullName:
            order.customerName.isNotEmpty ? order.customerName : 'Customer',
        email: '',
        phone: '',
        city: order.area,
        role: UserRole.customer);
    ref.read(conversationsProvider.notifier).startConversation(customer);
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ContractorChatScreen(otherUser: customer)));
  }

  void _showCustomerPopup(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allOrders =
        ref.read(contractorFirestoreOrdersProvider).valueOrNull ?? [];
    final customerOrders =
        allOrders.where((o) => o.customerId == order.customerId).toList();
    final totalOrders = customerOrders.length;
    final contactVisible = order.status == OrderStatus.inProgress ||
        order.status == OrderStatus.completed;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
            color: isDark ? const Color(0xFF7A3E1E) : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28))),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppBrown.light,
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          // Avatar
          Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                      colors: [AppBrown.darkest, AppBrown.dark]),
                  border: Border.all(
                      color: AppBrown.mid.withOpacity(0.4), width: 2.5)),
              child: Center(
                  child: Text(
                      order.customerName.isNotEmpty
                          ? order.customerName[0].toUpperCase()
                          : 'C',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900)))),
          const SizedBox(height: 12),
          Text(order.customerName.isNotEmpty ? order.customerName : 'Customer',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppBrown.darkest)),
          const SizedBox(height: 6),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: AppBrown.dark.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20)),
                child: const Text('Customer',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppBrown.dark,
                        fontWeight: FontWeight.w700))),
            const SizedBox(width: 8),
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: AppBrown.light.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.receipt_long_rounded,
                      size: 12, color: AppBrown.darkest),
                  const SizedBox(width: 4),
                  Text('$totalOrders orders',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppBrown.darkest,
                          fontWeight: FontWeight.w700)),
                ])),
          ]),
          const SizedBox(height: 20),
          // Info card
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color:
                  isDark ? AppBrown.darkest.withOpacity(0.25) : AppBrown.warm,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppBrown.mid.withOpacity(0.25)),
            ),
            child: Column(children: [
              _ContrCustomerInfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Location',
                  value: order.area,
                  isDark: isDark),
              Divider(height: 1, color: AppBrown.mid.withOpacity(0.15)),
              _ContrCustomerInfoRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: contactVisible ? 'customer@example.com' : '••••••••••',
                  isDark: isDark,
                  locked: !contactVisible),
              Divider(height: 1, color: AppBrown.mid.withOpacity(0.15)),
              _ContrCustomerInfoRow(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: contactVisible ? '+972 50 000 0000' : '••••••••••',
                  isDark: isDark,
                  locked: !contactVisible),
              Divider(height: 1, color: AppBrown.mid.withOpacity(0.15)),
              _ContrCustomerInfoRow(
                  icon: Icons.receipt_long_rounded,
                  label: 'Total Orders',
                  value: '$totalOrders order${totalOrders == 1 ? '' : 's'}',
                  isDark: isDark),
            ]),
          ),
          if (!contactVisible) ...[
            const SizedBox(height: 12),
            Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppBrown.dark.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12)),
                child: const Row(children: [
                  Icon(Icons.lock_outline_rounded,
                      size: 14, color: AppBrown.dark),
                  SizedBox(width: 8),
                  Expanded(
                      child: Text(
                          'Contact details available after accepting the order.',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppBrown.dark,
                              height: 1.4))),
                ])),
          ],
        ]),
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    final ctrl = TextEditingController();
    final l = AppLocalizations.of(context);
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text(l.get('cancel_reason'),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(l.get('enter_cancel_reason'),
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                TextField(
                    controller: ctrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                        hintText: 'Cancellation reason...',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)))),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l.get('back'))),
                ElevatedButton(
                    onPressed: () {
                      if (order.status != OrderStatus.pending) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Only pending orders can be rejected.'),
                                behavior: SnackBarBehavior.fixed));
                        return;
                      }
                      final reason = ctrl.text.trim();
                      Navigator.pop(context);
                      ref
                          .read(ordersProvider.notifier)
                          .rejectContractorOrderInFirestore(
                            orderId: order.id,
                            reason: reason.isEmpty ? null : reason,
                          )
                          .then((_) {
                        createOrderNotification(
                          userId: order.customerId,
                          title: 'Order Rejected',
                          message: 'Your order was rejected.',
                          orderId: order.id,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Order rejected successfully'),
                                  backgroundColor: AppColors.error,
                                  behavior: SnackBarBehavior.fixed));
                        }
                      }).catchError((_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Failed to reject order. Please try again.'),
                                  behavior: SnackBarBehavior.fixed));
                        }
                      });
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error),
                    child: Text(l.get('confirm_cancel'))),
              ],
            ));
  }

  void _showAssignWorkerDialog(BuildContext context) {
    if (order.status == OrderStatus.completed ||
        order.status == OrderStatus.cancelled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Cannot assign worker to completed or cancelled orders.'),
          behavior: SnackBarBehavior.fixed));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) =>
          _AssignWorkerSheet(order: order, ref: ref, parentContext: context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final surf = isDark ? AppColors.darkSurface : AppColors.surface;
    final brd = isDark ? AppColors.darkBorder : AppColors.border;
    final txtPri = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final txtSec =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final assignedWorkerName = order.assignedWorkerName;
    final assignedWorkerSpecialty = order.assignedWorkerSpecialty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
          color: isDark ? const Color(0xFF7A3E1E) : AppBrown.warm,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? AppBrown.dark.withOpacity(0.3)
                : AppBrown.mid.withOpacity(0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
                color: AppBrown.darkest.withOpacity(0.08),
                blurRadius: 14,
                offset: const Offset(0, 5))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Status bar
        Container(
            height: 4,
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [_statusColor, _statusColor.withOpacity(0.5)]),
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20)))),
        Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Customer row ────────────────────────────────────────
            GestureDetector(
              onTap: () => _showCustomerPopup(context),
              child: Row(children: [
                Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                            colors: [AppBrown.darkest, AppBrown.dark]),
                        border: Border.all(
                            color: AppBrown.mid.withOpacity(0.4), width: 1.5)),
                    child: Center(
                        child: Text(
                            order.customerName.isNotEmpty
                                ? order.customerName[0].toUpperCase()
                                : 'C',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900)))),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                        order.customerName.isNotEmpty
                            ? order.customerName
                            : 'Customer',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: txtSec))),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  GestureDetector(
                    onTap: () => _showCustomerPopup(context),
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppBrown.dark.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_outline_rounded,
                                  size: 10, color: AppBrown.dark),
                              SizedBox(width: 3),
                              Text('View',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: AppBrown.dark,
                                      fontWeight: FontWeight.w700)),
                            ])),
                  ),
                  const SizedBox(width: 6),
                  _OrderMenuButton(
                    order: order,
                    onViewDetail: () => _goToDetail(context),
                    onChat: () => _openChat(context),
                    onCancel: () => _showCancelDialog(context),
                    onAssign: () => _showAssignWorkerDialog(context),
                    isDark: isDark,
                  ),
                ]),
              ]),
            ),
            const SizedBox(height: 10),
            // Title + badges
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: Text(order.title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: txtPri,
                          letterSpacing: -0.3))),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                OrderStatusBadge(status: order.status, l: l),
                if (order.priority == OrderPriority.urgent) ...[
                  const SizedBox(height: 4),
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.priority_high_rounded,
                            size: 11, color: AppColors.error),
                        const SizedBox(width: 3),
                        Text(AppLocalizations.of(context).get('urgent'),
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.error)),
                      ])),
                ],
              ]),
            ]),
            const SizedBox(height: 6),

            Text(order.description,
                style: TextStyle(fontSize: 13, color: txtSec, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),

            // Info chips
            Wrap(spacing: 12, runSpacing: 4, children: [
              if (order.customerName.isNotEmpty)
                _IChip(
                    icon: Icons.person_outline,
                    label: order.customerName,
                    color: txtSec),
              _IChip(
                  icon: Icons.location_on_outlined,
                  label: order.area,
                  color: txtSec),
              if (order.selectedServiceName != null)
                _IChip(
                    icon: Icons.build_outlined,
                    label: order.selectedServiceName!,
                    color: AppBrown.dark)
              else if (order.serviceType != null)
                _IChip(
                    icon: Icons.build_outlined,
                    label: order.serviceType!,
                    color: AppBrown.dark),
              if (order.selectedServicePrice != null)
                _IChip(
                    icon: Icons.payments_outlined,
                    label: '₪${order.selectedServicePrice!.toStringAsFixed(0)}',
                    color: AppColors.accent),
              _IChip(
                  icon: Icons.calendar_today_outlined,
                  label:
                      '${order.serviceDate.day}/${order.serviceDate.month}/${order.serviceDate.year}',
                  color: txtSec),
              _IChip(
                  icon: Icons.access_time_outlined,
                  label:
                      '${order.serviceDate.hour}:${order.serviceDate.minute.toString().padLeft(2, '0')}',
                  color: txtSec),
            ]),

            const SizedBox(height: 10),
            _ProgressBar(status: order.status, isDark: isDark),

            // Assigned worker chip
            if (assignedWorkerName != null &&
                assignedWorkerName.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: AppBrown.light.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(6)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.engineering_outlined,
                        size: 14, color: AppBrown.darkest),
                    const SizedBox(width: 6),
                    Text(assignedWorkerName,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppBrown.darkest)),
                    if (assignedWorkerSpecialty != null &&
                        assignedWorkerSpecialty.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text('($assignedWorkerSpecialty)',
                          style: const TextStyle(
                              fontSize: 10, color: AppBrown.dark)),
                    ],
                  ])),
            ],

            if (order.status == OrderStatus.completed) ...[
              const SizedBox(height: 10),
              Divider(color: brd, height: 1),
              const SizedBox(height: 8),
              Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                      onPressed: () => _goToDetail(context),
                      icon: const Icon(Icons.visibility_outlined,
                          size: 15, color: _cColor),
                      label: Text(l.get('view_details'),
                          style: const TextStyle(
                              fontSize: 12,
                              color: _cColor,
                              fontWeight: FontWeight.w600)))),
            ],

            if (order.status == OrderStatus.cancelled &&
                order.rejectReason != null) ...[
              const SizedBox(height: 10),
              Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: AppColors.error.withOpacity(0.2))),
                  child: Row(children: [
                    const Icon(Icons.info_outline,
                        size: 14, color: AppColors.error),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(
                            '${AppLocalizations.of(context).get("cancel_reason")}: ${order.rejectReason}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.error,
                                height: 1.4))),
                  ])),
            ],
          ]),
        ),
      ]),
    );
  }
}

// ── Customer Info Row (customer popup) ───────────────────────────────────────
class _ContrCustomerInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final bool locked;
  const _ContrCustomerInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: AppBrown.dark.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon,
                  color:
                      locked ? AppBrown.dark.withOpacity(0.45) : AppBrown.dark,
                  size: 18)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppBrown.mid : AppBrown.dark,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: locked ? FontWeight.w400 : FontWeight.w700,
                        color: locked
                            ? (isDark ? AppBrown.mid : AppBrown.dark)
                            : (isDark ? Colors.white : AppBrown.darkest),
                        letterSpacing: locked ? 2 : 0)),
              ])),
          if (locked)
            Icon(Icons.lock_outline_rounded,
                size: 14, color: AppBrown.dark.withOpacity(0.5)),
        ]),
      );
}

// ── Worker assignment matching helpers (service-specialty filtering) ──────────
// Normalized (trim + lowercase) category id/nameKey values an order requires:
// for a multi-service order, resolves each selectedServices item's
// categoryId against categoriesProvider and keeps both the id and nameKey;
// for a legacy order with no usable selectedServices categories, falls back
// to order.categoryId/categoryNameKey. Never guesses from service name/desc.
Set<String> _orderRequiredCategoryKeys(
    OrderModel order, List<CategoryModel> categories) {
  final rawCategoryIds = order.selectedServices
      .map((s) => s.categoryId?.trim())
      .where((id) => id != null && id.isNotEmpty)
      .cast<String>()
      .toSet();
  final keys = <String>{};
  if (rawCategoryIds.isNotEmpty) {
    for (final rawId in rawCategoryIds) {
      final norm = rawId.toLowerCase();
      keys.add(norm);
      for (final c in categories) {
        if (c.id.trim().toLowerCase() == norm) {
          keys.add(c.nameKey.trim().toLowerCase());
          break;
        }
      }
    }
  } else {
    final legacyId = order.categoryId?.trim();
    final legacyKey = order.categoryNameKey?.trim();
    if (legacyId != null && legacyId.isNotEmpty)
      keys.add(legacyId.toLowerCase());
    if (legacyKey != null && legacyKey.isNotEmpty) {
      keys.add(legacyKey.toLowerCase());
    }
  }
  return keys;
}

Set<String> _workerSpecialtyKeys(WorkerModel worker) {
  final raw = worker.specialties.isNotEmpty
      ? worker.specialties
      : (worker.specialty.isNotEmpty ? [worker.specialty] : const <String>[]);
  return raw
      .map((s) => s.trim().toLowerCase())
      .where((s) => s.isNotEmpty)
      .toSet();
}

/// A worker is suitable when it matches at least one of the order's
/// required categories — never all of them.
bool _workerMatchesOrderCategories(
    WorkerModel worker, Set<String> requiredKeys) {
  if (requiredKeys.isEmpty) return true;
  final workerKeys = _workerSpecialtyKeys(worker);
  return workerKeys.any(requiredKeys.contains);
}

/// Compact specialty summary for a worker row: one specialty => localized
/// category name; multiple => "First +N more". Resolved from
/// categoriesProvider — never a raw nameKey.
String _workerSpecialtySummary(
    AppLocalizations l, List<CategoryModel> categories, WorkerModel worker) {
  final normalized = _workerSpecialtyKeys(worker);
  final resolved = categories
      .where((c) =>
          normalized.contains(c.id.trim().toLowerCase()) ||
          normalized.contains(c.nameKey.trim().toLowerCase()))
      .toList();
  if (resolved.isEmpty) return '—';
  final first = l.get(resolved.first.nameKey);
  return resolved.length > 1 ? '$first +${resolved.length - 1} more' : first;
}

/// Compact "Omar" / "Omar +1 more" label for an order's assigned worker(s):
/// prefers the new assignedWorkers snapshot list, falling back to the
/// legacy single assignedWorkerName for orders that predate it.
String? _assignedWorkersCompactLabel(OrderModel order) {
  if (order.assignedWorkers.isNotEmpty) {
    final first = order.assignedWorkers.first.name;
    final extra = order.assignedWorkers.length - 1;
    return extra > 0 ? '$first +$extra more' : first;
  }
  final legacyName = order.assignedWorkerName;
  return (legacyName != null && legacyName.isNotEmpty) ? legacyName : null;
}

// ─── Assign Worker Sheet ──────────────────────────────────────────────────────
class _AssignWorkerSheet extends ConsumerStatefulWidget {
  final OrderModel order;
  final WidgetRef ref;
  final BuildContext parentContext;
  const _AssignWorkerSheet(
      {required this.order, required this.ref, required this.parentContext});

  @override
  ConsumerState<_AssignWorkerSheet> createState() => _AssignWorkerSheetState();
}

class _AssignWorkerSheetState extends ConsumerState<_AssignWorkerSheet> {
  // Matches the Firestore rules-enforced cap on assignedWorkers per order
  // (Phase 3B3) — Firestore Security Rules can only validate a fixed number
  // of array indices, so the app must never let a contractor select more
  // than this many workers for a single order.
  static const int _maxAssignedWorkers = 5;

  late Set<String> _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final order = widget.order;
    _selected = order.assignedWorkers.isNotEmpty
        ? {for (final w in order.assignedWorkers) w.id}
        : (order.assignedWorkerId != null && order.assignedWorkerId!.isNotEmpty
            ? {order.assignedWorkerId!}
            : <String>{});
  }

  Future<void> _confirm(List<WorkerModel> allWorkers) async {
    final order = widget.order;
    if (_selected.isEmpty) return;
    if (_saving) return;
    setState(() => _saving = true);

    final workersById = {for (final w in allWorkers) w.id: w};
    final orderedSelectedWorkers = _selected
        .map((id) => workersById[id])
        .whereType<WorkerModel>()
        .toList();
    final snapshots = orderedSelectedWorkers
        .map((w) => AssignedWorkerSnapshot(
              id: w.id,
              name: w.name,
              specialties: w.specialties.isNotEmpty
                  ? w.specialties
                  : (w.specialty.isNotEmpty ? [w.specialty] : const []),
            ))
        .toList();

    final pCtx = widget.parentContext;
    final navigator = Navigator.of(context);
    try {
      await ref
          .read(ordersProvider.notifier)
          .assignWorkersToContractorOrderInFirestore(
            orderId: order.id,
            workers: snapshots,
            currentStatus: order.status,
          );
      if (snapshots.isNotEmpty) {
        createOrderNotification(
          userId: order.customerId,
          title: 'Worker Assigned',
          message: 'A worker was assigned to your order.',
          orderId: order.id,
        );
      }
      navigator.pop();
      if (pCtx.mounted) {
        ScaffoldMessenger.of(pCtx).showSnackBar(SnackBar(
            content: Text(snapshots.isEmpty
                ? 'Assignment cleared'
                : 'Worker assigned successfully'),
            backgroundColor: AppBrown.mid,
            behavior: SnackBarBehavior.fixed));
      }
    } catch (_) {
      setState(() => _saving = false);
      if (pCtx.mounted) {
        ScaffoldMessenger.of(pCtx).showSnackBar(const SnackBar(
            content: Text('Failed to assign worker. Please try again.'),
            behavior: SnackBarBehavior.fixed));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final order = widget.order;
    final workersAsync = ref.watch(contractorWorkersStreamProvider);
    final allWorkers = workersAsync.valueOrNull ?? const <WorkerModel>[];
    final categories =
        ref.watch(categoriesProvider).value ?? const <CategoryModel>[];

    if (workersAsync.isLoading && allWorkers.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF6EFE6),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(40),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (allWorkers.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF6EFE6),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(40),
        child: const Center(
          child: Text('No workers found. Please add workers first.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8A7263), fontSize: 14)),
        ),
      );
    }

    // Already-assigned workers (new snapshot list, or legacy single field)
    // stay visible/selectable regardless of category match or live status —
    // otherwise the contractor could never see or remove them here.
    final alreadyAssignedIds = order.assignedWorkers.isNotEmpty
        ? order.assignedWorkers.map((w) => w.id).toSet()
        : (order.assignedWorkerId != null && order.assignedWorkerId!.isNotEmpty
            ? {order.assignedWorkerId!}
            : const <String>{});

    final requiredKeys = _orderRequiredCategoryKeys(order, categories);
    final hasCategoryInfo = requiredKeys.isNotEmpty;

    final eligibleWorkers = allWorkers.where((w) {
      if (alreadyAssignedIds.contains(w.id)) return true;
      if (hasCategoryInfo && !_workerMatchesOrderCategories(w, requiredKeys)) {
        return false;
      }
      return w.status == WorkerStatus.available;
    }).toList()
      ..sort((a, b) {
        final aSel = _selected.contains(a.id) ? 0 : 1;
        final bSel = _selected.contains(b.id) ? 0 : 1;
        if (aSel != bSel) return aSel.compareTo(bSel);
        return a.name.compareTo(b.name);
      });

    final canConfirm = _selected.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF6EFE6),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
              color: Color(0xFFD9C6B2), blurRadius: 24, offset: Offset(8, 8)),
          BoxShadow(
              color: Colors.white, blurRadius: 24, offset: Offset(-8, -8)),
        ],
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(
            child: Container(
          width: 44,
          height: 5,
          decoration: BoxDecoration(
            color: const Color(0xFFD9C6B2),
            borderRadius: BorderRadius.circular(3),
            boxShadow: const [
              BoxShadow(
                  color: Colors.white, blurRadius: 2, offset: Offset(-1, -1)),
              BoxShadow(
                  color: Color(0xFFD9C6B2),
                  blurRadius: 2,
                  offset: Offset(1, 1)),
            ],
          ),
        )),
        const SizedBox(height: 20),
        Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFF6EFE6),
              boxShadow: [
                BoxShadow(
                    color: Color(0xFFD9C6B2),
                    blurRadius: 8,
                    offset: Offset(4, 4)),
                BoxShadow(
                    color: Colors.white, blurRadius: 8, offset: Offset(-4, -4)),
              ],
            ),
            child: const Icon(Icons.engineering_rounded,
                color: AppBrown.darkest, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.get('choose_worker'),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2B1B12))),
              const SizedBox(height: 4),
              Text(order.title,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF8A7263)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
        if (!hasCategoryInfo) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppBrown.light.withOpacity(0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded,
                  size: 15, color: AppBrown.darkest),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                    'Category information is unavailable for this legacy order.',
                    style: TextStyle(fontSize: 11.5, color: AppBrown.darkest)),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        if (eligibleWorkers.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFFF6EFE6),
              borderRadius: BorderRadius.all(Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                    color: Color(0xFFD9C6B2),
                    blurRadius: 8,
                    offset: Offset(4, 4)),
                BoxShadow(
                    color: Colors.white, blurRadius: 8, offset: Offset(-4, -4)),
              ],
            ),
            child: const Center(
              child: Text(
                  'No suitable workers found for this order\'s specialties.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF8A7263), fontSize: 14)),
            ),
          )
        else
          Container(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4),
            decoration: const BoxDecoration(
              color: Color(0xFFF6EFE6),
              borderRadius: BorderRadius.all(Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                    color: Color(0xFFD9C6B2),
                    blurRadius: 8,
                    offset: Offset(4, 4)),
                BoxShadow(
                    color: Colors.white, blurRadius: 8, offset: Offset(-4, -4)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(12),
                itemCount: eligibleWorkers.length,
                separatorBuilder: (_, __) => _ContrNeoDivider(),
                itemBuilder: (_, i) {
                  final w = eligibleWorkers[i];
                  final isSelected = _selected.contains(w.id);
                  final isAvail = w.status == WorkerStatus.available;
                  return GestureDetector(
                    onTap: () {
                      if (!isSelected &&
                          _selected.length >= _maxAssignedWorkers) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(l.get('max_assigned_workers_reached')),
                          behavior: SnackBarBehavior.fixed,
                        ));
                        return;
                      }
                      setState(() {
                        if (isSelected) {
                          _selected.remove(w.id);
                        } else {
                          _selected.add(w.id);
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppBrown.light.withOpacity(0.5)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: isSelected
                            ? const [
                                BoxShadow(
                                    color: Color(0xFFD9C6B2),
                                    blurRadius: 4,
                                    offset: Offset(2, 2)),
                                BoxShadow(
                                    color: Colors.white,
                                    blurRadius: 4,
                                    offset: Offset(-2, -2)),
                              ]
                            : [],
                      ),
                      child: Row(children: [
                        Stack(children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? const LinearGradient(
                                      colors: [AppBrown.darkest, AppBrown.dark],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight)
                                  : null,
                              color:
                                  isSelected ? null : const Color(0xFFD5C5BB),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                          color:
                                              AppBrown.darkest.withOpacity(0.3),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3))
                                    ]
                                  : const [
                                      BoxShadow(
                                          color: Color(0xFFD9C6B2),
                                          blurRadius: 4,
                                          offset: Offset(2, 2)),
                                      BoxShadow(
                                          color: Colors.white,
                                          blurRadius: 4,
                                          offset: Offset(-2, -2)),
                                    ],
                            ),
                            child: Center(
                                child: Text(
                                    w.name.isNotEmpty
                                        ? w.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18))),
                          ),
                          Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 13,
                                height: 13,
                                decoration: BoxDecoration(
                                  color: isAvail
                                      ? AppColors.accent
                                      : AppColors.warning,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: const Color(0xFFF6EFE6), width: 2),
                                ),
                              )),
                        ]),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(w.name,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected
                                          ? AppBrown.darkest
                                          : const Color(0xFF2B1B12))),
                              const SizedBox(height: 4),
                              Row(children: [
                                Text(_workerSpecialtySummary(l, categories, w),
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: isSelected
                                            ? AppBrown.dark
                                            : const Color(0xFF8A7263))),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (isAvail
                                            ? AppColors.accent
                                            : AppColors.warning)
                                        .withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isAvail
                                        ? l.get('available')
                                        : l.get('busy'),
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: isAvail
                                            ? AppColors.accent
                                            : AppColors.warning),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.star_rounded,
                                    size: 12, color: Color(0xFFF59E0B)),
                                const SizedBox(width: 2),
                                Text(w.rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF2B1B12))),
                              ]),
                            ])),
                        const SizedBox(width: 8),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFF6EFE6),
                            border: isSelected
                                ? null
                                : Border.all(
                                    color: const Color(0xFFD9C6B2), width: 1.5),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0xFFD9C6B2),
                                  blurRadius: 4,
                                  offset: Offset(2, 2)),
                              BoxShadow(
                                  color: Colors.white,
                                  blurRadius: 4,
                                  offset: Offset(-2, -2)),
                            ],
                          ),
                          child: isSelected
                              ? const Icon(Icons.check_rounded,
                                  size: 16, color: AppBrown.darkest)
                              : null,
                        ),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed:
                (_saving || !canConfirm) ? null : () => _confirm(allWorkers),
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(
                _selected.isEmpty
                    ? 'Select at least one worker'
                    : (_selected.length > 1
                        ? 'Confirm ${_selected.length} Workers'
                        : 'Confirm Worker'),
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppBrown.darkest,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppBrown.darkest.withOpacity(0.4),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─── Messages Screen ──────────────────────────────────────────────────────────
class ContractorMessagesScreen extends ContractorMessagesListScreen {
  const ContractorMessagesScreen({super.key});
}

// ─── Helper Data Class ────────────────────────────────────────────────────────
class _CNotif {
  final String? id;
  final IconData icon;
  final Color iconColor;
  final Color bg;
  final String title;
  final String subtitle;
  final String time;
  final bool isNew;
  final String notifType; // 'order', 'message', 'rating', 'worker', 'other'
  final String? relatedOrderId;
  final String? relatedCustomerId;
  final String? relatedWorkerId;
  final String? relatedReviewId;
  const _CNotif({
    this.id,
    required this.icon,
    required this.iconColor,
    required this.bg,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.isNew,
    this.notifType = 'other',
    this.relatedOrderId,
    this.relatedCustomerId,
    this.relatedWorkerId,
    this.relatedReviewId,
  });
}

String _cNotifTimeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.day}/${dt.month}/${dt.year}';
}

// Converts a real Firestore NotificationModel (overlaid with this user's
// per-user read/delete state — see UserNotificationView) into the display
// model used by the contractor's notification cards.
_CNotif _cNotifFromModel(UserNotificationView v) {
  final m = v.notification;
  IconData icon;
  Color iconColor;
  Color bg;
  String notifType;
  switch (m.type) {
    case NotificationType.chat:
      icon = Icons.chat_bubble_rounded;
      iconColor = AppBrown.dark;
      bg = AppBrown.light.withOpacity(0.5);
      notifType = 'message';
      break;
    case NotificationType.orderUpdate:
      icon = Icons.assignment_rounded;
      iconColor = const Color(0xFFFFB800);
      bg = const Color(0xFFFFF8E1);
      notifType = 'order';
      break;
    case NotificationType.broadcast:
      icon = Icons.campaign_rounded;
      iconColor = const Color(0xFF7C3AED);
      bg = const Color(0xFFF5F3FF);
      notifType = 'other';
      break;
    case NotificationType.complaint:
      icon = Icons.flag_rounded;
      iconColor = const Color(0xFFDC2626);
      bg = const Color(0xFFFEE2E2);
      notifType = 'other';
      break;
    case NotificationType.review:
      icon = Icons.star_rounded;
      iconColor = const Color(0xFFFFB800);
      bg = const Color(0xFFFFF8E1);
      notifType = 'rating';
      break;
    case NotificationType.system:
    case NotificationType.general:
    case NotificationType.categoryRequest:
      icon = Icons.info_rounded;
      iconColor = AppBrown.dark;
      bg = AppBrown.light.withOpacity(0.5);
      notifType = 'other';
      break;
  }
  return _CNotif(
    id: m.id,
    icon: icon,
    iconColor: iconColor,
    bg: bg,
    title: m.title,
    subtitle: m.message,
    time: _cNotifTimeAgo(m.createdAt),
    isNew: !v.isRead,
    notifType: notifType,
    relatedOrderId: m.relatedOrderId,
    relatedReviewId: m.relatedReviewId,
  );
}

// ─── Canonical Contractor Notifications Screen ────────────────────────────────
// Single, full-screen notifications destination for the Contractor role,
// reached from BOTH Contractor Home (bell/menu action) and Contractor
// Profile (Quick Actions "Notifications"). Backed by the same real,
// reactive `userNotificationsProvider` the Home bottom sheet already used
// (personal + role/broadcast content merged with this user's own
// read/delete state — see app_providers.dart) — never the old
// Profile-only hardcoded static notification list it replaces.
class ContractorNotificationsScreen extends ConsumerWidget {
  const ContractorNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final models = user == null
        ? const <UserNotificationView>[]
        : ref
                .watch(userNotificationsProvider(
                    (userId: user.id, role: UserRole.contractor)))
                .valueOrNull ??
            const <UserNotificationView>[];
    final notifs = models.map(_cNotifFromModel).toList();
    final unreadCount = models.where((m) => !m.isRead).length;

    return Scaffold(
      backgroundColor: AppBrown.warm,
      appBar: AppBar(
        backgroundColor: AppBrown.darkest,
        elevation: 0,
        centerTitle: false,
        leading: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: const Text('Notifications',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontSize: 17)),
        actions: [
          if (unreadCount > 0) ...[
            TextButton(
              onPressed: () {
                if (user != null) {
                  markAllNotificationsReadInFirestore(
                      user.id, UserRole.contractor);
                }
              },
              child: const Text('Mark all read',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ),
            Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12)),
              child: Text('$unreadCount new',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ),
          ],
        ],
      ),
      body: notifs.isEmpty
          ? const Center(
              child: Text('No notifications yet',
                  style: TextStyle(color: AppBrown.dark)))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              itemCount: notifs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final n = notifs[i];
                return GestureDetector(
                  onTap: () => handleNotificationTap(
                      context, ref, models[i], UserRole.contractor),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: n.isNew ? const Color(0xFFFDF6EC) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: n.isNew
                              ? AppBrown.mid.withOpacity(0.45)
                              : AppBrown.mid.withOpacity(0.2),
                          width: 1.2),
                      boxShadow: [
                        BoxShadow(
                            color: AppBrown.darkest.withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Row(children: [
                      Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                              color: n.bg,
                              borderRadius: BorderRadius.circular(14)),
                          child: Icon(n.icon, color: n.iconColor, size: 22)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Row(children: [
                              Expanded(
                                  child: Text(n.title,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: n.isNew
                                              ? AppBrown.darkest
                                              : AppBrown.dark))),
                              if (n.isNew)
                                Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(left: 6),
                                    decoration: const BoxDecoration(
                                        color: Color(0xFFEF4444),
                                        shape: BoxShape.circle)),
                            ]),
                            const SizedBox(height: 4),
                            Text(n.subtitle,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppBrown.dark.withOpacity(0.75))),
                            const SizedBox(height: 4),
                            Text(n.time,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppBrown.dark.withOpacity(0.55),
                                    fontWeight: FontWeight.w500)),
                          ])),
                      const SizedBox(width: 6),
                      Icon(Icons.chevron_right_rounded,
                          color: AppBrown.mid.withOpacity(0.6), size: 18),
                    ]),
                  ),
                );
              },
            ),
    );
  }
}

// ─── Stat Tile ────────────────────────────────────────────────────────────────
class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _StatTile({
    required this.value,
    required this.label,
    required this.color,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: selected
                ? color.withOpacity(0.75)
                : Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : Colors.white.withOpacity(0.15),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                color: selected ? Colors.white : Colors.white70, size: 18),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : Colors.white70),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ]),
        ),
      ),
    );
  }
}

// ─── Filter Chip ──────────────────────────────────────────────────────────────
class _FChip extends StatelessWidget {
  final String label;
  final String val;
  final String sel;
  final void Function(String) onTap;
  final bool isDark;
  final Color? color;
  const _FChip({
    required this.label,
    required this.val,
    required this.sel,
    required this.onTap,
    required this.isDark,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = sel == val;
    final activeColor = color ?? AppColors.contractor;
    return GestureDetector(
      onTap: () => onTap(val),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withOpacity(0.85)
              : Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : Colors.white.withOpacity(0.2),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : Colors.white70,
            )),
      ),
    );
  }
}

// ─── Section Title ────────────────────────────────────────────────────────────
class _SecTitle extends StatelessWidget {
  final String title;
  final Color color;
  const _SecTitle({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: -0.3));
  }
}

// ─── Info Chip ────────────────────────────────────────────────────────────────
class _IChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _IChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    ]);
  }
}

// ─── Progress Bar ─────────────────────────────────────────────────────────────
class _ProgressBar extends StatelessWidget {
  final OrderStatus status;
  final bool isDark;
  const _ProgressBar({required this.status, required this.isDark});

  double get _progress {
    switch (status) {
      case OrderStatus.pending:
        return 0.25;
      case OrderStatus.inProgress:
        return 0.65;
      case OrderStatus.completed:
        return 1.0;
      case OrderStatus.cancelled:
        return 0.0;
    }
  }

  Color get _color {
    switch (status) {
      case OrderStatus.pending:
        return AppColors.warning;
      case OrderStatus.inProgress:
        return AppBrown.mid;
      case OrderStatus.completed:
        return AppColors.accent;
      case OrderStatus.cancelled:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(AppLocalizations.of(context).get('progress'),
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary)),
        Text('${(_progress * 100).toInt()}%',
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: _color)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: _progress,
          backgroundColor:
              isDark ? AppBrown.darkest.withOpacity(0.3) : AppBrown.light,
          valueColor: AlwaysStoppedAnimation<Color>(_color),
          minHeight: 6,
        ),
      ),
    ]);
  }
}

// ─── Schedule Detail Sheet ───────────────────────────────────────────────────
// ── Contractor Schedule List Card ─────────────────────────────────────────────
class _ContrScheduleListCard extends StatelessWidget {
  final OrderModel order;
  final bool isDark;
  final VoidCallback? onTap;
  final VoidCallback? onCustomerTap;
  const _ContrScheduleListCard(
      {required this.order,
      required this.isDark,
      this.onTap,
      this.onCustomerTap});

  Color get _statusColor {
    switch (order.status) {
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

  String get _statusLabel {
    switch (order.status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.inProgress:
        return 'In Progress';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor;
    final statusLabel = _statusLabel;
    final d = order.serviceDate;
    final timeStr =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? AppBrown.darkest.withOpacity(0.3) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border(left: BorderSide(color: statusColor, width: 4)),
          boxShadow: [
            BoxShadow(
                color: AppBrown.darkest.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            // Customer avatar (tappable)
            GestureDetector(
              onTap: onCustomerTap,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppBrown.darkest, AppBrown.dark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                  border: onCustomerTap != null
                      ? Border.all(
                          color: AppBrown.mid.withOpacity(0.6), width: 2)
                      : null,
                ),
                child: Consumer(builder: (context, ref, _) {
                  final customerUser = order.customerId.isNotEmpty
                      ? ref
                          .watch(userByIdProvider(order.customerId))
                          .valueOrNull
                      : null;
                  return ProfileAvatarImage(
                    imageUrl: customerUser?.avatar,
                    size: 44,
                    borderRadius: 12,
                    fallbackText: order.customerName.isNotEmpty
                        ? order.customerName
                        : 'C',
                    fallbackTextStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800),
                  );
                }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(order.title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppBrown.darkest),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.location_on_outlined,
                        size: 13,
                        color: isDark ? Colors.white54 : AppBrown.dark),
                    const SizedBox(width: 3),
                    Expanded(
                        child: Text(order.area,
                            style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white54 : AppBrown.dark),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 3),
                  Row(children: [
                    Icon(Icons.access_time_rounded,
                        size: 13,
                        color: isDark ? Colors.white54 : AppBrown.dark),
                    const SizedBox(width: 3),
                    Text(timeStr,
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : AppBrown.dark)),
                  ]),
                ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(statusLabel,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: statusColor)),
              ),
              const SizedBox(height: 6),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: isDark ? Colors.white38 : AppBrown.mid),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── Contractor All Schedules Screen ───────────────────────────────────────────
class _ContrAllSchedulesScreen extends StatelessWidget {
  final List<OrderModel> orders;
  final bool isDark;
  const _ContrAllSchedulesScreen({required this.orders, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F1),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            backgroundColor: AppBrown.darkest,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.35),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 16, color: ContractorColors.onBrand),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  // Contractor brand gradient. Foregrounds are onBrand ink,
                  // never white — the #FFDD8D end is far too light for it.
                  gradient: ContractorColors.brandGradient,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text('All Schedules',
                              style: TextStyle(
                                  color: ContractorColors.onBrand,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5)),
                          const SizedBox(height: 3),
                          Text('${orders.length} active orders',
                              style: const TextStyle(
                                  color: ContractorColors.onBrandMuted,
                                  fontSize: 13)),
                        ]),
                  ),
                ),
              ),
            ),
          ),
          if (orders.isEmpty)
            const SliverFillRemaining(
              child: Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 60, color: AppBrown.light),
                    SizedBox(height: 12),
                    Text('No scheduled orders',
                        style: TextStyle(color: AppBrown.mid, fontSize: 15)),
                  ])),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              sliver: SliverToBoxAdapter(
                child: _ContrScheduleTimeline(
                  orders: orders,
                  onTap: (o) => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) =>
                        _ScheduleDetailSheet(order: o, l: l, isDark: isDark),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScheduleDetailSheet extends StatelessWidget {
  final OrderModel order;
  final AppLocalizations l;
  final bool isDark;
  const _ScheduleDetailSheet(
      {required this.order, required this.l, required this.isDark});

  void _openGoogleCalendar(BuildContext context) {
    Navigator.pop(context);
    addOrderToGoogleCalendar(context, order);
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _contrScheduleAccentColor(order.status);
    final statusLabel = _contrScheduleStatusLabel(order.status);
    final d = order.serviceDate;
    String pad(int n) => n.toString().padLeft(2, '0');
    final timeStr = '${pad(d.hour)}:${pad(d.minute)}';
    final dateStr = '${d.day}/${d.month}/${d.year}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 60, 12, 0),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF6EFE6),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
                color: Color(0xFFD9C6B2), blurRadius: 24, offset: Offset(8, 8)),
            BoxShadow(
                color: Colors.white, blurRadius: 24, offset: Offset(-8, -8)),
          ],
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD9C6B2),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.white,
                        blurRadius: 2,
                        offset: Offset(-1, -1)),
                    BoxShadow(
                        color: Color(0xFFD9C6B2),
                        blurRadius: 2,
                        offset: Offset(1, 1)),
                  ],
                ),
              )),
              const SizedBox(height: 20),
              Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFF6EFE6),
                    boxShadow: [
                      BoxShadow(
                          color: Color(0xFFD9C6B2),
                          blurRadius: 8,
                          offset: Offset(4, 4)),
                      BoxShadow(
                          color: Colors.white,
                          blurRadius: 8,
                          offset: Offset(-4, -4)),
                    ],
                  ),
                  child: const Icon(Icons.calendar_month_rounded,
                      color: AppBrown.darkest, size: 22),
                ),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Schedule Details',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2B1B12))),
                  const SizedBox(height: 5),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: statusColor.withOpacity(0.18),
                            blurRadius: 6,
                            offset: const Offset(0, 3))
                      ],
                    ),
                    child: Text(statusLabel,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: statusColor)),
                  ),
                ]),
              ]),
              const SizedBox(height: 18),
              // Info banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: Color(0xFFF6EFE6),
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                  boxShadow: [
                    BoxShadow(
                        color: Color(0xFFD9C6B2),
                        blurRadius: 6,
                        offset: Offset(3, 3)),
                    BoxShadow(
                        color: Colors.white,
                        blurRadius: 6,
                        offset: Offset(-3, -3)),
                  ],
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.title,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2B1B12))),
                      const SizedBox(height: 4),
                      Text(order.description,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8A7263),
                              height: 1.5)),
                    ]),
              ),
              const SizedBox(height: 16),
              // Detail rows neomorphism
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFF6EFE6),
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                        color: Color(0xFFD9C6B2),
                        blurRadius: 8,
                        offset: Offset(4, 4)),
                    BoxShadow(
                        color: Colors.white,
                        blurRadius: 8,
                        offset: Offset(-4, -4)),
                  ],
                ),
                child: Column(children: [
                  _ContrNeoDetailRow(
                      icon: Icons.access_time_rounded,
                      label: 'Time',
                      value: timeStr),
                  _ContrNeoDivider(),
                  _ContrNeoDetailRow(
                      icon: Icons.calendar_today_rounded,
                      label: 'Date',
                      value: dateStr),
                  _ContrNeoDivider(),
                  _ContrNeoDetailRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Customer',
                      value: order.customerName.isEmpty
                          ? 'Customer'
                          : order.customerName),
                  _ContrNeoDivider(),
                  _ContrNeoDetailRow(
                      icon: Icons.location_on_outlined,
                      label: 'Area',
                      value: order.area),
                  if (order.selectedServiceName != null) ...[
                    _ContrNeoDivider(),
                    _ContrNeoDetailRow(
                        icon: Icons.build_outlined,
                        label: 'Service',
                        value: order.selectedServiceName!),
                  ],
                  if (order.selectedServicePrice != null) ...[
                    _ContrNeoDivider(),
                    _ContrNeoDetailRow(
                        icon: Icons.payments_outlined,
                        label: 'Budget',
                        value:
                            '₪${order.selectedServicePrice!.toStringAsFixed(0)}'),
                  ],
                ]),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                    child: _ContrNeoOutlineButton(
                  label: 'Full Details',
                  icon: Icons.open_in_new_rounded,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                ContractorOrderDetailScreen(order: order)));
                  },
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: _ContrNeoFilledButton(
                  label: 'Add to Calendar',
                  icon: Icons.calendar_month_rounded,
                  onTap: () => _openGoogleCalendar(context),
                )),
              ]),
              const SizedBox(height: 32),
            ]),
      ),
    );
  }
}

// ─── Schedule Info Row ────────────────────────────────────────────────────────
// ─── Neo Detail Row (neomorphism) ─────────────────────────────────────────────
class _ContrNeoDetailRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _ContrNeoDetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFF6EFE6),
              boxShadow: [
                BoxShadow(
                    color: Color(0xFFD9C6B2),
                    blurRadius: 5,
                    offset: Offset(2, 2)),
                BoxShadow(
                    color: Colors.white, blurRadius: 5, offset: Offset(-2, -2)),
              ],
            ),
            child: Icon(icon, size: 16, color: AppBrown.darkest),
          ),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF8A7263))),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2B1B12))),
        ]),
      );
}

class _ContrNeoDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: [Color(0xFFE4D3C0), Colors.white, Color(0xFFE4D3C0)]),
        ),
      );
}

// ─── Neo Outline Button ────────────────────────────────────────────────────────
class _ContrNeoOutlineButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _ContrNeoOutlineButton(
      {required this.label, required this.icon, required this.onTap});
  @override
  State<_ContrNeoOutlineButton> createState() => _ContrNeoOutlineButtonState();
}

class _ContrNeoOutlineButtonState extends State<_ContrNeoOutlineButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _pressed = false;
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
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          setState(() => _pressed = true);
          _ctrl.forward();
        },
        onTapUp: (_) {
          setState(() => _pressed = false);
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () {
          setState(() => _pressed = false);
          _ctrl.reverse();
        },
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.04 * _ctrl.value, child: child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFF6EFE6),
              borderRadius: BorderRadius.circular(25),
              border:
                  Border.all(color: AppBrown.mid.withOpacity(0.4), width: 1.2),
              boxShadow: _pressed
                  ? const [
                      BoxShadow(
                          color: Color(0xFFD9C6B2),
                          blurRadius: 3,
                          offset: Offset(1, 1)),
                      BoxShadow(
                          color: Colors.white,
                          blurRadius: 2,
                          offset: Offset(-1, -1))
                    ]
                  : const [
                      BoxShadow(
                          color: Color(0xFFD9C6B2),
                          blurRadius: 0,
                          offset: Offset(0, 4)),
                      BoxShadow(
                          color: Color(0xFFD9C6B2),
                          blurRadius: 8,
                          offset: Offset(3, 3)),
                      BoxShadow(
                          color: Colors.white,
                          blurRadius: 8,
                          offset: Offset(-3, -3))
                    ],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(widget.icon, size: 15, color: AppBrown.darkest),
              const SizedBox(width: 6),
              Text(widget.label,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppBrown.darkest)),
            ]),
          ),
        ),
      );
}

// ─── Neo Filled Button ─────────────────────────────────────────────────────────
class _ContrNeoFilledButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _ContrNeoFilledButton(
      {required this.label, required this.icon, required this.onTap});
  @override
  State<_ContrNeoFilledButton> createState() => _ContrNeoFilledButtonState();
}

class _ContrNeoFilledButtonState extends State<_ContrNeoFilledButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _pressed = false;
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
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          HapticFeedback.mediumImpact();
          setState(() => _pressed = true);
          _ctrl.forward();
        },
        onTapUp: (_) {
          setState(() => _pressed = false);
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () {
          setState(() => _pressed = false);
          _ctrl.reverse();
        },
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.03 * _ctrl.value, child: child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: const LinearGradient(
                colors: [AppBrown.darkest, AppBrown.dark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: _pressed
                  ? [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.40),
                          blurRadius: 4,
                          offset: const Offset(2, 2))
                    ]
                  : [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.40),
                          blurRadius: 0,
                          offset: const Offset(0, 5)),
                      BoxShadow(
                          color: Colors.black.withOpacity(0.20),
                          blurRadius: 10,
                          offset: const Offset(0, 8)),
                      BoxShadow(
                          color: Colors.white.withOpacity(0.08),
                          blurRadius: 4,
                          offset: const Offset(0, -2)),
                    ],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(widget.icon, size: 15, color: Colors.white),
              const SizedBox(width: 6),
              Text(widget.label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2)),
            ]),
          ),
        ),
      );
}

// ─── Neo Schedule More Button ──────────────────────────────────────────────────
class _ContrNeoScheduleMoreButton extends StatefulWidget {
  final VoidCallback onTap;
  const _ContrNeoScheduleMoreButton({required this.onTap});
  @override
  State<_ContrNeoScheduleMoreButton> createState() =>
      _ContrNeoScheduleMoreButtonState();
}

class _ContrNeoScheduleMoreButtonState
    extends State<_ContrNeoScheduleMoreButton>
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
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) =>
            Transform.scale(scale: 1.0 - 0.07 * _ctrl.value, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFFF6EFE6),
            borderRadius: BorderRadius.all(Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                  color: Color(0xFFD9C6B2),
                  blurRadius: 0,
                  offset: Offset(0, 4)),
              BoxShadow(
                  color: Color(0xFFD9C6B2),
                  blurRadius: 8,
                  offset: Offset(4, 4)),
              BoxShadow(
                  color: Colors.white, blurRadius: 8, offset: Offset(-4, -4)),
            ],
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Text('More',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppBrown.darkest)),
            SizedBox(width: 4),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 10, color: AppBrown.darkest),
          ]),
        ),
      ),
    );
  }
}

// ─── Status Colors for Schedule Timeline ──────────────────────────────────────
// Derived strictly from order.status (never from list index/position), so
// the same order always renders with the same semantic color:
// Pending = orange/amber, In Progress = light blue, Completed = green,
// Cancelled = soft red.
Color _contrScheduleAccentColor(OrderStatus s) {
  switch (s) {
    case OrderStatus.pending:
      return const Color(0xFFF59E0B);
    case OrderStatus.inProgress:
      // Semantic status color — deliberately stays light blue through the
      // orange/gold rebrand so In Progress keeps reading as In Progress.
      return const Color(0xFF38BDF8);
    case OrderStatus.completed:
      return const Color(0xFF22C55E);
    case OrderStatus.cancelled:
      return const Color(0xFFEF4444);
  }
}

Color _contrScheduleBgColor(OrderStatus s) {
  switch (s) {
    case OrderStatus.pending:
      return const Color(0xFFFFF3E0);
    case OrderStatus.inProgress:
      return const Color(0xFFE3F2FD);
    case OrderStatus.completed:
      return const Color(0xFFE8F5E9);
    case OrderStatus.cancelled:
      return const Color(0xFFFFEBEE);
  }
}

String _contrScheduleStatusLabel(OrderStatus s) {
  switch (s) {
    case OrderStatus.pending:
      return 'Pending';
    case OrderStatus.inProgress:
      return 'In Progress';
    case OrderStatus.completed:
      return 'Completed';
    case OrderStatus.cancelled:
      return 'Cancelled';
  }
}

// ─── Dotted Line Painter ───────────────────────────────────────────────────────
class _ContrDottedLinePainter extends CustomPainter {
  final Color color;
  const _ContrDottedLinePainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const dashH = 4.0, dashSpace = 4.0;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(Offset(size.width / 2, y),
          Offset(size.width / 2, (y + dashH).clamp(0, size.height)), paint);
      y += dashH + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_ContrDottedLinePainter old) => old.color != color;
}

// ─── Contractor Schedule Timeline Widget ──────────────────────────────────────
class _ContrScheduleTimeline extends StatelessWidget {
  final List<OrderModel> orders;
  final void Function(OrderModel) onTap;
  final void Function(OrderModel)? onCustomerTap;
  const _ContrScheduleTimeline(
      {required this.orders, required this.onTap, this.onCustomerTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left timeline column
        SizedBox(
          width: 72,
          child: Column(
            children: List.generate(orders.length, (i) {
              final color = _contrScheduleAccentColor(orders[i].status);
              final statusLabel = _contrScheduleStatusLabel(orders[i].status);
              final isLast = i == orders.length - 1;
              return Column(children: [
                GestureDetector(
                  onTap: () => onTap(orders[i]),
                  child: Container(
                    width: 64,
                    padding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                            color: color.withOpacity(0.45),
                            blurRadius: 10,
                            offset: const Offset(0, 5)),
                        BoxShadow(
                            color: Colors.white.withOpacity(0.30),
                            blurRadius: 4,
                            offset: const Offset(0, -2)),
                      ],
                    ),
                    child: Center(
                        child: Text(statusLabel,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2),
                            textAlign: TextAlign.center)),
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 52,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: CustomPaint(
                        painter: _ContrDottedLinePainter(
                            color: color.withOpacity(0.45))),
                  ),
              ]);
            }),
          ),
        ),
        const SizedBox(width: 10),
        // Right cards column
        Expanded(
          child: Column(
            children: List.generate(orders.length, (i) {
              final order = orders[i];
              final color = _contrScheduleAccentColor(order.status);
              final bg = _contrScheduleBgColor(order.status);
              final d = order.serviceDate;
              final timeStr =
                  '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
              return GestureDetector(
                onTap: () => onTap(order),
                child: Container(
                  margin:
                      EdgeInsets.only(bottom: i < orders.length - 1 ? 12 : 0),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                          color: color.withOpacity(0.18),
                          blurRadius: 12,
                          offset: const Offset(0, 5)),
                      const BoxShadow(
                          color: Colors.white,
                          blurRadius: 6,
                          offset: Offset(-2, -2)),
                    ],
                    border:
                        Border.all(color: color.withOpacity(0.18), width: 1),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.access_time_rounded,
                              size: 13, color: color),
                          const SizedBox(width: 4),
                          Text(timeStr,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: color)),
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(right: 6, top: 1),
                              decoration: BoxDecoration(
                                  color: color, shape: BoxShape.circle)),
                          Expanded(
                              child: Text(order.title,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2B1B12)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis)),
                        ]),
                        const SizedBox(height: 3),
                        Row(children: [
                          Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(right: 6, top: 1),
                              decoration: BoxDecoration(
                                  color: color.withOpacity(0.45),
                                  shape: BoxShape.circle)),
                          Expanded(
                              child: Text(
                            order.customerName.isNotEmpty
                                ? '${order.area} · ${order.customerName.split(' ').first}'
                                : order.area,
                            style: TextStyle(
                                fontSize: 11,
                                color:
                                    const Color(0xFF5A4335).withOpacity(0.75)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )),
                        ]),
                      ]),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

// ─── 3-Dot Order Menu Button ──────────────────────────────────────────────────
class _OrderMenuButton extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onViewDetail;
  final VoidCallback onChat;
  final VoidCallback onCancel;
  final VoidCallback onAssign;
  final bool isDark;
  const _OrderMenuButton({
    required this.order,
    required this.onViewDetail,
    required this.onChat,
    required this.onCancel,
    required this.onAssign,
    required this.isDark,
  });

  void _show(BuildContext context) {
    final canAssign = order.status == OrderStatus.pending ||
        order.status == OrderStatus.inProgress;
    final canCancel = order.status == OrderStatus.pending ||
        order.status == OrderStatus.inProgress;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF7A3E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppBrown.mid.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(children: [
            Container(
                width: 10,
                height: 10,
                decoration:
                    BoxDecoration(color: AppBrown.mid, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(
                child: Text(order.title,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppBrown.darkest),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 14),
          Divider(color: AppBrown.mid.withOpacity(0.15), height: 1),
          const SizedBox(height: 10),
          _MenuAction(
            icon: Icons.open_in_new_rounded,
            label: 'View Full Details',
            color: AppBrown.darkest,
            iconBg: AppBrown.light.withOpacity(0.6),
            isDark: isDark,
            onTap: () {
              Navigator.pop(context);
              onViewDetail();
            },
          ),
          if (canAssign)
            _MenuAction(
              icon: order.status == OrderStatus.pending
                  ? Icons.engineering_rounded
                  : Icons.swap_horiz_rounded,
              label: order.status == OrderStatus.pending
                  ? 'Accept & Assign Worker'
                  : 'Change Worker',
              color: AppBrown.dark,
              iconBg: AppBrown.light.withOpacity(0.5),
              isDark: isDark,
              onTap: () {
                Navigator.pop(context);
                onAssign();
              },
            ),
          _MenuAction(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Message Customer',
            color: const Color(0xFF0B6E4F),
            iconBg: const Color(0xFFD1FAE5),
            isDark: isDark,
            onTap: () {
              Navigator.pop(context);
              onChat();
            },
          ),
          if (canCancel)
            _MenuAction(
              icon: Icons.close_rounded,
              label: 'Cancel Order',
              color: AppColors.error,
              iconBg: AppColors.error.withOpacity(0.10),
              isDark: isDark,
              onTap: () {
                Navigator.pop(context);
                onCancel();
              },
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => _show(context),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
              color: AppBrown.dark.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.more_vert_rounded,
              size: 16, color: AppBrown.darkest),
        ),
      );
}

// ─── Menu Action Row ──────────────────────────────────────────────────────────
class _MenuAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color, iconBg;
  final bool isDark;
  final VoidCallback onTap;
  const _MenuAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.iconBg,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
              color: isDark
                  ? AppBrown.darkest.withOpacity(0.25)
                  : const Color(0xFFFAF6F2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.10))),
          child: Row(children: [
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: iconBg, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18, color: color)),
            const SizedBox(width: 12),
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : color))),
            Icon(Icons.chevron_right_rounded,
                size: 18,
                color: isDark ? Colors.white30 : color.withOpacity(0.45)),
          ]),
        ),
      );
}

// ─── Small Icon Button ────────────────────────────────────────────────────────
class _SmBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SmBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppBrown.light.withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppBrown.mid.withOpacity(0.3)),
        ),
        child: Icon(icon, size: 16, color: AppBrown.darkest),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ── NEW: Contractor Header Dots Menu (professional neomorphic style) ──────────
// ══════════════════════════════════════════════════════════════════════════════

class _ContrHeaderDotsMenu extends StatefulWidget {
  final int pendingCount;
  final List<OrderModel> completedOrders;
  final List<OrderModel> cancelledOrders;
  final VoidCallback onNotifications;
  final VoidCallback onOpenAiPlanner;
  final VoidCallback onHelp;
  final VoidCallback onLogout;
  const _ContrHeaderDotsMenu({
    required this.pendingCount,
    required this.completedOrders,
    required this.cancelledOrders,
    required this.onNotifications,
    required this.onOpenAiPlanner,
    required this.onHelp,
    required this.onLogout,
  });
  @override
  State<_ContrHeaderDotsMenu> createState() => _ContrHeaderDotsMenuState();
}

class _ContrHeaderDotsMenuState extends State<_ContrHeaderDotsMenu>
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
    final items = <_ContrHeaderMenuItemData>[];
    items.add(_ContrHeaderMenuItemData(
      icon: Icons.notifications_rounded,
      label:
          'Notifications${widget.pendingCount > 0 ? " (${widget.pendingCount})" : ""}',
      color: AppBrown.darkest,
      badge: widget.pendingCount,
      onTap: widget.onNotifications,
    ));
    if (widget.completedOrders.isNotEmpty) {
      items.add(_ContrHeaderMenuItemData(
        icon: Icons.check_circle_rounded,
        label: 'Completed (${widget.completedOrders.length})',
        color: const Color(0xFF22C55E),
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _ContrFilteredOrdersScreen(
                title: 'Completed Orders',
                orders: widget.completedOrders,
                accentColor: const Color(0xFF22C55E),
                icon: Icons.check_circle_rounded,
              ),
            )),
      ));
    }
    if (widget.cancelledOrders.isNotEmpty) {
      items.add(_ContrHeaderMenuItemData(
        icon: Icons.cancel_rounded,
        label: 'Cancelled (${widget.cancelledOrders.length})',
        color: const Color(0xFFEF4444),
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _ContrFilteredOrdersScreen(
                title: 'Cancelled Orders',
                orders: widget.cancelledOrders,
                accentColor: const Color(0xFFEF4444),
                icon: Icons.cancel_rounded,
              ),
            )),
      ));
    }
    items.add(_ContrHeaderMenuItemData(
      icon: Icons.auto_awesome_rounded,
      label:
          AppLocalizations.of(context).get('contractor_ai_planner_menu_label'),
      color: AppBrown.mid,
      onTap: widget.onOpenAiPlanner,
    ));
    items.add(_ContrHeaderMenuItemData(
      icon: Icons.help_outline_rounded,
      label: 'Help',
      color: AppBrown.dark,
      onTap: widget.onHelp,
    ));
    items.add(_ContrHeaderMenuItemData(
      icon: Icons.logout_rounded,
      label: 'Logout',
      color: const Color(0xFFEF4444),
      onTap: widget.onLogout,
    ));

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.18),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        final box = context.findRenderObject() as RenderBox?;
        final pos = box?.localToGlobal(Offset.zero) ?? Offset.zero;
        final size = box?.size ?? Size.zero;
        final screenH = MediaQuery.of(ctx).size.height;
        final panelH = items.length * 58.0 + 20;
        double topPos = pos.dy + size.height - 30;
        if (topPos + panelH > screenH - 16) {
          topPos = pos.dy - panelH + 30;
        }
        topPos = topPos.clamp(16.0, screenH - panelH - 16);
        return Stack(children: [
          Positioned.fill(
              child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(color: Colors.transparent))),
          Positioned(
            right: 16,
            top: topPos,
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(0.3, -0.2), end: Offset.zero)
                  .animate(curved),
              child: FadeTransition(
                  opacity: anim, child: _ContrHeaderMenuPanel(items: items)),
            ),
          ),
        ]);
      },
    );
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
        _open(context);
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) =>
            Transform.scale(scale: 1.0 - 0.08 * _ctrl.value, child: child),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
            boxShadow: [
              BoxShadow(
                  color: AppBrown.darkest.withOpacity(0.25),
                  blurRadius: 0,
                  offset: const Offset(0, 3)),
              BoxShadow(
                  color: AppBrown.darkest.withOpacity(0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 5)),
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
                          color: Colors.white.withOpacity(0.85),
                          shape: BoxShape.circle),
                    )),
          ),
        ),
      ),
    );
  }
}

class _ContrHeaderMenuItemData {
  final IconData icon;
  final String label;
  final Color color;
  final int badge;
  final VoidCallback onTap;
  const _ContrHeaderMenuItemData({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badge = 0,
  });
}

class _ContrHeaderMenuPanel extends StatefulWidget {
  final List<_ContrHeaderMenuItemData> items;
  const _ContrHeaderMenuPanel({required this.items});
  @override
  State<_ContrHeaderMenuPanel> createState() => _ContrHeaderMenuPanelState();
}

class _ContrHeaderMenuPanelState extends State<_ContrHeaderMenuPanel>
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

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: const Color(0xFFFDF6EC),
        boxShadow: [
          BoxShadow(
              color: AppBrown.dark.withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(6, 6)),
          const BoxShadow(
              color: Colors.white, blurRadius: 16, offset: Offset(-6, -6)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                child: Stack(clipBehavior: Clip.none, children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFDF6EC),
                      boxShadow: [
                        BoxShadow(
                            color: AppBrown.mid.withOpacity(0.35),
                            blurRadius: 6,
                            offset: const Offset(3, 3)),
                        const BoxShadow(
                            color: Colors.white,
                            blurRadius: 6,
                            offset: Offset(-3, -3)),
                      ],
                    ),
                    child: Icon(item.icon, size: 20, color: item.color),
                  ),
                  if (item.badge > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                            color: Color(0xFFEF4444), shape: BoxShape.circle),
                        child: Text('${item.badge}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                ]),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ── NEW: Contractor Stepper Bar (like _ProfStepperBar) ────────────────────────
// ══════════════════════════════════════════════════════════════════════════════

class _ContrStepperBar extends StatefulWidget {
  final int allCount;
  final int pendingCount;
  final int inProgressCount;
  final String selected;
  final ValueChanged<String> onSelect;
  const _ContrStepperBar({
    required this.allCount,
    required this.pendingCount,
    required this.inProgressCount,
    required this.selected,
    required this.onSelect,
  });
  @override
  State<_ContrStepperBar> createState() => _ContrStepperBarState();
}

class _ContrStepperBarState extends State<_ContrStepperBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideCtrl;

  // Color mapping: All = green, Pending = amber/orange, In Progress =
  // light blue accent (matches the same semantics already approved on
  // Professional Home; kept as Contractor-local constants).
  static const _tabs = [
    _ContrTabData(
        label: 'All',
        icon: Icons.list_alt_rounded,
        value: 'all',
        activeColor: Color(0xFF4CAF50),
        darkColor: Color(0xFF2E7D32)),
    _ContrTabData(
        label: 'Pending',
        icon: Icons.hourglass_top_rounded,
        value: 'pending',
        activeColor: Color(0xFFF59E0B),
        darkColor: Color(0xFFB45309)),
    _ContrTabData(
        label: 'In Progress',
        icon: Icons.autorenew_rounded,
        value: 'inProgress',
        // Semantic status pair — In Progress stays blue, like every other
        // role's In Progress tab.
        activeColor: Color(0xFF38BDF8),
        darkColor: Color(0xFF0284C7)),
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
    final counts = [
      widget.allCount,
      widget.pendingCount,
      widget.inProgressCount
    ];
    return Container(
      height: 56,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF6EFE6),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
              color: Color(0xFFD9C6B2), blurRadius: 0, offset: Offset(0, 5)),
          BoxShadow(
              color: Color(0xFFD9C6B2), blurRadius: 14, offset: Offset(6, 6)),
          BoxShadow(
              color: Colors.white, blurRadius: 14, offset: Offset(-6, -6)),
        ],
      ),
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final tab = _tabs[i];
          final isActive = widget.selected == tab.value;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onSelect(tab.value);
                _slideCtrl.forward(from: 0);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white.withOpacity(0.95)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(23),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                              color: tab.activeColor.withOpacity(0.22),
                              blurRadius: 12,
                              offset: const Offset(0, 4)),
                          BoxShadow(
                              color: tab.darkColor.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(2, 2)),
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
                                      : const Color(0xFF5A4335)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 220),
                            style: TextStyle(
                              fontSize: isActive ? 12 : 11,
                              fontWeight:
                                  isActive ? FontWeight.w800 : FontWeight.w600,
                              color: isActive
                                  ? AppBrown.darkest
                                  : const Color(0xFF333333),
                              letterSpacing: -0.2,
                            ),
                            child: Text(tab.label,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                        if (counts[i] > 0) ...[
                          const SizedBox(width: 5),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 260),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? tab.activeColor
                                  : const Color(0xFFD9C6B2),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                          color:
                                              tab.activeColor.withOpacity(0.4),
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
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isActive
                                      ? Colors.white
                                      : const Color(0xFF6E5645),
                                )),
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
  }
}

class _ContrTabData {
  final String label, value;
  final IconData icon;
  final Color activeColor, darkColor;
  const _ContrTabData(
      {required this.label,
      required this.value,
      required this.icon,
      required this.activeColor,
      required this.darkColor});
}

// ══════════════════════════════════════════════════════════════════════════════
// ── NEW: Contractor Order Card 3D (like _ProfOrderCard3D) ─────────────────────
// ══════════════════════════════════════════════════════════════════════════════

class _ContrOrderCard3D extends ConsumerStatefulWidget {
  final String orderId;
  final bool isDark;
  const _ContrOrderCard3D({required this.orderId, required this.isDark});
  @override
  ConsumerState<_ContrOrderCard3D> createState() => _ContrOrderCard3DState();
}

class _ContrOrderCard3DState extends ConsumerState<_ContrOrderCard3D>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color _accentColor(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
        return const Color(0xFFF59E0B);
      case OrderStatus.inProgress:
        return const Color(0xFF26A69A); // teal/blue-green
      case OrderStatus.completed:
        return const Color(0xFF22C55E);
      case OrderStatus.cancelled:
        return const Color(0xFFEF4444);
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

  IconData _statusIcon(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
        return Icons.hourglass_top_rounded;
      case OrderStatus.inProgress:
        return Icons.autorenew_rounded;
      case OrderStatus.completed:
        return Icons.check_circle_rounded;
      case OrderStatus.cancelled:
        return Icons.cancel_rounded;
    }
  }

  void _openDetail(BuildContext context, OrderModel order) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ContractorOrderDetailScreen(order: order)));
  }

  void _openChat(BuildContext context, OrderModel order) {
    final customer = UserModel(
      id: order.customerId,
      fullName: order.customerName.isNotEmpty ? order.customerName : 'Customer',
      email: '',
      phone: '',
      city: order.area,
      role: UserRole.customer,
    );
    ref.read(conversationsProvider.notifier).startConversation(customer);
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ContractorChatScreen(otherUser: customer)));
  }

  void _showCancelSheet(BuildContext context, OrderModel order) {
    final ctrl = TextEditingController();
    final l = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFDF6EC),
            borderRadius: BorderRadius.circular(36),
            boxShadow: [
              BoxShadow(
                  color: AppBrown.mid.withOpacity(0.3),
                  blurRadius: 24,
                  offset: const Offset(10, 10)),
              const BoxShadow(
                  color: Colors.white,
                  blurRadius: 24,
                  offset: Offset(-10, -10)),
            ],
          ),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),
                Center(
                    child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                            color: AppBrown.mid.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(3)))),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(children: [
                    Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFDF6EC),
                            boxShadow: [
                              BoxShadow(
                                  color: AppBrown.mid.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(4, 4)),
                              const BoxShadow(
                                  color: Colors.white,
                                  blurRadius: 10,
                                  offset: Offset(-4, -4))
                            ]),
                        child: const Icon(Icons.cancel_outlined,
                            color: Color(0xFFEF4444), size: 24)),
                    const SizedBox(width: 16),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(l.get('cancel_reason'),
                              style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  color: AppBrown.darkest,
                                  letterSpacing: -0.3)),
                          const SizedBox(height: 2),
                          Text(order.title,
                              style: const TextStyle(
                                  fontSize: 12, color: AppBrown.dark),
                              overflow: TextOverflow.ellipsis),
                        ])),
                  ]),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: TextField(
                    controller: ctrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Cancellation reason...',
                      filled: true,
                      fillColor: const Color(0xFFFDF6EC),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              BorderSide(color: AppBrown.mid.withOpacity(0.3))),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(children: [
                    Expanded(
                        child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                              color: const Color(0xFFFDF6EC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: AppBrown.mid.withOpacity(0.3))),
                          child: const Center(
                              child: Text('Back',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppBrown.darkest)))),
                    )),
                    const SizedBox(width: 12),
                    Expanded(
                        child: GestureDetector(
                      onTap: () {
                        if (order.status != OrderStatus.pending) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Only pending orders can be rejected.'),
                                  behavior: SnackBarBehavior.fixed));
                          return;
                        }
                        final reason = ctrl.text.trim();
                        Navigator.pop(ctx);
                        ref
                            .read(ordersProvider.notifier)
                            .rejectContractorOrderInFirestore(
                              orderId: order.id,
                              reason: reason.isEmpty ? null : reason,
                            )
                            .then((_) {
                          createOrderNotification(
                            userId: order.customerId,
                            title: 'Order Rejected',
                            message: 'Your order was rejected.',
                            orderId: order.id,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Order rejected successfully'),
                                    backgroundColor: AppColors.error,
                                    behavior: SnackBarBehavior.fixed));
                          }
                        }).catchError((_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Failed to reject order. Please try again.'),
                                    behavior: SnackBarBehavior.fixed));
                          }
                        });
                      },
                      child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [
                                Color(0xFFEF4444),
                                Color(0xFFDC2626)
                              ]),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                    color: const Color(0xFFEF4444)
                                        .withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4))
                              ]),
                          child: const Center(
                              child: Text('Confirm Cancel',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white)))),
                    )),
                  ]),
                ),
                const SizedBox(height: 24),
              ]),
        ),
      ),
    );
  }

  void _showAssignWorkerDialog(BuildContext context, OrderModel order) {
    if (order.status == OrderStatus.completed ||
        order.status == OrderStatus.cancelled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Cannot assign worker to completed or cancelled orders.'),
          behavior: SnackBarBehavior.fixed));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) =>
          _AssignWorkerSheet(order: order, ref: ref, parentContext: context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allOrders =
        ref.watch(contractorFirestoreOrdersProvider).valueOrNull ?? [];
    OrderModel? order = allOrders
        .cast<OrderModel?>()
        .firstWhere((o) => o?.id == widget.orderId, orElse: () => null);
    if (order == null) return const SizedBox.shrink();

    final l = AppLocalizations.of(context);
    final customerUser = order.customerId.isNotEmpty
        ? ref.watch(userByIdProvider(order.customerId)).valueOrNull
        : null;
    final accent = _accentColor(order.status);
    final canAct = order.status == OrderStatus.pending ||
        order.status == OrderStatus.inProgress;
    final isPending = order.status == OrderStatus.pending;
    final isInProg = order.status == OrderStatus.inProgress;
    // Compact "Omar" / "Omar +1 more" label — prefers the new multi-worker
    // assignedWorkers snapshot list, falling back to the legacy single
    // assignedWorkerName field for orders that predate it.
    final assignedWorkerName = _assignedWorkersCompactLabel(order);
    // Localized specialty aside is only shown for a single assigned worker
    // (new single-worker snapshot, or legacy field); omitted for multiple
    // since "+N more" already conveys there's more than one.
    final assignedWorkerSpecialty = order.assignedWorkers.length == 1
        ? (order.assignedWorkers.first.specialties.isNotEmpty
            ? l.get(order.assignedWorkers.first.specialties.first)
            : null)
        : (order.assignedWorkers.isEmpty
            ? order.assignedWorkerSpecialty
            : null);

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
        _ctrl.forward();
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        _ctrl.reverse();
        _openDetail(context, order!);
      },
      onTapCancel: () {
        setState(() => _pressed = false);
        _ctrl.reverse();
      },
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) =>
            Transform.scale(scale: 1.0 - 0.015 * _ctrl.value, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: _pressed
                ? [
                    BoxShadow(
                        color: accent.withOpacity(0.15),
                        blurRadius: 4,
                        offset: const Offset(1, 2))
                  ]
                : [
                    BoxShadow(
                        color: accent.withOpacity(0.22),
                        blurRadius: 0,
                        offset: const Offset(0, 5)),
                    BoxShadow(
                        color: accent.withOpacity(0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 8)),
                    BoxShadow(
                        color: Colors.white.withOpacity(0.90),
                        blurRadius: 4,
                        offset: const Offset(0, -1)),
                  ],
            border: Border.all(color: accent.withOpacity(0.15), width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(children: [
              // Top accent bar
              Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [accent, accent.withOpacity(0.4)]),
                      ))),
              // Content
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row: avatar + title + status badge
                      Row(children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              accent.withOpacity(0.65),
                              accent.withOpacity(0.35)
                            ]),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                  color: accent.withOpacity(0.35),
                                  blurRadius: 0,
                                  offset: const Offset(0, 3)),
                              BoxShadow(
                                  color: accent.withOpacity(0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 5)),
                              const BoxShadow(
                                  color: Colors.white,
                                  blurRadius: 3,
                                  offset: Offset(0, -1)),
                            ],
                            border: Border.all(
                                color: Colors.white.withOpacity(0.6),
                                width: 1.5),
                          ),
                          child: ProfileAvatarImage(
                            imageUrl: customerUser?.avatar,
                            size: 48,
                            borderRadius: 15,
                            fallbackText: order.customerName,
                            fallbackTextStyle: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(order.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppBrown.darkest,
                                      letterSpacing: -0.3)),
                              const SizedBox(height: 3),
                              Text(
                                  order.customerName.isNotEmpty
                                      ? order.customerName
                                      : 'Customer',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: accent.withOpacity(0.8),
                                      fontWeight: FontWeight.w500)),
                            ])),
                        const SizedBox(width: 8),
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: accent.withOpacity(0.3)),
                            boxShadow: [
                              BoxShadow(
                                  color: accent.withOpacity(0.20),
                                  blurRadius: 0,
                                  offset: const Offset(0, 2)),
                              BoxShadow(
                                  color: accent.withOpacity(0.10),
                                  blurRadius: 6,
                                  offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(_statusIcon(order.status),
                                size: 11, color: accent),
                            const SizedBox(width: 4),
                            Text(_statusLabel(order.status, l),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: accent,
                                    fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ]),

                      const SizedBox(height: 12),
                      // Gradient divider
                      Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.transparent,
                              accent.withOpacity(0.25),
                              Colors.transparent
                            ]),
                          )),
                      const SizedBox(height: 10),

                      // Description
                      Text(order.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              color: accent.withOpacity(0.7),
                              height: 1.4)),
                      const SizedBox(height: 10),

                      // Order ID row
                      _ContrOrderIdRow(orderId: order.id, accentColor: accent),
                      const SizedBox(height: 10),

                      // Progress bar
                      _ContrOrderProgressBar(
                          status: order.status, accentColor: accent),
                      const SizedBox(height: 10),

                      // Assigned worker chip
                      if (assignedWorkerName != null &&
                          assignedWorkerName.isNotEmpty) ...[
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                                color: accent.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: accent.withOpacity(0.2))),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.engineering_outlined,
                                  size: 13, color: accent),
                              const SizedBox(width: 5),
                              Text(assignedWorkerName,
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: accent)),
                              if (assignedWorkerSpecialty != null &&
                                  assignedWorkerSpecialty.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Text('($assignedWorkerSpecialty)',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: accent.withOpacity(0.7))),
                              ],
                            ])),
                        const SizedBox(height: 10),
                      ],

                      // Chips row + 3-dots
                      Row(children: [
                        _Contr3DInfoChip(
                            icon: Icons.calendar_today_outlined,
                            label:
                                '${order.serviceDate.day}/${order.serviceDate.month}/${order.serviceDate.year}',
                            color: accent),
                        if (order.area.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _Contr3DInfoChip(
                              icon: Icons.location_on_outlined,
                              label: order.area,
                              color: accent)
                        ],
                        if (order.priority == OrderPriority.urgent) ...[
                          const SizedBox(width: 6),
                          _Contr3DInfoChip(
                              icon: Icons.priority_high_rounded,
                              label: 'Urgent',
                              color: const Color(0xFFEF4444))
                        ],
                        const Spacer(),
                        _ContrOrderCardDotsMenu(
                          order: order,
                          ref: ref,
                          onChat: () => _openChat(context, order!),
                          onAccept: isPending
                              ? () {
                                  if (order!.status != OrderStatus.pending) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Only pending orders can be accepted.'),
                                            behavior: SnackBarBehavior.fixed));
                                    return;
                                  }
                                  ref
                                      .read(ordersProvider.notifier)
                                      .acceptContractorOrderInFirestore(
                                          order!.id)
                                      .then((_) {
                                    createOrderNotification(
                                      userId: order.customerId,
                                      title: 'Order Accepted',
                                      message:
                                          '${order.providerName} accepted your order.',
                                      orderId: order.id,
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'Order accepted successfully'),
                                              backgroundColor: AppBrown.mid,
                                              behavior:
                                                  SnackBarBehavior.fixed));
                                    }
                                  }).catchError((_) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'Failed to accept order. Please try again.'),
                                              behavior:
                                                  SnackBarBehavior.fixed));
                                    }
                                  });
                                }
                              : null,
                          onComplete: isInProg
                              ? () {
                                  if (order!.status != OrderStatus.inProgress) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Only in-progress orders can be completed.'),
                                            behavior: SnackBarBehavior.fixed));
                                    return;
                                  }
                                  ref
                                      .read(ordersProvider.notifier)
                                      .completeContractorOrderInFirestore(
                                          order!.id)
                                      .then((_) {
                                    createOrderNotification(
                                      userId: order.customerId,
                                      title: 'Order Completed',
                                      message:
                                          'Your order was completed successfully.',
                                      orderId: order.id,
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'Order completed successfully'),
                                              backgroundColor: AppBrown.mid,
                                              behavior:
                                                  SnackBarBehavior.fixed));
                                    }
                                  }).catchError((_) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'Failed to complete order. Please try again.'),
                                              behavior:
                                                  SnackBarBehavior.fixed));
                                    }
                                  });
                                }
                              : null,
                          onCancel: canAct
                              ? () => _showCancelSheet(context, order!)
                              : null,
                          onAssign: canAct
                              ? () => _showAssignWorkerDialog(context, order!)
                              : null,
                          accentColor: accent,
                        ),
                      ]),

                      // Cancelled reason
                      if (order.status == OrderStatus.cancelled &&
                          order.rejectReason != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: const Color(0xFFEF4444)
                                      .withOpacity(0.2))),
                          child: Row(children: [
                            const Icon(Icons.info_outline,
                                size: 14, color: Color(0xFFEF4444)),
                            const SizedBox(width: 6),
                            Expanded(
                                child: Text('Cancelled: ${order.rejectReason}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFFEF4444),
                                        height: 1.4))),
                          ]),
                        ),
                      ],
                    ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Contractor Order ID Row ────────────────────────────────────────────────────
class _ContrOrderIdRow extends StatefulWidget {
  final String orderId;
  final Color accentColor;
  const _ContrOrderIdRow({required this.orderId, required this.accentColor});
  @override
  State<_ContrOrderIdRow> createState() => _ContrOrderIdRowState();
}

class _ContrOrderIdRowState extends State<_ContrOrderIdRow> {
  bool _copied = false;
  void _copyId() async {
    await Clipboard.setData(ClipboardData(text: widget.orderId));
    setState(() => _copied = true);
    await Future.delayed(const Duration(milliseconds: 1600));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final short = widget.orderId.length > 8
        ? widget.orderId.substring(0, 8).toUpperCase()
        : widget.orderId.toUpperCase();
    return Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
            color: widget.accentColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: widget.accentColor.withOpacity(0.18))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.tag_rounded,
              size: 10, color: widget.accentColor.withOpacity(0.7)),
          const SizedBox(width: 4),
          Text('ID: $short',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: widget.accentColor)),
        ]),
      ),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: _copyId,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _copied
                ? widget.accentColor.withOpacity(0.15)
                : const Color(0xFFFDF6EC),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                  color: AppBrown.mid.withOpacity(0.25),
                  blurRadius: 3,
                  offset: const Offset(1, 1)),
              const BoxShadow(
                  color: Colors.white, blurRadius: 3, offset: Offset(-1, -1)),
            ],
          ),
          child: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded,
              size: 13,
              color: _copied
                  ? widget.accentColor
                  : AppBrown.dark.withOpacity(0.6)),
        ),
      ),
    ]);
  }
}

// ── Contractor Order Progress Bar ────────────────────────────────────────────
class _ContrOrderProgressBar extends StatelessWidget {
  final OrderStatus status;
  final Color accentColor;
  const _ContrOrderProgressBar(
      {required this.status, required this.accentColor});

  double get _progress {
    switch (status) {
      case OrderStatus.pending:
        return 0.20;
      case OrderStatus.inProgress:
        return 0.55;
      case OrderStatus.completed:
        return 1.0;
      case OrderStatus.cancelled:
        return 0.0;
    }
  }

  String get _label {
    switch (status) {
      case OrderStatus.pending:
        return '20%';
      case OrderStatus.inProgress:
        return '55%';
      case OrderStatus.completed:
        return '100%';
      case OrderStatus.cancelled:
        return '0%';
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Progress',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: accentColor.withOpacity(0.6))),
          Text(_label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: accentColor)),
        ]),
        const SizedBox(height: 5),
        LayoutBuilder(
            builder: (ctx, c) => Container(
                  height: 6,
                  width: c.maxWidth,
                  decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10)),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: _progress),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (ctx, v, _) => Container(
                        width: c.maxWidth * v,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: LinearGradient(
                              colors: status == OrderStatus.cancelled
                                  ? [
                                      accentColor.withOpacity(0.3),
                                      accentColor.withOpacity(0.1)
                                    ]
                                  : [
                                      accentColor,
                                      accentColor.withOpacity(0.6)
                                    ]),
                          boxShadow: status == OrderStatus.cancelled
                              ? []
                              : [
                                  BoxShadow(
                                      color: accentColor.withOpacity(0.4),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2))
                                ],
                        ),
                      ),
                    ),
                  ),
                )),
      ]);
}

// ── Contractor 3D Info Chip ───────────────────────────────────────────────────
class _Contr3DInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Contr3DInfoChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.20), width: 1),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.12),
                blurRadius: 0,
                offset: const Offset(0, 2)),
            BoxShadow(
                color: color.withOpacity(0.06),
                blurRadius: 4,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ]),
      );
}

// ── Contractor Order Card Dots Menu ──────────────────────────────────────────
class _ContrOrderCardDotsMenu extends StatefulWidget {
  final OrderModel order;
  final WidgetRef ref;
  final VoidCallback onChat;
  final VoidCallback? onAccept;
  final VoidCallback? onComplete;
  final VoidCallback? onCancel;
  final VoidCallback? onAssign;
  final Color accentColor;
  const _ContrOrderCardDotsMenu({
    required this.order,
    required this.ref,
    required this.onChat,
    this.onAccept,
    this.onComplete,
    this.onCancel,
    this.onAssign,
    required this.accentColor,
  });
  @override
  State<_ContrOrderCardDotsMenu> createState() =>
      _ContrOrderCardDotsMenuState();
}

class _ContrOrderCardDotsMenuState extends State<_ContrOrderCardDotsMenu>
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

  void _open() {
    HapticFeedback.lightImpact();
    final items = <_ContrCardMenuItemData>[];
    if (widget.onAccept != null)
      items.add(_ContrCardMenuItemData(Icons.check_rounded, 'Accept',
          const Color(0xFF22C55E), widget.onAccept!));
    if (widget.onComplete != null)
      items.add(_ContrCardMenuItemData(Icons.check_circle_outline_rounded,
          'Complete', const Color(0xFF22C55E), widget.onComplete!));
    if (widget.onAssign != null)
      items.add(_ContrCardMenuItemData(
          Icons.engineering_rounded,
          widget.order.status == OrderStatus.inProgress
              ? 'Manage Assigned Workers'
              : 'Assign Worker',
          AppBrown.dark,
          widget.onAssign!));
    items.add(_ContrCardMenuItemData(Icons.chat_bubble_outline_rounded, 'Chat',
        AppBrown.dark, widget.onChat));
    if (widget.onCancel != null)
      items.add(_ContrCardMenuItemData(Icons.close_rounded, 'Cancel',
          const Color(0xFFEF4444), widget.onCancel!));

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.18),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        final box = context.findRenderObject() as RenderBox?;
        final pos = box?.localToGlobal(Offset.zero) ?? Offset.zero;
        final size = box?.size ?? Size.zero;
        final screenH = MediaQuery.of(ctx).size.height;
        final panelH = items.length * 58.0 + 20;
        double topPos = pos.dy + size.height - 30;
        if (topPos + panelH > screenH - 16) topPos = pos.dy - panelH + 30;
        topPos = topPos.clamp(16.0, screenH - panelH - 16);
        return Stack(children: [
          Positioned.fill(
              child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(color: Colors.transparent))),
          Positioned(
            right: 16,
            top: topPos,
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(0.3, -0.2), end: Offset.zero)
                  .animate(curved),
              child: FadeTransition(
                  opacity: anim, child: _ContrCardMenuPanel(items: items)),
            ),
          ),
        ]);
      },
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
              Transform.scale(scale: 1.0 - 0.08 * _ctrl.value, child: child),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFFDF6EC),
              borderRadius: BorderRadius.circular(11),
              boxShadow: [
                BoxShadow(
                    color: AppBrown.mid.withOpacity(0.35),
                    blurRadius: 0,
                    offset: const Offset(0, 3)),
                BoxShadow(
                    color: AppBrown.mid.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(3, 3)),
                const BoxShadow(
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
                            color: widget.accentColor.withOpacity(0.7),
                            shape: BoxShape.circle)))),
          ),
        ),
      );
}

class _ContrCardMenuItemData {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ContrCardMenuItemData(this.icon, this.label, this.color, this.onTap);
}

class _ContrCardMenuPanel extends StatefulWidget {
  final List<_ContrCardMenuItemData> items;
  const _ContrCardMenuPanel({required this.items});
  @override
  State<_ContrCardMenuPanel> createState() => _ContrCardMenuPanelState();
}

class _ContrCardMenuPanelState extends State<_ContrCardMenuPanel>
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

  @override
  Widget build(BuildContext context) => Container(
        width: 64,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          color: const Color(0xFFFDF6EC),
          boxShadow: [
            BoxShadow(
                color: AppBrown.mid.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(6, 6)),
            const BoxShadow(
                color: Colors.white, blurRadius: 16, offset: Offset(-6, -6)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(widget.items.length, (i) {
            final item = widget.items[i];
            final n = widget.items.length;
            final anim = CurvedAnimation(
                parent: _ctrl,
                curve: Interval((i / n).clamp(0, 1), ((i + 1) / n).clamp(0, 1),
                    curve: Curves.easeOutBack));
            return AnimatedBuilder(
              animation: anim,
              builder: (_, child) => Opacity(
                opacity: anim.value.clamp(0, 1),
                child: Transform.scale(
                    scale: 0.6 + 0.4 * anim.value.clamp(0, 1), child: child),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
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
                      color: const Color(0xFFFDF6EC),
                      boxShadow: [
                        BoxShadow(
                            color: AppBrown.mid.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(3, 3)),
                        const BoxShadow(
                            color: Colors.white,
                            blurRadius: 6,
                            offset: Offset(-3, -3)),
                      ],
                    ),
                    child: Icon(item.icon, size: 20, color: item.color),
                  ),
                ),
              ),
            );
          }),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// ── NEW: Contractor Filtered Orders Screen ────────────────────────────────────
// ══════════════════════════════════════════════════════════════════════════════

class _ContrFilteredOrdersScreen extends ConsumerWidget {
  final String title;
  final List<OrderModel> orders;
  final Color accentColor;
  final IconData icon;
  const _ContrFilteredOrdersScreen({
    required this.title,
    required this.orders,
    required this.accentColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF6EC),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            backgroundColor: AppBrown.darkest,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back_ios_rounded,
                    size: 18, color: ContractorColors.onBrand),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  // Contractor brand gradient — onBrand ink, not white.
                  gradient: ContractorColors.brandGradient,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: SafeArea(
                    child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(children: [
                          Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(11),
                                  border: Border.all(
                                      color: accentColor.withOpacity(0.55))),
                              child: Icon(icon,
                                  color: ContractorColors.onBrand, size: 18)),
                          const SizedBox(width: 12),
                          Text(title,
                              style: const TextStyle(
                                  color: ContractorColors.onBrand,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5)),
                        ]),
                        const SizedBox(height: 4),
                        Text('${orders.length} orders',
                            style: const TextStyle(
                                color: ContractorColors.onBrandMuted,
                                fontSize: 13)),
                      ]),
                )),
              ),
            ),
          ),
          if (orders.isEmpty)
            SliverFillRemaining(
              child: Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    Icon(icon, size: 60, color: accentColor.withOpacity(0.4)),
                    const SizedBox(height: 12),
                    Text('No $title',
                        style: TextStyle(
                            color: accentColor.withOpacity(0.7),
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ])),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final isDark =
                        Theme.of(context).brightness == Brightness.dark;
                    return _ContrOrderCard3D(
                        orderId: orders[i].id, isDark: isDark);
                  },
                  childCount: orders.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
