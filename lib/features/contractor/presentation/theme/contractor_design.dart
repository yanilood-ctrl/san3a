// ─────────────────────────────────────────────────────────────────────────────
// Contractor UI Kit — shared presentation-only design tokens for the
// Contractor role's screens. Colors, radii, shadows and reusable style
// builders ONLY — no business logic, no state, no navigation. Deliberately
// scoped under features/contractor so it never touches the global AppTheme
// (core/theme/app_theme.dart), which is also used by the Customer/Professional/
// Admin/Auth screens. Mirrors the shape of professional_design.dart /
// customer_design.dart — same token names, same radii, same shadow language,
// same helper signatures — with the Contractor's own orange/gold identity.
//
// ── Brand palette ───────────────────────────────────────────────────────────
// Primary orange  #DC7D4E  (ContractorColors.brandOrange / .primary / .mid)
// Light gold      #FFDD8D  (ContractorColors.brandGold  / .light)
// Brand gradient  #DC7D4E → #FFDD8D, topLeft → bottomRight
//                 (ContractorColors.brandGradient / .primaryGradient)
//
// Everything else here is a shade derived from those two: the deep end
// (darkest/dark/primaryDark) for text and for surfaces that carry white
// foregrounds, and the light end (lightest/warm/background) for page and
// section fills. No unrelated dominant hue is introduced — the only
// non-orange colors below are the semantic status colors (success/warning/
// error), which deliberately stay green/amber/red because they carry meaning.
//
// ── Foreground contrast rule ────────────────────────────────────────────────
// #FFDD8D is a light gold: white text or white icons on it are unreadable.
// So anything painted with [brandGradient] must use [onBrand] / [onBrandMuted]
// (deep warm ink) for its text and icons, never Colors.white. Surfaces that
// keep white foregrounds — small icon tiles, avatars, filled pills — use the
// deep [darkest] → [dark] pair instead, which stays dark across its whole
// ramp. Both are provided so each surface can pick the readable one.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../../../../core/theme/chat_theme.dart';

// A contractor-owned instance of the existing (untouched) ChatTheme data
// class — reuses its shape without editing lib/core/theme/chat_theme.dart.
// Pass this instead of ChatTheme.contractor everywhere a Contractor chat
// surface needs a theme, so the shared ChatTheme.contractor (still used by
// other roles, e.g. a Customer's own inbox showing a Contractor conversation)
// stays exactly as it is today.
//
// bubbleSent carries white message text, so it uses the deep end of the ramp
// rather than the brand orange.
const ChatTheme contractorChatTheme = ChatTheme(
  primary: Color(0xFFDC7D4E),
  primaryDark: Color(0xFF8F4620),
  primaryLight: Color(0xFFFFF3DC),
  bubbleSent: Color(0xFFA85428),
  bubbleReceived: Color(0xFFFDF1E2),
  headerBg: Color(0xFFA85428),
  inputBorder: Color(0xFFDC7D4E),
  searchBg: Color(0xFFFDF1E2),
  unreadBadge: Color(0xFFDC7D4E),
  avatarGradientStart: Color(0xFF7A3E1E),
  avatarGradientEnd: Color(0xFFA85428),
  bgPage: Color(0xFFFDF8F1),
);

class ContractorColors {
  ContractorColors._();

  // ── The two brand colors ─────────────────────────────────────────────────
  /// Primary orange — the Contractor role's signature color.
  static const brandOrange = Color(0xFFDC7D4E);

  /// Light gold — the bright end of the Contractor gradient.
  static const brandGold = Color(0xFFFFDD8D);

  // ── Core roles ───────────────────────────────────────────────────────────
  static const primary = brandOrange; // #DC7D4E
  static const primaryDark = Color(0xFF8F4620); // deep burnt orange
  static const secondary = Color(0xFFA85428);
  static const medium = brandOrange;
  static const accent = Color(0xFFF2A65A); // warm amber — focus rings
  static const background = Color(0xFFFDF8F1); // warm page background
  static const card = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF2B1B12); // warm near-black
  static const textSecondary = Color(0xFF8A7263); // warm gray
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);

  static const border = Color(0xFFE8D5BF);
  static const divider = Color(0xFFF0E2D2);

  // ── Foreground ink for [brandGradient] surfaces ──────────────────────────
  // White fails against #FFDD8D, so gradient headers use these instead.
  // onBrand on #DC7D4E ≈ 4.6:1, on #FFDD8D ≈ 11:1 — readable across the
  // whole ramp.
  static const onBrand = Color(0xFF3D1D0C);
  static const onBrandMuted = Color(0xFF6B3A1E);

  // AppBrown-shaped aliases (lib/features/contractor/presentation/screens/
  // contractor_home_screen.dart), also mirrored by _CB in
  // contractor_order_detail_screen.dart and _Brown in
  // contractor_suppliers_screen.dart. Ordered darkest → lightest. The
  // darkest/dark pair is the "white foreground is safe" end of the ramp and
  // is what every small gradient icon tile and avatar uses.
  static const darkest = Color(0xFF7A3E1E);
  static const dark = secondary; // 0xFFA85428
  static const mid = brandOrange; // 0xFFDC7D4E
  static const light = brandGold; // 0xFFFFDD8D
  static const lightest = Color(0xFFFFF7E6); // pale gold tint
  static const warm = Color(0xFFFDF6EC); // warmest section fill
  static const surface = card;
  static const surfaceCard = card;
  static const titleText = textPrimary;
  static const secondaryText = textSecondary;
  static const hintText = textSecondary;

  /// The Contractor brand gradient: #DC7D4E → #FFDD8D.
  /// Paint text/icons on top of it with [onBrand] / [onBrandMuted].
  static const brandGradient = LinearGradient(
    colors: [brandOrange, brandGold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Same gradient under the name the rest of the app already imports.
  static const primaryGradient = brandGradient;

  /// Deep variant for surfaces that keep white text/icons (small icon tiles,
  /// avatars, filled badges) where the gold end of [brandGradient] would be
  /// too light to read against.
  static const deepGradient = LinearGradient(
    colors: [darkest, dark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class ContractorRadii {
  ContractorRadii._();

  static const sm = 12.0;
  static const md = 16.0;
  static const card = 20.0;
  static const lg = 22.0;
  static const sheet = 24.0;
  static const pill = 999.0;
}

class ContractorShadows {
  ContractorShadows._();

  static const List<BoxShadow> soft = [
    BoxShadow(color: Color(0x147A3E1E), blurRadius: 20, offset: Offset(0, 8)),
  ];

  static const List<BoxShadow> raised = [
    BoxShadow(color: Color(0x1E7A3E1E), blurRadius: 28, offset: Offset(0, 12)),
  ];

  static const List<BoxShadow> primaryButton = [
    BoxShadow(color: Color(0x40DC7D4E), blurRadius: 18, offset: Offset(0, 8)),
  ];
}

class ContractorText {
  ContractorText._();

  static const TextStyle headline = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: ContractorColors.textPrimary,
    letterSpacing: -0.3,
  );

  static const TextStyle title = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: ContractorColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w500,
    color: ContractorColors.textPrimary,
    height: 1.4,
  );

  static const TextStyle secondary = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: ContractorColors.textSecondary,
    height: 1.35,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    color: ContractorColors.textSecondary,
  );
}

BoxDecoration contractorCardDecoration({
  double radius = ContractorRadii.card,
  Color color = ContractorColors.card,
  List<BoxShadow>? shadow,
  Color? borderColor,
}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borderColor ?? ContractorColors.border, width: 1),
    boxShadow: shadow ?? ContractorShadows.soft,
  );
}

BoxDecoration contractorSectionDecoration(
    {double radius = ContractorRadii.card}) {
  return BoxDecoration(
    color: ContractorColors.warm,
    borderRadius: BorderRadius.circular(radius),
  );
}

ButtonStyle contractorPrimaryButtonStyle({double radius = ContractorRadii.md}) {
  return ElevatedButton.styleFrom(
    // primaryDark rather than primary: this is a flat fill under white text,
    // and #DC7D4E is too light for a white label to read comfortably.
    backgroundColor: ContractorColors.primaryDark,
    foregroundColor: Colors.white,
    elevation: 0,
    shadowColor: Colors.transparent,
    minimumSize: const Size(double.infinity, 54),
    padding: const EdgeInsets.symmetric(horizontal: 20),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
  );
}

ButtonStyle contractorSecondaryButtonStyle(
    {double radius = ContractorRadii.md}) {
  return OutlinedButton.styleFrom(
    foregroundColor: ContractorColors.primaryDark,
    backgroundColor: ContractorColors.warm,
    side: BorderSide.none,
    minimumSize: const Size(double.infinity, 54),
    padding: const EdgeInsets.symmetric(horizontal: 20),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
  );
}

InputDecoration contractorInputDecoration({
  required String hint,
  Widget? prefixIcon,
  Widget? suffixIcon,
  String? label,
}) {
  const border = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(ContractorRadii.md)),
    borderSide: BorderSide(color: ContractorColors.border, width: 1.3),
  );
  return InputDecoration(
    hintText: hint,
    labelText: label,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: ContractorColors.card,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    hintStyle: ContractorText.secondary,
    labelStyle: ContractorText.secondary,
    border: border,
    enabledBorder: border,
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(ContractorRadii.md)),
      borderSide: BorderSide(color: ContractorColors.primary, width: 1.8),
    ),
    errorBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(ContractorRadii.md)),
      borderSide: BorderSide(color: ContractorColors.error, width: 1.3),
    ),
    focusedErrorBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(ContractorRadii.md)),
      borderSide: BorderSide(color: ContractorColors.error, width: 1.8),
    ),
  );
}

BoxDecoration contractorChipDecoration({required bool selected}) {
  return BoxDecoration(
    color: selected ? ContractorColors.primary : ContractorColors.warm,
    borderRadius: BorderRadius.circular(ContractorRadii.pill),
  );
}

TextStyle contractorChipTextStyle({required bool selected}) {
  return TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    // Deep ink on a #DC7D4E chip — white would sit at roughly 3:1 here.
    color: selected ? ContractorColors.onBrand : ContractorColors.primaryDark,
  );
}

class ContractorEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const ContractorEmptyState({
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
                color: ContractorColors.lightest,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: ContractorColors.primaryDark),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: ContractorText.title, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!,
                  style: ContractorText.secondary, textAlign: TextAlign.center),
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

class ContractorLoadingIndicator extends StatelessWidget {
  final double size;
  const ContractorLoadingIndicator({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: const CircularProgressIndicator(
          strokeWidth: 2.6,
          valueColor: AlwaysStoppedAnimation<Color>(ContractorColors.primary),
        ),
      ),
    );
  }
}
