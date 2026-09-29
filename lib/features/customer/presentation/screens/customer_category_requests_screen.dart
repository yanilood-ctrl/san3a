import 'package:flutter/material.dart';
import '../../../../shared/widgets/category_requests_screen.dart';
import '../theme/customer_design.dart';

// ══════════════════════════════════════════════════════════════════════════════
// ── My Category Requests Screen (Customer) ────────────────────────────────────
// ══════════════════════════════════════════════════════════════════════════════
// Thin wrapper over the shared CategoryRequestsScreen (extracted verbatim from
// this screen's original body so Professional/Contractor can reuse the exact
// same tab/card/dots-menu behavior). Kept as its own class + file so the
// existing `const CustomerCategoryRequestsScreen()` call site in
// all_categories_screen.dart needs no changes.
class CustomerCategoryRequestsScreen extends StatelessWidget {
  // Set from a notification tap so the matching request opens automatically.
  final String? initialRequestId;
  const CustomerCategoryRequestsScreen({super.key, this.initialRequestId});

  @override
  Widget build(BuildContext context) => CategoryRequestsScreen(
        gradientStart: CustomerColors.primaryDark,
        gradientEnd: CustomerColors.primary,
        secondaryColor: CustomerColors.primary,
        scaffoldBackgroundColor: CustomerColors.background,
        initialRequestId: initialRequestId,
      );
}
