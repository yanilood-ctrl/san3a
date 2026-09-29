import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/presentation/providers/app_providers.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../../shared/widgets/customer_details_sheet.dart';
import '../../../../shared/widgets/selected_services_sheet.dart';
import 'contractor_chat_screen.dart';
import '../theme/contractor_design.dart';

Future<void> _openMapsForAddress(BuildContext context, String area) async {
  if (area.trim().isEmpty) return;
  final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(area)}');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// ── Contractor Navy Palette ────────────────────────────────────────────────────
class _CB {
  static const darkest = ContractorColors.darkest;
  static const dark = ContractorColors.dark;
  static const mid = ContractorColors.mid;
  static const light = ContractorColors.light;
  static const bg = Color(0xFFF6EFE6); // neo base
}

// ── Accent by status ──────────────────────────────────────────────────────────
Color _accentForStatus(OrderStatus s) {
  switch (s) {
    case OrderStatus.pending:
      return const Color(0xFFF59E0B);
    case OrderStatus.inProgress:
      return const Color(0xFF26A69A);
    case OrderStatus.completed:
      return const Color(0xFF22C55E);
    case OrderStatus.cancelled:
      return const Color(0xFFEF4444);
  }
}

IconData _iconForStatus(OrderStatus s) {
  switch (s) {
    case OrderStatus.pending:
      return Icons.hourglass_top_rounded;
    case OrderStatus.inProgress:
      return Icons.autorenew_rounded;
    case OrderStatus.completed:
      return Icons.check_circle_rounded;
    case OrderStatus.cancelled:
      return Icons.cancel_rounded;
  }
}

String _labelForStatus(OrderStatus s, AppLocalizations l) {
  switch (s) {
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

// ════════════════════════════════════════════════════════════════════════════
// Main Screen
// ════════════════════════════════════════════════════════════════════════════
class ContractorOrderDetailScreen extends ConsumerWidget {
  final OrderModel order;
  const ContractorOrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final orders = ref.watch(ordersProvider);
    final liveOrder =
        orders.firstWhere((o) => o.id == order.id, orElse: () => order);
    // Read-only display list of every currently assigned worker — the new
    // multi-worker snapshot list, or (for a legacy order that predates it) a
    // single-entry list built from the legacy assignedWorkerId/Name/Specialty
    // fields. Never sourced from the DummyData-backed workersProvider.
    final assignedWorkerRows = liveOrder.assignedWorkers.isNotEmpty
        ? liveOrder.assignedWorkers
        : (liveOrder.assignedWorkerId != null &&
                liveOrder.assignedWorkerId!.isNotEmpty
            ? [
                AssignedWorkerSnapshot(
                  id: liveOrder.assignedWorkerId!,
                  name: liveOrder.assignedWorkerName ?? '',
                  specialties: (liveOrder.assignedWorkerSpecialty != null &&
                          liveOrder.assignedWorkerSpecialty!.isNotEmpty)
                      ? [liveOrder.assignedWorkerSpecialty!]
                      : const [],
                )
              ]
            : const <AssignedWorkerSnapshot>[]);
    // Live worker status (Available/Busy/Offline) for each row, resolved
    // from the real contractor_workers stream — null when the worker was
    // since deleted, in which case the status badge is simply omitted.
    final liveWorkersById = {
      for (final w in ref.watch(contractorWorkersStreamProvider).valueOrNull ??
          const <WorkerModel>[])
        w.id: w
    };

    final accent = _accentForStatus(liveOrder.status);
    final customerUser = liveOrder.customerId.isNotEmpty
        ? ref.watch(userByIdProvider(liveOrder.customerId)).valueOrNull
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F1),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── AppBar ──────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 130,
            backgroundColor: _CB.darkest,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: _ContrDetailBackBtn(),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _ContrComplaintButton(
                  onTap: () => _showComplaintSheet(context, ref, liveOrder, l),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  // Contractor brand gradient — onBrand ink, not white.
                  gradient: ContractorColors.brandGradient,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: SafeArea(
                    child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(
                                    color: accent.withOpacity(0.55))),
                            child: Icon(_iconForStatus(liveOrder.status),
                                color: ContractorColors.onBrand, size: 18),
                          ),
                          const SizedBox(width: 12),
                          const Text('Order Details',
                              style: TextStyle(
                                  color: ContractorColors.onBrand,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5)),
                        ]),
                        const SizedBox(height: 3),
                        Text(
                          '${liveOrder.area} • ${liveOrder.serviceDate.day}/${liveOrder.serviceDate.month}/${liveOrder.serviceDate.year}',
                          style: const TextStyle(
                              color: ContractorColors.onBrandMuted,
                              fontSize: 13),
                        ),
                      ]),
                )),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Customer Card ────────────────────────────────────────
                _ContrDetailSection(children: [
                  Row(children: [
                    GestureDetector(
                      onTap: () =>
                          _showCustomerProfileSheet(context, liveOrder),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [accent, accent.withOpacity(0.6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                                color: accent.withOpacity(0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 4))
                          ],
                          border: Border.all(
                              color: Colors.white.withOpacity(0.6), width: 1.5),
                        ),
                        child: Stack(children: [
                          ProfileAvatarImage(
                            imageUrl: customerUser?.avatar,
                            size: 52,
                            borderRadius: 15,
                            fallbackText: liveOrder.customerName.isNotEmpty
                                ? liveOrder.customerName
                                : 'C',
                            fallbackTextStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 17,
                              height: 17,
                              decoration: BoxDecoration(
                                color: _CB.bg,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                      color: _CB.mid.withOpacity(0.3),
                                      blurRadius: 3,
                                      offset: const Offset(1, 1))
                                ],
                              ),
                              child: const Icon(Icons.person_search_rounded,
                                  size: 9, color: Color(0xFF4A3427)),
                            ),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(
                              liveOrder.customerName.isNotEmpty
                                  ? liveOrder.customerName
                                  : 'Customer',
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: _CB.darkest)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: accent.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(20)),
                            child: Text('Customer',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: accent,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ])),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _CB.bg,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: _CB.mid.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(2, 2)),
                          const BoxShadow(
                              color: Colors.white,
                              blurRadius: 4,
                              offset: Offset(-2, -2)),
                        ],
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_iconForStatus(liveOrder.status),
                            size: 12, color: accent),
                        const SizedBox(width: 5),
                        Text(_labelForStatus(liveOrder.status, l),
                            style: TextStyle(
                                fontSize: 11,
                                color: accent,
                                fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  ]),
                  if (liveOrder.priority == OrderPriority.urgent) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: _CB.bg,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: _CB.mid.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(2, 2)),
                          const BoxShadow(
                              color: Colors.white,
                              blurRadius: 4,
                              offset: Offset(-2, -2)),
                        ],
                      ),
                      child: const Row(children: [
                        Icon(Icons.priority_high_rounded,
                            size: 15, color: Color(0xFFEF4444)),
                        SizedBox(width: 6),
                        Text('Urgent Priority',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFEF4444))),
                      ]),
                    ),
                  ],
                ]),
                const SizedBox(height: 16),

                // ── Title + Description ──────────────────────────────────
                _ContrDetailSection(children: [
                  Text(liveOrder.title,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _CB.darkest,
                          letterSpacing: -0.3)),
                  const SizedBox(height: 8),
                  Text(liveOrder.description,
                      style: TextStyle(
                          fontSize: 13,
                          color: _CB.dark.withOpacity(0.8),
                          height: 1.6)),
                ]),
                const SizedBox(height: 16),

                // ── Details rows ─────────────────────────────────────────
                _ContrDetailContainer(children: [
                  _ContrDetailRow(
                      icon: Icons.person_outline_rounded,
                      label: l.get('name'),
                      value: liveOrder.customerName.isNotEmpty
                          ? liveOrder.customerName
                          : 'Customer'),
                  _ContrDetailDivider(),
                  _ContrDetailRow(
                      icon: Icons.location_on_outlined,
                      label: l.get('area_or_city'),
                      value: liveOrder.area,
                      accentColor: _CB.dark,
                      onTap: () =>
                          _openMapsForAddress(context, liveOrder.area)),
                  _ContrDetailDivider(),
                  _ContrDetailRow(
                      icon: Icons.calendar_today_outlined,
                      label: l.get('order_date'),
                      value:
                          '${liveOrder.serviceDate.day}/${liveOrder.serviceDate.month}/${liveOrder.serviceDate.year}'),
                  _ContrDetailDivider(),
                  _ContrDetailRow(
                      icon: Icons.access_time_outlined,
                      label: l.get('response_time'),
                      value:
                          '${liveOrder.serviceDate.hour.toString().padLeft(2, '0')}:${liveOrder.serviceDate.minute.toString().padLeft(2, '0')}'),
                  if (orderHasSelectedServicesDetail(liveOrder)) ...[
                    _ContrDetailDivider(),
                    _ContrDetailRow(
                        icon: Icons.build_circle_outlined,
                        label: l.get('services'),
                        value: orderSelectedServicesSummary(liveOrder),
                        accentColor: _CB.dark,
                        trailingIcon: Icons.chevron_right_rounded,
                        onTap: () => _showSelectedServicesSheet(
                            context, liveOrder, accent)),
                  ],
                  if (liveOrder.selectedServicePrice != null) ...[
                    _ContrDetailDivider(),
                    _ContrDetailRow(
                        icon: Icons.payments_outlined,
                        label: l.get('price_ils'),
                        value:
                            '₪${liveOrder.selectedServicePrice!.toStringAsFixed(0)}',
                        accentColor: const Color(0xFF22C55E)),
                  ],
                ]),
                const SizedBox(height: 16),

                // ── Photo / Attachment ────────────────────────────────────
                if (liveOrder.imageUrls.isNotEmpty) ...[
                  _ContrOrderPhotoSection(imageUrl: liveOrder.imageUrls.first),
                  const SizedBox(height: 16),
                ],

                // ── Assigned Worker(s) — read-only list ──────────────────
                if (assignedWorkerRows.isNotEmpty) ...[
                  _ContrDetailSection(children: [
                    Row(children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [_CB.darkest, _CB.dark]),
                          borderRadius: BorderRadius.circular(11),
                          boxShadow: [
                            BoxShadow(
                                color: _CB.dark.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 3))
                          ],
                        ),
                        child: const Icon(Icons.engineering_rounded,
                            color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Text(
                          assignedWorkerRows.length > 1
                              ? 'Assigned Workers'
                              : 'Assigned Worker',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _CB.darkest)),
                    ]),
                    const SizedBox(height: 14),
                    for (final row in assignedWorkerRows) ...[
                      Builder(builder: (_) {
                        final liveWorker = liveWorkersById[row.id];
                        final isAvail =
                            liveWorker?.status == WorkerStatus.available;
                        final specialty = row.specialties.isNotEmpty
                            ? l.get(row.specialties.first)
                            : '';
                        return Container(
                          margin: EdgeInsets.only(
                              bottom: row == assignedWorkerRows.last ? 0 : 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _CB.bg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _CB.mid.withOpacity(0.3)),
                            boxShadow: [
                              BoxShadow(
                                  color: _CB.mid.withOpacity(0.2),
                                  blurRadius: 6,
                                  offset: const Offset(3, 3)),
                              const BoxShadow(
                                  color: Colors.white,
                                  blurRadius: 6,
                                  offset: Offset(-3, -3)),
                            ],
                          ),
                          child: Row(children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                    colors: [_CB.darkest, _CB.dark]),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Center(
                                  child: Text(
                                      row.name.isNotEmpty
                                          ? row.name[0].toUpperCase()
                                          : 'W',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(row.name,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: _CB.darkest)),
                                  if (specialty.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(specialty,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: _CB.dark.withOpacity(0.8))),
                                  ],
                                ])),
                            if (liveWorker != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (isAvail
                                          ? const Color(0xFF22C55E)
                                          : const Color(0xFFF59E0B))
                                      .withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isAvail ? 'Available' : 'Busy',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isAvail
                                        ? const Color(0xFF22C55E)
                                        : const Color(0xFFF59E0B),
                                  ),
                                ),
                              ),
                          ]),
                        );
                      }),
                    ],
                  ]),
                  const SizedBox(height: 16),
                ],

                // ── Cancelled Reason ─────────────────────────────────────
                if (liveOrder.status == OrderStatus.cancelled &&
                    liveOrder.rejectReason != null) ...[
                  _ContrDetailSection(
                    borderColor: const Color(0xFFEF4444),
                    children: [
                      Row(children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _CB.bg,
                            borderRadius: BorderRadius.circular(11),
                            boxShadow: [
                              BoxShadow(
                                  color: _CB.mid.withOpacity(0.3),
                                  blurRadius: 5,
                                  offset: const Offset(2, 2)),
                              const BoxShadow(
                                  color: Colors.white,
                                  blurRadius: 5,
                                  offset: Offset(-2, -2)),
                            ],
                          ),
                          child: const Icon(Icons.cancel_outlined,
                              size: 18, color: Color(0xFFEF4444)),
                        ),
                        const SizedBox(width: 12),
                        const Text('Cancellation Reason',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFEF4444))),
                      ]),
                      const SizedBox(height: 10),
                      Text(liveOrder.rejectReason!,
                          style: TextStyle(
                              fontSize: 13,
                              color: _CB.dark.withOpacity(0.8),
                              height: 1.5)),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                const SizedBox(height: 12),

                // ── Action Buttons ───────────────────────────────────────
                if (liveOrder.status == OrderStatus.pending) ...[
                  _ContrActionBtn(
                    label: l.get('send_message'),
                    icon: Icons.chat_bubble_outline_rounded,
                    filled: false,
                    color: const Color(0xFF26A69A),
                    onTap: () => _openChat(context, ref, liveOrder),
                  ),
                  const SizedBox(height: 12),
                  _ContrActionBtn(
                    label: l.get('reject'),
                    icon: Icons.close_rounded,
                    filled: false,
                    color: const Color(0xFFEF4444),
                    onTap: () => _showCancelDialog(context, ref, l, liveOrder),
                  ),
                  const SizedBox(height: 12),
                  _ContrActionBtn(
                    label: 'Accept & Assign Worker',
                    icon: Icons.engineering_rounded,
                    filled: true,
                    color: _CB.dark,
                    onTap: () => _showAssignSheet(context, ref, liveOrder),
                  ),
                ],
                if (liveOrder.status == OrderStatus.inProgress) ...[
                  _ContrActionBtn(
                    label: l.get('send_message'),
                    icon: Icons.chat_bubble_outline_rounded,
                    filled: false,
                    color: const Color(0xFF26A69A),
                    onTap: () => _openChat(context, ref, liveOrder),
                  ),
                  const SizedBox(height: 12),
                  _ContrActionBtn(
                    label: 'Manage Assigned Workers',
                    icon: Icons.engineering_rounded,
                    filled: false,
                    color: _CB.dark,
                    onTap: () => _showAssignSheet(context, ref, liveOrder),
                  ),
                  const SizedBox(height: 12),
                  _ContrActionBtn(
                    label: l.get('cancel'),
                    icon: Icons.close_rounded,
                    filled: false,
                    color: const Color(0xFFEF4444),
                    onTap: () => _showCancelDialog(context, ref, l, liveOrder),
                  ),
                  const SizedBox(height: 12),
                  _ContrActionBtn(
                    label: l.get('completed'),
                    icon: Icons.check_circle_outline_rounded,
                    filled: true,
                    color: const Color(0xFF22C55E),
                    onTap: () => _completeOrder(context, ref, l, liveOrder),
                  ),
                  if (assignedWorkerRows.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _ContrActionBtn(
                      label: 'Unassign All & Return to Pending',
                      icon: Icons.person_remove_alt_1_rounded,
                      filled: false,
                      color: const Color(0xFFEF4444),
                      onTap: () =>
                          _showUnassignAllDialog(context, ref, liveOrder),
                    ),
                  ],
                ],
                if (liveOrder.status == OrderStatus.completed ||
                    liveOrder.status == OrderStatus.cancelled) ...[
                  _ContrActionBtn(
                    label: l.get('send_message'),
                    icon: Icons.chat_bubble_outline_rounded,
                    filled: false,
                    color: _CB.dark,
                    onTap: () => _openChat(context, ref, liveOrder),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _openChat(BuildContext context, WidgetRef ref, OrderModel o) {
    final customer = UserModel(
      id: o.customerId,
      fullName: o.customerName.isNotEmpty ? o.customerName : 'Customer',
      email: '',
      phone: '',
      city: o.area,
      role: UserRole.customer,
    );
    ref.read(conversationsProvider.notifier).startConversation(customer);
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ContractorChatScreen(otherUser: customer)));
  }

  void _showCustomerProfileSheet(BuildContext context, OrderModel o) {
    final accent = _accentForStatus(o.status);
    showCustomerDetailsSheet(
      context: context,
      order: o,
      accent: accent,
      surfaceColor: _CB.bg,
      shadowTint: _CB.mid,
    );
  }

  void _showSelectedServicesSheet(
      BuildContext context, OrderModel o, Color accent) {
    showSelectedServicesSheet(
      context: context,
      order: o,
      accent: accent,
      surfaceColor: _CB.bg,
      shadowTint: _CB.mid,
    );
  }

  // Complete (inProgress → completed). Single source of truth shared with the
  // Contractor order card's three-dot "Complete" action
  // (contractor_home_screen.dart's _ContrOrderCardDotsMenu): the Firestore
  // writer completeContractorOrderInFirestore plus the customer
  // notification. The visible button previously called
  // ordersProvider.updateStatus(), which only mutates the in-memory
  // DummyData-seeded list and never reaches Firestore, so the completion was
  // never persisted. The screen is popped only after the write succeeds.
  Future<void> _completeOrder(BuildContext context, WidgetRef ref,
      AppLocalizations l, OrderModel order) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (order.status != OrderStatus.inProgress) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Only in-progress orders can be completed.'),
          behavior: SnackBarBehavior.fixed));
      return;
    }
    try {
      await ref
          .read(ordersProvider.notifier)
          .completeContractorOrderInFirestore(order.id);
      createOrderNotification(
        userId: order.customerId,
        title: 'Order Completed',
        message: 'Your order was completed successfully.',
        orderId: order.id,
      );
      if (navigator.canPop()) navigator.pop();
      messenger.showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(l.get('order_completed')),
          ]),
          backgroundColor: const Color(0xFF22C55E),
          behavior: SnackBarBehavior.fixed));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Failed to complete order. Please try again.'),
          behavior: SnackBarBehavior.fixed));
    }
  }

  // Reject/Cancel. Takes the full order (not just its id) so the Firestore
  // write and the customer notification both target the right order — the
  // same pair the Contractor order card's three-dot "Cancel" action performs
  // via _showCancelSheet in contractor_home_screen.dart. Previously called
  // the in-memory-only ordersProvider.cancelOrder(), so the cancellation was
  // never persisted and the customer was never notified.
  void _showCancelDialog(BuildContext context, WidgetRef ref,
      AppLocalizations l, OrderModel order) {
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: _CB.bg,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                  color: _CB.mid.withOpacity(0.3),
                  blurRadius: 24,
                  offset: const Offset(10, 10)),
              const BoxShadow(
                  color: Colors.white,
                  blurRadius: 24,
                  offset: Offset(-10, -10)),
            ],
          ),
          child: Form(
            key: formKey,
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 14),
                  Center(
                      child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                              color: _CB.mid.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(3)))),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Row(children: [
                      Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _CB.bg,
                              boxShadow: [
                                BoxShadow(
                                    color: _CB.mid.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(4, 4)),
                                const BoxShadow(
                                    color: Colors.white,
                                    blurRadius: 10,
                                    offset: Offset(-4, -4))
                              ]),
                          child: const Icon(Icons.cancel_outlined,
                              color: Color(0xFFEF4444), size: 24)),
                      const SizedBox(width: 16),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(l.get('cancel_reason'),
                                style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                    color: _CB.darkest,
                                    letterSpacing: -0.3)),
                            const SizedBox(height: 2),
                            Text(l.get('enter_cancel_reason'),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: _CB.dark.withOpacity(0.8))),
                          ])),
                    ]),
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: _ContrNeoTextField(
                      controller: ctrl,
                      hint: '${l.get("cancel_reason")}...',
                      icon: Icons.info_outline_rounded,
                      maxLines: 3,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Row(children: [
                      Expanded(
                          child: _ContrActionBtn(
                        label: l.get('back'),
                        icon: Icons.arrow_back_rounded,
                        filled: false,
                        color: _CB.dark,
                        onTap: () => Navigator.pop(ctx),
                      )),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _ContrActionBtn(
                        label: l.get('confirm_cancel'),
                        icon: Icons.close_rounded,
                        filled: true,
                        color: const Color(0xFFEF4444),
                        onTap: () async {
                          if (!formKey.currentState!.validate()) return;
                          final reason = ctrl.text.trim();
                          final messenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(context);
                          try {
                            await ref
                                .read(ordersProvider.notifier)
                                .rejectContractorOrderInFirestore(
                                  orderId: order.id,
                                  reason: reason.isEmpty ? null : reason,
                                );
                            createOrderNotification(
                              userId: order.customerId,
                              title: 'Order Rejected',
                              message: 'Your order was rejected.',
                              orderId: order.id,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (navigator.canPop()) navigator.pop();
                            messenger.showSnackBar(const SnackBar(
                                content: Text('Order rejected successfully'),
                                backgroundColor: Color(0xFFEF4444),
                                behavior: SnackBarBehavior.fixed));
                          } catch (_) {
                            messenger.showSnackBar(const SnackBar(
                                content: Text(
                                    'Failed to reject order. Please try again.'),
                                behavior: SnackBarBehavior.fixed));
                          }
                        },
                      )),
                    ]),
                  ),
                  const SizedBox(height: 28),
                ]),
          ),
        ),
      ),
    );
  }

  void _showAssignSheet(BuildContext context, WidgetRef ref, OrderModel o) {
    final workers = ref.read(contractorWorkersStreamProvider).valueOrNull ??
        const <WorkerModel>[];
    if (workers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No workers available — add workers first')));
      return;
    }
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _ContrAssignWorkerScreen(order: o, ref: ref),
        ));
  }
}

void _showUnassignAllDialog(
    BuildContext context, WidgetRef ref, OrderModel order) {
  bool saving = false;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: _CB.bg,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                    color: _CB.mid.withOpacity(0.3),
                    blurRadius: 24,
                    offset: const Offset(10, 10)),
                const BoxShadow(
                    color: Colors.white,
                    blurRadius: 24,
                    offset: Offset(-10, -10)),
              ],
            ),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 14),
                  Center(
                      child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                              color: _CB.mid.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(3)))),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Row(children: [
                      Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _CB.bg,
                              boxShadow: [
                                BoxShadow(
                                    color: _CB.mid.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(4, 4)),
                                const BoxShadow(
                                    color: Colors.white,
                                    blurRadius: 10,
                                    offset: Offset(-4, -4))
                              ]),
                          child: const Icon(Icons.person_remove_alt_1_rounded,
                              color: Color(0xFFEF4444), size: 24)),
                      const SizedBox(width: 16),
                      const Expanded(
                          child: Text('Unassign All & Return to Pending',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: _CB.darkest,
                                  letterSpacing: -0.3))),
                    ]),
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Text(
                      'All assigned workers will be removed and this order '
                      'will return to Pending. You will need to accept and '
                      'assign it again.',
                      style: TextStyle(
                          fontSize: 13,
                          color: _CB.dark.withOpacity(0.8),
                          height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Column(children: [
                      _ContrActionBtn(
                        label: 'Keep Assignment',
                        icon: Icons.arrow_back_rounded,
                        filled: false,
                        color: _CB.dark,
                        onTap: () => Navigator.pop(ctx),
                      ),
                      const SizedBox(height: 12),
                      _ContrActionBtn(
                        label: saving
                            ? 'Unassigning...'
                            : 'Unassign & Return to Pending',
                        icon: Icons.person_remove_alt_1_rounded,
                        filled: true,
                        color: const Color(0xFFEF4444),
                        onTap: () async {
                          if (saving) return;
                          setSheetState(() => saving = true);
                          final navigator = Navigator.of(ctx);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await ref
                                .read(ordersProvider.notifier)
                                .unassignAllWorkersAndReturnToPendingInFirestore(
                                    order.id);
                            navigator.pop();
                            if (context.mounted) {
                              messenger.showSnackBar(const SnackBar(
                                  content: Text(
                                      'Workers unassigned. Order returned to Pending.'),
                                  behavior: SnackBarBehavior.fixed));
                            }
                          } catch (_) {
                            setSheetState(() => saving = false);
                            if (context.mounted) {
                              messenger.showSnackBar(const SnackBar(
                                  content: Text(
                                      'Failed to unassign workers. Please try again.'),
                                  behavior: SnackBarBehavior.fixed));
                            }
                          }
                        },
                      ),
                    ]),
                  ),
                  const SizedBox(height: 28),
                ]),
          ),
        );
      },
    ),
  );
}

void _showComplaintSheet(
    BuildContext context, WidgetRef ref, OrderModel o, AppLocalizations l) {
  final formKey = GlobalKey<FormState>();
  final titleCtrl = TextEditingController(text: 'Complaint: ${o.title}');
  final descCtrl = TextEditingController();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _CB.bg,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
                color: _CB.mid.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(8, 8)),
            const BoxShadow(
                color: Colors.white, blurRadius: 20, offset: Offset(-8, -8)),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Form(
          key: formKey,
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                            color: _CB.mid.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: const [
                              BoxShadow(
                                  color: Colors.white,
                                  blurRadius: 2,
                                  offset: Offset(-1, -1)),
                              BoxShadow(
                                  color: Color(0xFFD9C6B2),
                                  blurRadius: 2,
                                  offset: Offset(1, 1))
                            ]))),
                const SizedBox(height: 20),
                Row(children: [
                  Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _CB.bg,
                          boxShadow: [
                            BoxShadow(
                                color: _CB.mid.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(4, 4)),
                            const BoxShadow(
                                color: Colors.white,
                                blurRadius: 8,
                                offset: Offset(-4, -4))
                          ]),
                      child: const Icon(Icons.flag_rounded,
                          color: Color(0xFFEF4444), size: 22)),
                  const SizedBox(width: 14),
                  const Text('Submit Complaint',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _CB.darkest)),
                ]),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: _CB.bg,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: _CB.mid.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(3, 3)),
                        const BoxShadow(
                            color: Colors.white,
                            blurRadius: 6,
                            offset: Offset(-3, -3))
                      ]),
                  child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: Color(0xFFEF4444), size: 18),
                        SizedBox(width: 10),
                        Expanded(
                            child: Text(
                          'Describe your issue clearly. The admin will review and respond soon.',
                          style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF8A7263),
                              height: 1.5),
                        )),
                      ]),
                ),
                const SizedBox(height: 20),
                Text('Subject',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _CB.dark.withOpacity(0.8))),
                const SizedBox(height: 8),
                _ContrNeoTextField(
                    controller: titleCtrl,
                    hint: 'Complaint subject...',
                    icon: Icons.flag_outlined,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null),
                const SizedBox(height: 16),
                Text('Description',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _CB.dark.withOpacity(0.8))),
                const SizedBox(height: 8),
                _ContrNeoTextField(
                    controller: descCtrl,
                    hint: 'Describe the issue in detail...',
                    icon: Icons.description_outlined,
                    maxLines: 3,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null),
                const SizedBox(height: 28),
                _ContrNeoSubmitButton(
                  label: 'Submit Complaint',
                  onTap: () async {
                    if (!formKey.currentState!.validate()) return;
                    final user = ref.read(authProvider);
                    final hasCustomer = o.customerId.isNotEmpty;
                    final complaint = ComplaintModel(
                      id: '',
                      userId: user?.id ?? '',
                      userName: user?.fullName ?? '',
                      complainantRole: 'contractor',
                      type: ComplaintType.order,
                      targetId: o.id,
                      targetName: o.title,
                      targetUserId: hasCustomer ? o.customerId : null,
                      targetUserName: hasCustomer ? o.customerName : null,
                      targetUserRole: hasCustomer ? 'customer' : null,
                      reason: titleCtrl.text.trim(),
                      description: descCtrl.text.trim(),
                      relatedOrderId: o.id,
                      relatedOrderTitle: o.title,
                      sourceContext: 'order_details',
                      createdAt: DateTime.now(),
                    );
                    try {
                      await addComplaintInFirestore(complaint);
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: const Row(children: [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 8),
                              Text('Complaint submitted'),
                            ]),
                            backgroundColor: _CB.dark,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))));
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Failed to submit complaint: $e')));
                      }
                    }
                  },
                ),
              ]),
        ),
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════════
// ── Back Button (Neomorphic)
// ════════════════════════════════════════════════════════════════════════════
class _ContrDetailBackBtn extends StatefulWidget {
  @override
  State<_ContrDetailBackBtn> createState() => _ContrDetailBackBtnState();
}

class _ContrDetailBackBtnState extends State<_ContrDetailBackBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _pressed = false;
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
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          setState(() => _pressed = true);
          _ctrl.forward();
        },
        onTapUp: (_) {
          setState(() => _pressed = false);
          _ctrl.reverse();
          Navigator.of(context).pop();
        },
        onTapCancel: () {
          setState(() => _pressed = false);
          _ctrl.reverse();
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, child) =>
                Transform.scale(scale: 1.0 - 0.07 * _ctrl.value, child: child),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF6EFE6),
                borderRadius: BorderRadius.circular(14),
                boxShadow: _pressed
                    ? const [
                        BoxShadow(
                            color: Color(0xFFD9C6B2),
                            blurRadius: 3,
                            offset: Offset(2, 2)),
                        BoxShadow(
                            color: Colors.white,
                            blurRadius: 3,
                            offset: Offset(-1, -1))
                      ]
                    : const [
                        BoxShadow(
                            color: Color(0xFFD9C6B2),
                            blurRadius: 0,
                            offset: Offset(0, 4)),
                        BoxShadow(
                            color: Color(0xFFD9C6B2),
                            blurRadius: 10,
                            offset: Offset(5, 5)),
                        BoxShadow(
                            color: Colors.white,
                            blurRadius: 10,
                            offset: Offset(-5, -5))
                      ],
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFF4A3427), size: 17),
            ),
          ),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════════════
// ── Complaint Button (Neomorphic)
// ════════════════════════════════════════════════════════════════════════════
class _ContrComplaintButton extends StatefulWidget {
  final VoidCallback onTap;
  const _ContrComplaintButton({required this.onTap});
  @override
  State<_ContrComplaintButton> createState() => _ContrComplaintButtonState();
}

class _ContrComplaintButtonState extends State<_ContrComplaintButton>
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
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          setState(() => _pressed = true);
          _ctrl.forward();
        },
        onTapUp: (_) {
          setState(() => _pressed = false);
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () {
          setState(() => _pressed = false);
          _ctrl.reverse();
        },
        child: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, child) =>
                Transform.scale(scale: 1.0 - 0.07 * _ctrl.value, child: child),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF6EFE6),
                borderRadius: BorderRadius.circular(20),
                boxShadow: _pressed
                    ? const [
                        BoxShadow(
                            color: Color(0xFFD9C6B2),
                            blurRadius: 3,
                            offset: Offset(2, 2)),
                        BoxShadow(
                            color: Colors.white,
                            blurRadius: 3,
                            offset: Offset(-1, -1))
                      ]
                    : const [
                        BoxShadow(
                            color: Color(0xFFD9C6B2),
                            blurRadius: 0,
                            offset: Offset(0, 4)),
                        BoxShadow(
                            color: Color(0xFFD9C6B2),
                            blurRadius: 10,
                            offset: Offset(5, 5)),
                        BoxShadow(
                            color: Colors.white,
                            blurRadius: 10,
                            offset: Offset(-5, -5))
                      ],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.flag_rounded,
                    color: _pressed
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF8A7263),
                    size: 15),
                const SizedBox(width: 6),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 80),
                  style: TextStyle(
                    color: _pressed
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF4A3427),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                  child: const Text('Complaint'),
                ),
              ]),
            ),
          ),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════════════
// ── Detail Section Card
// ════════════════════════════════════════════════════════════════════════════
class _ContrDetailSection extends StatelessWidget {
  final List<Widget> children;
  final Color? borderColor;
  const _ContrDetailSection({required this.children, this.borderColor});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _CB.bg,
          borderRadius: BorderRadius.circular(22),
          border: borderColor != null
              ? Border.all(color: borderColor!.withOpacity(0.3), width: 1.2)
              : null,
          boxShadow: [
            BoxShadow(
                color: _CB.mid.withOpacity(0.25),
                blurRadius: 0,
                offset: const Offset(0, 4)),
            BoxShadow(
                color: _CB.mid.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(5, 5)),
            const BoxShadow(
                color: Colors.white, blurRadius: 12, offset: Offset(-5, -5)),
          ],
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
}

// ════════════════════════════════════════════════════════════════════════════
// ── Detail Container (inset rows)
// ════════════════════════════════════════════════════════════════════════════
// ── Contr Order Photo Section (shows the customer's attached order image) ────
class _ContrOrderPhotoSection extends StatelessWidget {
  final String imageUrl;
  const _ContrOrderPhotoSection({required this.imageUrl});

  @override
  Widget build(BuildContext context) => _ContrDetailSection(children: [
        Row(children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: _CB.bg,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                        color: _CB.mid.withOpacity(0.3),
                        blurRadius: 5,
                        offset: const Offset(2, 2)),
                    const BoxShadow(
                        color: Colors.white,
                        blurRadius: 5,
                        offset: Offset(-2, -2))
                  ]),
              child: Icon(Icons.photo_outlined, size: 18, color: _CB.dark)),
          const SizedBox(width: 12),
          const Text('Attached Photo',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _CB.darkest)),
        ]),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => showDialog(
            context: context,
            barrierColor: Colors.black.withOpacity(0.85),
            builder: (ctx) => GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Scaffold(
                  backgroundColor: Colors.transparent,
                  body: Center(
                      child: InteractiveViewer(
                          child:
                              Image.network(imageUrl, fit: BoxFit.contain)))),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              imageUrl,
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : Container(
                      height: 180,
                      alignment: Alignment.center,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _CB.dark)),
              errorBuilder: (context, error, stack) => Container(
                height: 180,
                alignment: Alignment.center,
                color: _CB.bg,
                child:
                    Icon(Icons.broken_image_outlined, color: _CB.mid, size: 32),
              ),
            ),
          ),
        ),
      ]);
}

class _ContrDetailContainer extends StatelessWidget {
  final List<Widget> children;
  const _ContrDetailContainer({required this.children});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: _CB.bg,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
                color: _CB.mid.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(4, 4)),
            const BoxShadow(
                color: Colors.white, blurRadius: 8, offset: Offset(-4, -4)),
          ],
        ),
        child: Column(children: children),
      );
}

class _ContrDetailRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color? accentColor;
  final VoidCallback? onTap;
  // Shown at the trailing edge only when onTap is set — open_in_new for
  // rows that launch an external app (e.g. Maps), chevron_right for rows
  // that open an in-app details sheet (e.g. Services).
  final IconData trailingIcon;
  const _ContrDetailRow(
      {required this.icon,
      required this.label,
      required this.value,
      this.accentColor,
      this.onTap,
      this.trailingIcon = Icons.open_in_new_rounded});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(children: [
            Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _CB.bg,
                    boxShadow: [
                      BoxShadow(
                          color: _CB.mid.withOpacity(0.3),
                          blurRadius: 5,
                          offset: const Offset(2, 2)),
                      const BoxShadow(
                          color: Colors.white,
                          blurRadius: 5,
                          offset: Offset(-2, -2))
                    ]),
                child: Icon(icon, size: 16, color: const Color(0xFF8A7263))),
            const SizedBox(width: 12),
            Text(label,
                style: const TextStyle(fontSize: 13, color: Color(0xFF8A7263))),
            const Spacer(),
            if (onTap != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: _CB.bg,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                          color: _CB.mid.withOpacity(0.25),
                          blurRadius: 3,
                          offset: const Offset(1, 1)),
                      const BoxShadow(
                          color: Colors.white,
                          blurRadius: 3,
                          offset: Offset(-1, -1))
                    ]),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(value,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: accentColor ?? const Color(0xFF2B1B12))),
                  const SizedBox(width: 4),
                  Icon(trailingIcon,
                      size: 12, color: accentColor ?? const Color(0xFF8A7263)),
                ]),
              )
            else
              Flexible(
                  child: Text(value,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: accentColor ?? const Color(0xFF2B1B12)),
                      overflow: TextOverflow.ellipsis)),
          ]),
        ),
      );
}

class _ContrDetailDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
          _CB.mid.withOpacity(0.15),
          Colors.white,
          _CB.mid.withOpacity(0.15)
        ])),
      );
}

// ════════════════════════════════════════════════════════════════════════════
// ── Action Button
// ════════════════════════════════════════════════════════════════════════════
class _ContrActionBtn extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final Color color;
  final VoidCallback onTap;
  const _ContrActionBtn(
      {required this.label,
      required this.icon,
      required this.filled,
      required this.color,
      required this.onTap});
  @override
  State<_ContrActionBtn> createState() => _ContrActionBtnState();
}

class _ContrActionBtnState extends State<_ContrActionBtn>
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
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          setState(() => _pressed = true);
          _ctrl.forward();
        },
        onTapUp: (_) {
          setState(() => _pressed = false);
          _ctrl.reverse();
          widget.onTap();
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
              gradient: widget.filled
                  ? LinearGradient(
                      colors: [widget.color, widget.color.withOpacity(0.75)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: widget.filled ? null : _CB.bg,
              border: widget.filled
                  ? null
                  : Border.all(
                      color: widget.color.withOpacity(0.5), width: 1.5),
              boxShadow: _pressed
                  ? [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(2, 2))
                    ]
                  : widget.filled
                      ? [
                          BoxShadow(
                              color: widget.color.withOpacity(0.45),
                              blurRadius: 0,
                              offset: const Offset(0, 5)),
                          BoxShadow(
                              color: widget.color.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 8)),
                          BoxShadow(
                              color: Colors.white.withOpacity(0.08),
                              blurRadius: 4,
                              offset: const Offset(0, -2))
                        ]
                      : [
                          BoxShadow(
                              color: _CB.mid.withOpacity(0.25),
                              blurRadius: 0,
                              offset: const Offset(0, 4)),
                          BoxShadow(
                              color: _CB.mid.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(4, 4)),
                          const BoxShadow(
                              color: Colors.white,
                              blurRadius: 8,
                              offset: Offset(-4, -4))
                        ],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(widget.icon,
                  size: 18, color: widget.filled ? Colors.white : widget.color),
              const SizedBox(width: 8),
              Text(widget.label,
                  style: TextStyle(
                      color: widget.filled ? Colors.white : widget.color,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2)),
            ]),
          ),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════════════
// ── Neo Text Field
// ════════════════════════════════════════════════════════════════════════════
class _ContrNeoTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int maxLines;
  final String? Function(String?)? validator;
  const _ContrNeoTextField(
      {required this.controller,
      required this.hint,
      required this.icon,
      this.maxLines = 1,
      this.validator});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: _CB.bg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: _CB.mid.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(3, 3)),
              const BoxShadow(
                  color: Colors.white, blurRadius: 6, offset: Offset(-3, -3))
            ]),
        child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          style: const TextStyle(fontSize: 14, color: Color(0xFF2B1B12)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFBFA88F), fontSize: 13),
            prefixIcon: Icon(icon, color: const Color(0xFF8A7263), size: 20),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════════════
// ── Submit Button
// ════════════════════════════════════════════════════════════════════════════
class _ContrNeoSubmitButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _ContrNeoSubmitButton({required this.label, required this.onTap});
  @override
  State<_ContrNeoSubmitButton> createState() => _ContrNeoSubmitButtonState();
}

class _ContrNeoSubmitButtonState extends State<_ContrNeoSubmitButton>
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
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          HapticFeedback.mediumImpact();
          setState(() => _pressed = true);
          _ctrl.forward();
        },
        onTapUp: (_) {
          setState(() => _pressed = false);
          _ctrl.reverse();
          widget.onTap();
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
                colors: [_CB.darkest, _CB.dark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: _pressed
                  ? [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 4,
                          offset: const Offset(2, 2))
                    ]
                  : [
                      BoxShadow(
                          color: _CB.darkest.withOpacity(0.45),
                          blurRadius: 0,
                          offset: const Offset(0, 5)),
                      BoxShadow(
                          color: _CB.darkest.withOpacity(0.20),
                          blurRadius: 10,
                          offset: const Offset(0, 8)),
                      BoxShadow(
                          color: Colors.white.withOpacity(0.08),
                          blurRadius: 4,
                          offset: const Offset(0, -2))
                    ],
            ),
            child: Center(
                child: Text(widget.label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3))),
          ),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════════════
// ── Assign Worker Screen (Full Page - Professional Design)
// ════════════════════════════════════════════════════════════════════════════
// ── Worker assignment matching helpers (service-specialty filtering) ──────────
// Duplicated (small, per-file) from the same rules used in
// contractor_home_screen.dart's assignment sheet — see that file for the
// full rationale. Normalizes (trim + lowercase) category id/nameKey values.
Set<String> _orderRequiredCategoryKeys(
    OrderModel order, List<CategoryModel> categories) {
  final rawCategoryIds = order.selectedServices
      .map((s) => s.categoryId?.trim())
      .where((id) => id != null && id.isNotEmpty)
      .cast<String>()
      .toSet();
  final keys = <String>{};
  if (rawCategoryIds.isNotEmpty) {
    for (final rawId in rawCategoryIds) {
      final norm = rawId.toLowerCase();
      keys.add(norm);
      for (final c in categories) {
        if (c.id.trim().toLowerCase() == norm) {
          keys.add(c.nameKey.trim().toLowerCase());
          break;
        }
      }
    }
  } else {
    final legacyId = order.categoryId?.trim();
    final legacyKey = order.categoryNameKey?.trim();
    if (legacyId != null && legacyId.isNotEmpty)
      keys.add(legacyId.toLowerCase());
    if (legacyKey != null && legacyKey.isNotEmpty) {
      keys.add(legacyKey.toLowerCase());
    }
  }
  return keys;
}

Set<String> _workerSpecialtyKeys(WorkerModel worker) {
  final raw = worker.specialties.isNotEmpty
      ? worker.specialties
      : (worker.specialty.isNotEmpty ? [worker.specialty] : const <String>[]);
  return raw
      .map((s) => s.trim().toLowerCase())
      .where((s) => s.isNotEmpty)
      .toSet();
}

/// A worker is suitable when it matches at least one of the order's
/// required categories — never all of them.
bool _workerMatchesOrderCategories(
    WorkerModel worker, Set<String> requiredKeys) {
  if (requiredKeys.isEmpty) return true;
  final workerKeys = _workerSpecialtyKeys(worker);
  return workerKeys.any(requiredKeys.contains);
}

/// Compact specialty summary for a worker row: one specialty => localized
/// category name; multiple => "First +N more". Resolved from
/// categoriesProvider — never a raw nameKey.
String _workerSpecialtySummary(
    AppLocalizations l, List<CategoryModel> categories, WorkerModel worker) {
  final normalized = _workerSpecialtyKeys(worker);
  final resolved = categories
      .where((c) =>
          normalized.contains(c.id.trim().toLowerCase()) ||
          normalized.contains(c.nameKey.trim().toLowerCase()))
      .toList();
  if (resolved.isEmpty) return '—';
  final first = l.get(resolved.first.nameKey);
  return resolved.length > 1 ? '$first +${resolved.length - 1} more' : first;
}

class _ContrAssignWorkerScreen extends ConsumerStatefulWidget {
  final OrderModel order;
  final WidgetRef ref;
  const _ContrAssignWorkerScreen({required this.order, required this.ref});

  @override
  ConsumerState<_ContrAssignWorkerScreen> createState() =>
      _ContrAssignWorkerScreenState();
}

class _ContrAssignWorkerScreenState
    extends ConsumerState<_ContrAssignWorkerScreen> {
  // Matches the Firestore rules-enforced cap on assignedWorkers per order
  // (Phase 3B3) — Firestore Security Rules can only validate a fixed number
  // of array indices, so the app must never let a contractor select more
  // than this many workers for a single order.
  static const int _maxAssignedWorkers = 5;

  late Set<String> _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final order = widget.order;
    _selected = order.assignedWorkers.isNotEmpty
        ? {for (final w in order.assignedWorkers) w.id}
        : (order.assignedWorkerId != null && order.assignedWorkerId!.isNotEmpty
            ? {order.assignedWorkerId!}
            : <String>{});
  }

  Future<void> _confirm(List<WorkerModel> allWorkers) async {
    final order = widget.order;
    if (_selected.isEmpty) return;
    if (_saving) return;
    setState(() => _saving = true);

    final workersById = {for (final w in allWorkers) w.id: w};
    final orderedSelectedWorkers = _selected
        .map((id) => workersById[id])
        .whereType<WorkerModel>()
        .toList();
    final snapshots = orderedSelectedWorkers
        .map((w) => AssignedWorkerSnapshot(
              id: w.id,
              name: w.name,
              specialties: w.specialties.isNotEmpty
                  ? w.specialties
                  : (w.specialty.isNotEmpty ? [w.specialty] : const []),
            ))
        .toList();

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(ordersProvider.notifier)
          .assignWorkersToContractorOrderInFirestore(
            orderId: order.id,
            workers: snapshots,
            currentStatus: order.status,
          );
      navigator.pop();
      messenger.showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.engineering_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Text(snapshots.isEmpty
                ? 'Assignment cleared'
                : (snapshots.length > 1
                    ? '${snapshots.length} workers assigned'
                    : 'Assigned: ${snapshots.first.name}')),
          ]),
          backgroundColor: _CB.dark,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    } catch (_) {
      setState(() => _saving = false);
      messenger.showSnackBar(const SnackBar(
          content: Text('Failed to assign worker. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final l = AppLocalizations.of(context);
    final workersAsync = ref.watch(contractorWorkersStreamProvider);
    final allWorkers = workersAsync.valueOrNull ?? const <WorkerModel>[];
    final categories =
        ref.watch(categoriesProvider).value ?? const <CategoryModel>[];
    final customerUser = order.customerId.isNotEmpty
        ? ref.watch(userByIdProvider(order.customerId)).valueOrNull
        : null;

    final alreadyAssignedIds = order.assignedWorkers.isNotEmpty
        ? order.assignedWorkers.map((w) => w.id).toSet()
        : (order.assignedWorkerId != null && order.assignedWorkerId!.isNotEmpty
            ? {order.assignedWorkerId!}
            : const <String>{});

    final requiredKeys = _orderRequiredCategoryKeys(order, categories);
    final hasCategoryInfo = requiredKeys.isNotEmpty;

    final eligibleWorkers = allWorkers.where((w) {
      if (alreadyAssignedIds.contains(w.id)) return true;
      if (hasCategoryInfo && !_workerMatchesOrderCategories(w, requiredKeys)) {
        return false;
      }
      return w.status == WorkerStatus.available;
    }).toList()
      ..sort((a, b) {
        final aSel = _selected.contains(a.id) ? 0 : 1;
        final bSel = _selected.contains(b.id) ? 0 : 1;
        if (aSel != bSel) return aSel.compareTo(bSel);
        return a.name.compareTo(b.name);
      });

    final canConfirm = _selected.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F1),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed:
                  (_saving || !canConfirm) ? null : () => _confirm(allWorkers),
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(
                  _selected.isEmpty
                      ? 'Select at least one worker'
                      : (_selected.length > 1
                          ? 'Confirm ${_selected.length} Workers'
                          : 'Confirm Worker'),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _CB.darkest,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _CB.darkest.withOpacity(0.4),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── AppBar ──────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 130,
            backgroundColor: _CB.darkest,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6EFE6),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0xFFD9C6B2),
                          blurRadius: 0,
                          offset: Offset(0, 4)),
                      BoxShadow(
                          color: Color(0xFFD9C6B2),
                          blurRadius: 10,
                          offset: Offset(5, 5)),
                      BoxShadow(
                          color: Colors.white,
                          blurRadius: 10,
                          offset: Offset(-5, -5)),
                    ],
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Color(0xFF4A3427), size: 17),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  // Contractor brand gradient — onBrand ink, not white.
                  gradient: ContractorColors.brandGradient,
                  borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28)),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(11),
                                  border: Border.all(
                                      color: _CB.darkest.withOpacity(0.25))),
                              child: const Icon(Icons.engineering_rounded,
                                  color: ContractorColors.onBrand, size: 18),
                            ),
                            const SizedBox(width: 12),
                            const Text('Assign Worker',
                                style: TextStyle(
                                    color: ContractorColors.onBrand,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5)),
                          ]),
                          const SizedBox(height: 3),
                          Text('${eligibleWorkers.length} workers available',
                              style: const TextStyle(
                                  color: ContractorColors.onBrandMuted,
                                  fontSize: 13)),
                        ]),
                  ),
                ),
              ),
            ),
          ),

          // ── Order Summary Card ───────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _CB.bg,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: _CB.mid.withOpacity(0.22),
                        blurRadius: 0,
                        offset: const Offset(0, 4)),
                    BoxShadow(
                        color: _CB.mid.withOpacity(0.14),
                        blurRadius: 12,
                        offset: const Offset(5, 5)),
                    const BoxShadow(
                        color: Colors.white,
                        blurRadius: 12,
                        offset: Offset(-5, -5)),
                  ],
                ),
                child: Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient:
                          const LinearGradient(colors: [_CB.darkest, _CB.dark]),
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [
                        BoxShadow(
                            color: _CB.dark.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 3))
                      ],
                    ),
                    child: ProfileAvatarImage(
                      imageUrl: customerUser?.avatar,
                      size: 44,
                      borderRadius: 13,
                      fallbackText: order.customerName.isNotEmpty
                          ? order.customerName
                          : 'C',
                      fallbackTextStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(order.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: _CB.darkest)),
                        const SizedBox(height: 3),
                        Row(children: [
                          Icon(Icons.person_outline_rounded,
                              size: 12, color: _CB.dark.withOpacity(0.7)),
                          const SizedBox(width: 4),
                          Text(order.customerName,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: _CB.dark.withOpacity(0.8))),
                          if (order.serviceType != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _CB.mid.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(order.serviceType!,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: _CB.dark)),
                            ),
                          ],
                        ]),
                      ])),
                ]),
              ),
            ),
          ),

          if (!hasCategoryInfo)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _CB.light.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 15, color: _CB.darkest),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                          'Category information is unavailable for this legacy order.',
                          style: TextStyle(fontSize: 11.5, color: _CB.darkest)),
                    ),
                  ]),
                ),
              ),
            ),

          // ── Workers List ─────────────────────────────────────────────
          if (allWorkers.isEmpty)
            const SliverFillRemaining(
              child: Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    Icon(Icons.engineering_rounded,
                        size: 64, color: Color(0xFFDC7D4E)),
                    SizedBox(height: 16),
                    Text('No workers yet',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _CB.darkest)),
                    SizedBox(height: 6),
                    Text('Add workers from the Suppliers tab',
                        style: TextStyle(fontSize: 13, color: _CB.dark)),
                  ])),
            )
          else if (eligibleWorkers.isEmpty)
            const SliverFillRemaining(
              child: Center(
                  child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                    'No suitable workers found for this order\'s specialties.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Color(0xFFA8927F))),
              )),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final w = eligibleWorkers[i];
                    final isSelected = _selected.contains(w.id);
                    final isAvail = w.status == WorkerStatus.available;

                    return GestureDetector(
                      onTap: () {
                        if (!isSelected &&
                            _selected.length >= _maxAssignedWorkers) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content:
                                Text(l.get('max_assigned_workers_reached')),
                          ));
                          return;
                        }
                        setState(() {
                          if (isSelected) {
                            _selected.remove(w.id);
                          } else {
                            _selected.add(w.id);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: _CB.bg,
                          borderRadius: BorderRadius.circular(20),
                          border: isSelected
                              ? Border.all(color: _CB.dark, width: 2)
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                      color: _CB.dark.withOpacity(0.25),
                                      blurRadius: 0,
                                      offset: const Offset(0, 4)),
                                  BoxShadow(
                                      color: _CB.dark.withOpacity(0.15),
                                      blurRadius: 12,
                                      offset: const Offset(5, 5)),
                                  const BoxShadow(
                                      color: Colors.white,
                                      blurRadius: 12,
                                      offset: Offset(-5, -5)),
                                ]
                              : [
                                  BoxShadow(
                                      color: _CB.mid.withOpacity(0.2),
                                      blurRadius: 0,
                                      offset: const Offset(0, 4)),
                                  BoxShadow(
                                      color: _CB.mid.withOpacity(0.12),
                                      blurRadius: 12,
                                      offset: const Offset(5, 5)),
                                  const BoxShadow(
                                      color: Colors.white,
                                      blurRadius: 12,
                                      offset: Offset(-5, -5)),
                                ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                    colors: [_CB.darkest, _CB.dark]),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(
                                  child: Text(
                                      w.name.isNotEmpty
                                          ? w.name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 18))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(w.name,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: _CB.darkest)),
                                  const SizedBox(height: 4),
                                  Row(children: [
                                    Text(
                                        _workerSpecialtySummary(
                                            l, categories, w),
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: _CB.dark.withOpacity(0.8))),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (isAvail
                                                ? const Color(0xFF22C55E)
                                                : const Color(0xFFF59E0B))
                                            .withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isAvail ? 'Available' : 'Busy',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: isAvail
                                              ? const Color(0xFF22C55E)
                                              : const Color(0xFFF59E0B),
                                        ),
                                      ),
                                    ),
                                  ]),
                                ])),
                            const SizedBox(width: 8),
                            if (isSelected)
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                      colors: [_CB.darkest, _CB.dark]),
                                  borderRadius: BorderRadius.circular(11),
                                  boxShadow: [
                                    BoxShadow(
                                        color: _CB.dark.withOpacity(0.35),
                                        blurRadius: 0,
                                        offset: const Offset(0, 3)),
                                    BoxShadow(
                                        color: _CB.dark.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 5)),
                                  ],
                                ),
                                child: const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 18),
                              )
                            else
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: _CB.bg,
                                  borderRadius: BorderRadius.circular(11),
                                  boxShadow: [
                                    BoxShadow(
                                        color: _CB.mid.withOpacity(0.25),
                                        blurRadius: 0,
                                        offset: const Offset(0, 3)),
                                    BoxShadow(
                                        color: _CB.mid.withOpacity(0.15),
                                        blurRadius: 6,
                                        offset: const Offset(3, 3)),
                                    const BoxShadow(
                                        color: Colors.white,
                                        blurRadius: 6,
                                        offset: Offset(-3, -3)),
                                  ],
                                ),
                                child: const Icon(Icons.chevron_right_rounded,
                                    color: Color(0xFFA8927F), size: 20),
                              ),
                          ]),
                        ),
                      ),
                    );
                  },
                  childCount: eligibleWorkers.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
