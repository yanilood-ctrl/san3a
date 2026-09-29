// ─────────────────────────────────────────────────────────────────────────────
// Customer UI Kit — shared presentation-only design tokens for the Customer
// role's screens. Colors, radii, shadows and reusable style builders ONLY —
// no business logic, no state, no navigation. Deliberately scoped under
// features/customer so it never touches the global AppTheme (core/theme/
// app_theme.dart), which is also used by the Professional/Contractor/Admin/
// Auth screens.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../../../../core/theme/chat_theme.dart';

// A customer-owned instance of the existing (untouched) ChatTheme data class
// — reuses its shape without editing lib/core/theme/chat_theme.dart. Pass
// this instead of ChatTheme.customer everywhere a Customer chat surface
// needs a theme.
const ChatTheme customerChatTheme = ChatTheme(
  primary: Color(0xFF5EA9F7),
  primaryDark: Color(0xFF3E8DE8),
  primaryLight: Color(0xFFEAF4FF),
  bubbleSent: Color(0xFF3E8DE8),
  bubbleReceived: Color(0xFFEAF4FF),
  headerBg: Color(0xFF3E8DE8),
  inputBorder: Color(0xFF5EA9F7),
  searchBg: Color(0xFFEAF4FF),
  unreadBadge: Color(0xFF3E8DE8),
  avatarGradientStart: Color(0xFF3E8DE8),
  avatarGradientEnd: Color(0xFF5EA9F7),
  bgPage: Color(0xFFF6F9FC),
);

class CustomerColors {
  CustomerColors._();

  static const primary = Color(0xFF5EA9F7);
  static const primaryDark = Color(0xFF3E8DE8);
  static const background = Color(0xFFF6F9FC);
  static const card = Color(0xFFFFFFFF);
  static const lightBlueSection = Color(0xFFEAF4FF);
  static const textPrimary = Color(0xFF1F2937);
  static const textSecondary = Color(0xFF6B7280);
  static const success = Color(0xFF2ECC71);
  static const warning = Color(0xFFF39C12);
  static const error = Color(0xFFE74C3C);

  static const border = Color(0xFFE3ECF6);
  static const divider = Color(0xFFEDF2F7);

  // AppBlue-shaped 5-step gradient aliases (darkest → lightest), used when
  // migrating a screen off the shared AppBlue palette (lib/shared/widgets/
  // shared_widgets.dart) one-for-one without hand-mapping every call site.
  static const darkest = primaryDark;
  static const dark = primary;
  static const mid = Color(0xFF7DBBF9);
  static const light = Color(0xFFB3D9FB);
  static const lightest = lightBlueSection;

  static const primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class CustomerRadii {
  CustomerRadii._();

  static const sm = 12.0;
  static const md = 16.0;
  static const card = 20.0;
  static const lg = 22.0;
  static const sheet = 24.0;
  static const pill = 999.0;
}

class CustomerShadows {
  CustomerShadows._();

  /// Soft, low-elevation shadow for resting cards/tiles.
  static const List<BoxShadow> soft = [
    BoxShadow(color: Color(0x0F1F2937), blurRadius: 20, offset: Offset(0, 8)),
  ];

  /// Slightly stronger shadow for raised/floating surfaces (bottom nav,
  /// floating buttons, sheets' drag handle bar area).
  static const List<BoxShadow> raised = [
    BoxShadow(color: Color(0x141F2937), blurRadius: 28, offset: Offset(0, 12)),
  ];

  /// Tinted shadow for the primary CTA button.
  static const List<BoxShadow> primaryButton = [
    BoxShadow(color: Color(0x405EA9F7), blurRadius: 18, offset: Offset(0, 8)),
  ];
}

class CustomerText {
  CustomerText._();

  static const TextStyle headline = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: CustomerColors.textPrimary,
    letterSpacing: -0.3,
  );

  static const TextStyle title = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: CustomerColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w500,
    color: CustomerColors.textPrimary,
    height: 1.4,
  );

  static const TextStyle secondary = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: CustomerColors.textSecondary,
    height: 1.35,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    color: CustomerColors.textSecondary,
  );
}

/// Card container decoration — white surface, rounded corners, soft shadow,
/// hairline border. Use as the outer `BoxDecoration` for content cards.
BoxDecoration customerCardDecoration({
  double radius = CustomerRadii.card,
  Color color = CustomerColors.card,
  List<BoxShadow>? shadow,
  Color? borderColor,
}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borderColor ?? CustomerColors.border, width: 1),
    boxShadow: shadow ?? CustomerShadows.soft,
  );
}

/// Tinted "light blue section" decoration for callouts/banners.
BoxDecoration customerSectionDecoration({double radius = CustomerRadii.card}) {
  return BoxDecoration(
    color: CustomerColors.lightBlueSection,
    borderRadius: BorderRadius.circular(radius),
  );
}

/// Premium filled primary button style — gradient look is applied by
/// wrapping in a `Container` with [CustomerColors.primaryGradient] where a
/// full gradient button is wanted; this flat style covers the common case.
ButtonStyle customerPrimaryButtonStyle({double radius = CustomerRadii.md}) {
  return ElevatedButton.styleFrom(
    backgroundColor: CustomerColors.primary,
    foregroundColor: Colors.white,
    elevation: 0,
    shadowColor: Colors.transparent,
    minimumSize: const Size(double.infinity, 54),
    padding: const EdgeInsets.symmetric(horizontal: 20),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
  );
}

ButtonStyle customerSecondaryButtonStyle({double radius = CustomerRadii.md}) {
  return OutlinedButton.styleFrom(
    foregroundColor: CustomerColors.primaryDark,
    backgroundColor: CustomerColors.lightBlueSection,
    side: BorderSide.none,
    minimumSize: const Size(double.infinity, 54),
    padding: const EdgeInsets.symmetric(horizontal: 20),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
  );
}

InputDecoration customerInputDecoration({
  required String hint,
  Widget? prefixIcon,
  Widget? suffixIcon,
  String? label,
}) {
  const border = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(CustomerRadii.md)),
    borderSide: BorderSide(color: CustomerColors.border, width: 1.3),
  );
  return InputDecoration(
    hintText: hint,
    labelText: label,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: CustomerColors.card,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    hintStyle: CustomerText.secondary,
    labelStyle: CustomerText.secondary,
    border: border,
    enabledBorder: border,
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(CustomerRadii.md)),
      borderSide: BorderSide(color: CustomerColors.primary, width: 1.8),
    ),
    errorBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(CustomerRadii.md)),
      borderSide: BorderSide(color: CustomerColors.error, width: 1.3),
    ),
    focusedErrorBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(CustomerRadii.md)),
      borderSide: BorderSide(color: CustomerColors.error, width: 1.8),
    ),
  );
}

/// Consistent chip decoration for filter/category chips.
BoxDecoration customerChipDecoration({required bool selected}) {
  return BoxDecoration(
    color: selected ? CustomerColors.primary : CustomerColors.lightBlueSection,
    borderRadius: BorderRadius.circular(CustomerRadii.pill),
  );
}

TextStyle customerChipTextStyle({required bool selected}) {
  return TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: selected ? Colors.white : CustomerColors.primaryDark,
  );
}

/// Standard empty-state layout: icon in a tinted circle, title, optional
/// subtitle. Purely presentational — callers keep owning what triggers it.
class CustomerEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const CustomerEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: CustomerColors.lightBlueSection,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: CustomerColors.primaryDark),
            ),
            const SizedBox(height: 20),
            Text(title, style: CustomerText.title, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!,
                  style: CustomerText.secondary, textAlign: TextAlign.center),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Standard loading indicator — subtle, on-brand.
class CustomerLoadingIndicator extends StatelessWidget {
  final double size;
  const CustomerLoadingIndicator({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: const CircularProgressIndicator(
          strokeWidth: 2.6,
          valueColor: AlwaysStoppedAnimation<Color>(CustomerColors.primary),
        ),
      ),
    );
  }
}
