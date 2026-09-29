import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/presentation/providers/app_providers.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/utils/category_icon_helper.dart';
import '../../../../shared/widgets/shared_widgets.dart' show ProfileAvatarImage;
import '../../../../shared/helpers/calendar_helper.dart';
import '../theme/customer_design.dart';
import '../widgets/customer_provider_card.dart';
import 'provider_profile_screen.dart';
import 'new_order_screen.dart';
import 'all_categories_screen.dart';
import 'favorites_screen.dart';
import 'category_providers_screen.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../help/presentation/screens/help_center_screen.dart';
import '../../../ai_service_assistant/presentation/screens/ai_service_assistant_screen.dart';
import '../../../ai_service_assistant/presentation/providers/ai_service_assistant_provider.dart';

// Re-export blue palette for use in other files
export '../../../../shared/widgets/shared_widgets.dart' show AppBlue;
import 'notifications_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
class CustomerFeedScreen extends ConsumerStatefulWidget {
  const CustomerFeedScreen({super.key});
  @override
  ConsumerState<CustomerFeedScreen> createState() => _CustomerFeedScreenState();
}

class _CustomerFeedScreenState extends ConsumerState<CustomerFeedScreen> {
  final _searchCtrl = TextEditingController();
  bool _showAll = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showNotificationsSheet(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const CustomerNotificationsScreen(),
        transitionsBuilder: (_, animation, __, child) {
          final curved =
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }

  void _showThreeDotsMenu(BuildContext context) {
    final l = AppLocalizations.of(context);
    final currentUser = ref.read(authProvider);
    final unreadNotifications = currentUser == null
        ? 0
        : ref.read(unreadNotificationsCountProvider(
            (userId: currentUser.id, role: UserRole.customer)));
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.45),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(color: Colors.transparent),
              ),
            ),
            // Vertical pill panel — top right
            Positioned(
              top: 70,
              right: 16,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(curved),
                child: FadeTransition(
                  opacity: anim,
                  child: _VerticalNeoMenu(
                    onSelected: (val) {
                      Navigator.pop(ctx);
                      Future.microtask(() {
                        switch (val) {
                          case 'notifications':
                            _showNotificationsSheet(context);
                            break;
                          case 'favorites':
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const FavoritesScreen()));
                            break;
                          case 'help':
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const HelpCenterScreen(
                                          userRole: UserRole.customer,
                                          accentColor: Color(0xFF3B82F6),
                                          gradientStart: CustomerColors.darkest,
                                          gradientMid: Color(0xFF0A1F4E),
                                          gradientEnd: CustomerColors.dark,
                                        )));
                            break;
                          case 'logout':
                            ref.read(authProvider.notifier).logout();
                            Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const LoginScreen()),
                                (r) => false);
                            break;
                        }
                      });
                    },
                    items: [
                      _RadialItem('notifications', Icons.notifications_outlined,
                          l.get('notifications'), const Color(0xFF7C3AED),
                          badge: unreadNotifications),
                      _RadialItem(
                          'favorites',
                          Icons.bookmark_border_rounded,
                          l.get('favorites') ?? 'Favorites',
                          const Color(0xFF2563EB)),
                      _RadialItem('help', Icons.help_outline_rounded,
                          l.get('help'), const Color(0xFF059669)),
                      _RadialItem('logout', Icons.logout_rounded,
                          l.get('logout'), const Color(0xFFDC2626)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final user = ref.watch(liveCurrentUserProvider).valueOrNull ??
        ref.watch(authProvider);
    final categories = ref.watch(categoriesProvider).value ?? [];
    // Customer Home shows only the first 5 categories (existing Firestore
    // ordering preserved); All Categories screen still shows every category.
    final homeCategories = categories.take(5).toList();
    final query = ref.watch(searchQueryProvider);
    final featuredAsync = ref.watch(featuredProvidersProvider);
    final providers = (featuredAsync.valueOrNull ?? const <UserModel>[])
        .where((p) =>
            query.isEmpty ||
            p.fullName.toLowerCase().contains(query.toLowerCase()) ||
            (p.specialty?.toLowerCase().contains(query.toLowerCase()) ?? false))
        .toList();
    final visible = _showAll ? providers : providers.take(3).toList();
    final providersLoading =
        featuredAsync.isLoading && featuredAsync.valueOrNull == null;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F6FF),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Premium Dark Header ───────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      CustomerColors.darkest,
                      Color(0xFF0A1F4E),
                      CustomerColors.dark
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: [0.0, 0.5, 1.0],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: Color(0x40021024),
                        blurRadius: 24,
                        offset: Offset(0, 10)),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // ── Circular User Avatar ────────────────────
                        GestureDetector(
                          onTap: () =>
                              ref.read(navIndexProvider.notifier).state = 3,
                          child: Stack(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: (user?.avatar?.isNotEmpty ?? false)
                                      ? null
                                      : const LinearGradient(
                                          colors: [
                                            CustomerColors.mid,
                                            CustomerColors.light
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.5),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: CustomerColors.darkest
                                          .withOpacity(0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ProfileAvatarImage(
                                  imageUrl: user?.avatar,
                                  size: 48,
                                  fallbackText:
                                      user?.fullName.isNotEmpty == true
                                          ? user!.fullName
                                          : 'U',
                                  fallbackTextStyle: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                              // Online indicator dot
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
                                      color: CustomerColors.darkest,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
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
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l.get('search_best'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.60),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _showThreeDotsMenu(context),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A3A6B),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.35),
                                  blurRadius: 8,
                                  offset: const Offset(3, 3),
                                ),
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.08),
                                  blurRadius: 6,
                                  offset: const Offset(-2, -2),
                                ),
                              ],
                              border: Border.all(
                                color: Colors.white.withOpacity(0.15),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                  3,
                                  (i) => Container(
                                        width: 4,
                                        height: 4,
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 1.5),
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                      )),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Floating 3D Search Bar (reference style) ────────
                    _AnimatedSearchBar(
                      controller: _searchCtrl,
                      hintText: l.get('search'),
                      query: query,
                      onChanged: (v) =>
                          ref.read(searchQueryProvider.notifier).state = v,
                      onClear: () {
                        _searchCtrl.clear();
                        ref.read(searchQueryProvider.notifier).state = '';
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // ── AI Service Assistant entry point — standalone card, outside
            // the blue header ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _AiAssistantHomeEntry(
                  title: l.get('ai_assistant_home_title'),
                  subtitle: l.get('ai_assistant_home_subtitle'),
                  onTap: () async {
                    final notifier =
                        ref.read(aiServiceAssistantControllerProvider.notifier);
                    notifier.reset();
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AiServiceAssistantScreen()),
                    );
                    notifier.reset();
                  },
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ── Categories ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(l.get('categories'),
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: CustomerColors.darkest)),
                    const Spacer(),
                    // Neo icon button — opens all categories screen
                    _NeoIconShowMore(
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AllCategoriesScreen())),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 104,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: homeCategories.length,
                  itemBuilder: (context, i) {
                    final cat = homeCategories[i];
                    return _FeedNeoCategoryCard(
                      cat: cat,
                      label: l.get(cat.nameKey),
                      index: i,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => CategoryProvidersScreen(
                                categoryKey: cat.nameKey, categoryId: cat.id)),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 28)),

            // ── Today's Schedule ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: _TodaysScheduleSection(ref: ref, l: l),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 28)),

            // ── Providers ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l.get('recommended'),
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: CustomerColors.darkest),
                    ),
                    const Spacer(),
                    // Neomorphism More button — opens all providers screen
                    _NeoMoreButton(
                      label: l.get('more'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              _AllProvidersScreen(providers: providers),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            if (providersLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                      child:
                          CircularProgressIndicator(color: CustomerColors.mid)),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => CustomerProviderCard(
                    key: ValueKey(visible[i].id),
                    provider: visible[i],
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                ProviderProfileScreen(provider: visible[i]))),
                  ),
                  childCount: visible.length,
                ),
              ),

            if (!providersLoading && providers.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: Column(children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: CustomerColors.lightest,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(Icons.search_off_rounded,
                            size: 40, color: CustomerColors.mid),
                      ),
                      const SizedBox(height: 16),
                      Text(l.get('no_results'),
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: CustomerColors.darkest)),
                      const SizedBox(height: 4),
                      Text(l.get('try_another_search'),
                          style: const TextStyle(
                              fontSize: 14, color: CustomerColors.mid)),
                    ]),
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

// ─── Category Providers Screen ────────────────────────────────────────────────

// ── Schedule status → Customer-blue-consistent visual theme ────────────────────
// Reuses existing CustomerColors tokens only (no new palette introduced).
// "In progress" reuses CustomerColors.lightBlueSection — the Customer blue
// tint already used elsewhere in this design system — for the card tint;
// pending/completed/cancelled tints are the same warning/success/error
// accents softened over white so the badge and card stay visually coupled.
class _ScheduleStatusTheme {
  final Color accent;
  final Color background;
  final String label;
  const _ScheduleStatusTheme({
    required this.accent,
    required this.background,
    required this.label,
  });
}

_ScheduleStatusTheme _scheduleStatusTheme(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return _ScheduleStatusTheme(
        accent: CustomerColors.warning,
        background: Color.alphaBlend(
            CustomerColors.warning.withOpacity(0.13), Colors.white),
        label: 'Pending',
      );
    case OrderStatus.inProgress:
      return const _ScheduleStatusTheme(
        accent: CustomerColors.primaryDark,
        background: CustomerColors.lightBlueSection,
        label: 'In Progress',
      );
    case OrderStatus.completed:
      return _ScheduleStatusTheme(
        accent: CustomerColors.success,
        background: Color.alphaBlend(
            CustomerColors.success.withOpacity(0.13), Colors.white),
        label: 'Completed',
      );
    case OrderStatus.cancelled:
      return _ScheduleStatusTheme(
        accent: CustomerColors.error,
        background: Color.alphaBlend(
            CustomerColors.error.withOpacity(0.13), Colors.white),
        label: 'Cancelled',
      );
  }
}

// ── Today's Schedule Section — Daily Task style ───────────────────────────────
class _TodaysScheduleSection extends StatelessWidget {
  final WidgetRef ref;
  final AppLocalizations l;
  const _TodaysScheduleSection({required this.ref, required this.l});

  @override
  Widget build(BuildContext context) {
    // Reuses the same live per-customer Firestore stream as the Orders tab
    // (filtered by customerId, already used by customer_orders_screen.dart).
    final ordersAsync = ref.watch(customerFirestoreOrdersProvider);
    final bool isLoading =
        ordersAsync.isLoading && ordersAsync.valueOrNull == null;
    final bool hasError =
        ordersAsync.hasError && ordersAsync.valueOrNull == null;
    final orders = ordersAsync.valueOrNull ?? const <OrderModel>[];

    // Active orders only (excludes completed/cancelled); nearest scheduled
    // date/time first. Malformed serviceDate values already fall back to
    // DateTime.now() in OrderModel.fromMap, so sorting never throws here.
    final todayOrders = orders
        .where((o) =>
            o.status == OrderStatus.pending ||
            o.status == OrderStatus.inProgress)
        .toList()
      ..sort((a, b) => a.serviceDate.compareTo(b.serviceDate));

    final visibleOrders = todayOrders.take(2).toList();
    final hasMore = todayOrders.length > 2;

    Widget body;
    if (isLoading) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child:
            Center(child: CircularProgressIndicator(color: CustomerColors.mid)),
      );
    } else if (hasError) {
      body = Center(
        child: Column(children: [
          const Icon(Icons.wifi_off_rounded,
              size: 36, color: CustomerColors.mid),
          const SizedBox(height: 8),
          Text(
            'Could not load your schedule.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13,
                color: CustomerColors.mid.withOpacity(0.8),
                fontWeight: FontWeight.w600),
          ),
        ]),
      );
    } else if (todayOrders.isEmpty) {
      body = Center(
        child: Column(children: [
          const Icon(Icons.event_available_rounded,
              size: 36, color: CustomerColors.mid),
          const SizedBox(height: 8),
          Text(
            'No active orders scheduled',
            style: TextStyle(
                fontSize: 13,
                color: CustomerColors.mid.withOpacity(0.8),
                fontWeight: FontWeight.w600),
          ),
        ]),
      );
    } else {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Left vertical timeline ────────────────────────────────
          SizedBox(
            width: 72,
            child: Column(
              children: List.generate(visibleOrders.length, (i) {
                final theme = _scheduleStatusTheme(visibleOrders[i].status);
                final isLast = i == visibleOrders.length - 1;

                return Column(
                  children: [
                    // Pill label
                    GestureDetector(
                      onTap: () => _showScheduleDetails(
                          context, visibleOrders[i],
                          ref: ref),
                      child: Container(
                        width: 64,
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 6),
                        decoration: BoxDecoration(
                          color: theme.accent,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: theme.accent.withOpacity(0.40),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                            BoxShadow(
                              color: Colors.white.withOpacity(0.30),
                              blurRadius: 4,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            theme.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                    // Dotted connector line (not after last)
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 52,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: CustomPaint(
                          painter: _DottedLinePainter(
                              color: theme.accent.withOpacity(0.40)),
                        ),
                      ),
                  ],
                );
              }),
            ),
          ),

          const SizedBox(width: 10),

          // ── Right task cards ──────────────────────────────────────
          Expanded(
            child: Column(
              children: List.generate(visibleOrders.length, (i) {
                final order = visibleOrders[i];
                final theme = _scheduleStatusTheme(order.status);
                final color = theme.accent;
                final bg = theme.background;

                final d = order.serviceDate;
                final timeStr =
                    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

                return GestureDetector(
                  onTap: () => _showScheduleDetails(context, order, ref: ref),
                  child: Container(
                    margin: EdgeInsets.only(
                        bottom: i < visibleOrders.length - 1 ? 12 : 0),
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.16),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                        const BoxShadow(
                          color: Colors.white,
                          blurRadius: 6,
                          offset: Offset(-2, -2),
                        ),
                      ],
                      border: Border.all(
                        color: color.withOpacity(0.22),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Time row
                        Row(children: [
                          Icon(Icons.access_time_rounded,
                              size: 13, color: color),
                          const SizedBox(width: 4),
                          Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        // Title
                        Row(children: [
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 6, top: 1),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              order.title,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: CustomerColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 3),
                        // Area / provider
                        Row(children: [
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 6, top: 1),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.45),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              order.providerName.isNotEmpty
                                  ? '${order.area} · ${order.providerName.split(' ').first}'
                                  : order.area,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: CustomerColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section Header ────────────────────────────────────────────
          Row(children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: CustomerColors.dark,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              "Today's Schedule",
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: CustomerColors.darkest),
            ),
            const Spacer(),
            if (hasMore)
              _NeoScheduleMoreButton(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _AllSchedulesScreen(orders: todayOrders),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 16),
          body,
        ],
      ),
    );
  }
}

// ── Dotted line painter ───────────────────────────────────────────────────────
class _DottedLinePainter extends CustomPainter {
  final Color color;
  const _DottedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const dashHeight = 4.0;
    const dashSpace = 4.0;
    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, startY),
        Offset(size.width / 2, (startY + dashHeight).clamp(0, size.height)),
        paint,
      );
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_DottedLinePainter old) => old.color != color;
}

// ── Neomorphism More Button for Schedule ──────────────────────────────────────
class _NeoScheduleMoreButton extends StatefulWidget {
  final VoidCallback onTap;
  const _NeoScheduleMoreButton({required this.onTap});

  @override
  State<_NeoScheduleMoreButton> createState() => _NeoScheduleMoreButtonState();
}

class _NeoScheduleMoreButtonState extends State<_NeoScheduleMoreButton>
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
        builder: (_, child) => Transform.scale(
          scale: 1.0 - 0.07 * _ctrl.value,
          child: child,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFEEEEF5),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              // 3D raised neomorphism
              BoxShadow(
                color: const Color(0xFFBEBECF),
                blurRadius: 0,
                offset: const Offset(0, 4),
              ),
              const BoxShadow(
                color: Color(0xFFBEBECF),
                blurRadius: 8,
                offset: Offset(4, 4),
              ),
              const BoxShadow(
                color: Colors.white,
                blurRadius: 8,
                offset: Offset(-4, -4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'More',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF5555AA),
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 10, color: Color(0xFF5555AA)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Schedule Detail Bottom Sheet — 3D Neomorphism ─────────────────────────────
void _showScheduleDetails(BuildContext context, OrderModel order,
    {WidgetRef? ref}) {
  final isPending = order.status == OrderStatus.pending;
  final statusColor =
      isPending ? const Color(0xFFF59E0B) : const Color(0xFF3B82F6);
  final statusLabel = isPending ? 'Pending' : 'In Progress';

  final d = order.serviceDate;
  final timeStr =
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  final dateStr = '${d.day}/${d.month}/${d.year}';

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(12, 60, 12, 0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFEEEEF5),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          // Neomorphism 3D raised sheet
          boxShadow: const [
            BoxShadow(
              color: Color(0xFFBEBECF),
              blurRadius: 24,
              offset: Offset(8, 8),
            ),
            BoxShadow(
              color: Colors.white,
              blurRadius: 24,
              offset: Offset(-8, -8),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Handle ──────────────────────────────────────────────────
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFBEBECF),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.white,
                        blurRadius: 2,
                        offset: Offset(-1, -1)),
                    BoxShadow(
                        color: Color(0xFFBEBECF),
                        blurRadius: 2,
                        offset: Offset(1, 1)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Header row ───────────────────────────────────────────────
            Row(children: [
              // 3D Neomorphism icon badge
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFEEEEF5),
                  boxShadow: [
                    BoxShadow(
                        color: Color(0xFFBEBECF),
                        blurRadius: 8,
                        offset: Offset(4, 4)),
                    BoxShadow(
                        color: Colors.white,
                        blurRadius: 8,
                        offset: Offset(-4, -4)),
                  ],
                ),
                child: const Icon(Icons.calendar_month_rounded,
                    color: Color(0xFF5555AA), size: 22),
              ),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text(
                  'Schedule Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF333355),
                  ),
                ),
                const SizedBox(height: 5),
                // Status badge — neomorphism inset pill
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
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ]),
            ]),
            const SizedBox(height: 18),

            // ── Info banner — neomorphism inset ──────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Color(0xFFEEEEF5),
                borderRadius: BorderRadius.all(Radius.circular(16)),
                boxShadow: [
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF333355),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7777AA),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Detail rows — neomorphism inset container ─────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFEEEEF5),
                borderRadius: BorderRadius.all(Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                      color: Color(0xFFBEBECF),
                      blurRadius: 8,
                      offset: Offset(4, 4)),
                  BoxShadow(
                      color: Colors.white,
                      blurRadius: 8,
                      offset: Offset(-4, -4)),
                ],
              ),
              child: Column(
                children: [
                  _NeoDetailRow(
                      icon: Icons.access_time_rounded,
                      label: 'Time',
                      value: timeStr),
                  _NeoDivider(),
                  _NeoDetailRow(
                      icon: Icons.calendar_today_rounded,
                      label: 'Date',
                      value: dateStr),
                  _NeoDivider(),
                  _NeoDetailRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Customer',
                    value: order.customerName.isNotEmpty
                        ? order.customerName
                        : 'You',
                  ),
                  _NeoDivider(),
                  _NeoDetailRow(
                      icon: Icons.location_on_outlined,
                      label: 'Area',
                      value: order.area),
                  if (order.selectedServicePrice != null) ...[
                    _NeoDivider(),
                    _NeoDetailRow(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Budget',
                      value:
                          '₪${order.selectedServicePrice!.toStringAsFixed(0)}',
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Action buttons — 3D neomorphism ──────────────────────────
            Row(children: [
              // Full Details — neo outlined button
              Expanded(
                child: _NeoOutlineButton(
                  label: 'Full Details',
                  icon: Icons.open_in_new_rounded,
                  onTap: () {
                    Navigator.pop(context);
                    if (ref != null)
                      ref.read(navIndexProvider.notifier).state = 2;
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Add to Calendar — 3D filled button
              Expanded(
                child: _NeoFilledButton(
                  label: 'Add to Calendar',
                  icon: Icons.calendar_month_rounded,
                  onTap: () {
                    Navigator.pop(context);
                    addOrderToGoogleCalendar(context, order);
                  },
                ),
              ),
            ]),
            const SizedBox(height: 32),
          ],
        ),
      ),
    ),
  );
}

// ── Neo Detail Row ────────────────────────────────────────────────────────────
class _NeoDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _NeoDetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFEEEEF5),
            boxShadow: [
              BoxShadow(
                  color: Color(0xFFBEBECF),
                  blurRadius: 5,
                  offset: Offset(2, 2)),
              BoxShadow(
                  color: Colors.white, blurRadius: 5, offset: Offset(-2, -2)),
            ],
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF5555AA)),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF7777AA)),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF333355),
          ),
        ),
      ]),
    );
  }
}

// ── Neo Divider ───────────────────────────────────────────────────────────────
class _NeoDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [
          Color(0xFFD0D0DF),
          Colors.white,
          Color(0xFFD0D0DF),
        ]),
      ),
    );
  }
}

// ── Neo Outline Button ────────────────────────────────────────────────────────
class _NeoOutlineButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _NeoOutlineButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  State<_NeoOutlineButton> createState() => _NeoOutlineButtonState();
}

class _NeoOutlineButtonState extends State<_NeoOutlineButton>
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
  Widget build(BuildContext context) {
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
            Transform.scale(scale: 1.0 - 0.04 * _ctrl.value, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFFEEEEF5),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
                color: const Color(0xFF8888CC).withOpacity(0.4), width: 1.2),
            boxShadow: _pressed
                ? const [
                    BoxShadow(
                        color: Color(0xFFBEBECF),
                        blurRadius: 3,
                        offset: Offset(1, 1)),
                    BoxShadow(
                        color: Colors.white,
                        blurRadius: 2,
                        offset: Offset(-1, -1)),
                  ]
                : const [
                    BoxShadow(
                        color: Color(0xFFBEBECF),
                        blurRadius: 0,
                        offset: Offset(0, 4)),
                    BoxShadow(
                        color: Color(0xFFBEBECF),
                        blurRadius: 8,
                        offset: Offset(3, 3)),
                    BoxShadow(
                        color: Colors.white,
                        blurRadius: 8,
                        offset: Offset(-3, -3)),
                  ],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(widget.icon, size: 15, color: const Color(0xFF5555AA)),
            const SizedBox(width: 6),
            Text(
              widget.label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF5555AA),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Neo Filled Button (3D raised) ─────────────────────────────────────────────
class _NeoFilledButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _NeoFilledButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  State<_NeoFilledButton> createState() => _NeoFilledButtonState();
}

class _NeoFilledButtonState extends State<_NeoFilledButton>
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
  Widget build(BuildContext context) {
    return GestureDetector(
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
              colors: [Color(0xFF0A1628), Color(0xFF052659)],
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
            Text(
              widget.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── All Schedules Screen — Daily Task timeline style ──────────────────────────
class _AllSchedulesScreen extends StatelessWidget {
  final List<OrderModel> orders;
  const _AllSchedulesScreen({required this.orders});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FA),
      body: CustomScrollView(
        slivers: [
          // ── AppBar ────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            backgroundColor: CustomerColors.dark,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: const _NeoBackButton(),
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
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text(
                          'All Schedules',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${orders.length} active orders',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.65),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
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
                        size: 60, color: CustomerColors.light),
                    SizedBox(height: 12),
                    Text('No scheduled orders',
                        style:
                            TextStyle(color: CustomerColors.mid, fontSize: 15)),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              sliver: SliverToBoxAdapter(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Left vertical timeline ────────────────────────
                    SizedBox(
                      width: 72,
                      child: Column(
                        children: List.generate(orders.length, (i) {
                          final theme = _scheduleStatusTheme(orders[i].status);
                          final color = theme.accent;
                          final statusLabel = theme.label;
                          final isLast = i == orders.length - 1;

                          return Column(
                            children: [
                              GestureDetector(
                                onTap: () =>
                                    _showScheduleDetails(context, orders[i]),
                                child: Container(
                                  width: 64,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 6),
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(32),
                                    boxShadow: [
                                      BoxShadow(
                                        color: color.withOpacity(0.45),
                                        blurRadius: 10,
                                        offset: const Offset(0, 5),
                                      ),
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.30),
                                        blurRadius: 4,
                                        offset: const Offset(0, -2),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      statusLabel,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.2,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                              if (!isLast)
                                Container(
                                  width: 2,
                                  height: 68,
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: CustomPaint(
                                    painter: _DottedLinePainter(
                                        color: color.withOpacity(0.45)),
                                  ),
                                ),
                            ],
                          );
                        }),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // ── Right task cards ──────────────────────────────
                    Expanded(
                      child: Column(
                        children: List.generate(orders.length, (i) {
                          final order = orders[i];
                          final theme = _scheduleStatusTheme(order.status);
                          final color = theme.accent;
                          final bg = theme.background;
                          final d = order.serviceDate;
                          final timeStr =
                              '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
                          final isLast = i == orders.length - 1;

                          return GestureDetector(
                            onTap: () => _showScheduleDetails(context, order),
                            child: Container(
                              margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
                              padding:
                                  const EdgeInsets.fromLTRB(14, 13, 14, 13),
                              decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withOpacity(0.18),
                                    blurRadius: 12,
                                    offset: const Offset(0, 5),
                                  ),
                                  const BoxShadow(
                                    color: Colors.white,
                                    blurRadius: 6,
                                    offset: Offset(-2, -2),
                                  ),
                                ],
                                border: Border.all(
                                  color: color.withOpacity(0.18),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Time row
                                  Row(children: [
                                    Icon(Icons.access_time_rounded,
                                        size: 13, color: color),
                                    const SizedBox(width: 4),
                                    Text(
                                      timeStr,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: color,
                                      ),
                                    ),
                                  ]),
                                  const SizedBox(height: 6),
                                  // Title
                                  Row(children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      margin: const EdgeInsets.only(
                                          right: 6, top: 1),
                                      decoration: BoxDecoration(
                                          color: color, shape: BoxShape.circle),
                                    ),
                                    Expanded(
                                      child: Text(
                                        order.title,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF333344),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ]),
                                  const SizedBox(height: 3),
                                  // Area
                                  Row(children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      margin: const EdgeInsets.only(
                                          right: 6, top: 1),
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.45),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        order.area,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: const Color(0xFF555566)
                                              .withOpacity(0.75),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ]),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Schedule Order Card ───────────────────────────────────────────────────────
class _ScheduleOrderCard extends StatelessWidget {
  final OrderModel order;
  final UserModel? provider;
  final VoidCallback? onTap;
  final VoidCallback? onProviderTap;
  const _ScheduleOrderCard(
      {required this.order, this.provider, this.onTap, this.onProviderTap});

  @override
  Widget build(BuildContext context) {
    final isPending = order.status == OrderStatus.pending;
    final statusColor =
        isPending ? const Color(0xFFF59E0B) : const Color(0xFF3B82F6);
    final statusLabel = isPending ? 'Pending' : 'In Progress';
    final statusIcon = isPending
        ? Icons.hourglass_top_rounded
        : Icons.play_circle_filled_rounded;

    // Format date for display
    final d = order.serviceDate;
    final timeStr =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border(
            left: BorderSide(color: statusColor, width: 4),
          ),
          boxShadow: [
            BoxShadow(
              color: CustomerColors.mid.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(children: [
            // Provider Avatar (tappable → provider profile)
            GestureDetector(
              onTap: onProviderTap,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [CustomerColors.dark, CustomerColors.mid],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                  border: onProviderTap != null
                      ? Border.all(
                          color: CustomerColors.mid.withOpacity(0.5), width: 2)
                      : null,
                ),
                child: Center(
                  child: Text(
                    (provider?.fullName.isNotEmpty == true)
                        ? provider!.fullName[0].toUpperCase()
                        : (order.providerName.isNotEmpty
                            ? order.providerName[0].toUpperCase()
                            : 'P'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: CustomerColors.darkest),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.location_on_outlined,
                        size: 13, color: CustomerColors.mid),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        order.area,
                        style: const TextStyle(
                            fontSize: 12, color: CustomerColors.mid),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  Row(children: [
                    const Icon(Icons.access_time_rounded,
                        size: 13, color: CustomerColors.mid),
                    const SizedBox(width: 3),
                    Text(
                      timeStr,
                      style: const TextStyle(
                          fontSize: 12, color: CustomerColors.mid),
                    ),
                  ]),
                ],
              ),
            ),

            // Status badge + chevron
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: statusColor),
                  ),
                ),
                const SizedBox(height: 6),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: CustomerColors.light),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Radial Item Model ─────────────────────────────────────────────────────────
class _RadialItem {
  final String value;
  final IconData icon;
  final String label;
  final Color color;
  final int badge;
  const _RadialItem(this.value, this.icon, this.label, this.color,
      {this.badge = 0});
}

// ── Radial Menu Widget ────────────────────────────────────────────────────────
class _RadialMenu extends StatefulWidget {
  final List<_RadialItem> items;
  final ValueChanged<String> onSelected;

  const _RadialMenu({required this.items, required this.onSelected});

  @override
  State<_RadialMenu> createState() => _RadialMenuState();
}

class _RadialMenuState extends State<_RadialMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400))
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.items.length;

    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(n, (i) {
            final item = widget.items[i];
            // Safe interval: evenly divide 0..1 per item
            final start = (i / n).clamp(0.0, 1.0);
            final end = ((i + 1) / n).clamp(0.0, 1.0);
            final anim = CurvedAnimation(
              parent: _ctrl,
              curve: Interval(start, end, curve: Curves.easeOut),
            );
            final isLast = i == n - 1;

            return AnimatedBuilder(
              animation: anim,
              builder: (_, __) {
                return Opacity(
                  opacity: anim.value.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(20 * (1 - anim.value), 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => widget.onSelected(item.value),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 13),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: item.color.withOpacity(0.12),
                                  ),
                                  child: Icon(item.icon,
                                      color: item.color, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: item.color == const Color(0xFFDC2626)
                                        ? item.color
                                        : const Color(0xFF1E2A3A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (!isLast)
                          Divider(
                            height: 1,
                            color: Colors.grey.withOpacity(0.12),
                            indent: 16,
                            endIndent: 16,
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}

// ── Vertical Neomorphism Menu ─────────────────────────────────────────────────
class _VerticalNeoMenu extends StatefulWidget {
  final List<_RadialItem> items;
  final ValueChanged<String> onSelected;
  const _VerticalNeoMenu({required this.items, required this.onSelected});

  @override
  State<_VerticalNeoMenu> createState() => _VerticalNeoMenuState();
}

class _VerticalNeoMenuState extends State<_VerticalNeoMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420))
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
      width: 68,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        // Neomorphism pill background
        color: const Color(0xFFEEEEF5),
        boxShadow: [
          // outer shadow — bottom right (depth)
          const BoxShadow(
            color: Color(0xFFBEBECF),
            blurRadius: 16,
            offset: Offset(6, 6),
          ),
          // inner highlight — top left (raised)
          const BoxShadow(
            color: Colors.white,
            blurRadius: 16,
            offset: Offset(-6, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(widget.items.length, (i) {
          final item = widget.items[i];
          final n = widget.items.length;
          final start = (i / n).clamp(0.0, 1.0);
          final end = ((i + 1) / n).clamp(0.0, 1.0);
          final anim = CurvedAnimation(
            parent: _ctrl,
            curve: Interval(start, end, curve: Curves.easeOutBack),
          );

          return AnimatedBuilder(
            animation: anim,
            builder: (_, __) => Opacity(
              opacity: anim.value.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.6 + 0.4 * anim.value.clamp(0.0, 1.0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: GestureDetector(
                    onTap: () => widget.onSelected(item.value),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFEEEEF5),
                            boxShadow: [
                              const BoxShadow(
                                color: Color(0xFFBEBECF),
                                blurRadius: 6,
                                offset: Offset(3, 3),
                              ),
                              const BoxShadow(
                                color: Colors.white,
                                blurRadius: 6,
                                offset: Offset(-3, -3),
                              ),
                            ],
                          ),
                          child: Icon(
                            item.icon,
                            color: item.color,
                            size: 22,
                          ),
                        ),
                        if (item.badge > 0)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              constraints: const BoxConstraints(
                                  minWidth: 16, minHeight: 16),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF4444),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  item.badge > 9 ? '9+' : '${item.badge}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                          ),
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

// ── Glassmorphism Gradient palettes ──────────────────────────────────────────
// Per-category light pastel accent colors for Design D
const List<Color> _cardAccents = [
  Color(0xFF7C3AED),
  Color(0xFF0EA5E9),
  Color(0xFFF59E0B),
  Color(0xFF10B981),
  Color(0xFFEF4444),
  Color(0xFFEC4899),
  Color(0xFF6366F1),
  Color(0xFF14B8A6),
];

// ── Neomorphism More Button (feed screen) ─────────────────────────────────────
class _NeoMoreButton extends StatefulWidget {
  final VoidCallback onTap;
  final String label;
  const _NeoMoreButton({required this.onTap, required this.label});

  @override
  State<_NeoMoreButton> createState() => _NeoMoreButtonState();
}

class _NeoMoreButtonState extends State<_NeoMoreButton>
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
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => Transform.scale(
          scale: 1.0 - 0.07 * _ctrl.value,
          child: child,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFEEEEF5),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                  color: Color(0xFFBEBECF),
                  blurRadius: 8,
                  offset: Offset(4, 4)),
              BoxShadow(
                  color: Colors.white, blurRadius: 8, offset: Offset(-4, -4)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF5555AA),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 10, color: Color(0xFF5555AA)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Feed Screen 3D Category Card (horizontal scroll) ─────────────────────────
class _FeedNeoCategoryCard extends StatefulWidget {
  final dynamic cat;
  final String label;
  final VoidCallback onTap;
  final int index;
  const _FeedNeoCategoryCard(
      {required this.cat,
      required this.label,
      required this.onTap,
      this.index = 0});

  @override
  State<_FeedNeoCategoryCard> createState() => _FeedNeoCategoryCardState();
}

class _FeedNeoCategoryCardState extends State<_FeedNeoCategoryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 130));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = _cardAccents[widget.index % _cardAccents.length];

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
            Transform.scale(scale: 1.0 - 0.04 * _ctrl.value, child: child),
        child: Container(
          width: 88,
          margin: const EdgeInsets.only(right: 12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: const Color(0xFFEEEEF5),
              boxShadow: _pressed
                  ? [
                      const BoxShadow(
                          color: Color(0xFFBEBECF),
                          blurRadius: 6,
                          offset: Offset(2, 2)),
                      const BoxShadow(
                          color: Colors.white,
                          blurRadius: 6,
                          offset: Offset(-2, -2)),
                    ]
                  : [
                      const BoxShadow(
                          color: Color(0xFFBEBECF),
                          blurRadius: 12,
                          offset: Offset(5, 5)),
                      const BoxShadow(
                          color: Colors.white,
                          blurRadius: 12,
                          offset: Offset(-5, -5)),
                    ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon container — inset neumorphic
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: const Color(0xFFEEEEF5),
                      boxShadow: _pressed
                          ? [
                              BoxShadow(
                                  color:
                                      const Color(0xFFBEBECF).withOpacity(0.7),
                                  blurRadius: 4,
                                  offset: const Offset(2, 2)),
                              const BoxShadow(
                                  color: Colors.white,
                                  blurRadius: 4,
                                  offset: Offset(-2, -2)),
                            ]
                          : [
                              const BoxShadow(
                                  color: Color(0xFFBEBECF),
                                  blurRadius: 8,
                                  offset: Offset(3, 3)),
                              const BoxShadow(
                                  color: Colors.white,
                                  blurRadius: 8,
                                  offset: Offset(-3, -3)),
                            ],
                    ),
                    child: Center(
                      child: Icon(
                        categoryIconFor(
                            id: widget.cat.id,
                            nameKey: widget.cat.nameKey,
                            icon: widget.cat.icon),
                        color: const Color(0xFF5555AA),
                        size: 21,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF9999BB),
                      letterSpacing: 0.1,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Premium Curved Search Bar ──────────────────────────────────────────────────
class _AnimatedSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _AnimatedSearchBar({
    required this.controller,
    required this.hintText,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<_AnimatedSearchBar> createState() => _AnimatedSearchBarState();
}

class _AnimatedSearchBarState extends State<_AnimatedSearchBar>
    with TickerProviderStateMixin {
  late AnimationController _entryCtrl;
  late AnimationController _pressCtrl;
  late Animation<double> _entryAnim;
  late Animation<double> _pressAnim;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _entryAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.elasticOut);
    _pressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _pressAnim = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut),
    );
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_entryAnim, _pressAnim]),
      builder: (_, __) => Transform.scale(
        scale: _entryAnim.value * _pressAnim.value,
        child: SizedBox(
          height: 62,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              // ── Main container with custom left curve ────────────────
              Positioned(
                left: 26,
                right: 0,
                top: 0,
                bottom: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(32),
                      bottomLeft: Radius.circular(32),
                      topRight: Radius.circular(28),
                      bottomRight: Radius.circular(28),
                    ),
                    color: CustomerColors.card,
                    border: Border.all(
                      color: _focused
                          ? CustomerColors.primary
                          : Colors.white.withOpacity(0.65),
                      width: _focused ? 1.8 : 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: CustomerColors.darkest
                            .withOpacity(_focused ? 0.30 : 0.22),
                        blurRadius: _focused ? 22 : 16,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(32),
                      bottomLeft: Radius.circular(32),
                      topRight: Radius.circular(28),
                      bottomRight: Radius.circular(28),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 42, right: 16),
                      child: Center(
                        child: TextField(
                          controller: widget.controller,
                          onChanged: widget.onChanged,
                          onTap: () => setState(() => _focused = true),
                          onEditingComplete: () =>
                              setState(() => _focused = false),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: CustomerColors.textPrimary,
                            letterSpacing: 0.1,
                          ),
                          cursorColor: CustomerColors.primary,
                          cursorWidth: 1.5,
                          decoration: InputDecoration(
                            hintText: widget.hintText,
                            hintStyle: TextStyle(
                              color: CustomerColors.textSecondary
                                  .withOpacity(0.95),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 4),
                            suffixIcon: widget.query.isNotEmpty
                                ? GestureDetector(
                                    onTap: () {
                                      setState(() => _focused = false);
                                      widget.onClear();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: Icon(
                                        Icons.close_rounded,
                                        color: CustomerColors.textSecondary,
                                        size: 19,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Floating circular search button ──────────────────────
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  onTapDown: (_) {
                    _pressCtrl.forward();
                    setState(() => _focused = true);
                  },
                  onTapUp: (_) {
                    _pressCtrl.reverse();
                  },
                  onTapCancel: () => _pressCtrl.reverse(),
                  child: Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: CustomerColors.primaryGradient,
                      boxShadow: [
                        ...CustomerShadows.primaryButton,
                        BoxShadow(
                          color: Colors.white.withOpacity(0.18),
                          blurRadius: 6,
                          offset: const Offset(0, -2),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withOpacity(0.55),
                        width: 1.5,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Top shine
                        Positioned(
                          top: 2,
                          left: 2,
                          right: 2,
                          child: Container(
                            height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withOpacity(0.30),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        const Center(
                          child: Icon(Icons.search_rounded,
                              color: Colors.white, size: 24),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── AI Service Assistant — Home entry point ────────────────────────────────
// Standalone premium card in the normal (light) Customer page content, below
// the blue header and above Categories. Opens the mock-only
// AiServiceAssistantScreen; see lib/features/ai_service_assistant/ for the
// feature implementation.
class _AiAssistantHomeEntry extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _AiAssistantHomeEntry({
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
          color: CustomerColors.card,
          borderRadius: BorderRadius.circular(CustomerRadii.card),
          border: Border.all(
            color: CustomerColors.primary.withOpacity(0.20),
            width: 1.2,
          ),
          boxShadow: CustomerShadows.soft,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
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
                    style: CustomerText.title.copyWith(fontSize: 14.5),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CustomerText.secondary,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: CustomerColors.lightBlueSection,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_rounded,
                  color: CustomerColors.primaryDark, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Neo Icon Show More Button ─────────────────────────────────────────────────
// Appears above the "Featured Providers" title — neomorphism square icon button
class _NeoIconShowMore extends StatefulWidget {
  final VoidCallback onTap;
  const _NeoIconShowMore({required this.onTap});

  @override
  State<_NeoIconShowMore> createState() => _NeoIconShowMoreState();
}

class _NeoIconShowMoreState extends State<_NeoIconShowMore>
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
            Transform.scale(scale: 1.0 - 0.08 * _ctrl.value, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Color(0xFFEEEEF5),
            borderRadius: BorderRadius.all(Radius.circular(13)),
            boxShadow: [
              // 3D bottom solid
              BoxShadow(
                  color: Color(0xFFBEBECF),
                  blurRadius: 0,
                  offset: Offset(0, 3)),
              // outer dark
              BoxShadow(
                  color: Color(0xFFBEBECF),
                  blurRadius: 8,
                  offset: Offset(3, 4)),
              // top highlight
              BoxShadow(
                  color: Colors.white, blurRadius: 8, offset: Offset(-3, -3)),
            ],
          ),
          child: const Icon(
            Icons.open_in_full_rounded,
            size: 18,
            color: Color(0xFF5555AA),
          ),
        ),
      ),
    );
  }
}

// ── All Providers Screen ──────────────────────────────────────────────────────
class _AllProvidersScreen extends ConsumerWidget {
  final List<UserModel> providers;
  const _AllProvidersScreen({required this.providers});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F6FF),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            backgroundColor: CustomerColors.dark,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: const _NeoBackButton(),
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
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text(
                          'Featured Providers',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${providers.length} professionals available',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.65),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => CustomerProviderCard(
                key: ValueKey(providers[i].id),
                provider: providers[i],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          ProviderProfileScreen(provider: providers[i])),
                ),
              ),
              childCount: providers.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// ── Neo Back Button (Neomorphism style matching the image) ────────────────────
class _NeoBackButton extends StatefulWidget {
  const _NeoBackButton();

  @override
  State<_NeoBackButton> createState() => _NeoBackButtonState();
}

class _NeoBackButtonState extends State<_NeoBackButton>
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
  Widget build(BuildContext context) {
    return GestureDetector(
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
          builder: (_, child) => Transform.scale(
            scale: 1.0 - 0.08 * _ctrl.value,
            child: child,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: Colors.white.withOpacity(0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.28),
                  blurRadius: 0,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 8,
                  offset: const Offset(3, 4),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.12),
                  blurRadius: 6,
                  offset: const Offset(-2, -2),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Notifications Full Screen ─────────────────────────────────────────────────
