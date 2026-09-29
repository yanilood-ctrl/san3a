// ─────────────────────────────────────────────────────────────────────────────
// Customer Provider Card — Customer-owned copy of the shared ProviderCard
// (lib/shared/widgets/shared_widgets.dart), restyled to the Customer UI Kit.
// The shared original is used elsewhere (kept byte-for-byte untouched); this
// copy exists so the Customer redesign never edits shared/core files. Same
// props, same Riverpod reads/writes, same callbacks — visuals only differ.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/shared_widgets.dart' show ProfileAvatarImage;
import '../../../auth/presentation/providers/app_providers.dart';
import '../theme/customer_design.dart';

class CustomerProviderCard extends ConsumerStatefulWidget {
  final UserModel provider;
  final VoidCallback? onTap;
  final VoidCallback? onOrder;

  const CustomerProviderCard({
    super.key,
    required this.provider,
    this.onTap,
    this.onOrder,
  });

  @override
  ConsumerState<CustomerProviderCard> createState() =>
      _CustomerProviderCardState();
}

class _CustomerProviderCardState extends ConsumerState<CustomerProviderCard>
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
            Transform.scale(scale: 1.0 - 0.015 * _ctrl.value, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: CustomerColors.card,
            borderRadius: BorderRadius.circular(CustomerRadii.card),
            border: Border.all(
              color: CustomerColors.primary.withOpacity(0.16),
              width: 1.2,
            ),
            boxShadow: _pressed
                ? const []
                : [
                    BoxShadow(
                      color: CustomerColors.primary.withOpacity(0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(CustomerRadii.card),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top accent bar — ties the card to the Customer blue
                // palette, echoing the accent-bar treatment on Order cards.
                Container(
                  height: 3,
                  decoration: const BoxDecoration(
                    gradient: CustomerColors.primaryGradient,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CustomerAvatar(
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
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: CustomerText.title.copyWith(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                  _CustomerLikeButton(
                                    isFav: isFav,
                                    onTap: currentUser == null
                                        ? () {}
                                        : () => toggleFavoriteInFirestore(
                                              customerId: currentUser.id,
                                              provider: widget.provider,
                                            ),
                                  ),
                                ]),
                                const SizedBox(height: 8),
                                Row(children: [
                                  _CustomerRolePill(
                                      role: widget.provider.role, l: l),
                                  const SizedBox(width: 8),
                                  _CustomerRatingBadge(
                                    rating: ref
                                        .watch(providerAverageRatingProvider(
                                            widget.provider.id))
                                        .average,
                                  ),
                                ]),
                                const SizedBox(height: 8),
                                _CustomerLocationChip(widget.provider.city),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (widget.provider.services.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Divider(height: 1, color: CustomerColors.divider),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: widget.provider.services
                              .take(3)
                              .map((s) => _CustomerServiceChip(s))
                              .toList(),
                        ),
                      ],
                      if (widget.onOrder != null) ...[
                        const SizedBox(height: 14),
                        _CustomerOrderButton(
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

class _CustomerAvatar extends StatelessWidget {
  final String name;
  final UserRole role;
  final String? imageUrl;
  const _CustomerAvatar(
      {required this.name, required this.role, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        gradient: CustomerColors.primaryGradient,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: CustomerColors.primary.withOpacity(0.30),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ProfileAvatarImage(
        imageUrl: imageUrl,
        size: 58,
        borderRadius: 15,
        fallbackText: name,
        fallbackTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 21,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}

class _CustomerLikeButton extends StatefulWidget {
  final bool isFav;
  final VoidCallback onTap;
  const _CustomerLikeButton({required this.isFav, required this.onTap});

  @override
  State<_CustomerLikeButton> createState() => _CustomerLikeButtonState();
}

class _CustomerLikeButtonState extends State<_CustomerLikeButton>
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
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: widget.isFav
                ? CustomerColors.lightBlueSection
                : CustomerColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isFav
                  ? CustomerColors.primary.withOpacity(0.35)
                  : CustomerColors.border,
              width: 1,
            ),
          ),
          child: Icon(
            widget.isFav
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            color: widget.isFav
                ? CustomerColors.primaryDark
                : CustomerColors.textSecondary,
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _CustomerRolePill extends StatelessWidget {
  final UserRole role;
  final AppLocalizations l;
  const _CustomerRolePill({required this.role, required this.l});

  @override
  Widget build(BuildContext context) {
    final isContractor = role == UserRole.contractor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: CustomerColors.lightBlueSection,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CustomerColors.primary.withOpacity(0.18)),
      ),
      child: Text(
        isContractor ? l.get('contractor') : l.get('professional'),
        style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: CustomerColors.primaryDark),
      ),
    );
  }
}

class _CustomerRatingBadge extends StatelessWidget {
  final double rating;
  const _CustomerRatingBadge({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFB800).withOpacity(0.25)),
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

class _CustomerLocationChip extends StatelessWidget {
  final String city;
  const _CustomerLocationChip(this.city);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: CustomerColors.lightBlueSection,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: CustomerColors.primary.withOpacity(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on_rounded,
              size: 13, color: CustomerColors.primaryDark),
          const SizedBox(width: 4),
          Text(
            city,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: CustomerColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerServiceChip extends StatelessWidget {
  final String label;
  const _CustomerServiceChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: customerChipDecoration(selected: false),
      child: Text(label, style: customerChipTextStyle(selected: false)),
    );
  }
}

class _CustomerOrderButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _CustomerOrderButton({required this.label, required this.onTap});

  @override
  State<_CustomerOrderButton> createState() => _CustomerOrderButtonState();
}

class _CustomerOrderButtonState extends State<_CustomerOrderButton>
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
            Transform.scale(scale: 1.0 - 0.02 * _ctrl.value, child: child),
        child: Container(
          width: double.infinity,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CustomerRadii.md),
            gradient: CustomerColors.primaryGradient,
            boxShadow: CustomerShadows.primaryButton,
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
