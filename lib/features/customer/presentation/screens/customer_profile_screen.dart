import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/presentation/providers/app_providers.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/shared_widgets.dart' show ProfileAvatarImage;
import '../theme/customer_design.dart';
import '../../../../shared/widgets/profile_photo_menu.dart';
import '../../../../shared/helpers/location_helper.dart';
import 'customer_orders_screen.dart';
import 'favorites_screen.dart';
import '../../../help/presentation/screens/help_center_screen.dart';
import 'complaint_sheet.dart';
import 'notifications_screen.dart';
import '../../../../shared/widgets/complaint_details_dialog.dart';
import '../../../../shared/widgets/profile_field_selectors.dart'
    show kPreferredContactHourOptions, togglePreferredContactHour;

// ── Color constants for 3D neo theme ─────────────────────────────────────────
const _bgColor = Color(0xFFEEEEF5);
const _shadowDark = Color(0xFFBEBECF);
const _shadowLight = Colors.white;

class CustomerProfileScreen extends ConsumerStatefulWidget {
  const CustomerProfileScreen({super.key});
  @override
  ConsumerState<CustomerProfileScreen> createState() =>
      _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends ConsumerState<CustomerProfileScreen> {
  bool _pickingPhoto = false;

  Future<void> _pickPhoto() async {
    final user =
        ref.read(liveCurrentUserProvider).valueOrNull ?? ref.read(authProvider);
    if (user == null || _pickingPhoto) return;
    setState(() => _pickingPhoto = true);
    try {
      await showProfilePhotoActionSheet(
        context: context,
        ref: ref,
        user: user,
        accent: const Color(0xFF7C3AED),
      );
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final user = ref.watch(liveCurrentUserProvider).valueOrNull ??
        ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final myComplaints =
        ref.watch(userComplaintsProvider(user?.id ?? '')).valueOrNull ??
            const <ComplaintModel>[];

    if (user == null) return const SizedBox();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF060F1C) : _bgColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── 3D Hero Header ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: _ProfileHeader(
              user: user,
              pickingPhoto: _pickingPhoto,
              onPickPhoto: _pickPhoto,
              onThreeDots: () => _openThreeDotsMenu(context, ref, l),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: Column(
                children: [
                  // ── Stats Row ──────────────────────────────────────
                  const _Neo3DStatsRow(),
                  const SizedBox(height: 20),

                  // ── Section label ──────────────────────────────────
                  _SectionLabel(label: 'Personal Info'),
                  const SizedBox(height: 10),

                  // ── Info card 3D ───────────────────────────────────
                  _Neo3DCard(
                    child: Column(children: [
                      _Neo3DInfoRow(
                          icon: Icons.person_rounded,
                          iconColor: const Color(0xFF7C3AED),
                          label: l.get('full_name'),
                          value: user.fullName),
                      _Neo3DDivider(),
                      _Neo3DInfoRow(
                          icon: Icons.email_rounded,
                          iconColor: const Color(0xFF0EA5E9),
                          label: l.get('email'),
                          value: user.email),
                      _Neo3DDivider(),
                      _Neo3DInfoRow(
                          icon: Icons.phone_rounded,
                          iconColor: const Color(0xFF10B981),
                          label: l.get('phone'),
                          value: user.phone),
                      _Neo3DDivider(),
                      _Neo3DInfoRow(
                          icon: Icons.location_on_rounded,
                          iconColor: const Color(0xFFF59E0B),
                          label: 'Address',
                          value: user.fullAddress.isNotEmpty
                              ? user.fullAddress
                              : '—'),
                      _Neo3DDivider(),
                      _Neo3DInfoRow(
                          icon: Icons.language_rounded,
                          iconColor: const Color(0xFF14B8A6),
                          label: 'Languages',
                          value: user.languages.isNotEmpty
                              ? user.languages.join(' · ')
                              : '—'),
                      _Neo3DDivider(),
                      _Neo3DInfoRow(
                          icon: Icons.access_time_rounded,
                          iconColor: const Color(0xFF8B5CF6),
                          label: 'Best Contact Hours',
                          value: user.preferredContactHours.isNotEmpty
                              ? user.preferredContactHours.join(' · ')
                              : '—'),
                      _Neo3DDivider(),
                      _Neo3DInfoRow(
                          icon: Icons.star_rounded,
                          iconColor: const Color(0xFFEC4899),
                          label: 'Favorite Services',
                          value: user.favoriteServices.isNotEmpty
                              ? user.favoriteServices.join(' · ')
                              : '—'),
                      _Neo3DDivider(),
                      _Neo3DInfoRow(
                          icon: Icons.calendar_today_rounded,
                          iconColor: const Color(0xFF06B6D4),
                          label: 'Member Since',
                          value:
                              '${user.joinDate.day}/${user.joinDate.month}/${user.joinDate.year}'),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  // ── Quick Actions ──────────────────────────────────
                  _SectionLabel(label: 'Quick Actions'),
                  const SizedBox(height: 10),
                  _Neo3DQuickActionsCard(
                      isDark: isDark, myComplaints: myComplaints),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openThreeDotsMenu(
      BuildContext context, WidgetRef ref, AppLocalizations l) {
    HapticFeedback.lightImpact();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 280),
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
            Positioned(
              top: MediaQuery.of(context).padding.top + 54,
              right: 16,
              child: SlideTransition(
                position: Tween<Offset>(
                        begin: const Offset(0.5, -0.3), end: Offset.zero)
                    .animate(curved),
                child: FadeTransition(
                  opacity: anim,
                  child: _ProfileNeoMenuPanel(
                    onEdit: () {
                      Navigator.pop(ctx);
                      _showEditProfile(context, ref, l);
                    },
                    onLogout: () {
                      Navigator.pop(ctx);
                      ref.read(authProvider.notifier).logout();
                      Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                          (r) => false);
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showEditProfile(
      BuildContext context, WidgetRef ref, AppLocalizations l) {
    final user = ref.read(authProvider)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 12,
          right: 12,
        ),
        child: _EditProfileSheet(
          user: user,
          l: l,
          onSave: (updated) async {
            final nav = Navigator.of(ctx);
            final messenger = ScaffoldMessenger.of(context);
            try {
              await ref
                  .read(authProvider.notifier)
                  .updateCustomerProfile(updated);
              if (!mounted) return;
              nav.pop();
              messenger.showSnackBar(
                SnackBar(
                  content: const Row(children: [
                    Icon(Icons.check_circle_rounded, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Profile updated'),
                  ]),
                  backgroundColor: const Color(0xFF0A1F4E),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              );
            } catch (e) {
              debugPrint('[CustomerProfile] Firestore update error: $e');
              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(
                  content: const Row(children: [
                    Icon(Icons.error_rounded, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Failed to save. Please try again.'),
                  ]),
                  backgroundColor: const Color(0xFFEF4444),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  void _showAbout(BuildContext context, AppLocalizations l) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        title: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [CustomerColors.dark, CustomerColors.mid],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Center(
              child: Text('S',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Text(l.get('app_name'),
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: CustomerColors.darkest)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: CustomerColors.lightest,
                  borderRadius: BorderRadius.circular(8)),
              child: const Text('Version: 1.0.0',
                  style: TextStyle(
                      color: CustomerColors.dark,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 12),
            Text(l.get('app_about_text'),
                style: const TextStyle(
                    fontSize: 14, height: 1.6, color: CustomerColors.dark)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.get('cancel'),
                style: const TextStyle(
                    color: CustomerColors.dark, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── 3D Profile Header ─────────────────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  final UserModel user;
  final bool pickingPhoto;
  final VoidCallback onPickPhoto;
  final VoidCallback onThreeDots;
  const _ProfileHeader({
    required this.user,
    required this.pickingPhoto,
    required this.onPickPhoto,
    required this.onThreeDots,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        // Same gradient language as the Customer Home header (see
        // CustomerFeedScreen's "Premium Dark Header").
        gradient: LinearGradient(
          colors: [
            CustomerColors.darkest,
            Color(0xFF0A1F4E),
            CustomerColors.dark,
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
              color: Color(0x40021024), blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      child: Stack(
        children: [
          // Ambient glow orb top-right
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF7C3AED).withOpacity(0.22),
                    Colors.transparent
                  ],
                ),
              ),
            ),
          ),
          // Ambient glow orb bottom-left
          Positioned(
            bottom: -20,
            left: -20,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF0EA5E9).withOpacity(0.18),
                    Colors.transparent
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
              child: Column(
                children: [
                  // Top row
                  Row(children: [
                    // PROFILE label
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MY PROFILE',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.45),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Account',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ]),
                    const Spacer(),
                    // 3-dot menu button — same style as orders screen
                    _NeoHeaderButton(
                      onTap: onThreeDots,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                            3,
                            (i) => Container(
                                  width: 4,
                                  height: 4,
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 1.5),
                                  decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle),
                                )),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 28),

                  // Avatar + info row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ── 3D Avatar ──────────────────────────────────
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Outer glow ring
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFF7C3AED).withOpacity(0.55),
                                  blurRadius: 22,
                                  offset: const Offset(0, 10),
                                ),
                                BoxShadow(
                                  color:
                                      const Color(0xFF4C1D95).withOpacity(0.9),
                                  blurRadius: 0,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF7C3AED),
                                    Color(0xFF4C1D95)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.28),
                                    width: 2),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: Stack(children: [
                                  // Content
                                  ProfileAvatarImage(
                                    imageUrl: user.avatar,
                                    size: 96,
                                    borderRadius: 28,
                                    fallbackText: user.fullName.isNotEmpty
                                        ? user.fullName
                                        : 'U',
                                    fallbackTextStyle: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 42,
                                        fontWeight: FontWeight.w900),
                                  ),
                                  // Glass shine
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      height: 48,
                                      decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(28),
                                          topRight: Radius.circular(28),
                                        ),
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
                                ]),
                              ),
                            ),
                          ),
                          // Camera button
                          Positioned(
                            bottom: -4,
                            right: -4,
                            child: GestureDetector(
                              onTap: pickingPhoto ? null : onPickPhoto,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF0EA5E9),
                                      Color(0xFF0369A1)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                        color: const Color(0xFF0369A1)
                                            .withOpacity(0.7),
                                        blurRadius: 0,
                                        offset: const Offset(0, 3)),
                                    BoxShadow(
                                        color: const Color(0xFF0EA5E9)
                                            .withOpacity(0.45),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4)),
                                  ],
                                ),
                                child: Center(
                                  child: pickingPhoto
                                      ? const SizedBox(
                                          width: 13,
                                          height: 13,
                                          child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2))
                                      : const Icon(Icons.camera_alt_rounded,
                                          color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(width: 18),

                      // ── Name + email + badge ────────────────────────
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.fullName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 5),
                            // Email pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 1),
                              ),
                              child: Text(
                                user.email,
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Premium badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFF59E0B),
                                    Color(0xFFB45309)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                      color: const Color(0xFFF59E0B)
                                          .withOpacity(0.45),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4)),
                                  const BoxShadow(
                                      color: Color(0xFFB45309),
                                      blurRadius: 0,
                                      offset: Offset(0, 3)),
                                ],
                              ),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded,
                                        color: Colors.white, size: 11),
                                    const SizedBox(width: 4),
                                    const Text('Premium Customer',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800)),
                                  ]),
                            ),
                          ],
                        ),
                      ),
                    ],
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

// ── Header neo button ─────────────────────────────────────────────────────────
class _NeoHeaderButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _NeoHeaderButton({required this.child, required this.onTap});

  @override
  State<_NeoHeaderButton> createState() => _NeoHeaderButtonState();
}

class _NeoHeaderButtonState extends State<_NeoHeaderButton>
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
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) =>
            Transform.scale(scale: 1.0 - 0.07 * _ctrl.value, child: child),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: Colors.white.withOpacity(0.28), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 0,
                  offset: const Offset(0, 3)),
              BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(3, 4)),
              BoxShadow(
                  color: Colors.white.withOpacity(0.1),
                  blurRadius: 5,
                  offset: const Offset(-2, -2)),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ── Section Label ─────────────────────────────────────────────────────────────
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
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF444466),
                letterSpacing: 1.5)),
      ]);
}

// ── 3D Stats Row ──────────────────────────────────────────────────────────────
class _Neo3DStatsRow extends ConsumerWidget {
  const _Neo3DStatsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Live Firestore orders for the authenticated Customer — replaces the
    // previous ordersProvider-derived count, which read DummyData.orders
    // (ordersProvider is seeded with DummyData.orders and never repopulated
    // by the real order flow, which writes through
    // customerFirestoreOrdersProvider instead) and matched by a
    // customerId-or-customerName fallback that only worked by coincidence
    // for the demo user.
    final orders = ref.watch(customerFirestoreOrdersProvider).valueOrNull ??
        const <OrderModel>[];
    final total = orders.length;
    final completed =
        orders.where((o) => o.status == OrderStatus.completed).length;
    final inProgress =
        orders.where((o) => o.status == OrderStatus.inProgress).length;

    return Row(
      children: [
        _Neo3DStatCard(
            icon: Icons.receipt_long_rounded,
            value: '$total',
            label: 'Orders',
            colors: [const Color(0xFF7C3AED), const Color(0xFF4C1D95)]),
        const SizedBox(width: 10),
        _Neo3DStatCard(
            icon: Icons.check_circle_rounded,
            value: '$completed',
            label: 'Completed',
            colors: [const Color(0xFF10B981), const Color(0xFF065F46)]),
        const SizedBox(width: 10),
        _Neo3DStatCard(
            icon: Icons.autorenew_rounded,
            value: '$inProgress',
            label: 'In Progress',
            colors: [const Color(0xFF0EA5E9), const Color(0xFF0369A1)]),
      ],
    );
  }
}

class _Neo3DStatCard extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final List<Color> colors;
  const _Neo3DStatCard(
      {required this.icon,
      required this.value,
      required this.label,
      required this.colors});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: _shadowDark, blurRadius: 0, offset: Offset(0, 5)),
            BoxShadow(color: _shadowDark, blurRadius: 12, offset: Offset(5, 5)),
            BoxShadow(
                color: _shadowLight, blurRadius: 12, offset: Offset(-5, -5)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: colors[0].withOpacity(0.45),
                      blurRadius: 10,
                      offset: const Offset(0, 5)),
                  BoxShadow(
                      color: colors[1].withOpacity(0.9),
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
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  foreground: Paint()
                    ..shader = LinearGradient(colors: colors)
                        .createShader(const Rect.fromLTWH(0, 0, 80, 30)),
                )),
            const SizedBox(height: 3),
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF8888AA),
                    fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── 3D Card container ─────────────────────────────────────────────────────────
class _Neo3DCard extends StatelessWidget {
  final Widget child;
  const _Neo3DCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(color: _shadowDark, blurRadius: 0, offset: Offset(0, 6)),
            BoxShadow(color: _shadowDark, blurRadius: 16, offset: Offset(6, 6)),
            BoxShadow(
                color: _shadowLight, blurRadius: 16, offset: Offset(-6, -6)),
          ],
        ),
        child: child,
      );
}

// ── 3D Info Row ───────────────────────────────────────────────────────────────
class _Neo3DInfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label, value;
  const _Neo3DInfoRow(
      {required this.icon,
      required this.iconColor,
      required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) {
    final c2 = Color.lerp(iconColor, Colors.black, 0.35)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [iconColor, c2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(13),
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
            Center(child: Icon(icon, color: Colors.white, size: 18)),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9999BB),
                    letterSpacing: 0.5)),
            const SizedBox(height: 3),
            Text(value,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF22224A)),
                overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }
}

class _Neo3DDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: const EdgeInsets.only(left: 70, right: 16),
        color: _shadowDark.withOpacity(0.5),
      );
}

// ── 3D Action Tile ────────────────────────────────────────────────────────────
class _Neo3DActionTile extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  const _Neo3DActionTile(
      {required this.icon,
      required this.iconColor,
      required this.label,
      required this.onTap,
      this.isDestructive = false});
  @override
  State<_Neo3DActionTile> createState() => _Neo3DActionTileState();
}

class _Neo3DActionTileState extends State<_Neo3DActionTile>
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
    final c2 = Color.lerp(widget.iconColor, Colors.black, 0.35)!;
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
            Transform.scale(scale: 1.0 - 0.03 * _ctrl.value, child: child),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [widget.iconColor, c2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(13),
                boxShadow: [
                  BoxShadow(
                      color: widget.iconColor.withOpacity(0.45),
                      blurRadius: 8,
                      offset: const Offset(0, 4)),
                  BoxShadow(
                      color: c2.withOpacity(0.9),
                      blurRadius: 0,
                      offset: const Offset(0, 3)),
                ],
              ),
              child: Icon(widget.icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Text(widget.label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: widget.isDestructive
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF22224A)))),
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: _bgColor,
                borderRadius: BorderRadius.all(Radius.circular(10)),
                boxShadow: [
                  BoxShadow(
                      color: _shadowDark, blurRadius: 0, offset: Offset(0, 3)),
                  BoxShadow(
                      color: _shadowDark, blurRadius: 5, offset: Offset(3, 3)),
                  BoxShadow(
                      color: _shadowLight,
                      blurRadius: 5,
                      offset: Offset(-3, -3)),
                ],
              ),
              child: Icon(Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: widget.isDestructive
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF7777AA)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── 3D Quick Actions Card ─────────────────────────────────────────────────────
class _Neo3DQuickActionsCard extends ConsumerWidget {
  final bool isDark;
  final List<ComplaintModel> myComplaints;
  const _Neo3DQuickActionsCard(
      {required this.isDark, required this.myComplaints});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final unseenOrders = ref.watch(customerUnseenOrdersCountProvider);
    final unreadNotifications = user == null
        ? 0
        : ref.watch(unreadNotificationsCountProvider(
            (userId: user.id, role: UserRole.customer)));
    final actions = [
      _QAction(
          icon: Icons.receipt_long_rounded,
          label: 'My Orders',
          color: const Color(0xFF7C3AED),
          badge: unseenOrders,
          onTap: () {
            ref.read(navIndexProvider.notifier).state = 2;
            Navigator.of(context).popUntil((r) => r.isFirst);
          }),
      _QAction(
          icon: Icons.favorite_rounded,
          label: 'Favorites',
          color: const Color(0xFFE11D48),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const FavoritesScreen()))),
      _QAction(
          icon: Icons.flag_rounded,
          label: myComplaints.isNotEmpty
              ? 'Complaints (${myComplaints.length})'
              : 'Complaints',
          color: const Color(0xFFF59E0B),
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const CustomerComplaintsScreen()))),
      _QAction(
          icon: Icons.notifications_rounded,
          label: 'Notifications',
          badge: unreadNotifications,
          color: const Color(0xFF8B5CF6),
          onTap: () => Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, animation, __) =>
                    _ProfileNotificationsWrapper(),
                transitionsBuilder: (_, anim, __, child) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(1.0, 0.0), end: Offset.zero)
                        .animate(CurvedAnimation(
                            parent: anim, curve: Curves.easeOutCubic)),
                    child: child,
                  ),
                ),
                transitionDuration: const Duration(milliseconds: 320),
              ))),
      _QAction(
          icon: Icons.help_rounded,
          label: 'Help',
          color: const Color(0xFF059669),
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const HelpCenterScreen(
                      userRole: UserRole.customer,
                      accentColor: Color(0xFF3B82F6),
                      gradientStart: CustomerColors.darkest,
                      gradientMid: Color(0xFF0A1F4E),
                      gradientEnd: CustomerColors.dark)))),
    ];

    return _Neo3DCard(
      child: Column(
        children: actions.map((a) {
          final isLast = a == actions.last;
          return Column(children: [
            _Neo3DQuickTile(action: a),
            if (!isLast) _Neo3DDivider(),
          ]);
        }).toList(),
      ),
    );
  }
}

class _QAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final int badge;
  const _QAction(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap,
      this.badge = 0});
  bool operator ==(Object other) => other is _QAction && other.label == label;
  int get hashCode => label.hashCode;
}

class _Neo3DQuickTile extends StatefulWidget {
  final _QAction action;
  const _Neo3DQuickTile({required this.action});
  @override
  State<_Neo3DQuickTile> createState() => _Neo3DQuickTileState();
}

class _Neo3DQuickTileState extends State<_Neo3DQuickTile>
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
    final c = widget.action;
    final c2 = Color.lerp(c.color, Colors.black, 0.35)!;
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        _ctrl.forward();
      },
      onTapUp: (_) {
        _ctrl.reverse();
        c.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) =>
            Transform.scale(scale: 1.0 - 0.025 * _ctrl.value, child: child),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [c.color, c2],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                          color: c.color.withOpacity(0.45),
                          blurRadius: 8,
                          offset: const Offset(0, 4)),
                      BoxShadow(
                          color: c2.withOpacity(0.9),
                          blurRadius: 0,
                          offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Icon(c.icon, color: Colors.white, size: 18),
                ),
                if (c.badge > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF4444),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          c.badge > 9 ? '9+' : '${c.badge}',
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
            const SizedBox(width: 14),
            Expanded(
                child: Text(c.label,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF22224A)))),
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: _bgColor,
                borderRadius: BorderRadius.all(Radius.circular(10)),
                boxShadow: [
                  BoxShadow(
                      color: _shadowDark, blurRadius: 0, offset: Offset(0, 3)),
                  BoxShadow(
                      color: _shadowDark, blurRadius: 5, offset: Offset(3, 3)),
                  BoxShadow(
                      color: _shadowLight,
                      blurRadius: 5,
                      offset: Offset(-3, -3)),
                ],
              ),
              child: const Icon(Icons.arrow_forward_ios_rounded,
                  size: 12, color: Color(0xFF7777AA)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Customer Complaints Full Screen ──────────────────────────────────────────

// ══════════════════════════════════════════════════════════════════════════════
// ── My Complaints Screen ──────────────────────────────────────────────────────
// ══════════════════════════════════════════════════════════════════════════════

class CustomerComplaintsScreen extends ConsumerStatefulWidget {
  // Set from a notification tap so the matching complaint's tab is
  // auto-selected and its card is visually highlighted on open.
  final String? highlightComplaintId;
  const CustomerComplaintsScreen({super.key, this.highlightComplaintId});
  @override
  ConsumerState<CustomerComplaintsScreen> createState() =>
      _CustomerComplaintsScreenState();
}

class _CustomerComplaintsScreenState
    extends ConsumerState<CustomerComplaintsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _tabAnim;
  int _selectedTab = 0; // 0 = Pending, 1 = Resolved, 2 = Rejected
  bool _initialComplaintOpened = false;

  @override
  void initState() {
    super.initState();
    _tabAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400))
      ..forward();
  }

  @override
  void dispose() {
    _tabAnim.dispose();
    super.dispose();
  }

  void _openNewComplaintSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 12,
            right: 12),
        child: const _NewComplaintNeoSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final complaintsAsync = ref.watch(userComplaintsProvider(user?.id ?? ''));
    final loading =
        complaintsAsync.isLoading && complaintsAsync.valueOrNull == null;
    final hasError = complaintsAsync.hasError;
    final all = complaintsAsync.valueOrNull ?? const <ComplaintModel>[];
    final pending = all
        .where((c) =>
            c.status == ComplaintStatus.open ||
            c.status == ComplaintStatus.inReview)
        .toList();
    final resolved =
        all.where((c) => c.status == ComplaintStatus.resolved).toList();
    final rejected =
        all.where((c) => c.status == ComplaintStatus.rejected).toList();

    // A notification tap may pass a specific complaint to open — jump to
    // whichever tab it lives in and auto-open its details dialog once, the
    // first time it shows up in the stream, so the user's own later tab taps
    // and dialog opens/closes aren't overridden.
    if (widget.highlightComplaintId != null && !_initialComplaintOpened) {
      final match =
          all.where((c) => c.id == widget.highlightComplaintId).toList();
      if (match.isNotEmpty) {
        _initialComplaintOpened = true;
        final matchedComplaint = match.first;
        final targetTab = matchedComplaint.status == ComplaintStatus.resolved
            ? 1
            : matchedComplaint.status == ComplaintStatus.rejected
                ? 2
                : 0;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (targetTab != _selectedTab) {
            setState(() => _selectedTab = targetTab);
          }
          showComplaintDetailsDialog(context, matchedComplaint,
              accentColor: CustomerColors.dark);
        });
      }
    }

    final list = _selectedTab == 0
        ? pending
        : _selectedTab == 1
            ? resolved
            : rejected;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F6FF),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Header ──────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 130,
            backgroundColor: CustomerColors.dark,
            foregroundColor: Colors.white,
            elevation: 0,
            automaticallyImplyLeading: false,
            leading: _ComplaintsNeoBackBtn(),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 14, top: 8, bottom: 8),
                child: _ComplaintsNewBtn(onTap: _openNewComplaintSheet),
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
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1),
                            ),
                            child: const Icon(Icons.flag_rounded,
                                color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Text('My Complaints',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5)),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Pill tab selector ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: _ComplaintsStepBar(
                selectedIndex: _selectedTab,
                pendingCount: pending.length,
                resolvedCount: resolved.length,
                rejectedCount: rejected.length,
                onTap: (i) => setState(() {
                  _selectedTab = i;
                  _tabAnim.forward(from: 0);
                }),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── List ─────────────────────────────────────────────────────
          if (loading)
            const SliverFillRemaining(
              child: Center(
                  child: CircularProgressIndicator(color: CustomerColors.dark)),
            )
          else if (hasError)
            SliverFillRemaining(
              child: Center(
                child: Text('Failed to load complaints',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF555577))),
              ),
            )
          else if (list.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEEEEF5),
                          borderRadius: BorderRadius.all(Radius.circular(26)),
                          boxShadow: [
                            BoxShadow(
                                color: Color(0xFFBEBECF),
                                blurRadius: 10,
                                offset: Offset(5, 5)),
                            BoxShadow(
                                color: Colors.white,
                                blurRadius: 10,
                                offset: Offset(-5, -5)),
                          ],
                        ),
                        child: Icon(
                          _selectedTab == 0
                              ? Icons.flag_outlined
                              : _selectedTab == 1
                                  ? Icons.history_rounded
                                  : Icons.cancel_outlined,
                          size: 36,
                          color: const Color(0xFF9999BB),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _selectedTab == 0
                            ? 'No pending complaints'
                            : _selectedTab == 1
                                ? 'No resolved complaints'
                                : 'No rejected complaints',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF555577)),
                      ),
                    ]),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _ComplaintNeo3DCard(
                    complaint: list[i],
                    highlighted: list[i].id == widget.highlightComplaintId,
                  ),
                  childCount: list.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// ── Pill-Style Tab Bar (Pending ↔ Resolved) ────────────────────────────────────
class _ComplaintsStepBar extends StatefulWidget {
  final int selectedIndex;
  final int pendingCount;
  final int resolvedCount;
  final int rejectedCount;
  final void Function(int) onTap;
  const _ComplaintsStepBar({
    required this.selectedIndex,
    required this.pendingCount,
    required this.resolvedCount,
    required this.rejectedCount,
    required this.onTap,
  });
  @override
  State<_ComplaintsStepBar> createState() => _ComplaintsStepBarState();
}

class _ComplaintsStepBarState extends State<_ComplaintsStepBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideCtrl;
  late Animation<double> _slideAnim;
  int _prevIndex = 0;

  static const _tabData = [
    _CTabData(
        label: 'Pending',
        icon: Icons.hourglass_top_rounded,
        activeColor: Color(0xFFF59E0B),
        darkColor: Color(0xFFB45309)),
    _CTabData(
        label: 'Resolved',
        icon: Icons.check_circle_outline_rounded,
        activeColor: Color(0xFF10B981),
        darkColor: Color(0xFF065F46)),
    _CTabData(
        label: 'Rejected',
        icon: Icons.cancel_outlined,
        activeColor: Color(0xFFEF4444),
        darkColor: Color(0xFF991B1B)),
  ];

  @override
  void initState() {
    super.initState();
    _prevIndex = widget.selectedIndex;
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _slideAnim =
        CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic);
  }

  @override
  void didUpdateWidget(_ComplaintsStepBar old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex != widget.selectedIndex) {
      _prevIndex = old.selectedIndex;
      _slideCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final counts = [
      widget.pendingCount,
      widget.resolvedCount,
      widget.rejectedCount
    ];

    return Container(
      height: 56,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEF5),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
              color: Color(0xFFBEBECF), blurRadius: 0, offset: Offset(0, 5)),
          BoxShadow(
              color: Color(0xFFBEBECF), blurRadius: 14, offset: Offset(6, 6)),
          BoxShadow(
              color: Colors.white, blurRadius: 14, offset: Offset(-6, -6)),
        ],
      ),
      child: Row(
        children: List.generate(3, (i) {
          final isActive = widget.selectedIndex == i;
          final tab = _tabData[i];

          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onTap(i);
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
                              color: Color(0xFFBEBECF),
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
                    // Animated icon container
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      width: isActive ? 28 : 22,
                      height: isActive ? 28 : 22,
                      decoration: BoxDecoration(
                        gradient: isActive
                            ? LinearGradient(
                                colors: [tab.activeColor, tab.darkColor],
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
                                    color: tab.darkColor,
                                    blurRadius: 0,
                                    offset: const Offset(0, 2)),
                              ]
                            : [],
                      ),
                      child: Center(
                          child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          tab.icon,
                          key: ValueKey(isActive),
                          size: isActive ? 15 : 13,
                          color:
                              isActive ? Colors.white : const Color(0xFF9999BB),
                        ),
                      )),
                    ),
                    const SizedBox(width: 7),
                    // Label
                    Flexible(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 220),
                        style: TextStyle(
                          fontSize: isActive ? 13 : 12,
                          fontWeight:
                              isActive ? FontWeight.w800 : FontWeight.w600,
                          color: isActive
                              ? const Color(0xFF22224A)
                              : const Color(0xFF9999BB),
                          letterSpacing: -0.2,
                        ),
                        child: Text(tab.label,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    // Count badge
                    if (counts[i] > 0) ...[
                      const SizedBox(width: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isActive
                              ? tab.activeColor
                              : const Color(0xFFBEBECF),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                      color: tab.activeColor.withOpacity(0.4),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2)),
                                  BoxShadow(
                                      color: tab.darkColor,
                                      blurRadius: 0,
                                      offset: const Offset(0, 2))
                                ]
                              : [],
                        ),
                        child: Text(
                          '${counts[i]}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isActive
                                ? Colors.white
                                : const Color(0xFF666688),
                          ),
                        ),
                      ),
                    ],
                  ]),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _CTabData {
  final String label;
  final IconData icon;
  final Color activeColor, darkColor;
  const _CTabData(
      {required this.label,
      required this.icon,
      required this.activeColor,
      required this.darkColor});
}

// ── Neo Back Button ───────────────────────────────────────────────────────────
class _ComplaintsNeoBackBtn extends StatefulWidget {
  @override
  State<_ComplaintsNeoBackBtn> createState() => _ComplaintsNeoBackBtnState();
}

class _ComplaintsNeoBackBtnState extends State<_ComplaintsNeoBackBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 110));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          _c.forward();
        },
        onTapUp: (_) {
          _c.reverse();
          Navigator.of(context).pop();
        },
        onTapCancel: () => _c.reverse(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, child) =>
                Transform.scale(scale: 1.0 - 0.08 * _c.value, child: child),
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

// ── Neo + New Button (matching image style) ───────────────────────────────────
class _ComplaintsNewBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _ComplaintsNewBtn({required this.onTap});
  @override
  State<_ComplaintsNewBtn> createState() => _ComplaintsNewBtnState();
}

class _ComplaintsNewBtnState extends State<_ComplaintsNewBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 110));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          _c.forward();
        },
        onTapUp: (_) {
          _c.reverse();
          widget.onTap();
        },
        onTapCancel: () => _c.reverse(),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.08 * _c.value, child: child),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFEEEEF5),
              borderRadius: BorderRadius.circular(14),
              // Neomorphism 3D — matches the example image buttons
              boxShadow: const [
                BoxShadow(
                    color: Color(0xFFBEBECF),
                    blurRadius: 0,
                    offset: Offset(0, 4)),
                BoxShadow(
                    color: Color(0xFFBEBECF),
                    blurRadius: 8,
                    offset: Offset(4, 4)),
                BoxShadow(
                    color: Colors.white, blurRadius: 8, offset: Offset(-4, -4)),
              ],
              border:
                  Border.all(color: Colors.white.withOpacity(0.9), width: 1),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: Color(0xFF5555AA), size: 16),
                SizedBox(width: 5),
                Text('New',
                    style: TextStyle(
                        color: Color(0xFF5555AA),
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      );
}

// ── 3D Complaint Card ─────────────────────────────────────────────────────────
class _ComplaintNeo3DCard extends ConsumerStatefulWidget {
  final ComplaintModel complaint;
  final bool highlighted;
  const _ComplaintNeo3DCard(
      {required this.complaint, this.highlighted = false});
  @override
  ConsumerState<_ComplaintNeo3DCard> createState() =>
      _ComplaintNeo3DCardState();
}

class _ComplaintNeo3DCardState extends ConsumerState<_ComplaintNeo3DCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _dotsCtrl;

  static const _statusColors = {
    ComplaintStatus.open: Color(0xFFF59E0B),
    ComplaintStatus.inReview: Color(0xFF0EA5E9),
    ComplaintStatus.resolved: Color(0xFF10B981),
    ComplaintStatus.rejected: Color(0xFFEF4444),
    ComplaintStatus.deleted: Color(0xFF9999BB),
  };
  static const _statusLabels = {
    ComplaintStatus.open: 'Pending',
    ComplaintStatus.inReview: 'In Review',
    ComplaintStatus.resolved: 'Resolved',
    ComplaintStatus.rejected: 'Rejected',
    ComplaintStatus.deleted: 'Deleted',
  };

  bool get _canEditOrDelete =>
      widget.complaint.status == ComplaintStatus.open ||
      widget.complaint.status == ComplaintStatus.inReview;

  @override
  void initState() {
    super.initState();
    _dotsCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
  }

  @override
  void dispose() {
    _dotsCtrl.dispose();
    super.dispose();
  }

  void _openDotsMenu() {
    HapticFeedback.lightImpact();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        final box = context.findRenderObject() as RenderBox?;
        final pos = box?.localToGlobal(Offset.zero);
        return Stack(children: [
          Positioned.fill(
              child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(color: Colors.transparent))),
          Positioned(
            top: (pos?.dy ?? 200) + 10,
            right: 20,
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(0.4, -0.2), end: Offset.zero)
                  .animate(curved),
              child: FadeTransition(
                opacity: anim,
                child: _ComplaintDotsPanel(
                  onEdit: () {
                    Navigator.pop(ctx);
                    _openEditSheet();
                  },
                  onDelete: () {
                    Navigator.pop(ctx);
                    _confirmDelete();
                  },
                ),
              ),
            ),
          ),
        ]);
      },
    );
  }

  void _openEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 12,
            right: 12),
        child: _NewComplaintNeoSheet(existing: widget.complaint),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Complaint',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Are you sure you want to delete this complaint?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: CustomerColors.mid)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await softDeleteComplaintInFirestore(widget.complaint.id);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Failed to delete complaint: $e')));
                }
              }
            },
            child: const Text('Delete',
                style: TextStyle(
                    color: Color(0xFFEF4444), fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.complaint;
    final color = _statusColors[c.status] ?? CustomerColors.mid;
    final label = _statusLabels[c.status] ?? '';
    final darkColor = Color.lerp(color, Colors.black, 0.35)!;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showComplaintDetailsDialog(context, c,
          accentColor: CustomerColors.dark),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFEEEEF5),
          borderRadius: const BorderRadius.all(Radius.circular(24)),
          border: widget.highlighted
              ? Border.all(color: CustomerColors.dark, width: 2.5)
              : null,
          boxShadow: const [
            BoxShadow(
                color: Color(0xFFBEBECF), blurRadius: 0, offset: Offset(0, 6)),
            BoxShadow(
                color: Color(0xFFBEBECF), blurRadius: 14, offset: Offset(6, 6)),
            BoxShadow(
                color: Colors.white, blurRadius: 14, offset: Offset(-6, -6)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Header row ─────────────────────────────────────────────
            Row(children: [
              // Icon 3D gradient
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [color, darkColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: color.withOpacity(0.45),
                        blurRadius: 8,
                        offset: const Offset(0, 4)),
                    BoxShadow(
                        color: darkColor.withOpacity(0.9),
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
                              Colors.white.withOpacity(0.22),
                              Colors.transparent
                            ]),
                      ),
                    ),
                  ),
                  const Center(
                      child: Icon(Icons.flag_rounded,
                          color: Colors.white, size: 20)),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.reason,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF222244))),
                      const SizedBox(height: 3),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEEEF5),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0xFFBEBECF),
                                blurRadius: 4,
                                offset: Offset(2, 2)),
                            BoxShadow(
                                color: Colors.white,
                                blurRadius: 4,
                                offset: Offset(-2, -2)),
                          ],
                        ),
                        child: Text(label,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: color)),
                      ),
                    ]),
              ),
              // 3-dot menu button (only when the complaint can still be edited/deleted)
              if (_canEditOrDelete)
                GestureDetector(
                  onTapDown: (_) {
                    HapticFeedback.lightImpact();
                    _dotsCtrl.forward();
                  },
                  onTapUp: (_) {
                    _dotsCtrl.reverse();
                    _openDotsMenu();
                  },
                  onTapCancel: () => _dotsCtrl.reverse(),
                  child: AnimatedBuilder(
                    animation: _dotsCtrl,
                    builder: (_, child) => Transform.scale(
                        scale: 1.0 - 0.08 * _dotsCtrl.value, child: child),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEEEEF5),
                        borderRadius: BorderRadius.all(Radius.circular(12)),
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                            3,
                            (i) => Container(
                                  width: 4,
                                  height: 4,
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 1.5),
                                  decoration: const BoxDecoration(
                                      color: Color(0xFF7777AA),
                                      shape: BoxShape.circle),
                                )),
                      ),
                    ),
                  ),
                ),
            ]),

            // ── Related ─────────────────────────────────────────────────
            if (c.targetName != null) ...[
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.link_rounded,
                    size: 13, color: Color(0xFF9999BB)),
                const SizedBox(width: 5),
                Text('Related to: ${c.targetName}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9999BB),
                        fontWeight: FontWeight.w600)),
              ]),
            ],

            const SizedBox(height: 10),
            // ── Description ─────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEEEEF5),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0xFFBEBECF),
                      blurRadius: 4,
                      offset: Offset(2, 2)),
                  BoxShadow(
                      color: Colors.white,
                      blurRadius: 4,
                      offset: Offset(-2, -2)),
                ],
              ),
              child: Text(c.description,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF555577), height: 1.5),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
            ),

            const SizedBox(height: 10),
            // ── Date ────────────────────────────────────────────────────
            Row(children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Color(0xFFEEEEF5),
                  borderRadius: BorderRadius.all(Radius.circular(9)),
                  boxShadow: [
                    BoxShadow(
                        color: Color(0xFFBEBECF),
                        blurRadius: 4,
                        offset: Offset(2, 2)),
                    BoxShadow(
                        color: Colors.white,
                        blurRadius: 4,
                        offset: Offset(-2, -2)),
                  ],
                ),
                child: const Icon(Icons.calendar_today_rounded,
                    size: 13, color: Color(0xFF9999BB)),
              ),
              const SizedBox(width: 8),
              Text(
                  '${c.createdAt.day}/${c.createdAt.month}/${c.createdAt.year}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9999BB),
                      fontWeight: FontWeight.w600)),
            ]),

            // ── Admin reply ─────────────────────────────────────────────
            if (c.replyText != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF065F46)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    const BoxShadow(
                        color: Color(0xFF065F46),
                        blurRadius: 0,
                        offset: Offset(0, 3)),
                    BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.reply_rounded,
                          size: 16, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(c.replyText!,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  height: 1.4))),
                    ]),
              ),
            ],
            // ── Admin note ──────────────────────────────────────────────
            if (c.adminNote != null && c.adminNote!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEEEF5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFF0EA5E9).withOpacity(0.3)),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0xFFBEBECF),
                        blurRadius: 4,
                        offset: Offset(2, 2)),
                    BoxShadow(
                        color: Colors.white,
                        blurRadius: 4,
                        offset: Offset(-2, -2)),
                  ],
                ),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.sticky_note_2_outlined,
                          size: 16, color: Color(0xFF0EA5E9)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(c.adminNote!,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF555577),
                                  height: 1.4))),
                    ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

// ── Complaint Dots Panel (same style as orders) ───────────────────────────────
class _ComplaintDotsPanel extends StatefulWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _ComplaintDotsPanel({required this.onEdit, required this.onDelete});
  @override
  State<_ComplaintDotsPanel> createState() => _ComplaintDotsPanelState();
}

class _ComplaintDotsPanelState extends State<_ComplaintDotsPanel>
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
    final items = [
      (Icons.edit_rounded, const Color(0xFF7C3AED), widget.onEdit),
      (Icons.delete_rounded, const Color(0xFFEF4444), widget.onDelete),
    ];
    return Container(
      width: 68,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
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
        children: List.generate(items.length, (i) {
          final (icon, color, onTap) = items[i];
          final anim = CurvedAnimation(
            parent: _ctrl,
            curve: Interval((i / items.length).clamp(0.0, 1.0),
                ((i + 1) / items.length).clamp(0.0, 1.0),
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
                onTap: onTap,
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
                  child: Icon(icon, color: color, size: 22),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── New / Edit Complaint Sheet (request_category style) ───────────────────────
class _NewComplaintNeoSheet extends ConsumerStatefulWidget {
  final ComplaintModel? existing;
  const _NewComplaintNeoSheet({this.existing});
  @override
  ConsumerState<_NewComplaintNeoSheet> createState() =>
      _NewComplaintNeoSheetState();
}

class _NewComplaintNeoSheetState extends ConsumerState<_NewComplaintNeoSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descCtrl;
  String? _selectedReason;
  bool _loading = false;

  static const _reasons = [
    'Customer Behavior',
    'Payment Issue',
    'Platform Problem',
    'Incorrect Order Info',
    'Service Quality',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(text: widget.existing?.description ?? '');
    _selectedReason = widget.existing?.reason;
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Please select a reason'),
        backgroundColor: CustomerColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    setState(() => _loading = true);
    final user = ref.read(authProvider);

    try {
      if (widget.existing != null) {
        // Edit mode
        await updateComplaintInFirestore(
          widget.existing!.copyWith(
              reason: _selectedReason!, description: _descCtrl.text.trim()),
        );
      } else {
        // New mode
        await addComplaintInFirestore(ComplaintModel(
          id: '',
          userId: user?.id ?? 'current_user',
          userName: user?.fullName ?? 'User',
          complainantRole: 'customer',
          type: ComplaintType.general,
          targetId: 'general',
          targetName: 'General',
          reason: _selectedReason!,
          description: _descCtrl.text.trim(),
          sourceContext: 'my_complaints',
          createdAt: DateTime.now(),
        ));
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(widget.existing != null
                ? 'Complaint updated'
                : 'Complaint submitted'),
          ]),
          backgroundColor: CustomerColors.dark,
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
    final isEdit = widget.existing != null;
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEF5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: const [
          BoxShadow(
              color: Color(0xFFBEBECF), blurRadius: 20, offset: Offset(8, 8)),
          BoxShadow(
              color: Colors.white, blurRadius: 20, offset: Offset(-8, -8)),
        ],
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Handle
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
            )),
            const SizedBox(height: 20),

            // Header
            Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEEEEF5),
                  boxShadow: const [
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
                child: Icon(isEdit ? Icons.edit_rounded : Icons.flag_rounded,
                    color: isEdit
                        ? const Color(0xFF7C3AED)
                        : const Color(0xFFEF4444),
                    size: 22),
              ),
              const SizedBox(width: 14),
              Text(isEdit ? 'Edit Complaint' : 'Submit Complaint',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF333355))),
            ]),
            const SizedBox(height: 20),

            // Reason section
            const Text('Select Reason',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7777AA))),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _reasons.map((r) {
                final sel = _selectedReason == r;
                final selColor = const Color(0xFFEF4444);
                final darkSel = const Color(0xFF991B1B);
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
                      color: const Color(0xFFEEEEF5),
                      borderRadius: BorderRadius.circular(20),
                      gradient: sel
                          ? const LinearGradient(
                              colors: [Color(0xFFEF4444), Color(0xFF991B1B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight)
                          : null,
                      boxShadow: sel
                          ? const [
                              BoxShadow(
                                  color: Color(0x99EF4444),
                                  blurRadius: 8,
                                  offset: Offset(0, 4)),
                              BoxShadow(
                                  color: Color(0xFF991B1B),
                                  blurRadius: 0,
                                  offset: Offset(0, 3)),
                            ]
                          : const [
                              BoxShadow(
                                  color: Color(0xFFBEBECF),
                                  blurRadius: 5,
                                  offset: Offset(3, 3)),
                              BoxShadow(
                                  color: Colors.white,
                                  blurRadius: 5,
                                  offset: Offset(-3, -3)),
                            ],
                    ),
                    child: Text(r,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color:
                                sel ? Colors.white : const Color(0xFF7777AA))),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Description
            const Text('Describe the issue',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7777AA))),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFEEEEF5),
                borderRadius: BorderRadius.circular(16),
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
              child: TextFormField(
                controller: _descCtrl,
                maxLines: 4,
                style: const TextStyle(fontSize: 14, color: Color(0xFF333355)),
                decoration: const InputDecoration(
                  hintText: 'Describe the issue in detail...',
                  hintStyle: TextStyle(color: Color(0xFFAAAACC), fontSize: 13),
                  prefixIcon: Icon(Icons.description_outlined,
                      color: Color(0xFF7777AA), size: 20),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please describe the issue'
                    : null,
              ),
            ),
            const SizedBox(height: 28),

            // Submit button
            _NeoSaveButton(onTap: _submit),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF7C3AED))),
              ),
          ]),
        ),
      ),
    );
  }
}

// ── Quick Actions Help Screen ─────────────────────────────────────────────────
class _HelpScreen extends StatelessWidget {
  const _HelpScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F6FF),
      appBar: AppBar(
        title: const Text('Help & Support',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: CustomerColors.darkest)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: CustomerColors.dark),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _HelpItem(
              icon: Icons.question_answer_outlined,
              title: 'How to place an order?',
              body:
                  'Go to the Home tab, browse providers, then tap "Request Service" on any provider card.'),
          _HelpItem(
              icon: Icons.track_changes_rounded,
              title: 'How to track my order?',
              body:
                  'Open the Orders tab to see all your current and past orders with live status updates.'),
          _HelpItem(
              icon: Icons.flag_outlined,
              title: 'How to file a complaint?',
              body:
                  'Inside any order, tap the complaint icon or go to your profile and open the Complaints section.'),
          _HelpItem(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'How to message a provider?',
              body:
                  'Tap the message icon on any provider card or go to the Messages tab.'),
          _HelpItem(
              icon: Icons.phone_outlined,
              title: 'Contact Support',
              body: 'Email: support@san3a.app\nPhone: +972-XX-XXXXXXX'),
        ],
      ),
    );
  }
}

class _HelpItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _HelpItem(
      {required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CustomerColors.lightest, width: 1.2),
          boxShadow: [
            BoxShadow(
                color: CustomerColors.mid.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: CustomerColors.lightest,
                  borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, color: CustomerColors.dark, size: 18)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: CustomerColors.darkest)),
                const SizedBox(height: 5),
                Text(body,
                    style: const TextStyle(
                        fontSize: 13, color: CustomerColors.mid, height: 1.5)),
              ])),
        ]),
      );
}

// ── Supporting Widgets ────────────────────────────────────────────────────────
class _BlueInfoCard extends StatelessWidget {
  final List<Widget> children;
  final bool isDark;
  const _BlueInfoCard({required this.children, required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0D1B2E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? CustomerColors.dark.withOpacity(0.4)
                : CustomerColors.lightest,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: CustomerColors.mid.withOpacity(0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(children: children),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final bool isDark;
  const _InfoRow(
      {required this.icon,
      required this.label,
      required this.value,
      required this.isDark});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark
                  ? CustomerColors.dark.withOpacity(0.3)
                  : CustomerColors.lightest,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon,
                color: isDark ? CustomerColors.light : CustomerColors.dark,
                size: 18),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: isDark ? CustomerColors.light : CustomerColors.mid,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : CustomerColors.darkest)),
          ]),
        ]),
      );
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool isDark;
  const _ActionTile(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.color,
      required this.isDark});

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: (color ?? CustomerColors.dark).withOpacity(0.09),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: color ?? CustomerColors.dark, size: 18),
        ),
        title: Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color:
                    color ?? (isDark ? Colors.white : CustomerColors.darkest))),
        trailing: Icon(Icons.chevron_right_rounded,
            color:
                color ?? (isDark ? CustomerColors.light : CustomerColors.mid),
            size: 18),
      );
}

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});
  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        indent: 64,
        endIndent: 16,
        color: isDark
            ? CustomerColors.dark.withOpacity(0.3)
            : CustomerColors.lightest,
      );
}

class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  const _EditField(
      {required this.label,
      required this.controller,
      this.validator,
      this.keyboardType});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: CustomerColors.mid)),
          const SizedBox(height: 5),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            style: const TextStyle(fontSize: 14, color: CustomerColors.darkest),
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: CustomerColors.lightest, width: 1.5)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: CustomerColors.mid, width: 2)),
              errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: CustomerColors.error)),
              filled: true,
              fillColor: const Color(0xFFF8FBFF),
            ),
          ),
          const SizedBox(height: 12),
        ],
      );
}

// ── Address field: typeable + GPS detect button ───────────────────────────────
class _EditAddressField extends StatefulWidget {
  final String initialValue;
  final bool fetching;
  final ValueChanged<String> onChanged;
  final Future<void> Function() onDetect;
  const _EditAddressField({
    required this.initialValue,
    required this.fetching,
    required this.onChanged,
    required this.onDetect,
  });

  @override
  State<_EditAddressField> createState() => _EditAddressFieldState();
}

class _EditAddressFieldState extends State<_EditAddressField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant _EditAddressField old) {
    super.didUpdateWidget(old);
    // Keep field in sync when GPS overwrites the value from parent.
    if (widget.initialValue != _ctrl.text) {
      _ctrl.value = TextEditingValue(
        text: widget.initialValue,
        selection: TextSelection.collapsed(offset: widget.initialValue.length),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _ctrl,
      onChanged: widget.onChanged,
      style: const TextStyle(fontSize: 14, color: CustomerColors.darkest),
      decoration: InputDecoration(
        hintText: 'Type your address or tap GPS',
        hintStyle: const TextStyle(color: CustomerColors.light, fontSize: 13),
        prefixIcon: const Icon(Icons.location_on_outlined,
            size: 18, color: CustomerColors.mid),
        suffixIcon: widget.fetching
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: CustomerColors.mid)),
              )
            : IconButton(
                tooltip: 'Detect my location',
                icon: const Icon(Icons.my_location_rounded,
                    color: CustomerColors.mid, size: 20),
                onPressed: widget.onDetect,
              ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: CustomerColors.lightest, width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: CustomerColors.mid, width: 2)),
        filled: true,
        fillColor: const Color(0xFFF8FBFF),
      ),
    );
  }
}

// ── Statistics Row ────────────────────────────────────────────────────────────
class _StatsRow extends ConsumerWidget {
  final UserModel user;
  const _StatsRow({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    final stats = [
      _StatData(
          icon: Icons.receipt_long_rounded,
          value: '$total',
          label: 'Orders',
          color: CustomerColors.dark),
      _StatData(
          icon: Icons.check_circle_rounded,
          value: '$completed',
          label: 'Completed',
          color: const Color(0xFF059669)),
      _StatData(
          icon: Icons.autorenew_rounded,
          value: '$inProgress',
          label: 'In Progress',
          color: const Color(0xFF0EA5E9)),
    ];

    return Row(
      children: List.generate(
          stats.length,
          (i) => Expanded(
                child: Padding(
                  padding:
                      EdgeInsets.only(right: i < stats.length - 1 ? 10 : 0),
                  child: _StatCard(data: stats[i]),
                ),
              )),
    );
  }
}

class _StatData {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatData(
      {required this.icon,
      required this.value,
      required this.label,
      required this.color});
}

class _StatCard extends StatelessWidget {
  final _StatData data;
  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: CustomerColors.lightest, width: 1.2),
          boxShadow: [
            BoxShadow(
                color: data.color.withOpacity(0.10),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: data.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(11)),
                child: Icon(data.icon, color: data.color, size: 18)),
            const SizedBox(height: 8),
            Text(data.value,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: data.color,
                    letterSpacing: -0.5)),
            const SizedBox(height: 3),
            Text(data.label,
                style: const TextStyle(
                    fontSize: 11,
                    color: CustomerColors.mid,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
          ],
        ),
      );
}

// ── Quick Actions Card ────────────────────────────────────────────────────────
class _QuickActionsCard extends ConsumerWidget {
  final bool isDark;
  final List<ComplaintModel> myComplaints;
  const _QuickActionsCard({required this.isDark, required this.myComplaints});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark
                ? CustomerColors.dark.withOpacity(0.4)
                : CustomerColors.lightest,
            width: 1.2),
        boxShadow: [
          BoxShadow(
              color: CustomerColors.mid.withOpacity(0.08),
              blurRadius: 14,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text('Quick Actions',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : CustomerColors.darkest)),
          ),
          Divider(
              height: 1,
              color: isDark
                  ? CustomerColors.dark.withOpacity(0.3)
                  : CustomerColors.lightest),
          // My Orders
          _QuickActionTile(
            icon: Icons.receipt_long_rounded,
            label: 'My Orders',
            color: CustomerColors.dark,
            isDark: isDark,
            onTap: () {
              // Navigate to the Orders tab (index 2) in the bottom nav,
              // then pop back to the root so the tab switch is visible.
              ref.read(navIndexProvider.notifier).state = 2;
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
          // Favorites
          _QuickActionTile(
            icon: Icons.favorite_rounded,
            label: 'Favorites',
            color: const Color(0xFFE11D48),
            isDark: isDark,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const FavoritesScreen())),
          ),
          // Complaints
          _QuickActionTile(
            icon: Icons.flag_rounded,
            label: myComplaints.isNotEmpty
                ? 'Complaints (${myComplaints.length})'
                : 'Complaints',
            color: const Color(0xFFF59E0B),
            isDark: isDark,
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const CustomerComplaintsScreen())),
          ),
          // Notifications
          _QuickActionTile(
            icon: Icons.notifications_rounded,
            label: 'Notifications',
            color: const Color(0xFF8B5CF6),
            isDark: isDark,
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const CustomerNotificationsScreen())),
          ),
          // Help
          _QuickActionTile(
            icon: Icons.help_rounded,
            label: 'Help',
            color: const Color(0xFF059669),
            isDark: isDark,
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const HelpCenterScreen(
                          userRole: UserRole.customer,
                          accentColor: Color(0xFF3B82F6),
                          gradientStart: CustomerColors.darkest,
                          gradientMid: Color(0xFF0A1F4E),
                          gradientEnd: CustomerColors.dark,
                        ))),
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
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
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(11)),
                child: Icon(widget.icon, color: widget.color, size: 18)),
            const SizedBox(width: 12),
            Expanded(
                child: Text(widget.label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: widget.isDark
                            ? Colors.white
                            : CustomerColors.darkest))),
            Icon(Icons.chevron_right_rounded,
                color:
                    widget.isDark ? CustomerColors.light : CustomerColors.mid,
                size: 18),
          ]),
        ),
      ),
    );
  }
}

// ── Profile 3-Dot Neo Menu Panel ──────────────────────────────────────────────
class _ProfileNeoMenuPanel extends StatefulWidget {
  final VoidCallback onEdit;
  final VoidCallback onLogout;
  const _ProfileNeoMenuPanel({required this.onEdit, required this.onLogout});
  @override
  State<_ProfileNeoMenuPanel> createState() => _ProfileNeoMenuPanelState();
}

class _ProfileNeoMenuPanelState extends State<_ProfileNeoMenuPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 360))
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.edit_rounded, const Color(0xFF7C3AED), widget.onEdit),
      (Icons.logout_rounded, const Color(0xFFEF4444), widget.onLogout),
    ];
    return Container(
      width: 68,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
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
        children: List.generate(items.length, (i) {
          final (icon, color, onTap) = items[i];
          final anim = CurvedAnimation(
            parent: _ctrl,
            curve: Interval((i / items.length).clamp(0.0, 1.0),
                ((i + 1) / items.length).clamp(0.0, 1.0),
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
                onTap: onTap,
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
                  child: Icon(icon, color: color, size: 22),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Edit Profile Sheet (request_category style) ───────────────────────────────
class _EditProfileSheet extends ConsumerStatefulWidget {
  final UserModel user;
  final AppLocalizations l;
  final Future<void> Function(UserModel) onSave;
  const _EditProfileSheet(
      {required this.user, required this.l, required this.onSave});
  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;

  List<String> _languages = [];
  List<String> _contactHours = [];
  List<String> _favServices = [];
  bool _fetching = false;
  bool _saving = false;
  String _detectedCity = '';
  String _detectedStreet = '';
  // True only right after a successful GPS fetch during this edit session —
  // never inferred merely from _detectedCity being non-empty (it starts
  // seeded from the existing user.city, which is not a GPS result). Reset to
  // false the moment the Customer types into the Address field by hand, so a
  // manual edit is never silently discarded in favor of a stale GPS/city
  // value on Save.
  bool _cityFromGps = false;

  // The 5 most common languages, shown directly as chips. "More Languages"
  // opens _broadLanguages (a much larger world-language list) for anything
  // beyond these — see _showMoreLanguagesSheet.
  static const _mainLanguages = [
    'Arabic',
    'Hebrew',
    'English',
    'French',
    'Russian',
  ];
  static const _broadLanguages = [
    'Arabic',
    'Hebrew',
    'English',
    'French',
    'Russian',
    'Spanish',
    'German',
    'Italian',
    'Portuguese',
    'Turkish',
    'Chinese (Mandarin)',
    'Japanese',
    'Korean',
    'Hindi',
    'Urdu',
    'Persian (Farsi)',
    'Amharic',
    'Swahili',
    'Dutch',
    'Greek',
    'Polish',
    'Ukrainian',
    'Romanian',
    'Bulgarian',
    'Serbian',
    'Vietnamese',
    'Thai',
    'Indonesian',
    'Malay',
    'Tagalog (Filipino)',
    'Bengali',
    'Punjabi',
    'Tamil',
    'Armenian',
    'Georgian',
    'Azerbaijani',
    'Kurdish',
    'Somali',
    'Hausa',
    'Yoruba',
  ];
  static const _allHours = kPreferredContactHourOptions;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _nameCtrl = TextEditingController(text: u.fullName);
    _emailCtrl = TextEditingController(text: u.email);
    _phoneCtrl = TextEditingController(text: u.phone);
    _addressCtrl = TextEditingController(text: u.fullAddress);
    _languages = List.from(u.languages);
    _contactHours = List.from(u.preferredContactHours);
    _favServices = List.from(u.favoriteServices);
    _detectedCity = u.city;
    _detectedStreet = u.streetNumber;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(widget.user.copyWith(
        fullName: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        // Only trust _detectedCity when this session's GPS fetch actually
        // produced it — otherwise the Address field's own text (whatever
        // the Customer last typed) is authoritative, so manually typing a
        // new city always overrides a previously stored value, including a
        // stale coordinate string.
        city: _cityFromGps ? _detectedCity : _addressCtrl.text.trim(),
        streetNumber: _detectedStreet,
        languages: _languages,
        preferredContactHours: _contactHours,
        favoriteServices: _favServices,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reuses the same Firestore categories stream the rest of the app uses
    // for category browsing (categoriesProvider — collection 'categories',
    // isActive-filtered, sorted) so Favorite Services always reflects real,
    // current categories instead of a hardcoded service-name list.
    final categoriesAsync = ref.watch(categoriesProvider);
    final categoryNames =
        (categoriesAsync.valueOrNull ?? const <CategoryModel>[])
            .map((c) => widget.l.get(c.nameKey))
            .toList();

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEF5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: const [
          BoxShadow(
              color: Color(0xFFBEBECF), blurRadius: 20, offset: Offset(8, 8)),
          BoxShadow(
              color: Colors.white, blurRadius: 20, offset: Offset(-8, -8)),
        ],
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Handle ─────────────────────────────────────────────
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
              )),
              const SizedBox(height: 20),

              // ── Header ─────────────────────────────────────────────
              Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFEEEEF5),
                    boxShadow: const [
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
                  child: const Icon(Icons.edit_rounded,
                      color: Color(0xFF5555AA), size: 22),
                ),
                const SizedBox(width: 14),
                const Text('Edit Profile',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF333355))),
              ]),
              const SizedBox(height: 22),

              // ── Basic Info ─────────────────────────────────────────
              _NeoSectionHeader(
                  icon: Icons.badge_rounded,
                  iconColor: const Color(0xFF7C3AED),
                  title: 'Basic Info'),
              const SizedBox(height: 12),
              _NeoFieldLabel('Full Name'),
              _NeoSheetTextField(
                  ctrl: _nameCtrl,
                  hint: 'Your full name',
                  icon: Icons.person_rounded,
                  validator: (v) => (v == null || v.trim().length < 3)
                      ? 'Name too short'
                      : null),
              const SizedBox(height: 16),

              _NeoFieldLabel('Email'),
              _NeoSheetTextField(
                  ctrl: _emailCtrl,
                  hint: 'your@email.com',
                  icon: Icons.email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email required';
                    if (!RegExp(r'^[\w\.\+\-]+@[\w\-]+\.[a-zA-Z]{2,}$')
                        .hasMatch(v.trim())) return 'Invalid email';
                    return null;
                  }),
              const SizedBox(height: 16),

              _NeoFieldLabel('Phone'),
              _NeoSheetTextField(
                  ctrl: _phoneCtrl,
                  hint: '+970 5X XXX XXXX',
                  icon: Icons.phone_rounded,
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Phone required';
                    if (v.trim().length < 8) return 'Phone too short';
                    return null;
                  }),
              const SizedBox(height: 16),

              _NeoFieldLabel('Address'),
              _NeoSheetTextField(
                ctrl: _addressCtrl,
                hint: 'Your address or tap GPS',
                icon: Icons.location_on_rounded,
                // Any manual edit to this field means the Customer is
                // overriding whatever GPS/old value was there — the next
                // Save must use this typed text for city, not _detectedCity.
                onChanged: (_) {
                  if (_cityFromGps) setState(() => _cityFromGps = false);
                },
                suffixIcon: _fetching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFF7777AA))))
                    : GestureDetector(
                        onTap: () async {
                          setState(() => _fetching = true);
                          try {
                            final res =
                                await LocationHelper.getCurrentAddress();
                            setState(() {
                              _detectedCity = res.city;
                              _detectedStreet = res.streetNumber;
                              _addressCtrl.text = res.fullAddress;
                              _cityFromGps = true;
                            });
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(e.toString()),
                                backgroundColor: CustomerColors.error,
                                behavior: SnackBarBehavior.floating));
                          } finally {
                            setState(() => _fetching = false);
                          }
                        },
                        child: const Icon(Icons.my_location_rounded,
                            color: Color(0xFF7777AA), size: 20),
                      ),
              ),
              const SizedBox(height: 22),

              // ── Languages ──────────────────────────────────────────
              _NeoSectionHeader(
                  icon: Icons.language_rounded,
                  iconColor: const Color(0xFF14B8A6),
                  title: 'Languages'),
              const SizedBox(height: 10),
              _NeoChipSelector(
                // Main 5 first, then any already-saved language outside the
                // main 5 (from a previous "More Languages" pick) so it stays
                // visible/editable inline instead of disappearing.
                options: {..._mainLanguages, ..._languages}.toList(),
                selected: _languages,
                onToggle: (v) => setState(() => _languages.contains(v)
                    ? _languages.remove(v)
                    : _languages.add(v)),
                activeColor: const Color(0xFF14B8A6),
              ),
              const SizedBox(height: 10),
              _NeoMoreChip(
                label: 'More Languages',
                color: const Color(0xFF14B8A6),
                onTap: () => _showMoreLanguagesSheet(
                  context: context,
                  current: _languages,
                  onDone: (updated) => setState(() => _languages = updated),
                ),
              ),
              const SizedBox(height: 22),

              // ── Contact Hours ──────────────────────────────────────
              _NeoSectionHeader(
                  icon: Icons.access_time_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  title: 'Preferred Contact Hours'),
              const SizedBox(height: 10),
              _NeoChipSelector(
                options: _allHours,
                selected: _contactHours,
                // Shared rule (see togglePreferredContactHour): 'Any Time'
                // and the specific periods are mutually exclusive, so the
                // user can never end up claiming both "any hour" and a
                // narrower window at the same time.
                onToggle: (v) => setState(() => _contactHours =
                    togglePreferredContactHour(_contactHours, v)),
                activeColor: const Color(0xFF8B5CF6),
              ),
              const SizedBox(height: 22),

              // ── Favorite Services ──────────────────────────────────
              _NeoSectionHeader(
                  icon: Icons.star_rounded,
                  iconColor: const Color(0xFFEC4899),
                  title: 'Favorite Services'),
              const SizedBox(height: 6),
              // Max 3 hint
              Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEEEF5),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0xFFBEBECF),
                          blurRadius: 4,
                          offset: Offset(2, 2)),
                      BoxShadow(
                          color: Colors.white,
                          blurRadius: 4,
                          offset: Offset(-2, -2)),
                    ],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      _favServices.length >= 3
                          ? Icons.check_circle_rounded
                          : Icons.info_outline_rounded,
                      size: 13,
                      color: _favServices.length >= 3
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEC4899),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _favServices.length >= 3
                          ? 'Max selected (${_favServices.length}/3)'
                          : 'Pick up to 3 (${_favServices.length}/3)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _favServices.length >= 3
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEC4899),
                      ),
                    ),
                  ]),
                ),
              ]),
              const SizedBox(height: 10),
              if (categoriesAsync.isLoading && categoryNames.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFFEC4899))),
                )
              else if (categoriesAsync.hasError && categoryNames.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Could not load services. Please try again.',
                      style:
                          TextStyle(fontSize: 12, color: CustomerColors.error)),
                )
              else
                _NeoChipSelector(
                  options: categoryNames,
                  selected: _favServices,
                  onToggle: (v) => setState(() {
                    if (_favServices.contains(v)) {
                      _favServices.remove(v);
                    } else if (_favServices.length < 3) {
                      _favServices.add(v);
                    } else {
                      // shake/ignore — already at max
                      HapticFeedback.heavyImpact();
                    }
                  }),
                  activeColor: const Color(0xFFEC4899),
                  maxReached: _favServices.length >= 3,
                ),
              const SizedBox(height: 30),

              // ── Save button ────────────────────────────────────────
              if (_saving)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
                  ),
                )
              else
                _NeoSaveButton(onTap: _save),
            ],
          ),
        ),
      ),
    );
  }
}

// ── More Languages — large multi-select picker ────────────────────────────────
// Opens a scrollable checklist over _EditProfileSheetState._broadLanguages so
// the Customer can pick from a much wider language set than the 5 main
// chips. Selection is multi-select and mutates a local copy until "Done" is
// tapped, matching the existing chip-toggle UX rather than saving on every
// tap.
void _showMoreLanguagesSheet({
  required BuildContext context,
  required List<String> current,
  required ValueChanged<List<String>> onDone,
}) {
  final selected = List<String>.from(current);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEEEEF5),
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                    color: Color(0xFFBEBECF),
                    blurRadius: 20,
                    offset: Offset(8, 8)),
                BoxShadow(
                    color: Colors.white,
                    blurRadius: 20,
                    offset: Offset(-8, -8)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                const SizedBox(height: 14),
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFBEBECF),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                  child: Row(children: [
                    const Expanded(
                      child: Text('Select Languages',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF333355))),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEEEEF5),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Color(0xFFBEBECF),
                                blurRadius: 5,
                                offset: Offset(3, 3)),
                            BoxShadow(
                                color: Colors.white,
                                blurRadius: 5,
                                offset: Offset(-3, -3)),
                          ],
                        ),
                        child: const Icon(Icons.close_rounded,
                            size: 18, color: Color(0xFF7777AA)),
                      ),
                    ),
                  ]),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _EditProfileSheetState._broadLanguages.length,
                    itemBuilder: (_, i) {
                      final lang = _EditProfileSheetState._broadLanguages[i];
                      final isSelected = selected.contains(lang);
                      return _NeoCheckRow(
                        label: lang,
                        selected: isSelected,
                        color: const Color(0xFF14B8A6),
                        onTap: () => setSheetState(() => isSelected
                            ? selected.remove(lang)
                            : selected.add(lang)),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: _NeoSaveButton(
                    onTap: () {
                      onDone(List<String>.from(selected));
                      Navigator.pop(ctx);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

// Small pill-style trailing action chip (e.g. "More Languages") — visually
// distinct from the selection chips in _NeoChipSelector (outlined, with a
// leading "+" icon) so it reads as an action, not another selectable value.
class _NeoMoreChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _NeoMoreChip(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFEEEEF5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.5), width: 1.2),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add_rounded, size: 15, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          ]),
        ),
      );
}

// Toggleable row used inside the More Languages sheet — a simple checklist
// row reads more cleanly than a large Wrap of ~40 chips.
class _NeoCheckRow extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _NeoCheckRow(
      {required this.label,
      required this.selected,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEEEEF5),
              borderRadius: BorderRadius.circular(14),
              border: selected
                  ? Border.all(color: color, width: 1.4)
                  : Border.all(color: Colors.transparent, width: 1.4),
              boxShadow: const [
                BoxShadow(
                    color: Color(0xFFBEBECF),
                    blurRadius: 4,
                    offset: Offset(2, 2)),
                BoxShadow(
                    color: Colors.white, blurRadius: 4, offset: Offset(-2, -2)),
              ],
            ),
            child: Row(children: [
              Expanded(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: selected ? color : const Color(0xFF333355)))),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 20,
                color: selected ? color : const Color(0xFFBBBBCC),
              ),
            ]),
          ),
        ),
      );
}

// ── Neo Sheet helpers ─────────────────────────────────────────────────────────
class _NeoFieldLabel extends StatelessWidget {
  final String label;
  const _NeoFieldLabel(this.label);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF7777AA))),
      );
}

class _NeoSectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  const _NeoSectionHeader(
      {required this.icon, required this.iconColor, required this.title});
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFEEEEF5),
            boxShadow: const [
              BoxShadow(
                  color: Color(0xFFBEBECF),
                  blurRadius: 6,
                  offset: Offset(3, 3)),
              BoxShadow(
                  color: Colors.white, blurRadius: 6, offset: Offset(-3, -3)),
            ],
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF333355))),
      ]);
}

class _NeoSheetTextField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  const _NeoSheetTextField(
      {required this.ctrl,
      required this.hint,
      required this.icon,
      this.keyboardType,
      this.validator,
      this.suffixIcon,
      this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFFEEEEF5),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: Color(0xFFBEBECF), blurRadius: 6, offset: Offset(3, 3)),
            BoxShadow(
                color: Colors.white, blurRadius: 6, offset: Offset(-3, -3)),
          ],
        ),
        child: TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14, color: Color(0xFF333355)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFAAAACC), fontSize: 13),
            prefixIcon: Icon(icon, color: const Color(0xFF7777AA), size: 20),
            suffixIcon: suffixIcon,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      );
}

class _NeoChipSelector extends StatelessWidget {
  final List<String> options;
  final List<String> selected;
  final void Function(String) onToggle;
  final Color activeColor;
  final bool maxReached;
  const _NeoChipSelector(
      {required this.options,
      required this.selected,
      required this.onToggle,
      required this.activeColor,
      this.maxReached = false});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((opt) {
          final isSelected = selected.contains(opt);
          final isDisabled = maxReached && !isSelected;
          final darkColor = Color.lerp(activeColor, Colors.black, 0.3)!;
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onToggle(opt);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFEEEEF5),
                borderRadius: BorderRadius.circular(20),
                gradient: isSelected
                    ? LinearGradient(
                        colors: [activeColor, darkColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight)
                    : null,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                            color: activeColor.withOpacity(0.45),
                            blurRadius: 8,
                            offset: const Offset(0, 4)),
                        BoxShadow(
                            color: darkColor.withOpacity(0.9),
                            blurRadius: 0,
                            offset: const Offset(0, 3)),
                      ]
                    : const [
                        BoxShadow(
                            color: Color(0xFFBEBECF),
                            blurRadius: 5,
                            offset: Offset(3, 3)),
                        BoxShadow(
                            color: Colors.white,
                            blurRadius: 5,
                            offset: Offset(-3, -3)),
                      ],
              ),
              child: Text(
                opt,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? Colors.white
                      : (isDisabled
                          ? const Color(0xFFCCCCDD)
                          : const Color(0xFF7777AA)),
                ),
              ),
            ),
          );
        }).toList(),
      );
}

class _NeoSaveButton extends StatefulWidget {
  final VoidCallback onTap;
  const _NeoSaveButton({required this.onTap});
  @override
  State<_NeoSaveButton> createState() => _NeoSaveButtonState();
}

class _NeoSaveButtonState extends State<_NeoSaveButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
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

  @override
  Widget build(BuildContext context) => GestureDetector(
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
              Transform.scale(scale: 1.0 - 0.04 * _ctrl.value, child: child),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 17),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF4C1D95)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                    color: Color(0xFF4C1D95),
                    blurRadius: 0,
                    offset: Offset(0, 5)),
                BoxShadow(
                    color: Color(0x997C3AED),
                    blurRadius: 16,
                    offset: Offset(0, 8)),
                BoxShadow(
                    color: Colors.white, blurRadius: 4, offset: Offset(0, -2)),
              ],
            ),
            child: Stack(alignment: Alignment.center, children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 28,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20)),
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
              const Text('Save Changes',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.3)),
            ]),
          ),
        ),
      );
}

// ── Profile → Feed Notifications Wrapper ─────────────────────────────────────
// Routes to the same full-screen notifications page used in the Home feed
class _ProfileNotificationsWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const CustomerNotificationsScreen();
  }
}
