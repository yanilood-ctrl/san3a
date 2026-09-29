import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/admin_providers.dart';
import 'admin_dashboard_screen.dart';
import 'admin_users_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_categories_screen.dart';
import 'admin_complaints_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_chat_screen.dart';
import 'admin_review_management_screen.dart';
import 'admin_screens.dart';
import '../widgets/admin_bottom_nav.dart';

// Admin nav: 0=Home, 1=Users, 2=Orders, 3=Categories, 4=Complaints, 5=Profile
// Bottom bar shows: Home(0), Plus(opens menu), Profile(5)

class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navIndex = ref.watch(adminNavIndexProvider);

    final screens = [
      const AdminDashboardScreen(),
      const AdminUsersScreen(),
      const AdminOrdersScreen(),
      const AdminCategoriesScreen(),
      const AdminComplaintsScreen(),
      const AdminProfileScreen(),
    ];

    // bottomIndex: 0=Home, 1=Plus(center), 2=Profile
    final bottomIndex = navIndex == 5 ? 2 : (navIndex == 0 ? 0 : 1);

    // Same complaint + order total every AdminBottomNav-hosting screen shows.
    final totalBadge = adminTotalBadgeCount(ref);

    return Scaffold(
      body: IndexedStack(index: navIndex, children: screens),
      extendBody: true,
      bottomNavigationBar: AdminBottomNav(
        selectedIndex: bottomIndex,
        totalBadge: totalBadge,
        onHomeTap: () => goToAdminHomeTab(context, ref),
        onPlusTap: () => showAdminSectionsMenu(context, ref),
        onProfileTap: () => goToAdminProfileTab(context, ref),
      ),
    );
  }
}
