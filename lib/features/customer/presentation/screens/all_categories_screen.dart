import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/presentation/providers/app_providers.dart';
import '../../../../shared/utils/category_icon_helper.dart';
import '../theme/customer_design.dart';
import 'category_providers_screen.dart';
import 'category_request_sheet.dart';
import 'customer_category_requests_screen.dart';

class AllCategoriesScreen extends ConsumerWidget {
  const AllCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final categories = ref.watch(categoriesProvider).value ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF0F6FF),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Premium AppBar ────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            backgroundColor: CustomerColors.dark,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: const _NeoBackButtonWhite(),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _NeoCategoryMenuButton(
                  onTap: () => _showCategoryOptionsMenu(context, ref),
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
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          l.get('all_categories'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l
                              .get('categories_available')
                              .replaceAll('{count}', '${categories.length}'),
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

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // ── Categories Grid ───────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.82,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final cat = categories[i];
                  return _Pro3DCategoryCard(
                    cat: cat,
                    l: l,
                    index: i,
                    onTap: () => Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, anim, __) => CategoryProvidersScreen(
                            categoryKey: cat.nameKey, categoryId: cat.id),
                        transitionsBuilder: (_, anim, __, child) {
                          return FadeTransition(
                            opacity: anim,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.06),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                  parent: anim, curve: Curves.easeOutCubic)),
                              child: child,
                            ),
                          );
                        },
                        transitionDuration: const Duration(milliseconds: 280),
                      ),
                    ),
                  );
                },
                childCount: categories.length,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  void _showCategoryOptionsMenu(BuildContext context, WidgetRef ref) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return Stack(children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            top: 58,
            right: 16,
            child: FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                scale: curved,
                alignment: Alignment.topRight,
                child: _CategoryHeaderMenu(
                  onRequestNew: () {
                    Navigator.pop(ctx);
                    Future.microtask(
                        () => showCategoryRequestSheet(context, ref));
                  },
                  onMyRequests: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const CustomerCategoryRequestsScreen()),
                    );
                  },
                ),
              ),
            ),
          ),
        ]);
      },
    );
  }
}

// ── Category Header Options Menu (Request New / My Requests) ─────────────────
class _CategoryHeaderMenu extends StatelessWidget {
  final VoidCallback onRequestNew;
  final VoidCallback onMyRequests;
  const _CategoryHeaderMenu(
      {required this.onRequestNew, required this.onMyRequests});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 24,
              offset: const Offset(0, 8)),
        ],
      ),
      // Material provides both the white surface (so InkWell ripples paint
      // correctly) and the rounded clip, so no separate ClipRRect is needed.
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CategoryHeaderMenuItem(
              icon: Icons.add_circle_outline_rounded,
              label: 'Request a New Category',
              color: const Color(0xFF7C3AED),
              onTap: onRequestNew,
            ),
            Divider(
                height: 1,
                color: Colors.grey.withOpacity(0.15),
                indent: 16,
                endIndent: 16),
            _CategoryHeaderMenuItem(
              icon: Icons.list_alt_rounded,
              label: 'My Category Requests',
              color: const Color(0xFF0EA5E9),
              onTap: onMyRequests,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryHeaderMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _CategoryHeaderMenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: color.withOpacity(0.12)),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E2A3A)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Gradient palettes ─────────────────────────────────────────────────────────
const List<List<Color>> _cardGradients = [
  [Color(0xFFF5F3FF), Color(0xFFEDE9FE)], // violet
  [Color(0xFFEFF6FF), Color(0xFFDBEAFE)], // blue
  [Color(0xFFFFFBEB), Color(0xFFFEF3C7)], // amber
  [Color(0xFFECFDF5), Color(0xFFD1FAE5)], // emerald
  [Color(0xFFFFF1F2), Color(0xFFFEE2E2)], // red
  [Color(0xFFFDF2F8), Color(0xFFFCE7F3)], // pink
  [Color(0xFFEEF2FF), Color(0xFFE0E7FF)], // indigo
  [Color(0xFFF0FDFA), Color(0xFFCCFBF1)], // teal
  [Color(0xFFFFF7ED), Color(0xFFFED7AA)], // orange
  [Color(0xFFF5F3FF), Color(0xFFEDE9FE)], // violet repeat
  [Color(0xFFECFEFF), Color(0xFFCFFAFE)], // cyan
  [Color(0xFFF7FEE7), Color(0xFFDCFCE7)], // lime
  [Color(0xFFFDF4FF), Color(0xFFF5D0FE)], // fuchsia
];

// unused accent list removed

// ── Professional 3D Category Card ─────────────────────────────────────────────
class _Pro3DCategoryCard extends StatefulWidget {
  final dynamic cat;
  final AppLocalizations l;
  final VoidCallback onTap;
  final int index;
  const _Pro3DCategoryCard({
    required this.cat,
    required this.l,
    required this.onTap,
    this.index = 0,
  });

  @override
  State<_Pro3DCategoryCard> createState() => _Pro3DCategoryCardState();
}

class _Pro3DCategoryCardState extends State<_Pro3DCategoryCard>
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
        builder: (_, child) => Transform.scale(
          scale: 1.0 - 0.04 * _ctrl.value,
          child: child,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
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
                        blurRadius: 14,
                        offset: Offset(6, 6)),
                    const BoxShadow(
                        color: Colors.white,
                        blurRadius: 14,
                        offset: Offset(-6, -6)),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon container — inset neumorphic
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: const Color(0xFFEEEEF5),
                    boxShadow: _pressed
                        ? [
                            const BoxShadow(
                                color: Color(0xFFBEBECF),
                                blurRadius: 4,
                                offset: Offset(2, 2)),
                            const BoxShadow(
                                color: Colors.white,
                                blurRadius: 4,
                                offset: Offset(-2, -2)),
                          ]
                        : [
                            const BoxShadow(
                                color: Color(0xFFBEBECF),
                                blurRadius: 8,
                                offset: Offset(4, 4)),
                            const BoxShadow(
                                color: Colors.white,
                                blurRadius: 8,
                                offset: Offset(-4, -4)),
                          ],
                  ),
                  child: Center(
                    child: Icon(
                      categoryIconFor(
                          id: widget.cat.id,
                          nameKey: widget.cat.nameKey,
                          icon: widget.cat.icon),
                      color: const Color(0xFF5555AA),
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.l.get(widget.cat.nameKey),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9999BB),
                    letterSpacing: 0.1,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Neomorphism Menu Button (top-right in AppBar) ─────────────────────────────
class _NeoCategoryMenuButton extends StatefulWidget {
  final VoidCallback onTap;
  const _NeoCategoryMenuButton({required this.onTap});

  @override
  State<_NeoCategoryMenuButton> createState() => _NeoCategoryMenuButtonState();
}

class _NeoCategoryMenuButtonState extends State<_NeoCategoryMenuButton>
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
          scale: 1.0 - 0.08 * _ctrl.value,
          child: child,
        ),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: Colors.white.withOpacity(0.35), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 6,
                offset: const Offset(2, 3),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.15),
                blurRadius: 4,
                offset: const Offset(-1, -1),
              ),
            ],
          ),
          child: const Icon(Icons.more_vert_rounded,
              color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

// ── Animated Category Card (kept for backward compat in feed screen) ──────────
class _AnimatedCategoryCard extends StatefulWidget {
  final dynamic cat;
  final Color bg;
  final AppLocalizations l;
  final VoidCallback onTap;
  const _AnimatedCategoryCard(
      {required this.cat,
      required this.bg,
      required this.l,
      required this.onTap});

  @override
  State<_AnimatedCategoryCard> createState() => _AnimatedCategoryCardState();
}

class _AnimatedCategoryCardState extends State<_AnimatedCategoryCard>
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
            Transform.scale(scale: 1.0 - 0.05 * _ctrl.value, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
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
                        blurRadius: 10,
                        offset: Offset(4, 4)),
                    BoxShadow(
                        color: Colors.white,
                        blurRadius: 10,
                        offset: Offset(-4, -4)),
                  ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
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
                child: Center(
                    child: Text(widget.cat.icon,
                        style: const TextStyle(fontSize: 26))),
              ),
              const SizedBox(height: 7),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  widget.l.get(widget.cat.nameKey),
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF444466)),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Request Category Icon Button ──────────────────────────────────────────────
class _RequestCategoryIconButton extends StatefulWidget {
  final VoidCallback onTap;
  const _RequestCategoryIconButton({required this.onTap});
  @override
  State<_RequestCategoryIconButton> createState() =>
      _RequestCategoryIconButtonState();
}

class _RequestCategoryIconButtonState extends State<_RequestCategoryIconButton>
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
        builder: (_, child) =>
            Transform.scale(scale: 1.0 - 0.08 * _ctrl.value, child: child),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: const [
            Icon(Icons.add_rounded, color: Colors.white, size: 18),
            SizedBox(width: 4),
            Icon(Icons.category_outlined, color: Colors.white, size: 16),
          ]),
        ),
      ),
    );
  }
}

// ── Neo Back Button (white, for gradient headers) ─────────────────────────────
class _NeoBackButtonWhite extends StatefulWidget {
  const _NeoBackButtonWhite();

  @override
  State<_NeoBackButtonWhite> createState() => _NeoBackButtonWhiteState();
}

class _NeoBackButtonWhiteState extends State<_NeoBackButtonWhite>
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
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.08 * _ctrl.value, child: child),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(13),
              border:
                  Border.all(color: Colors.white.withOpacity(0.35), width: 1.5),
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
}
