// ─────────────────────────────────────────────────────────────────────────────
// Professional UI Kit — shared presentation-only design tokens for the
// Professional role's screens. Colors, radii, shadows and reusable style
// builders ONLY — no business logic, no state, no navigation. Deliberately
// scoped under features/professional so it never touches the global AppTheme
// (core/theme/app_theme.dart), which is also used by the Customer/Contractor/
// Admin/Auth screens.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../../../../core/theme/chat_theme.dart';

// A professional-owned instance of the existing (untouched) ChatTheme data
// class — reuses its shape without editing lib/core/theme/chat_theme.dart.
// Pass this instead of ChatTheme.professional everywhere a Professional chat
// surface needs a theme.
const ChatTheme professionalChatTheme = ChatTheme(
  primary: Color(0xFF14B8A6),
  primaryDark: Color(0xFF0F766E),
  primaryLight: Color(0xFFCCFBF1),
  bubbleSent: Color(0xFF0F766E),
  bubbleReceived: Color(0xFFF0FDFA),
  headerBg: Color(0xFF0F766E),
  inputBorder: Color(0xFF14B8A6),
  searchBg: Color(0xFFF0FDFA),
  unreadBadge: Color(0xFF0F766E),
  avatarGradientStart: Color(0xFF0F766E),
  avatarGradientEnd: Color(0xFF14B8A6),
  bgPage: Color(0xFFECFEFF),
);

class ProfessionalColors {
  ProfessionalColors._();

  static const primary = Color(0xFF14B8A6);
  static const primaryDark = Color(0xFF0F766E);
  static const primaryLight = Color(0xFF5EEAD4);
  static const accent = Color(0xFF2DD4BF);
  static const background = Color(0xFFECFEFF);
  static const card = Color(0xFFF0FDFA);
  static const textPrimary = Color(0xFF1F2937);
  static const textSecondary = Color(0xFF6B7280);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);

  static const border = Color(0xFF5EEAD4);
  static const divider = Color(0xFFE0F7F3);

  // AppGreen-shaped aliases (lib/core/theme/app_theme.dart), used when
  // migrating a screen off the shared AppGreen palette one-for-one without
  // hand-mapping every call site.
  static const darkest = primaryDark;
  static const dark = primary;
  static const midDark = Color(0xFF0D9488);
  static const mid = primary;
  static const light = Color(0xFF99F6E4);
  static const lightest = background;
  static const surface = card;
  static const surfaceCard = card;
  static const titleText = textPrimary;
  static const secondaryText = textSecondary;
  static const hintText = primaryLight;

  static const primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class ProfessionalRadii {
  ProfessionalRadii._();

  static const sm = 12.0;
  static const md = 16.0;
  static const card = 20.0;
  static const lg = 22.0;
  static const sheet = 24.0;
  static const pill = 999.0;
}

class ProfessionalShadows {
  ProfessionalShadows._();

  static const List<BoxShadow> soft = [
    BoxShadow(color: Color(0x0F0F766E), blurRadius: 20, offset: Offset(0, 8)),
  ];

  static const List<BoxShadow> raised = [
    BoxShadow(color: Color(0x140F766E), blurRadius: 28, offset: Offset(0, 12)),
  ];

  static const List<BoxShadow> primaryButton = [
    BoxShadow(color: Color(0x4014B8A6), blurRadius: 18, offset: Offset(0, 8)),
  ];
}

class ProfessionalText {
  ProfessionalText._();

  static const TextStyle headline = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: ProfessionalColors.textPrimary,
    letterSpacing: -0.3,
  );

  static const TextStyle title = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: ProfessionalColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w500,
    color: ProfessionalColors.textPrimary,
    height: 1.4,
  );

  static const TextStyle secondary = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: ProfessionalColors.textSecondary,
    height: 1.35,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    color: ProfessionalColors.textSecondary,
  );
}

BoxDecoration professionalCardDecoration({
  double radius = ProfessionalRadii.card,
  Color color = ProfessionalColors.card,
  List<BoxShadow>? shadow,
  Color? borderColor,
}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borderColor ?? ProfessionalColors.border.withOpacity(0.4), width: 1),
    boxShadow: shadow ?? ProfessionalShadows.soft,
  );
}

BoxDecoration professionalSectionDecoration({double radius = ProfessionalRadii.card}) {
  return BoxDecoration(
    color: ProfessionalColors.background,
    borderRadius: BorderRadius.circular(radius),
  );
}

ButtonStyle professionalPrimaryButtonStyle({double radius = ProfessionalRadii.md}) {
  return ElevatedButton.styleFrom(
    backgroundColor: ProfessionalColors.primary,
    foregroundColor: Colors.white,
    elevation: 0,
    shadowColor: Colors.transparent,
    minimumSize: const Size(double.infinity, 54),
    padding: const EdgeInsets.symmetric(horizontal: 20),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
  );
}

ButtonStyle professionalSecondaryButtonStyle({double radius = ProfessionalRadii.md}) {
  return OutlinedButton.styleFrom(
    foregroundColor: ProfessionalColors.primaryDark,
    backgroundColor: ProfessionalColors.card,
    side: BorderSide.none,
    minimumSize: const Size(double.infinity, 54),
    padding: const EdgeInsets.symmetric(horizontal: 20),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
  );
}

InputDecoration professionalInputDecoration({
  required String hint,
  Widget? prefixIcon,
  Widget? suffixIcon,
  String? label,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(ProfessionalRadii.md),
    borderSide: BorderSide(color: ProfessionalColors.border.withOpacity(0.5), width: 1.3),
  );
  return InputDecoration(
    hintText: hint,
    labelText: label,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: ProfessionalColors.card,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    hintStyle: ProfessionalText.secondary,
    labelStyle: ProfessionalText.secondary,
    border: border,
    enabledBorder: border,
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(ProfessionalRadii.md)),
      borderSide: BorderSide(color: ProfessionalColors.primary, width: 1.8),
    ),
    errorBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(ProfessionalRadii.md)),
      borderSide: BorderSide(color: ProfessionalColors.error, width: 1.3),
    ),
    focusedErrorBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(ProfessionalRadii.md)),
      borderSide: BorderSide(color: ProfessionalColors.error, width: 1.8),
    ),
  );
}

BoxDecoration professionalChipDecoration({required bool selected}) {
  return BoxDecoration(
    color: selected ? ProfessionalColors.primary : ProfessionalColors.background,
    borderRadius: BorderRadius.circular(ProfessionalRadii.pill),
  );
}

TextStyle professionalChipTextStyle({required bool selected}) {
  return TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: selected ? Colors.white : ProfessionalColors.primaryDark,
  );
}

class ProfessionalEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const ProfessionalEmptyState({
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
                color: ProfessionalColors.background,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: ProfessionalColors.primaryDark),
            ),
            const SizedBox(height: 20),
            Text(title, style: ProfessionalText.title, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!,
                  style: ProfessionalText.secondary, textAlign: TextAlign.center),
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

class ProfessionalLoadingIndicator extends StatelessWidget {
  final double size;
  const ProfessionalLoadingIndicator({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: const CircularProgressIndicator(
          strokeWidth: 2.6,
          valueColor: AlwaysStoppedAnimation<Color>(ProfessionalColors.primary),
        ),
      ),
    );
  }
}
