import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/models.dart';
import '../../../admin/presentation/providers/help_center_provider.dart';
import '../data/help_center_translations.dart';
import '../widgets/help_translate_action.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HelpCenterScreen — shared across Customer, Professional and Contractor roles
// ─────────────────────────────────────────────────────────────────────────────
class HelpCenterScreen extends ConsumerStatefulWidget {
  final UserRole userRole;
  final Color? accentColor;
  final Color? gradientStart;
  final Color? gradientEnd;
  // Optional middle gradient stop — lets a caller reproduce an exact 3-stop
  // gradient (e.g. the Customer Home header). Left null, the header keeps
  // its original 2-color gradient exactly as before for every other caller.
  final Color? gradientMid;

  const HelpCenterScreen({
    super.key,
    required this.userRole,
    this.accentColor,
    this.gradientStart,
    this.gradientEnd,
    this.gradientMid,
  });

  @override
  ConsumerState<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends ConsumerState<HelpCenterScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  // ── Filter state ─────────────────────────────────────────────────────────
  // null = show all, otherwise shows only that section
  String? _activeFilter; // 'about' | 'howto' | 'faq' | 'smart'

  void _onFilterTap(String key) {
    setState(() {
      _activeFilter = (_activeFilter == key) ? null : key;
    });
  }

  // ── Scroll + section keys ────────────────────────────────────────────────
  final _scrollCtrl = ScrollController();
  final _keyAbout = GlobalKey();
  final _keyHowTo = GlobalKey();
  final _keyFaq = GlobalKey();
  final _keySmart = GlobalKey();

  Color get _accent => widget.accentColor ?? AppColors.accent;
  Color get _gradStart => widget.gradientStart ?? const Color(0xFF052659);
  Color get _gradEnd => widget.gradientEnd ?? const Color(0xFF1A4A8A);

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.customer:
        return 'Customer';
      case UserRole.professional:
        return 'Professional';
      case UserRole.contractor:
        return 'Contractor';
      case UserRole.admin:
        return 'Admin';
    }
  }

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = ref.watch(helpCenterProvider);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF6F8FF),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          controller: _scrollCtrl,
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Hero Header ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _HeroHeader(
                gradStart: _gradStart,
                gradMid: widget.gradientMid,
                gradEnd: _gradEnd,
                activeFilter: _activeFilter,
                onFilterTap: _onFilterTap,
              ),
            ),

            // ── Body ────────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── About San3a ──────────────────────────────────────
                  if (_activeFilter == null || _activeFilter == 'about') ...[
                    _SectionCard(
                      key: _keyAbout,
                      icon: Icons.info_outline_rounded,
                      title: 'About San3a',
                      accent: _accent,
                      isDark: isDark,
                      child: _AboutSection(
                        isDark: isDark,
                        aboutText: content.aboutText,
                        userRole: widget.userRole,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── How to Use ───────────────────────────────────────
                  if (_activeFilter == null || _activeFilter == 'howto') ...[
                    _SectionCard(
                      key: _keyHowTo,
                      icon: Icons.menu_book_rounded,
                      title: 'How to Use as a ${_roleLabel(widget.userRole)}',
                      accent: _accent,
                      isDark: isDark,
                      child: _HowToUseSection(
                        isDark: isDark,
                        accent: _accent,
                        userRole: widget.userRole,
                        customerHelp: content.customerHelp,
                        professionalHelp: content.professionalHelp,
                        contractorHelp: content.contractorHelp,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── FAQ ──────────────────────────────────────────────
                  if (_activeFilter == null || _activeFilter == 'faq') ...[
                    _SectionCard(
                      key: _keyFaq,
                      icon: Icons.quiz_rounded,
                      title: 'Quick Support',
                      accent: _accent,
                      isDark: isDark,
                      child: _FaqSection(
                          isDark: isDark,
                          accent: _accent,
                          faqs: content.faqs
                              .where((f) =>
                                  f.role == null || f.role == widget.userRole)
                              .toList()),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Smart Features ───────────────────────────────────
                  if (_activeFilter == null || _activeFilter == 'smart') ...[
                    _SectionCard(
                      key: _keySmart,
                      icon: Icons.auto_awesome_rounded,
                      title: 'Smart Features',
                      accent: _accent,
                      isDark: isDark,
                      child: _SmartFeaturesSection(
                        isDark: isDark,
                        userRole: widget.userRole,
                      ),
                    ),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero Header
// ─────────────────────────────────────────────────────────────────────────────
class _HeroHeader extends StatelessWidget {
  final Color gradStart;
  final Color? gradMid;
  final Color gradEnd;
  final String? activeFilter;
  final void Function(String) onFilterTap;

  const _HeroHeader({
    required this.gradStart,
    this.gradMid,
    required this.gradEnd,
    required this.activeFilter,
    required this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradMid != null
              ? [gradStart, gradMid!, gradEnd]
              : [gradStart, gradEnd],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          // App bar row
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.support_agent_rounded,
                      color: Colors.white70, size: 14),
                  SizedBox(width: 5),
                  Text('Help Center',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
          ),

          // Title block
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
            child: Column(children: [
              // Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withOpacity(0.3), width: 2),
                ),
                child: const Icon(Icons.help_center_rounded,
                    color: Colors.white, size: 36),
              ),
              const SizedBox(height: 18),
              const Text(
                'Welcome to\nSan3a Help Center',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                    letterSpacing: -0.5),
              ),
              const SizedBox(height: 10),
              Text(
                'Find everything you need to know\nabout using San3a.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 14,
                    height: 1.5),
              ),

              const SizedBox(height: 24),

              // ── Filter buttons 2×2 grid ──────────────────────
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.6,
                children: [
                  _NavSquare(
                    label: 'About',
                    icon: Icons.info_outline_rounded,
                    isActive: activeFilter == 'about',
                    onTap: () => onFilterTap('about'),
                  ),
                  _NavSquare(
                    label: 'How to Use',
                    icon: Icons.menu_book_rounded,
                    isActive: activeFilter == 'howto',
                    onTap: () => onFilterTap('howto'),
                  ),
                  _NavSquare(
                    label: 'FAQ',
                    icon: Icons.quiz_rounded,
                    isActive: activeFilter == 'faq',
                    onTap: () => onFilterTap('faq'),
                  ),
                  _NavSquare(
                    label: 'Smart Features',
                    icon: Icons.auto_awesome_rounded,
                    isActive: activeFilter == 'smart',
                    onTap: () => onFilterTap('smart'),
                  ),
                ],
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nav Pill — now tappable
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// Nav Square — 2×2 grid button
// ─────────────────────────────────────────────────────────────────────────────
class _NavSquare extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;
  const _NavSquare(
      {required this.label,
      required this.icon,
      required this.onTap,
      this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withOpacity(0.35)
              : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? Colors.white.withOpacity(0.90)
                : Colors.white.withOpacity(0.35),
            width: isActive ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isActive ? 0.18 : 0.10),
              blurRadius: isActive ? 10 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w900 : FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Card wrapper
// ─────────────────────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accent;
  final bool isDark;
  final Widget child;

  const _SectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.accent,
    required this.isDark,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141414) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? Colors.white12 : const Color(0xFFE8EAFF),
            width: 1.2),
        boxShadow: [
          BoxShadow(
              color: accent.withOpacity(isDark ? 0.08 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accent, size: 19),
            ),
            const SizedBox(width: 10),
            Text(title,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0A0A1A),
                    letterSpacing: -0.2)),
          ]),
        ),
        Divider(
            height: 1,
            color: isDark ? Colors.white10 : const Color(0xFFEEEEFF)),
        child,
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// About San3a Section
// ─────────────────────────────────────────────────────────────────────────────
class _AboutSection extends StatelessWidget {
  final bool isDark;
  final String aboutText;
  final UserRole userRole;
  const _AboutSection(
      {required this.isDark, required this.aboutText, required this.userRole});

  static const _roleSummaries = {
    UserRole.customer:
        'Browse providers, create and track service requests, communicate '
            'with providers, and manage favorites, reviews, and complaints.',
    UserRole.professional:
        'Manage your profile, specialties, services, availability, '
            'incoming requests, customer communication, and reviews.',
    UserRole.contractor: 'Manage your company profile, services, workers, worker '
        'assignments, service requests, customer communication, and reviews.',
  };

  static const _roleIcons = {
    UserRole.customer: Icons.people_alt_rounded,
    UserRole.professional: Icons.engineering_rounded,
    UserRole.contractor: Icons.construction_rounded,
  };

  static const _roleColors = {
    UserRole.customer: Color(0xFF3B82F6), // blue
    UserRole.professional: Color(0xFF235347), // green
    UserRole.contractor: Color(0xFF8C6E63), // brown
  };

  static const _roleTitles = {
    UserRole.customer: 'Using San3a as a Customer',
    UserRole.professional: 'Using San3a as a Professional',
    UserRole.contractor: 'Using San3a as a Contractor',
  };

  @override
  Widget build(BuildContext context) {
    final roleColor = _roleColors[userRole] ?? const Color(0xFF3B82F6);
    final roleIcon = _roleIcons[userRole] ?? Icons.person_rounded;
    final roleTitle = _roleTitles[userRole] ?? 'Using San3a';
    final roleSummary = _roleSummaries[userRole] ?? '';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Main description
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF06C167).withOpacity(0.08)
                : const Color(0xFFE8FFF4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: const Color(0xFF06C167).withOpacity(0.25), width: 1),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.lightbulb_outline_rounded,
                color: Color(0xFF06C167), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    aboutText,
                    style: TextStyle(
                        fontSize: 13.5,
                        height: 1.6,
                        color:
                            isDark ? Colors.white70 : const Color(0xFF2D2D4E)),
                  ),
                  const SizedBox(height: 8),
                  HelpTranslateAction(
                    translations: HelpCenterTranslations.aboutGeneral,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),

        // Role-specific card for the logged-in role only
        if (roleSummary.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: roleColor.withOpacity(isDark ? 0.12 : 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: roleColor.withOpacity(0.25)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(roleIcon, color: roleColor, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(roleTitle,
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0A0A1A))),
                    const SizedBox(height: 4),
                    Text(roleSummary,
                        style: TextStyle(
                            fontSize: 12.5,
                            height: 1.5,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF2D2D4E))),
                    const SizedBox(height: 8),
                    HelpTranslateAction(
                      translations:
                          HelpCenterTranslations.aboutRoleSummary[userRole] ??
                              const {},
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// How to Use Section — steps for the logged-in role only
// ─────────────────────────────────────────────────────────────────────────────
class _HowToUseSection extends StatelessWidget {
  final bool isDark;
  final Color accent;
  final UserRole userRole;
  final String customerHelp;
  final String professionalHelp;
  final String contractorHelp;
  const _HowToUseSection({
    required this.isDark,
    required this.accent,
    required this.userRole,
    required this.customerHelp,
    required this.professionalHelp,
    required this.contractorHelp,
  });

  static const _roleColors = {
    UserRole.customer: Color(0xFF3B82F6), // blue
    UserRole.professional: Color(0xFF235347), // green
    UserRole.contractor: Color(0xFF8C6E63), // brown
  };

  static const _steps = {
    UserRole.customer: [
      (Icons.grid_view_rounded, 'Browse service categories'),
      (Icons.search_rounded, 'View professionals and contractors'),
      (Icons.favorite_rounded, 'Add providers to favorites'),
      (Icons.add_circle_outline_rounded, 'Create service requests'),
      (Icons.track_changes_rounded, 'Track your orders in real time'),
      (Icons.flag_outlined, 'Send complaints when needed'),
      (Icons.chat_bubble_outline_rounded, 'Chat directly with providers'),
    ],
    UserRole.professional: [
      (Icons.inbox_rounded, 'View and manage incoming requests'),
      (Icons.check_circle_outline_rounded, 'Accept or decline requests'),
      (Icons.build_circle_outlined, 'Manage your offered services'),
      (Icons.edit_note_rounded, 'Edit your profile and specialties'),
      (Icons.star_outline_rounded, 'View customer reviews and ratings'),
      (Icons.chat_bubble_outline_rounded, 'Chat with customers anytime'),
    ],
    UserRole.contractor: [
      (Icons.assignment_rounded, 'Manage and track service requests'),
      (Icons.group_rounded, 'Manage workers and suppliers'),
      (Icons.calendar_month_rounded, 'Track schedules and timelines'),
      (Icons.handyman_rounded, 'Manage services you offer'),
      (Icons.manage_accounts_rounded, 'Edit your profile and info'),
      (Icons.chat_bubble_outline_rounded, 'Chat with customers anytime'),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final color = _roleColors[userRole] ?? const Color(0xFF3B82F6);
    final steps = _steps[userRole] ?? const [];
    final helpText = userRole == UserRole.customer
        ? customerHelp
        : userRole == UserRole.professional
            ? professionalHelp
            : contractorHelp;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Steps list
        Column(
          children: List.generate(steps.length, (i) {
            final step = steps[i];
            return _StepTile(
              index: i + 1,
              icon: step.$1,
              label: step.$2,
              color: color,
              isDark: isDark,
            );
          }),
        ),

        // Role-specific help text from admin
        if (helpText.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: color.withOpacity(isDark ? 0.08 : 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.2))),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline_rounded, color: color, size: 16),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(helpText,
                        style: TextStyle(
                            fontSize: 12.5,
                            height: 1.5,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF2D2D4E)))),
              ]),
            ),
          ),

        const SizedBox(height: 10),
        HelpHowToTranslateAction(
          stepsByLanguage:
              HelpCenterTranslations.howToSteps[userRole] ?? const {},
          summaryByLanguage:
              HelpCenterTranslations.howToRoleSummary[userRole] ?? const {},
          color: color,
          isDark: isDark,
        ),
      ]),
    );
  }
}

class _StepTile extends StatelessWidget {
  final int index;
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  const _StepTile(
      {required this.index,
      required this.icon,
      required this.label,
      required this.color,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withOpacity(isDark ? 0.15 : 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : const Color(0xFF2D2D4E),
                  height: 1.4)),
        ),
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text('$index',
                style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w800, color: color)),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FAQ / Quick Support Section
// ─────────────────────────────────────────────────────────────────────────────
class _FaqSection extends StatelessWidget {
  final bool isDark;
  final Color accent;
  final List<FaqItem> faqs;
  const _FaqSection(
      {required this.isDark, required this.accent, required this.faqs});

  @override
  Widget build(BuildContext context) {
    if (faqs.isEmpty) {
      return Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
              child: Text('No FAQs available.',
                  style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.grey))));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Column(
        children: faqs.map((faq) {
          return _FaqTile(
            key: ValueKey(faq.id),
            id: faq.id,
            question: faq.question,
            answer: faq.answer,
            accent: accent,
            isDark: isDark,
          );
        }).toList(),
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  final String id;
  final String question;
  final String answer;
  final Color accent;
  final bool isDark;
  const _FaqTile(
      {super.key,
      required this.id,
      required this.question,
      required this.answer,
      required this.accent,
      required this.isDark});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  late final AnimationController _ctrl;
  late final Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _expandAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    _open ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: widget.isDark
              ? Colors.white.withOpacity(0.05)
              : const Color(0xFFF8F9FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: _open
                  ? widget.accent.withOpacity(0.4)
                  : (widget.isDark ? Colors.white10 : const Color(0xFFE8EAFF)),
              width: 1.2),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Question row
          GestureDetector(
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
              child: Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _open
                        ? widget.accent.withOpacity(0.15)
                        : (widget.isDark
                            ? Colors.white.withOpacity(0.08)
                            : const Color(0xFFEEEEFF)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.quiz_rounded,
                      size: 14, color: _open ? widget.accent : Colors.grey),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(widget.question,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: _open
                              ? widget.accent
                              : (widget.isDark
                                  ? Colors.white
                                  : const Color(0xFF1A1A2E)))),
                ),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      color: _open ? widget.accent : Colors.grey, size: 20),
                ),
              ]),
            ),
          ),

          // Answer (animated)
          SizeTransition(
            sizeFactor: _expandAnim,
            axisAlignment: -1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(52, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.answer,
                      style: TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: widget.isDark
                              ? Colors.white60
                              : const Color(0xFF4A4A6A))),
                  const SizedBox(height: 8),
                  HelpFaqTranslateAction(
                    translations:
                        HelpCenterTranslations.faq[widget.id] ?? const {},
                    isDark: widget.isDark,
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Smart Features Section — role-aware, static explanations only (Phase 4).
// No navigation, no Firestore, no translation backend: each card's
// "Translate" action is the same static HelpTranslateAction used elsewhere
// in this screen, resolving one of the HelpCenterTranslations.smart* maps.
// ─────────────────────────────────────────────────────────────────────────────
class _SmartFeaturesSection extends StatelessWidget {
  final bool isDark;
  final UserRole userRole;
  const _SmartFeaturesSection({required this.isDark, required this.userRole});

  static const String _aiAssistantBody =
      'The AI Service Assistant helps you find the right service category '
      'and providers faster.\n\n'
      'With it, you can:\n'
      '• Describe your service problem in your own words\n'
      '• Get a suggested service category with a clear reason for that '
      'suggestion\n'
      '• Refine the result once by answering a few follow-up questions, '
      'when shown\n'
      '• Choose your provider preference: Both, Professional, or '
      'Contractor\n'
      '• Choose a location preference: Any location or Same city\n'
      '• Choose a budget preference: Any budget or a specific budget\n'
      '• Add optional additional notes about your request\n'
      '• See real matching providers based on your selected criteria\n'
      '• Open a suggested provider\'s profile to learn more\n'
      '• Continue to Create Service Request directly from a suggested '
      'provider\n\n'
      'The AI suggestion never creates or submits an order automatically. '
      'You always review the result, choose a provider, complete the '
      'request details, and submit it yourself.\n\n'
      'Suggestions may not always be perfect, so please verify the '
      'suggested category and provider before continuing.';

  static const String _translationBody =
      'San3a\'s app interface is currently English-only.\n\n'
      'Some supported content — such as certain user-generated or '
      'informational text — provides a Translate action. Where available, '
      'you can:\n'
      '• Choose Arabic or Hebrew for that content\n'
      '• Keep seeing the original English text at the same time\n'
      '• View the translated text in a separate section below it\n'
      '• Use Hide Translation to return to the original-only view\n\n'
      'Translation availability depends on the specific screen or content '
      '— not everything in the app has a Translate action. Using it never '
      'changes the app\'s overall interface language.';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Customer-only: AI Service Assistant is not shown to Professional
          // or Contractor, who cannot use this Customer-facing feature.
          if (userRole == UserRole.customer) ...[
            _SmartFeatureCard(
              icon: Icons.smart_toy_rounded,
              color: const Color(0xFF7C3AED),
              title: 'AI Service Assistant',
              body: _aiAssistantBody,
              translations: HelpCenterTranslations.smartAiAssistant,
              isDark: isDark,
            ),
            const SizedBox(height: 14),
          ],

          // Shown to every role that reaches this screen (Customer,
          // Professional, Contractor).
          _SmartFeatureCard(
            icon: Icons.translate_rounded,
            color: const Color(0xFF3B82F6),
            title: 'Content Translation',
            body: _translationBody,
            translations: HelpCenterTranslations.smartContentTranslation,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _SmartFeatureCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final Map<HelpTranslationLanguage, String> translations;
  final bool isDark;
  const _SmartFeatureCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.translations,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.1 : 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0A0A1A))),
              const SizedBox(height: 6),
              Text(body,
                  style: TextStyle(
                      fontSize: 12.5,
                      height: 1.6,
                      color:
                          isDark ? Colors.white70 : const Color(0xFF2D2D4E))),
              const SizedBox(height: 8),
              HelpTranslateAction(
                translations: translations,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ]),
    );
  }
}
