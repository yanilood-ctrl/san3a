import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/presentation/providers/app_providers.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/shared_widgets.dart' show ProfileAvatarImage;
import '../../../../shared/widgets/provider_content_translate_action.dart';
import '../../../../shared/widgets/provider_service_translate_action.dart';
import '../../../../shared/helpers/phone_call_helper.dart';
import '../../../translation/data/translation_repository.dart'
    show TranslationContentType;
import 'new_order_screen.dart';
import 'customer_chat_screen.dart';
import 'customer_feed_screen.dart' show AppBlue;
import '../theme/customer_design.dart';
import '../../../contractor/presentation/screens/contractor_suppliers_screen.dart'
    show WorkerProfileScreen;

// ── Neo color constants ────────────────────────────────────────────────────────
const _nBg = Color(0xFFEEEEF5);
const _nDark = Color(0xFFBEBECF);
const _nLight = Colors.white;

// ── Provider About bio extraction ───────────────────────────────────────────
// A provider's `serviceDescription` is a free-text bio, but the
// Professional/Contractor Edit Profile screens additionally encode
// structured schedule data into the same field as pipe-separated segments —
// e.g. "bio text | hours: 08:00-18:00 | response: within an hour" (see
// UserModel.effectiveWork* / _legacyHoursPairFromDescription in
// shared/models/models.dart, and the same "hours:"/"response:" convention in
// contractor_profile_screen.dart and professional_home_screen.dart). No
// existing shared/public helper extracts just the prose segment — those
// other screens each parse it inline, privately, for their own edit forms —
// so this is the smallest private helper that does the same for display
// (and, here, for translation) purposes: it never changes the stored
// Firestore value, only what this screen reads out of it.
String _extractProviderAboutBio(String raw) {
  if (!raw.contains('|')) return raw.trim();
  final bioSegments = raw.split('|').map((segment) => segment.trim()).where(
      (segment) =>
          !segment.toLowerCase().startsWith('hours:') &&
          !segment.toLowerCase().startsWith('response:'));
  return bioSegments.join(' ').trim();
}

class ProviderProfileScreen extends ConsumerStatefulWidget {
  final UserModel provider;
  final String? categoryId;
  final String? categoryNameKey;
  const ProviderProfileScreen({
    super.key,
    required this.provider,
    this.categoryId,
    this.categoryNameKey,
  });

  @override
  ConsumerState<ProviderProfileScreen> createState() =>
      _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends ConsumerState<ProviderProfileScreen>
    with WidgetsBindingObserver {
  bool _showAllReviewsInline = false;
  UserModel get provider => widget.provider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Defensive-only refresh: a backgrounded Flutter Web tab's already-open
  // providerReviewsProvider listener has been observed to not promptly
  // redeliver a Firestore change (e.g. Admin hiding a review) made while
  // this tab was backgrounded — only a full refresh (F5) reliably showed
  // the update. Recreating just this provider's stream the moment the tab
  // returns to the foreground guarantees a fresh read without waiting on
  // that listener's own timing, mirroring the same
  // ref.invalidate(providerReviewsProvider(...)) pattern already used after
  // a review edit below — never touches any other provider, never mutates
  // ReviewModel data locally, and normal realtime delivery is unaffected.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(providerReviewsProvider(provider.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final currentUser = ref.watch(authProvider);
    final isFav = currentUser == null
        ? false
        : ref
                .watch(isFavoriteProvider((currentUser.id, provider.id)))
                .valueOrNull ??
            false;
    final reviewsAsync = ref.watch(providerReviewsProvider(provider.id));
    final reviewsLoading =
        reviewsAsync.isLoading && reviewsAsync.valueOrNull == null;
    final reviews = reviewsAsync.valueOrNull ?? const <ReviewModel>[];
    final completedOrders = ref
        .watch(ordersProvider)
        .where((o) =>
            o.providerId == provider.id && o.status == OrderStatus.completed)
        .toList();
    final activeCriteria =
        ref.watch(reviewCriteriaProvider).where((c) => c.isActive).toList();
    // Resolved once per build (not per service row) so each service card can
    // look up its category by id without its own ref.watch call.
    final categoriesById = {
      for (final c in ref.watch(categoriesProvider).valueOrNull ??
          const <CategoryModel>[])
        c.id: c
    };
    final avgOverall = reviews.isEmpty
        ? 0.0
        : reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;

    // Live provider document (real UID, not name-matched) so the displayed
    // availability reflects the provider's current structured schedule; a
    // safe fallback to the passed-in provider covers initial load/errors.
    final liveProvider =
        ref.watch(userByIdProvider(provider.id)).valueOrNull ?? provider;

    // Real free-text bio only — legacy "hours:"/"response:" segments
    // stripped (see _extractProviderAboutBio above). This is what the About
    // card displays and the only text ever passed to
    // ProviderContentTranslateAction for this section.
    final aboutBio =
        _extractProviderAboutBio(provider.serviceDescription ?? '');

    // Customer-facing browsing context: always use the Customer Home header
    // gradient/tokens (see CustomerFeedScreen's "Premium Dark Header"),
    // regardless of the viewed provider's role — no more role-specific
    // (e.g. purple contractor) header styling here.
    const headerColors = [
      CustomerColors.darkest,
      Color(0xFF0A1F4E),
      CustomerColors.dark,
    ];

    return Scaffold(
      backgroundColor: _nBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── HEADER ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _ProfileHeader(
              provider: provider,
              headerColors: headerColors,
              isFav: isFav,
              onFav: currentUser == null
                  ? () {}
                  : () => toggleFavoriteInFirestore(
                      customerId: currentUser.id, provider: provider),
              onFlag: () => _showComplaintSheet(context, ref, l),
            ),
          ),

          // ── BODY ────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats row
                  _NeoStatsRow(provider: provider, l: l, rating: avgOverall),
                  const SizedBox(height: 16),

                  // Action buttons
                  _ActionButtons(
                    provider: provider,
                    onMessage: () {
                      ref
                          .read(conversationsProvider.notifier)
                          .startConversation(provider);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  CustomerChatScreen(otherUser: provider)));
                    },
                    onNewOrder: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => NewOrderScreen(
                                  provider: provider,
                                  categoryId: widget.categoryId,
                                  categoryNameKey: widget.categoryNameKey,
                                ))),
                    l: l,
                  ),
                  const SizedBox(height: 14),

                  // Availability banner
                  _AvailBanner(),
                  const SizedBox(height: 18),

                  // About
                  if (aboutBio.isNotEmpty) ...[
                    _NeoSectionLabel(label: l.get('about_provider_section')),
                    const SizedBox(height: 10),
                    _NeoCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(aboutBio,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF8888AA),
                                    height: 1.65)),
                            const SizedBox(height: 10),
                            ProviderContentTranslateAction(
                              contentType: TranslationContentType.providerAbout,
                              sourceDocId: provider.id,
                              currentSourceText: aboutBio,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // Contact details
                  _NeoSectionLabel(label: l.get('contact_details')),
                  const SizedBox(height: 10),
                  _NeoCard(
                    child: Column(children: [
                      _NeoInfoRow(
                          icon: Icons.phone_rounded,
                          iconColor: const Color(0xFF7C3AED),
                          label: l.get('phone_number'),
                          value: provider.phone,
                          trailing: _CallIconButton(phone: provider.phone)),
                      _NeoInfoRow(
                          icon: Icons.map_outlined,
                          iconColor: const Color(0xFF0EA5E9),
                          label: l.get('work_area_label'),
                          value: provider.workArea ?? provider.city),
                      _NeoInfoRow(
                          icon: Icons.event_available_rounded,
                          iconColor: const Color(0xFF06B6D4),
                          label: 'Working Days',
                          value: formatWorkingDaysLabel(
                              liveProvider.effectiveWorkingDays)),
                      _NeoInfoRow(
                          icon: Icons.access_time_rounded,
                          iconColor: const Color(0xFF10B981),
                          label: l.get('working_hours_label'),
                          value: liveProvider.effectiveWorkingHoursLabel),
                      _NeoInfoRow(
                          icon: Icons.timeline_rounded,
                          iconColor: const Color(0xFFF59E0B),
                          label: l.get('experience_label'),
                          value: '${provider.experienceYears ?? 0}'),
                      _NeoInfoRow(
                          icon: Icons.check_circle_outline_rounded,
                          iconColor: const Color(0xFF14B8A6),
                          label: l.get('completed_orders'),
                          value: '${provider.totalJobs}+'),
                      _NeoInfoRow(
                          icon: Icons.timelapse_rounded,
                          iconColor: const Color(0xFF8B5CF6),
                          label: l.get('response_time'),
                          value: l.get('response_usually')),
                      _NeoInfoRow(
                        icon: provider.role == UserRole.contractor
                            ? Icons.business_rounded
                            : Icons.person_rounded,
                        iconColor: const Color(0xFF06B6D4),
                        label: l.get('service_type'),
                        value: provider.role == UserRole.contractor
                            ? l.get('service_type_company')
                            : l.get('service_type_individual'),
                        isLast: provider.languages.isEmpty,
                      ),
                      if (provider.languages.isNotEmpty)
                        _NeoInfoRow(
                          icon: Icons.translate_rounded,
                          iconColor: const Color(0xFFEC4899),
                          label: 'Languages',
                          value: provider.languages.join(', '),
                          isLast: true,
                        ),
                    ]),
                  ),
                  const SizedBox(height: 18),

                  // Services
                  if (provider.servicesList.isNotEmpty) ...[
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _NeoSectionLabel(label: l.get('services')),
                        ]),
                    const SizedBox(height: 10),
                    _NeoCard(
                      child: Column(
                        children: List.generate(
                            provider.servicesList.length,
                            (i) => _NeoServiceRow(
                                  service: provider.servicesList[i],
                                  category: categoriesById[
                                      provider.servicesList[i].categoryId],
                                  providerId: provider.id,
                                  isLast: i == provider.servicesList.length - 1,
                                )),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ] else if (provider.services.isNotEmpty) ...[
                    _NeoSectionLabel(label: l.get('services')),
                    const SizedBox(height: 10),
                    _NeoCard(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: provider.services
                              .map((s) => _NeoServiceBadge(s))
                              .toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // Team (contractor only)
                  if (provider.role == UserRole.contractor &&
                      provider.team.isNotEmpty) ...[
                    _NeoSectionLabel(label: l.get('team')),
                    const SizedBox(height: 10),
                    _NeoCard(
                      child: Column(
                        children: List.generate(
                            provider.team.length,
                            (i) => _NeoWorkerRow(
                                  worker: provider.team[i],
                                  isLast: i == provider.team.length - 1,
                                  l: l,
                                  specialtyLabel: _workerSpecialtyLabel(
                                      l,
                                      categoriesById.values.toList(),
                                      provider.team[i]),
                                )),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // Workers & Suppliers — live Firestore, read-only (contractor only)
                  if (provider.role == UserRole.contractor) ...[
                    _ContractorWorkersSection(contractorId: provider.id),
                    const SizedBox(height: 18),
                  ],

                  // Ratings
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _NeoSectionLabel(label: l.get('ratings')),
                        GestureDetector(
                          onTap: () => _showAddReviewSheet(
                              context,
                              ref,
                              completedOrders.isNotEmpty
                                  ? completedOrders.first
                                  : null),
                          child: _NeoAddReviewBtn(label: l.get('add_review')),
                        ),
                      ]),
                  const SizedBox(height: 10),

                  if (reviewsLoading)
                    _NeoCard(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: const Color(0xFF7C3AED)),
                          ),
                        ),
                      ),
                    )
                  else if (reviews.isEmpty)
                    _NeoCard(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                            child: Text(l.get('no_reviews_yet'),
                                style: const TextStyle(
                                    color: Color(0xFF9999BB), fontSize: 13))),
                      ),
                    )
                  else ...[
                    _NeoCard(
                      child: Column(children: [
                        // Summary
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(children: [
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(avgOverall.toStringAsFixed(1),
                                      style: const TextStyle(
                                          fontSize: 40,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFFB45309))),
                                  Text('${reviews.length} ${l.get("ratings")}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF9999BB))),
                                ]),
                            const SizedBox(width: 16),
                            Expanded(
                                child: Column(children: [
                              for (final c in activeCriteria)
                                _NeoRatingBar(
                                    label: c.name,
                                    value: _neoAvgForCriterion(reviews, c),
                                    maxRating: c.maxRating),
                            ])),
                          ]),
                        ),
                        // Divider
                        Container(
                            height: 1,
                            color: _nDark.withOpacity(0.4),
                            margin: const EdgeInsets.symmetric(horizontal: 16)),
                        // Reviews
                        ...(_showAllReviewsInline
                                ? reviews
                                : reviews.take(2).toList())
                            .map((r) => _NeoReviewTile(review: r)),
                      ]),
                    ),
                    if (reviews.length > 2) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => setState(() =>
                            _showAllReviewsInline = !_showAllReviewsInline),
                        child: _NeoCard(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _showAllReviewsInline
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    color: const Color(0xFF6D28D9),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _showAllReviewsInline
                                        ? l.get('show_less_reviews')
                                        : l.get('show_more_reviews').replaceAll(
                                            '{count}', '${reviews.length - 2}'),
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF6D28D9)),
                                  ),
                                ]),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showComplaintSheet(
      BuildContext context, WidgetRef ref, AppLocalizations l) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ComplaintSheet(
          type: ComplaintType.provider,
          targetId: provider.id,
          targetName: provider.fullName,
          targetRole: provider.role == UserRole.contractor
              ? 'contractor'
              : 'professional'),
    );
  }

  void _showAddReviewSheet(
      BuildContext context, WidgetRef ref, OrderModel? order) {
    final effectiveOrder = order ??
        OrderModel(
          id: 'mock_${provider.id}_${DateTime.now().millisecondsSinceEpoch}',
          title: 'General Rating',
          description: '',
          providerId: provider.id,
          providerName: provider.fullName,
          customerId: 'current_user',
          customerName: '',
          status: OrderStatus.completed,
          serviceDate: DateTime.now(),
          createdAt: DateTime.now(),
          area: '',
          priority: OrderPriority.normal,
        );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (_) =>
          _AddReviewSheet(order: effectiveOrder, provider: provider),
    );
  }
}

// ── Profile Header ─────────────────────────────────────────────────────────────
class _ProfileHeader extends ConsumerWidget {
  final UserModel provider;
  final List<Color> headerColors;
  final bool isFav;
  final VoidCallback onFav, onFlag;
  const _ProfileHeader({
    required this.provider,
    required this.headerColors,
    required this.isFav,
    required this.onFav,
    required this.onFlag,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: headerColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: const [
          BoxShadow(
              color: Color(0x40021024), blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      child: Stack(children: [
        // orbs
        Positioned(
            top: -50,
            right: -50,
            child:
                _Orb(size: 200, color: const Color(0xFF0EA5E9), opacity: 0.18)),
        Positioned(
            bottom: -30,
            left: -30,
            child:
                _Orb(size: 150, color: const Color(0xFF7C3AED), opacity: 0.15)),

        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
            child: Column(children: [
              // top bar
              Row(children: [
                _HdrBtn(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 17)),
                const Spacer(),
                _ProfileThreeDotsBtn(
                  isFav: isFav,
                  onFav: onFav,
                  onFlag: onFlag,
                ),
              ]),
              const SizedBox(height: 20),

              // avatar
              Stack(children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.3), width: 2),
                  ),
                  child: Stack(children: [
                    ProfileAvatarImage(
                      // Live avatar only — a pushed screen only receives a
                      // UserModel snapshot from navigation time, so
                      // userByIdProvider keeps just the photo fresh if the
                      // provider changes it while this screen stays open.
                      imageUrl: ref
                              .watch(userByIdProvider(provider.id))
                              .valueOrNull
                              ?.avatar ??
                          provider.avatar,
                      size: 84,
                      borderRadius: 22,
                      fallbackText: provider.fullName.isNotEmpty
                          ? provider.fullName
                          : '?',
                      fallbackTextStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w900),
                    ),
                    // shine
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(22),
                              topRight: Radius.circular(22)),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withOpacity(0.2),
                              Colors.transparent
                            ],
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C853),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF052659), width: 2.5),
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 12),
                  ),
                ),
              ]),
              const SizedBox(height: 12),

              Text(provider.fullName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3)),
              const SizedBox(height: 4),
              Text(provider.specialty ?? '',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.65), fontSize: 13)),
              const SizedBox(height: 8),

              // role pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    provider.role == UserRole.contractor
                        ? Icons.business_rounded
                        : Icons.person_rounded,
                    color: Colors.white.withOpacity(0.8),
                    size: 13,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    provider.role == UserRole.contractor
                        ? 'Company / Contractor'
                        : 'Individual provider',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.85), fontSize: 11),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Orb extends StatelessWidget {
  final double size, opacity;
  final Color color;
  const _Orb({required this.size, required this.color, required this.opacity});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
              colors: [color.withOpacity(opacity), Colors.transparent]),
        ),
      );
}

class _HdrBtn extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _HdrBtn({required this.child, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.22), width: 1),
          ),
          child: Center(child: child),
        ),
      );
}

// ── Neo Stats Row ──────────────────────────────────────────────────────────────
class _NeoStatsRow extends StatelessWidget {
  final UserModel provider;
  final AppLocalizations l;
  final double rating;
  const _NeoStatsRow(
      {required this.provider, required this.l, required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _NeoStatCard(
        icon: Icons.star_rounded,
        colors: [const Color(0xFFF59E0B), const Color(0xFFB45309)],
        value: rating.toStringAsFixed(1),
        label: l.get('rating'),
        numColor: const Color(0xFFB45309),
      ),
      const SizedBox(width: 10),
      _NeoStatCard(
        icon: Icons.timeline_rounded,
        colors: [const Color(0xFF0EA5E9), const Color(0xFF0369A1)],
        value: '${provider.experienceYears ?? 0}',
        label: l.get('experience_years'),
        numColor: const Color(0xFF0369A1),
      ),
      const SizedBox(width: 10),
      _NeoStatCard(
        icon: Icons.check_circle_outline_rounded,
        colors: [const Color(0xFF10B981), const Color(0xFF065F46)],
        value: '${provider.totalJobs}',
        label: l.get('completed_order_count'),
        numColor: const Color(0xFF065F46),
      ),
    ]);
  }
}

class _NeoStatCard extends StatelessWidget {
  final IconData icon;
  final List<Color> colors;
  final String value, label;
  final Color numColor;
  const _NeoStatCard({
    required this.icon,
    required this.colors,
    required this.value,
    required this.label,
    required this.numColor,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: _nBg,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(color: _nDark, blurRadius: 0, offset: Offset(0, 5)),
              BoxShadow(color: _nDark, blurRadius: 12, offset: Offset(5, 5)),
              BoxShadow(color: _nLight, blurRadius: 12, offset: Offset(-5, -5)),
            ],
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            // 3D icon
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: colors[0].withOpacity(0.45),
                      blurRadius: 10,
                      offset: const Offset(0, 5)),
                  BoxShadow(
                      color: colors[1].withOpacity(0.9),
                      blurRadius: 0,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: Stack(children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 23,
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
                        ],
                      ),
                    ),
                  ),
                ),
                Center(child: Icon(icon, color: Colors.white, size: 22)),
              ]),
            ),
            const SizedBox(height: 10),
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: numColor)),
            const SizedBox(height: 3),
            Text(label,
                style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF8888AA),
                    fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ]),
        ),
      );
}

// ── Action Buttons ─────────────────────────────────────────────────────────────
class _ActionButtons extends StatelessWidget {
  final UserModel provider;
  final VoidCallback onMessage, onNewOrder;
  final AppLocalizations l;
  const _ActionButtons({
    required this.provider,
    required this.onMessage,
    required this.onNewOrder,
    required this.l,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: onMessage,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: _nBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: _nDark, blurRadius: 0, offset: Offset(0, 4)),
                  BoxShadow(
                      color: _nDark, blurRadius: 10, offset: Offset(4, 4)),
                  BoxShadow(
                      color: _nLight, blurRadius: 10, offset: Offset(-4, -4)),
                ],
              ),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.chat_bubble_outline_rounded,
                    size: 17, color: Color(0xFF052659)),
                const SizedBox(width: 7),
                Text(l.get('send_message'),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF052659))),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: onNewOrder,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF052659), Color(0xFF0A3D7A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0xFF021024),
                      blurRadius: 0,
                      offset: Offset(0, 5)),
                  BoxShadow(
                      color: Color(0x66052659),
                      blurRadius: 12,
                      offset: Offset(0, 8)),
                ],
              ),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                const SizedBox(width: 6),
                Text(l.get('new_order'),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ]),
            ),
          ),
        ),
      ]);
}

// ── Availability Banner ────────────────────────────────────────────────────────
class _AvailBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _nBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: _nDark, blurRadius: 0, offset: Offset(0, 3)),
            BoxShadow(color: _nDark, blurRadius: 8, offset: Offset(3, 3)),
            BoxShadow(color: _nLight, blurRadius: 8, offset: Offset(-3, -3)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.4),
                    blurRadius: 6,
                    spreadRadius: 2)
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Available now',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF22224A))),
            const Text('Usually responds within 1 hour',
                style: TextStyle(fontSize: 10, color: Color(0xFF9999BB))),
          ]),
        ]),
      );
}

// ── Section Label ──────────────────────────────────────────────────────────────
class _NeoSectionLabel extends StatelessWidget {
  final String label;
  const _NeoSectionLabel({required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF4C1D95)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF7C3AED).withOpacity(0.5),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(label.toUpperCase(),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF444466),
                letterSpacing: 1.5)),
      ]);
}

// ── Neo Card ───────────────────────────────────────────────────────────────────
class _NeoCard extends StatelessWidget {
  final Widget child;
  const _NeoCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: _nBg,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(color: _nDark, blurRadius: 0, offset: Offset(0, 5)),
            BoxShadow(color: _nDark, blurRadius: 14, offset: Offset(6, 6)),
            BoxShadow(color: _nLight, blurRadius: 14, offset: Offset(-6, -6)),
          ],
        ),
        child: child,
      );
}

// ── Neo Info Row ───────────────────────────────────────────────────────────────
class _NeoInfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label, value;
  final bool isLast;
  final Widget? trailing;
  const _NeoInfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.isLast = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c2 = Color.lerp(iconColor, Colors.black, 0.35)!;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          // 3D icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [iconColor, c2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: iconColor.withOpacity(0.45),
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
                  height: 22,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(14),
                        topRight: Radius.circular(14)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.2),
                        Colors.transparent
                      ],
                    ),
                  ),
                ),
              ),
              Center(child: Icon(icon, color: Colors.white, size: 19)),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF9999BB),
                        letterSpacing: 0.4)),
                const SizedBox(height: 3),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF22224A)),
                    overflow: TextOverflow.ellipsis),
              ])),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
        ]),
      ),
      if (!isLast)
        Container(
            height: 1,
            margin: const EdgeInsets.only(left: 74, right: 16),
            color: _nDark.withOpacity(0.45)),
    ]);
  }
}

// ── Call Icon Button ───────────────────────────────────────────────────────────
// Shown only when the phone value is actually dialable; opens the device
// dialer via the shared tel: launcher, never placing the call automatically.
class _CallIconButton extends StatelessWidget {
  final String phone;
  const _CallIconButton({required this.phone});

  @override
  Widget build(BuildContext context) {
    if (normalizedTelNumber(phone) == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => launchPhoneCall(context, phone),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFF7C3AED).withOpacity(0.12),
          borderRadius: BorderRadius.circular(11),
        ),
        child:
            const Icon(Icons.call_rounded, size: 17, color: Color(0xFF7C3AED)),
      ),
    );
  }
}

// ── Neo Service Row ────────────────────────────────────────────────────────────
class _NeoServiceRow extends StatelessWidget {
  final ServiceModel service;
  final CategoryModel? category;
  final String providerId;
  final bool isLast;
  const _NeoServiceRow({
    required this.service,
    required this.category,
    required this.providerId,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0EA5E9), Color(0xFF0369A1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x660369A1),
                      blurRadius: 8,
                      offset: Offset(0, 4)),
                  BoxShadow(
                      color: Color(0xFF0369A1),
                      blurRadius: 0,
                      offset: Offset(0, 3)),
                ],
              ),
              child: Stack(children: [
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
                            Colors.white.withOpacity(0.2),
                            Colors.transparent
                          ]),
                    ),
                  ),
                ),
                const Center(
                    child: Icon(Icons.build_circle_outlined,
                        color: Colors.white, size: 20)),
              ]),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(service.name,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF22224A))),
                  _ServiceCategoryBadge(
                      category: category, color: const Color(0xFF0369A1)),
                  const SizedBox(height: 3),
                  Text(service.description,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF9999BB))),
                  const SizedBox(height: 4),
                  ProviderServiceTranslateAction(
                    sourceDocId: providerId,
                    serviceId: service.id,
                    currentServiceName: service.name,
                    currentServiceDescription: service.description,
                  ),
                ])),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF052659), Color(0xFF0A3D7A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0xFF021024),
                      blurRadius: 0,
                      offset: Offset(0, 3)),
                  BoxShadow(
                      color: Color(0x55052659),
                      blurRadius: 8,
                      offset: Offset(0, 5)),
                ],
              ),
              child: Text('₪${service.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ),
          ]),
        ),
        if (!isLast)
          Container(
              height: 1,
              margin: const EdgeInsets.only(left: 74, right: 16),
              color: _nDark.withOpacity(0.45)),
      ]);
}

// ── Service category badge ─────────────────────────────────────────────────────
// Small, secondary, single-line label showing the service's live Firestore
// category (never guessed from name/specialty). Renders nothing when the
// service has no categoryId, or that id doesn't match a currently loaded
// category — never shows a placeholder like "Unknown Category".
class _ServiceCategoryBadge extends StatelessWidget {
  final CategoryModel? category;
  final Color color;
  const _ServiceCategoryBadge({required this.category, required this.color});
  @override
  Widget build(BuildContext context) {
    final cat = category;
    if (cat == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final icon = cat.icon.trim();
    return Padding(
      padding: const EdgeInsets.only(top: 1, bottom: 2),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon.isNotEmpty) ...[
          Text(icon, style: const TextStyle(fontSize: 10)),
          const SizedBox(width: 3),
        ],
        Flexible(
          child: Text(l.get(cat.nameKey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ),
      ]),
    );
  }
}

// ── Neo Service Badge (fallback) ───────────────────────────────────────────────
class _NeoServiceBadge extends StatelessWidget {
  final String label;
  const _NeoServiceBadge(this.label);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _nBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: _nDark, blurRadius: 0, offset: Offset(0, 3)),
            BoxShadow(color: _nDark, blurRadius: 5, offset: Offset(3, 3)),
            BoxShadow(color: _nLight, blurRadius: 5, offset: Offset(-3, -3)),
          ],
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF22224A))),
      );
}

// ── Neo Worker Row ─────────────────────────────────────────────────────────────
class _NeoWorkerRow extends StatelessWidget {
  final WorkerModel worker;
  final bool isLast;
  final AppLocalizations l;
  // Resolved by the parent (which watches categoriesProvider) so this
  // widget never has to guess a category from a raw specialty string —
  // see _ContractorWorkersSection.build().
  final String specialtyLabel;
  const _NeoWorkerRow(
      {required this.worker,
      required this.l,
      required this.specialtyLabel,
      this.isLast = false});

  Color get _statusColor {
    switch (worker.status) {
      case WorkerStatus.available:
        return const Color(0xFF22C55E);
      case WorkerStatus.busy:
        return const Color(0xFFF59E0B);
      case WorkerStatus.offline:
        return const Color(0xFF9CA3AF);
    }
  }

  String _statusLabel() {
    switch (worker.status) {
      case WorkerStatus.available:
        return l.get('worker_available');
      case WorkerStatus.busy:
        return l.get('worker_busy');
      case WorkerStatus.offline:
        return l.get('worker_offline');
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        GestureDetector(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      WorkerProfileScreen(worker: worker, readOnly: true))),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // avatar
              Stack(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFF4C1D95)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0xFF4C1D95),
                          blurRadius: 0,
                          offset: Offset(0, 3)),
                      BoxShadow(
                          color: Color(0x667C3AED),
                          blurRadius: 8,
                          offset: Offset(0, 5)),
                    ],
                  ),
                  child: Center(
                      child: Text(
                    worker.name.isNotEmpty ? worker.name[0] : '?',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 20),
                  )),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _statusColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: _nBg, width: 2.5),
                    ),
                  ),
                ),
              ]),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Expanded(
                          child: Text(worker.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: Color(0xFF22224A)))),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: _statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: _statusColor.withOpacity(0.3)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                  color: _statusColor, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          Text(_statusLabel(),
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _statusColor)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(specialtyLabel,
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9999BB),
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 10, runSpacing: 4, children: [
                      if (worker.rating > 0)
                        _MiniStat(
                            icon: Icons.star_rounded,
                            text: worker.rating.toStringAsFixed(1),
                            color: const Color(0xFFF59E0B)),
                      if (worker.totalJobs > 0)
                        _MiniStat(
                            icon: Icons.check_circle_outline,
                            text: '${worker.totalJobs} ${l.get("jobs_short")}'),
                      if (worker.yearsExperience > 0)
                        _MiniStat(
                            icon: Icons.workspace_premium_outlined,
                            text:
                                '${worker.yearsExperience} ${l.get("years_short")}'),
                    ]),
                  ])),
              const SizedBox(width: 8),
              // neo arrow
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: _nBg,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  boxShadow: [
                    BoxShadow(
                        color: _nDark, blurRadius: 0, offset: Offset(0, 3)),
                    BoxShadow(
                        color: _nDark, blurRadius: 5, offset: Offset(3, 3)),
                    BoxShadow(
                        color: _nLight, blurRadius: 5, offset: Offset(-3, -3)),
                  ],
                ),
                child: const Icon(Icons.arrow_forward_ios_rounded,
                    size: 12, color: Color(0xFF9999BB)),
              ),
            ]),
          ),
        ),
        if (!isLast)
          Container(
              height: 1,
              margin: const EdgeInsets.only(left: 76, right: 16),
              color: _nDark.withOpacity(0.45)),
      ]);
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const _MiniStat({required this.icon, required this.text, this.color});
  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF9999BB);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: c),
      const SizedBox(width: 3),
      Text(text,
          style:
              TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w700)),
    ]);
  }
}

// ── Neo Rating Bar ─────────────────────────────────────────────────────────────
// Reads the criterion's own maxRating (Firestore-configurable, no longer a
// hardcoded 5) so bars stay proportionally correct and never overflow.
double? _neoCriterionScore(ReviewModel r, ReviewCriteriaModel c) {
  final v = r.criteriaRatings[c.id];
  if (v != null) return v;
  switch (c.name.trim().toLowerCase()) {
    case 'speed':
      return r.speedRating;
    case 'quality':
      return r.qualityRating;
    case 'communication':
      return r.communicationRating;
    default:
      return null;
  }
}

double _neoAvgForCriterion(List<ReviewModel> reviews, ReviewCriteriaModel c) {
  final scores =
      reviews.map((r) => _neoCriterionScore(r, c)).whereType<double>().toList();
  if (scores.isEmpty) return 0.0;
  return scores.reduce((a, b) => a + b) / scores.length;
}

class _NeoRatingBar extends StatelessWidget {
  final String label;
  final double value;
  final int maxRating;
  const _NeoRatingBar(
      {required this.label, required this.value, this.maxRating = 5});
  @override
  Widget build(BuildContext context) {
    final safeMax = maxRating > 0 ? maxRating : 5;
    final progress = (value / safeMax).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(
            width: 92,
            child: Text(label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 10, color: Color(0xFF9999BB)))),
        const SizedBox(width: 6),
        Expanded(
            child: Container(
          height: 6,
          decoration: BoxDecoration(
            color: _nDark.withOpacity(0.35),
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [
              BoxShadow(color: _nDark, blurRadius: 2, offset: Offset(1, 1)),
              BoxShadow(color: _nLight, blurRadius: 2, offset: Offset(-1, -1)),
            ],
          ),
          child: FractionallySizedBox(
            widthFactor: progress,
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        )),
        const SizedBox(width: 6),
        Text(value.toStringAsFixed(1),
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF8888AA))),
      ]),
    );
  }
}

// ── Neo Review Tile ────────────────────────────────────────────────────────────
class _NeoReviewTile extends ConsumerWidget {
  final ReviewModel review;
  const _NeoReviewTile({required this.review});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authProvider);
    final isOwn = currentUser?.id == review.customerId ||
        currentUser?.fullName == review.customerName;

    void onEdit() {
      // reuse add-review sheet in edit mode
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withOpacity(0.45),
        builder: (_) => _EditReviewSheet(review: review),
      );
    }

    void onDelete() {
      // Soft delete only — keeps a moderation trail, matches admin policy.
      deleteReviewInFirestore(review.id);
    }

    return Column(children: [
      Container(
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          color: _nDark.withOpacity(0.4)),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _nBg,
                borderRadius: BorderRadius.circular(11),
                boxShadow: const [
                  BoxShadow(color: _nDark, blurRadius: 0, offset: Offset(0, 3)),
                  BoxShadow(color: _nDark, blurRadius: 5, offset: Offset(3, 3)),
                  BoxShadow(
                      color: _nLight, blurRadius: 5, offset: Offset(-3, -3)),
                ],
              ),
              child: Center(
                  child: Text(
                review.customerName.isNotEmpty ? review.customerName[0] : '?',
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF6D28D9),
                    fontSize: 14),
              )),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(review.customerName,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF22224A))),
                  Text(
                      '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF9999BB))),
                ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.star_rounded,
                    color: Color(0xFFF59E0B), size: 13),
                const SizedBox(width: 3),
                Text(review.overallRating.toStringAsFixed(1),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB45309))),
              ]),
            ),
            if (isOwn) ...[
              const SizedBox(width: 8),
              _ReviewThreeDots(onEdit: onEdit, onDelete: onDelete),
            ],
          ]),
          const SizedBox(height: 10),
          Text(review.comment,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF8888AA), height: 1.45)),
          if (review.comment.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            ProviderContentTranslateAction(
              contentType: TranslationContentType.reviewComment,
              sourceDocId: review.id,
              currentSourceText: review.comment,
              entryLabelKey: 'translate_review',
            ),
          ],
        ]),
      ),
    ]);
  }
}

// ── Neo Add Review Button ──────────────────────────────────────────────────────
class _NeoAddReviewBtn extends StatelessWidget {
  final String label;
  const _NeoAddReviewBtn({required this.label});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: _nBg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: _nDark, blurRadius: 0, offset: Offset(0, 3)),
            BoxShadow(color: _nDark, blurRadius: 6, offset: Offset(3, 3)),
            BoxShadow(color: _nLight, blurRadius: 6, offset: Offset(-3, -3)),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.rate_review_rounded,
              size: 14, color: Color(0xFF6D28D9)),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6D28D9))),
        ]),
      );
}

// ── Complaint Sheet — Neo style ────────────────────────────────────────────────
class _ComplaintSheet extends ConsumerStatefulWidget {
  final ComplaintType type;
  final String? targetId;
  final String? targetName;
  final String? targetRole;
  const _ComplaintSheet(
      {required this.type, this.targetId, this.targetName, this.targetRole});
  @override
  ConsumerState<_ComplaintSheet> createState() => _ComplaintSheetState();
}

class _ComplaintSheetState extends ConsumerState<_ComplaintSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  String? _selectedReason;
  bool _loading = false;

  static const _reasons = [
    'Bad conduct',
    'Bad work quality',
    'Delay',
    'Extra fees',
    'Incomplete work',
    'Other',
  ];

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Please select a reason'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    if (_descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Please describe your complaint'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    setState(() => _loading = true);
    final user = ref.read(authProvider);
    try {
      await addComplaintInFirestore(ComplaintModel(
        id: '',
        userId: user?.id ?? 'current_user',
        userName: user?.fullName ?? '',
        complainantRole: 'customer',
        type: ComplaintType.provider,
        targetId: widget.targetId,
        targetName: widget.targetName,
        targetUserId: widget.targetId,
        targetUserName: widget.targetName,
        targetUserRole: widget.targetRole,
        reason: _selectedReason!,
        description: _descCtrl.text.trim(),
        sourceContext: 'provider_profile',
        createdAt: DateTime.now(),
      ));
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Complaint submitted'),
          ]),
          backgroundColor: const Color(0xFF052659),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to submit complaint: $e')));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: const BoxDecoration(
        color: _nBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(color: _nDark, blurRadius: 20, offset: Offset(8, 8)),
          BoxShadow(color: _nLight, blurRadius: 20, offset: Offset(-8, -8)),
        ],
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 32),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
                child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                  color: _nDark,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: const [
                    BoxShadow(
                        color: _nLight, blurRadius: 2, offset: Offset(-1, -1)),
                    BoxShadow(
                        color: _nDark, blurRadius: 2, offset: Offset(1, 1)),
                  ]),
            )),
            const SizedBox(height: 20),
            Row(children: [
              Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  color: _nBg,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: _nDark, blurRadius: 8, offset: Offset(4, 4)),
                    BoxShadow(
                        color: _nLight, blurRadius: 8, offset: Offset(-4, -4)),
                  ],
                ),
                child: const Icon(Icons.flag_rounded,
                    color: Color(0xFFEF4444), size: 24),
              ),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Submit Complaint',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF333355))),
                if (widget.targetName != null)
                  Text(widget.targetName!,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF9999BB))),
              ]),
            ]),
            const SizedBox(height: 22),
            const Text('Select Reason',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7777AA),
                    letterSpacing: 0.5)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _reasons.map((r) {
                final sel = _selectedReason == r;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _selectedReason = r);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: _nBg,
                      borderRadius: BorderRadius.circular(20),
                      border: sel
                          ? Border.all(
                              color: const Color(0xFFEF4444), width: 1.5)
                          : null,
                      boxShadow: sel
                          ? const [
                              BoxShadow(
                                  color: _nDark,
                                  blurRadius: 2,
                                  offset: Offset(1, 1)),
                              BoxShadow(
                                  color: _nLight,
                                  blurRadius: 2,
                                  offset: Offset(-1, -1)),
                            ]
                          : const [
                              BoxShadow(
                                  color: _nDark,
                                  blurRadius: 6,
                                  offset: Offset(3, 3)),
                              BoxShadow(
                                  color: _nLight,
                                  blurRadius: 6,
                                  offset: Offset(-3, -3)),
                            ],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (sel) ...[
                        const Icon(Icons.check_circle_rounded,
                            size: 14, color: Color(0xFFEF4444)),
                        const SizedBox(width: 5),
                      ],
                      Text(r,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: sel
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF555577),
                          )),
                    ]),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Text('Description',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7777AA),
                    letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: _nBg,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(color: _nDark, blurRadius: 8, offset: Offset(4, 4)),
                  BoxShadow(
                      color: _nLight, blurRadius: 8, offset: Offset(-4, -4)),
                ],
              ),
              child: TextFormField(
                controller: _descCtrl,
                maxLines: 4,
                style: const TextStyle(fontSize: 14, color: Color(0xFF22224A)),
                decoration: const InputDecoration(
                  hintText: 'Describe your complaint in detail...',
                  hintStyle: TextStyle(color: Color(0xFF9999BB), fontSize: 13),
                  filled: true,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _loading ? null : _submit,
              child: Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFF991B1B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0xFF991B1B),
                        blurRadius: 0,
                        offset: Offset(0, 4)),
                    BoxShadow(
                        color: Color(0x55EF4444),
                        blurRadius: 12,
                        offset: Offset(0, 8)),
                  ],
                ),
                child: Center(
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                              Icon(Icons.send_rounded,
                                  color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text('Submit Complaint',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white)),
                            ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// Shared by _AddReviewSheet and _EditReviewSheet to keep the legacy
// speed/quality/communication fields in sync with whichever active criteria
// currently carry those names.
ReviewCriteriaModel? _findCriterionByName(
    List<ReviewCriteriaModel> list, String needle) {
  for (final c in list) {
    if (c.name.trim().toLowerCase() == needle) return c;
  }
  return null;
}

class _AddReviewSheet extends ConsumerStatefulWidget {
  final OrderModel order;
  final UserModel provider;
  const _AddReviewSheet({required this.order, required this.provider});
  @override
  ConsumerState<_AddReviewSheet> createState() => _AddReviewSheetState();
}

class _AddReviewSheetState extends ConsumerState<_AddReviewSheet> {
  final _commentCtrl = TextEditingController();
  // Keyed by review_criteria doc id so ratings survive Firestore reordering
  // and stay stable regardless of criterion display order.
  final Map<String, double> _ratings = {};
  bool _loading = false;

  double _ratingFor(ReviewCriteriaModel c) =>
      _ratings[c.id] ?? (c.maxRating >= 3 ? 3.0 : c.maxRating.toDouble());

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  void _submit(List<ReviewCriteriaModel> activeCriteria) async {
    final l = AppLocalizations.of(context);
    if (_commentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.get('comment_required'))));
      return;
    }
    if (activeCriteria.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Unable to load review criteria. Please try again.')),
      );
      return;
    }
    final criteriaRatings = <String, double>{
      for (final c in activeCriteria) c.id: _ratingFor(c),
    };
    if (criteriaRatings.values.any((v) => v < 1)) return;
    final user = ref.read(authProvider);
    if (user == null) return;

    setState(() => _loading = true);
    // A real completed order carries its own id; the sheet falls back to a
    // synthetic 'mock_...' order when none exists, which we treat as a
    // general (order-less) review for duplicate-prevention purposes.
    final isGeneral = widget.order.id.startsWith('mock_');
    final effectiveOrderId = isGeneral ? null : widget.order.id;

    // Legacy speed/quality/communication fields are kept in sync by name so
    // the existing Rating Breakdown bars on the profile keep working as long
    // as those criteria still exist; unmatched criteria just default to 0,
    // same as before dynamic criteria existed.
    final speedC = _findCriterionByName(activeCriteria, 'speed');
    final qualityC = _findCriterionByName(activeCriteria, 'quality');
    final commC = _findCriterionByName(activeCriteria, 'communication');
    final speed = speedC == null ? 0.0 : criteriaRatings[speedC.id]!;
    final quality = qualityC == null ? 0.0 : criteriaRatings[qualityC.id]!;
    final communication = commC == null ? 0.0 : criteriaRatings[commC.id]!;

    try {
      final isUpdate = await reviewExistsInFirestore(
        customerId: user.id,
        providerId: widget.provider.id,
        orderId: effectiveOrderId,
      );
      await addReviewInFirestore(
        customer: user,
        provider: widget.provider,
        orderId: effectiveOrderId,
        relatedService: isGeneral ? null : widget.order.title,
        speedRating: speed,
        qualityRating: quality,
        communicationRating: communication,
        criteriaRatings: criteriaRatings,
        comment: _commentCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.star, color: Colors.white),
            const SizedBox(width: 8),
            Text(isUpdate
                ? l.get('review_already_exists')
                : l.get('review_submitted_successfully')),
          ]),
          backgroundColor: const Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to submit review: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Reuses the same provider Admin Review Settings uses so both surfaces
    // share one source of truth for criteria (see admin_review_management_screen.dart).
    final allCriteria = ref.watch(reviewCriteriaProvider);
    final activeCriteria = allCriteria.where((c) => c.isActive).toList();
    return Container(
      decoration: const BoxDecoration(
        color: _nBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
              color: Color(0x33000000), blurRadius: 24, offset: Offset(0, -4))
        ],
      ),
      padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 28),
      child: SingleChildScrollView(
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12, bottom: 20),
                      decoration: BoxDecoration(
                          color: _nDark,
                          borderRadius: BorderRadius.circular(2)))),
              Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFB45309)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0xFFB45309),
                          blurRadius: 0,
                          offset: Offset(0, 4)),
                      BoxShadow(
                          color: Color(0x66F59E0B),
                          blurRadius: 10,
                          offset: Offset(0, 6)),
                    ],
                  ),
                  child: const Icon(Icons.star_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.get('add_review_title'),
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF22224A))),
                  Text(widget.provider.fullName,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF9999BB))),
                ]),
              ]),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _nBg,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                        color: _nDark, blurRadius: 8, offset: Offset(4, 4)),
                    BoxShadow(
                        color: _nLight, blurRadius: 8, offset: Offset(-4, -4)),
                  ],
                ),
                child: activeCriteria.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFF7C3AED)),
                          ),
                        ),
                      )
                    : Column(children: [
                        for (final c in activeCriteria)
                          _StarRow(
                            label: c.name,
                            value: _ratingFor(c),
                            maxStars: c.maxRating,
                            onChanged: (v) =>
                                setState(() => _ratings[c.id] = v),
                          ),
                      ]),
              ),
              const SizedBox(height: 18),
              Text(l.get('your_comment'),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF22224A))),
              const SizedBox(height: 8),
              TextFormField(
                controller: _commentCtrl,
                maxLines: 4,
                style: const TextStyle(fontSize: 14, color: Color(0xFF22224A)),
                decoration: InputDecoration(
                  hintText: l.get('comment_hint'),
                  hintStyle:
                      const TextStyle(color: Color(0xFF9999BB), fontSize: 13),
                  filled: true,
                  fillColor: _nBg,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (_loading || activeCriteria.isEmpty)
                      ? null
                      : () => _submit(activeCriteria),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF052659),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    shadowColor: Colors.transparent,
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                              const Icon(Icons.send_rounded, size: 18),
                              const SizedBox(width: 8),
                              Text(l.get('send_review'),
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800)),
                            ]),
                ),
              ),
            ]),
      ),
    );
  }
}

/// Display label for a worker's specialty line: the localized name of the
/// first live/active category the worker's raw specialty values (trim +
/// lowercase, matched by id or nameKey) resolve to, plus "+N more" when
/// more than one resolves. Never a raw nameKey or a fabricated category —
/// same rule as _workerSpecialtyLabel in contractor_suppliers_screen.dart.
String _workerSpecialtyLabel(
    AppLocalizations l, List<CategoryModel> categories, WorkerModel worker) {
  final raw = worker.specialties.isNotEmpty
      ? worker.specialties
      : (worker.specialty.isNotEmpty ? [worker.specialty] : const <String>[]);
  final normalized =
      raw.map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty).toSet();
  final resolved = categories.where((c) {
    final normId = c.id.trim().toLowerCase();
    final normName = c.nameKey.trim().toLowerCase();
    return normalized.contains(normId) || normalized.contains(normName);
  }).toList();
  if (resolved.isEmpty) return '—';
  final first = l.get(resolved.first.nameKey);
  return resolved.length > 1 ? '$first +${resolved.length - 1} more' : first;
}

// ── Contractor Workers & Suppliers — read-only Firestore section ──────────────
class _ContractorWorkersSection extends ConsumerWidget {
  final String contractorId;
  const _ContractorWorkersSection({required this.contractorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final allCats =
        ref.watch(categoriesProvider).value ?? const <CategoryModel>[];
    final workersAsync = ref.watch(contractorWorkersByIdProvider(contractorId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _NeoSectionLabel(label: 'Workers & Suppliers'),
        const SizedBox(height: 10),
        workersAsync.when(
          loading: () => _NeoCard(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: const Color(0xFF7C3AED),
                  ),
                ),
              ),
            ),
          ),
          error: (e, _) {
            debugPrint('contractorWorkers load error: $e');
            return const _NeoCard(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Text('Could not load workers',
                      style: TextStyle(color: Color(0xFF9999BB), fontSize: 13)),
                ),
              ),
            );
          },
          data: (workers) => workers.isEmpty
              ? const _NeoCard(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: Text('No workers listed yet',
                          style: TextStyle(
                              color: Color(0xFF9999BB), fontSize: 13)),
                    ),
                  ),
                )
              : _NeoCard(
                  child: Column(
                    children: List.generate(
                      workers.length,
                      (i) => _NeoWorkerRow(
                        worker: workers[i],
                        isLast: i == workers.length - 1,
                        l: l,
                        specialtyLabel:
                            _workerSpecialtyLabel(l, allCats, workers[i]),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _StarRow extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final int maxStars;
  const _StarRow(
      {required this.label,
      required this.value,
      required this.onChanged,
      this.maxStars = 5});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          SizedBox(
              width: 90,
              child: Text(label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6D28D9)))),
          ...List.generate(
              maxStars,
              (i) => GestureDetector(
                    onTap: () => onChanged((i + 1).toDouble()),
                    child: Icon(
                        i < value
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: const Color(0xFFF59E0B),
                        size: 28),
                  )),
        ]),
      );
}

// ── Profile Three-Dots Button ─────────────────────────────────────────────────
class _ProfileThreeDotsBtn extends StatefulWidget {
  final bool isFav;
  final VoidCallback onFav, onFlag;
  const _ProfileThreeDotsBtn(
      {required this.isFav, required this.onFav, required this.onFlag});
  @override
  State<_ProfileThreeDotsBtn> createState() => _ProfileThreeDotsBtnState();
}

class _ProfileThreeDotsBtnState extends State<_ProfileThreeDotsBtn>
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
    final items = [
      _NeoMenuItem(
        icon: widget.isFav
            ? Icons.bookmark_rounded
            : Icons.bookmark_border_rounded,
        label: widget.isFav ? 'Unsave' : 'Save',
        color: const Color(0xFF0EA5E9),
        onTap: widget.onFav,
      ),
      _NeoMenuItem(
        icon: Icons.flag_outlined,
        label: 'Report',
        color: const Color(0xFFEF4444),
        onTap: widget.onFlag,
      ),
    ];
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.15),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        final box = context.findRenderObject() as RenderBox?;
        final pos = box?.localToGlobal(Offset.zero) ?? Offset.zero;
        final size = box?.size ?? Size.zero;
        return Stack(children: [
          Positioned.fill(
              child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(color: Colors.transparent))),
          Positioned(
            right: 16,
            top: pos.dy + size.height,
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(0.3, -0.2), end: Offset.zero)
                  .animate(curved),
              child: FadeTransition(
                  opacity: anim, child: _NeoMenuPanel(items: items)),
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
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.22), width: 1),
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
                          color: Colors.white.withOpacity(0.75),
                          shape: BoxShape.circle),
                    )),
          ),
        ),
      ),
    );
  }
}

// ── Review Three-Dots ─────────────────────────────────────────────────────────
class _ReviewThreeDots extends StatefulWidget {
  final VoidCallback onEdit, onDelete;
  const _ReviewThreeDots({required this.onEdit, required this.onDelete});
  @override
  State<_ReviewThreeDots> createState() => _ReviewThreeDotsState();
}

class _ReviewThreeDotsState extends State<_ReviewThreeDots>
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
    final items = [
      _NeoMenuItem(
          icon: Icons.edit_rounded,
          label: 'Edit',
          color: const Color(0xFF7C3AED),
          onTap: widget.onEdit),
      _NeoMenuItem(
          icon: Icons.delete_outline,
          label: 'Delete',
          color: const Color(0xFFEF4444),
          onTap: widget.onDelete),
    ];
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.15),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        final box = context.findRenderObject() as RenderBox?;
        final pos = box?.localToGlobal(Offset.zero) ?? Offset.zero;
        final size = box?.size ?? Size.zero;
        return Stack(children: [
          Positioned.fill(
              child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(color: Colors.transparent))),
          Positioned(
            right: 16,
            top: pos.dy + size.height,
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(0.3, -0.2), end: Offset.zero)
                  .animate(curved),
              child: FadeTransition(
                  opacity: anim, child: _NeoMenuPanel(items: items)),
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
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFEEEEF5),
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                  color: Color(0xFFBEBECF),
                  blurRadius: 0,
                  offset: Offset(0, 3)),
              BoxShadow(
                  color: Color(0xFFBEBECF),
                  blurRadius: 5,
                  offset: Offset(3, 3)),
              BoxShadow(
                  color: Colors.white, blurRadius: 5, offset: Offset(-3, -3)),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
                3,
                (i) => Container(
                      width: 3,
                      height: 3,
                      margin: const EdgeInsets.symmetric(vertical: 1),
                      decoration: BoxDecoration(
                          color: const Color(0xFF9999BB),
                          shape: BoxShape.circle),
                    )),
          ),
        ),
      ),
    );
  }
}

// ── Neo Menu Panel + Item (shared) ────────────────────────────────────────────
class _NeoMenuItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _NeoMenuItem(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
}

class _NeoMenuPanel extends StatefulWidget {
  final List<_NeoMenuItem> items;
  const _NeoMenuPanel({required this.items});
  @override
  State<_NeoMenuPanel> createState() => _NeoMenuPanelState();
}

class _NeoMenuPanelState extends State<_NeoMenuPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300))
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
        color: const Color(0xFFEEEEF5),
        boxShadow: const [
          BoxShadow(
              color: Color(0xFFBEBECF), blurRadius: 16, offset: Offset(6, 6)),
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
              (i / n).clamp(0.0, 1.0),
              ((i + 1) / n).clamp(0.0, 1.0),
              curve: Curves.easeOutBack,
            ),
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
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFEEEEF5),
                    boxShadow: const [
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
                  child: Icon(item.icon, color: item.color, size: 20),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Edit Review Sheet ──────────────────────────────────────────────────────────
class _EditReviewSheet extends ConsumerStatefulWidget {
  final ReviewModel review;
  const _EditReviewSheet({required this.review});
  @override
  ConsumerState<_EditReviewSheet> createState() => _EditReviewSheetState();
}

class _EditReviewSheetState extends ConsumerState<_EditReviewSheet> {
  late TextEditingController _commentCtrl;
  // Keyed by review_criteria doc id, same as _AddReviewSheet. Populated
  // lazily from the review's existing data the first time each criterion
  // is rendered (see _ratingFor), then overwritten as the user taps stars.
  final Map<String, double> _ratings = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _commentCtrl = TextEditingController(text: widget.review.comment);
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  // Prefill order: explicit criteriaRatings (reviews saved with dynamic
  // criteria) -> matching legacy speed/quality/communication field (older
  // reviews) -> a safe non-zero default for a criterion the review predates,
  // so a newly-added criterion never renders as a scary 0-star row.
  double _ratingFor(ReviewCriteriaModel c) {
    if (_ratings.containsKey(c.id)) return _ratings[c.id]!;
    final saved = widget.review.criteriaRatings[c.id];
    if (saved != null && saved > 0) return saved;
    final name = c.name.trim().toLowerCase();
    if (name == 'speed' && widget.review.speedRating > 0)
      return widget.review.speedRating;
    if (name == 'quality' && widget.review.qualityRating > 0)
      return widget.review.qualityRating;
    if ((name == 'communication' || name == 'comms') &&
        widget.review.communicationRating > 0) {
      return widget.review.communicationRating;
    }
    return c.maxRating >= 3 ? 3.0 : c.maxRating.toDouble();
  }

  void _submit(List<ReviewCriteriaModel> activeCriteria) async {
    if (_commentCtrl.text.trim().isEmpty) return;
    if (activeCriteria.isEmpty) return;
    final criteriaRatings = <String, double>{
      for (final c in activeCriteria) c.id: _ratingFor(c),
    };
    if (criteriaRatings.values.any((v) => v < 1)) return;
    setState(() => _loading = true);

    // Only touch the legacy fields when a currently-active criterion still
    // maps to that name; otherwise leave the review's existing values alone
    // (copyWith falls back to them when null is passed) so deactivating a
    // criterion doesn't silently zero out old breakdown data.
    final speedC = _findCriterionByName(activeCriteria, 'speed');
    final qualityC = _findCriterionByName(activeCriteria, 'quality');
    final commC = _findCriterionByName(activeCriteria, 'communication');

    await updateReviewInFirestore(
      widget.review.copyWith(
        speedRating: speedC == null ? null : criteriaRatings[speedC.id],
        qualityRating: qualityC == null ? null : criteriaRatings[qualityC.id],
        communicationRating: commC == null ? null : criteriaRatings[commC.id],
        criteriaRatings: criteriaRatings,
        comment: _commentCtrl.text.trim(),
      ),
    );
    // The write above succeeded (an exception would have propagated out of
    // this async function before reaching this line, skipping everything
    // below). Force providerReviewsProvider(providerId) to tear down and
    // recreate its Firestore listener so the just-saved edit is guaranteed
    // to be reflected immediately, instead of depending on the pre-existing
    // listener's own timing to redeliver it. Scoped to only this review's
    // provider — no other provider's reviews are affected.
    ref.invalidate(providerReviewsProvider(widget.review.providerId));
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.star, color: Colors.white),
          SizedBox(width: 8),
          Text('Review updated!'),
        ]),
        backgroundColor: const Color(0xFFF59E0B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final allCriteria = ref.watch(reviewCriteriaProvider);
    final activeCriteria = allCriteria.where((c) => c.isActive).toList();
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: const BoxDecoration(
        color: _nBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(color: _nDark, blurRadius: 20, offset: Offset(8, 8)),
          BoxShadow(color: _nLight, blurRadius: 20, offset: Offset(-8, -8)),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
          24, 8, 24, MediaQuery.of(context).viewInsets.bottom + 28),
      child: SingleChildScrollView(
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12, bottom: 20),
                      decoration: BoxDecoration(
                          color: _nDark,
                          borderRadius: BorderRadius.circular(2)))),
              Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: _nBg,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: _nDark, blurRadius: 8, offset: Offset(4, 4)),
                      BoxShadow(
                          color: _nLight,
                          blurRadius: 8,
                          offset: Offset(-4, -4)),
                    ],
                  ),
                  child: const Icon(Icons.edit_rounded,
                      color: Color(0xFF7C3AED), size: 22),
                ),
                const SizedBox(width: 12),
                const Text('Edit Review',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF22224A))),
              ]),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _nBg,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                        color: _nDark, blurRadius: 8, offset: Offset(4, 4)),
                    BoxShadow(
                        color: _nLight, blurRadius: 8, offset: Offset(-4, -4)),
                  ],
                ),
                child: activeCriteria.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFF7C3AED)),
                          ),
                        ),
                      )
                    : Column(children: [
                        for (final c in activeCriteria)
                          _StarRow(
                            label: c.name,
                            value: _ratingFor(c),
                            maxStars: c.maxRating,
                            onChanged: (v) =>
                                setState(() => _ratings[c.id] = v),
                          ),
                      ]),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: _nBg,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                        color: _nDark, blurRadius: 6, offset: Offset(3, 3)),
                    BoxShadow(
                        color: _nLight, blurRadius: 6, offset: Offset(-3, -3)),
                  ],
                ),
                child: TextFormField(
                  controller: _commentCtrl,
                  maxLines: 4,
                  style:
                      const TextStyle(fontSize: 14, color: Color(0xFF22224A)),
                  decoration: const InputDecoration(
                    hintText: 'Update your comment...',
                    hintStyle:
                        TextStyle(color: Color(0xFF9999BB), fontSize: 13),
                    filled: true,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(14),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: (_loading || activeCriteria.isEmpty)
                    ? null
                    : () => _submit(activeCriteria),
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF052659), Color(0xFF0A3D7A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0xFF021024),
                          blurRadius: 0,
                          offset: Offset(0, 4)),
                      BoxShadow(
                          color: Color(0x55052659),
                          blurRadius: 10,
                          offset: Offset(0, 6)),
                    ],
                  ),
                  child: Center(
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                                Icon(Icons.save_rounded,
                                    color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text('Save Changes',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white)),
                              ]),
                  ),
                ),
              ),
            ]),
      ),
    );
  }
}
