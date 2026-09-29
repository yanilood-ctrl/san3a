import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/helpers/notification_navigation_helper.dart';
import '../../../auth/presentation/providers/app_providers.dart';
import '../theme/customer_design.dart';

// ── Notification model & data ─────────────────────────────────────────────────
// Display model used by NotificationsScreen's presentational widgets. Real
// data comes from Firestore via CustomerNotificationsScreen below.
class AppNotification {
  final String id;
  final String title;
  final String subtitle;
  final String time;
  final IconData icon;
  final bool isRead;
  const AppNotification({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.time,
    this.icon = Icons.notifications_outlined,
    this.isRead = false,
  });
}

String _notifTimeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.day}/${dt.month}/${dt.year}';
}

IconData _iconForType(NotificationType type) {
  switch (type) {
    case NotificationType.orderUpdate:
      return Icons.task_alt_rounded;
    case NotificationType.chat:
      return Icons.chat_bubble_outline_rounded;
    case NotificationType.complaint:
      return Icons.flag_outlined;
    case NotificationType.review:
      return Icons.star_outline_rounded;
    case NotificationType.broadcast:
      return Icons.campaign_outlined;
    case NotificationType.system:
      return Icons.settings_outlined;
    case NotificationType.categoryRequest:
      return Icons.category_outlined;
    case NotificationType.general:
      return Icons.notifications_outlined;
  }
}

// ── Real Firestore-backed Notifications screen (customer) ────────────────────
// Wraps the presentational NotificationsScreen below with live data from the
// `notifications` Firestore collection, and handles tap-to-read + navigation.
class CustomerNotificationsScreen extends ConsumerStatefulWidget {
  const CustomerNotificationsScreen({super.key});

  @override
  ConsumerState<CustomerNotificationsScreen> createState() =>
      _CustomerNotificationsScreenState();
}

class _CustomerNotificationsScreenState
    extends ConsumerState<CustomerNotificationsScreen> {
  bool _markingAll = false;

  void _handleTap(BuildContext context, WidgetRef ref, UserNotificationView n) {
    handleNotificationTap(context, ref, n, UserRole.customer);
  }

  Future<void> _markAllRead(String uid) async {
    if (_markingAll) return;
    debugPrint('NOTIFICATION_MARK_ALL_DEBUG: customer pressed Mark all read uid=$uid');
    setState(() => _markingAll = true);
    try {
      await markAllNotificationsReadInFirestore(uid, UserRole.customer);
    } catch (e) {
      debugPrint('NOTIFICATION_MARK_ALL_ERROR: customer mark-all failed uid=$uid error=$e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Could not mark notifications as read. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    if (user == null) {
      return const NotificationsScreen(notifs: <AppNotification>[]);
    }
    debugPrint('CUSTOMER_NOTIFICATIONS_UID: ${user.id}');
    debugPrint(
        'CUSTOMER_NOTIFICATIONS_ROLE: ${NotificationModel.roleToString(UserRole.customer)}');

    final notificationsAsync = ref.watch(
        userNotificationsProvider((userId: user.id, role: UserRole.customer)));

    // Mirror the professional/contractor pattern: only treat this as a hard
    // failure when no data has ever arrived. A stream error that follows a
    // successful snapshot (e.g. a transient reconnect) must not blank out
    // notifications that already loaded correctly.
    final loading =
        notificationsAsync.isLoading && !notificationsAsync.hasValue;
    final hasError =
        notificationsAsync.hasError && !notificationsAsync.hasValue;
    final models =
        notificationsAsync.valueOrNull ?? const <UserNotificationView>[];

    if (notificationsAsync.hasError) {
      debugPrint('CUSTOMER_NOTIFICATIONS_ERROR: ${notificationsAsync.error}');
    }
    debugPrint('CUSTOMER_NOTIFICATIONS_COUNT: ${models.length}');

    if (loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF0F6FF),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (hasError) {
      return const Scaffold(
        backgroundColor: Color(0xFFF0F6FF),
        body: Center(child: Text('Failed to load notifications')),
      );
    }

    final byId = {for (final m in models) m.id: m};
    final notifs = models
        .map((m) => AppNotification(
              id: m.id,
              title: m.notification.title,
              subtitle: m.notification.message,
              time: _notifTimeAgo(m.notification.createdAt),
              icon: _iconForType(m.notification.type),
              isRead: m.isRead,
            ))
        .toList();
    final unreadCount = models.where((m) => !m.isRead).length;
    return NotificationsScreen(
      notifs: notifs,
      unreadCount: unreadCount,
      onMarkAllRead: (unreadCount > 0 && !_markingAll)
          ? () => _markAllRead(user.id)
          : null,
      onNotifTap: (n) {
        final model = byId[n.id];
        if (model != null) _handleTap(context, ref, model);
      },
    );
  }
}

// ── Notifications Full Screen ─────────────────────────────────────────────────
class NotificationsScreen extends StatefulWidget {
  final List<AppNotification> notifs;
  final void Function(AppNotification)? onNotifTap;
  final int? unreadCount;
  final VoidCallback? onMarkAllRead;

  const NotificationsScreen({
    super.key,
    this.notifs = const <AppNotification>[],
    this.onNotifTap,
    this.unreadCount,
    this.onMarkAllRead,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerCtrl;

  static const List<List<Color>> _gradients = [
    [Color(0xFF7C3AED), Color(0xFF4C1D95)],
    [Color(0xFF0EA5E9), Color(0xFF0369A1)],
    [Color(0xFF10B981), Color(0xFF065F46)],
    [Color(0xFFF59E0B), Color(0xFFB45309)],
    [Color(0xFFEF4444), Color(0xFF991B1B)],
  ];

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F6FF),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: CustomerColors.dark,
            foregroundColor: Colors.white,
            elevation: 0,
            automaticallyImplyLeading: false,
            leading: const _NeoBackBtn(),
            actions: [
              if (widget.onMarkAllRead != null)
                TextButton(
                  onPressed: widget.onMarkAllRead,
                  child: const Text('Mark all read',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ),
              if ((widget.unreadCount ?? widget.notifs.length) > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.35), width: 1.2),
                    ),
                    child: Text(
                        '${widget.unreadCount ?? widget.notifs.length} new',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [CustomerColors.darkest, CustomerColors.dark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.25),
                                    blurRadius: 8,
                                    offset: const Offset(3, 3)),
                                BoxShadow(
                                    color: Colors.white.withOpacity(0.1),
                                    blurRadius: 6,
                                    offset: const Offset(-2, -2)),
                              ],
                            ),
                            child: const Icon(Icons.notifications_rounded,
                                color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Text('Notifications',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5)),
                        ]),
                        const SizedBox(height: 4),
                        Text(
                          widget.notifs.isEmpty
                              ? 'All caught up!'
                              : '${widget.notifs.length} notifications waiting',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.65),
                              fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          if (widget.notifs.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEEEF5),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0xFFBEBECF),
                                blurRadius: 12,
                                offset: Offset(5, 5)),
                            BoxShadow(
                                color: Colors.white,
                                blurRadius: 12,
                                offset: Offset(-5, -5)),
                          ],
                        ),
                        child: const Icon(Icons.notifications_none_rounded,
                            size: 44, color: CustomerColors.mid),
                      ),
                      const SizedBox(height: 20),
                      const Text('No notifications right now',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: CustomerColors.darkest)),
                      const SizedBox(height: 8),
                      const Text("You're all caught up!",
                          style: TextStyle(fontSize: 13, color: CustomerColors.mid)),
                    ]),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final n = widget.notifs[i];
                    final colors = _gradients[i % _gradients.length];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _NeoNotifCard(
                        notif: n,
                        colors: colors,
                        index: i,
                        onTap: () => widget.onNotifTap?.call(n),
                      ),
                    );
                  },
                  childCount: widget.notifs.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// ── Neo Back Button ───────────────────────────────────────────────────────────
class _NeoBackBtn extends StatefulWidget {
  const _NeoBackBtn();
  @override
  State<_NeoBackBtn> createState() => _NeoBackBtnState();
}

class _NeoBackBtnState extends State<_NeoBackBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 110));
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
          _ctrl.forward();
        },
        onTapUp: (_) {
          _ctrl.reverse();
          Navigator.of(context).pop();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, child) =>
                Transform.scale(scale: 1.0 - 0.08 * _ctrl.value, child: child),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                    color: Colors.white.withOpacity(0.35), width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.28),
                      blurRadius: 0,
                      offset: const Offset(0, 3)),
                  BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 8,
                      offset: const Offset(3, 4)),
                  BoxShadow(
                      color: Colors.white.withOpacity(0.12),
                      blurRadius: 6,
                      offset: const Offset(-2, -2)),
                ],
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ),
      );
}

// ── Neo Notification Card ─────────────────────────────────────────────────────
class _NeoNotifCard extends StatefulWidget {
  final AppNotification notif;
  final List<Color> colors;
  final int index;
  final VoidCallback onTap;
  const _NeoNotifCard(
      {required this.notif,
      required this.colors,
      required this.index,
      required this.onTap});
  @override
  State<_NeoNotifCard> createState() => _NeoNotifCardState();
}

class _NeoNotifCardState extends State<_NeoNotifCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _pressed = false;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 110));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c1 = widget.colors[0];
    final c2 = widget.colors[1];
    return GestureDetector(
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
            Transform.scale(scale: 1.0 - 0.03 * _ctrl.value, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEEEEF5),
            borderRadius: BorderRadius.circular(22),
            boxShadow: _pressed
                ? const [
                    BoxShadow(
                        color: Color(0xFFBEBECF),
                        blurRadius: 4,
                        offset: Offset(2, 2)),
                    BoxShadow(
                        color: Colors.white,
                        blurRadius: 4,
                        offset: Offset(-1, -1)),
                  ]
                : const [
                    BoxShadow(
                        color: Color(0xFFBEBECF),
                        blurRadius: 0,
                        offset: Offset(0, 4)),
                    BoxShadow(
                        color: Color(0xFFBEBECF),
                        blurRadius: 12,
                        offset: Offset(5, 5)),
                    BoxShadow(
                        color: Colors.white,
                        blurRadius: 12,
                        offset: Offset(-5, -5)),
                  ],
          ),
          child: Row(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [c1, c2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: c1.withOpacity(0.45),
                      blurRadius: 10,
                      offset: const Offset(0, 5))
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
                Center(
                    child:
                        Icon(widget.notif.icon, color: Colors.white, size: 22)),
                if (!widget.notif.isRead)
                  Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                              color: Color(0xFFFF4444),
                              shape: BoxShape.circle))),
              ]),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.notif.title,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: widget.notif.isRead
                                ? FontWeight.w700
                                : FontWeight.w800,
                            color: const Color(0xFF333355))),
                    const SizedBox(height: 4),
                    Text(widget.notif.subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF777799)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEEEF5),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0xFFBEBECF),
                              blurRadius: 3,
                              offset: Offset(2, 2)),
                          BoxShadow(
                              color: Colors.white,
                              blurRadius: 3,
                              offset: Offset(-2, -2)),
                        ],
                      ),
                      child: Text(widget.notif.time,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: c1)),
                    ),
                  ]),
            ),
            const SizedBox(width: 8),
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Color(0xFFEEEEF5),
                borderRadius: BorderRadius.all(Radius.circular(11)),
                boxShadow: [
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
              child: const Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: Color(0xFF5555AA)),
            ),
          ]),
        ),
      ),
    );
  }
}
