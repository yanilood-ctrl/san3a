import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/presentation/providers/app_providers.dart';
import '../../../../shared/utils/category_icon_helper.dart';
import '../theme/customer_design.dart';
import '../widgets/customer_provider_card.dart';
import 'provider_profile_screen.dart';

class CategoryProvidersScreen extends ConsumerWidget {
  final String categoryKey;
  final String categoryId;
  const CategoryProvidersScreen({
    super.key,
    required this.categoryKey,
    this.categoryId = '',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final providersAsync = ref.watch(
      categoryProvidersStreamProvider((categoryKey, categoryId)),
    );
    final providers = providersAsync.valueOrNull ?? [];
    final isLoading = providersAsync.isLoading && providers.isEmpty;
    // Only show error state when there is genuinely no data at all.
    final hasErrorWithNoData = providersAsync.hasError && providers.isEmpty;
    if (providersAsync.hasError) {
      debugPrint('[CategoryProviders] stream error: ${providersAsync.error}');
    }

    // Resolve the icon the same way category cards do: look up the live
    // Firestore category (covers categories added via admin approval, not
    // just the seeded constant list) and map it through the shared helper.
    final allCats = ref.watch(categoriesProvider).value ?? [];
    final catModel = allCats.firstWhereOrNull(
      (c) => c.id == categoryId || c.nameKey == categoryKey,
    );
    final catIcon = categoryIconFor(
      id: catModel?.id ?? categoryId,
      nameKey: catModel?.nameKey ?? categoryKey,
      icon: catModel?.icon,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF0F6FF),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Premium SliverAppBar ──────────────────────────────────────
          SliverAppBar(
            expandedHeight: 150,
            pinned: true,
            backgroundColor: CustomerColors.dark,
            foregroundColor: Colors.white,
            elevation: 0,
            automaticallyImplyLeading: false,
            leading: const _NeoBackButton(),
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
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // ── 3D Category icon ──────────────────────
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.30),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.10),
                                    blurRadius: 6,
                                    offset: const Offset(0, -2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(catIcon,
                                    color: Colors.white, size: 28),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // ── Title + count badge ───────────────────
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l.get(categoryKey),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // ── Professionals count badge ─────────
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.30),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.people_rounded,
                                            color: Colors.white, size: 14),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${providers.length} Professional${providers.length != 1 ? 's' : ''}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Content ───────────────────────────────────────────────────
          if (isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: CustomerColors.dark),
              ),
            )
          else if (hasErrorWithNoData)
            const SliverFillRemaining(
              child: Center(
                child: Text(
                  'Could not load providers. Please check your connection.',
                  style: TextStyle(fontSize: 14, color: CustomerColors.mid),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else if (providers.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: CustomerColors.lightest,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Center(
                        child:
                            Icon(catIcon, color: CustomerColors.dark, size: 42),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No professionals in this category',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: CustomerColors.darkest,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Check back later!',
                        style:
                            TextStyle(fontSize: 13, color: CustomerColors.mid)),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => CustomerProviderCard(
                  key: ValueKey(providers[i].id),
                  provider: providers[i],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProviderProfileScreen(
                        provider: providers[i],
                        categoryId: categoryId,
                        categoryNameKey: categoryKey,
                      ),
                    ),
                  ),
                ),
                childCount: providers.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// ── Neo Back Button ───────────────────────────────────────────────────────────
class _NeoBackButton extends StatefulWidget {
  const _NeoBackButton();
  @override
  State<_NeoBackButton> createState() => _NeoBackButtonState();
}

class _NeoBackButtonState extends State<_NeoBackButton>
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
