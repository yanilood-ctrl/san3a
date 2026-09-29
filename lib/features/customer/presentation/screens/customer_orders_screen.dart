import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/presentation/providers/app_providers.dart';
import '../../../../shared/helpers/image_source_picker.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/shared_widgets.dart' show ProfileAvatarImage;
import '../../../../shared/widgets/selected_services_sheet.dart';
import '../theme/customer_design.dart';
import 'provider_profile_screen.dart';

// Same external-launch behavior already used by ProfessionalOrderDetailScreen
// and ContractorOrderDetailScreen: no-op on a blank area, never throws.
Future<void> _openMapsForArea(BuildContext context, String area) async {
  if (area.trim().isEmpty) return;
  final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(area)}');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// Same short-summary/description format already used by New Order's
// multi-service selection (see new_order_screen.dart), reproduced here for
// Edit Order's own service-selection state.
String _editServicesSummary(List<ServiceModel> services) {
  if (services.isEmpty) return '';
  if (services.length == 1) return services.first.name;
  return '${services.first.name} +${services.length - 1} more';
}

String _editServicesDescription(List<ServiceModel> services) =>
    services.map((s) => '${s.name}: ${s.description}').join('\n');

// Writes the ordersLastSeenAt marker only if at least one current order is
// actually unseen by it — an idempotent, no-op-when-nothing-changed guard so
// the listeners above can fire on every rebuild/snapshot without causing
// repeated Firestore writes once the Customer has caught up.
void _maybeMarkOrdersSeen(WidgetRef ref, List<OrderModel> orders) {
  final user = ref.read(authProvider);
  if (user == null || orders.isEmpty) return;
  final lastSeen = ref.read(customerOrdersLastSeenProvider).valueOrNull;
  final hasUnseen = lastSeen == null
      ? true
      : orders.any((o) => o.createdAt.isAfter(lastSeen));
  if (!hasUnseen) return;
  markCustomerOrdersSeenInFirestore(user.id).catchError((e) {
    debugPrint('ORDERS_SEEN_MARK_ERROR: $e');
  });
}

class CustomerOrdersScreen extends ConsumerWidget {
  const CustomerOrdersScreen({super.key});

  void _showGlobalComplaint(BuildContext context, WidgetRef ref) {
    final orders = ref.read(customerFirestoreOrdersProvider).valueOrNull ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderComplaintSheet(orders: orders),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final ordersAsync = ref.watch(customerFirestoreOrdersProvider);
    final List<OrderModel> orders = ordersAsync.valueOrNull ?? [];
    final bool isLoading = ordersAsync.isLoading && orders.isEmpty;
    final bool hasError = ordersAsync.hasError && orders.isEmpty;

    // Mark the bottom-nav Orders badge as "seen" — but only while this tab
    // is genuinely the one the Customer is looking at, never merely because
    // this widget got built. CustomerHomeScreen keeps every tab alive inside
    // an IndexedStack, so CustomerOrdersScreen.build runs at app startup
    // regardless of which tab is selected; relying on build() alone would
    // clear the badge before the Customer ever opened Orders. Two listeners
    // cover both orderings of "tab opened" vs. "data loaded":
    //  A) the Orders tab becomes active and data is already loaded, and
    //  B) data loads/changes while the Orders tab is already active
    //     (including a new order arriving live while the page is open).
    // Both funnel into _maybeMarkOrdersSeen, which only writes when there is
    // something actually unseen, so repeated rebuilds/snapshots don't cause
    // repeated writes.
    ref.listen<int>(navIndexProvider, (previous, next) {
      if (next != 2) return;
      final loadedOrders =
          ref.read(customerFirestoreOrdersProvider).valueOrNull;
      if (loadedOrders == null) return;
      _maybeMarkOrdersSeen(ref, loadedOrders);
    });
    ref.listen<AsyncValue<List<OrderModel>>>(customerFirestoreOrdersProvider,
        (previous, next) {
      final loadedOrders = next.valueOrNull;
      if (loadedOrders == null) return;
      if (ref.read(navIndexProvider) != 2) return;
      _maybeMarkOrdersSeen(ref, loadedOrders);
    });

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F6FF),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              expandedHeight: 130,
              floating: false,
              pinned: true,
              elevation: 0,
              backgroundColor: const Color(0xFF0A1F4E),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    // Same gradient language as the Customer Home header
                    // (see CustomerFeedScreen's "Premium Dark Header").
                    gradient: LinearGradient(
                      colors: [
                        CustomerColors.darkest,
                        Color(0xFF0A1F4E),
                        CustomerColors.dark,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: [0.0, 0.5, 1.0],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: Color(0x40021024),
                          blurRadius: 24,
                          offset: Offset(0, 10)),
                    ],
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.receipt_long_rounded,
                                  color: Colors.white, size: 22),
                              const SizedBox(width: 10),
                              Text(
                                l.get('orders'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              _OrdersThreeDotsMenu(
                                onComplaint: () =>
                                    _showGlobalComplaint(context, ref),
                                completedOrders: orders
                                    .where((o) =>
                                        o.status == OrderStatus.completed)
                                    .toList(),
                                cancelledOrders: orders
                                    .where((o) =>
                                        o.status == OrderStatus.cancelled)
                                    .toList(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${orders.length} ${l.get("orders")} • ${orders.where((o) => o.status == OrderStatus.inProgress || o.status == OrderStatus.pending).length} ${l.get("in_progress")}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // ── Status tabs — outside/below the dark header, floating on the
            // light page background, matching the My Complaints layout
            // (SliverAppBar ends, then a padded SliverToBoxAdapter tab bar,
            // then a spacer sliver before the list content).
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: _OrderStepperBar(
                  allCount: orders.length,
                  pendingCount: orders
                      .where((o) => o.status == OrderStatus.pending)
                      .length,
                  inProgressCount: orders
                      .where((o) => o.status == OrderStatus.inProgress)
                      .length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
          body: isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF052659)))
              : hasError
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.wifi_off_rounded,
                                size: 48, color: CustomerColors.mid),
                            const SizedBox(height: 12),
                            const Text(
                              'Could not load orders.\nPlease check your connection.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 14,
                                  color: CustomerColors.mid,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    )
                  : TabBarView(
                      children: [
                        _OrdersList(orders: orders, l: l),
                        _OrdersList(
                            orders: orders
                                .where((o) => o.status == OrderStatus.pending)
                                .toList(),
                            l: l),
                        _OrdersList(
                            orders: orders
                                .where(
                                    (o) => o.status == OrderStatus.inProgress)
                                .toList(),
                            l: l),
                      ],
                    ),
        ),
      ),
    );
  }
}

class _OrdersList extends StatelessWidget {
  final List<OrderModel> orders;
  final AppLocalizations l;
  const _OrdersList({required this.orders, required this.l});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFD6EEFF), Color(0xFFC1E8FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: CustomerColors.mid.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 6))
              ],
            ),
            child: const Icon(Icons.receipt_long_outlined,
                size: 48, color: CustomerColors.mid),
          ),
          const SizedBox(height: 18),
          Text(l.get('no_orders'),
              style: const TextStyle(
                  color: CustomerColors.dark,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(l.get('no_orders_section'),
              style: TextStyle(
                  color: CustomerColors.mid.withOpacity(0.7), fontSize: 13)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: orders.length,
      itemBuilder: (context, i) => _OrderCard(order: orders[i], l: l),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  final OrderModel order;
  final AppLocalizations l;
  const _OrderCard({required this.order, required this.l});

  // Show order photo full-screen with tap-to-dismiss. Shared by both the
  // in-memory (just-picked, same session) and already-uploaded (Storage URL)
  // cases so the dialog chrome only exists once.
  void _showFullPhotoWidget(BuildContext context, Widget image) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Stack(children: [
              Center(
                child:
                    InteractiveViewer(minScale: 1, maxScale: 4, child: image),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _showFullPhoto(BuildContext context, Uint8List bytes) =>
      _showFullPhotoWidget(context, Image.memory(bytes, fit: BoxFit.contain));

  void _showFullPhotoUrl(BuildContext context, String url) =>
      _showFullPhotoWidget(context, Image.network(url, fit: BoxFit.contain));

  // ── Photo options sheet ─────────────────────────────────────────────────────
  // Separate from Edit Order. Handles View / Add / Change / Add Another.
  // imageUrls is the only persisted image field (photoBytes/photoPath are
  // local-only and never round-trip through Firestore), so "has a photo" and
  // "view" must both key off imageUrls, not just the in-session photoBytes.
  // Reuses the exact same ImagePicker + Storage path convention + upload
  // order (Storage first, then Firestore) as order creation in
  // new_order_screen.dart — no second upload system.
  void _showPhotoOptionsSheet(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final hasPhoto = order.photoBytes != null || order.imageUrls.isNotEmpty;
    bool isUploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          Future<void> pickAndSave({required bool append}) async {
            if (isUploading) return;
            // Camera or gallery — identical compression, upload path and
            // Firestore write for both, so a freshly taken photo behaves
            // exactly like a chosen one.
            final picked = await pickImageWithSourceChoice(
              context: ctx,
              accent: CustomerColors.dark,
              title: 'Order Photo',
              imageQuality: 70,
              maxWidth: 1280,
              maxHeight: 1280,
              onError: (e) {
                debugPrint('ORDER_PHOTO_PICK_ERROR: $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Could not pick image. Check permissions.'),
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              },
            );
            if (picked == null) return; // user cancelled — no changes

            setSheetState(() => isUploading = true);
            try {
              final bytes = await picked.readAsBytes();
              final now = DateTime.now();
              // Phase 6B2: {customerUid} segment is order.customerId — this
              // screen only ever shows orders already scoped to the signed-in
              // customer (see customerFirestoreOrdersProvider's
              // customerId == user.id query), so order.customerId here is
              // always the real authenticated caller's own uid.
              final storageRef = FirebaseStorage.instance.ref().child(
                  'orders/${order.customerId}/${order.id}/images/img_${now.millisecondsSinceEpoch}.jpg');
              await storageRef.putData(
                bytes,
                SettableMetadata(contentType: 'image/jpeg'),
              );
              final url = await storageRef.getDownloadURL();

              final notifier = ref.read(ordersProvider.notifier);
              if (append) {
                await notifier.appendOrderImageInFirestore(
                    orderId: order.id, imageUrl: url);
              } else {
                await notifier.replaceOrderImageInFirestore(
                    orderId: order.id, imageUrl: url);
              }

              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Row(children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Photo updated successfully'),
                  ]),
                  backgroundColor: CustomerColors.dark,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ));
              }
            } catch (e) {
              debugPrint('ORDER_PHOTO_UPDATE_ERROR: $e');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Row(children: [
                    Icon(Icons.error_outline, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                        child:
                            Text('Failed to update photo. Please try again.')),
                  ]),
                  backgroundColor: CustomerColors.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ));
              }
              setSheetState(() => isUploading = false);
            }
          }

          Future<void> removePhoto() async {
            if (isUploading) return;
            final urls = order.imageUrls;
            if (urls.isEmpty) return;
            Navigator.pop(ctx);
            if (urls.length == 1) {
              if (context.mounted) {
                await _confirmAndRemoveImage(context, ref, order, urls.first);
              }
            } else {
              if (context.mounted) {
                final selected = await _showImageSelectionSheet(context, urls);
                if (selected != null && context.mounted) {
                  await _confirmAndRemoveImage(context, ref, order, selected);
                }
              }
            }
          }

          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              child: SingleChildScrollView(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEEEF5),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0xFFBEBECF),
                          blurRadius: 20,
                          offset: Offset(8, 8)),
                      BoxShadow(
                          color: Colors.white,
                          blurRadius: 20,
                          offset: Offset(-8, -8)),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                          child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFBEBECF),
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.white,
                                blurRadius: 2,
                                offset: Offset(-1, -1)),
                            BoxShadow(
                                color: Color(0xFFBEBECF),
                                blurRadius: 2,
                                offset: Offset(1, 1)),
                          ],
                        ),
                      )),
                      const SizedBox(height: 20),
                      Row(children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFEEEEF5),
                            boxShadow: [
                              BoxShadow(
                                  color: Color(0xFFBEBECF),
                                  blurRadius: 8,
                                  offset: Offset(4, 4)),
                              BoxShadow(
                                  color: Colors.white,
                                  blurRadius: 8,
                                  offset: Offset(-4, -4)),
                            ],
                          ),
                          child: const Icon(Icons.image_outlined,
                              color: Color(0xFF5555AA), size: 22),
                        ),
                        const SizedBox(width: 14),
                        Text(l.get('order_photo'),
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF333355))),
                      ]),
                      const SizedBox(height: 20),
                      if (isUploading) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Center(
                            child: SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Color(0xFF5555AA)),
                            ),
                          ),
                        ),
                      ] else if (hasPhoto) ...[
                        _NeoPhotoTile(
                            icon: Icons.visibility_outlined,
                            label: order.imageUrls.length > 1
                                ? 'View Photos (${order.imageUrls.length})'
                                : l.get('view_photo'),
                            color: const Color(0xFF5555AA),
                            onTap: () {
                              Navigator.pop(ctx);
                              final b = order.photoBytes;
                              if (b != null) {
                                _showFullPhoto(context, b);
                              } else if (order.imageUrls.length > 1) {
                                _showFullPhotoGallery(context, order.imageUrls);
                              } else if (order.imageUrls.isNotEmpty) {
                                _showFullPhotoUrl(
                                    context, order.imageUrls.first);
                              }
                            }),
                        const SizedBox(height: 10),
                        _NeoPhotoTile(
                            icon: Icons.swap_horiz_rounded,
                            label: l.get('change_photo'),
                            color: CustomerColors.mid,
                            onTap: () => pickAndSave(append: false)),
                        const SizedBox(height: 10),
                        _NeoPhotoTile(
                            icon: Icons.add_photo_alternate_outlined,
                            label: 'Add Another Photo',
                            color: const Color(0xFF5555AA),
                            onTap: () => pickAndSave(append: true)),
                        const SizedBox(height: 10),
                        _NeoPhotoTile(
                            icon: Icons.delete_outline_rounded,
                            label: l.get('remove_photo'),
                            color: CustomerColors.error,
                            onTap: removePhoto),
                      ] else ...[
                        _NeoPhotoTile(
                            icon: Icons.add_a_photo_outlined,
                            label: l.get('add_photo'),
                            color: const Color(0xFF5555AA),
                            onTap: () => pickAndSave(append: false)),
                      ],
                      const SizedBox(height: 14),
                      _NeoOutlineBtn(
                          label: l.get('cancel'),
                          onTap:
                              isUploading ? () {} : () => Navigator.pop(ctx)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEditDialog(
      BuildContext context, WidgetRef ref, UserModel provider) {
    if (order.status != OrderStatus.pending &&
        order.status != OrderStatus.inProgress) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Only pending or in-progress orders can be edited.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final titleCtrl = TextEditingController(text: order.title);
    final descCtrl = TextEditingController(text: order.description);
    final areaCtrl = TextEditingController(text: order.area);
    DateTime selectedDate = order.serviceDate;
    TimeOfDay selectedTime = TimeOfDay(
        hour: order.serviceDate.hour, minute: order.serviceDate.minute);
    OrderPriority priority = order.priority;
    bool saving = false;

    // ── Selected Services editing state ─────────────────────────────────────
    // The `provider` param is resolved by the caller from providersProvider,
    // a StateProvider seeded once from DummyData.providers — it is not the
    // live Firestore user doc, so its servicesList can be empty/stale (this
    // was the proven cause of Edit Order showing only the order's already-
    // selected service instead of every current provider service). Re-resolve
    // the live provider via userByIdProvider — the same live Firestore stream
    // already used for this exact purpose elsewhere (e.g. Order Details,
    // Provider Profile, New Order) — falling back to the passed-in snapshot
    // only while that stream hasn't emitted yet.
    final liveProvider =
        ref.read(userByIdProvider(order.providerId)).valueOrNull ?? provider;

    // Structured-service-only: only ServiceModel entries with real ids from
    // the provider's current live servicesList are selectable. Stored
    // selections are re-matched by id to the provider's current snapshot so
    // an edited name/description/price/category shows up-to-date; a stored
    // selection whose id no longer exists on the provider keeps its stored
    // snapshot so the Customer can still see and remove it.
    final currentServicesById = {
      for (final s in liveProvider.servicesList) s.id: s
    };
    List<ServiceModel> selectedServices = order.selectedServices.isNotEmpty
        ? order.selectedServices
            .map((s) => currentServicesById[s.id] ?? s)
            .toList()
        : (order.selectedServiceId != null &&
                currentServicesById[order.selectedServiceId] != null
            ? [currentServicesById[order.selectedServiceId]!]
            : <ServiceModel>[]);
    // Only flips to true once the Customer actively toggles a service tile —
    // gates whether Save touches the service fields at all, so an untouched
    // (including unmatched-legacy) selection is never overwritten just by
    // opening Edit Order.
    bool serviceSelectionChanged = false;
    // Baseline "what New Order would have generated for the current
    // selection" — used to tell an auto-generated title/description apart
    // from one the Customer typed manually (see the toggle handler below).
    String lastAutoTitle = _editServicesSummary(selectedServices);
    String lastAutoDescription = _editServicesDescription(selectedServices);
    final categoriesById = {
      for (final c in ref.read(categoriesProvider).valueOrNull ??
          const <CategoryModel>[])
        c.id: c
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          // Recomputed on every rebuild (add/remove) so a selected service
          // that's since been removed from the provider's live list is shown
          // — and stays selectable to remove — until the Customer removes it
          // from the selection here too.
          final removedSelectedServices = selectedServices
              .where((s) => !currentServicesById.containsKey(s.id))
              .toList();
          final tileServices = [
            ...liveProvider.servicesList,
            ...removedSelectedServices
          ];
          final selectedTotal =
              selectedServices.fold<double>(0, (sum, s) => sum + s.price);
          return Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              height: MediaQuery.of(ctx).size.height * 0.88,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEEEEF5),
                borderRadius: BorderRadius.circular(32),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0xFFBEBECF),
                      blurRadius: 20,
                      offset: Offset(8, 8)),
                  BoxShadow(
                      color: Colors.white,
                      blurRadius: 20,
                      offset: Offset(-8, -8)),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 14),
                  // Handle
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFBEBECF),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.white,
                            blurRadius: 2,
                            offset: Offset(-1, -1)),
                        BoxShadow(
                            color: Color(0xFFBEBECF),
                            blurRadius: 2,
                            offset: Offset(1, 1)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFEEEEF5),
                          boxShadow: [
                            BoxShadow(
                                color: Color(0xFFBEBECF),
                                blurRadius: 8,
                                offset: Offset(4, 4)),
                            BoxShadow(
                                color: Colors.white,
                                blurRadius: 8,
                                offset: Offset(-4, -4)),
                          ],
                        ),
                        child: const Icon(Icons.edit_rounded,
                            color: Color(0xFF5555AA), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Text(l.get('edit_order'),
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF333355))),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _NeoLabel(l.get('order_request_title')),
                          _NeoTextField(
                              controller: titleCtrl,
                              hint: l.get('enter_order_title')),
                          const SizedBox(height: 14),
                          _NeoLabel(l.get('order_request_desc')),
                          _NeoTextField(
                              controller: descCtrl,
                              hint: l.get('enter_order_desc'),
                              maxLines: 3),
                          const SizedBox(height: 14),
                          _NeoLabel(l.get('area_or_city')),
                          _NeoTextField(
                              controller: areaCtrl, hint: l.get('enter_area')),
                          const SizedBox(height: 14),
                          _NeoLabel(l.get('order_date')),
                          _NeoPickerRow(
                            icon: Icons.calendar_today_outlined,
                            label:
                                '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                            onTap: () async {
                              final d = await showDatePicker(
                                context: ctx,
                                initialDate: selectedDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365)),
                              );
                              if (d != null) setSheet(() => selectedDate = d);
                            },
                          ),
                          const SizedBox(height: 14),
                          _NeoLabel(l.get('order_service_time')),
                          _NeoPickerRow(
                            icon: Icons.access_time_rounded,
                            label:
                                '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                            onTap: () async {
                              final t = await showTimePicker(
                                  context: ctx, initialTime: selectedTime);
                              if (t != null) setSheet(() => selectedTime = t);
                            },
                          ),
                          const SizedBox(height: 14),
                          _NeoLabel(l.get('priority_label')),
                          Row(children: [
                            Expanded(
                                child: _NeoPriorityButton(
                              label: l.get('priority_normal'),
                              icon: Icons.remove_circle_outline,
                              selected: priority == OrderPriority.normal,
                              color: const Color(0xFF5555AA),
                              onTap: () => setSheet(
                                  () => priority = OrderPriority.normal),
                            )),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _NeoPriorityButton(
                              label: l.get('priority_urgent'),
                              icon: Icons.priority_high_rounded,
                              selected: priority == OrderPriority.urgent,
                              color: CustomerColors.error,
                              onTap: () => setSheet(
                                  () => priority = OrderPriority.urgent),
                            )),
                          ]),
                          if (tileServices.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            const _NeoLabel('Selected Services'),
                            ...tileServices.map((svc) {
                              final selIdx = selectedServices
                                  .indexWhere((s) => s.id == svc.id);
                              final isSelected = selIdx >= 0;
                              return _EditServiceTile(
                                service: svc,
                                category: categoriesById[svc.categoryId],
                                isSelected: isSelected,
                                onTap: () => setSheet(() {
                                  serviceSelectionChanged = true;
                                  if (isSelected) {
                                    selectedServices.removeAt(selIdx);
                                  } else {
                                    selectedServices.add(svc);
                                  }
                                  final newTitle =
                                      _editServicesSummary(selectedServices);
                                  final newDescription =
                                      _editServicesDescription(
                                          selectedServices);
                                  if (titleCtrl.text.trim().isEmpty ||
                                      titleCtrl.text == lastAutoTitle) {
                                    titleCtrl.text = newTitle;
                                  }
                                  if (descCtrl.text.trim().isEmpty ||
                                      descCtrl.text == lastAutoDescription) {
                                    descCtrl.text = newDescription;
                                  }
                                  lastAutoTitle = newTitle;
                                  lastAutoDescription = newDescription;
                                }),
                              );
                            }),
                            if (selectedServices.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              _EditTotalPriceBanner(total: selectedTotal),
                            ],
                          ],
                          const SizedBox(height: 24),
                          Row(children: [
                            Expanded(
                                child: _NeoOutlineBtn(
                              label: l.get('cancel'),
                              onTap: () => Navigator.pop(ctx),
                            )),
                            const SizedBox(width: 12),
                            Expanded(
                                child: saving
                                    ? const Center(
                                        child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF5555AA)),
                                      ))
                                    : _NeoSaveBtn(
                                        label: l.get('save'),
                                        onTap: () async {
                                          if (titleCtrl.text.trim().isEmpty) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                              content:
                                                  Text('Title is required.'),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                            ));
                                            return;
                                          }
                                          setSheet(() => saving = true);
                                          final newDate = DateTime(
                                            selectedDate.year,
                                            selectedDate.month,
                                            selectedDate.day,
                                            selectedTime.hour,
                                            selectedTime.minute,
                                          );
                                          final updated = order.copyWith(
                                            title: titleCtrl.text.trim(),
                                            description: descCtrl.text.trim(),
                                            area:
                                                areaCtrl.text.trim().isNotEmpty
                                                    ? areaCtrl.text.trim()
                                                    : order.area,
                                            serviceDate: newDate,
                                            priority: priority,
                                            updatedAt: DateTime.now(),
                                          );
                                          try {
                                            await ref
                                                .read(ordersProvider.notifier)
                                                .updateCustomerOrderInFirestore(
                                                  updated,
                                                  serviceSelectionChanged:
                                                      serviceSelectionChanged,
                                                  selectedServices:
                                                      selectedServices,
                                                  selectedServiceName:
                                                      selectedServices.isEmpty
                                                          ? null
                                                          : _editServicesSummary(
                                                              selectedServices),
                                                  selectedServicePrice:
                                                      selectedServices.isEmpty
                                                          ? null
                                                          : selectedTotal,
                                                  selectedServiceId:
                                                      selectedServices.length ==
                                                              1
                                                          ? selectedServices
                                                              .first.id
                                                          : null,
                                                );
                                            if (ctx.mounted) Navigator.pop(ctx);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(SnackBar(
                                                content: const Row(children: [
                                                  Icon(Icons.check_circle,
                                                      color: Colors.white),
                                                  SizedBox(width: 8),
                                                  Text(
                                                      'Order updated successfully'),
                                                ]),
                                                backgroundColor:
                                                    CustomerColors.dark,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12)),
                                              ));
                                            }
                                          } catch (_) {
                                            setSheet(() => saving = false);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(SnackBar(
                                                content: const Row(children: [
                                                  Icon(Icons.error_outline,
                                                      color: Colors.white),
                                                  SizedBox(width: 8),
                                                  Text(
                                                      'Failed to update order. Please try again.'),
                                                ]),
                                                backgroundColor:
                                                    CustomerColors.error,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12)),
                                              ));
                                            }
                                          }
                                        },
                                      )),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: CustomerColors.light, fontSize: 13),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: CustomerColors.light.withOpacity(0.4))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: CustomerColors.light.withOpacity(0.4))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: CustomerColors.dark, width: 2)),
        filled: true,
        fillColor: CustomerColors.lightest.withOpacity(0.4),
      );

  void _showOrderComplaint(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderComplaintSheet(
        orders: [order],
        preSelectedOrder: order,
      ),
    );
  }

  void _showCancelDialog(BuildContext context, WidgetRef ref) {
    if (order.status != OrderStatus.pending) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Only pending orders can be cancelled.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final reasonCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFEEEEF5),
            borderRadius: BorderRadius.circular(32),
            boxShadow: const [
              BoxShadow(
                  color: Color(0xFFBEBECF),
                  blurRadius: 20,
                  offset: Offset(8, 8)),
              BoxShadow(
                  color: Colors.white, blurRadius: 20, offset: Offset(-8, -8)),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                  child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFBEBECF),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.white,
                        blurRadius: 2,
                        offset: Offset(-1, -1)),
                    BoxShadow(
                        color: Color(0xFFBEBECF),
                        blurRadius: 2,
                        offset: Offset(1, 1)),
                  ],
                ),
              )),
              const SizedBox(height: 20),
              Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFEEEEF5),
                    boxShadow: [
                      BoxShadow(
                          color: Color(0xFFBEBECF),
                          blurRadius: 8,
                          offset: Offset(4, 4)),
                      BoxShadow(
                          color: Colors.white,
                          blurRadius: 8,
                          offset: Offset(-4, -4)),
                    ],
                  ),
                  child: const Icon(Icons.cancel_outlined,
                      color: CustomerColors.error, size: 22),
                ),
                const SizedBox(width: 14),
                Text(l.get('cancel_reason'),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF333355))),
              ]),
              const SizedBox(height: 18),
              // Info banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: Color(0xFFEEEEF5),
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                  boxShadow: [
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
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: CustomerColors.error, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(
                        'Please tell us why you\'d like to cancel this order.',
                        style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF555577),
                            height: 1.5),
                      )),
                    ]),
              ),
              const SizedBox(height: 16),
              _NeoLabel(l.get('enter_cancel_reason')),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFEEEEF5),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
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
                child: TextField(
                  controller: reasonCtrl,
                  maxLines: 3,
                  cursorColor: CustomerColors.error,
                  style:
                      const TextStyle(fontSize: 14, color: Color(0xFF333355)),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Provider not available…',
                    hintStyle:
                        TextStyle(color: Color(0xFFAAAACC), fontSize: 13),
                    prefixIcon: Icon(Icons.description_outlined,
                        color: Color(0xFF7777AA), size: 20),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                    child: _NeoOutlineBtn(
                        label: l.get('back'), onTap: () => Navigator.pop(ctx))),
                const SizedBox(width: 12),
                Expanded(
                    child: _NeoDeleteBtn(
                  label: l.get('confirm_cancel'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      await ref
                          .read(ordersProvider.notifier)
                          .cancelCustomerOrderInFirestore(
                            orderId: order.id,
                            reason: reasonCtrl.text.trim().isNotEmpty
                                ? reasonCtrl.text.trim()
                                : null,
                          );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: const Row(children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Order cancelled successfully'),
                          ]),
                          backgroundColor: CustomerColors.dark,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ));
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: const Row(children: [
                            Icon(Icons.error_outline, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Failed to cancel order. Please try again.'),
                          ]),
                          backgroundColor: CustomerColors.error,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ));
                      }
                    }
                  },
                )),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // ── Status helpers ─────────────────────────────────────────────
  _StatusConfig _getStatusConfig(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return _StatusConfig(
          bg: const Color(0xFFFFF3CD),
          text: const Color(0xFF856404),
          icon: Icons.hourglass_empty_rounded,
          accentColor: const Color(0xFFF59E0B),
        );
      case OrderStatus.inProgress:
        return _StatusConfig(
          bg: const Color(0xFFD1ECF1),
          text: const Color(0xFF0C5460),
          icon: Icons.autorenew_rounded,
          accentColor: const Color(0xFF0EA5E9),
        );
      case OrderStatus.completed:
        return _StatusConfig(
          bg: const Color(0xFFD4EDDA),
          text: const Color(0xFF155724),
          icon: Icons.check_circle_rounded,
          accentColor: const Color(0xFF10B981),
        );
      case OrderStatus.cancelled:
        return _StatusConfig(
          bg: const Color(0xFFF8D7DA),
          text: const Color(0xFF721C24),
          icon: Icons.cancel_rounded,
          accentColor: const Color(0xFFEF4444),
        );
    }
  }

  String _getStatusLabel(OrderStatus status, AppLocalizations l) {
    switch (status) {
      case OrderStatus.pending:
        return l.get('pending');
      case OrderStatus.inProgress:
        return l.get('in_progress');
      case OrderStatus.completed:
        return l.get('completed');
      case OrderStatus.cancelled:
        return l.get('cancelled');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = _getStatusConfig(order.status);
    final statusLabel = _getStatusLabel(order.status, l);
    final allPhotos = ref.watch(profilePhotoProvider);
    final providerPhoto = allPhotos[order.providerId];
    final providers = ref.watch(providersProvider);
    final provider = providers.firstWhere(
      (p) => p.id == order.providerId,
      orElse: () => UserModel(
        id: order.providerId,
        fullName: order.providerName,
        email: '',
        phone: '',
        city: '',
        role: UserRole.professional,
      ),
    );
    // Edit + Photo remain available for Pending and In Progress orders;
    // Cancel/Delete is Pending-only (In Progress orders are not cancellable
    // by the customer from this action).
    final canEdit = order.status != OrderStatus.cancelled &&
        order.status != OrderStatus.completed;
    final canCancel = order.status == OrderStatus.pending;

    return _OrderCard3D(
      order: order,
      cfg: cfg,
      statusLabel: statusLabel,
      providerPhoto: providerPhoto,
      provider: provider,
      canEdit: canEdit,
      canCancel: canCancel,
      l: l,
      onPhotoOptions: () => _showPhotoOptionsSheet(context, ref),
      onEdit: () => _showEditDialog(context, ref, provider),
      onCancel: () => _showCancelDialog(context, ref),
      onComplaint: () => _showOrderComplaint(context, ref),
      onFullPhoto: order.photoBytes != null
          ? () => _showFullPhoto(context, order.photoBytes!)
          : null,
    );
  }
}

// ── Notification-tap deep link ────────────────────────────────────────────────
// Opens the exact customer Order Details screen for a given order. Reuses
// _OrderCard's own status/photo/provider resolution and action callbacks
// (edit/cancel/complaint/photo) so this never duplicates that business logic.
void openCustomerOrderDetail(
    BuildContext context, WidgetRef ref, OrderModel order) {
  final l = AppLocalizations.of(context);
  final card = _OrderCard(order: order, l: l);
  final cfg = card._getStatusConfig(order.status);
  final statusLabel = card._getStatusLabel(order.status, l);
  final allPhotos = ref.read(profilePhotoProvider);
  final providerPhoto = allPhotos[order.providerId];
  final providers = ref.read(providersProvider);
  final provider = providers.firstWhere(
    (p) => p.id == order.providerId,
    orElse: () => UserModel(
      id: order.providerId,
      fullName: order.providerName,
      email: '',
      phone: '',
      city: '',
      role: UserRole.professional,
    ),
  );
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => _OrderDetailScreen(
        order: order,
        cfg: cfg,
        statusLabel: statusLabel,
        providerPhoto: providerPhoto,
        provider: provider,
        l: l,
        onPhotoOptions: () => card._showPhotoOptionsSheet(context, ref),
        onEdit: () => card._showEditDialog(context, ref, provider),
        onCancel: () => card._showCancelDialog(context, ref),
        onComplaint: () => card._showOrderComplaint(context, ref),
      ),
    ),
  );
}

// ── Order photo removal ──────────────────────────────────────────────────────
// Shows a confirmation dialog (with its own loading state so the Remove
// button is disabled and duplicate taps can't fire a second write), then
// performs the Firestore removal followed by a best-effort Storage cleanup.
// Firestore is always updated first — Storage is only touched after that
// succeeds, so a failed cleanup never leaves imageUrls pointing at a
// deleted object.
Future<void> _confirmAndRemoveImage(
  BuildContext context,
  WidgetRef ref,
  OrderModel order,
  String imageUrl,
) async {
  bool isRemoving = false;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (dialogCtx, setDialogState) => PopScope(
        canPop: !isRemoving,
        child: AlertDialog(
          backgroundColor: const Color(0xFFEEEEF5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Remove Photo?',
              style: TextStyle(
                  fontWeight: FontWeight.w800, color: Color(0xFF333355))),
          content: const Text(
              'This photo will be permanently removed from the order. This cannot be undone.',
              style: TextStyle(color: Color(0xFF555577))),
          actions: [
            TextButton(
              onPressed:
                  isRemoving ? null : () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            if (isRemoving)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: CustomerColors.error),
                ),
              )
            else
              TextButton(
                onPressed: () async {
                  setDialogState(() => isRemoving = true);
                  try {
                    await ref
                        .read(ordersProvider.notifier)
                        .removeOrderImageInFirestore(
                          orderId: order.id,
                          imageUrl: imageUrl,
                        );
                    if (dialogCtx.mounted) Navigator.pop(dialogCtx, true);
                  } catch (e) {
                    debugPrint('ORDER_PHOTO_REMOVE_ERROR: $e');
                    setDialogState(() => isRemoving = false);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Row(children: [
                          Icon(Icons.error_outline, color: Colors.white),
                          SizedBox(width: 8),
                          Expanded(
                              child: Text(
                                  'Failed to remove photo. Please try again.')),
                        ]),
                        backgroundColor: CustomerColors.error,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ));
                    }
                  }
                },
                child: const Text('Remove',
                    style: TextStyle(
                        color: CustomerColors.error,
                        fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      ),
    ),
  );

  if (confirmed != true) return;

  // Firestore removal succeeded. Best-effort Storage cleanup — only deletes
  // an object that resolves under this exact order's own image folder, so a
  // default/shared image can never be targeted. A cleanup failure here is
  // reported honestly and never causes the URL to be re-added: the order is
  // left correctly updated in Firestore, at the cost of a possible orphaned
  // Storage object.
  bool storageCleaned = true;
  try {
    final storageObjectRef = FirebaseStorage.instance.refFromURL(imageUrl);
    // Phase 6B2: accept both the new customerUid-scoped path and the
    // pre-6B2 legacy path — an order created before this phase may still
    // have imageUrls pointing at the legacy shape.
    final isNewPath = storageObjectRef.fullPath
        .startsWith('orders/${order.customerId}/${order.id}/images/');
    final isLegacyPath =
        storageObjectRef.fullPath.startsWith('orders/${order.id}/images/');
    if (isNewPath || isLegacyPath) {
      await storageObjectRef.delete();
    } else {
      storageCleaned = false;
      debugPrint(
          'ORDER_PHOTO_STORAGE_SKIP: ${storageObjectRef.fullPath} is not under orders/${order.customerId}/${order.id}/images/ or orders/${order.id}/images/ — leaving object in place');
    }
  } catch (e) {
    storageCleaned = false;
    debugPrint('ORDER_PHOTO_STORAGE_DELETE_ERROR: $e');
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white),
        const SizedBox(width: 8),
        Expanded(
          child: Text(storageCleaned
              ? 'Photo removed successfully'
              : 'Photo removed. Storage file cleanup failed (non-critical).'),
        ),
      ]),
      backgroundColor: CustomerColors.dark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }
}

// Minimal thumbnail grid so the Customer can pick exactly which image to
// remove when an order has more than one. Returns the selected URL, or null
// if the sheet was dismissed without a selection.
Future<String?> _showImageSelectionSheet(
    BuildContext context, List<String> urls) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEEEEF5),
              borderRadius: BorderRadius.circular(32),
              boxShadow: const [
                BoxShadow(
                    color: Color(0xFFBEBECF),
                    blurRadius: 20,
                    offset: Offset(8, 8)),
                BoxShadow(
                    color: Colors.white,
                    blurRadius: 20,
                    offset: Offset(-8, -8)),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFBEBECF),
                    borderRadius: BorderRadius.circular(3),
                  ),
                )),
                const SizedBox(height: 20),
                const Text('Select Photo to Remove',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF333355))),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: urls.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => Navigator.pop(ctx, urls[i]),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        urls[i],
                        fit: BoxFit.cover,
                        loadingBuilder: (c, child, progress) => progress == null
                            ? child
                            : Container(
                                color: const Color(0xFFDDDDEE),
                                child: const Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))),
                        errorBuilder: (c, e, st) => Container(
                          color: const Color(0xFFDDDDEE),
                          child: const Icon(Icons.broken_image_outlined,
                              color: Color(0xFF9999BB)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _NeoOutlineBtn(
                    label: 'Cancel', onTap: () => Navigator.pop(ctx)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

// ── Multi-image viewer ───────────────────────────────────────────────────────
// Called only when there are 2+ images — callers use the existing
// _showFullPhotoUrl single-image viewer otherwise. Opens a swipeable gallery
// with a position indicator.
void _showFullPhotoGallery(BuildContext context, List<String> urls) {
  if (urls.length < 2) return;
  showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.85),
    builder: (ctx) => _PhotoGalleryDialog(urls: urls),
  );
}

class _PhotoGalleryDialog extends StatefulWidget {
  final List<String> urls;
  const _PhotoGalleryDialog({required this.urls});

  @override
  State<_PhotoGalleryDialog> createState() => _PhotoGalleryDialogState();
}

class _PhotoGalleryDialogState extends State<_PhotoGalleryDialog> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Center(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Image.network(
                    widget.urls[i],
                    fit: BoxFit.contain,
                    loadingBuilder: (c, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                          child:
                              CircularProgressIndicator(color: Colors.white));
                    },
                    errorBuilder: (c, e, st) => const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_outlined,
                              color: Colors.white54, size: 48),
                          SizedBox(height: 8),
                          Text('Could not load image',
                              style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_index + 1} / ${widget.urls.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _StatusConfig {
  final Color bg, text, accentColor;
  final IconData icon;
  const _StatusConfig(
      {required this.bg,
      required this.text,
      required this.icon,
      required this.accentColor});
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F6FF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: CustomerColors.lightest),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: CustomerColors.light),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: CustomerColors.mid,
                  fontWeight: FontWeight.w500)),
        ]),
      );
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12, color: color, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}

class _EditLabel extends StatelessWidget {
  final String text;
  const _EditLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: CustomerColors.mid)),
      );
}

// ── Assigned Row Widget ───────────────────────────────────────────────────────
class _AssignedRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;
  const _AssignedRow({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: highlight
                  ? CustomerColors.dark.withOpacity(0.12)
                  : CustomerColors.lightest.withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 14,
              color: highlight ? CustomerColors.dark : CustomerColors.mid,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: CustomerColors.mid,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color:
                      highlight ? CustomerColors.dark : CustomerColors.darkest,
                ),
              ),
            ],
          ),
        ],
      );
}

// ── Tile used in the photo options sheet ─────────────────────────────────────
class _PhotoOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _PhotoOptionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3), width: 1.2),
        ),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          ),
          Icon(Icons.arrow_forward_ios_rounded,
              color: color.withOpacity(0.5), size: 14),
        ]),
      ),
    );
  }
}

// ── Order Stepper Bar — Animated progress steps ────────────────────────────────
// ── Neumorphic Pill-Style Tab Bar ─────────────────────────────────────────────
class _OrderStepperBar extends StatefulWidget {
  final int allCount;
  final int pendingCount;
  final int inProgressCount;
  const _OrderStepperBar({
    required this.allCount,
    required this.pendingCount,
    required this.inProgressCount,
  });

  @override
  State<_OrderStepperBar> createState() => _OrderStepperBarState();
}

class _OrderStepperBarState extends State<_OrderStepperBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideCtrl;
  int _prevIndex = 0;

  // Color mapping: All = green, Pending = amber/orange, In Progress =
  // Customer blue accent (CustomerColors.primary/primaryDark).
  static const _tabData = [
    _TabData(
        label: 'All',
        icon: Icons.list_alt_rounded,
        activeColor: Color(0xFF10B981),
        darkColor: Color(0xFF065F46)),
    _TabData(
        label: 'Pending',
        icon: Icons.hourglass_top_rounded,
        activeColor: Color(0xFFF59E0B),
        darkColor: Color(0xFFB45309)),
    _TabData(
        label: 'In Progress',
        icon: Icons.autorenew_rounded,
        activeColor: CustomerColors.primary,
        darkColor: CustomerColors.primaryDark),
  ];

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = DefaultTabController.of(context);
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        final current = ctrl.index;
        if (_prevIndex != current) {
          _prevIndex = current;
          _slideCtrl.forward(from: 0);
        }
        final counts = [
          widget.allCount,
          widget.pendingCount,
          widget.inProgressCount
        ];

        return Container(
          height: 56,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: const Color(0xFFEEEEF5),
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                  color: Color(0xFFBEBECF),
                  blurRadius: 0,
                  offset: Offset(0, 5)),
              BoxShadow(
                  color: Color(0xFFBEBECF),
                  blurRadius: 14,
                  offset: Offset(6, 6)),
              BoxShadow(
                  color: Colors.white, blurRadius: 14, offset: Offset(-6, -6)),
            ],
          ),
          child: Row(
            children: List.generate(_tabData.length, (i) {
              final isActive = current == i;
              final tab = _tabData[i];

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ctrl.animateTo(i);
                    setState(() {});
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      color: isActive ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(23),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                  color: tab.activeColor.withOpacity(0.18),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4)),
                              const BoxShadow(
                                  color: Color(0xFFBEBECF),
                                  blurRadius: 4,
                                  offset: Offset(2, 2)),
                              const BoxShadow(
                                  color: Colors.white,
                                  blurRadius: 4,
                                  offset: Offset(-2, -2)),
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Animated icon container
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 260),
                              width: isActive ? 26 : 20,
                              height: isActive ? 26 : 20,
                              decoration: BoxDecoration(
                                gradient: isActive
                                    ? LinearGradient(
                                        colors: [
                                          tab.activeColor,
                                          tab.darkColor
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                color: isActive ? null : Colors.transparent,
                                borderRadius:
                                    BorderRadius.circular(isActive ? 9 : 7),
                                boxShadow: isActive
                                    ? [
                                        BoxShadow(
                                            color: tab.activeColor
                                                .withOpacity(0.45),
                                            blurRadius: 6,
                                            offset: const Offset(0, 3)),
                                        BoxShadow(
                                            color: tab.darkColor,
                                            blurRadius: 0,
                                            offset: const Offset(0, 2)),
                                      ]
                                    : [],
                              ),
                              child: Center(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    tab.icon,
                                    key: ValueKey(isActive),
                                    size: isActive ? 14 : 12,
                                    color: isActive
                                        ? Colors.white
                                        : const Color(0xFF9999BB),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            // Label
                            Flexible(
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 220),
                                style: TextStyle(
                                  fontSize: isActive ? 12 : 11,
                                  fontWeight: isActive
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isActive
                                      ? const Color(0xFF22224A)
                                      : const Color(0xFF9999BB),
                                  letterSpacing: -0.2,
                                ),
                                child: Text(tab.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ),
                            // Count badge
                            if (counts[i] > 0) ...[
                              const SizedBox(width: 5),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 260),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? tab.activeColor
                                      : const Color(0xFFBEBECF),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: isActive
                                      ? [
                                          BoxShadow(
                                              color: tab.activeColor
                                                  .withOpacity(0.4),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2)),
                                          BoxShadow(
                                              color: tab.darkColor,
                                              blurRadius: 0,
                                              offset: const Offset(0, 2)),
                                        ]
                                      : [],
                                ),
                                child: Text(
                                  '${counts[i]}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: isActive
                                        ? Colors.white
                                        : const Color(0xFF666688),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

class _TabData {
  final String label;
  final IconData icon;
  final Color activeColor, darkColor;
  const _TabData(
      {required this.label,
      required this.icon,
      required this.activeColor,
      required this.darkColor});
}

// ── Three dots Neo menu for Orders header ──────────────────────────────────────
class _OrdersThreeDotsMenu extends StatefulWidget {
  final VoidCallback onComplaint;
  final List<OrderModel> completedOrders;
  final List<OrderModel> cancelledOrders;
  const _OrdersThreeDotsMenu({
    required this.onComplaint,
    required this.completedOrders,
    required this.cancelledOrders,
  });

  @override
  State<_OrdersThreeDotsMenu> createState() => _OrdersThreeDotsMenuState();
}

class _OrdersThreeDotsMenuState extends State<_OrdersThreeDotsMenu>
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

  void _openMenu() {
    HapticFeedback.lightImpact();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(color: Colors.transparent),
              ),
            ),
            Positioned(
              top: 72,
              right: 16,
              child: SlideTransition(
                position: Tween<Offset>(
                        begin: const Offset(0.5, -0.3), end: Offset.zero)
                    .animate(curved),
                child: FadeTransition(
                  opacity: anim,
                  child: _NeoOrderMenuPanel(
                    completedCount: widget.completedOrders.length,
                    cancelledCount: widget.cancelledOrders.length,
                    onCompleted: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _FilteredOrdersScreen(
                              title: 'Completed Orders',
                              orders: widget.completedOrders,
                              accentColor: const Color(0xFF10B981),
                              icon: Icons.check_circle_rounded,
                            ),
                          ));
                    },
                    onCancelled: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _FilteredOrdersScreen(
                              title: 'Cancelled Orders',
                              orders: widget.cancelledOrders,
                              accentColor: const Color(0xFFEF4444),
                              icon: Icons.cancel_rounded,
                            ),
                          ));
                    },
                    onComplaint: () {
                      Navigator.pop(ctx);
                      widget.onComplaint();
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
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
        _openMenu();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) =>
            Transform.scale(scale: 1.0 - 0.08 * _ctrl.value, child: child),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF1A3A6B),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 8,
                  offset: const Offset(3, 3)),
              BoxShadow(
                  color: Colors.white.withOpacity(0.08),
                  blurRadius: 6,
                  offset: const Offset(-2, -2)),
            ],
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
                3,
                (i) => Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 1.5),
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                    )),
          ),
        ),
      ),
    );
  }
}

// ── Neo Order Menu Panel ───────────────────────────────────────────────────────
class _NeoOrderMenuPanel extends StatefulWidget {
  final int completedCount;
  final int cancelledCount;
  final VoidCallback onCompleted;
  final VoidCallback onCancelled;
  final VoidCallback onComplaint;
  const _NeoOrderMenuPanel({
    required this.completedCount,
    required this.cancelledCount,
    required this.onCompleted,
    required this.onCancelled,
    required this.onComplaint,
  });

  @override
  State<_NeoOrderMenuPanel> createState() => _NeoOrderMenuPanelState();
}

class _NeoOrderMenuPanelState extends State<_NeoOrderMenuPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 360))
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      _MenuItemData(Icons.check_circle_outline_rounded, 'Completed',
          const Color(0xFF10B981), widget.completedCount, widget.onCompleted),
      _MenuItemData(Icons.cancel_outlined, 'Cancelled', const Color(0xFFEF4444),
          widget.cancelledCount, widget.onCancelled),
      _MenuItemData(Icons.flag_outlined, 'Complaint', const Color(0xFFB45309),
          0, widget.onComplaint),
    ];

    return Container(
      width: 68,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        color: const Color(0xFFEEEEF5),
        boxShadow: const [
          BoxShadow(
              color: Color(0xFFBEBECF), blurRadius: 16, offset: Offset(6, 6)),
          BoxShadow(
              color: Colors.white, blurRadius: 16, offset: Offset(-6, -6)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(items.length, (i) {
          final item = items[i];
          final n = items.length;
          final anim = CurvedAnimation(
            parent: _ctrl,
            curve: Interval(
                (i / n).clamp(0.0, 1.0), ((i + 1) / n).clamp(0.0, 1.0),
                curve: Curves.easeOutBack),
          );

          return AnimatedBuilder(
            animation: anim,
            builder: (_, child) => Opacity(
              opacity: anim.value.clamp(0.0, 1.0),
              child: Transform.scale(
                  scale: 0.6 + 0.4 * anim.value.clamp(0.0, 1.0), child: child),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: GestureDetector(
                onTap: item.onTap,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFEEEEF5),
                        boxShadow: const [
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
                      child: Icon(item.icon, color: item.color, size: 22),
                    ),
                    if (item.count > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: item.color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: item.color.withOpacity(0.4),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2))
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '${item.count}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _MenuItemData {
  final IconData icon;
  final String label;
  final Color color;
  final int count;
  final VoidCallback onTap;
  const _MenuItemData(
      this.icon, this.label, this.color, this.count, this.onTap);
}

// ── Filtered Orders Screen (Completed / Cancelled) ────────────────────────────
class _FilteredOrdersScreen extends StatelessWidget {
  final String title;
  final List<OrderModel> orders;
  final Color accentColor;
  final IconData icon;
  const _FilteredOrdersScreen({
    required this.title,
    required this.orders,
    required this.accentColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF0F6FF),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 110,
            backgroundColor: CustomerColors.dark,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const BackButton(color: Colors.white),
            ),
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
                    padding: const EdgeInsets.fromLTRB(20, 44, 20, 16),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: accentColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(title,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800)),
                            Text('${orders.length} orders',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.65),
                                    fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (orders.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 60, color: accentColor.withOpacity(0.4)),
                      const SizedBox(height: 12),
                      Text('No $title',
                          style: TextStyle(
                              color: CustomerColors.mid, fontSize: 15)),
                    ]),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _OrderCard(order: orders[i], l: l),
                childCount: orders.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// ── Neo Icon Action Button (for completed/cancelled) ──────────────────────────
class _NeoIconActionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;
  const _NeoIconActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  State<_NeoIconActionButton> createState() => _NeoIconActionButtonState();
}

class _NeoIconActionButtonState extends State<_NeoIconActionButton>
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
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          _ctrl.forward();
        },
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEEEEF5),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFFBEBECF),
                    blurRadius: 0,
                    offset: const Offset(0, 3)),
                const BoxShadow(
                    color: Color(0xFFBEBECF),
                    blurRadius: 6,
                    offset: Offset(3, 3)),
                const BoxShadow(
                    color: Colors.white, blurRadius: 6, offset: Offset(-3, -3)),
              ],
              border:
                  Border.all(color: widget.color.withOpacity(0.2), width: 1),
            ),
            child: Icon(widget.icon, size: 18, color: widget.color),
          ),
        ),
      ),
    );
  }
}

// ── Neo 3D Complaint Sheet ─────────────────────────────────────────────────────
// Replaces old _OrderComplaintSheet with full neomorphism design
class _OrderComplaintSheet extends ConsumerStatefulWidget {
  final List<OrderModel> orders;
  final OrderModel? preSelectedOrder;
  const _OrderComplaintSheet({required this.orders, this.preSelectedOrder});

  @override
  ConsumerState<_OrderComplaintSheet> createState() =>
      _OrderComplaintSheetState();
}

class _OrderComplaintSheetState extends ConsumerState<_OrderComplaintSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  String? _selectedReason;
  OrderModel? _selectedOrder;
  bool _loading = false;

  List<String> _getReasons(AppLocalizations l) => [
        l.get('reason_bad_behavior'),
        l.get('reason_late'),
        l.get('reason_bad_quality'),
        l.get('reason_fraud'),
        l.get('reason_mismatch'),
        l.get('reason_other'),
      ];

  @override
  void initState() {
    super.initState();
    _selectedOrder = widget.preSelectedOrder ??
        (widget.orders.isNotEmpty ? widget.orders.first : null);
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context).get('select_reason_error')),
        backgroundColor: CustomerColors.error,
      ));
      return;
    }
    if (_selectedOrder == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context).get('select_order_error')),
        backgroundColor: CustomerColors.error,
      ));
      return;
    }

    setState(() => _loading = true);
    final user = ref.read(authProvider);
    final order = _selectedOrder!;
    final hasProvider = order.providerId.isNotEmpty;

    final complaint = ComplaintModel(
      id: '',
      userId: user?.id ?? 'current_user',
      userName: user?.fullName ?? 'User',
      complainantRole: 'customer',
      type: ComplaintType.order,
      targetId: order.id,
      targetName: order.title,
      targetUserId: hasProvider ? order.providerId : null,
      targetUserName: hasProvider ? order.providerName : null,
      targetUserRole:
          hasProvider ? (order.providerRole ?? 'professional') : null,
      reason: _selectedReason!,
      description: _descCtrl.text,
      relatedOrderId: order.id,
      relatedOrderTitle: order.title,
      relatedProviderId: hasProvider ? order.providerId : null,
      relatedProviderName: hasProvider ? order.providerName : null,
      sourceContext: 'order_details',
      createdAt: DateTime.now(),
    );

    try {
      await addComplaintInFirestore(complaint);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Complaint sent successfully'),
            ]),
            backgroundColor: CustomerColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to submit complaint: $e')));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final reasons = _getReasons(l);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEEEEF5),
          borderRadius: BorderRadius.circular(32),
          boxShadow: const [
            BoxShadow(
                color: Color(0xFFBEBECF), blurRadius: 20, offset: Offset(8, 8)),
            BoxShadow(
                color: Colors.white, blurRadius: 20, offset: Offset(-8, -8)),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFBEBECF),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.white,
                            blurRadius: 2,
                            offset: Offset(-1, -1)),
                        BoxShadow(
                            color: Color(0xFFBEBECF),
                            blurRadius: 2,
                            offset: Offset(1, 1)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Header
                Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFEEEEF5),
                      boxShadow: [
                        BoxShadow(
                            color: Color(0xFFBEBECF),
                            blurRadius: 8,
                            offset: Offset(4, 4)),
                        BoxShadow(
                            color: Colors.white,
                            blurRadius: 8,
                            offset: Offset(-4, -4)),
                      ],
                    ),
                    child: const Icon(Icons.flag_rounded,
                        color: Color(0xFFB45309), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    l.get('order_complaint'),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF333355)),
                  ),
                ]),
                const SizedBox(height: 18),

                // Info banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEEEEF5),
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                    boxShadow: [
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
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: Color(0xFFB45309), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Can't find a resolution? Send us your complaint and our team will review it.",
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF555577),
                              height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Order selector (if multiple)
                if (widget.orders.length > 1) ...[
                  const Text('Select Order',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7777AA))),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEEEF5),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
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
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<OrderModel>(
                        value: _selectedOrder,
                        isExpanded: true,
                        dropdownColor: const Color(0xFFEEEEF5),
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF333355)),
                        onChanged: (val) =>
                            setState(() => _selectedOrder = val),
                        items: widget.orders
                            .map((o) => DropdownMenuItem(
                                  value: o,
                                  child: Text(o.title),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else if (_selectedOrder != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEEEF5),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0xFFBEBECF),
                            blurRadius: 5,
                            offset: Offset(2, 2)),
                        BoxShadow(
                            color: Colors.white,
                            blurRadius: 5,
                            offset: Offset(-2, -2)),
                      ],
                    ),
                    child: Row(children: [
                      const Icon(Icons.receipt_long_rounded,
                          size: 16, color: Color(0xFF5555AA)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_selectedOrder!.title,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF333355)))),
                    ]),
                  ),
                  const SizedBox(height: 16),
                ],

                // Reason label
                const Text('Complaint Reason',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7777AA))),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: reasons.map((r) {
                    final sel = _selectedReason == r;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedReason = r);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel
                              ? const Color(0xFFB45309)
                              : const Color(0xFFEEEEF5),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: sel
                              ? [
                                  BoxShadow(
                                      color: const Color(0xFFB45309)
                                          .withOpacity(0.40),
                                      blurRadius: 0,
                                      offset: const Offset(0, 3)),
                                  BoxShadow(
                                      color: const Color(0xFFB45309)
                                          .withOpacity(0.20),
                                      blurRadius: 8,
                                      offset: const Offset(0, 6))
                                ]
                              : const [
                                  BoxShadow(
                                      color: Color(0xFFBEBECF),
                                      blurRadius: 5,
                                      offset: Offset(3, 3)),
                                  BoxShadow(
                                      color: Colors.white,
                                      blurRadius: 5,
                                      offset: Offset(-3, -3)),
                                ],
                        ),
                        child: Text(
                          r,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: sel ? Colors.white : const Color(0xFF555577),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Details label
                const Text('Details',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7777AA))),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEEEF5),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
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
                  child: TextFormField(
                    controller: _descCtrl,
                    maxLines: 3,
                    style:
                        const TextStyle(fontSize: 14, color: Color(0xFF333355)),
                    cursorColor: const Color(0xFFB45309),
                    decoration: InputDecoration(
                      hintText: l.get('complaint_hint'),
                      hintStyle: const TextStyle(
                          color: Color(0xFFAAAACC), fontSize: 13),
                      prefixIcon: const Icon(Icons.description_outlined,
                          color: Color(0xFF7777AA), size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l.get('complaint_required')
                        : null,
                  ),
                ),
                const SizedBox(height: 28),

                // Submit button 3D
                _NeoComplaintSubmitButton(loading: _loading, onTap: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Neo Submit Button for Complaint ───────────────────────────────────────────
class _NeoComplaintSubmitButton extends StatefulWidget {
  final bool loading;
  final VoidCallback onTap;
  const _NeoComplaintSubmitButton({required this.loading, required this.onTap});

  @override
  State<_NeoComplaintSubmitButton> createState() =>
      _NeoComplaintSubmitButtonState();
}

class _NeoComplaintSubmitButtonState extends State<_NeoComplaintSubmitButton>
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
        if (!widget.loading) {
          HapticFeedback.mediumImpact();
          setState(() => _pressed = true);
          _ctrl.forward();
        }
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        _ctrl.reverse();
        if (!widget.loading) widget.onTap();
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
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(27),
            gradient: const LinearGradient(
              colors: [Color(0xFF7A2000), Color(0xFFB45309)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: _pressed
                ? [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.40),
                        blurRadius: 4,
                        offset: const Offset(2, 2))
                  ]
                : [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.40),
                        blurRadius: 0,
                        offset: const Offset(0, 5)),
                    BoxShadow(
                        color: const Color(0xFFB45309).withOpacity(0.30),
                        blurRadius: 12,
                        offset: const Offset(0, 8)),
                    BoxShadow(
                        color: Colors.white.withOpacity(0.08),
                        blurRadius: 4,
                        offset: const Offset(0, -2)),
                  ],
          ),
          child: Center(
            child: widget.loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.send_rounded, size: 18, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Send Complaint',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3)),
                  ]),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ── ORDER CARD 3D ─────────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════
class _OrderCard3D extends StatefulWidget {
  final OrderModel order;
  final _StatusConfig cfg;
  final String statusLabel;
  final Uint8List? providerPhoto;
  final UserModel provider;
  final bool canEdit;
  final bool canCancel;
  final AppLocalizations l;
  final VoidCallback onPhotoOptions;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onComplaint;
  final VoidCallback? onFullPhoto;

  const _OrderCard3D({
    required this.order,
    required this.cfg,
    required this.statusLabel,
    required this.providerPhoto,
    required this.provider,
    required this.canEdit,
    required this.canCancel,
    required this.l,
    required this.onPhotoOptions,
    required this.onEdit,
    required this.onCancel,
    required this.onComplaint,
    this.onFullPhoto,
  });

  @override
  State<_OrderCard3D> createState() => _OrderCard3DState();
}

class _OrderCard3DState extends State<_OrderCard3D>
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

  void _openDetail() {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _OrderDetailScreen(
            order: widget.order,
            cfg: widget.cfg,
            statusLabel: widget.statusLabel,
            providerPhoto: widget.providerPhoto,
            provider: widget.provider,
            l: widget.l,
            onPhotoOptions: widget.onPhotoOptions,
            onEdit: widget.onEdit,
            onCancel: widget.onCancel,
            onComplaint: widget.onComplaint,
          ),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final cfg = widget.cfg;

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
        _ctrl.forward();
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        _ctrl.reverse();
        _openDetail();
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
          duration: const Duration(milliseconds: 80),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: _pressed
                ? [
                    BoxShadow(
                        color: cfg.accentColor.withOpacity(0.15),
                        blurRadius: 4,
                        offset: const Offset(1, 2))
                  ]
                : [
                    BoxShadow(
                        color: cfg.accentColor.withOpacity(0.20),
                        blurRadius: 0,
                        offset: const Offset(0, 5)),
                    BoxShadow(
                        color: cfg.accentColor.withOpacity(0.10),
                        blurRadius: 16,
                        offset: const Offset(0, 8)),
                    BoxShadow(
                        color: Colors.white.withOpacity(0.90),
                        blurRadius: 4,
                        offset: const Offset(0, -1)),
                  ],
            border:
                Border.all(color: cfg.accentColor.withOpacity(0.15), width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(children: [
              // Top accent bar
              Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          cfg.accentColor,
                          cfg.accentColor.withOpacity(0.4)
                        ]),
                      ))),
              // Card content
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header row ──────────────────────────────────────────
                      Row(children: [
                        // Avatar 3D
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: widget.providerPhoto == null
                                ? LinearGradient(colors: [
                                    cfg.accentColor.withOpacity(0.6),
                                    cfg.accentColor.withOpacity(0.3)
                                  ])
                                : null,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                  color: cfg.accentColor.withOpacity(0.35),
                                  blurRadius: 0,
                                  offset: const Offset(0, 3)),
                              BoxShadow(
                                  color: cfg.accentColor.withOpacity(0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 5)),
                              const BoxShadow(
                                  color: Colors.white,
                                  blurRadius: 3,
                                  offset: Offset(0, -1)),
                            ],
                            border: Border.all(
                                color: Colors.white.withOpacity(0.6),
                                width: 1.5),
                          ),
                          child: widget.providerPhoto != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: Image.memory(widget.providerPhoto!,
                                      width: 48, height: 48, fit: BoxFit.cover))
                              : Consumer(builder: (context, ref, _) {
                                  final providerUser = o.providerId.isNotEmpty
                                      ? ref
                                          .watch(userByIdProvider(o.providerId))
                                          .valueOrNull
                                      : null;
                                  return ProfileAvatarImage(
                                    imageUrl: providerUser?.avatar,
                                    size: 48,
                                    borderRadius: 15,
                                    fallbackText: o.providerName,
                                    fallbackTextStyle: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white),
                                  );
                                }),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(o.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: CustomerColors.darkest,
                                      letterSpacing: -0.3)),
                              const SizedBox(height: 3),
                              Text(o.providerName,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: CustomerColors.mid,
                                      fontWeight: FontWeight.w500)),
                            ])),
                        const SizedBox(width: 8),
                        // Status badge 3D
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: cfg.bg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: cfg.accentColor.withOpacity(0.3)),
                            boxShadow: [
                              BoxShadow(
                                  color: cfg.accentColor.withOpacity(0.20),
                                  blurRadius: 0,
                                  offset: const Offset(0, 2)),
                              BoxShadow(
                                  color: cfg.accentColor.withOpacity(0.10),
                                  blurRadius: 6,
                                  offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(cfg.icon, size: 11, color: cfg.text),
                            const SizedBox(width: 4),
                            Text(widget.statusLabel,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: cfg.text,
                                    fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ]),

                      const SizedBox(height: 12),
                      // Divider gradient
                      Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.transparent,
                              cfg.accentColor.withOpacity(0.25),
                              Colors.transparent
                            ]),
                          )),
                      const SizedBox(height: 10),

                      // Description preview
                      Text(o.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              color: CustomerColors.mid.withOpacity(0.8),
                              height: 1.4)),
                      const SizedBox(height: 10),

                      // ── Order ID row ──────────────────────────────────────────
                      _OrderIdRow(orderId: o.id, accentColor: cfg.accentColor),
                      const SizedBox(height: 10),

                      // ── Progress bar ──────────────────────────────────────────
                      _OrderProgressBar(
                          status: o.status, accentColor: cfg.accentColor),
                      const SizedBox(height: 10),

                      // Info chips row
                      Row(children: [
                        _3DInfoChip(
                            icon: Icons.calendar_today_outlined,
                            label:
                                '${o.serviceDate.day}/${o.serviceDate.month}/${o.serviceDate.year}',
                            color: cfg.accentColor),
                        if (o.area.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _3DInfoChip(
                              icon: Icons.location_on_outlined,
                              label: o.area,
                              color: cfg.accentColor),
                        ],
                        if (o.priority == OrderPriority.urgent) ...[
                          const SizedBox(width: 6),
                          _3DInfoChip(
                              icon: Icons.priority_high_rounded,
                              label: 'Urgent',
                              color: CustomerColors.error),
                        ],
                        const Spacer(),
                        // Three dots menu
                        _CardThreeDotsMenu(
                          canEdit: widget.canEdit,
                          canCancel: widget.canCancel,
                          hasPhoto:
                              o.photoBytes != null || o.imageUrls.isNotEmpty,
                          isCompleted: o.status == OrderStatus.completed,
                          onPhoto: widget.onPhotoOptions,
                          onEdit: widget.onEdit,
                          onCancel: widget.onCancel,
                          onComplaint: widget.onComplaint,
                          accentColor: cfg.accentColor,
                        ),
                      ]),
                    ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Order ID Row ──────────────────────────────────────────────────────────────
class _OrderIdRow extends StatefulWidget {
  final String orderId;
  final Color accentColor;
  const _OrderIdRow({required this.orderId, required this.accentColor});

  @override
  State<_OrderIdRow> createState() => _OrderIdRowState();
}

class _OrderIdRowState extends State<_OrderIdRow> {
  bool _copied = false;

  void _copyId() async {
    await Clipboard.setData(ClipboardData(text: widget.orderId));
    setState(() => _copied = true);
    await Future.delayed(const Duration(milliseconds: 1600));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final shortId = widget.orderId.length > 8
        ? widget.orderId.substring(0, 8).toUpperCase()
        : widget.orderId.toUpperCase();
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F6FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: widget.accentColor.withOpacity(0.18)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.tag_rounded,
                size: 10, color: widget.accentColor.withOpacity(0.7)),
            const SizedBox(width: 4),
            Text(
              'ID: $shortId',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: CustomerColors.dark,
                letterSpacing: 0.5,
                fontFamily: 'monospace',
              ),
            ),
          ]),
        ),
        const SizedBox(width: 6),
        // Neumorphic copy button
        GestureDetector(
          onTap: _copyId,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFEEEEF5),
              borderRadius: BorderRadius.circular(8),
              boxShadow: _copied
                  ? [
                      const BoxShadow(
                          color: Color(0xFFBEBECF),
                          blurRadius: 2,
                          offset: Offset(1, 1)),
                      const BoxShadow(
                          color: Colors.white,
                          blurRadius: 2,
                          offset: Offset(-1, -1)),
                    ]
                  : [
                      const BoxShadow(
                          color: Color(0xFFBEBECF),
                          blurRadius: 5,
                          offset: Offset(3, 3)),
                      const BoxShadow(
                          color: Colors.white,
                          blurRadius: 5,
                          offset: Offset(-3, -3)),
                    ],
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _copied
                    ? const Icon(Icons.check_rounded,
                        key: ValueKey('check'),
                        size: 14,
                        color: Color(0xFF22C55E))
                    : const Icon(Icons.copy_rounded,
                        key: ValueKey('copy'),
                        size: 14,
                        color: CustomerColors.mid),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Order Progress Bar ────────────────────────────────────────────────────────
class _OrderProgressBar extends StatelessWidget {
  final OrderStatus status;
  final Color accentColor;
  const _OrderProgressBar({required this.status, required this.accentColor});

  double get _progress {
    switch (status) {
      case OrderStatus.pending:
        return 0.20;
      case OrderStatus.inProgress:
        return 0.50;
      case OrderStatus.completed:
        return 1.0;
      case OrderStatus.cancelled:
        return 0.0;
    }
  }

  String get _label {
    switch (status) {
      case OrderStatus.pending:
        return '20%';
      case OrderStatus.inProgress:
        return '50%';
      case OrderStatus.completed:
        return '100%';
      case OrderStatus.cancelled:
        return '0%';
    }
  }

  Color get _barColor {
    switch (status) {
      case OrderStatus.pending:
        return const Color(0xFFF59E0B);
      case OrderStatus.inProgress:
        return const Color(0xFF3B82F6);
      case OrderStatus.completed:
        return const Color(0xFF22C55E);
      case OrderStatus.cancelled:
        return const Color(0xFFEF4444);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progress',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: CustomerColors.mid.withOpacity(0.7),
              ),
            ),
            Text(
              _label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _barColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              height: 6,
              width: constraints.maxWidth,
              decoration: BoxDecoration(
                color: _barColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: _progress),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => Container(
                    width: constraints.maxWidth * value,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        colors: status == OrderStatus.cancelled
                            ? [
                                _barColor.withOpacity(0.3),
                                _barColor.withOpacity(0.1)
                              ]
                            : [_barColor, _barColor.withOpacity(0.6)],
                      ),
                      boxShadow: status == OrderStatus.cancelled
                          ? []
                          : [
                              BoxShadow(
                                color: _barColor.withOpacity(0.4),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ── 3D Info Chip ──────────────────────────────────────────────────────────────
class _3DInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _3DInfoChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.20), width: 1),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.12),
              blurRadius: 0,
              offset: const Offset(0, 2)),
          BoxShadow(
              color: color.withOpacity(0.06),
              blurRadius: 4,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── Card Three Dots Menu (neo floating panel) ─────────────────────────────────
class _CardThreeDotsMenu extends StatefulWidget {
  final bool canEdit;
  final bool canCancel;
  final bool hasPhoto;
  final bool isCompleted;
  final VoidCallback onPhoto;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onComplaint;
  final Color accentColor;
  const _CardThreeDotsMenu({
    required this.canEdit,
    required this.canCancel,
    required this.hasPhoto,
    required this.isCompleted,
    required this.onPhoto,
    required this.onEdit,
    required this.onCancel,
    required this.onComplaint,
    required this.accentColor,
  });

  @override
  State<_CardThreeDotsMenu> createState() => _CardThreeDotsMenuState();
}

class _CardThreeDotsMenuState extends State<_CardThreeDotsMenu>
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

  void _open() {
    HapticFeedback.lightImpact();
    // Build items based on status
    final items = <_CardMenuItemData>[];
    if (widget.canEdit) {
      items.add(_CardMenuItemData(
        icon:
            widget.hasPhoto ? Icons.image_rounded : Icons.add_a_photo_outlined,
        label: widget.hasPhoto ? 'Photo' : 'Add Photo',
        color: CustomerColors.mid,
        onTap: widget.onPhoto,
      ));
      items.add(_CardMenuItemData(
          icon: Icons.edit_outlined,
          label: 'Edit',
          color: const Color(0xFF5555AA),
          onTap: widget.onEdit));
    }
    // Cancel/Delete is Pending-only — not rendered at all for In Progress,
    // rather than shown disabled, so the panel (a plain Column sized to its
    // item count) shrinks with no empty gap.
    if (widget.canCancel) {
      items.add(_CardMenuItemData(
          icon: Icons.close_rounded,
          label: 'Cancel',
          color: CustomerColors.error,
          onTap: widget.onCancel));
    }
    if (widget.isCompleted) {
      items.add(_CardMenuItemData(
          icon: Icons.flag_outlined,
          label: 'Complaint',
          color: const Color(0xFFB45309),
          onTap: widget.onComplaint));
    }
    if (items.isEmpty) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.20),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        // Get card position
        final box = context.findRenderObject() as RenderBox?;
        final pos = box?.localToGlobal(Offset.zero) ?? Offset.zero;
        final size = box?.size ?? Size.zero;

        return Stack(children: [
          Positioned.fill(
              child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(color: Colors.transparent))),
          Positioned(
            right: 16,
            top: pos.dy + size.height - 30,
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(0.3, -0.2), end: Offset.zero)
                  .animate(curved),
              child: FadeTransition(
                opacity: anim,
                child: _CardMenuPanel(items: items),
              ),
            ),
          ),
        ]);
      },
    );
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
        _open();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) =>
            Transform.scale(scale: 1.0 - 0.08 * _ctrl.value, child: child),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFEEEEF5),
            borderRadius: BorderRadius.circular(11),
            boxShadow: const [
              BoxShadow(
                  color: Color(0xFFBEBECF),
                  blurRadius: 0,
                  offset: Offset(0, 3)),
              BoxShadow(
                  color: Color(0xFFBEBECF),
                  blurRadius: 6,
                  offset: Offset(3, 3)),
              BoxShadow(
                  color: Colors.white, blurRadius: 6, offset: Offset(-3, -3)),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
                3,
                (i) => Container(
                      width: 3.5,
                      height: 3.5,
                      margin: const EdgeInsets.symmetric(vertical: 1.2),
                      decoration: BoxDecoration(
                          color: widget.accentColor.withOpacity(0.6),
                          shape: BoxShape.circle),
                    )),
          ),
        ),
      ),
    );
  }
}

class _CardMenuItemData {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _CardMenuItemData(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
}

class _CardMenuPanel extends StatefulWidget {
  final List<_CardMenuItemData> items;
  const _CardMenuPanel({required this.items});

  @override
  State<_CardMenuPanel> createState() => _CardMenuPanelState();
}

class _CardMenuPanelState extends State<_CardMenuPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320))
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: const Color(0xFFEEEEF5),
        boxShadow: const [
          BoxShadow(
              color: Color(0xFFBEBECF), blurRadius: 16, offset: Offset(6, 6)),
          BoxShadow(
              color: Colors.white, blurRadius: 16, offset: Offset(-6, -6)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(widget.items.length, (i) {
          final item = widget.items[i];
          final n = widget.items.length;
          final anim = CurvedAnimation(
            parent: _ctrl,
            curve: Interval(
                (i / n).clamp(0.0, 1.0), ((i + 1) / n).clamp(0.0, 1.0),
                curve: Curves.easeOutBack),
          );
          return AnimatedBuilder(
            animation: anim,
            builder: (_, child) => Opacity(
              opacity: anim.value.clamp(0.0, 1.0),
              child: Transform.scale(
                  scale: 0.6 + 0.4 * anim.value.clamp(0.0, 1.0), child: child),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  item.onTap();
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFEEEEF5),
                    boxShadow: const [
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
                  child: Icon(item.icon, color: item.color, size: 20),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ── ORDER DETAIL SCREEN ───────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════
class _OrderDetailScreen extends ConsumerWidget {
  final OrderModel order;
  final _StatusConfig cfg;
  final String statusLabel;
  final Uint8List? providerPhoto;
  final UserModel provider;
  final AppLocalizations l;
  final VoidCallback onPhotoOptions;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onComplaint;

  const _OrderDetailScreen({
    required this.order,
    required this.cfg,
    required this.statusLabel,
    required this.providerPhoto,
    required this.provider,
    required this.l,
    required this.onPhotoOptions,
    required this.onEdit,
    required this.onCancel,
    required this.onComplaint,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Re-resolve the order from the live Firestore stream by id so this
    // screen (including the photo section) stays in sync after an
    // add/remove — no re-navigation or app restart required. Falls back to
    // the order passed at push time if the stream hasn't emitted yet or the
    // order can no longer be found (e.g. just got deleted).
    final liveOrders = ref.watch(customerFirestoreOrdersProvider).valueOrNull;
    final order = liveOrders?.firstWhere(
          (o) => o.id == this.order.id,
          orElse: () => this.order,
        ) ??
        this.order;
    final providerUserAsync = order.providerId.isNotEmpty
        ? ref.watch(userByIdProvider(order.providerId))
        : const AsyncValue<UserModel?>.data(null);
    final providerUser = providerUserAsync.valueOrNull;

    void showProviderUnavailable() {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Provider profile is unavailable.'),
        behavior: SnackBarBehavior.floating,
      ));
    }

    // Only navigates with a live Firestore UserModel resolved by the order's
    // real providerId — never falls back to name-matching. Any failure mode
    // (no id, doc missing, stream error, or an unsupported role) just shows a
    // SnackBar instead of pushing a screen with incomplete data.
    void openProviderProfile() {
      if (order.providerId.isEmpty ||
          providerUserAsync.hasError ||
          providerUser == null) {
        showProviderUnavailable();
        return;
      }
      if (providerUser.role != UserRole.professional &&
          providerUser.role != UserRole.contractor) {
        showProviderUnavailable();
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ProviderProfileScreen(provider: providerUser)),
      );
    }

    // Edit + Photo remain available for Pending and In Progress; Cancel is
    // Pending-only (matches _OrderCard.build's canEdit/canCancel split).
    final canEdit = order.status != OrderStatus.cancelled &&
        order.status != OrderStatus.completed;
    final canCancel = order.status == OrderStatus.pending;
    final hasPhoto = order.photoBytes != null || order.imageUrls.isNotEmpty;
    final d = order.serviceDate;
    final timeStr =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final dateStr = '${d.day}/${d.month}/${d.year}';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F6FF),
      body: CustomScrollView(
        slivers: [
          // ── AppBar ───────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 110,
            backgroundColor: CustomerColors.dark,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12)),
              child: const BackButton(color: Colors.white),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      CustomerColors.darkest,
                      cfg.accentColor.withOpacity(0.8)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28)),
                ),
                child: SafeArea(
                    child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 44, 20, 16),
                  child: Row(children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: cfg.accentColor.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: cfg.accentColor.withOpacity(0.3),
                              blurRadius: 0,
                              offset: const Offset(0, 3))
                        ],
                      ),
                      child: Icon(cfg.icon, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Order Details',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800)),
                            Container(
                              margin: const EdgeInsets.only(top: 3),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: cfg.bg.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                      color: cfg.accentColor.withOpacity(0.3),
                                      blurRadius: 0,
                                      offset: const Offset(0, 2))
                                ],
                              ),
                              child: Text(statusLabel,
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: cfg.text)),
                            ),
                          ]),
                    ),
                  ]),
                )),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            sliver: SliverToBoxAdapter(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Title card ─────────────────────────────────────────
                    _NeoDetailCard(children: [
                      Row(children: [
                        GestureDetector(
                          onTap: openProviderProfile,
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                cfg.accentColor.withOpacity(0.6),
                                cfg.accentColor.withOpacity(0.3)
                              ]),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                    color: cfg.accentColor.withOpacity(0.40),
                                    blurRadius: 0,
                                    offset: const Offset(0, 4)),
                                BoxShadow(
                                    color: cfg.accentColor.withOpacity(0.20),
                                    blurRadius: 10,
                                    offset: const Offset(0, 6)),
                              ],
                            ),
                            child: providerPhoto != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(15),
                                    child: Image.memory(providerPhoto!,
                                        width: 52,
                                        height: 52,
                                        fit: BoxFit.cover))
                                : ProfileAvatarImage(
                                    imageUrl: providerUser?.avatar,
                                    size: 52,
                                    borderRadius: 15,
                                    fallbackText: order.providerName,
                                    fallbackTextStyle: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(order.title,
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF333355),
                                      letterSpacing: -0.3)),
                              const SizedBox(height: 4),
                              Text(order.providerName,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: CustomerColors.mid,
                                      fontWeight: FontWeight.w500)),
                            ])),
                      ]),
                      const SizedBox(height: 12),
                      Container(
                          height: 1,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.transparent,
                              Color(0xFFD0D0DF),
                              Colors.transparent
                            ]),
                          )),
                      const SizedBox(height: 10),
                      Text(order.description,
                          style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF555577),
                              height: 1.6)),
                    ]),
                    const SizedBox(height: 14),

                    // ── Details rows ────────────────────────────────────────
                    _NeoDetailCard(children: [
                      _NeoDetailRow(
                          icon: Icons.access_time_rounded,
                          label: 'Time',
                          value: timeStr,
                          color: cfg.accentColor),
                      _NeoDivider(),
                      _NeoDetailRow(
                          icon: Icons.calendar_today_rounded,
                          label: 'Date',
                          value: dateStr,
                          color: cfg.accentColor),
                      _NeoDivider(),
                      _NeoDetailRow(
                          icon: Icons.location_on_outlined,
                          label: 'Area',
                          value: order.area,
                          color: cfg.accentColor,
                          trailingIcon: Icons.open_in_new_rounded,
                          onTap: order.area.trim().isEmpty
                              ? null
                              : () => _openMapsForArea(context, order.area)),
                      if (orderHasSelectedServicesDetail(order)) ...[
                        _NeoDivider(),
                        _NeoDetailRow(
                            icon: Icons.build_outlined,
                            label: 'Service',
                            value:
                                '${orderSelectedServicesSummary(order)} · ₪${order.selectedServicePrice?.toStringAsFixed(0) ?? '-'}',
                            color: cfg.accentColor,
                            trailingIcon: Icons.chevron_right_rounded,
                            onTap: () => showSelectedServicesSheet(
                                context: context,
                                order: order,
                                accent: cfg.accentColor,
                                surfaceColor: const Color(0xFFEEEEF5),
                                shadowTint: const Color(0xFFBEBECF))),
                      ],
                      if (order.priority == OrderPriority.urgent) ...[
                        _NeoDivider(),
                        _NeoDetailRow(
                            icon: Icons.priority_high_rounded,
                            label: 'Priority',
                            value: 'Urgent',
                            color: CustomerColors.error),
                      ],
                    ]),
                    const SizedBox(height: 14),

                    // ── Photo ───────────────────────────────────────────────
                    // Prefer the in-memory bytes from the current session; fall
                    // back to the uploaded Storage URL(s) so the photo still
                    // shows after the app restarts or the order is loaded
                    // fresh from Firestore (photoBytes is never persisted).
                    // The first URL is always the cover/preview; multi-image
                    // orders open the same shared gallery used by the Order
                    // Photo sheet instead of a second gallery implementation.
                    if (order.photoBytes != null ||
                        order.imageUrls.isNotEmpty) ...[
                      GestureDetector(
                        onTap: () {
                          if (order.photoBytes != null) {
                            showDialog(
                              context: context,
                              barrierColor: Colors.black.withOpacity(0.85),
                              builder: (ctx) => GestureDetector(
                                  onTap: () => Navigator.pop(ctx),
                                  child: Scaffold(
                                      backgroundColor: Colors.transparent,
                                      body: Center(
                                          child: InteractiveViewer(
                                              child: Image.memory(
                                                  order.photoBytes!,
                                                  fit: BoxFit.contain))))),
                            );
                          } else if (order.imageUrls.length > 1) {
                            _showFullPhotoGallery(context, order.imageUrls);
                          } else {
                            showDialog(
                              context: context,
                              barrierColor: Colors.black.withOpacity(0.85),
                              builder: (ctx) => GestureDetector(
                                  onTap: () => Navigator.pop(ctx),
                                  child: Scaffold(
                                      backgroundColor: Colors.transparent,
                                      body: Center(
                                          child: InteractiveViewer(
                                              child: Image.network(
                                                  order.imageUrls.first,
                                                  fit: BoxFit.contain))))),
                            );
                          }
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Stack(children: [
                            order.photoBytes != null
                                ? Image.memory(order.photoBytes!,
                                    width: double.infinity,
                                    height: 200,
                                    fit: BoxFit.cover)
                                : Image.network(
                                    order.imageUrls.first,
                                    width: double.infinity,
                                    height: 200,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (c, child, progress) =>
                                        progress == null
                                            ? child
                                            : Container(
                                                width: double.infinity,
                                                height: 200,
                                                color: const Color(0xFFE3ECFB),
                                                child: const Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                            strokeWidth: 2)),
                                              ),
                                    errorBuilder: (c, e, st) => Container(
                                      width: double.infinity,
                                      height: 200,
                                      color: const Color(0xFFE3ECFB),
                                      child: const Icon(
                                          Icons.broken_image_outlined,
                                          color: CustomerColors.mid,
                                          size: 36),
                                    ),
                                  ),
                            Positioned(
                                right: 10,
                                bottom: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.55),
                                      borderRadius: BorderRadius.circular(10)),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.zoom_in_rounded,
                                            color: Colors.white, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                            order.imageUrls.length > 1
                                                ? 'View Photos (${order.imageUrls.length})'
                                                : 'View',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600)),
                                      ]),
                                )),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // ── Assigned ────────────────────────────────────────────
                    if (order.status == OrderStatus.inProgress) ...[
                      _NeoDetailCard(children: [
                        const Row(children: [
                          Icon(Icons.verified_user_rounded,
                              size: 14, color: CustomerColors.mid),
                          SizedBox(width: 6),
                          Text('Assigned To',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: CustomerColors.mid,
                                  fontWeight: FontWeight.w600)),
                        ]),
                        const SizedBox(height: 12),
                        if (order.assignedWorkerName != null &&
                            order.assignedWorkerName!.isNotEmpty) ...[
                          _AssignedRow(
                              icon: Icons.business_rounded,
                              label: 'Contractor',
                              value: order.providerName),
                          const SizedBox(height: 8),
                          _AssignedRow(
                              icon: Icons.engineering_rounded,
                              label: 'Worker',
                              value: order.assignedWorkerName!,
                              highlight: true),
                        ] else
                          _AssignedRow(
                              icon: Icons.person_rounded,
                              label: 'Professional',
                              value: order.providerName,
                              highlight: true),
                      ]),
                      const SizedBox(height: 14),
                    ],

                    // ── Cancelled reason ───────────────────────────────────
                    if (order.status == OrderStatus.cancelled &&
                        order.rejectReason != null)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: CustomerColors.error.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: CustomerColors.error.withOpacity(0.2)),
                          boxShadow: [
                            BoxShadow(
                                color: CustomerColors.error.withOpacity(0.08),
                                blurRadius: 0,
                                offset: const Offset(0, 3))
                          ],
                        ),
                        child: Row(children: [
                          const Icon(Icons.info_outline,
                              size: 16, color: CustomerColors.error),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text('Reason: ${order.rejectReason}',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: CustomerColors.error,
                                      fontWeight: FontWeight.w500))),
                        ]),
                      ),

                    // ── Actions ─────────────────────────────────────────────
                    if (canEdit) ...[
                      const SizedBox(height: 20),
                      Row(children: [
                        Expanded(
                            child: _NeoActionBtn(
                                icon: hasPhoto
                                    ? Icons.image_rounded
                                    : Icons.add_a_photo_outlined,
                                label: hasPhoto ? 'Photo' : 'Add Photo',
                                color: CustomerColors.mid,
                                onTap: onPhotoOptions)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _NeoActionBtn(
                                icon: Icons.edit_outlined,
                                label: 'Edit',
                                color: const Color(0xFF5555AA),
                                onTap: onEdit)),
                        // Cancel is Pending-only — omitted entirely (not just
                        // disabled) for In Progress so the row has no empty gap.
                        if (canCancel) ...[
                          const SizedBox(width: 10),
                          Expanded(
                              child: _NeoActionBtn(
                                  icon: Icons.close_rounded,
                                  label: 'Cancel',
                                  color: CustomerColors.error,
                                  onTap: onCancel)),
                        ],
                      ]),
                    ],
                    if (order.status == OrderStatus.completed) ...[
                      const SizedBox(height: 20),
                      _NeoActionBtn(
                          icon: Icons.flag_outlined,
                          label: 'Submit Complaint',
                          color: const Color(0xFFB45309),
                          onTap: onComplaint,
                          fullWidth: true),
                    ],
                  ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Neo Detail Card (inset neomorphism container) ─────────────────────────────
class _NeoDetailCard extends StatelessWidget {
  final List<Widget> children;
  const _NeoDetailCard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Color(0xFFEEEEF5),
          borderRadius: BorderRadius.all(Radius.circular(20)),
          boxShadow: [
            BoxShadow(
                color: Color(0xFFBEBECF), blurRadius: 8, offset: Offset(4, 4)),
            BoxShadow(
                color: Colors.white, blurRadius: 8, offset: Offset(-4, -4)),
          ],
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
}

// ── Neo Detail Row ─────────────────────────────────────────────────────────────
class _NeoDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  // Optional and backward-compatible: rows without onTap render exactly as
  // before. When onTap is set, the whole row becomes tappable and a small
  // trailing icon is shown after the value to make the action visible.
  final VoidCallback? onTap;
  final IconData? trailingIcon;
  const _NeoDetailRow(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color,
      this.onTap,
      this.trailingIcon});

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFEEEEF5),
            boxShadow: const [
              BoxShadow(
                  color: Color(0xFFBEBECF),
                  blurRadius: 5,
                  offset: Offset(2, 2)),
              BoxShadow(
                  color: Colors.white, blurRadius: 5, offset: Offset(-2, -2)),
            ],
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Text(label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF7777AA))),
        const Spacer(),
        Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF333355)))),
        if (onTap != null && trailingIcon != null) ...[
          const SizedBox(width: 6),
          Icon(trailingIcon, size: 14, color: color),
        ],
      ]),
    );
    if (onTap == null) return row;
    return InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(10), child: row);
  }
}

// ── Neo Divider ────────────────────────────────────────────────────────────────
class _NeoDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: [Color(0xFFD0D0DF), Colors.white, Color(0xFFD0D0DF)]),
        ),
      );
}

// ── Neo Action Button (for detail screen) ─────────────────────────────────────
class _NeoActionBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool fullWidth;
  const _NeoActionBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap,
      this.fullWidth = false});

  @override
  State<_NeoActionBtn> createState() => _NeoActionBtnState();
}

class _NeoActionBtnState extends State<_NeoActionBtn>
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
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        _ctrl.forward();
      },
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) =>
            Transform.scale(scale: 1.0 - 0.05 * _ctrl.value, child: child),
        child: Container(
          width: widget.fullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFEEEEF5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: widget.color.withOpacity(0.25), width: 1),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFFBEBECF),
                  blurRadius: 0,
                  offset: const Offset(0, 3)),
              const BoxShadow(
                  color: Color(0xFFBEBECF),
                  blurRadius: 8,
                  offset: Offset(3, 4)),
              const BoxShadow(
                  color: Colors.white, blurRadius: 8, offset: Offset(-3, -3)),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(widget.icon, size: 20, color: widget.color),
            const SizedBox(height: 4),
            Text(widget.label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: widget.color),
                textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ── NEO FORM HELPERS ──────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════
class _NeoLabel extends StatelessWidget {
  final String text;
  const _NeoLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF7777AA))),
      );
}

class _NeoTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  const _NeoTextField(
      {required this.controller, required this.hint, this.maxLines = 1});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFFEEEEF5),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: Color(0xFFBEBECF), blurRadius: 6, offset: Offset(3, 3)),
            BoxShadow(
                color: Colors.white, blurRadius: 6, offset: Offset(-3, -3)),
          ],
        ),
        child: TextField(
          controller: controller,
          maxLines: maxLines,
          cursorColor: const Color(0xFF5555AA),
          style: const TextStyle(fontSize: 14, color: Color(0xFF333355)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFAAAACC), fontSize: 13),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      );
}

class _NeoPickerRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _NeoPickerRow(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFEEEEF5),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                  color: Color(0xFFBEBECF),
                  blurRadius: 5,
                  offset: Offset(3, 3)),
              BoxShadow(
                  color: Colors.white, blurRadius: 5, offset: Offset(-3, -3)),
            ],
          ),
          child: Row(children: [
            Icon(icon, size: 18, color: const Color(0xFF5555AA)),
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF333355),
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: Color(0xFFAAAACC)),
          ]),
        ),
      );
}

class _NeoPriorityButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _NeoPriorityButton(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? color : const Color(0xFFEEEEF5),
            borderRadius: BorderRadius.circular(16),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: color.withOpacity(0.40),
                        blurRadius: 0,
                        offset: const Offset(0, 4)),
                    BoxShadow(
                        color: color.withOpacity(0.20),
                        blurRadius: 10,
                        offset: const Offset(0, 7))
                  ]
                : const [
                    BoxShadow(
                        color: Color(0xFFBEBECF),
                        blurRadius: 5,
                        offset: Offset(3, 3)),
                    BoxShadow(
                        color: Colors.white,
                        blurRadius: 5,
                        offset: Offset(-3, -3)),
                  ],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16, color: selected ? Colors.white : color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : const Color(0xFF333355))),
          ]),
        ),
      );
}

// ── Edit Order — Selected Services tile ─────────────────────────────────────
// Toggleable row for one structured provider service inside the Edit Order
// sheet. Shows a live category badge only when categoryId resolves against
// the already-loaded categoriesProvider snapshot — never guessed/invented.
class _EditServiceTile extends StatelessWidget {
  static const _accent = Color(0xFF5555AA);
  final ServiceModel service;
  final CategoryModel? category;
  final bool isSelected;
  final VoidCallback onTap;
  const _EditServiceTile({
    required this.service,
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cat = category;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFEEEEF5),
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? Border.all(color: _accent, width: 2) : null,
          boxShadow: const [
            BoxShadow(
                color: Color(0xFFBEBECF), blurRadius: 5, offset: Offset(3, 3)),
            BoxShadow(
                color: Colors.white, blurRadius: 5, offset: Offset(-3, -3)),
          ],
        ),
        child: Row(children: [
          Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: _accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF333355))),
                if (cat != null) ...[
                  const SizedBox(height: 2),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    if (cat.icon.trim().isNotEmpty) ...[
                      Text(cat.icon.trim(),
                          style: const TextStyle(fontSize: 10)),
                      const SizedBox(width: 3),
                    ],
                    Flexible(
                      child: Text(AppLocalizations.of(context).get(cat.nameKey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _accent)),
                    ),
                  ]),
                ],
                if (service.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(service.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF9999BB))),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('₪${service.price.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: _accent)),
        ]),
      ),
    );
  }
}

// ── Edit Order — live Total Price banner ────────────────────────────────────
class _EditTotalPriceBanner extends StatelessWidget {
  final double total;
  const _EditTotalPriceBanner({required this.total});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF052659), Color(0xFF0A3D7A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          const Text('Total Price',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const Spacer(),
          Text('₪${total.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
        ]),
      );
}

class _NeoOutlineBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _NeoOutlineBtn({required this.label, required this.onTap});
  @override
  State<_NeoOutlineBtn> createState() => _NeoOutlineBtnState();
}

class _NeoOutlineBtnState extends State<_NeoOutlineBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) => _c.forward(),
        onTapUp: (_) {
          _c.reverse();
          widget.onTap();
        },
        onTapCancel: () => _c.reverse(),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.04 * _c.value, child: child),
          child: Container(
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFEEEEF5),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                  color: const Color(0xFF8888CC).withOpacity(0.4), width: 1.2),
              boxShadow: const [
                BoxShadow(
                    color: Color(0xFFBEBECF),
                    blurRadius: 0,
                    offset: Offset(0, 3)),
                BoxShadow(
                    color: Color(0xFFBEBECF),
                    blurRadius: 8,
                    offset: Offset(3, 3)),
                BoxShadow(
                    color: Colors.white, blurRadius: 8, offset: Offset(-3, -3)),
              ],
            ),
            child: Text(widget.label,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF5555AA))),
          ),
        ),
      );
}

class _NeoSaveBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _NeoSaveBtn({required this.label, required this.onTap});
  @override
  State<_NeoSaveBtn> createState() => _NeoSaveBtnState();
}

class _NeoSaveBtnState extends State<_NeoSaveBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          HapticFeedback.mediumImpact();
          _c.forward();
        },
        onTapUp: (_) {
          _c.reverse();
          widget.onTap();
        },
        onTapCancel: () => _c.reverse(),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.03 * _c.value, child: child),
          child: Container(
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: const LinearGradient(
                  colors: [CustomerColors.darkest, CustomerColors.dark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.40),
                    blurRadius: 0,
                    offset: const Offset(0, 4)),
                BoxShadow(
                    color: CustomerColors.darkest.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 8)),
              ],
            ),
            child: Text(widget.label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
          ),
        ),
      );
}

class _NeoDeleteBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _NeoDeleteBtn({required this.label, required this.onTap});
  @override
  State<_NeoDeleteBtn> createState() => _NeoDeleteBtnState();
}

class _NeoDeleteBtnState extends State<_NeoDeleteBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          HapticFeedback.mediumImpact();
          _c.forward();
        },
        onTapUp: (_) {
          _c.reverse();
          widget.onTap();
        },
        onTapCancel: () => _c.reverse(),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.03 * _c.value, child: child),
          child: Container(
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: const LinearGradient(
                  colors: [Color(0xFF8B0000), CustomerColors.error],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 0,
                    offset: const Offset(0, 4)),
                BoxShadow(
                    color: CustomerColors.error.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 8)),
              ],
            ),
            child: Text(widget.label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
          ),
        ),
      );
}

// ── Neo Photo Tile ─────────────────────────────────────────────────────────────
class _NeoPhotoTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _NeoPhotoTile(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
  @override
  State<_NeoPhotoTile> createState() => _NeoPhotoTileState();
}

class _NeoPhotoTileState extends State<_NeoPhotoTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          _c.forward();
        },
        onTapUp: (_) {
          _c.reverse();
          widget.onTap();
        },
        onTapCancel: () => _c.reverse(),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.03 * _c.value, child: child),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFEEEEF5),
              borderRadius: BorderRadius.circular(18),
              border:
                  Border.all(color: widget.color.withOpacity(0.20), width: 1),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFFBEBECF),
                    blurRadius: 0,
                    offset: const Offset(0, 3)),
                const BoxShadow(
                    color: Color(0xFFBEBECF),
                    blurRadius: 6,
                    offset: Offset(3, 3)),
                const BoxShadow(
                    color: Colors.white, blurRadius: 6, offset: Offset(-3, -3)),
              ],
            ),
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEEEEF5),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0xFFBEBECF),
                        blurRadius: 5,
                        offset: Offset(2, 2)),
                    BoxShadow(
                        color: Colors.white,
                        blurRadius: 5,
                        offset: Offset(-2, -2)),
                  ],
                ),
                child: Icon(widget.icon, color: widget.color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(widget.label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: widget.color))),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: widget.color.withOpacity(0.5), size: 14),
            ]),
          ),
        ),
      );
}
