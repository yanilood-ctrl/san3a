// ── Rich Customer Details Sheet ───────────────────────────────────────────────
// Shared by Professional and Contractor Order Details when the Customer
// avatar/card is tapped. Looks the Customer up live by their stable Firestore
// UID (order.customerId) via userByIdProvider so it shows the Customer's real
// profile (name/email/phone/address/languages/etc.) instead of just the
// name/area/status copied onto the order at creation time.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../../features/auth/presentation/providers/app_providers.dart';
import '../helpers/phone_call_helper.dart';
import 'shared_widgets.dart';

Future<void> showCustomerDetailsSheet({
  required BuildContext context,
  required OrderModel order,
  required Color accent,
  required Color surfaceColor,
  required Color shadowTint,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CustomerDetailsSheet(
      order: order,
      accent: accent,
      surfaceColor: surfaceColor,
      shadowTint: shadowTint,
    ),
  );
}

class CustomerDetailsSheet extends ConsumerWidget {
  final OrderModel order;
  final Color accent;
  final Color surfaceColor;
  final Color shadowTint;
  const CustomerDetailsSheet({
    super.key,
    required this.order,
    required this.accent,
    required this.surfaceColor,
    required this.shadowTint,
  });

  String _statusLabel(OrderStatus s) {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = order.customerId.isNotEmpty
        ? ref.watch(userByIdProvider(order.customerId))
        : const AsyncValue<UserModel?>.data(null);
    final user = userAsync.valueOrNull;
    final isLoading = userAsync.isLoading && !userAsync.hasValue;
    final hasError = userAsync.hasError;
    final missingUser =
        !isLoading && !hasError && order.customerId.isNotEmpty && user == null;

    final name = (user?.fullName.isNotEmpty ?? false)
        ? user!.fullName
        : (order.customerName.isNotEmpty ? order.customerName : 'Customer');

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.86),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(36),
          boxShadow: [
            BoxShadow(
                color: shadowTint.withOpacity(0.3),
                blurRadius: 24,
                offset: const Offset(10, 10)),
            const BoxShadow(
                color: Colors.white, blurRadius: 24, offset: Offset(-10, -10)),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 14),
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                      color: shadowTint.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(3)),
                ),
              ),
              const SizedBox(height: 28),

              // ── Avatar (real photo when available, else initial letter)
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [accent, accent.withOpacity(0.6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                        color: accent.withOpacity(0.45),
                        blurRadius: 18,
                        offset: const Offset(0, 8)),
                    BoxShadow(
                        color: shadowTint.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(5, 5)),
                    const BoxShadow(
                        color: Colors.white,
                        blurRadius: 12,
                        offset: Offset(-5, -5)),
                  ],
                ),
                child: ProfileAvatarImage(
                  imageUrl: user?.avatar,
                  size: 88,
                  borderRadius: 28,
                  fallbackText: name,
                  fallbackTextStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 18),

              Text(name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF333355),
                      letterSpacing: -0.5)),
              const SizedBox(height: 6),

              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: shadowTint.withOpacity(0.25),
                        blurRadius: 4,
                        offset: const Offset(3, 3)),
                    const BoxShadow(
                        color: Colors.white,
                        blurRadius: 4,
                        offset: Offset(-3, -3)),
                  ],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.person_rounded, size: 13, color: accent),
                  const SizedBox(width: 5),
                  Text('Customer',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: accent)),
                ]),
              ),
              const SizedBox(height: 24),

              // ── Live Customer profile state ──────────────────────────────
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: CircularProgressIndicator(),
                )
              else if (hasError)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SheetMessage(
                    icon: Icons.error_outline_rounded,
                    color: const Color(0xFFEF4444),
                    text: 'Could not load customer details. Please try again.',
                  ),
                )
              else if (missingUser)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SheetMessage(
                    icon: Icons.info_outline_rounded,
                    color: accent,
                    text: 'Full customer profile is unavailable.',
                  ),
                )
              else if (user != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: shadowTint.withOpacity(0.25),
                            blurRadius: 8,
                            offset: const Offset(4, 4)),
                        const BoxShadow(
                            color: Colors.white,
                            blurRadius: 8,
                            offset: Offset(-4, -4)),
                      ],
                    ),
                    child: Column(children: [
                      _InfoRow(
                          icon: Icons.email_rounded,
                          label: 'Email',
                          value: user.email.isNotEmpty ? user.email : '—',
                          accent: accent,
                          shadowTint: shadowTint),
                      _RowDivider(shadowTint: shadowTint),
                      _InfoRow(
                          icon: Icons.phone_rounded,
                          label: 'Phone',
                          value: user.phone.isNotEmpty ? user.phone : '—',
                          accent: accent,
                          shadowTint: shadowTint,
                          trailing: _CallIconButton(
                              phone: user.phone, accent: accent)),
                      _RowDivider(shadowTint: shadowTint),
                      _InfoRow(
                          icon: Icons.location_on_rounded,
                          label: 'Address',
                          value: user.fullAddress.isNotEmpty
                              ? user.fullAddress
                              : '—',
                          accent: accent,
                          shadowTint: shadowTint,
                          wrap: true),
                      _RowDivider(shadowTint: shadowTint),
                      _InfoRow(
                          icon: Icons.language_rounded,
                          label: 'Languages',
                          value: user.languages.isNotEmpty
                              ? user.languages.join(' · ')
                              : '—',
                          accent: accent,
                          shadowTint: shadowTint,
                          wrap: true),
                      _RowDivider(shadowTint: shadowTint),
                      _InfoRow(
                          icon: Icons.access_time_rounded,
                          label: 'Best Contact Hours',
                          value: user.preferredContactHours.isNotEmpty
                              ? user.preferredContactHours.join(' · ')
                              : '—',
                          accent: accent,
                          shadowTint: shadowTint,
                          wrap: true),
                      _RowDivider(shadowTint: shadowTint),
                      _InfoRow(
                          icon: Icons.star_rounded,
                          label: 'Favorite Services',
                          value: user.favoriteServices.isNotEmpty
                              ? user.favoriteServices.join(' · ')
                              : '—',
                          accent: accent,
                          shadowTint: shadowTint,
                          wrap: true),
                      _RowDivider(shadowTint: shadowTint),
                      _InfoRow(
                          icon: Icons.calendar_today_rounded,
                          label: 'Member Since',
                          value:
                              '${user.joinDate.day}/${user.joinDate.month}/${user.joinDate.year}',
                          accent: accent,
                          shadowTint: shadowTint),
                    ]),
                  ),
                ),
              const SizedBox(height: 20),

              // ── Order context (always available — copied at order time,
              // independent of whether the live Customer doc loaded) ────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: shadowTint.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(4, 4)),
                      const BoxShadow(
                          color: Colors.white,
                          blurRadius: 8,
                          offset: Offset(-4, -4)),
                    ],
                  ),
                  child: Column(children: [
                    _InfoRow(
                        icon: Icons.receipt_long_rounded,
                        label: 'Order',
                        value: order.title,
                        accent: accent,
                        shadowTint: shadowTint,
                        wrap: true),
                    _RowDivider(shadowTint: shadowTint),
                    _InfoRow(
                        icon: Icons.location_on_outlined,
                        label: 'City / Area',
                        value: order.area.isNotEmpty ? order.area : '—',
                        accent: accent,
                        shadowTint: shadowTint),
                    _RowDivider(shadowTint: shadowTint),
                    _InfoRow(
                        icon: Icons.circle_rounded,
                        label: 'Status',
                        value: _statusLabel(order.status),
                        accent: accent,
                        shadowTint: shadowTint,
                        valueColor: accent),
                  ]),
                ),
              ),
              const SizedBox(height: 28),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _CloseButton(
                    accent: accent, onTap: () => Navigator.pop(context)),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetMessage extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _SheetMessage(
      {required this.icon, required this.color, required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: TextStyle(fontSize: 12.5, color: color, height: 1.5))),
        ]),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color accent;
  final Color shadowTint;
  final Color? valueColor;
  // When true, the value wraps onto its own line below the label instead of
  // being squeezed/ellipsized to the right — used for fields that can hold
  // several joined items (address, languages, favorite services, ...).
  final bool wrap;
  final Widget? trailing;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.shadowTint,
    this.valueColor,
    this.wrap = false,
    this.trailing,
  });

  Widget _iconBadge() => Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.35),
          boxShadow: [
            BoxShadow(
                color: shadowTint.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(2, 2)),
            const BoxShadow(
                color: Colors.white, blurRadius: 4, offset: Offset(-2, -2)),
          ]),
      child: Icon(icon, size: 14, color: const Color(0xFF7777AA)));

  @override
  Widget build(BuildContext context) {
    if (wrap) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _iconBadge(),
            const SizedBox(width: 12),
            Text(label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF7777AA))),
          ]),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 44),
            child: Text(value,
                softWrap: true,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: valueColor ?? const Color(0xFF333355))),
          ),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(children: [
        _iconBadge(),
        const SizedBox(width: 12),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF7777AA))),
        const Spacer(),
        Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: valueColor ?? const Color(0xFF333355)),
                overflow: TextOverflow.ellipsis)),
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
class _CallIconButton extends StatelessWidget {
  final String phone;
  final Color accent;
  const _CallIconButton({required this.phone, required this.accent});

  @override
  Widget build(BuildContext context) {
    if (normalizedTelNumber(phone) == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => launchPhoneCall(context, phone),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: accent.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.call_rounded, size: 15, color: accent),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  final Color shadowTint;
  const _RowDivider({required this.shadowTint});
  @override
  Widget build(BuildContext context) => Divider(
      color: shadowTint.withOpacity(0.15),
      height: 1,
      indent: 16,
      endIndent: 16);
}

class _CloseButton extends StatelessWidget {
  final Color accent;
  final VoidCallback onTap;
  const _CloseButton({required this.accent, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: LinearGradient(
                colors: [accent, Color.lerp(accent, Colors.black, 0.3)!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
          ),
          child: const Center(
              child: Text('Close',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800))),
        ),
      );
}
