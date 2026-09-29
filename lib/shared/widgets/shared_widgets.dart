import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/models.dart';
import '../../core/localization/app_localizations.dart';
import '../../features/auth/presentation/providers/app_providers.dart';

// ── Blue Gradient Color Palette ──────────────────────────────────────────────
class AppBlue {
  static const darkest = Color(0xFF021024);
  static const dark = Color(0xFF052659);
  static const mid = Color(0xFF5483B3);
  static const light = Color(0xFF7DA0CA);
  static const lightest = Color(0xFFC1E8FF);
}

// ─── App Text Field ───────────────────────────────────────────────────────────
class AppTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscureText;
  final Widget? prefix;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  final VoidCallback? onTap;
  final bool readOnly;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.obscureText = false,
    this.prefix,
    this.suffix,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
    this.onTap,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onTap: onTap,
          readOnly: readOnly,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
          decoration: InputDecoration(
              hintText: hint, prefixIcon: prefix, suffixIcon: suffix),
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}

// ─── Profile Avatar Content ────────────────────────────────────────────────────
// Drop-in replacement for the "first letter ↔ saved photo" ternary that used
// to be inline at every avatar call site. Callers keep their own frame
// (Container size/gradient/border/shadow/shape) and only swap in this widget
// as the content — see UserModel.avatar (models.dart) for the single shared
// source of truth this reads from. Renders, in order: fallback letter (no/
// empty URL) → network image (fit: cover, clipped to [borderRadius] or a
// circle) → fallback letter again on load error, so a broken/expired URL
// never surfaces Flutter's default broken-image icon.
class ProfileAvatarImage extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final String fallbackText;
  final TextStyle fallbackTextStyle;
  final double? borderRadius; // null = circle

  const ProfileAvatarImage({
    super.key,
    required this.imageUrl,
    required this.size,
    required this.fallbackText,
    required this.fallbackTextStyle,
    this.borderRadius,
  });

  Widget _fallback() {
    final trimmed = fallbackText.trim();
    return Center(
      child: Text(
        trimmed.isNotEmpty ? trimmed[0].toUpperCase() : '?',
        style: fallbackTextStyle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) return _fallback();

    final image = Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _fallback(),
      errorBuilder: (context, error, stack) => _fallback(),
    );

    return borderRadius == null
        ? ClipOval(child: image)
        : ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius!), child: image);
  }
}

// ─── Provider Card — 3D Neomorphism Premium ───────────────────────────────────
class ProviderCard extends ConsumerStatefulWidget {
  final UserModel provider;
  final VoidCallback? onTap;
  final VoidCallback? onOrder;

  const ProviderCard({
    super.key,
    required this.provider,
    this.onTap,
    this.onOrder,
  });

  @override
  ConsumerState<ProviderCard> createState() => _ProviderCardState();
}

class _ProviderCardState extends ConsumerState<ProviderCard>
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final currentUser = ref.watch(authProvider);
    final isFav = currentUser == null
        ? false
        : ref
                .watch(isFavoriteProvider((currentUser.id, widget.provider.id)))
                .valueOrNull ??
            false;

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
        _ctrl.forward();
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        _ctrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () {
        setState(() => _pressed = false);
        _ctrl.reverse();
      },
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) =>
            Transform.scale(scale: 1.0 - 0.02 * _ctrl.value, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            // Subtle white card
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: _pressed
                ? [
                    BoxShadow(
                        color: AppBlue.mid.withOpacity(0.12),
                        blurRadius: 4,
                        offset: const Offset(1, 2)),
                  ]
                : [
                    // 3D layered shadow system
                    BoxShadow(
                        color: AppBlue.darkest.withOpacity(0.12),
                        blurRadius: 0,
                        offset: const Offset(0, 4)),
                    BoxShadow(
                        color: AppBlue.dark.withOpacity(0.10),
                        blurRadius: 16,
                        offset: const Offset(0, 8)),
                    BoxShadow(
                        color: Colors.white.withOpacity(0.90),
                        blurRadius: 4,
                        offset: const Offset(0, -1)),
                  ],
            border:
                Border.all(color: AppBlue.lightest.withOpacity(0.8), width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // ── Top accent bar ─────────────────────────────────────
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 4,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppBlue.darkest, AppBlue.mid, AppBlue.light],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),
                // ── Card content ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Avatar 3D
                          _Premium3DAvatar(
                              name: widget.provider.fullName,
                              role: widget.provider.role,
                              imageUrl: widget.provider.avatar),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Expanded(
                                    child: Text(
                                      widget.provider.fullName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        color: AppBlue.darkest,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                  ),
                                  // Neo Like Button
                                  _NeoLikeButton(
                                    isFav: isFav,
                                    onTap: currentUser == null
                                        ? () {}
                                        : () => toggleFavoriteInFirestore(
                                              customerId: currentUser.id,
                                              provider: widget.provider,
                                            ),
                                  ),
                                ]),
                                const SizedBox(height: 7),
                                Row(children: [
                                  _3DRolePill(role: widget.provider.role, l: l),
                                  const SizedBox(width: 8),
                                  _3DRatingBadge(
                                    rating: ref
                                        .watch(providerAverageRatingProvider(
                                            widget.provider.id))
                                        .average,
                                  ),
                                ]),
                                const SizedBox(height: 6),
                                Row(children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppBlue.lightest,
                                      boxShadow: const [
                                        BoxShadow(
                                            color: AppBlue.light,
                                            blurRadius: 2,
                                            offset: Offset(0, 1)),
                                      ],
                                    ),
                                    child: const Icon(Icons.location_on_rounded,
                                        size: 10, color: AppBlue.dark),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    widget.provider.city,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppBlue.mid,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ]),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (widget.provider.services.isNotEmpty) ...[
                        const SizedBox(height: 13),
                        // Divider
                        Container(
                          height: 1,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.transparent,
                              AppBlue.lightest,
                              Colors.transparent,
                            ]),
                          ),
                        ),
                        const SizedBox(height: 11),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: widget.provider.services
                              .take(3)
                              .map((s) => _3DServiceChip(s))
                              .toList(),
                        ),
                      ],
                      if (widget.onOrder != null) ...[
                        const SizedBox(height: 14),
                        _Neo3DOrderButton(
                            label: l.get('new_order'), onTap: widget.onOrder!),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 3D Avatar ─────────────────────────────────────────────────────────────────
class _Premium3DAvatar extends StatelessWidget {
  final String name;
  final UserRole role;
  final String? imageUrl;
  const _Premium3DAvatar(
      {required this.name, required this.role, this.imageUrl});

  List<Color> get _colors {
    switch (role) {
      case UserRole.contractor:
        return [const Color(0xFF1A3A6B), const Color(0xFF5483B3)];
      case UserRole.professional:
        return [const Color(0xFF052659), const Color(0xFF7DA0CA)];
      default:
        return [AppBlue.dark, AppBlue.mid];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: _colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          // 3D bottom shadow
          BoxShadow(
              color: _colors[0].withOpacity(0.50),
              blurRadius: 0,
              offset: const Offset(0, 4)),
          BoxShadow(
              color: _colors[0].withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 6)),
          // Top highlight
          BoxShadow(
              color: Colors.white.withOpacity(0.20),
              blurRadius: 4,
              offset: const Offset(0, -2)),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
      ),
      child: Stack(
        children: [
          // Shine
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 28,
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(17)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withOpacity(0.20), Colors.transparent],
                ),
              ),
            ),
          ),
          ProfileAvatarImage(
            imageUrl: imageUrl,
            size: 58,
            borderRadius: 18,
            fallbackText: name,
            fallbackTextStyle: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Neo Like Button (neomorphism square) ──────────────────────────────────────
class _NeoLikeButton extends StatefulWidget {
  final bool isFav;
  final VoidCallback onTap;
  const _NeoLikeButton({required this.isFav, required this.onTap});

  @override
  State<_NeoLikeButton> createState() => _NeoLikeButtonState();
}

class _NeoLikeButtonState extends State<_NeoLikeButton>
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFEEEEF5),
            borderRadius: BorderRadius.circular(12),
            boxShadow: widget.isFav
                ? [
                    BoxShadow(
                        color: AppBlue.dark.withOpacity(0.30),
                        blurRadius: 0,
                        offset: const Offset(0, 3)),
                    BoxShadow(
                        color: AppBlue.dark.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 4)),
                  ]
                : const [
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
          child: Icon(
            widget.isFav
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            color: widget.isFav ? AppBlue.dark : const Color(0xFFAAAAAA),
            size: 18,
          ),
        ),
      ),
    );
  }
}

// ── 3D Role Pill ──────────────────────────────────────────────────────────────
class _3DRolePill extends StatelessWidget {
  final UserRole role;
  final AppLocalizations l;
  const _3DRolePill({required this.role, required this.l});

  @override
  Widget build(BuildContext context) {
    final isContractor = role == UserRole.contractor;
    final color = isContractor ? AppBlue.dark : AppBlue.mid;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.18), color.withOpacity(0.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.30), width: 1),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 0,
              offset: const Offset(0, 2)),
          BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 4,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Text(
        isContractor ? l.get('contractor') : l.get('professional'),
        style:
            TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

// ── 3D Rating Badge ───────────────────────────────────────────────────────────
class _3DRatingBadge extends StatelessWidget {
  final double rating;
  const _3DRatingBadge({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: const Color(0xFFFFD54F).withOpacity(0.5), width: 1),
        boxShadow: const [
          BoxShadow(
              color: Color(0xFFFFB800), blurRadius: 0, offset: Offset(0, 2)),
          BoxShadow(
              color: Color(0x22FFB800), blurRadius: 6, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFFB800)),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF8A6200)),
          ),
        ],
      ),
    );
  }
}

// ── 3D Service Chip ───────────────────────────────────────────────────────────
class _3DServiceChip extends StatelessWidget {
  final String label;
  const _3DServiceChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: AppBlue.lightest.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppBlue.light.withOpacity(0.35), width: 1),
        boxShadow: const [
          BoxShadow(color: AppBlue.light, blurRadius: 0, offset: Offset(0, 2)),
          BoxShadow(
              color: Color(0x22C1E8FF), blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: AppBlue.dark),
      ),
    );
  }
}

// ── Neo 3D Order Button ───────────────────────────────────────────────────────
class _Neo3DOrderButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _Neo3DOrderButton({required this.label, required this.onTap});

  @override
  State<_Neo3DOrderButton> createState() => _Neo3DOrderButtonState();
}

class _Neo3DOrderButtonState extends State<_Neo3DOrderButton>
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
            Transform.scale(scale: 1.0 - 0.03 * _ctrl.value, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          width: double.infinity,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(23),
            gradient: const LinearGradient(
              colors: [AppBlue.darkest, AppBlue.dark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: _pressed
                ? [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 4,
                        offset: const Offset(1, 2))
                  ]
                : [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.45),
                        blurRadius: 0,
                        offset: const Offset(0, 4)),
                    BoxShadow(
                        color: AppBlue.darkest.withOpacity(0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 8)),
                    BoxShadow(
                        color: Colors.white.withOpacity(0.10),
                        blurRadius: 3,
                        offset: const Offset(0, -1)),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_circle_outline_rounded,
                  size: 16, color: Colors.white),
              const SizedBox(width: 7),
              Text(
                widget.label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Order Status Badge ───────────────────────────────────────────────────────
class OrderStatusBadge extends StatelessWidget {
  final OrderStatus status;
  final AppLocalizations l;
  const OrderStatusBadge({super.key, required this.status, required this.l});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    String text;
    switch (status) {
      case OrderStatus.pending:
        bg = const Color(0xFFFFF3CD);
        fg = const Color(0xFFB45309);
        text = l.get('pending');
        break;
      case OrderStatus.inProgress:
        bg = AppBlue.lightest;
        fg = AppBlue.dark;
        text = l.get('in_progress');
        break;
      case OrderStatus.completed:
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF065F46);
        text = l.get('completed');
        break;
      case OrderStatus.cancelled:
        bg = const Color(0xFFFFE4E6);
        fg = AppColors.error;
        text = l.get('cancelled');
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style:
              TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg)),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onMore;
  final String? moreLabel;

  const SectionHeader(
      {super.key, required this.title, this.onMore, this.moreLabel});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppBlue.dark, AppBlue.mid],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppBlue.darkest,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        if (onMore != null)
          GestureDetector(
            onTap: onMore,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppBlue.dark.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppBlue.mid.withOpacity(0.2)),
              ),
              child: Text(
                moreLabel ?? '',
                style: const TextStyle(
                  color: AppBlue.dark,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Uber Stat Card ───────────────────────────────────────────────────────────
class UberStatCard extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;

  const UberStatCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0D1B2E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppBlue.dark.withOpacity(0.10),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDark ? AppBlue.dark.withOpacity(0.35) : AppBlue.lightest,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.15), color.withOpacity(0.08)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 10),
            Text(value,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? AppBlue.light : AppBlue.mid,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Theme Toggle Button ──────────────────────────────────────────────────────
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
