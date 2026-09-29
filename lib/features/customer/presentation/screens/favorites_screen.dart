import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/presentation/providers/app_providers.dart';
import '../../../../shared/models/models.dart';
import '../theme/customer_design.dart';
import '../widgets/customer_provider_card.dart';
import 'provider_profile_screen.dart';
import 'new_order_screen.dart';

// Fallback UserModel built from the favorite's denormalized fields, used when
// the live provider record isn't available yet (still loading) or was removed.
UserModel _stubProviderFromFavorite(FavoriteModel f) => UserModel(
      id: f.providerId,
      fullName: f.providerName,
      email: '',
      phone: '',
      city: '',
      role: f.providerRole == 'contractor'
          ? UserRole.contractor
          : UserRole.professional,
      avatar: f.providerImageUrl,
      specialty: f.providerCategory,
      specialties:
          f.providerCategory != null ? [f.providerCategory!] : const [],
    );

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final currentUser = ref.watch(authProvider);
    final favoritesAsync =
        ref.watch(customerFavoritesProvider(currentUser?.id ?? ''));
    final allProviders =
        ref.watch(featuredProvidersProvider).valueOrNull ?? const <UserModel>[];
    final favoriteCount = favoritesAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      backgroundColor: CustomerColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Premium AppBar ────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            backgroundColor: CustomerColors.primaryDark,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: const _NeoBackButtonWhite(),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: CustomerColors.primaryGradient,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(CustomerRadii.sheet),
                    bottomRight: Radius.circular(CustomerRadii.sheet),
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.bookmark_rounded,
                                  color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              l.get('favorites'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const Spacer(),
                            if (favoriteCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$favoriteCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
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

          favoritesAsync.when(
            loading: () => const SliverFillRemaining(
              child: CustomerLoadingIndicator(),
            ),
            error: (e, st) => SliverFillRemaining(
              child: CustomerEmptyState(
                icon: Icons.error_outline_rounded,
                title: l.get('something_went_wrong'),
              ),
            ),
            data: (favorites) {
              if (favorites.isEmpty) {
                return SliverFillRemaining(
                  child: CustomerEmptyState(
                    icon: Icons.bookmark_border_rounded,
                    title: l.get('no_favorites'),
                    subtitle: l.get('add_favorites_hint'),
                  ),
                );
              }

              // Local-only filter over the already-loaded favorites — no
              // Firestore query, no change to favoritesProvider/stored data.
              final resolved = favorites
                  .map((fav) =>
                      allProviders
                          .firstWhereOrNull((p) => p.id == fav.providerId) ??
                      _stubProviderFromFavorite(fav))
                  .toList();
              final query = _query.trim().toLowerCase();
              final filtered = query.isEmpty
                  ? resolved
                  : resolved.where((p) {
                      final roleLabel = p.role == UserRole.contractor
                          ? l.get('contractor')
                          : l.get('professional');
                      return p.fullName.toLowerCase().contains(query) ||
                          roleLabel.toLowerCase().contains(query) ||
                          p.city.toLowerCase().contains(query);
                    }).toList();

              return SliverMainAxisGroup(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                      child: _FavoritesSearchBar(
                        controller: _searchCtrl,
                        query: _query,
                        onChanged: (v) => setState(() => _query = v),
                        onClear: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      ),
                    ),
                  ),
                  if (filtered.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: CustomerEmptyState(
                        icon: Icons.search_off_rounded,
                        title: l.get('no_results'),
                        subtitle: l.get('try_another_search'),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final provider = filtered[i];
                          return CustomerProviderCard(
                            key: ValueKey(provider.id),
                            provider: provider,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ProviderProfileScreen(provider: provider),
                              ),
                            ),
                            onOrder: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    NewOrderScreen(provider: provider),
                              ),
                            ),
                          );
                        },
                        childCount: filtered.length,
                      ),
                    ),
                ],
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// ── Neo Back Button ───────────────────────────────────────────────────────────
class _NeoBackButtonWhite extends StatefulWidget {
  const _NeoBackButtonWhite();

  @override
  State<_NeoBackButtonWhite> createState() => _NeoBackButtonWhiteState();
}

class _NeoBackButtonWhiteState extends State<_NeoBackButtonWhite>
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

// ── Favorites search bar ────────────────────────────────────────────────────
// Local-only filter UI for the already-loaded favorites list — reuses the
// existing Customer input decoration token (customerInputDecoration) rather
// than introducing a new style system. No Firestore query is issued here.
class _FavoritesSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _FavoritesSearchBar({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CustomerRadii.md),
        boxShadow: CustomerShadows.soft,
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: CustomerColors.textPrimary,
        ),
        cursorColor: CustomerColors.primary,
        decoration: customerInputDecoration(
          hint: 'Search favorites...',
          prefixIcon: const Icon(Icons.search_rounded,
              color: CustomerColors.primaryDark),
          suffixIcon: query.isNotEmpty
              ? GestureDetector(
                  onTap: onClear,
                  child: const Icon(Icons.close_rounded,
                      color: CustomerColors.textSecondary, size: 19),
                )
              : null,
        ),
      ),
    );
  }
}
