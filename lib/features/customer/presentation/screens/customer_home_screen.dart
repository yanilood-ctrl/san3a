import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/presentation/providers/app_providers.dart';
import '../../../../shared/models/models.dart';
import '../theme/customer_design.dart';
import 'customer_feed_screen.dart';
import 'customer_messages_screen.dart';
import 'customer_orders_screen.dart';
import 'customer_profile_screen.dart';

export 'customer_feed_screen.dart' show AppBlue;

class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navIndex = ref.watch(navIndexProvider);
    final l = AppLocalizations.of(context);

    final currentUser = ref.watch(authProvider);
    final firestoreConvsAsync = ref.watch(currentUserConversationsProvider);
    final unread = currentUser == null
        ? 0
        : (firestoreConvsAsync.valueOrNull ?? const <ConversationModel>[])
            .fold<int>(
                0,
                (int s, ConversationModel c) =>
                    s + c.unreadCountFor(currentUser.id));

    // Real, live "unseen since last Orders-page visit" count — see
    // customerUnseenOrdersCountProvider. Replaces the previous
    // ordersProvider-derived count, which was never anything but
    // DummyData.orders (ordersProvider is seeded with DummyData.orders and
    // is not written to by the real Customer order flow, which uses
    // customerFirestoreOrdersProvider instead) filtered to pending/inProgress
    // — a hardcoded-looking 4 that never changed.
    final unseenOrders = ref.watch(customerUnseenOrdersCountProvider);

    final List<Widget> screens = [
      const CustomerFeedScreen(),
      const CustomerMessagesScreen(),
      const CustomerOrdersScreen(),
      const CustomerProfileScreen(),
    ];

    final List<Map<String, dynamic>> navItems = [
      {
        'icon': Icons.home_outlined,
        'active': Icons.home_rounded,
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
        'icon': Icons.receipt_long_outlined,
        'active': Icons.receipt_long_rounded,
        'label': l.get('orders'),
        'badge': unseenOrders
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
      bottomNavigationBar: _FancyBottomNav(
        navItems: navItems,
        navIndex: navIndex,
        onTap: (i) => ref.read(navIndexProvider.notifier).state = i,
      ),
    );
  }
}

// ── Fancy Bottom Navigation (floating pill with raised active icon) ────────────
class _FancyBottomNav extends StatelessWidget {
  final List<Map<String, dynamic>> navItems;
  final int navIndex;
  final ValueChanged<int> onTap;

  const _FancyBottomNav({
    required this.navItems,
    required this.navIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
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
              top: 20, // leave room for raised icon
              child: Container(
                decoration: BoxDecoration(
                  color: CustomerColors.card,
                  borderRadius: BorderRadius.circular(CustomerRadii.sheet),
                  boxShadow: [
                    BoxShadow(
                      color: CustomerColors.primary.withOpacity(0.14),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
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
                  final selected = navIndex == i;
                  final badge = item['badge'] as int;
                  return Expanded(
                    child: _NavItem(
                      icon: item['icon'] as IconData,
                      activeIcon: item['active'] as IconData,
                      label: item['label'] as String,
                      selected: selected,
                      badge: badge,
                      onTap: () => onTap(i),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Raised active bubble OR normal icon
          SizedBox(
            height: 46,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                if (selected)
                  // White circle "bump" behind the icon
                  Positioned(
                    top: 0,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: CustomerColors.card,
                        boxShadow: [
                          BoxShadow(
                            color: CustomerColors.primary.withOpacity(0.28),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (selected)
                  Positioned(
                    top: 4,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: CustomerColors.primaryGradient,
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child:
                                Icon(activeIcon, color: Colors.white, size: 22),
                          ),
                          if (badge > 0)
                            Positioned(
                              right: 4,
                              top: 4,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: const BoxDecoration(
                                  color: CustomerColors.error,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    badge > 9 ? '9+' : '$badge',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 7,
                                        fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (!selected)
                  Positioned(
                    bottom: 8,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(icon, color: CustomerColors.textSecondary.withOpacity(0.7), size: 22),
                        if (badge > 0)
                          Positioned(
                            right: -7,
                            top: -6,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: CustomerColors.error,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                badge > 9 ? '9+' : '$badge',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Label
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? CustomerColors.primaryDark
                    : CustomerColors.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
