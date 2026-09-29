// ── Selected Services Sheet ───────────────────────────────────────────────────
// Read-only bottom sheet listing every service selected on an order (San3a
// multi-service orders), shared by Customer/Professional/Contractor Order
// Details so this isn't duplicated three times. Falls back to the legacy
// single-service fields (selectedServiceName/selectedServicePrice) for orders
// created before OrderModel.selectedServices existed — never invents a
// description or category for that legacy fallback.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../../core/localization/app_localizations.dart';
import '../../features/auth/presentation/providers/app_providers.dart'
    show categoriesProvider;

/// Whether the Services row should be tappable at all: either a new
/// multi-service snapshot exists, or a legacy single-service name is present.
/// When both are absent (order has no service info at all) the caller should
/// keep the Services row hidden, exactly as before.
bool orderHasSelectedServicesDetail(OrderModel order) =>
    order.selectedServices.isNotEmpty ||
    (order.selectedServiceName?.trim().isNotEmpty ?? false);

/// Compact one-line summary for the closed Services row, e.g. "AC Inspection
/// and Diagnosis +1 more". Prefers the stored summary (selectedServiceName,
/// already written in this short form at order creation) and only derives
/// one from selectedServices as a defensive fallback for the case where a
/// service snapshot exists without a stored summary name.
String orderSelectedServicesSummary(OrderModel order) {
  final stored = order.selectedServiceName?.trim() ?? '';
  if (stored.isNotEmpty) return stored;
  final services = order.selectedServices;
  if (services.isEmpty) return '';
  if (services.length == 1) return services.first.name;
  return '${services.first.name} +${services.length - 1} more';
}

Future<void> showSelectedServicesSheet({
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
    builder: (_) => SelectedServicesSheet(
      order: order,
      accent: accent,
      surfaceColor: surfaceColor,
      shadowTint: shadowTint,
    ),
  );
}

class SelectedServicesSheet extends ConsumerWidget {
  final OrderModel order;
  final Color accent;
  final Color surfaceColor;
  final Color shadowTint;
  const SelectedServicesSheet({
    super.key,
    required this.order,
    required this.accent,
    required this.surfaceColor,
    required this.shadowTint,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    // Watched once here (not per service item) and resolved by id — no new
    // provider/Firestore query, matching the categoriesProvider already used
    // elsewhere in the app.
    final categoriesById = {
      for (final c in ref.watch(categoriesProvider).valueOrNull ??
          const <CategoryModel>[])
        c.id: c
    };

    final services = order.selectedServices;
    final hasSnapshot = services.isNotEmpty;
    final legacyName = order.selectedServiceName?.trim() ?? '';
    final showLegacy = !hasSnapshot && legacyName.isNotEmpty;

    final total = order.selectedServicePrice ??
        (hasSnapshot
            ? services.fold<double>(0, (sum, s) => sum + s.price)
            : null);

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
              const SizedBox(height: 22),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.build_circle_outlined, size: 19, color: accent),
                const SizedBox(width: 8),
                const Text('Selected Services',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF333355),
                        letterSpacing: -0.3)),
              ]),
              const SizedBox(height: 20),
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
                    if (hasSnapshot)
                      for (var i = 0; i < services.length; i++) ...[
                        if (i > 0) _SheetDivider(shadowTint: shadowTint),
                        _ServiceDetailItem(
                          service: services[i],
                          category: categoriesById[services[i].categoryId],
                          accent: accent,
                          l: l,
                        ),
                      ]
                    else if (showLegacy)
                      _LegacyServiceDetailItem(
                        name: legacyName,
                        price: order.selectedServicePrice,
                        accent: accent,
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      accent,
                      Color.lerp(accent, Colors.black, 0.3)!
                    ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(children: [
                    const Text('Total Price',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    const Spacer(),
                    Text(total != null ? '₪${total.toStringAsFixed(0)}' : '—',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)),
                  ]),
                ),
              ),
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _SheetCloseButton(
                    accent: accent, onTap: () => Navigator.pop(context)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// One selected service's read-only detail: name + price, an optional live
// category badge, then the description.
class _ServiceDetailItem extends StatelessWidget {
  final ServiceModel service;
  final CategoryModel? category;
  final Color accent;
  final AppLocalizations l;
  const _ServiceDetailItem({
    required this.service,
    required this.category,
    required this.accent,
    required this.l,
  });

  @override
  Widget build(BuildContext context) {
    final cat = category;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Text(service.name,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF333355)))),
          const SizedBox(width: 8),
          Text('₪${service.price.toStringAsFixed(0)}',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: accent)),
        ]),
        if (cat != null) ...[
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (cat.icon.trim().isNotEmpty) ...[
              Text(cat.icon.trim(), style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(l.get(cat.nameKey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: accent)),
            ),
          ]),
        ],
        if (service.description.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(service.description,
              style: const TextStyle(
                  fontSize: 12.5, color: Color(0xFF7777AA), height: 1.4)),
        ],
      ]),
    );
  }
}

// Legacy single-service fallback: name + price only, verbatim from the order
// — never split, and never given an invented description or category.
class _LegacyServiceDetailItem extends StatelessWidget {
  final String name;
  final double? price;
  final Color accent;
  const _LegacyServiceDetailItem({
    required this.name,
    required this.price,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          Expanded(
              child: Text(name,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF333355)))),
          const SizedBox(width: 8),
          Text(price != null ? '₪${price!.toStringAsFixed(0)}' : '—',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: accent)),
        ]),
      );
}

class _SheetDivider extends StatelessWidget {
  final Color shadowTint;
  const _SheetDivider({required this.shadowTint});
  @override
  Widget build(BuildContext context) => Divider(
      color: shadowTint.withOpacity(0.15),
      height: 1,
      indent: 16,
      endIndent: 16);
}

class _SheetCloseButton extends StatelessWidget {
  final Color accent;
  final VoidCallback onTap;
  const _SheetCloseButton({required this.accent, required this.onTap});
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
