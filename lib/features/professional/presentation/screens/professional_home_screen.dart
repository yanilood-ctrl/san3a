import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/presentation/providers/app_providers.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/shared_widgets.dart' show ProfileAvatarImage;
import '../../../../shared/widgets/profile_photo_menu.dart';
import '../../../../shared/widgets/profile_field_selectors.dart';
import '../../../../shared/widgets/category_requests_screen.dart';
import '../../../../shared/helpers/calendar_helper.dart';
import '../../../../shared/helpers/notification_navigation_helper.dart';
import '../../../../shared/widgets/complaint_details_dialog.dart';
import '../../../../shared/widgets/provider_content_translate_action.dart';
import '../../../translation/data/translation_repository.dart'
    show TranslationContentType;
import '../theme/professional_design.dart';
import 'professional_messages_screen.dart';
import 'professional_order_detail_screen.dart';
import 'professional_chat_screen.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../help/presentation/screens/help_center_screen.dart';
import '../../../professional_ai_assistant/presentation/screens/professional_ai_assistant_screen.dart';

// ── Professional Green Palette alias ─────────────────────────────────────────
// AppGreen is defined in app_theme.dart and used throughout this file.

// ─── Nav Shell ────────────────────────────────────────────────────────────────
class ProfessionalHomeScreen extends ConsumerWidget {
  const ProfessionalHomeScreen({super.key});

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor =
        isDark ? AppColors.darkSurface : ProfessionalColors.card;
    final borderColor =
        isDark ? AppColors.darkBorder : ProfessionalColors.border;
    final selColor = ProfessionalColors.mid;

    final screens = [
      const ProfessionalDashboard(),
      const ProfessionalMessagesScreen(),
      const ProfessionalProfileScreen(),
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
        'icon': Icons.person_outline_rounded,
        'active': Icons.person_rounded,
        'label': l.get('profile'),
        'badge': 0
      },
    ];
    final safeIndex = navIndex.clamp(0, screens.length - 1);

    return Scaffold(
      body: IndexedStack(index: safeIndex, children: screens),
      extendBody: true,
      bottomNavigationBar: _ProfFancyBottomNav(
        navItems: navItems,
        navIndex: safeIndex,
        onTap: (i) => ref.read(navIndexProvider.notifier).state = i,
      ),
    );
  }
}

// ── Professional Header 3-Dots Menu (customer style) ─────────────────────────
class _ProfHeaderDotsMenu extends StatefulWidget {
  final int pendingCount;
  final List<OrderModel> completedOrders;
  final List<OrderModel> cancelledOrders;
  final VoidCallback onNotifications;
  final VoidCallback onAiAssistant;
  final VoidCallback onHelp;
  final VoidCallback onLogout;
  const _ProfHeaderDotsMenu({
    required this.pendingCount,
    required this.completedOrders,
    required this.cancelledOrders,
    required this.onNotifications,
    required this.onAiAssistant,
    required this.onHelp,
    required this.onLogout,
  });
  @override
  State<_ProfHeaderDotsMenu> createState() => _ProfHeaderDotsMenuState();
}

class _ProfHeaderDotsMenuState extends State<_ProfHeaderDotsMenu>
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

  void _openMenu() {
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
        return Stack(children: [
          Positioned.fill(
              child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(color: Colors.transparent))),
          Positioned(
            top: 72,
            right: 16,
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(0.5, -0.3), end: Offset.zero)
                  .animate(curved),
              child: FadeTransition(
                opacity: anim,
                child: _ProfHeaderMenuPanel(
                  pendingCount: widget.pendingCount,
                  completedCount: widget.completedOrders.length,
                  cancelledCount: widget.cancelledOrders.length,
                  onNotifications: () {
                    Navigator.pop(ctx);
                    widget.onNotifications();
                  },
                  onAiAssistant: () {
                    Navigator.pop(ctx);
                    widget.onAiAssistant();
                  },
                  onCompleted: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _ProfFilteredOrdersScreen(
                            title: 'Completed Orders',
                            orders: widget.completedOrders,
                            accentColor: const Color(0xFF10B981),
                            icon: Icons.check_circle_rounded,
                          ),
                        ));
                  },
                  onCancelled: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _ProfFilteredOrdersScreen(
                            title: 'Cancelled Orders',
                            orders: widget.cancelledOrders,
                            accentColor: const Color(0xFFEF4444),
                            icon: Icons.cancel_rounded,
                          ),
                        ));
                  },
                  onHelp: () {
                    Navigator.pop(ctx);
                    widget.onHelp();
                  },
                  onLogout: () {
                    Navigator.pop(ctx);
                    widget.onLogout();
                  },
                ),
              ),
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
          _openMenu();
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
              color: ProfessionalColors.darkest,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(3, 3)),
                BoxShadow(
                    color: Colors.white.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(-2, -2)),
              ],
              border:
                  Border.all(color: Colors.white.withOpacity(0.15), width: 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                  3,
                  (i) => Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 1.5),
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle),
                      )),
            ),
          ),
        ),
      );
}

class _ProfHeaderMenuPanel extends StatefulWidget {
  final int pendingCount;
  final int completedCount;
  final int cancelledCount;
  final VoidCallback onNotifications;
  final VoidCallback onAiAssistant;
  final VoidCallback onCompleted;
  final VoidCallback onCancelled;
  final VoidCallback onHelp;
  final VoidCallback onLogout;
  const _ProfHeaderMenuPanel({
    required this.pendingCount,
    required this.completedCount,
    required this.cancelledCount,
    required this.onNotifications,
    required this.onAiAssistant,
    required this.onCompleted,
    required this.onCancelled,
    required this.onHelp,
    required this.onLogout,
  });
  @override
  State<_ProfHeaderMenuPanel> createState() => _ProfHeaderMenuPanelState();
}

class _ProfHeaderMenuPanelState extends State<_ProfHeaderMenuPanel>
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
    final l = AppLocalizations.of(context);
    final items = [
      _ProfHeaderMenuItem(Icons.notifications_rounded, 'Notifications',
          ProfessionalColors.mid, widget.pendingCount, widget.onNotifications),
      _ProfHeaderMenuItem(
          Icons.auto_awesome_rounded,
          l.get('professional_ai_assistant_menu_label'),
          ProfessionalColors.mid,
          0,
          widget.onAiAssistant),
      _ProfHeaderMenuItem(Icons.check_circle_outline_rounded, 'Completed',
          const Color(0xFF10B981), widget.completedCount, widget.onCompleted),
      _ProfHeaderMenuItem(Icons.cancel_outlined, 'Cancelled',
          const Color(0xFFEF4444), widget.cancelledCount, widget.onCancelled),
      _ProfHeaderMenuItem(Icons.help_outline_rounded, 'Help',
          const Color(0xFF0277BD), 0, widget.onHelp),
      _ProfHeaderMenuItem(Icons.logout_rounded, 'Logout',
          ProfessionalColors.error, 0, widget.onLogout),
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
          final item = items[i];
          final n = items.length;
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
                onTap: item.onTap,
                child: Stack(clipBehavior: Clip.none, children: [
                  Container(
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
                    child: Icon(item.icon, color: item.color, size: 22),
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
                                    offset: const Offset(0, 2))
                              ]),
                          child: Center(
                              child: Text('${item.count}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800))),
                        )),
                ]),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ProfHeaderMenuItem {
  final IconData icon;
  final String label;
  final Color color;
  final int count;
  final VoidCallback onTap;
  const _ProfHeaderMenuItem(
      this.icon, this.label, this.color, this.count, this.onTap);
}

// ── Professional Neo Back Button (top-level, usable anywhere) ────────────────
// ── Neo Sheet Outline Button (Back / secondary) ───────────────────────────────
class _NeoSheetOutlineButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _NeoSheetOutlineButton({required this.label, required this.onTap});
  @override
  State<_NeoSheetOutlineButton> createState() => _NeoSheetOutlineButtonState();
}

class _NeoSheetOutlineButtonState extends State<_NeoSheetOutlineButton>
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
              Transform.scale(scale: 1.0 - 0.03 * _ctrl.value, child: child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFEEEEF5),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: const Color(0xFFCCCCDD), width: 1.2),
              boxShadow: _pressed
                  ? const [
                      BoxShadow(
                          color: Color(0xFFBEBECF),
                          blurRadius: 3,
                          offset: Offset(2, 2)),
                      BoxShadow(
                          color: Colors.white,
                          blurRadius: 3,
                          offset: Offset(-1, -1))
                    ]
                  : const [
                      BoxShadow(
                          color: Color(0xFFBEBECF),
                          blurRadius: 0,
                          offset: Offset(0, 4)),
                      BoxShadow(
                          color: Color(0xFFBEBECF),
                          blurRadius: 8,
                          offset: Offset(4, 4)),
                      BoxShadow(
                          color: Colors.white,
                          blurRadius: 8,
                          offset: Offset(-4, -4))
                    ],
            ),
            child: Center(
                child: Text(widget.label,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4A4A6A),
                        letterSpacing: 0.1))),
          ),
        ),
      );
}

// ── Neo Sheet Danger Button (Confirm Cancel / destructive) ────────────────────
class _NeoSheetDangerButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _NeoSheetDangerButton({required this.label, required this.onTap});
  @override
  State<_NeoSheetDangerButton> createState() => _NeoSheetDangerButtonState();
}

class _NeoSheetDangerButtonState extends State<_NeoSheetDangerButton>
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
              gradient: LinearGradient(
                colors: _pressed
                    ? [const Color(0xFFCC2222), const Color(0xFFAA1111)]
                    : [const Color(0xFFEF4444), const Color(0xFFCC2222)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: _pressed
                  ? [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 4,
                          offset: const Offset(2, 2))
                    ]
                  : [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.38),
                          blurRadius: 0,
                          offset: const Offset(0, 5)),
                      BoxShadow(
                          color: const Color(0xFFEF4444).withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 6)),
                      BoxShadow(
                          color: Colors.white.withOpacity(0.08),
                          blurRadius: 4,
                          offset: const Offset(0, -2))
                    ],
            ),
            child: Stack(children: [
              // Glossy top
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 25,
                  decoration: BoxDecoration(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(25)),
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.18),
                          Colors.transparent
                        ]),
                  ),
                ),
              ),
              Center(
                  child: Text(widget.label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2))),
            ]),
          ),
        ),
      );
}

// ── Professional Search Bar ───────────────────────────────────────────────
// A single coherent rounded pill: a small primary-gradient search icon,
// the text field, and an optional clear button — refined spacing/shadow
// instead of the previous heavy multi-layer glow/floating-button treatment.
class _ProfCurvedSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final String query;
  final bool isDark;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _ProfCurvedSearchBar({
    required this.controller,
    required this.query,
    required this.isDark,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<_ProfCurvedSearchBar> createState() => _ProfCurvedSearchBarState();
}

class _ProfCurvedSearchBarState extends State<_ProfCurvedSearchBar> {
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

    final fieldBg =
        isDark ? const Color(0xFF0A1A14).withOpacity(0.85) : Colors.white;
    final borderC = _focused
        ? ProfessionalColors.primary
        : (isDark
            ? ProfessionalColors.mid.withOpacity(0.30)
            : ProfessionalColors.border.withOpacity(0.5));
    final textC = isDark ? Colors.white : ProfessionalColors.textPrimary;
    final hintC = isDark
        ? Colors.white.withOpacity(0.40)
        : ProfessionalColors.textSecondary;

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(ProfessionalRadii.pill),
        border: Border.all(color: borderC, width: 1.3),
        boxShadow: [
          BoxShadow(
            color: ProfessionalColors.primaryDark
                .withOpacity(isDark ? 0.35 : 0.10),
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
              gradient: ProfessionalColors.primaryGradient,
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
                      : ProfessionalColors.primaryDark.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close_rounded,
                    color: isDark
                        ? Colors.white.withOpacity(0.65)
                        : ProfessionalColors.primaryDark.withOpacity(0.55),
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

class _ProfNeoBackBtn extends StatefulWidget {
  const _ProfNeoBackBtn();
  @override
  State<_ProfNeoBackBtn> createState() => _ProfNeoBackBtnState();
}

class _ProfNeoBackBtnState extends State<_ProfNeoBackBtn>
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
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          setState(() => _pressed = true);
          _ctrl.forward();
        },
        onTapUp: (_) {
          setState(() => _pressed = false);
          _ctrl.reverse();
          Navigator.of(context).pop();
        },
        onTapCancel: () {
          setState(() => _pressed = false);
          _ctrl.reverse();
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, child) =>
                Transform.scale(scale: 1.0 - 0.07 * _ctrl.value, child: child),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFEEEEF5),
                borderRadius: BorderRadius.circular(14),
                boxShadow: _pressed
                    ? const [
                        BoxShadow(
                            color: Color(0xFFBEBECF),
                            blurRadius: 3,
                            offset: Offset(2, 2)),
                        BoxShadow(
                            color: Colors.white,
                            blurRadius: 3,
                            offset: Offset(-1, -1)),
                      ]
                    : const [
                        BoxShadow(
                            color: Color(0xFFBEBECF),
                            blurRadius: 0,
                            offset: Offset(0, 4)),
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
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFF4A4A6A), size: 17),
            ),
          ),
        ),
      );
}

// ── Professional Fancy Bottom Navigation ──────────────────────────────────────
class _ProfFancyBottomNav extends StatelessWidget {
  final List<Map<String, dynamic>> navItems;
  final int navIndex;
  final ValueChanged<int> onTap;

  const _ProfFancyBottomNav({
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
              top: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: [
                    BoxShadow(
                      color: ProfessionalColors.mid.withOpacity(0.18),
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
                  final selected = navIndex == i;
                  final badge = item['badge'] as int;
                  return Expanded(
                    child: _ProfNavItem(
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

class _ProfNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  const _ProfNavItem({
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
          SizedBox(
            height: 46,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                if (selected)
                  Positioned(
                    top: 0,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: ProfessionalColors.mid.withOpacity(0.28),
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
                        gradient: LinearGradient(
                          colors: [
                            ProfessionalColors.mid,
                            ProfessionalColors.darkest
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Stack(children: [
                        Center(
                            child: Icon(activeIcon,
                                color: Colors.white, size: 22)),
                        if (badge > 0)
                          Positioned(
                            right: 4,
                            top: 4,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF4444),
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
                      ]),
                    ),
                  ),
                if (!selected)
                  Positioned(
                    bottom: 8,
                    child: Stack(clipBehavior: Clip.none, children: [
                      Icon(icon, color: const Color(0xFFBBBBCC), size: 22),
                      if (badge > 0)
                        Positioned(
                          right: -7,
                          top: -6,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF4444),
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
                    ]),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color:
                    selected ? ProfessionalColors.mid : const Color(0xFFAAAAAA),
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

// ─── Dashboard ────────────────────────────────────────────────────────────────
class ProfessionalDashboard extends ConsumerStatefulWidget {
  const ProfessionalDashboard({super.key});
  @override
  ConsumerState<ProfessionalDashboard> createState() =>
      _ProfessionalDashboardState();
}

class _ProfessionalDashboardState extends ConsumerState<ProfessionalDashboard> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _filter = 'all';
  @override
  void initState() {
    super.initState();
  }

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
                          (userId: user.id, role: UserRole.professional)))
                      .valueOrNull ??
                  const <UserNotificationView>[];
          final notifs = models.map(_profNotifFromModel).toList();
          final unreadCount = models.where((m) => !m.isRead).length;
          return Container(
            height: MediaQuery.of(context).size.height * 0.65,
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
                    color: const Color(0xFF7DA0CA),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            ProfessionalColors.dark,
                            ProfessionalColors.mid
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.notifications_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF021024),
                      ),
                    ),
                    const Spacer(),
                    if (unreadCount > 0) ...[
                      TextButton(
                        onPressed: () {
                          if (user != null) {
                            markAllNotificationsReadInFirestore(
                                user.id, UserRole.professional);
                          }
                        },
                        child: const Text('Mark all read',
                            style: TextStyle(
                                color: ProfessionalColors.dark,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$unreadCount new',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: ProfessionalColors.error,
                          ),
                        ),
                      ),
                    ],
                  ]),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: notifs.isEmpty
                      ? const Center(
                          child: Text('No notifications yet',
                              style: TextStyle(
                                  color: ProfessionalColors.secondaryText)))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: notifs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final n = notifs[i];
                            return GestureDetector(
                              onTap: () {
                                Navigator.pop(context); // close sheet first
                                // models[i] is the full NotificationModel that
                                // notifs[i] (_ProfNotif) was derived from —
                                // pass it straight through so no related-id
                                // field the notification was created with
                                // gets dropped before routing.
                                handleNotificationTap(homeContext, ref,
                                    models[i], UserRole.professional);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: n.isNew
                                      ? const Color(0xFFF0F6FF)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: n.isNew
                                        ? const Color(0xFF7DA0CA)
                                            .withOpacity(0.4)
                                        : const Color(0xFFC1E8FF),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: ProfessionalColors.darkest
                                          .withOpacity(0.06),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: n.bg,
                                      borderRadius: BorderRadius.circular(14),
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
                                          child: Text(
                                            n.title,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: n.isNew
                                                  ? ProfessionalColors.titleText
                                                  : ProfessionalColors.dark,
                                            ),
                                          ),
                                        ),
                                        if (n.isNew)
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              color: ProfessionalColors.error,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ]),
                                      const SizedBox(height: 3),
                                      Text(
                                        n.subtitle,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color:
                                              ProfessionalColors.secondaryText,
                                        ),
                                      ),
                                    ],
                                  )),
                                  const SizedBox(width: 8),
                                  Text(
                                    n.time,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: ProfessionalColors.hintText,
                                    ),
                                  ),
                                ]),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
              ],
            ),
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
    final bg =
        isDark ? AppColors.darkBackground : ProfessionalColors.background;
    final surf = isDark ? AppColors.darkSurface : ProfessionalColors.card;
    final brd = isDark ? AppColors.darkBorder : ProfessionalColors.border;
    final txtPri =
        isDark ? AppColors.darkTextPrimary : ProfessionalColors.textPrimary;
    final txtSec =
        isDark ? AppColors.darkTextSecondary : ProfessionalColors.textSecondary;

    final ordersAsync = ref.watch(professionalFirestoreOrdersProvider);
    if (ordersAsync.isLoading && !ordersAsync.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (ordersAsync.hasError && !ordersAsync.hasValue) {
      debugPrint(
          'ORDERS_LOAD_ERROR [ProfessionalHomeScreen]: ${ordersAsync.error}');
      debugPrint(
          'ORDERS_LOAD_STACK [ProfessionalHomeScreen]: ${ordersAsync.stackTrace}');
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
            (userId: user.id, role: UserRole.professional)));

    List<OrderModel> filtered = orders;
    if (_filter == 'pending') filtered = pending;
    if (_filter == 'inProgress') filtered = inProgress;
    if (_filter == 'completed') filtered = completed;
    if (_filter == 'cancelled') filtered = cancelled;
    if (_query.isNotEmpty) {
      filtered = filtered
          .where((o) =>
              o.title.toLowerCase().contains(_query.toLowerCase()) ||
              o.area.toLowerCase().contains(_query.toLowerCase()) ||
              o.customerName.toLowerCase().contains(_query.toLowerCase()) ||
              (o.selectedServiceName
                      ?.toLowerCase()
                      .contains(_query.toLowerCase()) ??
                  false) ||
              (o.serviceType?.toLowerCase().contains(_query.toLowerCase()) ??
                  false))
          .toList();
    }

    // Today's Schedule: show ALL pending + inProgress orders (any date)
    // Completed & Cancelled are always excluded
    // Reactive: re-renders automatically when order status changes
    final scheduleOrders = orders
        .where((o) =>
            o.status == OrderStatus.pending ||
            o.status == OrderStatus.inProgress)
        .toList();
    // Home shows at most 2 — same list/order as above, just truncated for
    // display. "More" opens Professional All Schedules with the full list.
    final visibleScheduleOrders = scheduleOrders.take(2).toList();
    final hasMoreSchedule = scheduleOrders.length > 2;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  // Same gradient identity as the Professional Messages
                  // header (see ProfessionalMessagesListScreen's AppBar).
                  gradient: ProfessionalColors.primaryGradient,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: Color(0x600F766E),
                        blurRadius: 24,
                        offset: Offset(0, 10)),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      // Circular avatar (Customer style)
                      GestureDetector(
                        onTap: () =>
                            ref.read(navIndexProvider.notifier).state = 2,
                        child: Stack(children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: (user?.avatar?.isNotEmpty ?? false)
                                  ? null
                                  : const LinearGradient(
                                      colors: [
                                        ProfessionalColors.mid,
                                        ProfessionalColors.light
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.5),
                                  width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFF021024).withOpacity(0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ProfileAvatarImage(
                              imageUrl: user?.avatar,
                              size: 48,
                              fallbackText: user?.fullName.isNotEmpty == true
                                  ? user!.fullName
                                  : 'P',
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
                                color: ProfessionalColors.light,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: ProfessionalColors.darkest,
                                    width: 2),
                              ),
                            ),
                          ),
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
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color:
                                      ProfessionalColors.mid.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: ProfessionalColors.light
                                          .withOpacity(0.4)),
                                ),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.verified_rounded,
                                          color: Colors.white, size: 12),
                                      const SizedBox(width: 4),
                                      Text(l.get('professional'),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          )),
                                    ]),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.star_rounded,
                                  size: 13, color: Color(0xFFFFD700)),
                              const SizedBox(width: 3),
                              Text(
                                user?.rating.toStringAsFixed(1) ?? '0.0',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ]),
                          ])),
                      // Theme toggle
                      const SizedBox(width: 8),
                      // 3-dots action menu — customer style
                      _ProfHeaderDotsMenu(
                        pendingCount: unreadNotifications,
                        completedOrders: completed,
                        cancelledOrders: cancelled,
                        onNotifications: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const _ProfNotificationsPage())),
                        onAiAssistant: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const ProfessionalAiAssistantScreen())),
                        onHelp: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const HelpCenterScreen(
                                      userRole: UserRole.professional,
                                      accentColor: ProfessionalColors.mid,
                                      gradientStart: ProfessionalColors.darkest,
                                      gradientEnd: ProfessionalColors.dark,
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

                    // ── Premium 3D Curved Search Bar ──────────────────────
                    _ProfCurvedSearchBar(
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
                  ],
                ),
              ),
            ),
            // ── Standalone Professional AI entry card — same UX concept as
            // the Customer Home AI card: outside the header, above the
            // filter bar. Opens the exact same ProfessionalAiAssistantScreen
            // already reachable from the header's three-dot menu.
            const SliverToBoxAdapter(child: SizedBox(height: 18)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _ProfAiAssistantHomeEntry(
                  title: l.get('professional_ai_assistant_menu_label'),
                  subtitle: 'Get instant guidance on your orders',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const ProfessionalAiAssistantScreen())),
                ),
              ),
            ),
            // ── Filter/segment bar — now lives in the normal page content,
            // outside the top header, instead of inside its gradient panel.
            const SliverToBoxAdapter(child: SizedBox(height: 18)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _ProfStepperBar(
                  allCount: orders.length,
                  pendingCount: pending.length,
                  inProgressCount: inProgress.length,
                  selected: _filter,
                  onSelect: (v) => setState(() => _filter = v),
                ),
              ),
            ),
            if (scheduleOrders.isNotEmpty) ...[
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(children: [
                    Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                            color: ProfessionalColors.dark,
                            borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 8),
                    Text(l.get('today_schedule'),
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: ProfessionalColors.darkest)),
                    const Spacer(),
                    if (hasMoreSchedule)
                      _ProfNeoScheduleMoreButton(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                _ProfAllSchedulesScreen(orders: scheduleOrders),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _ProfScheduleTimeline(
                    orders: visibleScheduleOrders,
                    onTap: (o) =>
                        _showProfScheduleDetails(context, o, ref: ref),
                  ),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _SectionTitle2(
                    title: '${l.get("orders_count")} (${filtered.length})',
                    color: isDark ? Colors.white : ProfessionalColors.titleText,
                    isDark: isDark),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),
            filtered.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                        child: Column(children: [
                      Icon(Icons.search_off_rounded, size: 52, color: txtSec),
                      const SizedBox(height: 10),
                      Text(l.get('no_orders'),
                          style: TextStyle(color: txtSec, fontSize: 15)),
                    ])),
                  ))
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _ProfOrderCard3D(
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

// ── Professional AI — Home entry point ─────────────────────────────────────
// Standalone premium card in the normal page content, below the header and
// above the filter bar — same layout/quality concept as the Customer Home
// AI card (_AiAssistantHomeEntry in customer_feed_screen.dart), adapted to
// the Professional teal design system. Opens the existing
// ProfessionalAiAssistantScreen; see lib/features/professional_ai_assistant/
// for the feature implementation. Purely a navigation entry point — no AI
// logic lives here.
class _ProfAiAssistantHomeEntry extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ProfAiAssistantHomeEntry({
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
          color: ProfessionalColors.card,
          borderRadius: BorderRadius.circular(ProfessionalRadii.card),
          border: Border.all(
            color: ProfessionalColors.primary.withOpacity(0.25),
            width: 1.2,
          ),
          boxShadow: ProfessionalShadows.soft,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: ProfessionalColors.primaryGradient,
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
                    style: ProfessionalText.title.copyWith(fontSize: 14.5),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ProfessionalText.secondary,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: ProfessionalColors.background,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_rounded,
                  color: ProfessionalColors.primaryDark, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Prof Stepper Filter Bar (matching customer _OrderStepperBar) ──────────────
class _ProfStepperBar extends StatefulWidget {
  final int allCount;
  final int pendingCount;
  final int inProgressCount;
  final String selected;
  final ValueChanged<String> onSelect;
  const _ProfStepperBar({
    required this.allCount,
    required this.pendingCount,
    required this.inProgressCount,
    required this.selected,
    required this.onSelect,
  });
  @override
  State<_ProfStepperBar> createState() => _ProfStepperBarState();
}

class _ProfStepperBarState extends State<_ProfStepperBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideCtrl;

  // Color mapping: All = green, Pending = amber/orange, In Progress =
  // light blue accent (kept visually distinct from the green/teal
  // Professional identity used elsewhere).
  static const _tabs = [
    _ProfTabData(
        label: 'All',
        icon: Icons.list_alt_rounded,
        value: 'all',
        activeColor: Color(0xFF4CAF50),
        darkColor: Color(0xFF2E7D32)),
    _ProfTabData(
        label: 'Pending',
        icon: Icons.hourglass_top_rounded,
        value: 'pending',
        activeColor: Color(0xFFF59E0B),
        darkColor: Color(0xFFB45309)),
    _ProfTabData(
        label: 'In Progress',
        icon: Icons.autorenew_rounded,
        value: 'inProgress',
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
                                      : const Color(0xFF9999BB)),
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
                                  ? const Color(0xFF22224A)
                                  : const Color(0xFF9999BB),
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
                                  : const Color(0xFFBEBECF),
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
                                      : const Color(0xFF666688),
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

class _ProfTabData {
  final String label, value;
  final IconData icon;
  final Color activeColor, darkColor;
  const _ProfTabData(
      {required this.label,
      required this.value,
      required this.icon,
      required this.activeColor,
      required this.darkColor});
}

// ── Filtered Orders Screen (Completed / Cancelled) ────────────────────────────
class _ProfFilteredOrdersScreen extends ConsumerWidget {
  final String title;
  final List<OrderModel> orders;
  final Color accentColor;
  final IconData icon;
  const _ProfFilteredOrdersScreen({
    required this.title,
    required this.orders,
    required this.accentColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            backgroundColor: ProfessionalColors.darkest,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: _ProfNeoBackBtn(),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [
                    ProfessionalColors.darkest,
                    ProfessionalColors.dark
                  ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28)),
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
                                  color: accentColor.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(11),
                                  border: Border.all(
                                      color: accentColor.withOpacity(0.4))),
                              child: Icon(icon, color: Colors.white, size: 18)),
                          const SizedBox(width: 12),
                          Text(title,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5)),
                        ]),
                        const SizedBox(height: 4),
                        Text('${orders.length} orders',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.65),
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
                    final order = orders[i];
                    final isDark =
                        Theme.of(context).brightness == Brightness.dark;
                    return _ProfOrderCard3D(orderId: order.id, isDark: isDark);
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

// ─── Section Title ────────────────────────────────────────────────────────────
// ─── Prof Schedule Detail Sheet ─────────────────────────────────────────────
// ── Prof Schedule status → semantic color theme ─────────────────────────────
// Colors are derived from order.status (never list index/position), matching
// the same Pending/In Progress/Completed/Cancelled semantics used by
// Customer's Today's Schedule. Kept local to this file — no shared design
// token changes.
class _ProfScheduleStatusTheme {
  final Color accent;
  final Color background;
  final String label;
  const _ProfScheduleStatusTheme({
    required this.accent,
    required this.background,
    required this.label,
  });
}

_ProfScheduleStatusTheme _profScheduleStatusTheme(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return const _ProfScheduleStatusTheme(
        accent: Color(0xFFF59E0B),
        background: Color(0xFFFFF3E0),
        label: 'Pending',
      );
    case OrderStatus.inProgress:
      return const _ProfScheduleStatusTheme(
        accent: Color(0xFF3B82F6),
        background: Color(0xFFE3F2FD),
        label: 'In Progress',
      );
    case OrderStatus.completed:
      return const _ProfScheduleStatusTheme(
        accent: Color(0xFF10B981),
        background: Color(0xFFE8F5E9),
        label: 'Completed',
      );
    case OrderStatus.cancelled:
      return const _ProfScheduleStatusTheme(
        accent: Color(0xFFEF4444),
        background: Color(0xFFFFEBEE),
        label: 'Cancelled',
      );
  }
}

// ── Prof Schedule Timeline Widget ─────────────────────────────────────────────
class _ProfScheduleTimeline extends StatelessWidget {
  final List<OrderModel> orders;
  final void Function(OrderModel) onTap;
  const _ProfScheduleTimeline({required this.orders, required this.onTap});

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
              final theme = _profScheduleStatusTheme(orders[i].status);
              final color = theme.accent;
              final statusLabel = theme.label;
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
                        painter: _ProfDottedLinePainter(
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
              final theme = _profScheduleStatusTheme(order.status);
              final color = theme.accent;
              final bg = theme.background;
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
                                      color: Color(0xFF333344)),
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
                                    const Color(0xFF555566).withOpacity(0.75)),
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

// ── Dotted Line Painter ───────────────────────────────────────────────────────
class _ProfDottedLinePainter extends CustomPainter {
  final Color color;
  const _ProfDottedLinePainter({required this.color});
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
  bool shouldRepaint(_ProfDottedLinePainter old) => old.color != color;
}

// ── Neo Schedule More Button ──────────────────────────────────────────────────
class _ProfNeoScheduleMoreButton extends StatefulWidget {
  final VoidCallback onTap;
  const _ProfNeoScheduleMoreButton({required this.onTap});
  @override
  State<_ProfNeoScheduleMoreButton> createState() =>
      _ProfNeoScheduleMoreButtonState();
}

class _ProfNeoScheduleMoreButtonState extends State<_ProfNeoScheduleMoreButton>
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
          decoration: BoxDecoration(
            color: const Color(0xFFEEEEF5),
            borderRadius: BorderRadius.circular(20),
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
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Text('More',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF235347))),
            SizedBox(width: 4),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 10, color: Color(0xFF235347)),
          ]),
        ),
      ),
    );
  }
}

// ── Prof Schedule Detail Bottom Sheet — Neomorphism ────────────────────────────
void _showProfScheduleDetails(BuildContext context, OrderModel order,
    {WidgetRef? ref}) {
  final isPending = order.status == OrderStatus.pending;
  final statusColor =
      isPending ? const Color(0xFFF59E0B) : ProfessionalColors.mid;
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
        decoration: const BoxDecoration(
          color: Color(0xFFEEEEF5),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
                color: Color(0xFFBEBECF), blurRadius: 24, offset: Offset(8, 8)),
            BoxShadow(
                color: Colors.white, blurRadius: 24, offset: Offset(-8, -8)),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Row(children: [
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
                            offset: Offset(-4, -4))
                      ]),
                  child: const Icon(Icons.calendar_month_rounded,
                      color: ProfessionalColors.dark, size: 22),
                ),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Schedule Details',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF333355))),
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
                          offset: Offset(-3, -3))
                    ]),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.title,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF333355))),
                      const SizedBox(height: 4),
                      Text(order.description,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF7777AA),
                              height: 1.5)),
                    ]),
              ),
              const SizedBox(height: 16),
              // Detail rows
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
                          offset: Offset(-4, -4))
                    ]),
                child: Column(children: [
                  _ProfNeoDetailRow(
                      icon: Icons.access_time_rounded,
                      label: 'Time',
                      value: timeStr),
                  _ProfNeoDivider(),
                  _ProfNeoDetailRow(
                      icon: Icons.calendar_today_rounded,
                      label: 'Date',
                      value: dateStr),
                  _ProfNeoDivider(),
                  _ProfNeoDetailRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Customer',
                      value: order.customerName.isNotEmpty
                          ? order.customerName
                          : 'Customer'),
                  _ProfNeoDivider(),
                  _ProfNeoDetailRow(
                      icon: Icons.location_on_outlined,
                      label: 'Area',
                      value: order.area),
                  if (order.selectedServiceName != null) ...[
                    _ProfNeoDivider(),
                    _ProfNeoDetailRow(
                        icon: Icons.build_outlined,
                        label: 'Service',
                        value: order.selectedServiceName!),
                  ],
                  if (order.selectedServicePrice != null) ...[
                    _ProfNeoDivider(),
                    _ProfNeoDetailRow(
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
                    child: _ProfNeoOutlineButton(
                  label: 'Full Details',
                  icon: Icons.open_in_new_rounded,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                ProfessionalOrderDetailScreen(order: order)));
                  },
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: _ProfNeoFilledButton(
                  label: 'Add to Calendar',
                  icon: Icons.calendar_month_rounded,
                  onTap: () {
                    Navigator.pop(context);
                    addOrderToGoogleCalendar(context, order);
                  },
                )),
              ]),
              const SizedBox(height: 32),
            ]),
      ),
    ),
  );
}

// ── Neo Detail Row ────────────────────────────────────────────────────────────
class _ProfNeoDetailRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _ProfNeoDetailRow(
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
                  color: Color(0xFFEEEEF5),
                  boxShadow: [
                    BoxShadow(
                        color: Color(0xFFBEBECF),
                        blurRadius: 5,
                        offset: Offset(2, 2)),
                    BoxShadow(
                        color: Colors.white,
                        blurRadius: 5,
                        offset: Offset(-2, -2))
                  ]),
              child: Icon(icon, size: 16, color: ProfessionalColors.dark)),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF7777AA))),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF333355))),
        ]),
      );
}

class _ProfNeoDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [Color(0xFFD0D0DF), Colors.white, Color(0xFFD0D0DF)])),
      );
}

class _ProfNeoOutlineButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _ProfNeoOutlineButton(
      {required this.label, required this.icon, required this.onTap});
  @override
  State<_ProfNeoOutlineButton> createState() => _ProfNeoOutlineButtonState();
}

class _ProfNeoOutlineButtonState extends State<_ProfNeoOutlineButton>
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
              color: const Color(0xFFEEEEF5),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                  color: ProfessionalColors.mid.withOpacity(0.4), width: 1.2),
              boxShadow: _pressed
                  ? const [
                      BoxShadow(
                          color: Color(0xFFBEBECF),
                          blurRadius: 3,
                          offset: Offset(1, 1)),
                      BoxShadow(
                          color: Colors.white,
                          blurRadius: 2,
                          offset: Offset(-1, -1))
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
                          offset: Offset(-3, -3))
                    ],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(widget.icon, size: 15, color: ProfessionalColors.dark),
              const SizedBox(width: 6),
              Text(widget.label,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: ProfessionalColors.darkest)),
            ]),
          ),
        ),
      );
}

class _ProfNeoFilledButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _ProfNeoFilledButton(
      {required this.label, required this.icon, required this.onTap});
  @override
  State<_ProfNeoFilledButton> createState() => _ProfNeoFilledButtonState();
}

class _ProfNeoFilledButtonState extends State<_ProfNeoFilledButton>
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
                  colors: [ProfessionalColors.darkest, ProfessionalColors.dark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
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
                          offset: const Offset(0, -2))
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

// ── All Schedules Screen — Timeline style ─────────────────────────────────────
class _ProfAllSchedulesScreen extends StatelessWidget {
  final List<OrderModel> orders;
  const _ProfAllSchedulesScreen({required this.orders});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            backgroundColor: ProfessionalColors.darkest,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: _ProfNeoBackBtn(),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [
                    ProfessionalColors.darkest,
                    ProfessionalColors.dark
                  ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28)),
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
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5)),
                          const SizedBox(height: 3),
                          Text('${orders.length} active orders',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.65),
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
                        size: 60, color: ProfessionalColors.light),
                    SizedBox(height: 12),
                    Text('No scheduled orders',
                        style: TextStyle(
                            color: ProfessionalColors.mid, fontSize: 15)),
                  ])),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              sliver: SliverToBoxAdapter(
                child: _ProfScheduleTimeline(
                  orders: orders,
                  onTap: (o) => _showProfScheduleDetails(context, o),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Today Card (legacy - kept for compatibility) ─────────────────────────────
class _TodayCard extends StatelessWidget {
  final OrderModel order;
  final Color surf, brd, txtPri, txtSec;
  const _TodayCard(
      {required this.order,
      required this.surf,
      required this.brd,
      required this.txtPri,
      required this.txtSec});

  @override
  Widget build(BuildContext context) => Container(
        width: 200,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: ProfessionalColors.lightest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: ProfessionalColors.light.withOpacity(0.35))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(order.title,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: txtPri),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.location_on_outlined, size: 12, color: txtSec),
            const SizedBox(width: 3),
            Text(order.area, style: TextStyle(fontSize: 11, color: txtSec)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.access_time_rounded,
                size: 12, color: ProfessionalColors.mid),
            const SizedBox(width: 3),
            Text(
                '${order.serviceDate.hour}:${order.serviceDate.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ProfessionalColors.mid)),
          ]),
        ]),
      );
}

class _ProfOrderMenuBtn extends StatefulWidget {
  final OrderModel order;
  final WidgetRef ref;
  final VoidCallback onViewDetail, onChat, onReject;
  final bool isDark;
  const _ProfOrderMenuBtn({
    required this.order,
    required this.ref,
    required this.onViewDetail,
    required this.onChat,
    required this.onReject,
    required this.isDark,
  });

  @override
  State<_ProfOrderMenuBtn> createState() => _ProfOrderMenuBtnState();
}

class _ProfOrderMenuBtnState extends State<_ProfOrderMenuBtn>
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
    final order = widget.order;
    final ref = widget.ref;
    final l = AppLocalizations.of(context);
    final canAct = order.status == OrderStatus.pending ||
        order.status == OrderStatus.inProgress;
    final isPending = order.status == OrderStatus.pending;
    final isInProg = order.status == OrderStatus.inProgress;

    final items = <_ProfMenuItemData>[];
    items.add(_ProfMenuItemData(
        icon: Icons.open_in_new_rounded,
        label: 'View Details',
        color: ProfessionalColors.darkest,
        onTap: widget.onViewDetail));
    if (isPending)
      items.add(_ProfMenuItemData(
          icon: Icons.check_rounded,
          label: 'Accept',
          color: ProfessionalColors.mid,
          onTap: () {
            final ctx = context;
            widget.ref
                .read(ordersProvider.notifier)
                .acceptProfessionalOrderInFirestore(order.id)
                .then((_) {
              createOrderNotification(
                userId: order.customerId,
                title: 'Order Accepted',
                message: '${order.providerName} accepted your order.',
                orderId: order.id,
              );
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Order accepted successfully'),
                    backgroundColor: ProfessionalColors.mid,
                    behavior: SnackBarBehavior.fixed));
              }
            }).catchError((_) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Failed to accept order. Please try again.'),
                    behavior: SnackBarBehavior.fixed));
              }
            });
          }));
    if (isInProg)
      items.add(_ProfMenuItemData(
          icon: Icons.check_circle_outline_rounded,
          label: 'Complete',
          color: ProfessionalColors.success,
          onTap: () {
            final ctx = context;
            widget.ref
                .read(ordersProvider.notifier)
                .completeProfessionalOrderInFirestore(order.id)
                .then((_) {
              createOrderNotification(
                userId: order.customerId,
                title: 'Order Completed',
                message: 'Your order was completed successfully.',
                orderId: order.id,
              );
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Order completed successfully'),
                    backgroundColor: ProfessionalColors.success,
                    behavior: SnackBarBehavior.fixed));
              }
            }).catchError((_) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content:
                        Text('Failed to complete order. Please try again.'),
                    behavior: SnackBarBehavior.fixed));
              }
            });
          }));
    items.add(_ProfMenuItemData(
        icon: Icons.chat_bubble_outline_rounded,
        label: 'Chat',
        color: ProfessionalColors.dark,
        onTap: widget.onChat));
    if (canAct)
      items.add(_ProfMenuItemData(
          icon: Icons.close_rounded,
          label: 'Cancel',
          color: ProfessionalColors.error,
          onTap: widget.onReject));

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
        return Stack(children: [
          Positioned.fill(
              child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(color: Colors.transparent))),
          Positioned(
            right: 16,
            top: pos.dy + size.height - 30,
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(0.3, -0.2), end: Offset.zero)
                  .animate(curved),
              child: FadeTransition(
                  opacity: anim, child: _ProfMenuPanel(items: items)),
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
            color: const Color(0xFFEEEEF5),
            borderRadius: BorderRadius.circular(11),
            boxShadow: const [
              BoxShadow(
                  color: Color(0xFFBEBECF),
                  blurRadius: 0,
                  offset: Offset(0, 3)),
              BoxShadow(
                  color: Color(0xFFBEBECF),
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
                          color: ProfessionalColors.mid.withOpacity(0.7),
                          shape: BoxShape.circle),
                    )),
          ),
        ),
      ),
    );
  }
}

class _ProfMenuItemData {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ProfMenuItemData(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
}

class _ProfMenuPanel extends StatefulWidget {
  final List<_ProfMenuItemData> items;
  const _ProfMenuPanel({required this.items});
  @override
  State<_ProfMenuPanel> createState() => _ProfMenuPanelState();
}

class _ProfMenuPanelState extends State<_ProfMenuPanel>
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

class _ProfMenuAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color, iconBg;
  final bool isDark;
  final VoidCallback onTap;
  const _ProfMenuAction(
      {required this.icon,
      required this.label,
      required this.color,
      required this.iconBg,
      required this.isDark,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
              color: isDark
                  ? ProfessionalColors.darkest.withOpacity(0.3)
                  : const Color(0xFFF4FAF5),
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

class _SectionTitle2 extends StatelessWidget {
  final String title;
  final Color color;
  final bool isDark;
  const _SectionTitle2(
      {required this.title, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.5)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter),
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Text(title,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: -0.3)),
      ]);
}

// ─── Filter Chip ──────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label, value, selected;
  final Function(String) onTap;
  final bool isDark;
  final Color? color;
  const _FilterChip(
      {required this.label,
      required this.value,
      required this.selected,
      required this.onTap,
      required this.isDark,
      this.color});

  @override
  Widget build(BuildContext context) {
    final sel = selected == value;
    final c = color ??
        (isDark ? AppColors.darkTextPrimary : ProfessionalColors.textPrimary);
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
            color: sel
                ? c
                : (isDark ? AppColors.darkSurface : ProfessionalColors.card),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: sel
                    ? c
                    : (isDark
                        ? AppColors.darkBorder
                        : ProfessionalColors.border))),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: sel
                    ? Colors.white
                    : (isDark
                        ? AppColors.darkTextSecondary
                        : ProfessionalColors.textSecondary))),
      ),
    );
  }
}

// ─── Customer Details Sheet (for schedule cards) ──────────────────────────────
void _showProfCustomerDetailsSheet(
    BuildContext context, WidgetRef ref, OrderModel order) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final allOrders =
      ref.read(professionalFirestoreOrdersProvider).valueOrNull ?? [];
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
          color: isDark ? const Color(0xFF0B1A12) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: ProfessionalColors.lightest,
                    borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                    colors: [ProfessionalColors.dark, ProfessionalColors.mid]),
                border: Border.all(
                    color: ProfessionalColors.light.withOpacity(0.3),
                    width: 2.5)),
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
                color: isDark ? Colors.white : const Color(0xFF051F20))),
        const SizedBox(height: 4),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: ProfessionalColors.mid.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20)),
              child: const Text('Customer',
                  style: TextStyle(
                      fontSize: 12,
                      color: ProfessionalColors.mid,
                      fontWeight: FontWeight.w700))),
          const SizedBox(width: 8),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: const Color(0xFF7DA0CA).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.receipt_long_rounded,
                    size: 12, color: Color(0xFF5483B3)),
                const SizedBox(width: 4),
                Text('$totalOrders orders',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF5483B3),
                        fontWeight: FontWeight.w700)),
              ])),
        ]),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark
                ? ProfessionalColors.dark.withOpacity(0.15)
                : ProfessionalColors.lightest.withOpacity(0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ProfessionalColors.mid.withOpacity(0.15)),
          ),
          child: Column(children: [
            _CustomerInfoRow(
                icon: Icons.location_on_outlined,
                label: 'Location',
                value: order.area,
                isDark: isDark),
            Divider(
                height: 1,
                color: isDark ? Colors.white10 : Colors.grey.shade100),
            _CustomerInfoRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: contactVisible ? 'customer@example.com' : '••••••••••',
                isDark: isDark,
                locked: !contactVisible),
            Divider(
                height: 1,
                color: isDark ? Colors.white10 : Colors.grey.shade100),
            _CustomerInfoRow(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: contactVisible ? '+972 50 000 0000' : '••••••••••',
                isDark: isDark,
                locked: !contactVisible),
            Divider(
                height: 1,
                color: isDark ? Colors.white10 : Colors.grey.shade100),
            _CustomerInfoRow(
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
              color: ProfessionalColors.lightest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: ProfessionalColors.mid.withOpacity(0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.lock_outline_rounded,
                  size: 15, color: ProfessionalColors.mid),
              const SizedBox(width: 8),
              const Expanded(
                  child: Text(
                      'Contact details available after accepting the order.',
                      style: TextStyle(
                          fontSize: 12, color: ProfessionalColors.mid))),
            ]),
          ),
        ],
      ]),
    ),
  );
}

// ── Professional Order Card 3D (matching customer style) ─────────────────────
class _ProfOrderCard3D extends ConsumerStatefulWidget {
  final String orderId;
  final bool isDark;
  const _ProfOrderCard3D({required this.orderId, required this.isDark});
  @override
  ConsumerState<_ProfOrderCard3D> createState() => _ProfOrderCard3DState();
}

class _ProfOrderCard3DState extends ConsumerState<_ProfOrderCard3D>
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
        return const Color(0xFF26A69A);
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
            builder: (_) => ProfessionalOrderDetailScreen(order: order)));
  }

  void _openChat(BuildContext context, OrderModel order) {
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
            builder: (_) => ProfessionalChatScreen(otherUser: customer)));
  }

  void _showRejectDialog(BuildContext context, OrderModel order) {
    final ctrl = TextEditingController();
    final l = AppLocalizations.of(context);
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFEEEEF5),
            borderRadius: BorderRadius.circular(36),
            boxShadow: const [
              BoxShadow(
                  color: Color(0xFFBEBECF),
                  blurRadius: 24,
                  offset: Offset(10, 10)),
              BoxShadow(
                  color: Colors.white,
                  blurRadius: 24,
                  offset: Offset(-10, -10)),
            ],
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag Handle
                const SizedBox(height: 14),
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCCCCDD),
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
                const SizedBox(height: 24),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFEEEEF5),
                        boxShadow: [
                          BoxShadow(
                              color: Color(0xFFBEBECF),
                              blurRadius: 10,
                              offset: Offset(4, 4)),
                          BoxShadow(
                              color: Colors.white,
                              blurRadius: 10,
                              offset: Offset(-4, -4)),
                        ],
                      ),
                      child: const Icon(Icons.cancel_outlined,
                          color: Color(0xFFEF4444), size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(l.get('cancel_reason'),
                              style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF333355),
                                  letterSpacing: -0.3)),
                          const SizedBox(height: 2),
                          Text(order.title,
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF7777AA)),
                              overflow: TextOverflow.ellipsis),
                        ])),
                  ]),
                ),
                const SizedBox(height: 18),
                // Info box
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEEEF5),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
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
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 16, color: Color(0xFFEF4444)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(
                            l.get('enter_cancel_reason'),
                            style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF555577),
                                height: 1.5),
                          )),
                        ]),
                  ),
                ),
                const SizedBox(height: 20),
                // Label
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Text(l.get('cancel_reason'),
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7777AA))),
                ),
                const SizedBox(height: 8),
                // Text field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEEEF5),
                      borderRadius: BorderRadius.circular(18),
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
                      controller: ctrl,
                      maxLines: 3,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? l.get('cancel_reason')
                          : null,
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF333355)),
                      decoration: InputDecoration(
                        hintText: '${l.get("cancel_reason")}...',
                        hintStyle: const TextStyle(
                            color: Color(0xFFAAAACC), fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                // Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(children: [
                    Expanded(
                      child: _NeoSheetOutlineButton(
                        label: l.get('back'),
                        onTap: () => Navigator.pop(ctx),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _NeoSheetDangerButton(
                        label: l.get('confirm_cancel'),
                        onTap: () {
                          if (!formKey.currentState!.validate()) return;
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
                              .rejectProfessionalOrderInFirestore(
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
                                      backgroundColor: ProfessionalColors.error,
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
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orders =
        ref.watch(professionalFirestoreOrdersProvider).valueOrNull ?? [];
    final order = orders
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

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
        _ctrl.forward();
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        _ctrl.reverse();
        _openDetail(context, order);
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
                        color: accent.withOpacity(0.20),
                        blurRadius: 0,
                        offset: const Offset(0, 5)),
                    BoxShadow(
                        color: accent.withOpacity(0.10),
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
                      // Header row
                      Row(children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              accent.withOpacity(0.6),
                              accent.withOpacity(0.3)
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
                                      color: Color(0xFF1A2A1A),
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
                      _ProfOrderIdRow(orderId: order.id, accentColor: accent),
                      const SizedBox(height: 10),

                      // Progress bar
                      _ProfOrderProgressBar(
                          status: order.status, accentColor: accent),
                      const SizedBox(height: 10),

                      // Chips row + 3-dots
                      Row(children: [
                        _Prof3DInfoChip(
                            icon: Icons.calendar_today_outlined,
                            label:
                                '${order.serviceDate.day}/${order.serviceDate.month}/${order.serviceDate.year}',
                            color: accent),
                        if (order.area.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _Prof3DInfoChip(
                              icon: Icons.location_on_outlined,
                              label: order.area,
                              color: accent)
                        ],
                        if (order.priority == OrderPriority.urgent) ...[
                          const SizedBox(width: 6),
                          _Prof3DInfoChip(
                              icon: Icons.priority_high_rounded,
                              label: 'Urgent',
                              color: ProfessionalColors.error)
                        ],
                        const Spacer(),
                        _ProfOrderCardDotsMenu(
                          order: order,
                          ref: ref,
                          onChat: () => _openChat(context, order),
                          onAccept: isPending
                              ? () {
                                  final ctx = context;
                                  ref
                                      .read(ordersProvider.notifier)
                                      .acceptProfessionalOrderInFirestore(
                                          order.id)
                                      .then((_) {
                                    createOrderNotification(
                                      userId: order.customerId,
                                      title: 'Order Accepted',
                                      message:
                                          '${order.providerName} accepted your order.',
                                      orderId: order.id,
                                    );
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  'Order accepted successfully'),
                                              backgroundColor:
                                                  ProfessionalColors.mid,
                                              behavior:
                                                  SnackBarBehavior.fixed));
                                    }
                                  }).catchError((_) {
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                          const SnackBar(
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
                                  final ctx = context;
                                  ref
                                      .read(ordersProvider.notifier)
                                      .completeProfessionalOrderInFirestore(
                                          order.id)
                                      .then((_) {
                                    createOrderNotification(
                                      userId: order.customerId,
                                      title: 'Order Completed',
                                      message:
                                          'Your order was completed successfully.',
                                      orderId: order.id,
                                    );
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  'Order completed successfully'),
                                              backgroundColor:
                                                  ProfessionalColors.success,
                                              behavior:
                                                  SnackBarBehavior.fixed));
                                    }
                                  }).catchError((_) {
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  'Failed to complete order. Please try again.'),
                                              behavior:
                                                  SnackBarBehavior.fixed));
                                    }
                                  });
                                }
                              : null,
                          onCancel: canAct
                              ? () => _showRejectDialog(context, order)
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
                              color: ProfessionalColors.error.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: ProfessionalColors.error
                                      .withOpacity(0.2))),
                          child: Row(children: [
                            const Icon(Icons.info_outline,
                                size: 14, color: ProfessionalColors.error),
                            const SizedBox(width: 6),
                            Expanded(
                                child: Text('Cancelled: ${order.rejectReason}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: ProfessionalColors.error,
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

// ── Prof Order ID Row ─────────────────────────────────────────────────────────
class _ProfOrderIdRow extends StatefulWidget {
  final String orderId;
  final Color accentColor;
  const _ProfOrderIdRow({required this.orderId, required this.accentColor});
  @override
  State<_ProfOrderIdRow> createState() => _ProfOrderIdRowState();
}

class _ProfOrderIdRowState extends State<_ProfOrderIdRow> {
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
            color: const Color(0xFFF0FAF4),
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
                : const Color(0xFFEEEEF5),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                  color: Color(0xFFBEBECF),
                  blurRadius: 3,
                  offset: Offset(1, 1)),
              BoxShadow(
                  color: Colors.white, blurRadius: 3, offset: Offset(-1, -1))
            ],
          ),
          child: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded,
              size: 13,
              color: _copied ? widget.accentColor : const Color(0xFF9999BB)),
        ),
      ),
    ]);
  }
}

// ── Prof Order Progress Bar ───────────────────────────────────────────────────
class _ProfOrderProgressBar extends StatelessWidget {
  final OrderStatus status;
  final Color accentColor;
  const _ProfOrderProgressBar(
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

// ── Prof 3D Info Chip ─────────────────────────────────────────────────────────
class _Prof3DInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Prof3DInfoChip(
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
                offset: const Offset(0, 3))
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

// ── Prof Order Card 3-Dots Menu ───────────────────────────────────────────────
class _ProfOrderCardDotsMenu extends StatefulWidget {
  final OrderModel order;
  final WidgetRef ref;
  final VoidCallback onChat;
  final VoidCallback? onAccept;
  final VoidCallback? onComplete;
  final VoidCallback? onCancel;
  final Color accentColor;
  const _ProfOrderCardDotsMenu({
    required this.order,
    required this.ref,
    required this.onChat,
    this.onAccept,
    this.onComplete,
    this.onCancel,
    required this.accentColor,
  });
  @override
  State<_ProfOrderCardDotsMenu> createState() => _ProfOrderCardDotsMenuState();
}

class _ProfOrderCardDotsMenuState extends State<_ProfOrderCardDotsMenu>
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
    final items = <_ProfCardMenuItemData>[];
    if (widget.onAccept != null)
      items.add(_ProfCardMenuItemData(Icons.check_rounded, 'Accept',
          const Color(0xFF26A69A), widget.onAccept!));
    if (widget.onComplete != null)
      items.add(_ProfCardMenuItemData(Icons.check_circle_outline_rounded,
          'Complete', const Color(0xFF22C55E), widget.onComplete!));
    items.add(_ProfCardMenuItemData(Icons.chat_bubble_outline_rounded, 'Chat',
        ProfessionalColors.dark, widget.onChat));
    if (widget.onCancel != null)
      items.add(_ProfCardMenuItemData(Icons.close_rounded, 'Cancel',
          ProfessionalColors.error, widget.onCancel!));

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
        // Each item ~58px (48 icon + 10 padding), plus 20 vertical padding
        final panelH = items.length * 58.0 + 20;
        // Preferred: open downward from the button
        double topPos = pos.dy + size.height - 30;
        // If panel would overflow bottom of screen, open upward instead
        if (topPos + panelH > screenH - 16) {
          topPos = pos.dy - panelH + 30;
        }
        // Clamp so it never goes above the top either
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
                  opacity: anim, child: _ProfCardMenuPanel(items: items)),
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
              color: const Color(0xFFEEEEF5),
              borderRadius: BorderRadius.circular(11),
              boxShadow: const [
                BoxShadow(
                    color: Color(0xFFBEBECF),
                    blurRadius: 0,
                    offset: Offset(0, 3)),
                BoxShadow(
                    color: Color(0xFFBEBECF),
                    blurRadius: 6,
                    offset: Offset(3, 3)),
                BoxShadow(
                    color: Colors.white, blurRadius: 6, offset: Offset(-3, -3))
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

class _ProfCardMenuItemData {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ProfCardMenuItemData(this.icon, this.label, this.color, this.onTap);
}

class _ProfCardMenuPanel extends StatefulWidget {
  final List<_ProfCardMenuItemData> items;
  const _ProfCardMenuPanel({required this.items});
  @override
  State<_ProfCardMenuPanel> createState() => _ProfCardMenuPanelState();
}

class _ProfCardMenuPanelState extends State<_ProfCardMenuPanel>
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
            color: const Color(0xFFEEEEF5),
            boxShadow: const [
              BoxShadow(
                  color: Color(0xFFBEBECF),
                  blurRadius: 16,
                  offset: Offset(6, 6)),
              BoxShadow(
                  color: Colors.white, blurRadius: 16, offset: Offset(-6, -6))
            ]),
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
                      scale: 0.6 + 0.4 * anim.value.clamp(0, 1), child: child)),
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
                                offset: Offset(-3, -3))
                          ]),
                      child: Icon(item.icon, color: item.color, size: 20)),
                ),
              ),
            );
          }),
        ),
      );
}

// ── Customer Info Row (used in customer popup) ────────────────────────────────
class _CustomerInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final bool locked;
  const _CustomerInfoRow({
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
                  color: ProfessionalColors.mid.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon,
                  color: locked
                      ? ProfessionalColors.mid.withOpacity(0.45)
                      : ProfessionalColors.mid,
                  size: 18)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? ProfessionalColors.hintText
                            : ProfessionalColors.secondaryText,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: locked ? FontWeight.w400 : FontWeight.w700,
                        color: locked
                            ? (isDark
                                ? ProfessionalColors.hintText
                                : ProfessionalColors.secondaryText)
                            : (isDark ? Colors.white : const Color(0xFF051F20)),
                        letterSpacing: locked ? 2 : 0)),
              ])),
          if (locked)
            Icon(Icons.lock_outline_rounded,
                size: 14, color: ProfessionalColors.mid.withOpacity(0.5)),
        ]),
      );
}

class _ChatBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _ChatBtn({required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: ProfessionalColors.mid.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.chat_bubble_outline_rounded,
                size: 17, color: ProfessionalColors.mid)),
      );
}

class _DetailsBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _DetailsBtn({required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: ProfessionalColors.mid.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.open_in_new_rounded,
                size: 17, color: ProfessionalColors.mid)),
      );
}

class _SmallOutlineBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SmallOutlineBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 14),
        label: Text(
          label,
          style: const TextStyle(fontSize: 11),
          overflow: TextOverflow.ellipsis,
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip(
      {required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ]);
}

class _OrderProgressBar extends StatelessWidget {
  final OrderStatus status;
  const _OrderProgressBar({required this.status});

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
        return ProfessionalColors.warning;
      case OrderStatus.inProgress:
        return ProfessionalColors.mid;
      case OrderStatus.completed:
        return ProfessionalColors.accent;
      case OrderStatus.cancelled:
        return ProfessionalColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: _progress,
        backgroundColor: isDark
            ? AppColors.darkSurfaceVariant
            : ProfessionalColors.background,
        valueColor: AlwaysStoppedAnimation<Color>(_color),
        minHeight: 5,
      ),
    );
  }
}

// ─── Professional Profile Screen ──────────────────────────────────────────────
class ProfessionalProfileScreen extends ConsumerStatefulWidget {
  const ProfessionalProfileScreen({super.key});
  @override
  ConsumerState<ProfessionalProfileScreen> createState() =>
      _ProfessionalProfileScreenState();
}

class _ProfessionalProfileScreenState
    extends ConsumerState<ProfessionalProfileScreen>
    with WidgetsBindingObserver {
  bool _pickingPhoto = false;

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

  // Same defensive-only refresh already proven for the Customer Provider
  // Profile screen (see provider_profile_screen.dart): a backgrounded
  // Flutter Web tab's already-open providerReviewsProvider listener has
  // been observed to not promptly redeliver a Firestore change (e.g. Admin
  // hiding a review) made while this tab was backgrounded. Recreating just
  // this provider's stream the moment the tab returns to the foreground
  // guarantees a fresh read without waiting on that listener's own timing.
  // Uses the same user-resolution fallback already used by _pickPhoto()
  // above, matching exactly what build() below watches
  // (providerReviewsProvider(user?.id ?? '')).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final user = ref.read(liveCurrentUserProvider).valueOrNull ??
          ref.read(authProvider);
      ref.invalidate(providerReviewsProvider(user?.id ?? ''));
    }
  }

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
        accent: ProfessionalColors.mid,
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
    final reviewsAsync = ref.watch(providerReviewsProvider(user?.id ?? ''));
    final myOrders =
        ref.watch(professionalFirestoreOrdersProvider).valueOrNull ??
            const <OrderModel>[];
    final completedCount =
        myOrders.where((o) => o.status == OrderStatus.completed).length;

    if (user == null) return const SizedBox();

    final allCats =
        ref.watch(categoriesProvider).valueOrNull ?? const <CategoryModel>[];
    // Resolved once per build (not per service row) so each service card can
    // look up its category by id without its own ref.watch call.
    final categoriesById = {for (final c in allCats) c.id: c};

    // Parse bio/response (hours now come from user.effectiveWork* below)
    final desc = user.serviceDescription ?? '';
    String bio = '', response = 'Usually within an hour';
    if (desc.contains('hours:')) {
      for (final p in desc.split('|')) {
        final t = p.trim();
        if (t.startsWith('hours:')) {
          // handled via user.effectiveWorkingHoursLabel
        } else if (t.startsWith('response:'))
          response = t.replaceFirst('response:', '').trim();
        else if (t.isNotEmpty) bio = t;
      }
    } else {
      bio = desc;
    }

    final completionRate = myOrders.isEmpty
        ? 0
        : ((completedCount / myOrders.length) * 100).round();

    final allReviews = reviewsAsync.valueOrNull ?? const <ReviewModel>[];
    final avgRating = allReviews.isEmpty
        ? 0.0
        : allReviews.map((r) => r.rating).reduce((a, b) => a + b) /
            allReviews.length;
    final activeCriteria =
        ref.watch(reviewCriteriaProvider).where((c) => c.isActive).toList();

    // Only ever the live, active CategoryModel objects this provider's raw
    // specialties/specialty actually resolve to — never a fallback built
    // from an unmatched raw string (see _resolveProviderServiceCategories).
    final resolvedSpecialtyCategories =
        _resolveProviderServiceCategories(allCats, user);

    return Scaffold(
      backgroundColor: _pNeoBase,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Hero ──────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                // Same gradient/shadow identity as the Professional Home
                // header (see ProfessionalDashboard's Hero Container).
                gradient: ProfessionalColors.primaryGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                      color: Color(0x600F766E),
                      blurRadius: 24,
                      offset: Offset(0, 10)),
                ],
              ),
              child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: Column(children: [
                      // top bar
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(l.get('profile'),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3)),
                            // Permanent Logout button — replaces the former
                            // three-dots menu, whose only entry was Logout.
                            // The callback below is that menu's Logout
                            // callback, unchanged.
                            _ProfProfileLogoutBtn(
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
                      const SizedBox(height: 20),
                      // avatar
                      Stack(alignment: Alignment.bottomRight, children: [
                        Container(
                          width: 86,
                          height: 86,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [
                                ProfessionalColors.mid,
                                Color(0xFF3D7A6E)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.45),
                                width: 2.5),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x55000000),
                                  blurRadius: 18,
                                  offset: Offset(0, 7))
                            ],
                          ),
                          child: ProfileAvatarImage(
                            imageUrl: user.avatar,
                            size: 86,
                            fallbackText:
                                user.fullName.isNotEmpty ? user.fullName : 'P',
                            fallbackTextStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w900),
                          ),
                        ),
                        GestureDetector(
                          onTap: _pickingPhoto ? null : _pickPhoto,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: ProfessionalColors.mid,
                              shape: BoxShape.circle,
                              border: Border.all(color: _pNeoBase, width: 2.5),
                              boxShadow: const [
                                BoxShadow(
                                    color: Color(0x44000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 3))
                              ],
                            ),
                            child: _pickingPhoto
                                ? const Padding(
                                    padding: EdgeInsets.all(5),
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.camera_alt_rounded,
                                    color: Colors.white, size: 12),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Text(user.fullName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3)),
                      const SizedBox(height: 3),
                      Text(
                        '${resolvedSpecialtyCategories.isNotEmpty ? l.get(resolvedSpecialtyCategories.first.nameKey) : l.get("professional")} · ${user.role == UserRole.contractor ? l.get("company_contractor") : l.get("individual")}',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.5), fontSize: 11),
                      ),
                      const SizedBox(height: 16),
                      // stats strip (borderless like contractor)
                      Container(
                        decoration: BoxDecoration(
                          border: Border(
                              top: BorderSide(
                                  color: Colors.white.withOpacity(0.09))),
                        ),
                        child: Row(children: [
                          _ProfNeoHeroStat(
                              icon: Icons.star_rounded,
                              value: avgRating.toStringAsFixed(1),
                              label: l.get('rating'),
                              color: const Color(0xFFFFCA28)),
                          _ProfNeoHeroStat(
                              icon: Icons.check_circle_rounded,
                              value: '$completedCount',
                              label: l.get('completed_count'),
                              color: const Color(0xFF5DCAA5)),
                          _ProfNeoHeroStat(
                              icon: Icons.receipt_long_rounded,
                              value: '${myOrders.length}',
                              label: l.get('orders_count'),
                              color: ProfessionalColors.light),
                          _ProfNeoHeroStat(
                              icon: Icons.workspace_premium_rounded,
                              value: '${user.experienceYears ?? 0}',
                              label: l.get('years_exp'),
                              color: ProfessionalColors.mid,
                              isLast: true),
                        ]),
                      ),
                    ]),
                  )),
            ),
          ),

          // ── Body ──────────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
                delegate: SliverChildListDelegate([
              // mini stats
              Row(children: [
                Expanded(
                    child: _ProfNeoMiniStat(
                        value: '$completionRate%',
                        label: 'Completion rate',
                        color: ProfessionalColors.mid)),
                const SizedBox(width: 10),
                Expanded(
                    child: _ProfNeoMiniStat(
                        value: response,
                        label: 'Response time',
                        color: ProfessionalColors.dark,
                        maxLines: 2)),
              ]),
              const SizedBox(height: 18),

              // ── SECTION 1: Basic Info ──────────────────────────────────
              _ProfNeoSectionHead(
                icon: Icons.person_outline_rounded,
                iconColor: ProfessionalColors.dark,
                title: l.get('basic_info'),
                action: _ProfNeoSectionPill(
                    label: l.get('edit'),
                    icon: Icons.edit_rounded,
                    color: ProfessionalColors.dark,
                    onTap: () => _showEditFullProfile(context, user, l)),
              ),
              const SizedBox(height: 10),
              _ProfNeoCard(children: [
                _ProfNeoInfoRow(
                    icon: Icons.person_outline_rounded,
                    iconColor: ProfessionalColors.dark,
                    label: l.get('full_name'),
                    value: user.fullName),
                _ProfNeoInfoRow(
                    icon: Icons.email_outlined,
                    iconColor: ProfessionalColors.mid,
                    label: l.get('email'),
                    value: user.email),
                _ProfNeoInfoRow(
                    icon: Icons.phone_outlined,
                    iconColor: ProfessionalColors.dark,
                    label: l.get('phone'),
                    value: user.phone),
                _ProfNeoInfoRow(
                    icon: Icons.map_outlined,
                    iconColor: const Color(0xFF3D7A6E),
                    label: l.get('work_area'),
                    value: user.workArea?.isNotEmpty == true
                        ? l.translateRegion(user.workArea!)
                        : user.city),
                _ProfNeoInfoRow(
                    icon: Icons.work_history_outlined,
                    iconColor: ProfessionalColors.dark,
                    label: l.get('experience'),
                    value: '${user.experienceYears ?? 0} ${l.get("years")}'),
                _ProfNeoInfoRow(
                    icon: Icons.language_outlined,
                    iconColor: ProfessionalColors.mid,
                    label: 'Languages',
                    value: user.languages.isNotEmpty
                        ? user.languages.join(', ')
                        : '—'),
                _ProfNeoInfoRow(
                    icon: Icons.event_available_rounded,
                    iconColor: ProfessionalColors.mid,
                    label: 'Working Days',
                    value: formatWorkingDaysLabel(user.effectiveWorkingDays)),
                _ProfNeoInfoRow(
                    icon: Icons.access_time_rounded,
                    iconColor: ProfessionalColors.dark,
                    label: l.get('working_hours'),
                    value: user.effectiveWorkingHoursLabel,
                    isLast: true),
              ]),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                    color: _pNeoBase,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0xFFBEBECF),
                          blurRadius: 8,
                          offset: Offset(4, 4),
                          spreadRadius: -1),
                      BoxShadow(
                          color: Colors.white,
                          blurRadius: 8,
                          offset: Offset(-4, -4),
                          spreadRadius: -1),
                    ]),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    bio.isNotEmpty ? bio : 'No description added yet.',
                    style: TextStyle(
                        fontSize: 13,
                        color: ProfessionalColors.dark.withOpacity(0.85),
                        height: 1.6),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── SECTION 2: Specialties ─────────────────────────────────
              _ProfNeoSectionHead(
                icon: Icons.category_outlined,
                iconColor: ProfessionalColors.darkest,
                title: l.get('specialties'),
                action: _ProfNeoDotsBtn(
                  onTap: () => _showSpecialtiesMenu(context, user),
                ),
              ),
              const SizedBox(height: 10),
              _ProfNeoCard(children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: resolvedSpecialtyCategories.isEmpty
                      ? Center(
                          child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text('Tap ⋮ to add specialties',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: ProfessionalColors.mid
                                          .withOpacity(0.6)))))
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: resolvedSpecialtyCategories.map((cat) {
                            return _ProfNeoChip(
                                emoji: cat.icon,
                                label: l.get(cat.nameKey),
                                color: ProfessionalColors.dark);
                          }).toList(),
                        ),
                ),
              ]),
              const SizedBox(height: 20),

              // ── SECTION 3: Services ────────────────────────────────────
              _ProfNeoSectionHead(
                icon: Icons.build_circle_outlined,
                iconColor: ProfessionalColors.mid,
                title: l.get('services_prices'),
                action: _ProfNeoSectionPill(
                    label: l.get('add'),
                    icon: Icons.add_rounded,
                    color: ProfessionalColors.mid,
                    onTap: () => _showAddService(context, user)),
              ),
              const SizedBox(height: 10),
              _ProfNeoCard(
                  children: user.servicesList.isNotEmpty
                      ? user.servicesList
                          .map((svc) => _ProfNeoServiceRow(
                              service: svc,
                              category: categoriesById[svc.categoryId],
                              onEdit: () =>
                                  _showEditService(context, user, svc),
                              onDelete: () => _deleteService(user, svc.id)))
                          .toList()
                      : [
                          Padding(
                              padding: const EdgeInsets.all(16),
                              child: Center(
                                  child: Text('Tap + to add services',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: ProfessionalColors.mid
                                              .withOpacity(0.6)))))
                        ]),
              const SizedBox(height: 20),

              // ── SECTION 4: Ratings ─────────────────────────────────────
              _ProfNeoSectionHead(
                  icon: Icons.star_rounded,
                  iconColor: const Color(0xFFBA7517),
                  title: l.get('ratings_reviews')),
              const SizedBox(height: 10),
              _ProfNeoCard(children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(avgRating.toStringAsFixed(1),
                              style: const TextStyle(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF051F20),
                                  letterSpacing: -2,
                                  height: 1)),
                          Row(
                              children: List.generate(
                                  5,
                                  (i) => Icon(
                                      i < avgRating.round()
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      color: const Color(0xFFFFCA28),
                                      size: 14))),
                          const SizedBox(height: 4),
                          Text('${allReviews.length} ${l.get("rating")}',
                              style: const TextStyle(
                                  fontSize: 10, color: ProfessionalColors.mid)),
                        ]),
                        const SizedBox(width: 18),
                        Expanded(
                            child: Column(children: [
                          for (var i = 0; i < activeCriteria.length; i++) ...[
                            _ProfNeoRatingBar(
                                label: activeCriteria[i].name,
                                value: _profAvgForCriterion(
                                    allReviews, activeCriteria[i]),
                                maxRating: activeCriteria[i].maxRating),
                            if (i != activeCriteria.length - 1)
                              const SizedBox(height: 8),
                          ],
                        ])),
                      ]),
                ),
              ]),
              const SizedBox(height: 10),
              _ProfNeoCard(
                  children: allReviews
                      .asMap()
                      .entries
                      .map((e) => _ProfNeoReviewCard(
                          review: e.value,
                          isLast: e.key == allReviews.length - 1))
                      .toList()),
              const SizedBox(height: 20),

              // ── SECTION 5: Quick Actions ───────────────────────────────
              _ProfNeoSectionHead(
                  icon: Icons.bolt_rounded,
                  iconColor: ProfessionalColors.dark,
                  title: 'Quick actions'),
              const SizedBox(height: 10),
              _ProfNeoCard(children: [
                _ProfNeoActionRow(
                    icon: Icons.receipt_long_rounded,
                    iconColor: ProfessionalColors.dark,
                    label: 'My orders',
                    onTap: () => ref.read(navIndexProvider.notifier).state = 0),
                _ProfNeoActionRow(
                    icon: Icons.notifications_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                    label: 'Notifications',
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const _ProfNotificationsPage()))),
                _ProfNeoActionRow(
                    icon: Icons.flag_rounded,
                    iconColor: const Color(0xFFD97706),
                    label: 'My Complaints',
                    onTap: () => _showComplaintSheet(context)),
                _ProfNeoActionRow(
                    icon: Icons.help_outline_rounded,
                    iconColor: ProfessionalColors.dark,
                    label: 'Help & support',
                    isLast: true,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const HelpCenterScreen(
                                userRole: UserRole.professional,
                                accentColor: ProfessionalColors.mid,
                                gradientStart: ProfessionalColors.darkest,
                                gradientEnd: ProfessionalColors.dark)))),
              ]),
              SizedBox(height: 36 + 92 + MediaQuery.of(context).padding.bottom),
            ])),
          ),
        ],
      ),
    );
  }

  // ── Edit Full Profile (merged) ──────────────────────────────────────────────
  void _showEditFullProfile(
      BuildContext context, UserModel user, AppLocalizations l) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: user.fullName);
    final expCtrl =
        TextEditingController(text: user.experienceYears?.toString() ?? '');
    final emailCtrl = TextEditingController(text: user.email);
    final phoneCtrl = TextEditingController(text: user.phone);
    final workAreaKey = GlobalKey<WorkAreaFieldState>();
    final languagesKey = GlobalKey<LanguagesFieldState>();

    // Parse response/bio from serviceDescription (hours come from
    // user.effectiveWork* so the edit sheet always reflects the same
    // resolved schedule as the rest of the app).
    final desc = user.serviceDescription ?? '';
    String bio = '', response = 'Usually within an hour';
    if (desc.contains('hours:')) {
      for (final p in desc.split('|')) {
        final t = p.trim();
        if (t.startsWith('hours:')) {
          // handled via user.effectiveWorkingHoursLabel
        } else if (t.startsWith('response:'))
          response = t.replaceFirst('response:', '').trim();
        else if (t.isNotEmpty) bio = t;
      }
    } else {
      bio = desc;
    }

    final hoursKey = GlobalKey<WorkingHoursFieldState>();
    final workingDaysKey = GlobalKey<WorkingDaysFieldState>();
    final responseKey = GlobalKey<ResponseTimeFieldState>();
    final bioCtrl = TextEditingController(text: bio);
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFEEEEF5),
            borderRadius: BorderRadius.circular(32),
            boxShadow: const [
              BoxShadow(
                  color: Color(0xFFBEBECF),
                  blurRadius: 20,
                  offset: Offset(8, 8)),
              BoxShadow(
                  color: Colors.white, blurRadius: 20, offset: Offset(-8, -8)),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle + X button row
                  Row(children: [
                    Expanded(
                        child: Center(
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
                    ))),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFEEEEF5),
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
                        child: const Icon(Icons.close_rounded,
                            size: 16, color: Color(0xFF888899)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  // Title row
                  Row(children: [
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
                      child: const Icon(Icons.person_pin_rounded,
                          color: ProfessionalColors.dark, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Text(l.get('edit_profile_title'),
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF333355))),
                  ]),
                  const SizedBox(height: 18),
                  // Info hint card
                  Container(
                    padding: const EdgeInsets.all(14),
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
                    child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: Color(0xFF7777AA), size: 18),
                          SizedBox(width: 10),
                          Expanded(
                              child: Text(
                                  'Update your personal details and profile information.',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF555577),
                                      height: 1.5))),
                        ]),
                  ),
                  const SizedBox(height: 20),
                  // Fields using same neo input as complaint
                  const Text('Full Name',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7777AA))),
                  const SizedBox(height: 8),
                  _ProfNeoInputField(
                      controller: nameCtrl,
                      hint: 'Your full name',
                      icon: Icons.person_outline_rounded,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null),
                  const SizedBox(height: 14),
                  const Text('Experience (years)',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7777AA))),
                  const SizedBox(height: 8),
                  _ProfNeoInputField(
                      controller: expCtrl,
                      hint: 'e.g. 5',
                      icon: Icons.work_history_outlined),
                  const SizedBox(height: 14),
                  const Text('Email',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7777AA))),
                  const SizedBox(height: 8),
                  _ProfNeoInputField(
                      controller: emailCtrl,
                      hint: 'your@email.com',
                      icon: Icons.email_outlined),
                  const SizedBox(height: 14),
                  const Text('Phone',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7777AA))),
                  const SizedBox(height: 8),
                  _ProfNeoInputField(
                      controller: phoneCtrl,
                      hint: '+972 5X XXX XXXX',
                      icon: Icons.phone_outlined),
                  const SizedBox(height: 14),
                  const Text('Work Area',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7777AA))),
                  const SizedBox(height: 8),
                  WorkAreaField(
                      key: workAreaKey,
                      initialValue: user.workArea ?? user.city,
                      accentColor: const Color(0xFF7777AA)),
                  const SizedBox(height: 14),
                  const Text('Working Hours',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7777AA))),
                  const SizedBox(height: 8),
                  WorkingHoursField(
                      key: hoursKey,
                      initialRange: user.effectiveWorkingHoursLabel,
                      accentColor: const Color(0xFF7777AA)),
                  const SizedBox(height: 14),
                  const Text('Working Days',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7777AA))),
                  const SizedBox(height: 8),
                  WorkingDaysField(
                      key: workingDaysKey,
                      initialValue: user.effectiveWorkingDays,
                      accentColor: const Color(0xFF7777AA)),
                  const SizedBox(height: 14),
                  const Text('Response Time',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7777AA))),
                  const SizedBox(height: 8),
                  ResponseTimeField(
                      key: responseKey,
                      initialValue: response,
                      accentColor: const Color(0xFF7777AA)),
                  const SizedBox(height: 14),
                  const Text('Languages',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7777AA))),
                  const SizedBox(height: 8),
                  LanguagesField(
                      key: languagesKey,
                      initialValue: user.languages,
                      accentColor: const Color(0xFF7777AA)),
                  const SizedBox(height: 14),
                  const Text('About Me',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7777AA))),
                  const SizedBox(height: 8),
                  _ProfNeoInputField(
                      controller: bioCtrl,
                      hint: 'Brief description about yourself...',
                      icon: Icons.notes_rounded,
                      maxLines: 3),
                  const SizedBox(height: 28),
                  StatefulBuilder(
                    builder: (ctx, setBtnState) => _ProfNeoSubmitButton(
                      label: 'Save Changes',
                      loading: saving,
                      onTap: () async {
                        if (saving) return;
                        if (!formKey.currentState!.validate()) return;
                        final hoursValue = hoursKey.currentState!.validate();
                        if (hoursValue == null) return;
                        final workingDaysValue =
                            workingDaysKey.currentState!.validate();
                        if (workingDaysValue == null) return;
                        final responseValue = responseKey.currentState!.value;
                        final langs = languagesKey.currentState!.value;
                        final workAreaValue = workAreaKey.currentState!.value;
                        final hoursParts = splitWorkingHoursRange(hoursValue);
                        final newDesc = [
                          if (bioCtrl.text.trim().isNotEmpty)
                            bioCtrl.text.trim(),
                          'hours: $hoursValue',
                          'response: $responseValue',
                        ].join(' | ');
                        final nav = Navigator.of(ctx);
                        final messenger = ScaffoldMessenger.of(context);
                        setBtnState(() => saving = true);
                        try {
                          await ref
                              .read(authProvider.notifier)
                              .updateProfessionalProfile(user.copyWith(
                                fullName: nameCtrl.text.trim(),
                                experienceYears:
                                    int.tryParse(expCtrl.text.trim()),
                                email: emailCtrl.text.trim(),
                                phone: phoneCtrl.text.trim(),
                                workArea: workAreaValue,
                                languages: langs,
                                serviceDescription:
                                    newDesc.isEmpty ? null : newDesc,
                                workingDays: workingDaysValue,
                                workStartTime: hoursParts?[0],
                                workEndTime: hoursParts?[1],
                              ));
                          if (!mounted) return;
                          nav.pop();
                          messenger.showSnackBar(SnackBar(
                            content: Row(children: [
                              const Icon(Icons.check_circle,
                                  color: Colors.white),
                              const SizedBox(width: 8),
                              Text(l.get('profile_updated')),
                            ]),
                            backgroundColor: ProfessionalColors.mid,
                            behavior: SnackBarBehavior.fixed,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ));
                        } catch (e) {
                          debugPrint(
                              '[ProfessionalProfile] updateProfile error: $e');
                          setBtnState(() => saving = false);
                          if (!mounted) return;
                          messenger.showSnackBar(const SnackBar(
                            content: Row(children: [
                              Icon(Icons.error_rounded, color: Colors.white),
                              SizedBox(width: 8),
                              Text('Failed to save. Please try again.'),
                            ]),
                            backgroundColor: Color(0xFFEF4444),
                            behavior: SnackBarBehavior.fixed,
                          ));
                        }
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

  // ── Edit Categories ─────────────────────────────────────────────────────────
  void _showEditCategories(BuildContext context, UserModel user) {
    final l = AppLocalizations.of(context);
    final allCats = ref.read(categoriesProvider).value ?? [];
    List<String> selected = List.from(user.specialties);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: ProfessionalColors.border,
                            borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text(l.get('edit_specialties'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allCats.map((cat) {
                      final key = cat.nameKey;
                      final sel = selected.contains(key);
                      return GestureDetector(
                        onTap: () => setSheet(() {
                          if (sel)
                            selected.remove(key);
                          else
                            selected.add(key);
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                              color: sel
                                  ? ProfessionalColors.mid
                                  : ProfessionalColors.card,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: sel
                                      ? ProfessionalColors.mid
                                      : ProfessionalColors.light
                                          .withOpacity(0.4),
                                  width: sel ? 2 : 1)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(cat.icon,
                                style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 6),
                            Text(l.get(key),
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: sel
                                        ? Colors.white
                                        : ProfessionalColors.mid)),
                            if (sel) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 13)
                            ],
                          ]),
                        ),
                      );
                    }).toList()),
                const SizedBox(height: 20),
                ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: ProfessionalColors.mid),
                    onPressed: () async {
                      await ref
                          .read(authProvider.notifier)
                          .saveSpecialties(selected);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Text(l.get('save_specialties'))),
              ]),
        ),
      ),
    );
  }

  // ── Add/Edit Service ────────────────────────────────────────────────────────
  // Resolves the real, currently-active Firestore categories this provider's
  // specialties actually correspond to, using the exact same normalized
  // (trim + lowercase) category.id/category.nameKey vs specialties equality
  // already used by categoryProvidersStreamProvider (app_providers.dart) —
  // including its same legacy fallback to the single `specialty` field when
  // `specialties` is empty. Never guesses a category from the service name
  // and never offers an unrelated category as a fallback.
  List<CategoryModel> _resolveProviderServiceCategories(
      List<CategoryModel> activeCategories, UserModel user) {
    final rawSpecialties = user.specialties.isNotEmpty
        ? user.specialties
        : (user.specialty != null ? [user.specialty!] : const <String>[]);
    final normalizedSpecialties = rawSpecialties
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toSet();
    if (normalizedSpecialties.isEmpty) return const [];
    return activeCategories.where((c) {
      final normId = c.id.trim().toLowerCase();
      final normName = c.nameKey.trim().toLowerCase();
      return normalizedSpecialties.contains(normId) ||
          normalizedSpecialties.contains(normName);
    }).toList();
  }

  void _showAddService(BuildContext context, UserModel user) =>
      _showServiceSheet(context, user, null);

  void _showEditService(
          BuildContext context, UserModel user, ServiceModel svc) =>
      _showServiceSheet(context, user, svc);

  void _showServiceSheet(
      BuildContext context, UserModel user, ServiceModel? existing) {
    final l = AppLocalizations.of(context);
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final priceCtrl = TextEditingController(
        text:
            existing?.price == null ? '' : existing!.price.toStringAsFixed(0));
    final isEdit = existing != null;

    // Real Firestore categories this provider's specialties actually
    // resolve to — read once when the sheet opens (the same one-shot
    // pattern already used for user/nameCtrl/priceCtrl above), so a legacy
    // service with categoryId == null starts with no preselection and a
    // linked service preselects only if its categoryId is still eligible.
    final activeCategories =
        ref.read(categoriesProvider).value ?? const <CategoryModel>[];
    final eligibleCategories =
        _resolveProviderServiceCategories(activeCategories, user);
    String? selectedCategoryId = (existing?.categoryId != null &&
            eligibleCategories.any((c) => c.id == existing!.categoryId))
        ? existing!.categoryId
        : null;
    bool categoryError = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx2, setModalState) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEEEEF5),
              borderRadius: BorderRadius.circular(32),
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Center(
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
                      ))),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFEEEEF5),
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
                          child: const Icon(Icons.close_rounded,
                              size: 16, color: Color(0xFF888899)),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
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
                        child: Icon(
                            isEdit
                                ? Icons.edit_rounded
                                : Icons.build_circle_rounded,
                            color: ProfessionalColors.dark,
                            size: 22),
                      ),
                      const SizedBox(width: 14),
                      Text(
                          isEdit
                              ? l.get('edit_service')
                              : l.get('add_new_service'),
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF333355))),
                    ]),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
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
                      child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded,
                                color: Color(0xFF7777AA), size: 18),
                            SizedBox(width: 10),
                            Expanded(
                                child: Text(
                                    'Fill in the service details to display it on your profile.',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF555577),
                                        height: 1.5))),
                          ]),
                    ),
                    const SizedBox(height: 20),
                    Text(l.get('service_name'),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF7777AA))),
                    const SizedBox(height: 8),
                    _ProfNeoInputField(
                        controller: nameCtrl,
                        hint: 'e.g. Electrical Wiring, Painting...',
                        icon: Icons.label_outline_rounded,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Please enter service name'
                            : null),
                    const SizedBox(height: 14),
                    Text(l.get('service_desc'),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF7777AA))),
                    const SizedBox(height: 8),
                    _ProfNeoInputField(
                        controller: descCtrl,
                        hint: 'Describe the service briefly...',
                        icon: Icons.description_outlined,
                        maxLines: 3,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Please enter description'
                            : null),
                    const SizedBox(height: 14),
                    Text(l.get('price_ils'),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF7777AA))),
                    const SizedBox(height: 8),
                    _ProfNeoInputField(
                        controller: priceCtrl,
                        hint: 'e.g. 150',
                        icon: Icons.payments_outlined,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty)
                            return 'Please enter the price';
                          if (double.tryParse(v.trim()) == null)
                            return 'Enter a valid number';
                          return null;
                        }),
                    const SizedBox(height: 14),
                    Text(l.get('categories'),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF7777AA))),
                    const SizedBox(height: 8),
                    if (eligibleCategories.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
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
                        child: Text(l.get('no_specialties_yet'),
                            style: const TextStyle(
                                fontSize: 12.5, color: Color(0xFF555577))),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: eligibleCategories.map((cat) {
                          final selected = selectedCategoryId == cat.id;
                          return GestureDetector(
                            onTap: () => setModalState(() {
                              selectedCategoryId = cat.id;
                              categoryError = false;
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(
                                color: selected
                                    ? ProfessionalColors.mid
                                    : const Color(0xFFEEEEF5),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: selected
                                    ? null
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
                              child: Text(l.get(cat.nameKey),
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: selected
                                          ? Colors.white
                                          : const Color(0xFF333355))),
                            ),
                          );
                        }).toList(),
                      ),
                    if (categoryError) ...[
                      const SizedBox(height: 6),
                      const Text('Please select a category',
                          style: TextStyle(
                              fontSize: 11.5, color: Color(0xFFEF4444))),
                    ],
                    const SizedBox(height: 28),
                    _ProfNeoSubmitButton(
                      label:
                          isEdit ? l.get('save_changes') : l.get('add_service'),
                      onTap: () async {
                        if (!formKey.currentState!.validate()) return;
                        if (eligibleCategories.isEmpty ||
                            selectedCategoryId == null) {
                          setModalState(() => categoryError = true);
                          return;
                        }
                        final newSvc = ServiceModel(
                          id: existing?.id ??
                              'svc_${DateTime.now().millisecondsSinceEpoch}',
                          name: nameCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                          price: double.parse(priceCtrl.text.trim()),
                          categoryId: selectedCategoryId,
                        );
                        List<ServiceModel> updatedList;
                        if (existing != null) {
                          updatedList = user.servicesList
                              .map((s) => s.id == existing.id ? newSvc : s)
                              .toList();
                        } else {
                          updatedList = [...user.servicesList, newSvc];
                        }
                        final nav = Navigator.of(ctx);
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await ref
                              .read(authProvider.notifier)
                              .saveServicesList(
                                  user.copyWith(servicesList: updatedList));
                          if (!mounted) return;
                          nav.pop();
                          messenger.showSnackBar(SnackBar(
                              content: Row(children: [
                                const Icon(Icons.check_circle_rounded,
                                    color: Colors.white),
                                const SizedBox(width: 8),
                                Text(isEdit
                                    ? l.get('service_updated')
                                    : l.get('service_added')),
                              ]),
                              backgroundColor: ProfessionalColors.mid,
                              behavior: SnackBarBehavior.fixed,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12))));
                        } catch (e) {
                          debugPrint(
                              '[ProfessionalProfile] saveService error: $e');
                          if (!mounted) return;
                          messenger.showSnackBar(const SnackBar(
                            content: Row(children: [
                              Icon(Icons.error_rounded, color: Colors.white),
                              SizedBox(width: 8),
                              Text('Failed to save service. Please try again.'),
                            ]),
                            backgroundColor: Color(0xFFEF4444),
                            behavior: SnackBarBehavior.fixed,
                          ));
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _deleteService(UserModel user, String serviceId) async {
    final updated = user.servicesList.where((s) => s.id != serviceId).toList();
    try {
      await ref
          .read(authProvider.notifier)
          .saveServicesList(user.copyWith(servicesList: updated));
    } catch (e) {
      debugPrint('[ProfessionalProfile] deleteService error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Row(children: [
            Icon(Icons.error_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text('Failed to delete service.'),
          ]),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.fixed,
        ));
      }
    }
  }

  // ── Edit Additional Info ────────────────────────────────────────────────────
  void _showEditAdditionalInfo(BuildContext context, UserModel user) {
    // Store optional fields encoded in serviceDescription using pipe-separated format:
    // "bio text | hours: 08:00-18:00 | response: within an hour"
    // Parse existing values
    final desc = user.serviceDescription ?? '';
    String bio = '';
    String hours = '08:00 – 18:00';
    String response = 'Usually within an hour';

    if (desc.contains('hours:')) {
      final parts = desc.split('|');
      for (final p in parts) {
        final t = p.trim();
        if (t.startsWith('hours:'))
          hours = t.replaceFirst('hours:', '').trim();
        else if (t.startsWith('response:'))
          response = t.replaceFirst('response:', '').trim();
        else if (t.isNotEmpty) bio = t;
      }
    } else {
      bio = desc;
    }
    final l = AppLocalizations.of(context);
    final bioCtrl = TextEditingController(text: bio);
    final hoursCtrl = TextEditingController(text: hours);
    final responseCtrl = TextEditingController(text: response);
    final areaCtrl = TextEditingController(text: user.workArea ?? '');
    final langsCtrl = TextEditingController(text: user.languages.join(', '));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFC1E8FF),
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
              const SizedBox(height: 18),
              Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: ProfessionalColors.mid.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.info_outline_rounded,
                      color: ProfessionalColors.mid, size: 20),
                ),
                const SizedBox(width: 12),
                const Text('Additional Information',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: ProfessionalColors.titleText)),
              ]),
              const SizedBox(height: 6),
              const Text(
                  'These fields are optional and can be edited at any time.',
                  style: TextStyle(
                      fontSize: 12, color: ProfessionalColors.hintText)),
              const SizedBox(height: 20),
              _ProfEditField(
                  label: l.get('about_me'), controller: bioCtrl, maxLines: 3),
              _ProfEditField(
                  label: 'Languages (e.g. English, Arabic, Hebrew)',
                  controller: langsCtrl),
              _ProfEditField(
                  label: 'Working Hours (e.g. 08:00 – 18:00)',
                  controller: hoursCtrl),
              _ProfEditField(
                  label: l.get('response_time'), controller: responseCtrl),
              _ProfEditField(
                  label: 'Service Area / Region', controller: areaCtrl),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: ProfessionalColors.light),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(
                            color: Color(0xFF5483B3),
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () async {
                      final nav = Navigator.of(ctx);
                      final messenger = ScaffoldMessenger.of(context);
                      final newDesc = [
                        if (bioCtrl.text.trim().isNotEmpty) bioCtrl.text.trim(),
                        if (hoursCtrl.text.trim().isNotEmpty)
                          'hours: ${hoursCtrl.text.trim()}',
                        if (responseCtrl.text.trim().isNotEmpty)
                          'response: ${responseCtrl.text.trim()}',
                      ].join(' | ');
                      try {
                        await ref
                            .read(authProvider.notifier)
                            .updateProfessionalProfile(
                              user.copyWith(
                                serviceDescription:
                                    newDesc.isEmpty ? null : newDesc,
                                workArea: areaCtrl.text.trim().isEmpty
                                    ? user.workArea
                                    : areaCtrl.text.trim(),
                                languages: langsCtrl.text.trim().isEmpty
                                    ? user.languages
                                    : langsCtrl.text
                                        .split(',')
                                        .map((s) => s.trim())
                                        .where((s) => s.isNotEmpty)
                                        .toList(),
                              ),
                            );
                        if (!mounted) return;
                        nav.pop();
                        messenger.showSnackBar(SnackBar(
                          content: const Row(children: [
                            Icon(Icons.check_circle_rounded,
                                color: Colors.white),
                            SizedBox(width: 8),
                            Text('Additional information saved'),
                          ]),
                          backgroundColor: ProfessionalColors.mid,
                          behavior: SnackBarBehavior.fixed,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ));
                      } catch (e) {
                        debugPrint(
                            '[ProfessionalProfile] updateAdditional error: $e');
                        if (!mounted) return;
                        messenger.showSnackBar(const SnackBar(
                          content: Row(children: [
                            Icon(Icons.error_rounded, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Failed to save. Please try again.'),
                          ]),
                          backgroundColor: Color(0xFFEF4444),
                          behavior: SnackBarBehavior.fixed,
                        ));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF052659),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Save',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // ── Specialties three-dots menu ───────────────────────────────────────────
  void _showSpecialtiesMenu(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded,
                  color: ProfessionalColors.dark),
              title: const Text('Edit Specialties',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.pop(context);
                _editSpecialties(user);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline_rounded,
                  color: Color(0xFF5555AA)),
              title: const Text('Request a New Category',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.pop(context);
                _showRequestCategorySheet(context);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.list_alt_rounded, color: Color(0xFF0EA5E9)),
              title: const Text('My Category Requests',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CategoryRequestsScreen(
                              gradientStart: ProfessionalColors.darkest,
                              gradientEnd: ProfessionalColors.dark,
                              secondaryColor: ProfessionalColors.mid,
                              scaffoldBackgroundColor: Color(0xFFEEEEF5),
                            )));
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Edit specialties ───────────────────────────────────────────────────────
  // Same modal-bottom-sheet layout/interaction as the Contractor profile's
  // _editSpecialties (transparent scrim, rounded top sheet, handle, title +
  // icon, wrap-style selectable chips, full-width Save Changes button) —
  // kept in the Professional green palette instead of Contractor's brown.
  void _editSpecialties(UserModel user) {
    final allCats =
        ref.read(categoriesProvider).value ?? const <CategoryModel>[];
    // Seed the sheet's selection with canonical nameKeys resolved from the
    // live category list only — an invalid/deleted/inactive stored
    // specialty must never end up silently selected (it wouldn't render a
    // chip to un-toggle, yet would still be written back on Save).
    final selected = <String>{
      for (final c in _resolveProviderServiceCategories(allCats, user))
        c.nameKey
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setSt) {
        final l = AppLocalizations.of(ctx);
        return Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: ProfessionalColors.light.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(children: [
              Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [
                        ProfessionalColors.darkest,
                        ProfessionalColors.mid
                      ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.category_outlined,
                      color: Colors.white, size: 20)),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(l.get('edit_specialties'),
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: ProfessionalColors.darkest))),
            ]),
            const SizedBox(height: 16),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children: allCats.map((cat) {
                  final key = cat.nameKey;
                  final isSel = selected.contains(key);
                  return GestureDetector(
                    onTap: () => setSt(
                        () => isSel ? selected.remove(key) : selected.add(key)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel
                            ? ProfessionalColors.dark
                            : ProfessionalColors.light.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: isSel
                                ? ProfessionalColors.dark
                                : ProfessionalColors.light.withOpacity(0.5),
                            width: 1.5),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(cat.icon, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(l.get(key),
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isSel
                                    ? Colors.white
                                    : ProfessionalColors.darkest)),
                      ]),
                    ),
                  );
                }).toList()),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Write canonical nameKeys in categoriesProvider display
                  // order for deterministic Firestore data; anything left
                  // in `selected` that no longer matches a live category
                  // (there shouldn't be any, since selection only ever
                  // came from allCats) is naturally dropped here too.
                  final orderedSelected = allCats
                      .where((c) => selected.contains(c.nameKey))
                      .map((c) => c.nameKey)
                      .toList();
                  ref
                      .read(authProvider.notifier)
                      .saveSpecialties(orderedSelected);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Row(children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.white),
                      const SizedBox(width: 8),
                      Text(l.get('specialties_updated')),
                    ]),
                    backgroundColor: ProfessionalColors.mid,
                    behavior: SnackBarBehavior.fixed,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ));
                },
                icon: const Icon(Icons.save_alt_rounded, size: 18),
                label: Text(l.get('save_changes'),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ProfessionalColors.dark,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ]),
        );
      }),
    );
  }

  // ── Request New Category Sheet ────────────────────────────────────────────
  void _showRequestCategorySheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFEEEEF5),
            borderRadius: BorderRadius.circular(32),
            boxShadow: const [
              BoxShadow(
                  color: Color(0xFFBEBECF),
                  blurRadius: 20,
                  offset: Offset(8, 8)),
              BoxShadow(
                  color: Colors.white, blurRadius: 20, offset: Offset(-8, -8)),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle + X
                  Row(children: [
                    Expanded(
                        child: Center(
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
                    ))),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFEEEEF5),
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
                        child: const Icon(Icons.close_rounded,
                            size: 16, color: Color(0xFF888899)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  // Title
                  Row(children: [
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
                      child: const Icon(Icons.category_rounded,
                          color: Color(0xFF5555AA), size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Text('Request New Category',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF333355))),
                  ]),
                  const SizedBox(height: 18),
                  // Hint card
                  Container(
                    padding: const EdgeInsets.all(14),
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
                    child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: Color(0xFF7777AA), size: 18),
                          SizedBox(width: 10),
                          Expanded(
                              child: Text(
                            "Can\'t find the category you need? Send us a request and the admin will review it.",
                            style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF555577),
                                height: 1.5),
                          )),
                        ]),
                  ),
                  const SizedBox(height: 20),
                  const Text('Category Name',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7777AA))),
                  const SizedBox(height: 8),
                  _ProfNeoInputField(
                    controller: nameCtrl,
                    hint: 'e.g. Interior Design, HVAC Technician...',
                    icon: Icons.category_outlined,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Please enter a category name'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  const Text('Description (Optional)',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7777AA))),
                  const SizedBox(height: 8),
                  _ProfNeoInputField(
                    controller: descCtrl,
                    hint: 'Describe what this category covers...',
                    icon: Icons.description_outlined,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 28),
                  _ProfNeoSubmitButton(
                    label: 'Send Request',
                    onTap: () async {
                      if (!formKey.currentState!.validate()) return;
                      final user = ref.read(authProvider);
                      final name = nameCtrl.text.trim();
                      final desc = descCtrl.text.trim();
                      Navigator.pop(ctx);
                      try {
                        final req = CategoryRequestModel(
                          id: '',
                          requesterId: user?.id ?? '',
                          requesterName: user?.fullName ?? '',
                          requesterRole: 'professional',
                          requestedName: name,
                          requestedDescription: desc,
                          createdAt: DateTime.now(),
                        );
                        final reqRef = await FirebaseFirestore.instance
                            .collection('category_requests')
                            .add(req.toMap());
                        createCategoryRequestNotification(
                          targetRole: 'admin',
                          title: 'New Category Request',
                          message: 'A user requested a new category.',
                          categoryRequestId: reqRef.id,
                        );
                      } catch (_) {}
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Row(children: [
                            const Icon(Icons.check_circle_rounded,
                                color: Colors.white),
                            const SizedBox(width: 8),
                            Text('Request for "$name" sent successfully!'),
                          ]),
                          backgroundColor: ProfessionalColors.mid,
                          behavior: SnackBarBehavior.fixed,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ));
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Complaint Sheet (matches Customer flow) ────────────────────────────────
  void _showComplaintSheet(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfessionalComplaintsPage()),
    );
  }
}

// ─── Professional Neo Helper Widgets (Neumorphic - Green Palette) ────────────

// ── Section three-dots menu trigger ───────────────────────────────────────────
class _ProfNeoDotsBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _ProfNeoDotsBtn({required this.onTap});
  @override
  State<_ProfNeoDotsBtn> createState() => _ProfNeoDotsBtnState();
}

class _ProfNeoDotsBtnState extends State<_ProfNeoDotsBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _p = false;
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
          setState(() => _p = true);
          _ctrl.forward();
        },
        onTapUp: (_) {
          setState(() => _p = false);
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () {
          setState(() => _p = false);
          _ctrl.reverse();
        },
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.07 * _ctrl.value, child: child),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _pNeoBase,
              borderRadius: BorderRadius.circular(11),
              boxShadow: _p ? _pNeoInset : _pNeoBtnRaised,
            ),
            child: const Icon(Icons.more_vert_rounded,
                size: 18, color: ProfessionalColors.dark),
          ),
        ),
      );
}

const _pNeoBase = Color(0xFFEEEEF5);
const List<BoxShadow> _pNeoRaised = [
  BoxShadow(color: Color(0xFFBEBECF), blurRadius: 0, offset: Offset(0, 4)),
  BoxShadow(color: Color(0xFFBEBECF), blurRadius: 14, offset: Offset(6, 6)),
  BoxShadow(color: Colors.white, blurRadius: 14, offset: Offset(-6, -6)),
];
const List<BoxShadow> _pNeoInset = [
  BoxShadow(
      color: Color(0xFFBEBECF),
      blurRadius: 6,
      offset: Offset(3, 3),
      spreadRadius: -1),
  BoxShadow(
      color: Colors.white,
      blurRadius: 6,
      offset: Offset(-3, -3),
      spreadRadius: -1),
];
const List<BoxShadow> _pNeoBtnRaised = [
  BoxShadow(color: Color(0xFFBEBECF), blurRadius: 0, offset: Offset(0, 3)),
  BoxShadow(color: Color(0xFFBEBECF), blurRadius: 9, offset: Offset(4, 4)),
  BoxShadow(color: Colors.white, blurRadius: 9, offset: Offset(-4, -4)),
];

// ── Profile Logout Button ─────────────────────────────────────────────────────
// Replaces the former three-dots menu in the Professional Profile header.
// That menu's only remaining entry was Logout (My Complaints had already
// moved to the Quick Actions section), so the menu step is gone and the
// action is now permanently visible. Keeps the exact container styling the
// three-dots trigger used — 42×42, ProfessionalColors.darkest, radius 14,
// same shadows/border and the same press-scale animation — so the header's
// teal design language is unchanged; only the glyph and the tap target's
// destination differ.
class _ProfProfileLogoutBtn extends StatefulWidget {
  final VoidCallback onLogout;
  const _ProfProfileLogoutBtn({required this.onLogout});
  @override
  State<_ProfProfileLogoutBtn> createState() => _ProfProfileLogoutBtnState();
}

class _ProfProfileLogoutBtnState extends State<_ProfProfileLogoutBtn>
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
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Logout',
        child: GestureDetector(
          onTapDown: (_) {
            HapticFeedback.lightImpact();
            _ctrl.forward();
          },
          onTapUp: (_) {
            _ctrl.reverse();
            widget.onLogout();
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
                color: ProfessionalColors.darkest,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(3, 3)),
                  BoxShadow(
                      color: Colors.white.withOpacity(0.08),
                      blurRadius: 6,
                      offset: const Offset(-2, -2)),
                ],
                border:
                    Border.all(color: Colors.white.withOpacity(0.15), width: 1),
              ),
              child: const Icon(Icons.logout_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ),
      );
}

// ── Neo Complaint Button (kept for compatibility) ─────────────────────────────

class _ProfNeoComplaintBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _ProfNeoComplaintBtn({required this.onTap});
  @override
  State<_ProfNeoComplaintBtn> createState() => _ProfNeoComplaintBtnState();
}

class _ProfNeoComplaintBtnState extends State<_ProfNeoComplaintBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _p = false;
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
          setState(() => _p = true);
          _ctrl.forward();
        },
        onTapUp: (_) {
          setState(() => _p = false);
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () {
          setState(() => _p = false);
          _ctrl.reverse();
        },
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.07 * _ctrl.value, child: child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: _p
                  ? Colors.white.withOpacity(0.25)
                  : Colors.white.withOpacity(0.13),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.22)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(3, 3))
              ],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_p ? Icons.flag_rounded : Icons.flag_outlined,
                  color: Colors.white, size: 13),
              const SizedBox(width: 6),
              const Text('Complaint',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}

// ── Hero stat ─────────────────────────────────────────────────────────────────
class _ProfNeoHeroStat extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color color;
  final bool isLast;
  const _ProfNeoHeroStat(
      {required this.icon,
      required this.value,
      required this.label,
      required this.color,
      this.isLast = false});
  @override
  Widget build(BuildContext context) => Expanded(
          child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
            border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.09)),
          right: isLast
              ? BorderSide.none
              : BorderSide(color: Colors.white.withOpacity(0.07)),
        )),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          Text(label,
              style:
                  TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 9),
              textAlign: TextAlign.center),
        ]),
      ));
}

// ── Mini stat ─────────────────────────────────────────────────────────────────
class _ProfNeoMiniStat extends StatelessWidget {
  final String value, label;
  final Color color;
  final int maxLines;
  const _ProfNeoMiniStat(
      {required this.value,
      required this.label,
      required this.color,
      this.maxLines = 1});
  @override
  Widget build(BuildContext context) {
    // Single-line stats (percentages, counts) keep the original 22px size;
    // multi-line stats (e.g. a saved response-time sentence) shrink just
    // enough to fit 2 lines without truncating the value's meaning.
    final fontSize = maxLines <= 1
        ? 22.0
        : value.length > 26
            ? 12.0
            : value.length > 18
                ? 14.0
                : 18.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
          color: _pNeoBase,
          borderRadius: BorderRadius.circular(18),
          boxShadow: _pNeoRaised),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                maxLines: maxLines,
                overflow: TextOverflow.visible,
                softWrap: true,
                style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w900,
                    color: color,
                    height: 1.15)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: ProfessionalColors.mid)),
          ]),
    );
  }
}

// ── Section head ──────────────────────────────────────────────────────────────
class _ProfNeoSectionHead extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget? action;
  const _ProfNeoSectionHead(
      {required this.icon,
      required this.iconColor,
      required this.title,
      this.action});
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: _pNeoBase,
                borderRadius: BorderRadius.circular(11),
                boxShadow: _pNeoBtnRaised),
            child: Icon(icon, color: iconColor, size: 17)),
        const SizedBox(width: 10),
        Expanded(
            child: Text(title,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: ProfessionalColors.darkest,
                    letterSpacing: -0.2))),
        if (action != null) action!,
      ]);
}

// ── Section pill ──────────────────────────────────────────────────────────────
class _ProfNeoSectionPill extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ProfNeoSectionPill(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});
  @override
  State<_ProfNeoSectionPill> createState() => _ProfNeoSectionPillState();
}

class _ProfNeoSectionPillState extends State<_ProfNeoSectionPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _p = false;
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
          setState(() => _p = true);
          _ctrl.forward();
        },
        onTapUp: (_) {
          setState(() => _p = false);
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () {
          setState(() => _p = false);
          _ctrl.reverse();
        },
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.05 * _ctrl.value, child: child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
            decoration: BoxDecoration(
                color: _pNeoBase,
                borderRadius: BorderRadius.circular(20),
                boxShadow: _p ? _pNeoInset : _pNeoBtnRaised),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(widget.icon, size: 12, color: widget.color),
              const SizedBox(width: 5),
              Text(widget.label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: widget.color)),
            ]),
          ),
        ),
      );
}

// ── Neo icon button ───────────────────────────────────────────────────────────
class _ProfNeoIconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _ProfNeoIconBtn({required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
            color: _pNeoBase,
            borderRadius: BorderRadius.circular(10),
            boxShadow: _pNeoBtnRaised),
        child: Icon(icon, color: color, size: 18),
      );
}

// ── Neo Card ──────────────────────────────────────────────────────────────────
class _ProfNeoCard extends StatelessWidget {
  final List<Widget> children;
  const _ProfNeoCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: _pNeoBase,
            borderRadius: BorderRadius.circular(22),
            boxShadow: _pNeoRaised),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
}

// ── Info row ──────────────────────────────────────────────────────────────────
class _ProfNeoInfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label, value;
  final bool isLast;
  const _ProfNeoInfoRow(
      {required this.icon,
      required this.iconColor,
      required this.label,
      required this.value,
      this.isLast = false});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
            border: isLast
                ? null
                : const Border(bottom: BorderSide(color: Color(0x0A000000)))),
        child: Row(children: [
          Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                  color: _pNeoBase,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: _pNeoBtnRaised),
              child: Icon(icon, color: iconColor, size: 15)),
          const SizedBox(width: 11),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: ProfessionalColors.mid))),
          Flexible(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: ProfessionalColors.darkest),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
        ]),
      );
}

// ── Chip with emoji ───────────────────────────────────────────────────────────
class _ProfNeoChip extends StatefulWidget {
  final String emoji, label;
  final Color color;
  const _ProfNeoChip(
      {required this.emoji, required this.label, required this.color});
  @override
  State<_ProfNeoChip> createState() => _ProfNeoChipState();
}

class _ProfNeoChipState extends State<_ProfNeoChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _p = false;
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
          HapticFeedback.selectionClick();
          setState(() => _p = true);
          _ctrl.forward();
        },
        onTapUp: (_) {
          setState(() => _p = false);
          _ctrl.reverse();
        },
        onTapCancel: () {
          setState(() => _p = false);
          _ctrl.reverse();
        },
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.06 * _ctrl.value, child: child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
                color: _pNeoBase,
                borderRadius: BorderRadius.circular(20),
                boxShadow: _p ? _pNeoInset : _pNeoBtnRaised),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(widget.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(widget.label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: widget.color)),
            ]),
          ),
        ),
      );
}

// ── Service row ───────────────────────────────────────────────────────────────
class _ProfNeoServiceRow extends StatelessWidget {
  final ServiceModel service;
  final CategoryModel? category;
  final VoidCallback onEdit, onDelete;
  const _ProfNeoServiceRow(
      {required this.service,
      required this.category,
      required this.onEdit,
      required this.onDelete});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0x0A000000)))),
        child: Row(children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  color: ProfessionalColors.mid, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(service.name,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ProfessionalColors.darkest)),
                _ServiceCategoryBadge(
                    category: category, color: ProfessionalColors.mid),
                if (service.description.isNotEmpty)
                  Text(service.description,
                      style: const TextStyle(
                          fontSize: 11, color: ProfessionalColors.mid),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ])),
          Text('₪${service.price.toStringAsFixed(0)}',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: ProfessionalColors.dark)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (_) => Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                          color: _pNeoBase,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0xFFBEBECF),
                                blurRadius: 20,
                                offset: Offset(8, 8)),
                            BoxShadow(
                                color: Colors.white,
                                blurRadius: 20,
                                offset: Offset(-8, -8))
                          ]),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const SizedBox(height: 14),
                        Center(
                            child: Container(
                                width: 40,
                                height: 5,
                                decoration: BoxDecoration(
                                    color: const Color(0xFFCCCCDD),
                                    borderRadius: BorderRadius.circular(3)))),
                        const SizedBox(height: 16),
                        ListTile(
                            leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                    color: _pNeoBase,
                                    borderRadius: BorderRadius.circular(11),
                                    boxShadow: _pNeoBtnRaised),
                                child: Icon(Icons.edit_rounded,
                                    color: ProfessionalColors.dark, size: 18)),
                            title: Text('Edit',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: ProfessionalColors.darkest)),
                            onTap: () {
                              Navigator.pop(context);
                              onEdit();
                            }),
                        ListTile(
                            leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                    color: _pNeoBase,
                                    borderRadius: BorderRadius.circular(11),
                                    boxShadow: _pNeoBtnRaised),
                                child: const Icon(Icons.delete_outline_rounded,
                                    color: Color(0xFFA32D2D), size: 18)),
                            title: const Text('Delete',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFA32D2D))),
                            onTap: () {
                              Navigator.pop(context);
                              onDelete();
                            }),
                        const SizedBox(height: 16),
                      ]),
                    )),
            child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                    color: _pNeoBase,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: _pNeoBtnRaised),
                child: Icon(Icons.more_vert_rounded,
                    size: 15, color: ProfessionalColors.mid.withOpacity(0.7))),
          ),
        ]),
      );
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

// ── Rating bar ────────────────────────────────────────────────────────────────
// Reads the criterion's own maxRating (Firestore-configurable, no longer a
// hardcoded 5) so bars stay proportionally correct and never overflow.
double? _profCriterionScore(ReviewModel r, ReviewCriteriaModel c) {
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

double _profAvgForCriterion(List<ReviewModel> reviews, ReviewCriteriaModel c) {
  final scores = reviews
      .map((r) => _profCriterionScore(r, c))
      .whereType<double>()
      .toList();
  if (scores.isEmpty) return 0.0;
  return scores.reduce((a, b) => a + b) / scores.length;
}

class _ProfNeoRatingBar extends StatelessWidget {
  final String label;
  final double value;
  final int maxRating;
  const _ProfNeoRatingBar(
      {required this.label, required this.value, this.maxRating = 5});
  @override
  Widget build(BuildContext context) {
    final safeMax = maxRating > 0 ? maxRating : 5;
    final progress = (value / safeMax).clamp(0.0, 1.0);
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      SizedBox(
          width: 92,
          child: Text(label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 10, color: ProfessionalColors.mid))),
      const SizedBox(width: 6),
      Expanded(
          child: Container(
              height: 6,
              decoration: BoxDecoration(
                  color: _pNeoBase,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0xFFBEBECF),
                        blurRadius: 4,
                        offset: Offset(2, 2),
                        spreadRadius: -1),
                    BoxShadow(
                        color: Colors.white,
                        blurRadius: 4,
                        offset: Offset(-2, -2),
                        spreadRadius: -1)
                  ]),
              child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(
                      decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      ProfessionalColors.light,
                      ProfessionalColors.mid
                    ]),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                          color: ProfessionalColors.mid.withOpacity(0.45),
                          blurRadius: 6,
                          offset: const Offset(0, 2))
                    ],
                  ))))),
      const SizedBox(width: 8),
      SizedBox(
          width: 30,
          child: Text(value.toStringAsFixed(1),
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: ProfessionalColors.darkest),
              textAlign: TextAlign.right)),
    ]);
  }
}

// ── Review card ───────────────────────────────────────────────────────────────
class _ProfNeoReviewCard extends ConsumerWidget {
  final ReviewModel review;
  final bool isLast;
  const _ProfNeoReviewCard({required this.review, this.isLast = false});

  void _showReviewComplaint(BuildContext context, WidgetRef ref) {
    final subjectCtrl =
        TextEditingController(text: 'Unfair Review – ${review.customerName}');
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFEEEEF5),
            borderRadius: BorderRadius.circular(32),
            boxShadow: const [
              BoxShadow(
                  color: Color(0xFFBEBECF),
                  blurRadius: 20,
                  offset: Offset(8, 8)),
              BoxShadow(
                  color: Colors.white, blurRadius: 20, offset: Offset(-8, -8)),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Form(
            key: formKey,
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle + X
                  Row(children: [
                    Expanded(
                        child: Center(
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
                    ))),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFEEEEF5),
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
                        child: const Icon(Icons.close_rounded,
                            size: 16, color: Color(0xFF888899)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  // Title
                  Row(children: [
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
                      child: const Icon(Icons.flag_rounded,
                          color: Color(0xFFEF4444), size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Text('Report Review',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF333355))),
                  ]),
                  const SizedBox(height: 14),
                  // Review preview card
                  Container(
                    padding: const EdgeInsets.all(12),
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
                    child: Row(children: [
                      const Icon(Icons.star_rounded,
                          color: Color(0xFFFFCA28), size: 15),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(
                        '${review.customerName}  •  ${review.comment.isNotEmpty ? (review.comment.length > 40 ? "${review.comment.substring(0, 40)}..." : review.comment) : "No comment"}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF555577)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  const Text('Subject',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7777AA))),
                  const SizedBox(height: 8),
                  _ProfNeoInputField(
                      controller: subjectCtrl,
                      hint: 'Reason for reporting...',
                      icon: Icons.flag_outlined,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter a subject'
                          : null),
                  const SizedBox(height: 14),
                  const Text('Details (Optional)',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7777AA))),
                  const SizedBox(height: 8),
                  _ProfNeoInputField(
                      controller: descCtrl,
                      hint: 'Describe why this review is unfair...',
                      icon: Icons.description_outlined,
                      maxLines: 3),
                  const SizedBox(height: 24),
                  _ProfNeoSubmitButton(
                    label: 'Send Report',
                    onTap: () async {
                      if (!formKey.currentState!.validate()) return;
                      Navigator.pop(ctx);
                      final currentUser = ref.read(authProvider);
                      if (currentUser == null) return;
                      final title = subjectCtrl.text.trim();
                      final description = descCtrl.text.trim();
                      try {
                        await addComplaintInFirestore(ComplaintModel(
                          id: '',
                          userId: currentUser.id,
                          userName: currentUser.fullName,
                          complainantRole: 'professional',
                          type: ComplaintType.reviewReport,
                          targetId: review.id,
                          targetName: review.customerName,
                          targetUserId: review.customerId,
                          targetUserName: review.customerName,
                          targetUserRole: 'customer',
                          reason: title,
                          description: description,
                          relatedReviewId: review.id,
                          relatedProviderId: currentUser.id,
                          relatedProviderName: currentUser.fullName,
                          sourceContext: 'review_report',
                          createdAt: DateTime.now(),
                        ));
                        await reportReviewInFirestore(review.id, title);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: const Row(children: [
                              Icon(Icons.check_circle_rounded,
                                  color: Colors.white),
                              SizedBox(width: 8),
                              Text('Report submitted successfully'),
                            ]),
                            backgroundColor: ProfessionalColors.mid,
                            behavior: SnackBarBehavior.fixed,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ));
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Failed to submit report: $e')));
                        }
                      }
                    },
                  ),
                ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avg = (review.speedRating +
            review.qualityRating +
            review.communicationRating) /
        3;
    final initials = review.customerName
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0] : '')
        .join();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: Color(0x0A000000)))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Avatar
          Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: _pNeoBase,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _pNeoBtnRaised),
              child: Center(
                  child: Text(initials,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: ProfessionalColors.dark)))),
          const SizedBox(width: 9),
          // Name + stars
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(review.customerName,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: ProfessionalColors.darkest)),
                const SizedBox(height: 2),
                Row(children: [
                  ...List.generate(
                      5,
                      (i) => Icon(
                          i < avg.round()
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: const Color(0xFFFFCA28),
                          size: 11)),
                  const SizedBox(width: 5),
                  Text('${review.createdAt.day}/${review.createdAt.month}',
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFFBBAA99))),
                ]),
              ])),
          const SizedBox(width: 8),
          // ── Complaint button (neo neumorphic icon) ─────────────────────
          _ProfReviewComplaintBtn(
              onTap: () => _showReviewComplaint(context, ref)),
        ]),
        if (review.comment.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(review.comment,
              style: const TextStyle(
                  fontSize: 11, color: ProfessionalColors.mid, height: 1.5)),
          if (review.comment.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            ProviderContentTranslateAction(
              contentType: TranslationContentType.reviewComment,
              sourceDocId: review.id,
              currentSourceText: review.comment,
              entryLabelKey: 'translate_review',
            ),
          ],
        ],
      ]),
    );
  }
}

// ── Review Complaint Button — Neo neumorphic flag icon ─────────────────────────
class _ProfReviewComplaintBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _ProfReviewComplaintBtn({required this.onTap});
  @override
  State<_ProfReviewComplaintBtn> createState() =>
      _ProfReviewComplaintBtnState();
}

class _ProfReviewComplaintBtnState extends State<_ProfReviewComplaintBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _p = false;
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
          setState(() => _p = true);
          _ctrl.forward();
        },
        onTapUp: (_) {
          setState(() => _p = false);
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () {
          setState(() => _p = false);
          _ctrl.reverse();
        },
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.10 * _ctrl.value, child: child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _pNeoBase,
              borderRadius: BorderRadius.circular(11),
              boxShadow: _p
                  ? [
                      const BoxShadow(
                          color: Color(0xFFBEBECF),
                          blurRadius: 4,
                          offset: Offset(2, 2),
                          spreadRadius: -1),
                      const BoxShadow(
                          color: Colors.white,
                          blurRadius: 4,
                          offset: Offset(-2, -2),
                          spreadRadius: -1),
                    ]
                  : _pNeoBtnRaised,
            ),
            child: Icon(
              _p ? Icons.flag_rounded : Icons.flag_outlined,
              color: _p ? const Color(0xFFEF4444) : const Color(0xFFBBAA99),
              size: 16,
            ),
          ),
        ),
      );
}

// ── Action row ────────────────────────────────────────────────────────────────
class _ProfNeoActionRow extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color? labelColor;
  final bool isLast;
  final VoidCallback onTap;
  const _ProfNeoActionRow(
      {required this.icon,
      required this.iconColor,
      required this.label,
      this.labelColor,
      this.isLast = false,
      required this.onTap});
  @override
  State<_ProfNeoActionRow> createState() => _ProfNeoActionRowState();
}

class _ProfNeoActionRowState extends State<_ProfNeoActionRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _p = false;
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
          setState(() => _p = true);
          _ctrl.forward();
        },
        onTapUp: (_) {
          setState(() => _p = false);
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () {
          setState(() => _p = false);
          _ctrl.reverse();
        },
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.02 * _ctrl.value, child: child),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
                border: widget.isLast
                    ? null
                    : const Border(
                        bottom: BorderSide(color: Color(0x0A000000)))),
            child: Row(children: [
              AnimatedContainer(
                  duration: const Duration(milliseconds: 80),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: _pNeoBase,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: _p ? _pNeoInset : _pNeoBtnRaised),
                  child: Icon(widget.icon, color: widget.iconColor, size: 18)),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(widget.label,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: widget.labelColor ??
                              ProfessionalColors.darkest))),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 13, color: Color(0xFFBBAA99)),
            ]),
          ),
        ),
      );
}

// ─── New Profile Helper Widgets ──────────────────────────────────────────────

// ── Header Stat Item (4-column grid in header) ───────────────────────────────
class _HeaderStatItem extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color iconColor;
  const _HeaderStatItem(
      {required this.value,
      required this.label,
      required this.icon,
      required this.iconColor});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(height: 5),
          Text(value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              )),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center),
        ]),
      );
}

class _HeaderStatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 36,
        color: Colors.white.withOpacity(0.15),
      );
}

// ── Mini stat card (completion rate / avg response) ──────────────────────────
class _MiniStatCard extends StatelessWidget {
  final bool isDark;
  final String value, label;
  final Color valueColor;
  const _MiniStatCard(
      {required this.isDark,
      required this.value,
      required this.label,
      required this.valueColor});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0D1B12) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: isDark
                  ? ProfessionalColors.dark.withOpacity(0.25)
                  : ProfessionalColors.lightest),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF051F20).withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: valueColor,
                letterSpacing: -1,
              )),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                fontSize: 12,
                color:
                    isDark ? Colors.white54 : ProfessionalColors.secondaryText,
                fontWeight: FontWeight.w500,
              )),
        ]),
      );
}

// ── Section header ────────────────────────────────────────────────────────────
class _ProfileSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isDark;
  final Widget? action;
  final Color? iconColor;
  const _ProfileSectionHeader(
      {required this.title,
      required this.icon,
      required this.isDark,
      this.action,
      this.iconColor});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: (iconColor ?? ProfessionalColors.mid).withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child:
              Icon(icon, color: iconColor ?? ProfessionalColors.mid, size: 17),
        ),
        const SizedBox(width: 10),
        Expanded(
            child: Text(title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF021024),
                  letterSpacing: -0.3,
                ))),
        if (action != null) action!,
      ]);
}

// ── Edit chip button ──────────────────────────────────────────────────────────
class _EditChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final IconData icon;
  const _EditChip(
      {required this.label,
      required this.onTap,
      this.icon = Icons.edit_rounded});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: ProfessionalColors.mid.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ProfessionalColors.mid.withOpacity(0.25)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: ProfessionalColors.mid),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ProfessionalColors.mid)),
          ]),
        ),
      );
}

// ── Animated profile card (press feedback) ───────────────────────────────────
class _AnimatedProfileCard extends StatefulWidget {
  final List<Widget> children;
  final bool isDark;
  const _AnimatedProfileCard({required this.children, required this.isDark});
  @override
  State<_AnimatedProfileCard> createState() => _AnimatedProfileCardState();
}

class _AnimatedProfileCardState extends State<_AnimatedProfileCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 80));
    _scale = Tween(begin: 1.0, end: 0.985)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: Container(
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF0D1B12) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: widget.isDark
                    ? ProfessionalColors.dark.withOpacity(0.25)
                    : ProfessionalColors.lightest),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF051F20).withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Column(children: widget.children),
        ),
      );
}

// ── Profile row (label + value) ───────────────────────────────────────────────
class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final bool isDark;
  const _ProfileRow(
      {required this.icon,
      required this.label,
      required this.value,
      required this.isDark});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isDark
                  ? ProfessionalColors.dark.withOpacity(0.3)
                  : ProfessionalColors.lightest.withOpacity(0.8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                color:
                    isDark ? ProfessionalColors.light : ProfessionalColors.mid,
                size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? ProfessionalColors.light
                          : ProfessionalColors.secondaryText,
                      fontWeight: FontWeight.w500,
                    )),
                const SizedBox(height: 2),
                Text(value.isEmpty ? '—' : value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: value.isEmpty
                          ? (isDark
                              ? ProfessionalColors.midDark
                              : ProfessionalColors.hintText)
                          : (isDark
                              ? Colors.white
                              : ProfessionalColors.titleText),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ])),
        ]),
      );
}

// ── Row divider ───────────────────────────────────────────────────────────────
class _ProfileRowDivider extends StatelessWidget {
  final bool isDark;
  const _ProfileRowDivider({required this.isDark});
  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        indent: 62,
        endIndent: 16,
        color: isDark
            ? ProfessionalColors.dark.withOpacity(0.25)
            : ProfessionalColors.lightest,
      );
}

// ── Specialty chip ────────────────────────────────────────────────────────────
class _SpecialtyChip extends StatelessWidget {
  final String icon, label;
  final bool isDark;
  const _SpecialtyChip(
      {required this.icon, required this.label, required this.isDark});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: ProfessionalColors.mid.withOpacity(isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ProfessionalColors.mid.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: ProfessionalColors.mid)),
        ]),
      );
}

// ── Service row (inside card, no separate container) ──────────────────────────
class _ServiceRow extends StatefulWidget {
  final ServiceModel service;
  final bool isDark;
  final VoidCallback onEdit, onDelete;
  const _ServiceRow(
      {required this.service,
      required this.isDark,
      required this.onEdit,
      required this.onDelete});
  @override
  State<_ServiceRow> createState() => _ServiceRowState();
}

class _ServiceRowState extends State<_ServiceRow> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          HapticFeedback.selectionClick();
          setState(() => _pressed = true);
        },
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          color: _pressed
              ? ProfessionalColors.mid.withOpacity(0.05)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF1B7A4A).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Center(
                  child:
                      Icon(Icons.circle, color: Color(0xFF1B7A4A), size: 10)),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Text(widget.service.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: widget.isDark
                          ? Colors.white
                          : const Color(0xFF021024),
                    ))),
            Text('₪${widget.service.price.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ProfessionalColors.mid)),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: widget.onEdit,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: ProfessionalColors.mid.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.edit_outlined,
                    size: 15, color: ProfessionalColors.mid),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: widget.onDelete,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: ProfessionalColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.delete_outline,
                    size: 15, color: ProfessionalColors.error),
              ),
            ),
          ]),
        ),
      );
}

// ── Quick action tile (with press animation) ──────────────────────────────────
class _QuickActionTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;
  final Color? iconColor, labelColor;
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
    this.iconColor,
    this.labelColor,
  });
  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          HapticFeedback.selectionClick();
          setState(() => _pressed = true);
        },
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          color: _pressed
              ? (widget.iconColor ?? ProfessionalColors.mid).withOpacity(0.06)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (widget.iconColor ?? ProfessionalColors.mid)
                    .withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(widget.icon,
                  color: widget.iconColor ?? ProfessionalColors.mid, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Text(widget.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: widget.labelColor ??
                          (widget.isDark
                              ? Colors.white
                              : const Color(0xFF021024)),
                    ))),
            Icon(Icons.chevron_right_rounded,
                color: (widget.isDark ? Colors.white : const Color(0xFF021024))
                    .withOpacity(0.3),
                size: 20),
          ]),
        ),
      );
}

// ── Profile Complaint Button (3D neo animated) ────────────────────────────────
class _ProfProfileComplaintButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _ProfProfileComplaintButton({required this.label, required this.onTap});
  @override
  State<_ProfProfileComplaintButton> createState() =>
      _ProfProfileComplaintButtonState();
}

class _ProfProfileComplaintButtonState
    extends State<_ProfProfileComplaintButton>
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
              Transform.scale(scale: 1.0 - 0.07 * _ctrl.value, child: child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _pressed
                  ? const Color(0xFFEF4444).withOpacity(0.35)
                  : Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                  color: _pressed
                      ? const Color(0xFFEF4444).withOpacity(0.7)
                      : Colors.white.withOpacity(0.35),
                  width: 1.2),
              boxShadow: _pressed
                  ? [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 4,
                          offset: const Offset(2, 2))
                    ]
                  : [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.38),
                          blurRadius: 0,
                          offset: const Offset(0, 4)),
                      BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 6)),
                      BoxShadow(
                          color: Colors.white.withOpacity(0.10),
                          blurRadius: 4,
                          offset: const Offset(0, -2))
                    ],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.flag_rounded, color: Colors.white, size: 14),
              const SizedBox(width: 6),
              Text(widget.label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2)),
            ]),
          ),
        ),
      );
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;
  const _StatPill(
      {required this.icon, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              )),
        ]),
      );
}

class _ProfSectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool isDark;
  final Widget? action;
  final String? badge;
  const _ProfSectionTitle({
    required this.title,
    required this.icon,
    required this.color,
    required this.isDark,
    this.action,
    this.badge,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(children: [
              Text(title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF021024),
                    letterSpacing: -0.3,
                  )),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(badge!,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: color)),
                ),
              ],
            ]),
          ),
          if (action != null) action!,
        ],
      );
}

class _ProfInfoCard extends StatelessWidget {
  final List<Widget> children;
  final bool isDark;
  final Color? accent;
  const _ProfInfoCard(
      {required this.children, required this.isDark, this.accent});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0D1B2E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? (accent ?? ProfessionalColors.dark).withOpacity(0.3)
                : (accent?.withOpacity(0.2) ?? ProfessionalColors.lightest),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: ProfessionalColors.darkest.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(children: children),
      );
}

class _ProfInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final bool isOptional;
  final bool multiline;
  const _ProfInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    this.isOptional = false,
    this.multiline = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          crossAxisAlignment:
              multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isDark
                    ? ProfessionalColors.dark.withOpacity(0.35)
                    : ProfessionalColors.lightest.withOpacity(0.8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  color: isDark
                      ? ProfessionalColors.light
                      : ProfessionalColors.mid,
                  size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(label,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? ProfessionalColors.light
                                : ProfessionalColors.secondaryText,
                            fontWeight: FontWeight.w500,
                          )),
                      if (isOptional) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5483B3).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Optional',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFF5483B3),
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Text(
                      value.isEmpty ? '—' : value,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: value.isEmpty || value == '—'
                            ? (isDark
                                ? ProfessionalColors.midDark
                                : ProfessionalColors.hintText)
                            : (isDark
                                ? Colors.white
                                : ProfessionalColors.titleText),
                        height: multiline ? 1.5 : 1.0,
                      ),
                      maxLines: multiline ? 4 : 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ]),
            ),
          ],
        ),
      );
}

class _ProfDivider extends StatelessWidget {
  final bool isDark;
  const _ProfDivider({required this.isDark});
  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        indent: 62,
        endIndent: 16,
        color: isDark
            ? ProfessionalColors.dark.withOpacity(0.3)
            : ProfessionalColors.lightest,
      );
}

class _ProfRatingBar extends StatelessWidget {
  final String label;
  final double value;
  final bool isDark;
  const _ProfRatingBar(
      {required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(
          width: 52,
          child: Text(label,
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? const Color(0xFF7DA0CA)
                    : ProfessionalColors.textSecondary,
              )),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value / 5,
              backgroundColor: isDark
                  ? const Color(0xFF052659).withOpacity(0.3)
                  : const Color(0xFFC1E8FF),
              valueColor: const AlwaysStoppedAnimation(Color(0xFFFFB800)),
              minHeight: 7,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(value.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFFFFB800),
            )),
      ]);
}

class _ProfReviewCard extends StatelessWidget {
  final ReviewModel review;
  final bool isDark;
  const _ProfReviewCard({required this.review, required this.isDark});

  void _showReportDialog(BuildContext context) {
    String? selectedReason;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
              const SizedBox(height: 16),
              Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.flag_rounded,
                      color: Colors.red.shade400, size: 20),
                ),
                const SizedBox(width: 10),
                const Text('Report Review',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF021024))),
              ]),
              const SizedBox(height: 16),
              ...[
                'Inappropriate review',
                'Fake review',
                'Offensive language',
                'Other',
              ].map((reason) => RadioListTile<String>(
                    title: Text(reason, style: const TextStyle(fontSize: 14)),
                    value: reason,
                    groupValue: selectedReason,
                    activeColor: ProfessionalColors.mid,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setState(() => selectedReason = v),
                  )),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: ProfessionalColors.light),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(
                            color: ProfessionalColors.mid,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: selectedReason == null
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: const Row(children: [
                                Icon(Icons.check_circle_rounded,
                                    color: Colors.white),
                                SizedBox(width: 8),
                                Text('Review reported successfully.'),
                              ]),
                              backgroundColor: ProfessionalColors.mid,
                              behavior: SnackBarBehavior.fixed,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ));
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade400,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text('Submit Report',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0B1A12) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? ProfessionalColors.dark.withOpacity(0.3)
                : ProfessionalColors.lightest,
          ),
          boxShadow: [
            BoxShadow(
              color: ProfessionalColors.darkest.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [ProfessionalColors.dark, ProfessionalColors.mid],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                  child: Text(
                review.customerName.isNotEmpty ? review.customerName[0] : '?',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  fontSize: 14,
                ),
              )),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(review.customerName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF021024),
                      )),
                  Text(
                    '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                    style:
                        const TextStyle(fontSize: 11, color: Color(0xFF7DA0CA)),
                  ),
                ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.star_rounded,
                    color: Color(0xFFFFB800), size: 13),
                const SizedBox(width: 3),
                Text(review.overallRating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF856400),
                    )),
              ]),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => _showReportDialog(context),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.flag_outlined,
                    size: 16, color: Colors.red.shade400),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? ProfessionalColors.dark.withOpacity(0.2)
                  : ProfessionalColors.lightest.withOpacity(0.7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(review.comment,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? ProfessionalColors.light
                      : ProfessionalColors.secondaryText,
                  height: 1.5,
                )),
          ),
          if (review.relatedService != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: ProfessionalColors.mid.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(review.relatedService!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: ProfessionalColors.mid,
                    fontWeight: FontWeight.w600,
                  )),
            ),
          ],
        ]),
      );
}

// ─── Supporting Widgets ───────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;
  final Widget? action;
  const _SectionHeader(
      {required this.title, required this.isDark, this.action});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : ProfessionalColors.textPrimary)),
          if (action != null) action!,
        ],
      );
}

class _RatingBar extends StatelessWidget {
  final String label;
  final double value;
  const _RatingBar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          SizedBox(
              width: 52,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: ProfessionalColors.textSecondary))),
          Expanded(
              child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
                value: value / 5,
                backgroundColor: ProfessionalColors.border,
                valueColor: const AlwaysStoppedAnimation(Color(0xFFFBBF24)),
                minHeight: 6),
          )),
          const SizedBox(width: 6),
          Text(value.toStringAsFixed(1),
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      );
}

class _ReviewCard extends StatelessWidget {
  final ReviewModel review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: ProfessionalColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ProfessionalColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                    color: ProfessionalColors.mid.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Center(
                    child: Text(
                        review.customerName.isNotEmpty
                            ? review.customerName[0]
                            : '?',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: ProfessionalColors.mid,
                            fontSize: 13)))),
            const SizedBox(width: 8),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(review.customerName,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  Text(
                      '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: ProfessionalColors.textSecondary)),
                ])),
            Row(children: [
              const Icon(Icons.star_rounded,
                  color: Color(0xFFFBBF24), size: 14),
              const SizedBox(width: 2),
              Text(review.overallRating.toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ]),
          const SizedBox(height: 6),
          Text(review.comment,
              style: const TextStyle(
                  fontSize: 12,
                  color: ProfessionalColors.textSecondary,
                  height: 1.4)),
        ]),
      );
}

class _ServiceManageCard extends StatelessWidget {
  final ServiceModel service;
  final UserModel user;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _ServiceManageCard(
      {required this.service,
      required this.user,
      required this.isDark,
      required this.onEdit,
      required this.onDelete});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0B1A12) : const Color(0xFFF4FBF5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: isDark
                    ? ProfessionalColors.dark.withOpacity(0.3)
                    : ProfessionalColors.light.withOpacity(0.4))),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ProfessionalColors.mid.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.build_outlined,
                color: ProfessionalColors.mid, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(service.name,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color:
                            isDark ? Colors.white : const Color(0xFF051F20))),
                const SizedBox(height: 3),
                Text(service.description,
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? ProfessionalColors.light
                            : ProfessionalColors.secondaryText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ])),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: ProfessionalColors.mid.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: ProfessionalColors.mid.withOpacity(0.25)),
            ),
            child: Text('₪${service.price.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: ProfessionalColors.mid)),
          ),
          const SizedBox(width: 8),
          GestureDetector(
              onTap: onEdit,
              child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: ProfessionalColors.mid.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit_outlined,
                      size: 16, color: ProfessionalColors.mid))),
          const SizedBox(width: 6),
          GestureDetector(
              onTap: onDelete,
              child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: ProfessionalColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_outline,
                      size: 16, color: ProfessionalColors.error))),
        ]),
      );
}

class _EmptyState extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _EmptyState({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
              color: ProfessionalColors.mid.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: ProfessionalColors.light.withOpacity(0.4),
                  style: BorderStyle.solid)),
          child: Column(children: [
            const Icon(Icons.add_circle_outline,
                color: ProfessionalColors.mid, size: 28),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ProfessionalColors.mid)),
            const SizedBox(height: 2),
            const Text('Tap to add',
                style: TextStyle(
                    fontSize: 11, color: ProfessionalColors.secondaryText)),
          ]),
        ),
      );
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  final bool isDark;
  const _InfoCard({required this.children, required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : ProfessionalColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color:
                    isDark ? AppColors.darkBorder : ProfessionalColors.border)),
        child: Column(children: children),
      );
}

class _ProfileInfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final bool isDark;
  const _ProfileInfoRow(
      {required this.icon,
      required this.label,
      required this.value,
      required this.isDark});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Icon(icon,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : ProfessionalColors.textSecondary,
              size: 20),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : ProfessionalColors.textSecondary)),
            Text(value,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : ProfessionalColors.textPrimary)),
          ]),
        ]),
      );
}

class _ProfileActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool isDark;
  const _ProfileActionTile(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.color,
      required this.isDark});

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        leading: Icon(icon,
            color: color ??
                (isDark
                    ? AppColors.darkTextSecondary
                    : ProfessionalColors.textSecondary),
            size: 20),
        title: Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color ??
                    (isDark
                        ? AppColors.darkTextPrimary
                        : ProfessionalColors.textPrimary))),
        trailing: Icon(Icons.chevron_right_rounded,
            color: color ??
                (isDark
                    ? AppColors.darkTextSecondary
                    : ProfessionalColors.textSecondary),
            size: 18),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      );
}

class _ProfileDivider extends StatelessWidget {
  final bool isDark;
  const _ProfileDivider({required this.isDark});
  @override
  Widget build(BuildContext context) => Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: isDark ? AppColors.darkBorder : ProfessionalColors.border);
}

class _ProfEditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  const _ProfEditField(
      {required this.label,
      required this.controller,
      this.validator,
      this.keyboardType,
      this.maxLines = 1});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ProfessionalColors.secondaryText)),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            validator: validator,
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: ProfessionalColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: ProfessionalColors.mid, width: 2)),
              errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: ProfessionalColors.error)),
            ),
          ),
          const SizedBox(height: 12),
        ],
      );
}

// ─── Work Area Row with Google Maps Button ─────────────────────────────────────
class _ProfWorkAreaRow extends StatelessWidget {
  final String value;
  final String rawArea;
  final bool isDark;
  const _ProfWorkAreaRow({
    required this.value,
    required this.rawArea,
    required this.isDark,
  });

  Future<void> _openMaps(BuildContext context) async {
    Uri uri;
    if (rawArea.isNotEmpty) {
      final encoded = Uri.encodeComponent(rawArea);
      uri = Uri.parse('https://maps.google.com/?q=$encoded');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No work area set'),
        behavior: SnackBarBehavior.fixed,
      ));
      return;
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not open Google Maps'),
          behavior: SnackBarBehavior.fixed,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasArea = rawArea.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: isDark
                ? ProfessionalColors.dark.withOpacity(0.35)
                : ProfessionalColors.lightest.withOpacity(0.8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.location_on_outlined,
              color: isDark ? ProfessionalColors.light : ProfessionalColors.mid,
              size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Work Area',
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? ProfessionalColors.light
                    : ProfessionalColors.secondaryText,
                fontWeight: FontWeight.w500,
              )),
          const SizedBox(height: 2),
          Text(value.isEmpty ? '—' : value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: value.isEmpty
                    ? (isDark
                        ? ProfessionalColors.midDark
                        : ProfessionalColors.hintText)
                    : (isDark ? Colors.white : ProfessionalColors.titleText),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ])),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: hasArea ? () => _openMaps(context) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: hasArea
                  ? ProfessionalColors.mid.withOpacity(0.10)
                  : ProfessionalColors.border.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: hasArea
                      ? ProfessionalColors.mid.withOpacity(0.35)
                      : ProfessionalColors.border),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.map_rounded,
                  size: 14,
                  color: hasArea
                      ? ProfessionalColors.mid
                      : ProfessionalColors.textSecondary),
              const SizedBox(width: 4),
              Text('Maps',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: hasArea
                          ? ProfessionalColors.mid
                          : ProfessionalColors.textSecondary)),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── Notification Data Model ───────────────────────────────────────────────────
class _ProfNotif {
  final String? id;
  final IconData icon;
  final Color iconColor;
  final Color bg;
  final String title;
  final String subtitle;
  final String time;
  final bool isNew;
  final String notifType; // 'order', 'message', 'rating', 'other'
  final String? relatedOrderId;
  final String? relatedCustomerId;
  final String? relatedReviewId;
  const _ProfNotif({
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
    this.relatedReviewId,
  });
}

String _profNotifTimeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.day}/${dt.month}/${dt.year}';
}

// Converts a real Firestore NotificationModel (overlaid with this user's
// per-user read/delete state — see UserNotificationView) into the display
// model used by the professional's notification cards.
_ProfNotif _profNotifFromModel(UserNotificationView v) {
  final m = v.notification;
  IconData icon;
  Color iconColor;
  Color bg;
  String notifType;
  switch (m.type) {
    case NotificationType.chat:
      icon = Icons.chat_bubble_rounded;
      iconColor = const Color(0xFF5483B3);
      bg = const Color(0xFFEEF5FF);
      notifType = 'message';
      break;
    case NotificationType.orderUpdate:
      icon = Icons.assignment_rounded;
      iconColor = const Color(0xFFFFB800);
      bg = const Color(0xFFFFF8E1);
      notifType = 'order';
      break;
    case NotificationType.review:
      icon = Icons.star_rounded;
      iconColor = const Color(0xFFFFB800);
      bg = const Color(0xFFFFF8E1);
      notifType = 'rating';
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
    case NotificationType.system:
    case NotificationType.general:
    case NotificationType.categoryRequest:
      icon = Icons.info_rounded;
      iconColor = const Color(0xFF052659);
      bg = const Color(0xFFEEF5FF);
      notifType = 'other';
      break;
  }
  return _ProfNotif(
    id: m.id,
    icon: icon,
    iconColor: iconColor,
    bg: bg,
    title: m.title,
    subtitle: m.message,
    time: _profNotifTimeAgo(m.createdAt),
    isNew: !v.isRead,
    notifType: notifType,
    relatedOrderId: m.relatedOrderId,
    relatedReviewId: m.relatedReviewId,
  );
}

// ── Professional Notifications Page — Premium style matching Request Category ──
class _ProfNotificationsPage extends ConsumerStatefulWidget {
  const _ProfNotificationsPage();
  @override
  ConsumerState<_ProfNotificationsPage> createState() =>
      _ProfNotificationsPageState();
}

// The All / New / Orders / Messages filter chips were removed — every
// notification now appears in one list, so this page has no filter state and
// nothing to derive from it. Notification loading, read/unread state,
// "Mark all read", the new-count badge and tap navigation are unchanged.
class _ProfNotificationsPageState
    extends ConsumerState<_ProfNotificationsPage> {
  static const List<List<Color>> _gradients = [
    [Color(0xFF235347), Color(0xFF051F20)],
    [Color(0xFF163832), Color(0xFF051F20)],
    [Color(0xFF2E7D32), Color(0xFF1B5E20)],
    [Color(0xFFFFB800), Color(0xFFB45309)],
    [Color(0xFF0277BD), Color(0xFF01579B)],
  ];

  // model is looked up by id from the full overlaid-view list (see build()
  // below) rather than derived from the reduced _ProfNotif display model, so
  // every related-id field survives through to the shared router.
  void _handleTap(
      BuildContext context, WidgetRef ref, UserNotificationView? model) {
    if (model == null) return;
    handleNotificationTap(context, ref, model, UserRole.professional);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final notificationsAsync = user == null
        ? const AsyncValue<List<UserNotificationView>>.data(
            <UserNotificationView>[])
        : ref.watch(userNotificationsProvider(
            (userId: user.id, role: UserRole.professional)));
    final loading =
        notificationsAsync.isLoading && !notificationsAsync.hasValue;
    final hasError =
        notificationsAsync.hasError && !notificationsAsync.hasValue;
    final models =
        notificationsAsync.valueOrNull ?? const <UserNotificationView>[];
    final notifs = models.map(_profNotifFromModel).toList();
    final modelsById = {for (final m in models) m.id: m};
    final newCount = notifs.where((n) => n.isNew).length;

    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (hasError) {
      return const Scaffold(
          body: Center(child: Text('Failed to load notifications')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Header
          SliverAppBar(
            // Was 160 to make room for the filter-chip strip underneath the
            // title; with the chips gone that height left a blank band, so it
            // is trimmed to fit the icon + title/subtitle block exactly.
            expandedHeight: 128,
            pinned: true,
            backgroundColor: ProfessionalColors.darkest,
            foregroundColor: Colors.white,
            elevation: 0,
            automaticallyImplyLeading: false,
            leading: _ProfNeoBackBtn(),
            actions: [
              if (newCount > 0)
                TextButton(
                  onPressed: () {
                    if (user != null) {
                      markAllNotificationsReadInFirestore(
                          user.id, UserRole.professional);
                    }
                  },
                  child: const Text('Mark all read',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ),
              if (newCount > 0)
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
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 3))
                      ],
                    ),
                    child: Text('$newCount new',
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
                    colors: [
                      ProfessionalColors.darkest,
                      ProfessionalColors.dark
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
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
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(3, 4)),
                                BoxShadow(
                                    color: Colors.white.withOpacity(0.12),
                                    blurRadius: 6,
                                    offset: const Offset(-2, -2)),
                              ],
                            ),
                            child: Stack(children: [
                              const Center(
                                  child: Icon(Icons.notifications_rounded,
                                      color: Colors.white, size: 22)),
                              if (newCount > 0)
                                Positioned(
                                    right: 8,
                                    top: 8,
                                    child: Container(
                                        width: 9,
                                        height: 9,
                                        decoration: const BoxDecoration(
                                            color: Color(0xFFFF4444),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                  color: Color(0xFFFF4444),
                                                  blurRadius: 4,
                                                  spreadRadius: 1)
                                            ]))),
                            ]),
                          ),
                          const SizedBox(width: 14),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Notifications',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.5)),
                                Text(
                                  notifs.isEmpty
                                      ? 'All caught up!'
                                      : '${notifs.length} notifications',
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.65),
                                      fontSize: 12),
                                ),
                              ]),
                        ]),
                      ]),
                )),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // ── Section header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [
                      ProfessionalColors.mid,
                      ProfessionalColors.dark
                    ], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text('${notifs.length} Total',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF333355))),
                const Spacer(),
                if (notifs.isEmpty)
                  const Text('No notifications',
                      style: TextStyle(fontSize: 12, color: Color(0xFFAAAAAA))),
              ]),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // ── List
          if (notifs.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFEEEEF5),
                          boxShadow: [
                            BoxShadow(
                                color: Color(0xFFBEBECF),
                                blurRadius: 10,
                                offset: Offset(5, 5)),
                            BoxShadow(
                                color: Colors.white,
                                blurRadius: 10,
                                offset: Offset(-5, -5))
                          ]),
                      child: const Icon(Icons.notifications_off_outlined,
                          size: 28, color: Color(0xFFAAAACC))),
                  const SizedBox(height: 14),
                  const Text('Nothing here',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFAAAACC))),
                ]),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final n = notifs[i];
                    final colors = _gradients[i % _gradients.length];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ProfNeoNotifCard(
                          notif: n,
                          colors: colors,
                          onTap: () =>
                              _handleTap(context, ref, modelsById[n.id])),
                    );
                  },
                  childCount: notifs.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// ── Prof Neo Notification Card ─────────────────────────────────────────────────
class _ProfNeoNotifCard extends StatefulWidget {
  final _ProfNotif notif;
  final List<Color> colors;
  final VoidCallback onTap;
  const _ProfNeoNotifCard(
      {required this.notif, required this.colors, required this.onTap});
  @override
  State<_ProfNeoNotifCard> createState() => _ProfNeoNotifCardState();
}

class _ProfNeoNotifCardState extends State<_ProfNeoNotifCard>
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
                        offset: Offset(-1, -1))
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
                        offset: Offset(-5, -5))
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
                  ]),
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
                                ])))),
                Center(
                    child:
                        Icon(widget.notif.icon, color: Colors.white, size: 22)),
                if (widget.notif.isNew)
                  Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                          width: 8,
                          height: 8,
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
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF333355))),
                  const SizedBox(height: 4),
                  Text(widget.notif.subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF777799)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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
                              offset: Offset(-2, -2))
                        ]),
                    child: Text(widget.notif.time,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: c1)),
                  ),
                ])),
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
                        offset: Offset(-3, -3))
                  ]),
              child: const Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: Color(0xFF235347)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Neo Input Field for Complaint Sheet ───────────────────────────────────────
class _ProfNeoInputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int maxLines;
  final String? Function(String?)? validator;
  const _ProfNeoInputField(
      {required this.controller,
      required this.hint,
      required this.icon,
      this.maxLines = 1,
      this.validator});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: const Color(0xFFEEEEF5),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                  color: Color(0xFFBEBECF),
                  blurRadius: 6,
                  offset: Offset(3, 3)),
              BoxShadow(
                  color: Colors.white, blurRadius: 6, offset: Offset(-3, -3))
            ]),
        child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          style: const TextStyle(fontSize: 14, color: Color(0xFF333355)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFAAAACC), fontSize: 13),
            prefixIcon: Icon(icon, color: const Color(0xFF7777AA), size: 20),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      );
}

// ── Neo Submit Button ─────────────────────────────────────────────────────────
class _ProfNeoSubmitButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool loading;
  const _ProfNeoSubmitButton(
      {required this.label, required this.onTap, this.loading = false});
  @override
  State<_ProfNeoSubmitButton> createState() => _ProfNeoSubmitButtonState();
}

class _ProfNeoSubmitButtonState extends State<_ProfNeoSubmitButton>
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
          if (!widget.loading) {
            HapticFeedback.mediumImpact();
            setState(() => _pressed = true);
            _ctrl.forward();
          }
        },
        onTapUp: (_) {
          setState(() => _pressed = false);
          _ctrl.reverse();
          if (!widget.loading) widget.onTap();
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
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(27),
              gradient: const LinearGradient(
                  colors: [Color(0xFF0A1628), Color(0xFF051F20)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
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
                          offset: const Offset(0, -2))
                    ],
            ),
            child: Center(
                child: widget.loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : Text(widget.label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3))),
          ),
        ),
      );
}

// ── Professional Complaints Full Page ────────────────────────────────────────
class ProfessionalComplaintsPage extends ConsumerStatefulWidget {
  // Set from a notification tap so the matching complaint's tab is
  // auto-selected and its card is visually highlighted on open.
  final String? highlightComplaintId;
  const ProfessionalComplaintsPage({super.key, this.highlightComplaintId});
  @override
  ConsumerState<ProfessionalComplaintsPage> createState() =>
      _ProfessionalComplaintsPageState();
}

class _ProfessionalComplaintsPageState
    extends ConsumerState<ProfessionalComplaintsPage>
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
    final user = ref.read(authProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 12,
            right: 12),
        child: _ProfNewComplaintNeoSheet(user: user),
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
    final allComplaints =
        complaintsAsync.valueOrNull ?? const <ComplaintModel>[];
    final pending = allComplaints
        .where((c) =>
            c.status == ComplaintStatus.open ||
            c.status == ComplaintStatus.inReview)
        .toList();
    final resolved = allComplaints
        .where((c) => c.status == ComplaintStatus.resolved)
        .toList();
    final rejected = allComplaints
        .where((c) => c.status == ComplaintStatus.rejected)
        .toList();

    // A notification tap may pass a specific complaint to open — jump to
    // whichever tab it lives in and auto-open its details dialog once, the
    // first time it shows up in the stream, so the user's own later tab taps
    // and dialog opens/closes aren't overridden.
    if (widget.highlightComplaintId != null && !_initialComplaintOpened) {
      final match = allComplaints
          .where((c) => c.id == widget.highlightComplaintId)
          .toList();
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
              accentColor: ProfessionalColors.dark);
        });
      }
    }

    final list = _selectedTab == 0
        ? pending
        : _selectedTab == 1
            ? resolved
            : rejected;

    return Scaffold(
      backgroundColor: const Color(0xFFEEF7EF),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Header ──────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 130,
            backgroundColor: ProfessionalColors.darkest,
            foregroundColor: Colors.white,
            elevation: 0,
            automaticallyImplyLeading: false,
            leading: _ProfComplaintsBackBtn(),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 14, top: 8, bottom: 8),
                child: _ProfComplaintsNewBtn(onTap: _openNewComplaintSheet),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      ProfessionalColors.darkest,
                      ProfessionalColors.dark
                    ],
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
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
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
              child: _ProfComplaintsStepBar(
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
                  child: CircularProgressIndicator(
                      color: ProfessionalColors.darkest)),
            )
          else if (hasError)
            const SliverFillRemaining(
              child: Center(
                child: Text('Failed to load complaints',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: ProfessionalColors.darkest)),
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
                          color: ProfessionalColors.mid,
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
                            color: ProfessionalColors.darkest),
                      ),
                    ]),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _ProfComplaintNeo3DCard(
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

// ── Prof Complaints Pill Tab Bar ──────────────────────────────────────────────
class _ProfComplaintsStepBar extends StatefulWidget {
  final int selectedIndex, pendingCount, resolvedCount, rejectedCount;
  final void Function(int) onTap;
  const _ProfComplaintsStepBar({
    required this.selectedIndex,
    required this.pendingCount,
    required this.resolvedCount,
    required this.rejectedCount,
    required this.onTap,
  });
  @override
  State<_ProfComplaintsStepBar> createState() => _ProfComplaintsStepBarState();
}

class _ProfComplaintsStepBarState extends State<_ProfComplaintsStepBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideCtrl;

  static const _tabData = [
    (
      label: 'Pending',
      icon: Icons.hourglass_top_rounded,
      activeColor: Color(0xFFF59E0B),
      darkColor: Color(0xFFB45309)
    ),
    (
      label: 'Resolved',
      icon: Icons.check_circle_outline_rounded,
      activeColor: ProfessionalColors.mid,
      darkColor: ProfessionalColors.dark
    ),
    (
      label: 'Rejected',
      icon: Icons.cancel_outlined,
      activeColor: Color(0xFFEF4444),
      darkColor: Color(0xFF991B1B)
    ),
  ];

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void didUpdateWidget(_ProfComplaintsStepBar old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex != widget.selectedIndex) _slideCtrl.forward(from: 0);
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
                        child: Icon(tab.icon,
                            size: isActive ? 15 : 13,
                            color: isActive
                                ? Colors.white
                                : const Color(0xFF9999BB))),
                  ),
                  const SizedBox(width: 7),
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
                                : const Color(0xFF666688),
                          )),
                    ),
                  ],
                ])),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Prof Complaints Back Button ───────────────────────────────────────────────
class _ProfComplaintsBackBtn extends StatefulWidget {
  @override
  State<_ProfComplaintsBackBtn> createState() => _ProfComplaintsBackBtnState();
}

class _ProfComplaintsBackBtnState extends State<_ProfComplaintsBackBtn>
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

// ── Prof Complaints New Button ────────────────────────────────────────────────
class _ProfComplaintsNewBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _ProfComplaintsNewBtn({required this.onTap});
  @override
  State<_ProfComplaintsNewBtn> createState() => _ProfComplaintsNewBtnState();
}

class _ProfComplaintsNewBtnState extends State<_ProfComplaintsNewBtn>
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
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_rounded, color: Color(0xFF5555AA), size: 16),
              SizedBox(width: 5),
              Text('New',
                  style: TextStyle(
                      color: Color(0xFF5555AA),
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      );
}

// ── Prof Complaint Neo 3D Card ────────────────────────────────────────────────
class _ProfComplaintNeo3DCard extends ConsumerStatefulWidget {
  final ComplaintModel complaint;
  final bool highlighted;
  const _ProfComplaintNeo3DCard(
      {required this.complaint, this.highlighted = false});
  @override
  ConsumerState<_ProfComplaintNeo3DCard> createState() =>
      _ProfComplaintNeo3DCardState();
}

class _ProfComplaintNeo3DCardState
    extends ConsumerState<_ProfComplaintNeo3DCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _dotsCtrl;

  static const _statusColors = {
    ComplaintStatus.open: Color(0xFFF59E0B),
    ComplaintStatus.inReview: Color(0xFF0EA5E9),
    ComplaintStatus.resolved: ProfessionalColors.mid,
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
        final screenH = MediaQuery.of(ctx).size.height;
        const panelH = 2 * 58.0 + 20;
        double topPos = (pos?.dy ?? 200) + 10;
        if (topPos + panelH > screenH - 16)
          topPos = (pos?.dy ?? 200) - panelH + 10;
        topPos = topPos.clamp(16.0, screenH - panelH - 16);
        return Stack(children: [
          Positioned.fill(
              child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(color: Colors.transparent))),
          Positioned(
            top: topPos,
            right: 20,
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(0.4, -0.2), end: Offset.zero)
                  .animate(curved),
              child: FadeTransition(
                  opacity: anim,
                  child: _ProfComplaintDotsPanel(
                    onEdit: () {
                      Navigator.pop(ctx);
                      _openEditSheet();
                    },
                    onDelete: () {
                      Navigator.pop(ctx);
                      _confirmDelete();
                    },
                  )),
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
        child: _ProfNewComplaintNeoSheet(existing: widget.complaint),
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
                  style: TextStyle(color: ProfessionalColors.mid))),
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
    final color = _statusColors[c.status] ?? ProfessionalColors.mid;
    final label = _statusLabels[c.status] ?? '';

    // Visual-quality reference: the Professional Order card (white surface,
    // status-accent top bar, thin accent-tinted outer border, soft
    // status-tinted shadow) — reused here for design consistency only.
    // Content/fields/actions/status logic below are all unchanged.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showComplaintDetailsDialog(context, c,
          accentColor: ProfessionalColors.dark),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.all(Radius.circular(24)),
          border: widget.highlighted
              ? Border.all(color: ProfessionalColors.dark, width: 2.5)
              : Border.all(color: color.withOpacity(0.18), width: 1),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.20),
                blurRadius: 0,
                offset: const Offset(0, 5)),
            BoxShadow(
                color: color.withOpacity(0.10),
                blurRadius: 16,
                offset: const Offset(0, 8)),
            BoxShadow(
                color: Colors.white.withOpacity(0.90),
                blurRadius: 4,
                offset: const Offset(0, -1)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(children: [
            // Top accent bar — mirrors the Professional Order card's status
            // accent bar.
            Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [color, color.withOpacity(0.4)]),
                    ))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header row ──────────────────────────────────────
                    Row(children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [
                                color.withOpacity(0.65),
                                color.withOpacity(0.35)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                                color: color.withOpacity(0.35),
                                blurRadius: 0,
                                offset: const Offset(0, 3)),
                            BoxShadow(
                                color: color.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 5)),
                            const BoxShadow(
                                color: Colors.white,
                                blurRadius: 3,
                                offset: Offset(0, -1)),
                          ],
                          border: Border.all(
                              color: Colors.white.withOpacity(0.6), width: 1.5),
                        ),
                        child: const Center(
                            child: Icon(Icons.flag_rounded,
                                color: Colors.white, size: 20)),
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
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.10),
                                borderRadius:
                                    BorderRadius.all(Radius.circular(20)),
                                border:
                                    Border.all(color: color.withOpacity(0.3)),
                              ),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                        width: 5,
                                        height: 5,
                                        decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle)),
                                    const SizedBox(width: 5),
                                    Text(label,
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: color)),
                                  ]),
                            ),
                          ])),
                      // 3-dot menu (only when the complaint can still be
                      // edited/deleted)
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
                                scale: 1.0 - 0.08 * _dotsCtrl.value,
                                child: child),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                  color: Colors.white,
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(12)),
                                  border: Border.fromBorderSide(
                                      BorderSide(color: Color(0x2614B8A6))),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Color(0x1F14B8A6),
                                        blurRadius: 10,
                                        offset: Offset(0, 3)),
                                    BoxShadow(
                                        color: Color(0x14000000),
                                        blurRadius: 4,
                                        offset: Offset(0, 1)),
                                  ]),
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
                                                color: Color(0xFF7777AA),
                                                shape: BoxShape.circle),
                                          ))),
                            ),
                          ),
                        ),
                    ]),

                    // ── Related ───────────────────────────────────────────
                    if (c.targetName != null &&
                        c.targetName!.isNotEmpty &&
                        c.targetName != 'General') ...[
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

                    const SizedBox(height: 12),
                    // Gradient divider — mirrors the Professional Order
                    // card's status-accent divider.
                    Container(
                        height: 1,
                        decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                          Colors.transparent,
                          color.withOpacity(0.25),
                          Colors.transparent
                        ]))),
                    const SizedBox(height: 10),

                    // ── Description ───────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF4FBFA),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color:
                                  ProfessionalColors.dark.withOpacity(0.08))),
                      child: Text(c.description,
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF555577),
                              height: 1.5),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis),
                    ),

                    const SizedBox(height: 10),
                    // ── Date ───────────────────────────────────────────────
                    Row(children: [
                      Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                              color: ProfessionalColors.dark.withOpacity(0.06),
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(9))),
                          child: const Icon(Icons.calendar_today_rounded,
                              size: 13, color: Color(0xFF9999BB))),
                      const SizedBox(width: 8),
                      Text(
                          '${c.createdAt.day}/${c.createdAt.month}/${c.createdAt.year}',
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9999BB),
                              fontWeight: FontWeight.w600)),
                    ]),

                    // ── Admin reply ─────────────────────────────────────────
                    if (c.replyText != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [
                                ProfessionalColors.mid,
                                ProfessionalColors.dark
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(
                                color: ProfessionalColors.dark,
                                blurRadius: 0,
                                offset: Offset(0, 3)),
                            BoxShadow(
                                color: Color(0x8010B981),
                                blurRadius: 8,
                                offset: Offset(0, 4)),
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
                    // ── Admin note ──────────────────────────────────────────
                    if (c.adminNote != null &&
                        c.adminNote!.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4FBFA),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: ProfessionalColors.mid.withOpacity(0.3)),
                        ),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.sticky_note_2_outlined,
                                  size: 16, color: ProfessionalColors.dark),
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
          ]),
        ),
      ),
    );
  }
}

// ── Prof Complaint Dots Panel ─────────────────────────────────────────────────
class _ProfComplaintDotsPanel extends StatefulWidget {
  final VoidCallback onEdit, onDelete;
  const _ProfComplaintDotsPanel({required this.onEdit, required this.onDelete});
  @override
  State<_ProfComplaintDotsPanel> createState() =>
      _ProfComplaintDotsPanelState();
}

class _ProfComplaintDotsPanelState extends State<_ProfComplaintDotsPanel>
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
                  curve: Curves.easeOutBack));
          return AnimatedBuilder(
            animation: anim,
            builder: (_, child) => Opacity(
                opacity: anim.value.clamp(0.0, 1.0),
                child: Transform.scale(
                    scale: 0.6 + 0.4 * anim.value.clamp(0.0, 1.0),
                    child: child)),
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
                      ]),
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

// ── Prof New/Edit Complaint Neo Sheet ─────────────────────────────────────────
class _ProfNewComplaintNeoSheet extends ConsumerStatefulWidget {
  final ComplaintModel? existing;
  final UserModel? user;
  const _ProfNewComplaintNeoSheet({this.existing, this.user});
  @override
  ConsumerState<_ProfNewComplaintNeoSheet> createState() =>
      _ProfNewComplaintNeoSheetState();
}

class _ProfNewComplaintNeoSheetState
    extends ConsumerState<_ProfNewComplaintNeoSheet> {
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
        backgroundColor: ProfessionalColors.error,
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    setState(() => _loading = true);
    final currentUser = widget.user ?? ref.read(authProvider);

    try {
      if (widget.existing != null) {
        await updateComplaintInFirestore(
          widget.existing!.copyWith(
              reason: _selectedReason!, description: _descCtrl.text.trim()),
        );
      } else {
        await addComplaintInFirestore(ComplaintModel(
          id: '',
          userId: currentUser?.id ?? '',
          userName: currentUser?.fullName ?? '',
          complainantRole: 'professional',
          type: ComplaintType.general,
          targetId: 'general',
          targetName: null,
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
          backgroundColor: ProfessionalColors.mid,
          behavior: SnackBarBehavior.fixed,
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
                        offset: Offset(1, 1))
                  ]),
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
                            offset: Offset(-4, -4))
                      ]),
                  child: Icon(isEdit ? Icons.edit_rounded : Icons.flag_rounded,
                      color: isEdit
                          ? const Color(0xFF7C3AED)
                          : const Color(0xFFEF4444),
                      size: 22)),
              const SizedBox(width: 14),
              Text(isEdit ? 'Edit Complaint' : 'Submit Complaint',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF333355))),
            ]),
            const SizedBox(height: 20),
            // Reason
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
                                  offset: Offset(0, 3))
                            ]
                          : const [
                              BoxShadow(
                                  color: Color(0xFFBEBECF),
                                  blurRadius: 5,
                                  offset: Offset(3, 3)),
                              BoxShadow(
                                  color: Colors.white,
                                  blurRadius: 5,
                                  offset: Offset(-3, -3))
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
                        offset: Offset(-3, -3))
                  ]),
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
            _ProfNeoSubmitButton(
              label: _loading ? 'Submitting...' : 'Save Changes',
              onTap: _loading ? () {} : _submit,
              loading: _loading,
            ),
          ]),
        ),
      ),
    );
  }
}
