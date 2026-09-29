import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/admin_providers.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/shared_widgets.dart' show ProfileAvatarImage;
import '../../../../shared/helpers/phone_call_helper.dart';
import '../../../../shared/widgets/profile_field_selectors.dart';
import 'admin_screens.dart' show AdminOrdersScreen, showAdminOrderDetails;
import '../../../auth/presentation/providers/app_providers.dart'
    show
        ordersProvider,
        providerReviewsProvider,
        categoriesProvider,
        contractorWorkersByIdProvider,
        authProvider,
        createProfileUpdateNotification,
        createWorkerUpdateNotification,
        sendUserWarningNotification,
        ContractorWorkersService,
        adminFirestoreOrdersProvider;

// ─── Constants ────────────────────────────────────────────────────────────────
const Map<String, String> _categoryLabels = {
  'electrician': 'Electrician',
  'carpenter': 'Carpenter',
  'plumber': 'Plumber',
  'painter': 'Painter',
  'mason': 'Mason',
  'gardener': 'Gardener',
  'ac_technician': 'AC Technician',
  'mechanic': 'Mechanic',
  'welder': 'Welder / Blacksmith',
  'blacksmith': 'Blacksmith',
  'tailor': 'Tailor',
  'cleaner': 'Cleaner',
  'other_services': 'Other Services',
};

const Map<UserRole, String> _roleLabels = {
  UserRole.customer: 'Customer',
  UserRole.professional: 'Professional',
  UserRole.contractor: 'Contractor',
  UserRole.admin: 'Admin',
};
const Map<UserRole, Color> _roleColors = {
  // Blue family — was AppColors.primary (pure black, indistinguishable from
  // "no color"). Same light-blue already established elsewhere in Admin
  // (e.g. the In Progress order status) for a coherent app-wide blue.
  UserRole.customer: Color(0xFF0EA5E9),
  UserRole.professional: AppColors.success,
  UserRole.contractor: Color(0xFF7C3AED),
  UserRole.admin: AppAdmin.dark,
};

// ─── Active-order safety check (Block User) ────────────────────────────────
// "Active" = not in a terminal state. OrderModel only has 4 real statuses —
// completed/cancelled are terminal (a rejected order is stored as
// OrderStatus.cancelled + rejectReason, per the existing reject flow in
// app_providers.dart), pending/inProgress are active. No other statuses
// exist in the current schema.
bool _isActiveOrderStatus(OrderStatus status) =>
    status == OrderStatus.pending || status == OrderStatus.inProgress;

// Matches orders to the user the same way each role's own order/profile
// screens already do:
//  - Customer: customerId, with the customerName fallback already used by
//    the real Customer Profile stats (customer_profile_screen.dart).
//  - Professional/Contractor: providerId only — neither role's own profile
//    screen uses a name fallback, so this doesn't invent one.
//  - Admin: never a customer/provider on an order, so always empty.
List<OrderModel> _activeOrdersForUser(
    List<OrderModel> allOrders, UserModel user) {
  bool ownedByUser(OrderModel o) {
    switch (user.role) {
      case UserRole.customer:
        return o.customerId == user.id || o.customerName == user.fullName;
      case UserRole.professional:
      case UserRole.contractor:
        return o.providerId == user.id;
      case UserRole.admin:
        return false;
    }
  }

  return allOrders
      .where((o) => _isActiveOrderStatus(o.status) && ownedByUser(o))
      .toList();
}

Future<void> _openInMaps(String address) async {
  if (address.trim().isEmpty) return;
  final encoded = Uri.encodeComponent(address);
  final uri =
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');
  if (await canLaunchUrl(uri))
    await launchUrl(uri, mode: LaunchMode.externalApplication);
}

// ─── Public helper to open user details from other screens ───────────────────
void showAdminUserDetails(BuildContext context, UserModel user, WidgetRef ref) {
  showAdminUserModal(
      context: context,
      builder: (_) => _UserDetailsDialog(user: user, ref: ref));
}

// Which list the body shows when it isn't following the visible role tabs —
// reached via the header's three-dots menu instead of a tab.
enum _UserListFilter { none, blocked, deleted }

// ─── ONE shared presentation for every Admin Users secondary flow ────────────
// Every major Admin Users overlay (User Details, Edit User, Warn, Suspend,
// Block/Unblock confirm, End Suspension, Delete/Deactivate, Restore, the
// Active Orders blocker, Edit Worker, Add/Edit Service) opens through this
// single helper instead of a mix of showDialog/showModalBottomSheet calls,
// so they all share the exact same entrance direction, backdrop, width
// strategy and corner language. Modeled on showModalBottomSheet's own
// defaults (dimmed barrier, slide-up transition) — deliberately not
// reinventing a custom transition/overlay mechanism.
Future<T?> showAdminUserModal<T>({
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

// One reusable premium shell every flow above renders its content into.
// Visual language mirrors the Admin Orders order-details sheet's
// neo-morphism (see _OrderDetailsSheet in admin_screens.dart, mirrored
// locally since that widget is private to that file) and this file's own
// already-upgraded User Details / Edit User header formula (dark gradient
// banner, glass close button) — reused everywhere instead of redesigning
// those two dialogs again.
//
// [accentColor] tints the header gradient and the drag handle's glow so
// each flow keeps its own semantic identity (orange for Warn/Suspend, red
// for destructive actions, green for Restore/Unblock/End Suspension,
// AppAdmin lilac for neutral flows like Edit User/Edit Worker/Services)
// while every flow still shares the exact same structural shell.
class _AdminUserModalShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color accentColor;
  final Widget body;
  final Widget? footer;
  final EdgeInsets bodyPadding;
  const _AdminUserModalShell({
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
      // Keeps the sheet above the keyboard — same convention already used
      // by _SuspendUserSheet.
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          // Same max-width strategy as the rest of the redesigned Admin
          // Users dialogs — keeps the sheet from stretching edge-to-edge on
          // wide/Web viewports while still filling narrow mobile widths.
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
              // Header — same dark-gradient-banner + drop-shadow + glass
              // close button language already used by User Details / Edit
              // User, tinted per-flow by [accentColor].
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

// ─── Admin Users Screen ───────────────────────────────────────────────────────
class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _searchCtrl = TextEditingController();
  String _query = '';
  // Guards against re-showing details for the same pending-id request across
  // rebuilds; a new distinct id (from a fresh request) clears this guard.
  String? _lastHandledPendingUserId;

  // 4 visible role tabs: All / Customers / Professionals / Contractors.
  // Blocked/Deleted are switched to via the header's three-dots menu (see
  // _extraFilter) instead of a visible tab, but still reuse this same
  // screen/state and its existing filtered lists.
  static const int _tabCount = 4;
  _UserListFilter _extraFilter = _UserListFilter.none;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _tabCount, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestoreState = ref.watch(firestoreUsersStreamProvider);
    final users = ref.watch(adminUsersProvider);
    final blocked = ref.watch(blockedUsersProvider);
    final pendingUserId = ref.watch(adminPendingUserDetailsIdProvider);

    // Open the requested provider's details once the live users list has
    // loaded, then never again for this same request (guards against
    // Riverpod rebuilds re-opening the dialog on every state change). A
    // later distinct request (a new id) is still honored since it won't
    // match _lastHandledPendingUserId.
    if (pendingUserId != null &&
        pendingUserId != _lastHandledPendingUserId &&
        firestoreState.hasValue) {
      _lastHandledPendingUserId = pendingUserId;
      final matches = users.where((u) => u.id == pendingUserId).toList();
      final matched = matches.isNotEmpty ? matches.first : null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Reset to null so this is a one-shot signal, not persistent
        // selection state.
        ref.read(adminPendingUserDetailsIdProvider.notifier).state = null;
        if (!context.mounted) return;
        if (matched != null) {
          showAdminUserDetails(context, matched, ref);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Related user could not be found.'),
              behavior: SnackBarBehavior.floating));
        }
      });
    }

    // Matches the visible name/email as before, plus the Firestore document
    // id (== Firebase UID — firestoreUsersStreamProvider loads it as
    // UserModel.id via `UserModel.fromMap(d.data(), id: d.id)`, so it's
    // already in this in-memory list; no extra Firestore query needed) and
    // phone/city/work area. Both sides are trimmed + lowercased, and id
    // matching is substring-based so a partial UID still finds the user.
    final normalizedQuery = _query.trim().toLowerCase();
    bool matchesQuery(UserModel u) {
      if (normalizedQuery.isEmpty) return true;
      bool fieldMatches(String? value) =>
          value != null && value.trim().toLowerCase().contains(normalizedQuery);
      return fieldMatches(u.id) ||
          fieldMatches(u.fullName) ||
          fieldMatches(u.email) ||
          fieldMatches(u.phone) ||
          fieldMatches(u.city) ||
          fieldMatches(u.workArea);
    }

    // Status priority: Deleted > Blocked > Actively Suspended > Active.
    // Deleted users are pulled out first and only ever shown in the Deleted
    // tab — they never appear in All/Customers/Professionals/Contractors or
    // Blocked, even if isBlocked/suspendedUntil are still set underneath.
    // These counts (and the header/tab/menu labels below) are always derived
    // from the full unfiltered [users] list — a search query only narrows
    // which cards are rendered inside the currently selected tab, it must
    // never move a user between counts or tabs.
    final deletedList = users.where((u) => u.isDeleted).toList();
    final nonDeleted = users.where((u) => !u.isDeleted).toList();

    final activeUsers =
        nonDeleted.where((u) => !blocked.contains(u.id)).toList();
    final all = activeUsers;
    final customers =
        activeUsers.where((u) => u.role == UserRole.customer).toList();
    final professionals =
        activeUsers.where((u) => u.role == UserRole.professional).toList();
    final contractors =
        activeUsers.where((u) => u.role == UserRole.contractor).toList();
    final blockedList =
        nonDeleted.where((u) => blocked.contains(u.id)).toList();

    // Search-narrowed display lists — the only lists ever handed to
    // _UsersList. Filtering within each already-computed partition means a
    // query can only hide/show cards, never change which count/tab a user
    // belongs to.
    final allDisplay = all.where(matchesQuery).toList();
    final customersDisplay = customers.where(matchesQuery).toList();
    final professionalsDisplay = professionals.where(matchesQuery).toList();
    final contractorsDisplay = contractors.where(matchesQuery).toList();
    final blockedDisplay = blockedList.where(matchesQuery).toList();
    final deletedDisplay = deletedList.where(matchesQuery).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(children: [
        // ── Header — same premium lilac / 3D depth language as the
        // redesigned Admin Orders header (3-stop gradient, 32px rounded
        // bottom corners, tinted drop shadow). Role navigation no longer
        // lives inside this header — see below.
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [AppAdmin.inkDarkest, AppAdmin.darkest, AppAdmin.dark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                  color: Color(0x60321143),
                  blurRadius: 28,
                  offset: Offset(0, 12)),
            ],
          ),
          child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                child: Row(children: [
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
                    child: const Icon(Icons.people_alt_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('Users',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                  const Spacer(),
                  // Active count badge
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.25)),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 6,
                                offset: const Offset(0, 3)),
                          ]),
                      child: Text('${all.length} Active',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700))),
                  if (blockedList.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.28),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.error.withOpacity(0.35)),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3)),
                            ]),
                        child: Text('${blockedList.length} Blocked',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700))),
                  ],
                  if (deletedList.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.26),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.3)),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3)),
                            ]),
                        child: Text('${deletedList.length} Deleted',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700))),
                  ],
                  const SizedBox(width: 6),
                  // Page-level menu: Blocked/Deleted lists live here now
                  // instead of as visible tabs, reusing the same counts
                  // already computed above (no extra Firestore queries).
                  // Same premium glass 3D trigger + floating neumorphic
                  // panel language as the redesigned Admin Orders header
                  // menu — same two destinations/counts/callbacks.
                  _UsersHeaderMenuButton(
                    blockedCount: blockedList.length,
                    deletedCount: deletedList.length,
                    onBlocked: () =>
                        setState(() => _extraFilter = _UserListFilter.blocked),
                    onDeleted: () =>
                        setState(() => _extraFilter = _UserListFilter.deleted),
                  ),
                ]),
              )),
        ),

        // ── Role Navigation — moved outside/below the purple header, as
        // its own separate elevated component on the light page background
        // (matches the Admin Orders All / Pending / In Progress bar).
        // Same TabController, same counts, same selected-role logic — the
        // Blocked/Deleted filter bar swap-in is unchanged, just relocated
        // and restyled for the light background it now sits on.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: _extraFilter != _UserListFilter.none
              ? _ExtraFilterBar(
                  title: _extraFilter == _UserListFilter.blocked
                      ? 'Blocked Users'
                      : 'Deleted Users',
                  count: _extraFilter == _UserListFilter.blocked
                      ? blockedList.length
                      : deletedList.length,
                  onBack: () =>
                      setState(() => _extraFilter = _UserListFilter.none),
                )
              : _UserRoleStepperBar(
                  controller: _tab,
                  allCount: all.length,
                  customersCount: customers.length,
                  professionalsCount: professionals.length,
                  contractorsCount: contractors.length,
                  onTabChanged: (i) => setState(() => _tab.animateTo(i)),
                ),
        ),

        // ── Search Bar — local premium elevated search row, mirroring the
        // Admin Orders search surface (not the shared AdminSearchBar, which
        // other Admin screens still use unchanged). Same controller, same
        // search logic/fields, same clear behavior.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Container(
            decoration: BoxDecoration(
              color: AppAdmin.surfaceTint,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                    color: AppAdmin.borderSoft,
                    blurRadius: 0,
                    offset: Offset(0, 5)),
                BoxShadow(
                    color: AppAdmin.borderSoft,
                    blurRadius: 12,
                    offset: Offset(5, 5)),
                BoxShadow(
                    color: Colors.white,
                    blurRadius: 12,
                    offset: Offset(-4, -4)),
              ],
            ),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [AppAdmin.dark, AppAdmin.darkest],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: AppAdmin.dark.withOpacity(0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3)),
                  ],
                ),
                child: const Icon(Icons.search_rounded,
                    color: Colors.white, size: 20),
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
                    hintText: 'Search by name, email, phone, or ID...',
                    hintStyle: TextStyle(
                        color: AppAdmin.inkLight.withOpacity(0.8),
                        fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    suffixIcon: _query.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                            child: const Icon(Icons.close_rounded,
                                size: 18, color: AppAdmin.inkLight))
                        : null,
                  ),
                ),
              ),
            ]),
          ),
        ),

        // ── Tab Content ──
        Expanded(
          child: firestoreState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.cloud_off_rounded,
                      size: 48, color: AppColors.textSecondary),
                  const SizedBox(height: 12),
                  Text('Failed to load users',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Text(e.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ]),
              ),
            ),
            data: (_) => _extraFilter == _UserListFilter.blocked
                ? _UsersList(users: blockedDisplay, showBlockedStyle: true)
                : _extraFilter == _UserListFilter.deleted
                    ? _UsersList(users: deletedDisplay, showDeletedStyle: true)
                    : TabBarView(
                        controller: _tab,
                        children: [
                          _UsersList(users: allDisplay),
                          _UsersList(users: customersDisplay),
                          _UsersList(users: professionalsDisplay),
                          _UsersList(users: contractorsDisplay),
                        ],
                      ),
          ),
        ),
      ]),
    );
  }
}

// Replaces the role stepper bar while a Blocked/Deleted filter from the
// header's three-dots menu is active, so no role tab is ever left looking
// selected. Tapping back returns to the previously selected visible role
// tab. Now sits outside the header on the light page background, so it's
// restyled as its own elevated neumorphic surface (same treatment as the
// role stepper bar / Admin Orders stepper bar) instead of the old
// translucent-white-on-dark-header look.
class _ExtraFilterBar extends StatelessWidget {
  final String title;
  final int count;
  final VoidCallback onBack;
  const _ExtraFilterBar(
      {required this.title, required this.count, required this.onBack});
  @override
  Widget build(BuildContext context) => Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
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
        child: Row(children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: AppAdmin.dark.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.arrow_back_rounded,
                  color: AppAdmin.dark, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('$title ($count)',
                style: const TextStyle(
                    color: AppAdmin.inkDarkest,
                    fontSize: 15,
                    fontWeight: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      );
}

// ─── Role Navigation Stepper Bar (outside the header, Admin Orders style) ─────
// Horizontally scrollable so 4 role labels (including the longer
// "Professionals" / "Contractors") never risk a RenderFlex overflow on
// narrow screens, unlike a fixed equal-width row. Same premium elevated
// pill-bar language as _AdminOrderStepperBar in Admin Orders. Role colors
// are the same identity colors already used on the user cards/badges
// (_roleColors) — never the generic Admin lilac for a specific role.
class _RoleTabData {
  final String label;
  final IconData icon;
  final Color activeColor;
  const _RoleTabData(
      {required this.label, required this.icon, required this.activeColor});
}

class _UserRoleStepperBar extends StatefulWidget {
  final TabController controller;
  final int allCount, customersCount, professionalsCount, contractorsCount;
  final ValueChanged<int> onTabChanged;
  const _UserRoleStepperBar({
    required this.controller,
    required this.allCount,
    required this.customersCount,
    required this.professionalsCount,
    required this.contractorsCount,
    required this.onTabChanged,
  });
  @override
  State<_UserRoleStepperBar> createState() => _UserRoleStepperBarState();
}

class _UserRoleStepperBarState extends State<_UserRoleStepperBar> {
  static const _tabs = [
    _RoleTabData(
        label: 'All',
        icon: Icons.people_alt_rounded,
        activeColor: AppAdmin.dark),
    _RoleTabData(
        label: 'Customers',
        icon: Icons.person_rounded,
        activeColor: AppColors.primary),
    _RoleTabData(
        label: 'Professionals',
        icon: Icons.engineering_rounded,
        activeColor: AppColors.success),
    _RoleTabData(
        label: 'Contractors',
        icon: Icons.groups_rounded,
        activeColor: Color(0xFF7C3AED)),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final current = widget.controller.index;
        final counts = [
          widget.allCount,
          widget.customersCount,
          widget.professionalsCount,
          widget.contractorsCount,
        ];

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
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _tabs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              final isActive = current == i;
              final tab = _tabs[i];
              final darkColor =
                  Color.lerp(tab.activeColor, Colors.black, 0.35)!;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onTabChanged(i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
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
                                  colors: [tab.activeColor, darkColor],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight)
                              : null,
                          color: isActive ? null : Colors.transparent,
                          borderRadius: BorderRadius.circular(isActive ? 9 : 7),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                      color: tab.activeColor.withOpacity(0.45),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3)),
                                  BoxShadow(
                                      color: darkColor,
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
                              color:
                                  isActive ? Colors.white : AppAdmin.inkLight),
                        )),
                      ),
                      const SizedBox(width: 6),
                      AnimatedDefaultTextStyle(
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
                      ),
                      if (counts[i] > 0) ...[
                        const SizedBox(width: 6),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isActive
                                ? tab.activeColor
                                : AppAdmin.borderSoft,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                        color: tab.activeColor.withOpacity(0.4),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2)),
                                    BoxShadow(
                                        color: darkColor,
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
                                      : AppAdmin.inkMid)),
                        ),
                      ],
                    ]),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ─── Users Header Three-Dots Menu (premium 3D, floating neo panel) ────────────
// Presentation-only replacement for the old PopupMenuButton: same trigger
// position, same two actions (Blocked Users / Deleted Users) with the same
// counts and _extraFilter callbacks, wrapped in the same elevated
// floating-panel language used by the redesigned Admin Orders header menu.
class _UsersHeaderMenuButton extends StatefulWidget {
  final int blockedCount;
  final int deletedCount;
  final VoidCallback onBlocked;
  final VoidCallback onDeleted;
  const _UsersHeaderMenuButton({
    required this.blockedCount,
    required this.deletedCount,
    required this.onBlocked,
    required this.onDeleted,
  });

  @override
  State<_UsersHeaderMenuButton> createState() => _UsersHeaderMenuButtonState();
}

class _UsersHeaderMenuButtonState extends State<_UsersHeaderMenuButton>
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
    // Blocked keeps its destructive/red identity; Deleted stays a muted,
    // archive-like gray — same semantic colors as the original menu.
    final items = [
      _UsersMenuItemData(
        icon: Icons.block_rounded,
        label: 'Blocked Users',
        color: AppColors.error,
        count: widget.blockedCount,
        onTap: widget.onBlocked,
      ),
      _UsersMenuItemData(
        icon: Icons.delete_outline_rounded,
        label: 'Deleted Users',
        color: AppColors.textSecondary,
        count: widget.deletedCount,
        onTap: widget.onDeleted,
      ),
    ];

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
            right: 14,
            top: 70,
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(0.4, -0.3), end: Offset.zero)
                  .animate(curved),
              child: FadeTransition(
                  opacity: anim, child: _UsersHeaderMenuPanel(items: items)),
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
          child: const Icon(Icons.more_horiz_rounded,
              color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _UsersMenuItemData {
  final IconData icon;
  final String label;
  final Color color;
  final int count;
  final VoidCallback onTap;
  const _UsersMenuItemData({
    required this.icon,
    required this.label,
    required this.color,
    required this.count,
    required this.onTap,
  });
}

// ─── Users Header Menu Panel (floating, staggered animation, neo-3D rows) ─────
class _UsersHeaderMenuPanel extends StatefulWidget {
  final List<_UsersMenuItemData> items;
  const _UsersHeaderMenuPanel({required this.items});
  @override
  State<_UsersHeaderMenuPanel> createState() => _UsersHeaderMenuPanelState();
}

class _UsersHeaderMenuPanelState extends State<_UsersHeaderMenuPanel>
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
      width: 210,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: AppAdmin.surfaceTint,
        boxShadow: const [
          BoxShadow(
              color: AppAdmin.borderSoft, blurRadius: 16, offset: Offset(6, 6)),
          BoxShadow(
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
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  item.onTap();
                },
                child: Row(children: [
                  Stack(clipBehavior: Clip.none, children: [
                    Container(
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
                              offset: Offset(-3, -3)),
                        ],
                      ),
                      child: Icon(item.icon, color: item.color, size: 20),
                    ),
                    if (item.count > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: item.color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: item.color.withOpacity(0.4),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Center(
                            child: Text('${item.count}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ),
                  ]),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(item.label,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppAdmin.inkDarkest))),
                ]),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Users List ───────────────────────────────────────────────────────────────
class _UsersList extends StatelessWidget {
  final List<UserModel> users;
  final bool showBlockedStyle;
  final bool showDeletedStyle;
  const _UsersList(
      {required this.users,
      this.showBlockedStyle = false,
      this.showDeletedStyle = false});

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(
            showDeletedStyle
                ? Icons.no_accounts_rounded
                : showBlockedStyle
                    ? Icons.block_rounded
                    : Icons.people_outline,
            size: 60,
            color: showDeletedStyle
                ? AppColors.textSecondary.withOpacity(0.3)
                : showBlockedStyle
                    ? AppColors.error.withOpacity(0.3)
                    : AppColors.border),
        const SizedBox(height: 12),
        Text(
            showDeletedStyle
                ? 'No deactivated users'
                : showBlockedStyle
                    ? 'No blocked users'
                    : 'No users found',
            style: const TextStyle(
                color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: users.length,
      itemBuilder: (ctx, i) => _AnimatedUserCard(
        key: ValueKey(users[i].id),
        user: users[i],
        index: i,
        isBlocked: showBlockedStyle,
      ),
    );
  }
}

// ─── Animated wrapper for staggered entrance ─────────────────────────────────
class _AnimatedUserCard extends StatefulWidget {
  final UserModel user;
  final int index;
  final bool isBlocked;
  const _AnimatedUserCard(
      {super.key,
      required this.user,
      required this.index,
      required this.isBlocked});
  @override
  State<_AnimatedUserCard> createState() => _AnimatedUserCardState();
}

class _AnimatedUserCardState extends State<_AnimatedUserCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 280 + widget.index * 40),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
      opacity: _fade,
      child: SlideTransition(
          position: _slide,
          child: _UserCard(user: widget.user, isBlockedTab: widget.isBlocked)));
}

// ─── User Card (neo-3D) ───────────────────────────────────────────────────────
class _UserCard extends ConsumerWidget {
  final UserModel user;
  final bool isBlockedTab;
  const _UserCard({required this.user, this.isBlockedTab = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = ref.watch(blockedUsersProvider);
    final isBlocked = blocked.contains(user.id);
    final isDeleted = user.isDeleted;
    // Priority: Deleted > Blocked > Actively Suspended > Active — never
    // label a user "Suspended" once their suspendedUntil has passed, and
    // Blocked always wins visually since it's the stronger restriction.
    // A deleted user only ever appears in the Deleted tab (see
    // _AdminUsersScreenState.build), so its own pill takes priority here too.
    final isSuspended = !isBlocked && !isDeleted && user.isActivelySuspended;
    final color = _roleColors[user.role] ?? AppAdmin.dark;
    final c2 = Color.lerp(color, Colors.black, 0.35) ?? color;

    final accentColor = isBlocked ? AppColors.error : color;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppAdmin.surfaceTint,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withOpacity(0.16), width: 1),
        boxShadow: isBlocked
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
            onTap: () => showAdminUserDetails(context, user, ref),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── Top accent bar — refined premium treatment matching the
              // redesigned Admin Orders cards (slim gradient strip, tinted
              // by role color / blocked-red instead of a full color block).
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
                      // 3D Avatar
                      Stack(children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: isBlocked
                                ? const LinearGradient(
                                    colors: [
                                        Color(0xFFEF4444),
                                        Color(0xFF991B1B)
                                      ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight)
                                : LinearGradient(
                                    colors: [color, c2],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: (isBlocked
                                        ? const Color(0xFFEF4444)
                                        : color)
                                    .withOpacity(0.45),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                              BoxShadow(
                                color:
                                    (isBlocked ? const Color(0xFF991B1B) : c2)
                                        .withOpacity(0.9),
                                blurRadius: 0,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Stack(children: [
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 25,
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
                            ProfileAvatarImage(
                              imageUrl: user.avatar,
                              size: 50,
                              borderRadius: 16,
                              fallbackText: user.fullName.isNotEmpty
                                  ? user.fullName
                                  : '?',
                              fallbackTextStyle: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white),
                            ),
                          ]),
                        ),
                        if (isBlocked)
                          Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                    color: AppColors.error,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: AppAdmin.surfaceTint, width: 2)),
                                child: const Icon(Icons.block_rounded,
                                    size: 10, color: Colors.white),
                              )),
                      ]),
                      const SizedBox(width: 12),

                      // Info
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Row(children: [
                              Expanded(
                                  child: Text(user.fullName,
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: isBlocked
                                              ? AppColors.error
                                              : AppAdmin.inkDarkest))),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  gradient: isBlocked
                                      ? null
                                      : LinearGradient(colors: [
                                          color.withOpacity(0.15),
                                          c2.withOpacity(0.08)
                                        ]),
                                  color: isBlocked
                                      ? AppColors.error.withOpacity(0.10)
                                      : null,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(_roleLabels[user.role] ?? 'Admin',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: isBlocked
                                            ? AppColors.error
                                            : color)),
                              ),
                            ]),
                            const SizedBox(height: 3),
                            Text(user.email,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: isBlocked
                                        ? AppColors.error.withOpacity(0.5)
                                        : AppAdmin.inkLight)),
                            const SizedBox(height: 6),
                            // Metadata chips — Wrap instead of a rigid Row so a
                            // long phone number or work area/city never risks a
                            // RenderFlex overflow on narrow screens; same premium
                            // chip language as the redesigned Admin Orders cards.
                            Wrap(spacing: 8, runSpacing: 6, children: [
                              if (user.phone.isNotEmpty)
                                _UserInfoChip(
                                    icon: Icons.phone_outlined,
                                    label: user.phone,
                                    color: isBlocked
                                        ? AppColors.error
                                        : AppAdmin.inkMid),
                              if (user.role != UserRole.customer &&
                                  (user.workArea?.isNotEmpty ?? false))
                                _UserInfoChip(
                                    icon: Icons.map_outlined,
                                    label: user.workArea!,
                                    color: isBlocked
                                        ? AppColors.error
                                        : AppAdmin.inkMid)
                              else if (user.city.isNotEmpty)
                                _UserInfoChip(
                                    icon: Icons.location_on_outlined,
                                    label: user.city,
                                    color: isBlocked
                                        ? AppColors.error
                                        : AppAdmin.inkMid),
                            ]),
                            if (isDeleted) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                    color: AppColors.textSecondary
                                        .withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: AppColors.textSecondary
                                            .withOpacity(0.25))),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.no_accounts_rounded,
                                          size: 10,
                                          color: AppColors.textSecondary
                                              .withOpacity(0.8)),
                                      const SizedBox(width: 4),
                                      Text('Deactivated',
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textSecondary
                                                  .withOpacity(0.8))),
                                    ]),
                              ),
                            ] else if (isBlocked) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                    color: AppColors.error.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color:
                                            AppColors.error.withOpacity(0.2))),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.block_rounded,
                                          size: 10,
                                          color:
                                              AppColors.error.withOpacity(0.7)),
                                      const SizedBox(width: 4),
                                      Text('Account Blocked',
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.error
                                                  .withOpacity(0.7))),
                                    ]),
                              ),
                            ] else if (isSuspended) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                    color: const Color(0xFFF97316)
                                        .withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: const Color(0xFFF97316)
                                            .withOpacity(0.25))),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                          Icons.pause_circle_outline_rounded,
                                          size: 10,
                                          color: Color(0xFFF97316)),
                                      const SizedBox(width: 4),
                                      Text(
                                          'Suspended until ${user.suspendedUntil!.day}/${user.suspendedUntil!.month}/${user.suspendedUntil!.year}',
                                          style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFFF97316))),
                                    ]),
                              ),
                            ],
                          ])),
                      const SizedBox(width: 4),
                      _UserPopupMenu(
                          user: user,
                          isBlocked: isBlocked,
                          isDeleted: isDeleted,
                          ref: ref),
                    ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── Small info chip used on the redesigned User Card ─────────────────────────
// Mirrors the Neo3DChip metadata-chip language from the redesigned Admin
// Orders cards, kept local to this file rather than importing a shared
// widget from admin_screens.dart for an unrelated screen.
class _UserInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _UserInfoChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
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
              color: color.withOpacity(0.08),
              blurRadius: 4,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color.withOpacity(0.9))),
      ]),
    );
  }
}

// ─── Neo-3D Popup Menu ────────────────────────────────────────────────────────
class _UserPopupMenu extends StatelessWidget {
  final UserModel user;
  final bool isBlocked;
  final bool isDeleted;
  final WidgetRef ref;
  const _UserPopupMenu(
      {required this.user,
      required this.isBlocked,
      required this.isDeleted,
      required this.ref});

  // Awaits a real partial Firestore write (AdminUsersNotifier.setUserBlocked)
  // before showing success; the admin-list UI then refreshes itself via the
  // live firestoreUsersStreamProvider listener that already backs
  // adminUsersProvider/blockedUsersProvider — no local-only state mutation.
  Future<void> _handleBlockWithNav(
      BuildContext ctx, ScaffoldMessengerState messenger) async {
    final notifier = ref.read(adminUsersProvider.notifier);
    if (isBlocked) {
      // Unblock — unchanged: no active-order check runs on this path.
      try {
        await notifier.setUserBlocked(user.id, false);
        messenger.showSnackBar(SnackBar(
            content: Text('${user.fullName} has been unblocked'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))));
      } catch (e) {
        debugPrint('[AdminUsers] unblock failed: $e');
        messenger.showSnackBar(SnackBar(
            content: const Text('Failed to unblock user. Please try again.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))));
      }
      return;
    }

    await _checkActiveOrdersThenBlock(ctx, messenger, notifier);
  }

  // Safety check before Block: read the live admin orders stream once
  // (adminFirestoreOrdersProvider — the same one AdminOrdersScreen/dashboard
  // already use), decide, then either open the existing Block confirmation
  // unchanged or show the active-orders warning instead of it.
  Future<void> _checkActiveOrdersThenBlock(BuildContext ctx,
      ScaffoldMessengerState messenger, AdminUsersNotifier notifier) async {
    showDialog(
        context: ctx,
        barrierDismissible: false,
        builder: (_) => const _CheckingOrdersDialog());

    List<OrderModel> activeOrders;
    try {
      final allOrders = await ref.read(adminFirestoreOrdersProvider.future);
      activeOrders = _activeOrdersForUser(allOrders, user);
    } catch (e) {
      debugPrint('[AdminUsers] active-orders check failed: $e');
      if (ctx.mounted) Navigator.of(ctx, rootNavigator: true).pop();
      messenger.showSnackBar(SnackBar(
          content:
              const Text('Unable to verify active orders. Please try again.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
      return;
    }
    if (ctx.mounted) Navigator.of(ctx, rootNavigator: true).pop();
    if (!ctx.mounted) return;

    if (activeOrders.isNotEmpty) {
      showAdminUserModal(
          context: ctx,
          builder: (_) => _ActiveOrdersWarningDialog(
              user: user, orders: activeOrders, ref: ref, outerContext: ctx));
      return;
    }

    _showBlockConfirmDialog(ctx, messenger, notifier);
  }

  // Unchanged existing Block confirmation + Firestore write flow.
  void _showBlockConfirmDialog(BuildContext ctx,
      ScaffoldMessengerState messenger, AdminUsersNotifier notifier) {
    showAdminUserModal(
        context: ctx,
        builder: (_) => _ConfirmDialog(
              title: 'Block User',
              message:
                  'Block ${user.fullName}? They will not be able to send messages or place orders.',
              confirmLabel: 'Block',
              confirmColor: const Color(0xFFEA580C),
              icon: Icons.block_rounded,
              onConfirm: () async {
                try {
                  await notifier.setUserBlocked(user.id, true);
                  messenger.showSnackBar(SnackBar(
                      content: Text('${user.fullName} has been blocked'),
                      backgroundColor: const Color(0xFFEA580C),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))));
                } catch (e) {
                  debugPrint('[AdminUsers] block failed: $e');
                  messenger.showSnackBar(SnackBar(
                      content:
                          const Text('Failed to block user. Please try again.'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))));
                }
              },
            ));
  }

  // Ends an active temporary suspension early. Separate from Block/Unblock —
  // reuses the existing AdminUsersNotifier.unsuspendUserFirestore write
  // (already clears suspendedUntil only; isBlocked/isDeleted are untouched),
  // and the same immediate-pop + async-snackbar pattern as
  // _showBlockConfirmDialog above, so there's no new loading UI to add.
  void _showEndSuspensionDialog(BuildContext ctx,
      ScaffoldMessengerState messenger, AdminUsersNotifier notifier) {
    showAdminUserModal(
        context: ctx,
        builder: (_) => _ConfirmDialog(
              title: 'End Suspension',
              message:
                  'This user will regain access immediately. Their account will no longer remain suspended until the original end date.',
              confirmLabel: 'End Suspension',
              cancelLabel: 'Keep Suspended',
              confirmColor: AppColors.success,
              icon: Icons.play_circle_outline_rounded,
              onConfirm: () async {
                try {
                  await notifier.unsuspendUserFirestore(user.id);
                  messenger.showSnackBar(SnackBar(
                      content: Text('Suspension ended for ${user.fullName}'),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))));
                } catch (e) {
                  debugPrint('[AdminUsers] end suspension failed: $e');
                  messenger.showSnackBar(SnackBar(
                      content: const Text(
                          'Failed to end suspension. Please try again.'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))));
                }
              },
            ));
  }

  // Delete User is now a real, persistent Soft Delete (isDeleted/deletedAt),
  // not the old local-state-only deleteUser(). Same active-orders safety
  // check as Block, then a strong type-DELETE-to-confirm dialog instead of
  // the old one-tap confirm.
  Future<void> _handleDeleteWithNav(
      BuildContext ctx, ScaffoldMessengerState messenger) async {
    // Defensive guard — the menu already hides 'delete' for admin accounts;
    // AdminUsersNotifier.softDeleteUser also refuses the write itself.
    if (user.role == UserRole.admin) return;
    final notifier = ref.read(adminUsersProvider.notifier);
    await _checkActiveOrdersThenDelete(ctx, messenger, notifier);
  }

  // Mirrors _checkActiveOrdersThenBlock exactly (same provider, same
  // matching rules, same warning dialog — just a different action label and
  // a different dialog shown once orders are confirmed clear).
  Future<void> _checkActiveOrdersThenDelete(BuildContext ctx,
      ScaffoldMessengerState messenger, AdminUsersNotifier notifier) async {
    showDialog(
        context: ctx,
        barrierDismissible: false,
        builder: (_) => const _CheckingOrdersDialog());

    List<OrderModel> activeOrders;
    try {
      final allOrders = await ref.read(adminFirestoreOrdersProvider.future);
      activeOrders = _activeOrdersForUser(allOrders, user);
    } catch (e) {
      debugPrint('[AdminUsers] active-orders check failed: $e');
      if (ctx.mounted) Navigator.of(ctx, rootNavigator: true).pop();
      messenger.showSnackBar(SnackBar(
          content:
              const Text('Unable to verify active orders. Please try again.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
      return;
    }
    if (ctx.mounted) Navigator.of(ctx, rootNavigator: true).pop();
    if (!ctx.mounted) return;

    if (activeOrders.isNotEmpty) {
      showAdminUserModal(
          context: ctx,
          builder: (_) => _ActiveOrdersWarningDialog(
              user: user,
              orders: activeOrders,
              ref: ref,
              outerContext: ctx,
              actionLabel: 'deactivating the account'));
      return;
    }

    showAdminUserModal(
        context: ctx,
        builder: (_) =>
            _DeactivateUserDialog(user: user, ref: ref, messenger: messenger));
  }

  void _handleRestoreWithNav(
      BuildContext ctx, ScaffoldMessengerState messenger) {
    showAdminUserModal(
        context: ctx,
        builder: (_) =>
            _RestoreUserDialog(user: user, ref: ref, messenger: messenger));
  }

  // Keep old methods for backward compat (unused but avoids refactor)
  void _handleBlock(BuildContext context) =>
      _handleBlockWithNav(context, ScaffoldMessenger.of(context));
  void _handleSuspend(BuildContext context) {}
  void _handleDelete(BuildContext context) =>
      _handleDeleteWithNav(context, ScaffoldMessenger.of(context));

  void _snack(BuildContext context, String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  // Dispatches an action exactly like the old PopupMenuButton.onSelected did
  // — same postFrameCallback-guarded switch, same dialogs/sheets/handlers,
  // same behavior. Only the trigger that calls this (a floating panel
  // instead of PopupMenuItem taps) has changed.
  void _dispatch(BuildContext context, String val) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = context;
      if (!ctx.mounted) return;
      final scaffoldMsg = ScaffoldMessenger.of(ctx);
      switch (val) {
        case 'edit':
          showAdminUserModal(
              context: ctx,
              builder: (_) => _EditUserDialog(user: user, ref: ref));
          break;
        case 'warn':
          showAdminUserModal(
              context: ctx,
              builder: (_) => _WarnUserDialog(
                    user: user,
                    onConfirm: (msg) async {
                      final admin = ref.read(authProvider);
                      await sendUserWarningNotification(
                        userId: user.id,
                        message: msg,
                        createdById: admin?.id,
                        createdByName: admin?.fullName,
                      );
                      ref
                          .read(adminUsersProvider.notifier)
                          .warnUser(user.id, msg);
                      if (ctx.mounted) {
                        scaffoldMsg.showSnackBar(SnackBar(
                            content: Text('Warning sent to ${user.fullName}'),
                            backgroundColor: const Color(0xFFF97316),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))));
                      }
                    },
                  ));
          break;
        case 'suspend':
          showAdminUserModal(
            context: ctx,
            builder: (_) =>
                _SuspendUserSheet(user: user, ref: ref, messenger: scaffoldMsg),
          );
          break;
        case 'end_suspension':
          _showEndSuspensionDialog(
              ctx, scaffoldMsg, ref.read(adminUsersProvider.notifier));
          break;
        case 'block':
          _handleBlockWithNav(ctx, scaffoldMsg);
          break;
        case 'delete':
          _handleDeleteWithNav(ctx, scaffoldMsg);
          break;
        case 'restore':
          _handleRestoreWithNav(ctx, scaffoldMsg);
          break;
      }
    });
  }

  // Same premium floating neumorphic panel language as the redesigned
  // Admin Orders per-card three-dots menu: positioned off the tapped
  // trigger, staggered pop-in entrance animation. Exact same conditional
  // action list/visibility and semantic colors as before — Edit stays
  // Admin lilac/neutral, Warn/Suspend stay amber/orange, Block stays
  // red/orange destructive (or green for Unblock), Delete stays red.
  void _open(BuildContext context) {
    HapticFeedback.lightImpact();
    final items = isDeleted
        ? [
            _UserActionItemData(
                icon: Icons.restore_rounded,
                label: 'Restore User',
                iconColors: [AppColors.success, const Color(0xFF065F46)],
                labelColor: AppColors.success,
                onTap: () => _dispatch(context, 'restore')),
          ]
        : [
            _UserActionItemData(
                icon: Icons.edit_outlined,
                label: 'Edit User',
                iconColors: [AppAdmin.dark, AppAdmin.darkest],
                onTap: () => _dispatch(context, 'edit')),
            _UserActionItemData(
                icon: Icons.warning_amber_rounded,
                label: 'Warn User',
                iconColors: [const Color(0xFFF97316), const Color(0xFF9A3412)],
                labelColor: const Color(0xFFF97316),
                onTap: () => _dispatch(context, 'warn')),
            _UserActionItemData(
                icon: Icons.pause_circle_outline_rounded,
                label: 'Suspend',
                iconColors: [const Color(0xFFF97316), const Color(0xFF9A3412)],
                labelColor: const Color(0xFFF97316),
                onTap: () => _dispatch(context, 'suspend')),
            // Only while a temporary suspension is currently in effect —
            // hidden once suspendedUntil is absent or has already passed,
            // and separate from Block/Unblock (isBlocked is untouched by
            // this action either way).
            if (user.isActivelySuspended)
              _UserActionItemData(
                  icon: Icons.play_circle_outline_rounded,
                  label: 'End Suspension',
                  iconColors: [AppColors.success, const Color(0xFF065F46)],
                  labelColor: AppColors.success,
                  onTap: () => _dispatch(context, 'end_suspension')),
            _UserActionItemData(
                icon: isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
                label: isBlocked ? 'Unblock User' : 'Block User',
                iconColors: isBlocked
                    ? [AppColors.success, const Color(0xFF065F46)]
                    : [const Color(0xFFEA580C), const Color(0xFF9A3412)],
                labelColor:
                    isBlocked ? AppColors.success : const Color(0xFFEA580C),
                onTap: () => _dispatch(context, 'block')),
            // Admin accounts must not be soft-deletable through this UI —
            // hiding the menu item is the first layer; softDeleteUser()
            // itself also refuses the write as a defensive guard.
            if (user.role != UserRole.admin)
              _UserActionItemData(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete User',
                  iconColors: [AppColors.error, const Color(0xFF991B1B)],
                  labelColor: AppColors.error,
                  onTap: () => _dispatch(context, 'delete')),
          ];

    final box = context.findRenderObject() as RenderBox?;
    final pos = box?.localToGlobal(Offset.zero) ?? Offset.zero;
    final size = box?.size ?? Size.zero;

    // Viewport-aware direction/height so the panel never renders below the
    // screen, underneath the Admin bottom navigation, or above the safe
    // top area — see the class doc comment above for the full reasoning.
    final mq = MediaQuery.of(context);
    const edgeMargin = 14.0;
    // Not coupled to the real bottom-nav widget/height on purpose (per the
    // fix's own requirement) — a generous fixed safety margin on top of the
    // device's own safe-area inset keeps this correct even if the bottom
    // nav's height changes later.
    const bottomNavSafetyMargin = 84.0;
    final topSafeBound = mq.padding.top + edgeMargin;
    final bottomSafeBound =
        mq.size.height - mq.padding.bottom - bottomNavSafetyMargin - edgeMargin;

    // Estimated from the panel's own fixed layout formula (outer vertical
    // padding + a fixed per-row height) — only used to pick a direction and
    // a safe max height. The panel itself still clamps to whatever space is
    // actually available and scrolls if needed, so an estimate mismatch can
    // never cause real overflow.
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
      // Neither direction fully fits — use whichever side has more room
      // and let the panel's own action list scroll internally so every
      // action stays reachable instead of being clipped off-screen. Lower
      // bound is 0 (never estimatedPanelHeight, which can itself be under
      // 120 for a short menu) so this can never throw on a pathologically
      // small viewport — it would just render a very short scrollable
      // panel instead, still fully within the visible bounds.
      openDownward = spaceBelow >= spaceAbove;
      final available = openDownward ? spaceBelow : spaceAbove;
      maxPanelHeight = available.clamp(0.0, estimatedPanelHeight);
    }

    // Horizontal: same right-aligned anchor as before, but never let the
    // panel's fixed width push past the left screen edge on very narrow
    // viewports.
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
                  child: _UserActionMenuPanel(
                      items: items, maxHeight: maxPanelHeight)),
            ),
          ),
        ]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _UserThreeDotsTrigger(isBlocked: isBlocked, onOpen: _open);
  }
}

// ─── Per-user three-dots trigger (raised neumorphic, same 3D quality as ──────
// ─── the redesigned Admin Orders per-card trigger) ─────────────────────────────
class _UserThreeDotsTrigger extends StatefulWidget {
  final bool isBlocked;
  final void Function(BuildContext triggerContext) onOpen;
  const _UserThreeDotsTrigger({required this.isBlocked, required this.onOpen});
  @override
  State<_UserThreeDotsTrigger> createState() => _UserThreeDotsTriggerState();
}

class _UserThreeDotsTriggerState extends State<_UserThreeDotsTrigger>
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

class _UserActionItemData {
  final IconData icon;
  final String label;
  final List<Color> iconColors;
  final Color labelColor;
  final VoidCallback onTap;
  const _UserActionItemData({
    required this.icon,
    required this.label,
    required this.iconColors,
    this.labelColor = AppAdmin.inkDarkest,
    required this.onTap,
  });
}

// ─── Per-user Action Menu Panel (floating, staggered animation, neo-3D) ───────
class _UserActionMenuPanel extends StatefulWidget {
  final List<_UserActionItemData> items;
  // Set only when neither "open fully downward" nor "open fully upward"
  // has enough room in the viewport — constrains the action list to the
  // actual available space and makes it scrollable so every action stays
  // reachable instead of being clipped off-screen. Null (the common case)
  // keeps the previous unconstrained, non-scrolling layout unchanged.
  final double? maxHeight;
  const _UserActionMenuPanel({required this.items, this.maxHeight});
  @override
  State<_UserActionMenuPanel> createState() => _UserActionMenuPanelState();
}

class _UserActionMenuPanelState extends State<_UserActionMenuPanel>
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
    // Same premium neumorphic panel — the only difference is that when
    // [maxHeight] is set (the panel wouldn't otherwise fully fit above or
    // below the trigger), the action list scrolls within that bound
    // instead of overflowing off-screen. When null (the common case),
    // layout is identical to before.
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

// ─── Suspend User Dialog ──────────────────────────────────────────────────────
class _SuspendUserDialog extends StatefulWidget {
  final UserModel user;
  final WidgetRef ref;
  final ScaffoldMessengerState? messenger;
  const _SuspendUserDialog(
      {required this.user, required this.ref, this.messenger});
  @override
  State<_SuspendUserDialog> createState() => _SuspendUserDialogState();
}

class _SuspendUserDialogState extends State<_SuspendUserDialog> {
  int _selectedDays = 3; // default: 3 Days

  static const List<_SuspendOption> _options = [
    _SuspendOption(days: 1, label: '1 Day'),
    _SuspendOption(days: 3, label: '3 Days'),
    _SuspendOption(days: 7, label: '7 Days'),
    _SuspendOption(days: 14, label: '14 Days'),
    _SuspendOption(days: 30, label: '1 Month'),
  ];

  DateTime get _suspendUntil =>
      DateTime.now().add(Duration(days: _selectedDays));

  String get _untilLabel {
    final d = _suspendUntil;
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 60),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFFF97316).withOpacity(0.18),
                  blurRadius: 28,
                  offset: const Offset(0, 8))
            ]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: const BoxDecoration(
                color: Color(0xFFFFF7ED),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: Row(children: [
              Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      color: const Color(0xFFF97316).withOpacity(0.12),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.pause_circle_outline_rounded,
                      color: Color(0xFFF97316), size: 22)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Suspend Account',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF9A3412))),
                    Text(widget.user.fullName,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFFEA580C))),
                  ])),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Select suspension duration:',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppAdmin.darkest)),
              const SizedBox(height: 14),
              // Duration chips
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _options.map((opt) {
                    final selected = _selectedDays == opt.days;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedDays = opt.days),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFF97316)
                                : const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: selected
                                    ? const Color(0xFFF97316)
                                    : const Color(0xFFFED7AA),
                                width: 1.5)),
                        child: Text(opt.label,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFFEA580C))),
                      ),
                    );
                  }).toList()),
              const SizedBox(height: 14),
              // Until info
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFED7AA))),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 16, color: Color(0xFFEA580C)),
                  const SizedBox(width: 8),
                  Text('Account will be suspended until $_untilLabel',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9A3412),
                          fontWeight: FontWeight.w600)),
                ]),
              ),
              const SizedBox(height: 18),
            ]),
          ),
          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(children: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel',
                      style: TextStyle(
                          color: AppAdmin.dark, fontWeight: FontWeight.w700))),
              const Spacer(),
              ElevatedButton(
                  onPressed: () {
                    final msg =
                        widget.messenger ?? ScaffoldMessenger.of(context);
                    final untilStr = _untilLabel;
                    final userName = widget.user.fullName;
                    widget.ref
                        .read(adminUsersProvider.notifier)
                        .suspendUser(widget.user.id, _suspendUntil);
                    Navigator.of(context).pop();
                    msg.showSnackBar(SnackBar(
                        content: Text('$userName suspended until $untilStr'),
                        backgroundColor: const Color(0xFFF97316),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))));
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF97316),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: const Text('Suspend',
                      style: TextStyle(fontWeight: FontWeight.w700))),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─── Suspend User BottomSheet (avoids Dialog layout crash on web) ─────────────
class _SuspendUserSheet extends StatefulWidget {
  final UserModel user;
  final WidgetRef ref;
  final ScaffoldMessengerState? messenger;
  const _SuspendUserSheet(
      {required this.user, required this.ref, this.messenger});
  @override
  State<_SuspendUserSheet> createState() => _SuspendUserSheetState();
}

class _SuspendUserSheetState extends State<_SuspendUserSheet> {
  int _selectedDays = 3;
  bool _saving = false;
  static const List<_SuspendOption> _options = [
    _SuspendOption(days: 1, label: '1 Day'),
    _SuspendOption(days: 3, label: '3 Days'),
    _SuspendOption(days: 7, label: '7 Days'),
    _SuspendOption(days: 14, label: '14 Days'),
    _SuspendOption(days: 30, label: '1 Month'),
  ];
  DateTime get _suspendUntil =>
      DateTime.now().add(Duration(days: _selectedDays));
  String get _untilLabel {
    final d = _suspendUntil;
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return _AdminUserModalShell(
      icon: Icons.pause_circle_outline_rounded,
      title: 'Suspend Account',
      subtitle: widget.user.fullName,
      accentColor: const Color(0xFFF97316),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Select suspension duration:',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppAdmin.darkest,
                letterSpacing: 0.3)),
        const SizedBox(height: 14),
        // Premium 3D duration chips — neumorphic surface + colored shadow
        // when selected, same active-state language as the role stepper
        // bar / Admin Orders stepper bar.
        Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _options.map((opt) {
              final selected = opt.days == _selectedDays;
              return GestureDetector(
                onTap: () => setState(() => _selectedDays = opt.days),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: selected
                        ? const LinearGradient(
                            colors: [Color(0xFFF97316), Color(0xFF9A3412)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight)
                        : null,
                    color: selected ? null : AppAdmin.surfaceTint,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                                color: const Color(0xFFF97316).withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 4)),
                            const BoxShadow(
                                color: Color(0xFF9A3412),
                                blurRadius: 0,
                                offset: Offset(0, 2)),
                          ]
                        : const [
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
                  child: Text(opt.label,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : AppAdmin.inkMid)),
                ),
              );
            }).toList()),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFED7AA))),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded,
                size: 16, color: Color(0xFFEA580C)),
            const SizedBox(width: 8),
            Expanded(
                child: Text('Account will be suspended until $_untilLabel',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9A3412),
                        fontWeight: FontWeight.w600))),
          ]),
        ),
      ]),
      footer: Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
                foregroundColor: AppAdmin.dark,
                side: BorderSide(color: AppAdmin.dark.withOpacity(0.3)),
                minimumSize: const Size(0, 46),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: const Text('Cancel',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _saving ? null : _handleSuspendConfirm,
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    const Color(0xFFF97316).withOpacity(0.6),
                elevation: 0,
                minimumSize: const Size(0, 46),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Suspend',
                    style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  // Awaits the real Firestore write (AdminUsersNotifier.suspendUserFirestore)
  // before closing/showing success, and guards against duplicate submissions
  // while the write is in flight.
  Future<void> _handleSuspendConfirm() async {
    if (_saving) return;
    setState(() => _saving = true);
    final msg = widget.messenger ?? ScaffoldMessenger.of(context);
    final untilStr = _untilLabel;
    final userName = widget.user.fullName;
    final until = _suspendUntil;
    try {
      await widget.ref
          .read(adminUsersProvider.notifier)
          .suspendUserFirestore(widget.user.id, until);
      if (!mounted) return;
      Navigator.of(context).pop();
      msg.showSnackBar(SnackBar(
          content: Text('$userName suspended until $untilStr'),
          backgroundColor: const Color(0xFFF97316),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    } catch (e) {
      debugPrint('[AdminUsers] suspend failed: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      msg.showSnackBar(SnackBar(
          content: const Text('Failed to suspend user. Please try again.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    }
  }
}

class _SuspendOption {
  final int days;
  final String label;
  const _SuspendOption({required this.days, required this.label});
}

// ─── Confirm Action Dialog ─────────────────────────────────────────────────────
class _ConfirmDialog extends StatelessWidget {
  final String title, message, confirmLabel;
  final String cancelLabel;
  final Color confirmColor;
  final IconData icon;
  final VoidCallback onConfirm;
  const _ConfirmDialog(
      {required this.title,
      required this.message,
      required this.confirmLabel,
      this.cancelLabel = 'Cancel',
      required this.confirmColor,
      required this.icon,
      required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return _AdminUserModalShell(
      icon: icon,
      title: title,
      accentColor: confirmColor,
      body: Text(message,
          style: const TextStyle(
              fontSize: 13, color: AppAdmin.inkMid, height: 1.5)),
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
                child: Text(cancelLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700)))),
        const SizedBox(width: 10),
        Expanded(
            child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onConfirm();
                },
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
    );
  }
}

// ─── Warn User Dialog ───────────────────────────────────────────────────────────
// Mirrors the trimmed-message / loading-state / inline-error UX already used
// by other Admin "Warn User" dialogs (e.g. Review Management), but the
// onConfirm callback here actually delivers a real Firestore notification
// (see the 'warn' case above) rather than only updating local state.
class _WarnUserDialog extends StatefulWidget {
  final UserModel user;
  final Future<void> Function(String message) onConfirm;
  const _WarnUserDialog({required this.user, required this.onConfirm});
  @override
  State<_WarnUserDialog> createState() => _WarnUserDialogState();
}

class _WarnUserDialogState extends State<_WarnUserDialog> {
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
        _error = 'Could not send warning. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AdminUserModalShell(
      icon: Icons.warning_amber_rounded,
      title: 'Warn User',
      subtitle: widget.user.fullName,
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
            color: AppAdmin.surfaceTint,
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
            decoration: InputDecoration(
              hintText: 'Enter warning message…',
              hintStyle:
                  const TextStyle(color: AppAdmin.inkLight, fontSize: 13),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
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

// ─── Checking Active Orders (brief, non-dismissible) ───────────────────────────
class _CheckingOrdersDialog extends StatelessWidget {
  const _CheckingOrdersDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: AppAdmin.dark)),
          const SizedBox(width: 16),
          const Text('Checking active orders...',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppAdmin.darkest)),
        ]),
      ),
    );
  }
}

// ─── Active Orders Warning (blocks the Block confirmation) ────────────────────
class _ActiveOrdersWarningDialog extends StatelessWidget {
  final UserModel user;
  final List<OrderModel> orders;
  final WidgetRef ref;
  // Stable ancestor context (the Admin Users screen), captured before this
  // dialog opened — used for follow-up navigation after this dialog pops
  // itself, instead of this widget's own about-to-be-removed build context.
  final BuildContext outerContext;
  // Slots into "...before $actionLabel." — shared by Block ("blocking the
  // account") and Delete ("deactivating the account") so both reuse this
  // exact same warning UI/order-matching instead of two definitions.
  final String actionLabel;
  const _ActiveOrdersWarningDialog(
      {required this.user,
      required this.orders,
      required this.ref,
      required this.outerContext,
      this.actionLabel = 'blocking the account'});

  static Color _statusColor(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
        return const Color(0xFFF59E0B);
      case OrderStatus.inProgress:
        return const Color(0xFF0EA5E9);
      case OrderStatus.completed:
        return AppColors.success;
      case OrderStatus.cancelled:
        return AppColors.error;
    }
  }

  static String _statusLabel(OrderStatus s) {
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

  @override
  Widget build(BuildContext context) {
    return _AdminUserModalShell(
      icon: Icons.warning_amber_rounded,
      title: 'Active Orders Must Be Resolved',
      accentColor: const Color(0xFFF97316),
      bodyPadding: EdgeInsets.zero,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
              'This user has ${orders.length} active order${orders.length == 1 ? '' : 's'}. '
              'Resolve or cancel these orders before $actionLabel.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: AppAdmin.inkMid, height: 1.5)),
        ),
        // Order rows — same premium chip/status quality as the redesigned
        // Admin Orders cards (status-tinted badge, Order ID, dates).
        ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _ActiveOrderRow(
            order: orders[i],
            statusColor: _statusColor(orders[i].status),
            statusLabel: _statusLabel(orders[i].status),
            onTap: () {
              Navigator.of(context).pop();
              showAdminOrderDetails(outerContext, orders[i], ref);
            },
          ),
        ),
      ]),
      footer: Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(outerContext).push(
                  MaterialPageRoute(builder: (_) => const AdminOrdersScreen()));
            },
            style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF9A3412),
                side: const BorderSide(color: Color(0xFFFED7AA)),
                minimumSize: const Size(0, 46),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: const Text('View Active Orders',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppAdmin.darkest,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 46),
                padding: EdgeInsets.zero,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: const Text('Close',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

class _ActiveOrderRow extends StatelessWidget {
  final OrderModel order;
  final Color statusColor;
  final String statusLabel;
  final VoidCallback onTap;
  const _ActiveOrderRow(
      {required this.order,
      required this.statusColor,
      required this.statusLabel,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final date = order.serviceDate;
    return Container(
      decoration: BoxDecoration(
        color: AppAdmin.surfaceTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
              color: statusColor.withOpacity(0.14),
              blurRadius: 10,
              offset: const Offset(0, 5)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Top accent bar — same premium treatment as the redesigned
              // Admin Orders cards.
              Container(
                height: 4,
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [statusColor, statusColor.withOpacity(0.35)])),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(
                                order.title.isNotEmpty
                                    ? order.title
                                    : 'Untitled Order',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppAdmin.inkDarkest),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: statusColor.withOpacity(0.3))),
                            child: Text(statusLabel,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: statusColor))),
                      ]),
                      const SizedBox(height: 6),
                      Wrap(spacing: 8, runSpacing: 6, children: [
                        _UserInfoChip(
                            icon: Icons.tag_rounded,
                            label: order.id.length > 10
                                ? order.id.substring(0, 10)
                                : order.id,
                            color: AppAdmin.inkMid),
                        if (order.customerName.isNotEmpty)
                          _UserInfoChip(
                              icon: Icons.person_outline,
                              label: order.customerName,
                              color: AppAdmin.inkMid),
                        if (order.providerName.isNotEmpty)
                          _UserInfoChip(
                              icon: Icons.handyman_outlined,
                              label: order.providerName,
                              color: AppAdmin.inkMid),
                        _UserInfoChip(
                            icon: Icons.event_outlined,
                            label: '${date.day}/${date.month}/${date.year}',
                            color: AppAdmin.inkMid),
                      ]),
                    ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── Deactivate User (soft delete) — strong, type-to-confirm dialog ───────────
class _DeactivateUserDialog extends StatefulWidget {
  final UserModel user;
  final WidgetRef ref;
  final ScaffoldMessengerState messenger;
  const _DeactivateUserDialog(
      {required this.user, required this.ref, required this.messenger});
  @override
  State<_DeactivateUserDialog> createState() => _DeactivateUserDialogState();
}

class _DeactivateUserDialogState extends State<_DeactivateUserDialog> {
  final _confirmCtrl = TextEditingController();
  bool _saving = false;
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _confirmCtrl.addListener(() {
      final ok = _confirmCtrl.text.trim().toUpperCase() == 'DELETE';
      if (ok != _confirmed) setState(() => _confirmed = ok);
    });
  }

  @override
  void dispose() {
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    if (_saving || !_confirmed) return;
    setState(() => _saving = true);
    try {
      await widget.ref
          .read(adminUsersProvider.notifier)
          .softDeleteUser(widget.user.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.messenger.showSnackBar(SnackBar(
          content: Text('${widget.user.fullName} has been deactivated'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    } catch (e) {
      debugPrint('[AdminUsers] soft delete failed: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      widget.messenger.showSnackBar(SnackBar(
          content: const Text('Failed to deactivate user. Please try again.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return _AdminUserModalShell(
      icon: Icons.person_off_rounded,
      title: 'Deactivate User Account',
      subtitle: u.fullName,
      accentColor: AppColors.error,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _DetailRow(
            icon: Icons.person_outline, label: 'Full Name', value: u.fullName),
        _DetailRow(icon: Icons.email_outlined, label: 'Email', value: u.email),
        _DetailRow(
            icon: Icons.badge_outlined,
            label: 'Role',
            value: _roleLabels[u.role] ?? 'Admin'),
        const SizedBox(height: 8),
        const Text(
            "This will deactivate the user's account. The user "
            'will no longer be able to access the application.',
            style:
                TextStyle(fontSize: 13, color: AppAdmin.inkMid, height: 1.5)),
        const SizedBox(height: 8),
        const Text(
            'Historical orders, reviews, chats, complaints, and '
            'other linked records will be preserved.',
            style:
                TextStyle(fontSize: 13, color: AppAdmin.inkMid, height: 1.5)),
        const SizedBox(height: 8),
        const Text(
            'This action can be reversed from the Deleted users '
            'tab.',
            style: TextStyle(
                fontSize: 13,
                color: AppAdmin.inkMid,
                height: 1.5,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        const Text('Type DELETE to confirm',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppAdmin.darkest)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppAdmin.surfaceTint,
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
            controller: _confirmCtrl,
            enabled: !_saving,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(fontSize: 14, color: AppAdmin.inkDark),
            decoration: const InputDecoration(
              hintText: 'DELETE',
              hintStyle: TextStyle(color: AppAdmin.inkLight),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ),
      ]),
      footer: Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
                foregroundColor: AppAdmin.dark,
                side: const BorderSide(color: AppAdmin.lightest),
                minimumSize: const Size(0, 46),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: const Text('Cancel',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            onPressed: (_confirmed && !_saving) ? _handleConfirm : null,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.error.withOpacity(0.35),
                minimumSize: const Size(0, 46),
                padding: EdgeInsets.zero,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Deactivate Account',
                    style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

// ─── Restore User (undo soft delete) ───────────────────────────────────────────
class _RestoreUserDialog extends StatefulWidget {
  final UserModel user;
  final WidgetRef ref;
  final ScaffoldMessengerState messenger;
  const _RestoreUserDialog(
      {required this.user, required this.ref, required this.messenger});
  @override
  State<_RestoreUserDialog> createState() => _RestoreUserDialogState();
}

class _RestoreUserDialogState extends State<_RestoreUserDialog> {
  bool _saving = false;

  Future<void> _handleConfirm() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.ref
          .read(adminUsersProvider.notifier)
          .restoreDeletedUser(widget.user.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.messenger.showSnackBar(SnackBar(
          content: Text('${widget.user.fullName} has been restored'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    } catch (e) {
      debugPrint('[AdminUsers] restore failed: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      widget.messenger.showSnackBar(SnackBar(
          content: const Text('Failed to restore user. Please try again.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return _AdminUserModalShell(
      icon: Icons.restore_rounded,
      title: 'Restore User Account',
      subtitle: u.fullName,
      accentColor: AppColors.success,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(u.email,
            style: const TextStyle(fontSize: 12, color: AppAdmin.inkLight)),
        const SizedBox(height: 10),
        Text(
            'This account will be restored and allowed to access the '
            'app again according to its remaining status — if it is '
            'still Blocked or Suspended, that restriction stays in '
            'effect.',
            style: const TextStyle(
                fontSize: 13, color: AppAdmin.inkMid, height: 1.5)),
      ]),
      footer: Row(children: [
        Expanded(
            child: OutlinedButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
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
                onPressed: _saving ? null : _handleConfirm,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 46),
                    padding: EdgeInsets.zero,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Restore User',
                        style: TextStyle(fontWeight: FontWeight.w700)))),
      ]),
    );
  }
}

// ─── User Details Dialog ──────────────────────────────────────────────────────
class _UserDetailsDialog extends StatefulWidget {
  final UserModel user;
  final WidgetRef ref;
  const _UserDetailsDialog({required this.user, required this.ref});
  @override
  State<_UserDetailsDialog> createState() => _UserDetailsDialogState();
}

class _UserDetailsDialogState extends State<_UserDetailsDialog> {
  late UserModel _user;
  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  bool get _isContractor => _user.role == UserRole.contractor;

  @override
  Widget build(BuildContext context) {
    final blocked = widget.ref.watch(blockedUsersProvider);
    final isBlocked = blocked.contains(_user.id);
    final isDeleted = _user.isDeleted;
    // Priority: Deleted > Blocked > Actively Suspended > Active.
    final isSuspended = !isBlocked && !isDeleted && _user.isActivelySuspended;
    final color = _roleColors[_user.role]!;

    // Outer presentation only — same standardized bottom-sheet shell as
    // every other Admin Users secondary flow (slide up, dimmed backdrop,
    // rounded top corners, drag handle, max width). The header/body/footer
    // content below is unchanged from the previous redesign pass.
    return Padding(
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
              // Header — same premium dark-gradient + drop-shadow language as
              // the Admin Orders / Admin Users page headers. Keeps the Admin
              // lilac identity here (role coloring lives on the list cards —
              // see _UserCard), only switching to red when the account is
              // blocked, unchanged from before.
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: isBlocked
                          ? [const Color(0xFF991B1B), const Color(0xFFB91C1C)]
                          : [
                              AppAdmin.inkDarkest,
                              AppAdmin.darkest,
                              AppAdmin.dark
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  boxShadow: [
                    BoxShadow(
                        color: (isBlocked
                                ? const Color(0xFF991B1B)
                                : AppAdmin.darkest)
                            .withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 6)),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
                child: Row(children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                        color: isBlocked
                            ? Colors.red.withOpacity(0.25)
                            : color.withOpacity(0.25),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withOpacity(0.3), width: 2),
                        boxShadow: [
                          BoxShadow(
                              color: (isBlocked ? Colors.red : color)
                                  .withOpacity(0.45),
                              blurRadius: 12,
                              offset: const Offset(0, 4)),
                        ]),
                    child: ProfileAvatarImage(
                      imageUrl: _user.avatar,
                      size: 52,
                      fallbackText:
                          _user.fullName.isNotEmpty ? _user.fullName : '?',
                      fallbackTextStyle: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(_user.fullName,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        const SizedBox(height: 5),
                        Row(children: [
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                  color: isBlocked
                                      ? Colors.red.withOpacity(0.3)
                                      : color.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.3))),
                              child: Text(_roleLabels[_user.role]!,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white))),
                          if (isDeleted) ...[
                            const SizedBox(width: 6),
                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20)),
                                child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.no_accounts_rounded,
                                          size: 10, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text('Deactivated',
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white)),
                                    ])),
                          ] else if (isBlocked) ...[
                            const SizedBox(width: 6),
                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20)),
                                child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.block_rounded,
                                          size: 10, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text('Blocked',
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white)),
                                    ])),
                          ] else if (isSuspended) ...[
                            const SizedBox(width: 6),
                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20)),
                                child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.pause_circle_outline_rounded,
                                          size: 10, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text('Suspended',
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white)),
                                    ])),
                          ],
                        ]),
                      ])),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
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

              // Body
              Flexible(
                  child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _AdminSectionLabel(label: 'Basic Information'),
                      const SizedBox(height: 12),
                      _DetailRow(
                          icon: Icons.person_outline,
                          label: 'Full Name',
                          value: _user.fullName),
                      if (_isContractor &&
                          _user.companyName?.isNotEmpty == true)
                        _DetailRow(
                            icon: Icons.business_outlined,
                            label: 'Company Name',
                            value: _user.companyName!),
                      _DetailRow(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: _user.email),
                      _DetailRow(
                          icon: Icons.phone_outlined,
                          label: 'Phone',
                          value: _user.phone,
                          trailing: _DetailCallButton(phone: _user.phone)),
                      _DetailRow(
                          icon: Icons.badge_outlined,
                          label: 'Role',
                          value: _roleLabels[_user.role]!,
                          valueColor: color),
                      _DetailRow(
                          icon: Icons.fingerprint_rounded,
                          label: 'User ID',
                          value: _user.id,
                          trailing: _user.id.isNotEmpty
                              ? _DetailCopyButton(
                                  value: _user.id, snackText: 'User ID copied.')
                              : null),
                      _DetailRow(
                          icon: isDeleted
                              ? Icons.no_accounts_rounded
                              : isBlocked
                                  ? Icons.block_rounded
                                  : isSuspended
                                      ? Icons.pause_circle_outline_rounded
                                      : Icons.verified_outlined,
                          label: 'Account Status',
                          value: isDeleted
                              ? 'Deactivated'
                              : isBlocked
                                  ? 'Blocked'
                                  : isSuspended
                                      ? 'Suspended until ${_user.suspendedUntil!.day}/${_user.suspendedUntil!.month}/${_user.suspendedUntil!.year}'
                                      : 'Active',
                          valueColor: isDeleted
                              ? AppColors.textSecondary
                              : isBlocked
                                  ? AppColors.error
                                  : isSuspended
                                      ? const Color(0xFFF97316)
                                      : AppColors.success),
                      if (isDeleted && _user.deletedAt != null)
                        _DetailRow(
                            icon: Icons.event_busy_outlined,
                            label: 'Deleted At',
                            value:
                                '${_user.deletedAt!.day}/${_user.deletedAt!.month}/${_user.deletedAt!.year}'),
                      if (_user.role == UserRole.customer)
                        _CustomerDetailsBody(user: _user, ref: widget.ref),
                      if (_user.role == UserRole.professional)
                        _ProfessionalDetailsBody(user: _user, ref: widget.ref),
                      if (_isContractor)
                        _ContractorDetailsBody(user: _user, ref: widget.ref),
                      const SizedBox(height: 8),
                    ]),
              )),

              // Footer
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Row(children: [
                  Expanded(
                      child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: AppAdmin.dark,
                              side: const BorderSide(color: AppAdmin.dark),
                              minimumSize: const Size(0, 46),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12))),
                          child: const Text('Close',
                              style: TextStyle(fontWeight: FontWeight.w700)))),
                  // Edit is hidden for deactivated accounts — they must be
                  // restored first (Admin Users → Restore User) before editing.
                  if (!isDeleted) ...[
                    const SizedBox(width: 12),
                    Expanded(
                        child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              showAdminUserModal(
                                  context: context,
                                  builder: (_) => _EditUserDialog(
                                      user: _user, ref: widget.ref));
                            },
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text('Edit',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppAdmin.darkest,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 46),
                                padding: EdgeInsets.zero,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12))))),
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

// ─── Role-specific detail body helpers ─────────────────────────────────────────

// Parses bio/working-hours/response-time out of the encoded serviceDescription
// string (same "hours:"/"response:" convention used by the real profile
// screens) instead of showing the raw encoded value.
({String bio, String hours, String response}) _parseServiceDescription(
    String? raw) {
  final desc = raw ?? '';
  String bio = '', hours = '', response = '';
  if (desc.contains('hours:')) {
    for (final part in desc.split('|')) {
      final t = part.trim();
      if (t.startsWith('hours:')) {
        hours = t.replaceFirst('hours:', '').trim();
      } else if (t.startsWith('response:')) {
        response = t.replaceFirst('response:', '').trim();
      } else if (t.isNotEmpty) {
        bio = t;
      }
    }
  } else {
    bio = desc;
  }
  return (
    bio: bio.isEmpty ? '—' : bio,
    hours: hours.isEmpty ? '—' : hours,
    response: response.isEmpty ? '—' : response,
  );
}

// Inverse of _parseServiceDescription — re-encodes bio/hours/response back
// into the same "hours:"/"response:" convention the real Professional and
// Contractor profile screens already write, so admin-saved edits stay
// readable by the exact same parsing logic used everywhere else. Returns
// null (not '') when all three are empty, matching serviceDescription's
// nullable-field convention.
String? _buildServiceDescription(String bio, String hours, String response) {
  final joined = [
    if (bio.trim().isNotEmpty) bio.trim(),
    if (hours.trim().isNotEmpty) 'hours: ${hours.trim()}',
    if (response.trim().isNotEmpty) 'response: ${response.trim()}',
  ].join(' | ');
  return joined.isEmpty ? null : joined;
}

// Resolves a specialty/category key to a display label: prefers the hardcoded
// dictionary, falls back to the live Firestore categories list (so categories
// added later still resolve), then prettifies the raw key as a last resort.
String _resolveCategoryLabel(String key, List<CategoryModel> categories) {
  if (key.isEmpty) return '—';
  final known = _categoryLabels[key];
  if (known != null) return known;
  final match = categories.where((c) => c.nameKey == key);
  final resolvedKey = match.isNotEmpty ? match.first.nameKey : key;
  return resolvedKey
      .split('_')
      .where((w) => w.isNotEmpty)
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

// ─── Customer Details Body ──────────────────────────────────────────────────
class _CustomerDetailsBody extends StatelessWidget {
  final UserModel user;
  final WidgetRef ref;
  const _CustomerDetailsBody({required this.user, required this.ref});

  @override
  Widget build(BuildContext context) {
    final orders = ref
        .watch(ordersProvider)
        .where(
            (o) => o.customerId == user.id || o.customerName == user.fullName)
        .toList();
    final total = orders.length;
    final completed =
        orders.where((o) => o.status == OrderStatus.completed).length;
    final inProgress =
        orders.where((o) => o.status == OrderStatus.inProgress).length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 16),
      const _AdminSectionLabel(label: 'Personal Information'),
      const SizedBox(height: 12),
      _DetailRow(
          icon: Icons.location_on_outlined,
          label: 'Full Address',
          value: user.fullAddress.isNotEmpty ? user.fullAddress : '—'),
      _DetailRow(
          icon: Icons.language_outlined,
          label: 'Languages',
          value: user.languages.isNotEmpty ? user.languages.join(' • ') : '—'),
      _DetailRow(
          icon: Icons.access_time_outlined,
          label: 'Best Contact Hours',
          value: user.preferredContactHours.isNotEmpty
              ? user.preferredContactHours.join(' • ')
              : '—'),
      _DetailRow(
          icon: Icons.star_outline_rounded,
          label: 'Favorite Services',
          value: user.favoriteServices.isNotEmpty
              ? user.favoriteServices.join(' • ')
              : '—'),
      _DetailRow(
          icon: Icons.calendar_today_outlined,
          label: 'Member Since',
          value:
              '${user.joinDate.day}/${user.joinDate.month}/${user.joinDate.year}'),
      const SizedBox(height: 16),
      const _AdminSectionLabel(label: 'Customer Statistics'),
      const SizedBox(height: 12),
      _StatTilesGrid(tiles: [
        _StatTileData(
            icon: Icons.receipt_long_rounded,
            value: '$total',
            label: 'Total Orders'),
        _StatTileData(
            icon: Icons.check_circle_outline_rounded,
            value: '$completed',
            label: 'Completed'),
        _StatTileData(
            icon: Icons.autorenew_rounded,
            value: '$inProgress',
            label: 'In Progress'),
      ]),
    ]);
  }
}

// ─── Work Information Section (Professional & Contractor) ──────────────────
class _WorkInfoSection extends StatelessWidget {
  final UserModel user;
  const _WorkInfoSection({required this.user});

  String get _mapsAddress {
    final parts = <String>[];
    if (user.workArea?.isNotEmpty == true) parts.add(user.workArea!);
    if (user.streetNumber.isNotEmpty) parts.add('Street ${user.streetNumber}');
    if (user.city.isNotEmpty) parts.add(user.city);
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final hasAddress = _mapsAddress.isNotEmpty;
    final parsed = _parseServiceDescription(user.serviceDescription);
    final cityAddress = [
      if (user.city.isNotEmpty) user.city,
      if (user.streetNumber.isNotEmpty) 'Street ${user.streetNumber}',
    ].join(', ');

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _AdminSectionLabel(label: 'Work Information'),
      const SizedBox(height: 12),
      _DetailRow(
          icon: Icons.map_outlined,
          label: 'Work Area',
          value: user.workArea?.isNotEmpty == true ? user.workArea! : '—'),
      _DetailRow(
          icon: Icons.location_city_outlined,
          label: 'City / Address',
          value: cityAddress.isNotEmpty ? cityAddress : '—'),
      _DetailRow(
          icon: Icons.work_history_outlined,
          label: 'Experience',
          value: user.experienceYears != null
              ? '${user.experienceYears} years'
              : '—'),
      _DetailRow(
          icon: Icons.language_outlined,
          label: 'Languages',
          value: user.languages.isNotEmpty ? user.languages.join(' • ') : '—'),
      _DetailRow(
          icon: Icons.access_time_rounded,
          label: 'Working Hours',
          value: parsed.hours),
      _DetailRow(
          icon: Icons.timer_outlined,
          label: 'Avg. Response Time',
          value: parsed.response),
      const SizedBox(height: 4),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppAdmin.warm,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppAdmin.lightest)),
        child: Text(parsed.bio,
            style: const TextStyle(
                fontSize: 13, color: AppAdmin.darkest, height: 1.5)),
      ),
      const SizedBox(height: 10),
      SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: hasAddress ? () => _openInMaps(_mapsAddress) : null,
            icon: const Icon(Icons.map_rounded, size: 16),
            label: const Text('Open in Google Maps',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
                backgroundColor:
                    hasAddress ? const Color(0xFF1A73E8) : Colors.grey.shade300,
                foregroundColor:
                    hasAddress ? Colors.white : Colors.grey.shade600,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
          )),
      if (!hasAddress)
        const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('No address available.',
                style: TextStyle(fontSize: 11, color: AppAdmin.mid))),
    ]);
  }
}

// ─── Specialties Section (Professional & Contractor) ────────────────────────
class _SpecialtiesSection extends StatelessWidget {
  final UserModel user;
  final List<CategoryModel> categories;
  const _SpecialtiesSection({required this.user, required this.categories});

  @override
  Widget build(BuildContext context) {
    final specialties = user.specialties.isNotEmpty
        ? user.specialties
        : (user.specialty != null && user.specialty!.isNotEmpty
            ? [user.specialty!]
            : const <String>[]);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _AdminSectionLabel(label: 'Specialties'),
      const SizedBox(height: 12),
      specialties.isEmpty
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: AppAdmin.warm,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppAdmin.lightest)),
              child: const Center(
                  child: Text('—',
                      style: TextStyle(color: AppAdmin.mid, fontSize: 13))),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: specialties.map((key) {
                final label = _resolveCategoryLabel(key, categories);
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                      color: AppAdmin.warm,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppAdmin.lightest)),
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppAdmin.darkest)),
                );
              }).toList()),
    ]);
  }
}

// ─── Services & Prices Section (Professional & Contractor) ─────────────────
class _ServicesSection extends StatelessWidget {
  final List<ServiceModel> services;
  const _ServicesSection({required this.services});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _AdminSectionLabel(label: 'Services & Prices'),
      const SizedBox(height: 12),
      if (services.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppAdmin.warm,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppAdmin.lightest)),
          child: const Center(
              child: Text('No services added.',
                  style: TextStyle(color: AppAdmin.mid, fontSize: 13))),
        )
      else
        ...services.map((s) => _ServiceReadRow(service: s)),
    ]);
  }
}

class _ServiceReadRow extends StatelessWidget {
  final ServiceModel service;
  const _ServiceReadRow({required this.service});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppAdmin.warm,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppAdmin.lightest)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(service.name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppAdmin.darkest)),
                if (service.description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(service.description,
                      style:
                          const TextStyle(fontSize: 11, color: AppAdmin.mid)),
                ],
              ])),
          const SizedBox(width: 8),
          Text('₪${service.price.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppAdmin.dark)),
        ]),
      );
}

// ─── Profile Statistics Section (Professional & Contractor) ────────────────
class _ProfileStatsSection extends StatelessWidget {
  final double avgRating;
  final int reviewsCount;
  final int totalOrders;
  final int completedOrders;
  final int completionRate;
  final int experienceYears;
  const _ProfileStatsSection({
    required this.avgRating,
    required this.reviewsCount,
    required this.totalOrders,
    required this.completedOrders,
    required this.completionRate,
    required this.experienceYears,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _AdminSectionLabel(label: 'Profile Statistics'),
      const SizedBox(height: 12),
      _StatTilesGrid(tiles: [
        _StatTileData(
            icon: Icons.star_rounded,
            value: avgRating > 0 ? avgRating.toStringAsFixed(1) : '—',
            label: 'Avg. Rating'),
        _StatTileData(
            icon: Icons.reviews_outlined,
            value: '$reviewsCount',
            label: 'Reviews'),
        _StatTileData(
            icon: Icons.receipt_long_rounded,
            value: '$totalOrders',
            label: 'Total Orders'),
        _StatTileData(
            icon: Icons.check_circle_outline_rounded,
            value: '$completedOrders',
            label: 'Completed'),
        _StatTileData(
            icon: Icons.trending_up_rounded,
            value: '$completionRate%',
            label: 'Completion Rate'),
        _StatTileData(
            icon: Icons.work_history_outlined,
            value: '$experienceYears',
            label: 'Exp. Years'),
      ]),
    ]);
  }
}

class _StatTileData {
  final IconData icon;
  final String value;
  final String label;
  const _StatTileData(
      {required this.icon, required this.value, required this.label});
}

class _StatTilesGrid extends StatelessWidget {
  final List<_StatTileData> tiles;
  const _StatTilesGrid({required this.tiles});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      const spacing = 10.0;
      const columns = 3;
      final tileWidth =
          (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: tiles
            .map((t) => SizedBox(width: tileWidth, child: _StatTile(data: t)))
            .toList(),
      );
    });
  }
}

class _StatTile extends StatelessWidget {
  final _StatTileData data;
  const _StatTile({required this.data});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
            color: AppAdmin.warm,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppAdmin.lightest)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(data.icon, size: 18, color: AppAdmin.dark),
          const SizedBox(height: 6),
          Text(data.value,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppAdmin.darkest)),
          const SizedBox(height: 2),
          Text(data.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 10,
                  color: AppAdmin.mid,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

// ─── Ratings Summary Section (Professional only) ────────────────────────────
class _RatingsSummarySection extends StatelessWidget {
  final double avgRating;
  final int reviewsCount;
  final double speed;
  final double quality;
  final double communication;
  const _RatingsSummarySection({
    required this.avgRating,
    required this.reviewsCount,
    required this.speed,
    required this.quality,
    required this.communication,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _AdminSectionLabel(label: 'Ratings Summary'),
      const SizedBox(height: 12),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppAdmin.warm,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppAdmin.lightest)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text(avgRating.toStringAsFixed(1),
                style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: AppAdmin.darkest)),
            Row(
                children: List.generate(
                    5,
                    (i) => Icon(
                        i < avgRating.round()
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: const Color(0xFFFFCA28),
                        size: 13))),
            const SizedBox(height: 4),
            Text('$reviewsCount reviews',
                style: const TextStyle(fontSize: 10, color: AppAdmin.mid)),
          ]),
          const SizedBox(width: 18),
          Expanded(
              child: Column(children: [
            _RatingBarRow(label: 'Speed', value: speed),
            const SizedBox(height: 8),
            _RatingBarRow(label: 'Quality', value: quality),
            const SizedBox(height: 8),
            _RatingBarRow(label: 'Communication', value: communication),
          ])),
        ]),
      ),
    ]);
  }
}

class _RatingBarRow extends StatelessWidget {
  final String label;
  final double value;
  const _RatingBarRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(
            width: 92,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppAdmin.dark,
                    fontWeight: FontWeight.w600))),
        Expanded(
            child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                    value: (value / 5).clamp(0, 1),
                    minHeight: 8,
                    backgroundColor: AppAdmin.lightest,
                    color: AppAdmin.dark))),
        const SizedBox(width: 8),
        Text(value.toStringAsFixed(1),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppAdmin.darkest)),
      ]);
}

// ─── Workers / Team Section (Contractor) ────────────────────────────────────
class _WorkersTeamSection extends StatelessWidget {
  final UserModel contractor;
  final WidgetRef ref;
  const _WorkersTeamSection({required this.contractor, required this.ref});

  @override
  Widget build(BuildContext context) {
    final workersAsync =
        ref.watch(contractorWorkersByIdProvider(contractor.id));
    final workers = workersAsync.valueOrNull ?? const <WorkerModel>[];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: _AdminSectionLabel(label: 'Workers / Team')),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: AppAdmin.lightest,
                borderRadius: BorderRadius.circular(20)),
            child: Text('${workers.length} workers',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppAdmin.dark))),
      ]),
      const SizedBox(height: 12),
      if (workersAsync.isLoading && workers.isEmpty)
        const Center(
            child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator()))
      else if (workers.isEmpty)
        Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: AppAdmin.warm,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppAdmin.lightest)),
            child: const Center(
                child: Text('No workers added yet.',
                    style: TextStyle(color: AppAdmin.mid, fontSize: 13))))
      else
        ...workers.map((w) =>
            _WorkerReadCard(worker: w, contractor: contractor, ref: ref)),
    ]);
  }
}

Color _workerStatusColor(WorkerStatus status) {
  switch (status) {
    case WorkerStatus.available:
      return AppColors.success;
    case WorkerStatus.busy:
      return const Color(0xFFF59E0B);
    case WorkerStatus.offline:
      return const Color(0xFF9CA3AF);
  }
}

String _workerStatusLabel(WorkerStatus status) {
  switch (status) {
    case WorkerStatus.available:
      return 'Available';
    case WorkerStatus.busy:
      return 'Busy';
    case WorkerStatus.offline:
      return 'Offline';
  }
}

class _WorkerReadCard extends StatelessWidget {
  final WorkerModel worker;
  final UserModel contractor;
  final WidgetRef ref;
  const _WorkerReadCard(
      {required this.worker, required this.contractor, required this.ref});

  @override
  Widget build(BuildContext context) {
    final sc = _workerStatusColor(worker.status);
    final statusLabel = _workerStatusLabel(worker.status);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showAdminUserModal(
            context: context,
            builder: (_) => _AdminWorkerDetailsDialog(
                worker: worker, contractor: contractor, ref: ref)),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: AppAdmin.warm,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppAdmin.lightest)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: AppAdmin.lightest,
                    borderRadius: BorderRadius.circular(12)),
                child: Center(
                    child: Text(worker.name.isNotEmpty ? worker.name[0] : '?',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppAdmin.dark)))),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Expanded(
                        child: Text(worker.name,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppAdmin.darkest))),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                            color: sc.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(statusLabel,
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: sc))),
                  ]),
                  const SizedBox(height: 3),
                  Text(worker.specialty.isNotEmpty ? worker.specialty : '—',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppAdmin.dark,
                          fontWeight: FontWeight.w600)),
                  if (worker.phone?.isNotEmpty == true) ...[
                    const SizedBox(height: 3),
                    Row(children: [
                      const Icon(Icons.phone_outlined,
                          size: 11, color: AppAdmin.mid),
                      const SizedBox(width: 4),
                      Text(worker.phone!,
                          style: const TextStyle(
                              fontSize: 11, color: AppAdmin.mid))
                    ]),
                  ],
                  if (worker.city?.isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.map_outlined,
                          size: 11, color: AppAdmin.mid),
                      const SizedBox(width: 4),
                      Text(worker.city!,
                          style: const TextStyle(
                              fontSize: 11, color: AppAdmin.mid))
                    ]),
                  ],
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.work_history_outlined,
                        size: 11, color: AppAdmin.mid),
                    const SizedBox(width: 4),
                    Text('${worker.yearsExperience} yrs',
                        style:
                            const TextStyle(fontSize: 11, color: AppAdmin.mid)),
                    const SizedBox(width: 10),
                    const Icon(Icons.star_rounded,
                        size: 12, color: Color(0xFFFFCA28)),
                    const SizedBox(width: 3),
                    Text(worker.rating.toStringAsFixed(1),
                        style:
                            const TextStyle(fontSize: 11, color: AppAdmin.mid)),
                  ]),
                ])),
          ]),
        ),
      ),
    );
  }
}

// ─── Admin Worker Details Dialog ────────────────────────────────────────────
class _AdminWorkerDetailsDialog extends StatelessWidget {
  final WorkerModel worker;
  final UserModel contractor;
  final WidgetRef ref;
  const _AdminWorkerDetailsDialog(
      {required this.worker, required this.contractor, required this.ref});

  bool get _ownershipOk =>
      worker.contractorId == null || worker.contractorId == contractor.id;

  // Same precedence as WorkerModel.fromFirestore/the Contractor Worker form:
  // the specialties list first, falling back to the legacy single specialty
  // field only when the list is empty. Matched against ALL live, active
  // categoriesProvider categories (not restricted to the parent contractor's
  // current specialty set — a contractor may have since removed a specialty
  // that was already assigned to this worker) by normalized nameKey/id —
  // reusing the same _resolveCategoriesFromKeysAdmin helper the Edit Worker
  // dialog already uses. An invalid/deleted/inactive stored value simply
  // resolves to nothing here — never a raw nameKey, never an "(Unavailable)"
  // placeholder.
  List<CategoryModel> _resolvedSpecialties(List<CategoryModel> categories) {
    final raw = worker.specialties.isNotEmpty
        ? worker.specialties
        : (worker.specialty.isNotEmpty ? [worker.specialty] : const <String>[]);
    return _resolveCategoriesFromKeysAdmin(categories, raw);
  }

  Widget _specialtyChip(CategoryModel cat, List<CategoryModel> categories) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: AppAdmin.lightest, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(cat.icon, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 5),
          Text(_resolveCategoryLabel(cat.nameKey, categories),
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppAdmin.darkest)),
        ]),
      );

  // Mirrors _DetailRow's icon/label layout, but renders the value as a Wrap
  // of chips (every resolved specialty shown — no "+N more" truncation)
  // instead of a single Text value.
  Widget _specialtiesDetailRow(
          List<CategoryModel> resolved, List<CategoryModel> allCategories) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: AppAdmin.lightest,
                  borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.build_outlined,
                  size: 16, color: AppAdmin.dark)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Specialties',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppAdmin.dark,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                if (resolved.isEmpty)
                  const Text('—',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppAdmin.darkest))
                else
                  Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: resolved
                          .map((c) => _specialtyChip(c, allCategories))
                          .toList()),
              ])),
        ]),
      );

  // Same matching rule as the already-proven
  // contractor_suppliers_screen.dart WorkerProfileScreen._isAssignedToWorker:
  // prefer the multi-worker assignedWorkers snapshot list, falling back to
  // the legacy single assignedWorkerId only when that list is empty.
  static bool _isAssignedToWorker(OrderModel order, String workerId) =>
      order.assignedWorkers.isNotEmpty
          ? order.assignedWorkers.any((w) => w.id == workerId)
          : order.assignedWorkerId == workerId;

  @override
  Widget build(BuildContext context) {
    final sc = _workerStatusColor(worker.status);
    final statusLabel = _workerStatusLabel(worker.status);
    final contractorName = contractor.companyName?.isNotEmpty == true
        ? contractor.companyName!
        : contractor.fullName;

    final categories =
        ref.watch(categoriesProvider).valueOrNull ?? const <CategoryModel>[];
    final resolvedSpecialties = _resolvedSpecialties(categories);
    final canonicalLanguages = canonicalizeLanguages(worker.languages);
    final hoursLabel = worker.effectiveWorkingHoursLabel;

    // Live job counters from the existing Admin all-orders stream (no new
    // Firestore query) — falls back to the stored WorkerModel counters while
    // orders are loading/unavailable, and is never written back anywhere.
    final ordersAsync = ref.watch(adminFirestoreOrdersProvider);
    final liveOrders = ordersAsync.valueOrNull;
    final int completedJobs;
    final int currentJobs;
    if (liveOrders != null) {
      completedJobs = liveOrders
          .where((o) =>
              o.status == OrderStatus.completed &&
              _isAssignedToWorker(o, worker.id))
          .length;
      currentJobs = liveOrders
          .where((o) =>
              o.status == OrderStatus.inProgress &&
              _isAssignedToWorker(o, worker.id))
          .length;
    } else {
      completedJobs = worker.totalJobs;
      currentJobs = worker.currentJobs;
    }

    // Same standardized bottom-sheet shell as every other Admin Users
    // secondary flow. Header/body/footer content below is unchanged.
    return Padding(
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
              // Header — same dark-gradient-banner + drop-shadow language as
              // User Details / Edit User.
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [
                    AppAdmin.inkDarkest,
                    AppAdmin.darkest,
                    AppAdmin.dark
                  ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  boxShadow: [
                    BoxShadow(
                        color: Color(0x59321143),
                        blurRadius: 14,
                        offset: Offset(0, 6)),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
                child: Row(children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withOpacity(0.3), width: 2),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4)),
                        ]),
                    child: Center(
                        child: Text(
                            worker.name.isNotEmpty ? worker.name[0] : '?',
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(worker.name,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        const SizedBox(height: 5),
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                                color: sc.withOpacity(0.35),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.3))),
                            child: Text(statusLabel,
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white))),
                      ])),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
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

              // Body
              Flexible(
                  child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _AdminSectionLabel(label: 'Basic Information'),
                      const SizedBox(height: 12),
                      _DetailRow(
                          icon: Icons.person_outline,
                          label: 'Full Name',
                          value: worker.name.isNotEmpty ? worker.name : '—'),
                      _specialtiesDetailRow(resolvedSpecialties, categories),
                      _DetailRow(
                          icon: Icons.phone_outlined,
                          label: 'Phone',
                          value: worker.phone?.isNotEmpty == true
                              ? worker.phone!
                              : '—'),
                      _DetailRow(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: worker.email?.isNotEmpty == true
                              ? worker.email!
                              : '—'),
                      _DetailRow(
                          icon: Icons.map_outlined,
                          label: 'Work Area',
                          value: worker.workArea?.isNotEmpty == true
                              ? worker.workArea!
                              : (worker.city?.isNotEmpty == true
                                  ? worker.city!
                                  : '—')),
                      _DetailRow(
                          icon: Icons.workspace_premium_outlined,
                          label: 'Experience',
                          value: '${worker.yearsExperience} years'),
                      _DetailRow(
                          icon: Icons.schedule_outlined,
                          label: 'Working Hours',
                          value: hoursLabel != null && hoursLabel.isNotEmpty
                              ? hoursLabel
                              : '—'),
                      _DetailRow(
                          icon: Icons.language_outlined,
                          label: 'Languages',
                          value: canonicalLanguages.isNotEmpty
                              ? canonicalLanguages.join(' • ')
                              : '—'),
                      _DetailRow(
                          icon: Icons.star_border_rounded,
                          label: 'Skills',
                          value: worker.skills.isNotEmpty
                              ? worker.skills.join(' • ')
                              : '—'),
                      _DetailRow(
                          icon: Icons.description_outlined,
                          label: 'Description',
                          value: worker.description?.isNotEmpty == true
                              ? worker.description!
                              : '—'),
                      const SizedBox(height: 16),
                      const _AdminSectionLabel(label: 'Performance'),
                      const SizedBox(height: 12),
                      _DetailRow(
                          icon: Icons.task_alt_rounded,
                          label: 'Completed Jobs',
                          value: '$completedJobs'),
                      _DetailRow(
                          icon: Icons.work_outline_rounded,
                          label: 'Current Jobs',
                          value: '$currentJobs'),
                      const SizedBox(height: 16),
                      const _AdminSectionLabel(label: 'Contractor'),
                      const SizedBox(height: 12),
                      _DetailRow(
                          icon: Icons.business_outlined,
                          label: 'Contractor Name',
                          value: contractorName),
                      const SizedBox(height: 8),
                    ]),
              )),

              // Footer
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Row(children: [
                  Expanded(
                      child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: AppAdmin.dark,
                              side: const BorderSide(color: AppAdmin.dark),
                              minimumSize: const Size(0, 46),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12))),
                          child: const Text('Close',
                              style: TextStyle(fontWeight: FontWeight.w700)))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: ElevatedButton.icon(
                          onPressed: () {
                            if (!_ownershipOk) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content: const Text(
                                    'This worker does not belong to this contractor.'),
                                backgroundColor: AppColors.error,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ));
                              return;
                            }
                            Navigator.pop(context);
                            showAdminUserModal(
                                context: context,
                                builder: (_) => _AdminEditWorkerDialog(
                                    worker: worker,
                                    contractor: contractor,
                                    ref: ref));
                          },
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Edit Worker',
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
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Worker specialty resolution helpers (Admin Edit Worker) ─────────────────
// Small Admin-local mirror of contractor_suppliers_screen.dart's private
// _resolveCategoriesFromRaw/_resolveContractorSpecialtyCategories, kept as a
// separate copy (rather than importing that file's private logic) so the
// real Contractor Add/Edit Worker form is never touched by this change.
List<CategoryModel> _resolveCategoriesFromKeysAdmin(
    List<CategoryModel> categories, List<String> rawValues) {
  final normalized = rawValues
      .map((s) => s.trim().toLowerCase())
      .where((s) => s.isNotEmpty)
      .toSet();
  if (normalized.isEmpty) return const [];
  return categories.where((c) {
    final normId = c.id.trim().toLowerCase();
    final normName = c.nameKey.trim().toLowerCase();
    return normalized.contains(normId) || normalized.contains(normName);
  }).toList();
}

/// The parent contractor's own valid (live, active) specialty categories —
/// the only specialty options ever offered when editing one of their
/// workers. Always resolved from the [contractor] UserModel passed down from
/// the Admin Users list/detail dialog — never the currently authenticated
/// Admin's own data.
List<CategoryModel> _resolveContractorSpecialtyCategoriesAdmin(
    List<CategoryModel> activeCategories, UserModel contractor) {
  final raw = contractor.specialties.isNotEmpty
      ? contractor.specialties
      : (contractor.specialty != null
          ? [contractor.specialty!]
          : const <String>[]);
  return _resolveCategoriesFromKeysAdmin(activeCategories, raw);
}

// ─── Admin Edit Worker Dialog ───────────────────────────────────────────────
class _AdminEditWorkerDialog extends StatefulWidget {
  final WorkerModel worker;
  final UserModel contractor;
  final WidgetRef ref;
  const _AdminEditWorkerDialog(
      {required this.worker, required this.contractor, required this.ref});

  @override
  State<_AdminEditWorkerDialog> createState() => _AdminEditWorkerDialogState();
}

class _AdminEditWorkerDialogState extends State<_AdminEditWorkerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl,
      _phoneCtrl,
      _emailCtrl,
      _yearsCtrl,
      _skillsCtrl,
      _descCtrl;
  final _workAreaKey = GlobalKey<WorkAreaFieldState>();
  final _hoursKey = GlobalKey<WorkingHoursFieldState>();
  final _languagesKey = GlobalKey<LanguagesFieldState>();
  late WorkerStatus _status;
  bool _saving = false;
  bool _specialtiesError = false;

  // Specialties are restricted to the parent contractor's own valid, active
  // categories (see _resolveContractorSpecialtyCategoriesAdmin) — never the
  // currently authenticated Admin's data — which requires categoriesProvider
  // to have loaded first. Resolved once, on the first build after
  // categories become available (see build()), then mutated only via chip
  // taps — never re-resolved afterwards, so an in-progress edit can never be
  // reset back to its initial selection by an unrelated provider rebuild.
  late final List<String> _rawInitialSpecialties;
  bool _specialtiesInitialized = false;
  Set<String> _selectedSpecialties = <String>{};
  Set<String> _initialSpecialties = <String>{};

  @override
  void initState() {
    super.initState();
    final w = widget.worker;
    _nameCtrl = TextEditingController(text: w.name);
    _phoneCtrl = TextEditingController(text: w.phone ?? '');
    _emailCtrl = TextEditingController(text: w.email ?? '');
    _yearsCtrl = TextEditingController(text: w.yearsExperience.toString());
    _skillsCtrl = TextEditingController(text: w.skills.join(', '));
    _descCtrl = TextEditingController(text: w.description ?? '');
    _status = w.status;
    // Same precedence as WorkerModel.fromFirestore /
    // contractor_suppliers_screen.dart's _showWorkerForm: the specialties
    // list first, falling back to the legacy single specialty field only
    // when the list is empty.
    _rawInitialSpecialties = w.specialties.isNotEmpty
        ? w.specialties
        : (w.specialty.isNotEmpty ? [w.specialty] : const <String>[]);
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _phoneCtrl,
      _emailCtrl,
      _yearsCtrl,
      _skillsCtrl,
      _descCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  static List<String> _splitCsv(String raw) =>
      raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _setEquals(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  static String _statusToFirestore(WorkerStatus s) {
    switch (s) {
      case WorkerStatus.available:
        return 'available';
      case WorkerStatus.busy:
        return 'busy';
      case WorkerStatus.offline:
        return 'offline';
    }
  }

  void _snack(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: color ?? AppAdmin.dark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // Deterministic order: eligible categories in their existing display order
  // (categoriesProvider order) — same convention already used by
  // AuthNotifier.saveSpecialties and the real Contractor Add/Edit Worker
  // form.
  List<String> _deterministicSelectedSpecialties(
          List<CategoryModel> eligibleCategories) =>
      eligibleCategories
          .where((c) => _selectedSpecialties.contains(c.nameKey))
          .map((c) => c.nameKey)
          .toList();

  Future<void> _handleSave(List<CategoryModel> eligibleCategories) async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    // Same requirement as the real Contractor Add/Edit Worker form: a
    // worker must always keep at least one valid specialty, and specialties
    // can only ever come from the parent contractor's own eligible
    // categories.
    if (eligibleCategories.isEmpty || _selectedSpecialties.isEmpty) {
      setState(() => _specialtiesError = true);
      return;
    }
    final hoursValue = _hoursKey.currentState!.validate();
    if (hoursValue == null) return;

    final original = widget.worker;

    // Defensive ownership check — the worker must belong to the contractor
    // whose Admin details are currently open. contractorId is never sent
    // to Firestore as part of `changes` below, so it can never be altered
    // by this flow either way.
    if (original.contractorId != null &&
        original.contractorId != widget.contractor.id) {
      _snack('This worker does not belong to this contractor.',
          color: AppColors.error);
      return;
    }

    final changes = <String, dynamic>{};

    final newName = _nameCtrl.text.trim();
    if (newName != original.name) changes['fullName'] = newName;

    if (!_setEquals(_selectedSpecialties, _initialSpecialties)) {
      final orderedSpecialties =
          _deterministicSelectedSpecialties(eligibleCategories);
      // Written together so the legacy 'specialty' field can never go stale
      // relative to 'specialties' — same backward-compatible convention as
      // the real Contractor Add/Edit Worker form.
      changes['specialties'] = orderedSpecialties;
      changes['specialty'] = orderedSpecialties.first;
    }

    final newPhone = _phoneCtrl.text.trim();
    if (newPhone != (original.phone ?? '')) changes['phone'] = newPhone;

    final newEmail = _emailCtrl.text.trim();
    if (newEmail != (original.email ?? '')) changes['email'] = newEmail;

    final workAreaValue = _workAreaKey.currentState!.value;
    if (workAreaValue != (original.workArea ?? original.city ?? '')) {
      // city and workArea are always written together (see
      // WorkerModel.toFirestoreMap) — keep them in sync here too.
      changes['city'] = workAreaValue;
      changes['workArea'] = workAreaValue;
    }

    final newYears = int.tryParse(_yearsCtrl.text.trim()) ?? 0;
    if (newYears != original.yearsExperience) {
      changes['experienceYears'] = newYears;
    }

    final hoursParts = splitWorkingHoursRange(hoursValue);
    if (hoursValue != (original.workHours ?? '') ||
        hoursParts?[0] != (original.workStartTime ?? '') ||
        hoursParts?[1] != (original.workEndTime ?? '')) {
      // workHours (compact legacy label) and workStartTime/workEndTime are
      // always written together, same as contractor_suppliers_screen.dart's
      // _showWorkerForm.
      changes['workHours'] = hoursValue;
      changes['workStartTime'] = hoursParts?[0];
      changes['workEndTime'] = hoursParts?[1];
    }

    final newLanguages = _languagesKey.currentState!.value;
    if (!_listEquals(newLanguages, original.languages)) {
      changes['languages'] = newLanguages;
    }

    final newSkills = _splitCsv(_skillsCtrl.text);
    if (!_listEquals(newSkills, original.skills)) {
      changes['skills'] = newSkills;
    }

    final newDescription = _descCtrl.text.trim();
    if (newDescription != (original.description ?? '')) {
      changes['description'] = newDescription;
    }

    if (_status != original.status) {
      changes['status'] = _statusToFirestore(_status);
    }

    if (changes.isEmpty) {
      _snack('No changes to save');
      return;
    }

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ContractorWorkersService.updateFields(original.id, changes);

      // Best-effort: createWorkerUpdateNotification never throws (errors
      // are caught and logged internally), so a notification failure can
      // never land in this catch block and falsely report the worker save
      // itself as failed.
      final admin = widget.ref.read(authProvider);
      await createWorkerUpdateNotification(
        contractorId: widget.contractor.id,
        workerName: newName,
        createdById: admin?.id,
        createdByName: admin?.fullName,
      );

      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(SnackBar(
        content: const Text('Worker updated successfully'),
        backgroundColor: AppAdmin.dark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } catch (e) {
      debugPrint('[AdminEditWorker] Firestore update failed: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(
        content: const Text('Failed to save changes. Please try again.'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  // Same premium neumorphic input language as _EditUserDialogState._neoField
  // — mirrored locally (that method is private to a different State class)
  // rather than sharing, since both are small/local to this file already.
  Widget _neoField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppAdmin.surfaceTint,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: AppAdmin.borderSoft, blurRadius: 6, offset: Offset(3, 3)),
          BoxShadow(color: Colors.white, blurRadius: 6, offset: Offset(-3, -3)),
        ],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(fontSize: 14, color: AppAdmin.inkDark),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
              color: AppAdmin.inkMid,
              fontSize: 13,
              fontWeight: FontWeight.w600),
          prefixIcon: Icon(icon, color: AppAdmin.inkMid, size: 18),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _statusChip(WorkerStatus value, String label) {
    final selected = _status == value;
    final color = _workerStatusColor(value);
    return Expanded(
      child: GestureDetector(
        onTap: _saving ? null : () => setState(() => _status = value),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: selected ? color.withOpacity(0.15) : AppAdmin.warm,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: selected ? color : AppAdmin.lightest,
                  width: selected ? 1.5 : 1)),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? color : AppAdmin.mid)),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppAdmin.dark)),
      );

  Widget _specialtyChip(CategoryModel cat) {
    final selected = _selectedSpecialties.contains(cat.nameKey);
    return InkWell(
      onTap: _saving
          ? null
          : () => setState(() {
                if (selected) {
                  _selectedSpecialties.remove(cat.nameKey);
                } else {
                  _selectedSpecialties.add(cat.nameKey);
                }
                if (_selectedSpecialties.isNotEmpty) _specialtiesError = false;
              }),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
            color: selected ? AppAdmin.darkest : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? AppAdmin.darkest : AppAdmin.lightest,
                width: 1.3)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(cat.icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          if (selected) ...[
            const Icon(Icons.check_rounded, size: 14, color: Colors.white),
            const SizedBox(width: 5),
          ],
          Text(_resolveCategoryLabel(cat.nameKey, const []),
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppAdmin.dark)),
        ]),
      ),
    );
  }

  // Specialty options are restricted to the parent contractor's own valid,
  // active categories (never every system category, never the Admin's own
  // data) — see _resolveContractorSpecialtyCategoriesAdmin. Loading/error
  // states replace the whole section so an Admin can never toggle — and
  // therefore never save — a specialty that hasn't actually been validated
  // against the contractor's live categories.
  Widget _buildWorkerSpecialtiesSection({
    required bool loading,
    required bool hasError,
    required List<CategoryModel> eligibleCategories,
  }) {
    if (loading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
            color: AppAdmin.warm,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppAdmin.lightest, width: 1.5)),
        child: const Row(children: [
          SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 10),
          Text('Loading categories...',
              style: TextStyle(fontSize: 13, color: AppAdmin.mid)),
        ]),
      );
    }
    if (hasError) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3))),
        child: Row(children: [
          const Expanded(
              child: Text('Failed to load categories',
                  style: TextStyle(fontSize: 13, color: AppColors.error))),
          TextButton.icon(
              onPressed: () => widget.ref.invalidate(categoriesProvider),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry')),
        ]),
      );
    }
    if (eligibleCategories.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
            color: AppAdmin.warm,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppAdmin.lightest)),
        child: const Text(
            'This contractor has no valid specialties configured yet. '
            'Worker specialties cannot be edited until the contractor\'s '
            'own profile has at least one active specialty.',
            style: TextStyle(fontSize: 12.5, color: AppAdmin.mid, height: 1.4)),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(
          spacing: 8,
          runSpacing: 8,
          children: eligibleCategories.map(_specialtyChip).toList()),
      if (_specialtiesError)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('Select at least one specialty',
              style: TextStyle(fontSize: 12, color: AppColors.error)),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = widget.ref.watch(categoriesProvider);
    final categoriesLoading =
        categoriesAsync.isLoading && !categoriesAsync.hasValue;
    final categoriesHasError =
        categoriesAsync.hasError && !categoriesAsync.hasValue;
    final allCategories =
        categoriesAsync.valueOrNull ?? const <CategoryModel>[];
    final eligibleCategories = _resolveContractorSpecialtyCategoriesAdmin(
        allCategories, widget.contractor);

    if (!_specialtiesInitialized && categoriesAsync.hasValue) {
      final resolved = _resolveCategoriesFromKeysAdmin(
              eligibleCategories, _rawInitialSpecialties)
          .map((c) => c.nameKey)
          .toSet();
      _selectedSpecialties = Set<String>.from(resolved);
      _initialSpecialties = Set<String>.from(resolved);
      _specialtiesInitialized = true;
    }

    // Same standardized bottom-sheet shell as every other Admin Users
    // secondary flow.
    return Padding(
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
                decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [
                      AppAdmin.inkDarkest,
                      AppAdmin.darkest,
                      AppAdmin.dark
                    ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    boxShadow: [
                      BoxShadow(
                          color: Color(0x59321143),
                          blurRadius: 14,
                          offset: Offset(0, 6)),
                    ]),
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                child: Row(children: [
                  Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.edit_outlined,
                          color: Colors.white, size: 20)),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text('Edit Worker',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        Text(widget.worker.name,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70)),
                      ])),
                  GestureDetector(
                    onTap: _saving ? null : () => Navigator.pop(context),
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
                child: Form(
                    key: _formKey,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _AdminSectionLabel(label: 'Basic Information'),
                          const SizedBox(height: 12),
                          _neoField(
                              controller: _nameCtrl,
                              label: 'Full Name',
                              icon: Icons.person_outline,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Required'
                                  : null),
                          const SizedBox(height: 16),
                          _fieldLabel('Specialties'),
                          _buildWorkerSpecialtiesSection(
                              loading: categoriesLoading,
                              hasError: categoriesHasError,
                              eligibleCategories: eligibleCategories),
                          const SizedBox(height: 12),
                          _neoField(
                              controller: _phoneCtrl,
                              label: 'Phone',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone),
                          const SizedBox(height: 12),
                          _neoField(
                              controller: _emailCtrl,
                              label: 'Email',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress),
                          const SizedBox(height: 20),
                          const _AdminSectionLabel(label: 'Work Details'),
                          const SizedBox(height: 12),
                          _fieldLabel('Work Area'),
                          WorkAreaField(
                              key: _workAreaKey,
                              initialValue: widget.worker.workArea ??
                                  widget.worker.city ??
                                  '',
                              accentColor: AppAdmin.dark),
                          const SizedBox(height: 14),
                          _neoField(
                              controller: _yearsCtrl,
                              label: 'Experience (years)',
                              icon: Icons.workspace_premium_outlined,
                              keyboardType: TextInputType.number),
                          const SizedBox(height: 14),
                          _fieldLabel('Start Time / End Time'),
                          WorkingHoursField(
                              key: _hoursKey,
                              initialRange:
                                  widget.worker.effectiveWorkingHoursLabel ??
                                      '',
                              accentColor: AppAdmin.dark),
                          const SizedBox(height: 14),
                          _fieldLabel('Languages'),
                          LanguagesField(
                              key: _languagesKey,
                              initialValue: widget.worker.languages,
                              accentColor: AppAdmin.dark),
                          const SizedBox(height: 12),
                          _neoField(
                              controller: _skillsCtrl,
                              label: 'Skills (comma separated)',
                              icon: Icons.star_border_rounded),
                          const SizedBox(height: 12),
                          _neoField(
                              controller: _descCtrl,
                              maxLines: 3,
                              label: 'Description',
                              icon: Icons.description_outlined),
                          const SizedBox(height: 20),
                          const _AdminSectionLabel(label: 'Availability'),
                          const SizedBox(height: 12),
                          Row(children: [
                            _statusChip(WorkerStatus.available, 'Available'),
                            _statusChip(WorkerStatus.busy, 'Busy'),
                            _statusChip(WorkerStatus.offline, 'Offline'),
                          ]),
                          const SizedBox(height: 8),
                        ])),
              )),
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Row(children: [
                    Expanded(
                        child: OutlinedButton(
                            onPressed:
                                _saving ? null : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: AppAdmin.dark,
                                side: const BorderSide(color: AppAdmin.dark),
                                minimumSize: const Size(0, 48),
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12))),
                            child: const Text('Cancel',
                                style:
                                    TextStyle(fontWeight: FontWeight.w700)))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: ElevatedButton.icon(
                            onPressed: (_saving || categoriesLoading)
                                ? null
                                : () => _handleSave(eligibleCategories),
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.save_outlined, size: 16),
                            label: Text(_saving ? 'Saving...' : 'Save Changes',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppAdmin.darkest,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    AppAdmin.darkest.withOpacity(0.6),
                                minimumSize: const Size(0, 48),
                                padding: EdgeInsets.zero,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12))))),
                  ])),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── Professional Details Body ──────────────────────────────────────────────
class _ProfessionalDetailsBody extends StatelessWidget {
  final UserModel user;
  final WidgetRef ref;
  const _ProfessionalDetailsBody({required this.user, required this.ref});

  @override
  Widget build(BuildContext context) {
    final orders = ref
        .watch(ordersProvider)
        .where((o) => o.providerId == user.id)
        .toList();
    final completed =
        orders.where((o) => o.status == OrderStatus.completed).length;
    final completionRate =
        orders.isEmpty ? 0 : ((completed / orders.length) * 100).round();
    final reviews = ref.watch(providerReviewsProvider(user.id)).valueOrNull ??
        const <ReviewModel>[];
    final avgRating = reviews.isEmpty
        ? 0.0
        : reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
    final avgSpeed = reviews.isEmpty
        ? 0.0
        : reviews.map((r) => r.speedRating).reduce((a, b) => a + b) /
            reviews.length;
    final avgQuality = reviews.isEmpty
        ? 0.0
        : reviews.map((r) => r.qualityRating).reduce((a, b) => a + b) /
            reviews.length;
    final avgComm = reviews.isEmpty
        ? 0.0
        : reviews.map((r) => r.communicationRating).reduce((a, b) => a + b) /
            reviews.length;
    final categories =
        ref.watch(categoriesProvider).valueOrNull ?? const <CategoryModel>[];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 16),
      _WorkInfoSection(user: user),
      const SizedBox(height: 16),
      _SpecialtiesSection(user: user, categories: categories),
      const SizedBox(height: 16),
      _ServicesSection(services: user.servicesList),
      const SizedBox(height: 16),
      _ProfileStatsSection(
          avgRating: avgRating,
          reviewsCount: reviews.length,
          totalOrders: orders.length,
          completedOrders: completed,
          completionRate: completionRate,
          experienceYears: user.experienceYears ?? 0),
      const SizedBox(height: 16),
      _RatingsSummarySection(
          avgRating: avgRating,
          reviewsCount: reviews.length,
          speed: avgSpeed,
          quality: avgQuality,
          communication: avgComm),
    ]);
  }
}

// ─── Contractor Details Body ────────────────────────────────────────────────
class _ContractorDetailsBody extends StatelessWidget {
  final UserModel user;
  final WidgetRef ref;
  const _ContractorDetailsBody({required this.user, required this.ref});

  @override
  Widget build(BuildContext context) {
    final orders = ref
        .watch(ordersProvider)
        .where((o) => o.providerId == user.id)
        .toList();
    final completed =
        orders.where((o) => o.status == OrderStatus.completed).length;
    final completionRate =
        orders.isEmpty ? 0 : ((completed / orders.length) * 100).round();
    final reviews = ref.watch(providerReviewsProvider(user.id)).valueOrNull ??
        const <ReviewModel>[];
    final avgRating = reviews.isEmpty
        ? 0.0
        : reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
    final categories =
        ref.watch(categoriesProvider).valueOrNull ?? const <CategoryModel>[];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 16),
      _WorkInfoSection(user: user),
      const SizedBox(height: 16),
      _SpecialtiesSection(user: user, categories: categories),
      const SizedBox(height: 16),
      _ServicesSection(services: user.servicesList),
      const SizedBox(height: 16),
      _ProfileStatsSection(
          avgRating: avgRating,
          reviewsCount: reviews.length,
          totalOrders: orders.length,
          completedOrders: completed,
          completionRate: completionRate,
          experienceYears: user.experienceYears ?? 0),
      const SizedBox(height: 16),
      _WorkersTeamSection(contractor: user, ref: ref),
    ]);
  }
}

// ─── Edit User Dialog ─────────────────────────────────────────────────────────
class _EditUserDialog extends StatefulWidget {
  final UserModel user;
  final WidgetRef ref;
  const _EditUserDialog({required this.user, required this.ref});
  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl,
      _phoneCtrl,
      _cityCtrl,
      _streetCtrl,
      _companyCtrl,
      _experienceCtrl,
      _bioCtrl;
  // Structured Professional/Contractor fields — same shared widgets/state
  // shape as the real profile edit forms (professional_home_screen.dart
  // _showEditFullProfile / contractor_profile_screen.dart _editBasicInfo),
  // instead of the previous free-text/CSV controllers.
  final _workAreaKey = GlobalKey<WorkAreaFieldState>();
  final _hoursKey = GlobalKey<WorkingHoursFieldState>();
  final _workingDaysKey = GlobalKey<WorkingDaysFieldState>();
  final _responseKey = GlobalKey<ResponseTimeFieldState>();
  final _languagesKey = GlobalKey<LanguagesFieldState>();
  // Parsed once from the original serviceDescription in initState, purely to
  // preload ResponseTimeField — never written back verbatim (Save always
  // rebuilds serviceDescription fresh from the live field values).
  late final String _initialResponse;
  late List<String> _selectedContactHours;
  late final List<String> _initialContactHours;
  // Favorite Services (Customer) — raw stored values are captured here
  // unresolved; _favoriteServices/_initialFavoriteServices are only ever
  // populated from live, active categoriesProvider matches the first time
  // categories become available (see _buildFavoriteServicesSection), so an
  // invalid/deleted/inactive stored value can never be displayed, reselected,
  // or written back.
  late final List<String> _rawInitialFavoriteServices;
  bool _favoritesResolved = false;
  List<String> _favoriteServices = <String>[];
  List<String> _initialFavoriteServices = <String>[];
  // Professional/Contractor Specialties — same lazy-resolve pattern: raw
  // stored values captured unresolved, then matched against live, active
  // categoriesProvider categories only (by normalized nameKey/id) the first
  // time categories become available (see _buildCategoriesSection). Neither
  // _selectedSpecialties nor _initialSpecialties can ever contain a value
  // that isn't a live category's nameKey.
  late final List<String> _rawInitialSpecialties;
  bool _specialtiesResolved = false;
  Set<String> _selectedSpecialties = <String>{};
  Set<String> _initialSpecialties = <String>{};
  late List<ServiceModel> _services;
  bool _saving = false;

  static bool _setEquals(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  // Deterministic order: live categories in their existing categoriesProvider
  // display order. _selectedSpecialties only ever contains nameKeys resolved
  // against live categories (see _buildCategoriesSection), so there is never
  // an invalid/legacy leftover to append — an invalid/deleted/inactive
  // stored value is simply absent from the result.
  List<String> _deterministicSpecialtiesList(List<CategoryModel> categories) =>
      categories
          .where((c) => _selectedSpecialties.contains(c.nameKey))
          .map((c) => c.nameKey)
          .toList();

  // Primary 'specialty': keep the user's original primary if it's still
  // among the selected (live) categories, otherwise fall back to the first
  // selected value in the same deterministic display order — matching
  // AuthNotifier.saveSpecialties' "first of list, or null" convention
  // applied to a stable order.
  String? _computePrimarySpecialty(List<CategoryModel> categories) {
    if (_selectedSpecialties.isEmpty) return null;
    final originalPrimary = widget.user.specialty;
    if (originalPrimary != null &&
        originalPrimary.isNotEmpty &&
        _selectedSpecialties.contains(originalPrimary)) {
      return originalPrimary;
    }
    for (final cat in categories) {
      if (_selectedSpecialties.contains(cat.nameKey)) return cat.nameKey;
    }
    // Unreachable in practice — every element of _selectedSpecialties is
    // resolved from `categories` in the first place — but fall back to a
    // deterministic pick from the current (already-valid) selection rather
    // than inventing anything, since it's known non-empty here.
    final sorted = _selectedSpecialties.toList()..sort();
    return sorted.first;
  }

  Widget _categoryChip(
      {required String label,
      required bool selected,
      required VoidCallback? onTap,
      String? icon,
      bool dimmed = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
            color: selected ? AppAdmin.darkest : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? AppAdmin.darkest : AppAdmin.lightest,
                width: 1.3)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
          ],
          if (selected) ...[
            const Icon(Icons.check_rounded, size: 14, color: Colors.white),
            const SizedBox(width: 5),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Colors.white
                      : (dimmed
                          ? AppAdmin.mid.withValues(alpha: 0.5)
                          : AppAdmin.dark))),
        ]),
      ),
    );
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppAdmin.dark)),
      );

  // Preferred Contact Hours — same option list (kPreferredContactHourOptions,
  // including 'Any Time') and the same selection rule
  // (togglePreferredContactHour: 'Any Time' is exclusive with the specific
  // periods) as the real Customer Profile edit sheet, so admin edits can't
  // produce a combination the customer's own screen would reject.
  Widget _buildContactHoursSection() => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: kPreferredContactHourOptions.map((opt) {
        final selected = _selectedContactHours.contains(opt);
        return _categoryChip(
            label: opt,
            selected: selected,
            onTap: () => setState(() {
                  _selectedContactHours =
                      togglePreferredContactHour(_selectedContactHours, opt);
                }));
      }).toList());

  // Favorite Services — categoriesProvider-driven, same max-3 rule and
  // haptic-ignore-when-full feedback as the real Customer Profile edit sheet
  // (customer_profile_screen.dart _EditProfileSheetState). Canonical stored
  // value is the resolved category label (matching what that screen itself
  // saves — it stores `l.get(category.nameKey)`, and Admin's English-only UI
  // renders/saves the same resolved label via _resolveCategoryLabel).
  // Existing stored values are matched by normalized label, nameKey, or id
  // the first time categories become available; anything that matches no
  // live category is dropped from _favoriteServices entirely — never shown,
  // never reselected, never written back.
  Widget _buildFavoriteServicesSection() {
    final categoriesAsync = widget.ref.watch(categoriesProvider);

    if (categoriesAsync.isLoading && !categoriesAsync.hasValue) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
            color: AppAdmin.warm,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppAdmin.lightest, width: 1.5)),
        child: const Row(children: [
          SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 10),
          Text('Loading services...',
              style: TextStyle(fontSize: 13, color: AppAdmin.mid)),
        ]),
      );
    }

    if (categoriesAsync.hasError && !categoriesAsync.hasValue) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3))),
        child: Row(children: [
          const Expanded(
              child: Text('Failed to load services',
                  style: TextStyle(fontSize: 13, color: AppColors.error))),
          TextButton.icon(
              onPressed: () => widget.ref.invalidate(categoriesProvider),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry')),
        ]),
      );
    }

    final categories = categoriesAsync.value ?? const <CategoryModel>[];
    bool normEq(String a, String b) =>
        a.trim().toLowerCase() == b.trim().toLowerCase();
    String labelFor(CategoryModel c) =>
        _resolveCategoryLabel(c.nameKey, categories);

    if (!_favoritesResolved) {
      final resolved = <String>[];
      for (final raw in _rawInitialFavoriteServices) {
        final match = categories.where((c) =>
            normEq(raw, labelFor(c)) ||
            normEq(raw, c.nameKey) ||
            normEq(raw, c.id));
        if (match.isNotEmpty) {
          final label = labelFor(match.first);
          if (!resolved.contains(label)) resolved.add(label);
        }
      }
      _favoriteServices = resolved;
      _initialFavoriteServices = List<String>.from(resolved);
      _favoritesResolved = true;
    }

    final atMax = _favoriteServices.length >= 3;
    final chips = categories.map((c) {
      final selected = _favoriteServices.any((v) => normEq(v, labelFor(c)));
      return _categoryChip(
        label: labelFor(c),
        icon: c.icon,
        selected: selected,
        dimmed: atMax && !selected,
        onTap: () => setState(() {
          if (selected) {
            _favoriteServices.removeWhere((v) => normEq(v, labelFor(c)));
          } else if (_favoriteServices.length < 3) {
            _favoriteServices.add(labelFor(c));
          } else {
            HapticFeedback.heavyImpact();
          }
        }),
      );
    }).toList();

    if (categories.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
            color: AppAdmin.warm,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppAdmin.lightest)),
        child: const Text('No services available.',
            style: TextStyle(fontSize: 13, color: AppAdmin.mid)),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppAdmin.warm,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppAdmin.lightest, width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.star_outline_rounded,
              size: 16, color: AppAdmin.dark),
          const SizedBox(width: 8),
          const Expanded(
              child: Text('Favorite Services',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppAdmin.dark))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: atMax
                    ? AppColors.success.withValues(alpha: 0.12)
                    : AppAdmin.lightest,
                borderRadius: BorderRadius.circular(10)),
            child: Text(
                atMax
                    ? 'Max selected (${_favoriteServices.length}/3)'
                    : 'Pick up to 3 (${_favoriteServices.length}/3)',
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: atMax ? AppColors.success : AppAdmin.dark)),
          ),
        ]),
        const SizedBox(height: 10),
        if (chips.isEmpty)
          const Text('No services available.',
              style: TextStyle(fontSize: 12, color: AppAdmin.mid))
        else
          Wrap(spacing: 8, runSpacing: 8, children: chips),
      ]),
    );
  }

  // Categories are 100% Firestore-driven (categoriesProvider) — the old
  // static dictionary is never a source of selectable options.
  // _resolveCategoryLabel is still reused purely for display (it already
  // knows how to prettify well-known keys like 'ac_technician' -> 'AC
  // Technician' and gracefully falls back for unknown ones).
  //
  // Loading/error states replace the whole section (rather than silently
  // falling back to a static list), so an Admin can never toggle — and
  // therefore never save — a category value that hasn't actually been
  // validated against live Firestore data. Only categories that are
  // currently live and active are ever shown or selectable; an
  // invalid/deleted/inactive stored value is resolved out entirely the
  // first time categories load (see the one-time resolve below) and can
  // never be displayed, reselected, or written back.
  Widget _buildCategoriesSection() {
    final categoriesAsync = widget.ref.watch(categoriesProvider);

    if (categoriesAsync.isLoading && !categoriesAsync.hasValue) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
            color: AppAdmin.warm,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppAdmin.lightest, width: 1.5)),
        child: const Row(children: [
          SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 10),
          Text('Loading categories...',
              style: TextStyle(fontSize: 13, color: AppAdmin.mid)),
        ]),
      );
    }

    if (categoriesAsync.hasError && !categoriesAsync.hasValue) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.error.withOpacity(0.3))),
        child: Row(children: [
          const Expanded(
              child: Text('Failed to load categories',
                  style: TextStyle(fontSize: 13, color: AppColors.error))),
          TextButton.icon(
              onPressed: () => widget.ref.invalidate(categoriesProvider),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry')),
        ]),
      );
    }

    final categories = categoriesAsync.value ?? const <CategoryModel>[];

    if (!_specialtiesResolved) {
      final normalized = _rawInitialSpecialties
          .map((s) => s.trim().toLowerCase())
          .where((s) => s.isNotEmpty)
          .toSet();
      final resolved = categories
          .where((c) =>
              normalized.contains(c.nameKey.trim().toLowerCase()) ||
              normalized.contains(c.id.trim().toLowerCase()))
          .map((c) => c.nameKey)
          .toSet();
      _selectedSpecialties = resolved;
      _initialSpecialties = Set<String>.from(resolved);
      _specialtiesResolved = true;
    }

    if (categories.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
            color: AppAdmin.warm,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppAdmin.lightest)),
        child: const Text('No categories available.',
            style: TextStyle(fontSize: 13, color: AppAdmin.mid)),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppAdmin.warm,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppAdmin.lightest, width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.category_outlined, size: 16, color: AppAdmin.dark),
          SizedBox(width: 8),
          Text('Categories / Specialties',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppAdmin.dark)),
        ]),
        const SizedBox(height: 4),
        Text('Tap to select or remove. Multiple categories can be selected.',
            style:
                TextStyle(fontSize: 11, color: AppAdmin.mid.withOpacity(0.9))),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ...categories.map((cat) {
            final selected = _selectedSpecialties.contains(cat.nameKey);
            return _categoryChip(
                label: _resolveCategoryLabel(cat.nameKey, categories),
                selected: selected,
                onTap: () => setState(() {
                      if (selected) {
                        _selectedSpecialties.remove(cat.nameKey);
                      } else {
                        _selectedSpecialties.add(cat.nameKey);
                      }
                    }));
          }),
        ]),
      ]),
    );
  }

  bool get _isCustomer => widget.user.role == UserRole.customer;
  bool get _isContractor => widget.user.role == UserRole.contractor;
  bool get _isPro =>
      widget.user.role == UserRole.professional ||
      widget.user.role == UserRole.contractor;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _nameCtrl = TextEditingController(text: u.fullName);
    _phoneCtrl = TextEditingController(text: u.phone);
    _cityCtrl = TextEditingController(text: u.city);
    _streetCtrl = TextEditingController(text: u.streetNumber);
    _companyCtrl = TextEditingController(text: u.companyName ?? '');
    _experienceCtrl =
        TextEditingController(text: u.experienceYears?.toString() ?? '');
    // Reuse the Phase 1 serviceDescription parser (same "hours:"/"response:"
    // convention as the real Professional/Contractor profile screens) — it
    // returns '—' placeholders for display, so swap those back to '' for a
    // clean editable prefill. Hours themselves are NOT read from here —
    // WorkingHoursField is preloaded from u.effectiveWorkingHoursLabel below,
    // same as the real edit forms (structured fields win over the legacy
    // description text).
    final parsed = _parseServiceDescription(u.serviceDescription);
    _bioCtrl = TextEditingController(text: parsed.bio == '—' ? '' : parsed.bio);
    _initialResponse = parsed.response == '—' ? '' : parsed.response;
    _selectedContactHours = List<String>.from(u.preferredContactHours);
    _initialContactHours = List<String>.from(_selectedContactHours);
    // Raw, unresolved — _favoriteServices/_initialFavoriteServices are only
    // ever populated from live categoriesProvider matches, in
    // _buildFavoriteServicesSection.
    _rawInitialFavoriteServices = List<String>.from(u.favoriteServices);
    // Priority: specialties list first (real current schema), falling back
    // to the legacy single specialty field only when the list is empty —
    // same precedence the real discovery/matching code already uses. Raw,
    // unresolved — _selectedSpecialties/_initialSpecialties are only ever
    // populated from live categoriesProvider matches, in
    // _buildCategoriesSection.
    _rawInitialSpecialties = u.specialties.isNotEmpty
        ? u.specialties
        : (u.specialty != null && u.specialty!.trim().isNotEmpty
            ? [u.specialty!]
            : const <String>[]);
    _services = List<ServiceModel>.from(u.servicesList);
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _phoneCtrl,
      _cityCtrl,
      _streetCtrl,
      _companyCtrl,
      _experienceCtrl,
      _bioCtrl,
    ]) c.dispose();
    super.dispose();
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _serviceEquals(ServiceModel a, ServiceModel b) =>
      a.id == b.id &&
      a.name == b.name &&
      a.description == b.description &&
      a.price == b.price;

  static bool _servicesEqual(List<ServiceModel> a, List<ServiceModel> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_serviceEquals(a[i], b[i])) return false;
    }
    return true;
  }

  // Add/Edit Service — reuses the exact field set, validation and id
  // convention as the real Professional/Contractor "My Services" screens
  // (ServiceModel.id is stable and generated once as 'svc_<timestamp>', then
  // preserved across edits). Purely local edit-state: no Firestore write
  // happens here, only when Save Changes is pressed on the parent dialog.
  // The form itself lives in _AdminServiceFormDialog, a proper StatefulWidget
  // that owns its own TextEditingControllers (created in its initState,
  // disposed only in its own dispose). This method never touches those
  // controllers — it just awaits the typed result and, once the dialog
  // route has genuinely finished popping, applies it to local edit state.
  Future<void> _showServiceForm({ServiceModel? existing}) async {
    final result = await showAdminUserModal<ServiceModel>(
      context: context,
      builder: (_) => _AdminServiceFormDialog(initialService: existing),
    );

    if (!mounted || result == null) return;
    setState(() {
      if (existing != null) {
        _services =
            _services.map((s) => s.id == existing.id ? result : s).toList();
      } else {
        _services = [..._services, result];
      }
    });
  }

  // Same shared premium modal family as every other Admin Users
  // confirmation — was a plain AlertDialog before.
  Future<void> _confirmRemoveService(ServiceModel s) async {
    bool confirmed = false;
    await showAdminUserModal(
      context: context,
      builder: (dialogCtx) => _ConfirmDialog(
        title: 'Remove Service?',
        message: 'Remove "${s.name}" from this profile?',
        confirmLabel: 'Remove',
        confirmColor: AppColors.error,
        icon: Icons.delete_outline_rounded,
        onConfirm: () => confirmed = true,
      ),
    );
    if (!confirmed || !mounted) return;
    setState(() => _services = _services.where((x) => x.id != s.id).toList());
  }

  Widget _buildServiceCard(ServiceModel s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppAdmin.warm,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppAdmin.lightest)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.name.isNotEmpty ? s.name : '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppAdmin.darkest)),
          if (s.description.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(s.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppAdmin.mid)),
          ],
          const SizedBox(height: 4),
          Text('₪ ${s.price.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppAdmin.dark)),
        ])),
        const SizedBox(width: 6),
        IconButton(
            onPressed: _saving ? null : () => _showServiceForm(existing: s),
            icon:
                const Icon(Icons.edit_outlined, size: 18, color: AppAdmin.dark),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Edit'),
        const SizedBox(width: 10),
        IconButton(
            onPressed: _saving ? null : () => _confirmRemoveService(s),
            icon: const Icon(Icons.delete_outline_rounded,
                size: 18, color: AppColors.error),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Remove'),
      ]),
    );
  }

  void _snack(String message, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: color ?? AppAdmin.dark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _handleSave() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    final original = widget.user;
    final changes = <String, dynamic>{};

    final newName = _nameCtrl.text.trim();
    if (newName != original.fullName) changes['fullName'] = newName;
    final newPhone = _phoneCtrl.text.trim();
    if (newPhone != original.phone) changes['phone'] = newPhone;

    if (_isCustomer) {
      final newCity = _cityCtrl.text.trim();
      if (newCity != original.city) changes['city'] = newCity;
      final newStreet = _streetCtrl.text.trim();
      if (newStreet != original.streetNumber)
        changes['streetNumber'] = newStreet;

      final newLanguages = _languagesKey.currentState!.value;
      if (!_listEquals(newLanguages, original.languages)) {
        changes['languages'] = newLanguages;
      }
      if (!_listEquals(_selectedContactHours, _initialContactHours)) {
        changes['preferredContactHours'] = _selectedContactHours;
      }
      if (!_listEquals(_favoriteServices, _initialFavoriteServices)) {
        changes['favoriteServices'] = _favoriteServices;
      }
    } else {
      // Work Area / Working Hours / Working Days are required structured
      // fields — same validation order as the real Professional/Contractor
      // edit sheets (professional_home_screen.dart _showEditFullProfile /
      // contractor_profile_screen.dart _editBasicInfo): an invalid hours
      // range or zero selected working days blocks Save entirely.
      final hoursValue = _hoursKey.currentState!.validate();
      if (hoursValue == null) return;
      final workingDaysValue = _workingDaysKey.currentState!.validate();
      if (workingDaysValue == null) return;

      // Professional/Contractor's only editable location value is workArea
      // — city is kept synchronized to it, matching
      // AuthNotifier.updateProfessionalProfile/updateContractorProfile.
      final workAreaValue = _workAreaKey.currentState!.value;
      if (workAreaValue != (original.workArea ?? '')) {
        final trimmedWorkArea = workAreaValue.trim();
        final effectiveCity =
            trimmedWorkArea.isNotEmpty ? trimmedWorkArea : original.city.trim();
        changes['workArea'] = workAreaValue;
        changes['city'] = effectiveCity;
      }

      if (!_setEquals(_selectedSpecialties, _initialSpecialties)) {
        final categories = widget.ref.read(categoriesProvider).valueOrNull ??
            const <CategoryModel>[];
        // Write both fields together so they can never go stale relative to
        // each other — exactly like AuthNotifier.saveSpecialties does for
        // the real Professional/Contractor specialty picker.
        changes['specialties'] = _deterministicSpecialtiesList(categories);
        changes['specialty'] = _computePrimarySpecialty(categories);
      }
      final newExperience = int.tryParse(_experienceCtrl.text.trim());
      if (newExperience != original.experienceYears) {
        changes['experienceYears'] = newExperience;
      }
      final newLanguages = _languagesKey.currentState!.value;
      if (!_listEquals(newLanguages, original.languages)) {
        changes['languages'] = newLanguages;
      }

      final hoursParts = splitWorkingHoursRange(hoursValue);
      if (hoursParts?[0] != (original.workStartTime ?? '') ||
          hoursParts?[1] != (original.workEndTime ?? '')) {
        changes['workStartTime'] = hoursParts?[0];
        changes['workEndTime'] = hoursParts?[1];
      }
      if (!_listEquals(workingDaysValue, original.workingDays)) {
        changes['workingDays'] = workingDaysValue;
      }

      // Rebuilt from the full bio/hours/response trio every time, so leaving
      // hours or response untouched while editing only the bio (or vice
      // versa) can never silently drop the other two — see initState prefill.
      final responseValue = _responseKey.currentState!.value;
      final newDesc =
          _buildServiceDescription(_bioCtrl.text, hoursValue, responseValue);
      if (newDesc != original.serviceDescription) {
        changes['serviceDescription'] = newDesc;
      }

      if (_isContractor) {
        final newCompany = _companyCtrl.text.trim();
        if (newCompany != (original.companyName ?? '')) {
          changes['companyName'] = newCompany.isEmpty ? null : newCompany;
        }
      }

      // Services & Prices — same Firestore key/shape as
      // AuthNotifier.saveServicesList (a single 'servicesList' key holding
      // the whole rebuilt list), written only when the list actually
      // changed content, never per-item.
      if (!_servicesEqual(_services, original.servicesList)) {
        changes['servicesList'] = _services.map((s) => s.toMap()).toList();
      }
    }

    if (changes.isEmpty) {
      _snack('No changes to save');
      return;
    }

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await widget.ref
          .read(adminUsersProvider.notifier)
          .updateUserFields(original.id, changes);

      // Best-effort: createProfileUpdateNotification never throws (errors are
      // caught and logged internally), so a notification failure can never
      // land in this catch block and falsely report the profile save itself
      // as failed.
      final admin = widget.ref.read(authProvider);
      await createProfileUpdateNotification(
        userId: original.id,
        createdById: admin?.id,
        createdByName: admin?.fullName,
      );

      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(SnackBar(
        content: const Text('Changes saved successfully'),
        backgroundColor: AppAdmin.dark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } catch (e) {
      debugPrint('[AdminEditUser] Firestore update failed: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(
        content: const Text('Failed to save changes. Please try again.'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  // Same premium neumorphic input language as Admin Orders' _NeoInputField
  // (admin_screens.dart), mirrored locally since that widget is private to
  // that file. Replaces the old flat outlined-border decoration — same
  // controllers, same validators, same keyboardTypes, same save behavior.
  Widget _neoField({
    TextEditingController? controller,
    String? initialValue,
    required String label,
    required IconData icon,
    int maxLines = 1,
    bool readOnly = false,
    bool enabled = true,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    String? helperText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: enabled ? AppAdmin.surfaceTint : AppAdmin.warm,
        borderRadius: BorderRadius.circular(16),
        boxShadow: enabled
            ? const [
                BoxShadow(
                    color: AppAdmin.borderSoft,
                    blurRadius: 6,
                    offset: Offset(3, 3)),
                BoxShadow(
                    color: Colors.white, blurRadius: 6, offset: Offset(-3, -3)),
              ]
            : null,
      ),
      child: TextFormField(
        controller: controller,
        initialValue: controller == null ? initialValue : null,
        readOnly: readOnly,
        enabled: enabled,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(fontSize: 14, color: AppAdmin.inkDark),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
              color: AppAdmin.inkMid,
              fontSize: 13,
              fontWeight: FontWeight.w600),
          prefixIcon: Icon(icon, color: AppAdmin.inkMid, size: 18),
          helperText: helperText,
          helperStyle: const TextStyle(color: AppAdmin.inkLight, fontSize: 11),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Outer presentation only — same standardized bottom-sheet shell as
    // every other Admin Users secondary flow. Header/body/footer content
    // below is unchanged from the previous redesign pass.
    return Padding(
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
              // Header — same premium dark-gradient + drop-shadow language as
              // the User Details dialog / Admin Orders headers.
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [
                    AppAdmin.inkDarkest,
                    AppAdmin.darkest,
                    AppAdmin.dark
                  ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  boxShadow: [
                    BoxShadow(
                        color: Color(0x59321143),
                        blurRadius: 14,
                        offset: Offset(0, 6)),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                child: Row(children: [
                  Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.25))),
                      child: const Icon(Icons.edit_outlined,
                          color: Colors.white, size: 20)),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text('Edit User Data',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        Text(widget.user.fullName,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70)),
                      ])),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
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
                child: Form(
                    key: _formKey,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _AdminSectionLabel(label: 'Basic Information'),
                          const SizedBox(height: 12),
                          _neoField(
                              controller: _nameCtrl,
                              label: 'Full Name',
                              icon: Icons.person_outline,
                              validator: (v) =>
                                  (v == null || v.isEmpty) ? 'Required' : null),
                          const SizedBox(height: 12),
                          // Email is read-only here: it also backs the Firebase
                          // Auth identity, so changing it would need Auth
                          // Admin SDK / Cloud Functions, which is out of scope.
                          _neoField(
                              initialValue: widget.user.email,
                              readOnly: true,
                              enabled: false,
                              label: 'Email (read-only)',
                              icon: Icons.email_outlined,
                              helperText: 'Email cannot be changed here'),
                          const SizedBox(height: 12),
                          // Role is also read-only — changing it is not supported
                          // from this dialog.
                          _DetailRow(
                              icon: Icons.badge_outlined,
                              label: 'Role',
                              value: _roleLabels[widget.user.role] ?? 'Admin'),
                          const SizedBox(height: 4),
                          _neoField(
                              controller: _phoneCtrl,
                              label: 'Phone',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              validator: (v) =>
                                  (v == null || v.isEmpty) ? 'Required' : null),
                          if (_isPro) ...[
                            const SizedBox(height: 20),
                            const _AdminSectionLabel(
                                label: 'Work Area & Address'),
                            const SizedBox(height: 12),
                            _fieldLabel('Work Area'),
                            WorkAreaField(
                                key: _workAreaKey,
                                initialValue:
                                    widget.user.workArea ?? widget.user.city,
                                accentColor: AppAdmin.dark),
                            const SizedBox(height: 14),
                            Row(children: [
                              Expanded(
                                  flex: 2,
                                  child: _neoField(
                                      controller: _cityCtrl,
                                      label: 'City',
                                      icon: Icons.location_city_outlined)),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: _neoField(
                                      controller: _streetCtrl,
                                      label: 'Street No.',
                                      icon: Icons.signpost_outlined,
                                      keyboardType: TextInputType.number)),
                            ]),
                            const SizedBox(height: 12),
                            _neoField(
                                controller: _experienceCtrl,
                                label: 'Experience (years)',
                                icon: Icons.work_history_outlined,
                                keyboardType: TextInputType.number),
                            const SizedBox(height: 14),
                            _fieldLabel('Working Hours'),
                            WorkingHoursField(
                                key: _hoursKey,
                                initialRange:
                                    widget.user.effectiveWorkingHoursLabel,
                                accentColor: AppAdmin.dark),
                            const SizedBox(height: 14),
                            _fieldLabel('Working Days'),
                            WorkingDaysField(
                                key: _workingDaysKey,
                                initialValue: widget.user.effectiveWorkingDays,
                                accentColor: AppAdmin.dark),
                            const SizedBox(height: 14),
                            _fieldLabel('Response Time'),
                            ResponseTimeField(
                                key: _responseKey,
                                initialValue: _initialResponse,
                                accentColor: AppAdmin.dark),
                            const SizedBox(height: 14),
                            _fieldLabel('Languages'),
                            LanguagesField(
                                key: _languagesKey,
                                initialValue: widget.user.languages,
                                accentColor: AppAdmin.dark),
                            const SizedBox(height: 20),
                            const _AdminSectionLabel(
                                label: 'Professional Information'),
                            const SizedBox(height: 12),
                            _buildCategoriesSection(),
                            if (_isContractor) ...[
                              const SizedBox(height: 12),
                              _neoField(
                                  controller: _companyCtrl,
                                  label: 'Company Name (optional)',
                                  icon: Icons.business_outlined),
                            ],
                            const SizedBox(height: 12),
                            _neoField(
                                controller: _bioCtrl,
                                maxLines: 3,
                                label: 'Profile Description / Bio',
                                icon: Icons.notes_rounded),
                            const SizedBox(height: 20),
                            const _AdminSectionLabel(
                                label: 'Services & Prices'),
                            const SizedBox(height: 12),
                            ..._services.map(_buildServiceCard),
                            if (_services.isEmpty)
                              Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                      color: AppAdmin.warm,
                                      borderRadius: BorderRadius.circular(12),
                                      border:
                                          Border.all(color: AppAdmin.lightest)),
                                  child: const Text('No services added yet.',
                                      style: TextStyle(
                                          fontSize: 13, color: AppAdmin.mid))),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                                onPressed:
                                    _saving ? null : () => _showServiceForm(),
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('Add Service'),
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: AppAdmin.dark,
                                    side:
                                        const BorderSide(color: AppAdmin.dark),
                                    minimumSize:
                                        const Size(double.infinity, 44),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)))),
                          ] else ...[
                            const SizedBox(height: 12),
                            _neoField(
                                controller: _cityCtrl,
                                label: 'City',
                                icon: Icons.location_city_outlined,
                                validator: (v) => (v == null || v.isEmpty)
                                    ? 'Required'
                                    : null),
                            const SizedBox(height: 12),
                            _neoField(
                                controller: _streetCtrl,
                                label: 'Street No.',
                                icon: Icons.signpost_outlined,
                                keyboardType: TextInputType.number),
                            const SizedBox(height: 20),
                            const _AdminSectionLabel(
                                label: 'Personal Information'),
                            const SizedBox(height: 12),
                            _fieldLabel('Languages'),
                            LanguagesField(
                                key: _languagesKey,
                                initialValue: widget.user.languages,
                                accentColor: AppAdmin.dark),
                            const SizedBox(height: 16),
                            _fieldLabel('Preferred Contact Hours'),
                            _buildContactHoursSection(),
                            const SizedBox(height: 16),
                            _buildFavoriteServicesSection(),
                          ],
                          const SizedBox(height: 8),
                        ])),
              )),
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Row(children: [
                    Expanded(
                        child: OutlinedButton(
                            onPressed:
                                _saving ? null : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: AppAdmin.dark,
                                side: const BorderSide(color: AppAdmin.dark),
                                minimumSize: const Size(0, 48),
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12))),
                            child: const Text('Cancel',
                                style:
                                    TextStyle(fontWeight: FontWeight.w700)))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: ElevatedButton.icon(
                            onPressed: _saving ? null : _handleSave,
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.save_outlined, size: 16),
                            label: Text(_saving ? 'Saving...' : 'Save Changes',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppAdmin.darkest,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    AppAdmin.darkest.withOpacity(0.6),
                                minimumSize: const Size(0, 48),
                                padding: EdgeInsets.zero,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12))))),
                  ])),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── Admin Service Form Dialog (Add/Edit Service) ──────────────────────────
// Owns its own TextEditingControllers end-to-end: created in initState,
// disposed only in dispose(). Never disposed manually by the caller and
// never disposed right after Navigator.pop — that premature-dispose pattern
// (disposing controllers the instant showDialog's Future resolves, while
// the dialog route is still playing its reverse/exit transition) is what
// previously crashed with "A TextEditingController was used after being
// disposed" plus cascading RenderFlex/_dependents assertions. Purely a
// local form: no Firestore access happens here at all.
class _AdminServiceFormDialog extends StatefulWidget {
  final ServiceModel? initialService;
  const _AdminServiceFormDialog({this.initialService});

  @override
  State<_AdminServiceFormDialog> createState() =>
      _AdminServiceFormDialogState();
}

class _AdminServiceFormDialogState extends State<_AdminServiceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;

  @override
  void initState() {
    super.initState();
    final existing = widget.initialService;
    _nameCtrl = TextEditingController(text: existing?.name ?? '');
    _descCtrl = TextEditingController(text: existing?.description ?? '');
    _priceCtrl = TextEditingController(
        text: existing != null ? existing.price.toStringAsFixed(0) : '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  // Same premium neumorphic input language as _EditUserDialogState._neoField
  // — mirrored locally rather than shared across State classes.
  Widget _neoField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppAdmin.surfaceTint,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: AppAdmin.borderSoft, blurRadius: 6, offset: Offset(3, 3)),
          BoxShadow(color: Colors.white, blurRadius: 6, offset: Offset(-3, -3)),
        ],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(fontSize: 14, color: AppAdmin.inkDark),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
              color: AppAdmin.inkMid,
              fontSize: 13,
              fontWeight: FontWeight.w600),
          prefixIcon: Icon(icon, color: AppAdmin.inkMid, size: 18),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  // Pops with a typed ServiceModel result — the parent applies it to its
  // local _services list only after this dialog route has actually
  // finished returning (see _EditUserDialogState._showServiceForm).
  void _handleSave() {
    if (!_formKey.currentState!.validate()) return;
    final existing = widget.initialService;
    Navigator.of(context).pop(ServiceModel(
        id: existing?.id ?? 'svc_${DateTime.now().millisecondsSinceEpoch}',
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        price: double.parse(_priceCtrl.text.trim())));
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.initialService;
    return _AdminUserModalShell(
      icon: Icons.design_services_outlined,
      title: existing == null ? 'Add Service' : 'Edit Service',
      accentColor: AppAdmin.dark,
      body: Form(
        key: _formKey,
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _neoField(
                  controller: _nameCtrl,
                  label: 'Service Name',
                  icon: Icons.design_services_outlined,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter service name'
                      : null),
              const SizedBox(height: 12),
              _neoField(
                  controller: _descCtrl,
                  maxLines: 2,
                  label: 'Description',
                  icon: Icons.notes_rounded,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter description'
                      : null),
              const SizedBox(height: 12),
              _neoField(
                  controller: _priceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  label: 'Price (₪)',
                  icon: Icons.payments_outlined,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter the price';
                    }
                    final parsed = double.tryParse(v.trim());
                    if (parsed == null) {
                      return 'Enter a valid number';
                    }
                    if (parsed < 0) {
                      return 'Price cannot be negative';
                    }
                    return null;
                  }),
            ]),
      ),
      footer: Row(children: [
        Expanded(
            child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppAdmin.dark,
                    side: const BorderSide(color: AppAdmin.dark),
                    minimumSize: const Size(0, 46),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: const Text('Cancel',
                    style: TextStyle(fontWeight: FontWeight.w700)))),
        const SizedBox(width: 12),
        Expanded(
            child: ElevatedButton(
                onPressed: _handleSave,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppAdmin.darkest,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 46),
                    padding: EdgeInsets.zero,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: const Text('Save',
                    style: TextStyle(fontWeight: FontWeight.w700)))),
      ]),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────
// Same premium neo-morphism language as Admin Orders' _NeoSectionLabel /
// _NeoDetailRow / _NeoRowIconBtn (admin_screens.dart) — mirrored locally
// here since those are private to that file, rather than modifying a
// shared widget used by the unrelated Orders screen. Used 60+ times across
// the User Details dialog and every role-specific detail body, so this one
// change cascades the premium "elevated info row" look across the whole
// details view.
class _AdminSectionLabel extends StatelessWidget {
  final String label;
  const _AdminSectionLabel({required this.label});
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
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                      color: AppAdmin.accent.withOpacity(0.35),
                      blurRadius: 4,
                      offset: const Offset(0, 2)),
                ])),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppAdmin.darkest,
                letterSpacing: 0.2)),
      ]);
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color? valueColor;
  final Widget? trailing;
  const _DetailRow(
      {required this.icon,
      required this.label,
      required this.value,
      this.valueColor,
      this.trailing});
  @override
  Widget build(BuildContext context) {
    final iconColor = valueColor ?? AppAdmin.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppAdmin.surfaceTint,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: AppAdmin.borderSoft, blurRadius: 4, offset: Offset(2, 2)),
          BoxShadow(color: Colors.white, blurRadius: 4, offset: Offset(-2, -2)),
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 16, color: iconColor)),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppAdmin.inkMid,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? AppAdmin.inkDarkest)),
        ])),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ]),
    );
  }
}

// Shown only when the phone value is actually dialable; opens the device
// dialer via the shared tel: launcher, never placing the call automatically.
class _DetailCallButton extends StatelessWidget {
  final String phone;
  const _DetailCallButton({required this.phone});

  @override
  Widget build(BuildContext context) {
    if (normalizedTelNumber(phone) == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => launchPhoneCall(context, phone),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppAdmin.dark.withOpacity(0.12),
        ),
        child: Icon(Icons.call_rounded, size: 14, color: AppAdmin.dark),
      ),
    );
  }
}

// Copies [value] to the clipboard and shows [snackText]. Used for User ID —
// no Firestore access, no network calls.
class _DetailCopyButton extends StatelessWidget {
  final String value;
  final String snackText;
  const _DetailCopyButton({required this.value, required this.snackText});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: value));
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(snackText), behavior: SnackBarBehavior.floating));
        },
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppAdmin.dark.withOpacity(0.12),
          ),
          child: Icon(Icons.copy_rounded, size: 14, color: AppAdmin.dark),
        ),
      );
}
