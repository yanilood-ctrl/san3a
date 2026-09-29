import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/presentation/providers/app_providers.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/customer_details_sheet.dart';
import '../../../../shared/widgets/selected_services_sheet.dart';
import '../../../../shared/widgets/shared_widgets.dart' show ProfileAvatarImage;
import '../theme/professional_design.dart';
import 'professional_chat_screen.dart';

Future<void> _openMapsForAddress(BuildContext context, String area) async {
  if (area.trim().isEmpty) return;
  final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(area)}');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class ProfessionalOrderDetailScreen extends ConsumerWidget {
  final OrderModel order;
  const ProfessionalOrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final orders = ref.watch(ordersProvider);
    final liveOrder =
        orders.firstWhere((o) => o.id == order.id, orElse: () => order);
    final customerUser = liveOrder.customerId.isNotEmpty
        ? ref.watch(userByIdProvider(liveOrder.customerId)).valueOrNull
        : null;

    Color accent;
    switch (liveOrder.status) {
      case OrderStatus.pending:
        accent = const Color(0xFFF59E0B);
        break;
      case OrderStatus.inProgress:
        accent = const Color(0xFF26A69A);
        break;
      case OrderStatus.completed:
        accent = const Color(0xFF22C55E);
        break;
      case OrderStatus.cancelled:
        accent = const Color(0xFFEF4444);
        break;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── AppBar ─────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 130,
            backgroundColor: ProfessionalColors.darkest,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: _NeoDetailBackBtn(),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _NeoComplaintButton(
                  onTap: () => _showNeoComplaintSheet(context, ref, liveOrder),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      ProfessionalColors.darkest,
                      ProfessionalColors.dark
                    ],
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
                                  color: accent.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(11),
                                  border: Border.all(
                                      color: accent.withOpacity(0.4))),
                              child: Icon(_statusIcon(liveOrder.status),
                                  color: Colors.white, size: 18)),
                          const SizedBox(width: 12),
                          const Text('Order Details',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5)),
                        ]),
                        const SizedBox(height: 3),
                        Text(
                            '${liveOrder.area} • ${liveOrder.serviceDate.day}/${liveOrder.serviceDate.month}/${liveOrder.serviceDate.year}',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.65),
                                fontSize: 13)),
                      ]),
                )),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Customer Card ─────────────────────────────────────
                _NeoDetailSection(children: [
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
                              end: Alignment.bottomRight),
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
                        child: Stack(
                          children: [
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
                                  color: const Color(0xFFEEEEF5),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 1.5),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Color(0xFFBEBECF),
                                        blurRadius: 3,
                                        offset: Offset(1, 1))
                                  ],
                                ),
                                child: const Icon(Icons.person_search_rounded,
                                    size: 9, color: Color(0xFF4A4A6A)),
                              ),
                            ),
                          ],
                        ),
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
                                  color: Color(0xFF333355))),
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
                        color: const Color(0xFFEEEEF5),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0xFFBEBECF),
                              blurRadius: 4,
                              offset: Offset(2, 2)),
                          BoxShadow(
                              color: Colors.white,
                              blurRadius: 4,
                              offset: Offset(-2, -2))
                        ],
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_statusIcon(liveOrder.status),
                            size: 12, color: accent),
                        const SizedBox(width: 5),
                        Text(_statusLabel(liveOrder.status, l),
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
                          color: const Color(0xFFEEEEF5),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0xFFBEBECF),
                                blurRadius: 4,
                                offset: Offset(2, 2)),
                            BoxShadow(
                                color: Colors.white,
                                blurRadius: 4,
                                offset: Offset(-2, -2))
                          ]),
                      child: Row(children: [
                        const Icon(Icons.priority_high_rounded,
                            size: 15, color: Color(0xFFEF4444)),
                        const SizedBox(width: 6),
                        const Text('Urgent Priority',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFEF4444))),
                      ]),
                    ),
                  ],
                ]),
                const SizedBox(height: 16),

                // ── Title + Description ──────────────────────────────
                _NeoDetailSection(children: [
                  Text(liveOrder.title,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF333355),
                          letterSpacing: -0.3)),
                  const SizedBox(height: 8),
                  Text(liveOrder.description,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF7777AA), height: 1.6)),
                ]),
                const SizedBox(height: 16),

                // ── Details ──────────────────────────────────────────
                _NeoDetailContainer(children: [
                  _NeoDetailRow(
                      icon: Icons.person_outline_rounded,
                      label: l.get('name'),
                      value: liveOrder.customerName.isNotEmpty
                          ? liveOrder.customerName
                          : 'Customer'),
                  _NeoDetailDivider(),
                  _NeoDetailRow(
                      icon: Icons.location_on_outlined,
                      label: l.get('area_or_city'),
                      value: liveOrder.area,
                      onTap: () =>
                          _openMapsForAddress(context, liveOrder.area)),
                  _NeoDetailDivider(),
                  _NeoDetailRow(
                      icon: Icons.calendar_today_outlined,
                      label: l.get('order_date'),
                      value:
                          '${liveOrder.serviceDate.day}/${liveOrder.serviceDate.month}/${liveOrder.serviceDate.year}'),
                  _NeoDetailDivider(),
                  _NeoDetailRow(
                      icon: Icons.access_time_outlined,
                      label: l.get('response_time'),
                      value:
                          '${liveOrder.serviceDate.hour.toString().padLeft(2, '0')}:${liveOrder.serviceDate.minute.toString().padLeft(2, '0')}'),
                  if (orderHasSelectedServicesDetail(liveOrder)) ...[
                    _NeoDetailDivider(),
                    _NeoDetailRow(
                        icon: Icons.build_circle_outlined,
                        label: l.get('services'),
                        value: orderSelectedServicesSummary(liveOrder),
                        accentColor: accent,
                        trailingIcon: Icons.chevron_right_rounded,
                        onTap: () => _showSelectedServicesSheet(
                            context, liveOrder, accent)),
                  ],
                  if (liveOrder.selectedServicePrice != null) ...[
                    _NeoDetailDivider(),
                    _NeoDetailRow(
                        icon: Icons.payments_outlined,
                        label: l.get('price_ils'),
                        value:
                            '₪${liveOrder.selectedServicePrice!.toStringAsFixed(0)}',
                        accentColor: const Color(0xFF22C55E)),
                  ],
                ]),
                const SizedBox(height: 16),

                // ── Photo / Attachment ────────────────────────────────
                if (liveOrder.imageUrls.isNotEmpty) ...[
                  _NeoOrderPhotoSection(imageUrl: liveOrder.imageUrls.first),
                  const SizedBox(height: 16),
                ],

                // ── Cancelled Reason ─────────────────────────────────
                if (liveOrder.status == OrderStatus.cancelled &&
                    liveOrder.rejectReason != null) ...[
                  _NeoDetailSection(
                    borderColor: const Color(0xFFEF4444),
                    children: [
                      Row(children: [
                        Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                                color: const Color(0xFFEEEEF5),
                                borderRadius: BorderRadius.circular(11),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Color(0xFFBEBECF),
                                      blurRadius: 5,
                                      offset: Offset(2, 2)),
                                  BoxShadow(
                                      color: Colors.white,
                                      blurRadius: 5,
                                      offset: Offset(-2, -2))
                                ]),
                            child: const Icon(Icons.cancel_outlined,
                                size: 18, color: Color(0xFFEF4444))),
                        const SizedBox(width: 12),
                        const Text('Cancellation Reason',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFEF4444))),
                      ]),
                      const SizedBox(height: 10),
                      Text(liveOrder.rejectReason!,
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF7777AA),
                              height: 1.5)),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                const SizedBox(height: 12),

                // ── Action Buttons ────────────────────────────────────
                if (liveOrder.status == OrderStatus.pending) ...[
                  _NeoActionRow(
                      label: l.get('send_message'),
                      icon: Icons.chat_bubble_outline_rounded,
                      filled: false,
                      color: const Color(0xFF26A69A),
                      onTap: () => _openChat(context, ref, liveOrder)),
                  const SizedBox(height: 12),
                  _NeoActionRow(
                      label: l.get('reject'),
                      icon: Icons.close_rounded,
                      filled: false,
                      color: const Color(0xFFEF4444),
                      onTap: () =>
                          _showRejectDialog(context, ref, l, liveOrder)),
                  const SizedBox(height: 12),
                  _NeoActionRow(
                      label: l.get('accept'),
                      icon: Icons.check_rounded,
                      filled: true,
                      color: const Color(0xFF26A69A),
                      onTap: () => _acceptOrder(context, ref, l, liveOrder)),
                ],
                if (liveOrder.status == OrderStatus.inProgress) ...[
                  _NeoActionRow(
                      label: l.get('send_message'),
                      icon: Icons.chat_bubble_outline_rounded,
                      filled: false,
                      color: const Color(0xFF26A69A),
                      onTap: () => _openChat(context, ref, liveOrder)),
                  const SizedBox(height: 12),
                  _NeoActionRow(
                      label: l.get('cancel'),
                      icon: Icons.close_rounded,
                      filled: false,
                      color: const Color(0xFFEF4444),
                      onTap: () =>
                          _showRejectDialog(context, ref, l, liveOrder)),
                  const SizedBox(height: 12),
                  _NeoActionRow(
                      label: l.get('completed'),
                      icon: Icons.check_circle_outline_rounded,
                      filled: true,
                      color: const Color(0xFF22C55E),
                      onTap: () => _completeOrder(context, ref, l, liveOrder)),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomerProfileSheet(BuildContext context, OrderModel o) {
    final accent = _accentForStatus(o.status);
    showCustomerDetailsSheet(
      context: context,
      order: o,
      accent: accent,
      surfaceColor: const Color(0xFFEEEEF5),
      shadowTint: const Color(0xFFBEBECF),
    );
  }

  void _showSelectedServicesSheet(
      BuildContext context, OrderModel o, Color accent) {
    showSelectedServicesSheet(
      context: context,
      order: o,
      accent: accent,
      surfaceColor: const Color(0xFFEEEEF5),
      shadowTint: const Color(0xFFBEBECF),
    );
  }

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

  IconData _statusIcon(OrderStatus s) {
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

  String _statusLabel(OrderStatus s, AppLocalizations l) {
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

  void _openChat(BuildContext context, WidgetRef ref, OrderModel o) {
    final customer = UserModel(
        id: o.customerId,
        fullName: o.customerName.isNotEmpty ? o.customerName : 'Customer',
        email: '',
        phone: '',
        city: o.area,
        role: UserRole.customer);
    ref.read(conversationsProvider.notifier).startConversation(customer);
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ProfessionalChatScreen(otherUser: customer)));
  }

  // Accept (pending → inProgress). Same single source of truth as the
  // Professional order card's three-dot "Accept" action
  // (professional_home_screen.dart's _ProfOrderCardDotsMenu): the Firestore
  // writer acceptProfessionalOrderInFirestore plus the customer
  // notification. The visible button previously called
  // ordersProvider.updateStatus(), which only mutates the in-memory
  // DummyData-seeded list and never reaches Firestore — so nothing was
  // persisted and `liveOrder` (read from the live Firestore stream) never
  // changed. Status is re-checked here because this screen can stay open
  // while another device/role moves the order on.
  Future<void> _acceptOrder(BuildContext context, WidgetRef ref,
      AppLocalizations l, OrderModel order) async {
    final messenger = ScaffoldMessenger.of(context);
    if (order.status != OrderStatus.pending) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Only pending orders can be accepted.'),
          behavior: SnackBarBehavior.fixed));
      return;
    }
    try {
      await ref
          .read(ordersProvider.notifier)
          .acceptProfessionalOrderInFirestore(order.id);
      createOrderNotification(
        userId: order.customerId,
        title: 'Order Accepted',
        message: '${order.providerName} accepted your order.',
        orderId: order.id,
      );
      messenger.showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(l.get('order_accepted')),
          ]),
          backgroundColor: ProfessionalColors.mid,
          behavior: SnackBarBehavior.fixed));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Failed to accept order. Please try again.'),
          behavior: SnackBarBehavior.fixed));
    }
  }

  // Complete (inProgress → completed) — same reasoning and same underlying
  // writer (completeProfessionalOrderInFirestore) as the order card's
  // three-dot "Complete" action. This screen is popped only after the write
  // actually succeeds, so a failed completion leaves the user on the order
  // with an error instead of silently closing it.
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
          .completeProfessionalOrderInFirestore(order.id);
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
          backgroundColor: ProfessionalColors.success,
          behavior: SnackBarBehavior.fixed));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Failed to complete order. Please try again.'),
          behavior: SnackBarBehavior.fixed));
    }
  }

  // The same modern Cancellation Reason sheet + Firestore-writing handler
  // (rejectProfessionalOrderInFirestore) used by the working Professional
  // reject/cancel entry point elsewhere in the app — replaces the previous
  // local-only `ordersProvider.cancelOrder()` call, which only mutated an
  // in-memory list and never persisted to Firestore, so `liveOrder` (read
  // from the live Firestore stream above) never actually reflected the
  // rejection. [order] is the full, current order — required so the
  // Firestore update and the customer notification always target the
  // right order/customer, not just a bare id.
  void _showRejectDialog(BuildContext context, WidgetRef ref,
      AppLocalizations l, OrderModel order) {
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setSheetState) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                                    offset: Offset(1, 1))
                              ]))),
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
                                  offset: Offset(-4, -4))
                            ]),
                        child: const Icon(Icons.cancel_outlined,
                            color: Color(0xFFEF4444), size: 22)),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Text(l.get('cancel_reason'),
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF333355)))),
                  ]),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
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
                              offset: Offset(-3, -3))
                        ]),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: Color(0xFFEF4444), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(l.get('enter_cancel_reason'),
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF555577),
                                      height: 1.5))),
                        ]),
                  ),
                  const SizedBox(height: 20),
                  _NeoFormTextField(
                    controller: ctrl,
                    hint: '${l.get("cancel_reason")}...',
                    icon: Icons.edit_note_rounded,
                    maxLines: 3,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l.get('cancel_reason')
                        : null,
                  ),
                  const SizedBox(height: 28),
                  _NeoFormSubmitButton(
                    label: l.get('confirm_cancel'),
                    onTap: () async {
                      if (submitting) return;
                      if (!formKey.currentState!.validate()) return;
                      final reason = ctrl.text.trim();
                      setSheetState(() => submitting = true);
                      try {
                        await ref
                            .read(ordersProvider.notifier)
                            .rejectProfessionalOrderInFirestore(
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
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Order rejected successfully'),
                                  backgroundColor: ProfessionalColors.error,
                                  behavior: SnackBarBehavior.fixed));
                        }
                      } catch (_) {
                        setSheetState(() => submitting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Failed to reject order. Please try again.'),
                                  behavior: SnackBarBehavior.fixed));
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showNeoComplaintSheet(
      BuildContext context, WidgetRef ref, OrderModel o) {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(text: 'Complaint: ${o.title}');
    final descCtrl = TextEditingController();
    final l = AppLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
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
                                    offset: Offset(1, 1))
                              ]))),
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
                                  offset: Offset(-4, -4))
                            ]),
                        child: const Icon(Icons.flag_rounded,
                            color: Color(0xFFEF4444), size: 22)),
                    const SizedBox(width: 14),
                    const Text('Submit Complaint',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF333355))),
                  ]),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
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
                              offset: Offset(-3, -3))
                        ]),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: Color(0xFFEF4444), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(
                                  'Describe your issue clearly. The admin will review and respond soon.',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF555577),
                                      height: 1.5))),
                        ]),
                  ),
                  const SizedBox(height: 20),
                  const Text('Subject',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7777AA))),
                  const SizedBox(height: 8),
                  _NeoFormTextField(
                      controller: titleCtrl,
                      hint: 'Complaint subject...',
                      icon: Icons.flag_outlined,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null),
                  const SizedBox(height: 16),
                  const Text('Description',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7777AA))),
                  const SizedBox(height: 8),
                  _NeoFormTextField(
                      controller: descCtrl,
                      hint: 'Describe the issue in detail...',
                      icon: Icons.description_outlined,
                      maxLines: 3,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null),
                  const SizedBox(height: 28),
                  _NeoFormSubmitButton(
                    label: 'Submit Complaint',
                    onTap: () async {
                      if (!formKey.currentState!.validate()) return;
                      final user = ref.read(authProvider);
                      final hasCustomer = o.customerId.isNotEmpty;
                      final complaint = ComplaintModel(
                        id: '',
                        userId: user?.id ?? '',
                        userName: user?.fullName ?? '',
                        complainantRole: 'professional',
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
                                Text('Complaint submitted')
                              ]),
                              backgroundColor: ProfessionalColors.mid,
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
}

// ── Neo Detail Back Button — Light Neumorphic (matches image style) ───────────
class _NeoDetailBackBtn extends StatefulWidget {
  @override
  State<_NeoDetailBackBtn> createState() => _NeoDetailBackBtnState();
}

class _NeoDetailBackBtnState extends State<_NeoDetailBackBtn>
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
                color: const Color(0xFFEEEEF5),
                borderRadius: BorderRadius.circular(14),
                boxShadow: _pressed
                    ? const [
                        BoxShadow(
                            color: Color(0xFFBEBECF),
                            blurRadius: 3,
                            offset: Offset(2, 2)),
                        BoxShadow(
                            color: Colors.white,
                            blurRadius: 3,
                            offset: Offset(-1, -1)),
                      ]
                    : const [
                        BoxShadow(
                            color: Color(0xFFBEBECF),
                            blurRadius: 0,
                            offset: Offset(0, 4)),
                        BoxShadow(
                            color: Color(0xFFBEBECF),
                            blurRadius: 10,
                            offset: Offset(5, 5)),
                        BoxShadow(
                            color: Colors.white,
                            blurRadius: 10,
                            offset: Offset(-5, -5)),
                      ],
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFF4A4A6A), size: 17),
            ),
          ),
        ),
      );
}

// ── Neo Complaint Button — Light Neumorphic (matches image style) ─────────────
class _NeoComplaintButton extends StatefulWidget {
  final VoidCallback onTap;
  const _NeoComplaintButton({required this.onTap});
  @override
  State<_NeoComplaintButton> createState() => _NeoComplaintButtonState();
}

class _NeoComplaintButtonState extends State<_NeoComplaintButton>
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
                color: const Color(0xFFEEEEF5),
                borderRadius: BorderRadius.circular(20),
                boxShadow: _pressed
                    ? const [
                        BoxShadow(
                            color: Color(0xFFBEBECF),
                            blurRadius: 3,
                            offset: Offset(2, 2)),
                        BoxShadow(
                            color: Colors.white,
                            blurRadius: 3,
                            offset: Offset(-1, -1)),
                      ]
                    : const [
                        BoxShadow(
                            color: Color(0xFFBEBECF),
                            blurRadius: 0,
                            offset: Offset(0, 4)),
                        BoxShadow(
                            color: Color(0xFFBEBECF),
                            blurRadius: 10,
                            offset: Offset(5, 5)),
                        BoxShadow(
                            color: Colors.white,
                            blurRadius: 10,
                            offset: Offset(-5, -5)),
                      ],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.flag_rounded,
                    color: _pressed
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF7777AA),
                    size: 15),
                const SizedBox(width: 6),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 80),
                  style: TextStyle(
                    color: _pressed
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF4A4A6A),
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

// ── Neo Detail Section Card ───────────────────────────────────────────────────
class _NeoDetailSection extends StatelessWidget {
  final List<Widget> children;
  final Color? borderColor;
  const _NeoDetailSection({required this.children, this.borderColor});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFEEEEF5),
          borderRadius: BorderRadius.circular(22),
          border: borderColor != null
              ? Border.all(color: borderColor!.withOpacity(0.3), width: 1.2)
              : null,
          boxShadow: const [
            BoxShadow(
                color: Color(0xFFBEBECF), blurRadius: 0, offset: Offset(0, 4)),
            BoxShadow(
                color: Color(0xFFBEBECF), blurRadius: 12, offset: Offset(5, 5)),
            BoxShadow(
                color: Colors.white, blurRadius: 12, offset: Offset(-5, -5)),
          ],
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
}

// ── Neo Order Photo Section (shows the customer's attached order image) ──────
class _NeoOrderPhotoSection extends StatelessWidget {
  final String imageUrl;
  const _NeoOrderPhotoSection({required this.imageUrl});

  @override
  Widget build(BuildContext context) => _NeoDetailSection(children: [
        Row(children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: const Color(0xFFEEEEF5),
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0xFFBEBECF),
                        blurRadius: 5,
                        offset: Offset(2, 2)),
                    BoxShadow(
                        color: Colors.white,
                        blurRadius: 5,
                        offset: Offset(-2, -2))
                  ]),
              child: const Icon(Icons.photo_outlined,
                  size: 18, color: Color(0xFF26A69A))),
          const SizedBox(width: 12),
          const Text('Attached Photo',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF333355))),
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
                  : const SizedBox(
                      height: 180,
                      child: Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF26A69A)))),
              errorBuilder: (context, error, stack) => Container(
                height: 180,
                alignment: Alignment.center,
                color: const Color(0xFFEEEEF5),
                child: const Icon(Icons.broken_image_outlined,
                    color: Color(0xFF9999BB), size: 32),
              ),
            ),
          ),
        ),
      ]);
}

// ── Neo Detail Container (inset look for rows) ────────────────────────────────
class _NeoDetailContainer extends StatelessWidget {
  final List<Widget> children;
  const _NeoDetailContainer({required this.children});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFFEEEEF5),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
                color: Color(0xFFBEBECF), blurRadius: 8, offset: Offset(4, 4)),
            BoxShadow(
                color: Colors.white, blurRadius: 8, offset: Offset(-4, -4)),
          ],
        ),
        child: Column(children: children),
      );
}

class _NeoDetailRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color? accentColor;
  final VoidCallback? onTap;
  // Shown at the trailing edge only when onTap is set — open_in_new for
  // rows that launch an external app (e.g. Maps), chevron_right for rows
  // that open an in-app details sheet (e.g. Services).
  final IconData trailingIcon;
  const _NeoDetailRow(
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
                decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFEEEEF5),
                    boxShadow: [
                      BoxShadow(
                          color: Color(0xFFBEBECF),
                          blurRadius: 5,
                          offset: Offset(2, 2)),
                      BoxShadow(
                          color: Colors.white,
                          blurRadius: 5,
                          offset: Offset(-2, -2))
                    ]),
                child: Icon(icon, size: 16, color: const Color(0xFF7777AA))),
            const SizedBox(width: 12),
            Text(label,
                style: const TextStyle(fontSize: 13, color: Color(0xFF7777AA))),
            const Spacer(),
            if (onTap != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: const Color(0xFFEEEEF5),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0xFFBEBECF),
                          blurRadius: 3,
                          offset: Offset(1, 1)),
                      BoxShadow(
                          color: Colors.white,
                          blurRadius: 3,
                          offset: Offset(-1, -1))
                    ]),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(value,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: accentColor ?? const Color(0xFF333355))),
                  const SizedBox(width: 4),
                  Icon(trailingIcon,
                      size: 12, color: accentColor ?? const Color(0xFF7777AA)),
                ]),
              )
            else
              Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: accentColor ?? const Color(0xFF333355))),
          ]),
        ),
      );
}

class _NeoDetailDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [Color(0xFFD0D0DF), Colors.white, Color(0xFFD0D0DF)])),
      );
}

// ── Neo Action Button ─────────────────────────────────────────────────────────
class _NeoActionRow extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final Color color;
  final VoidCallback onTap;
  const _NeoActionRow(
      {required this.label,
      required this.icon,
      required this.filled,
      required this.color,
      required this.onTap});
  @override
  State<_NeoActionRow> createState() => _NeoActionRowState();
}

class _NeoActionRowState extends State<_NeoActionRow>
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
              color: widget.filled ? null : const Color(0xFFEEEEF5),
              border: widget.filled
                  ? null
                  : Border.all(
                      color: widget.color.withOpacity(0.5), width: 1.5),
              boxShadow: _pressed
                  ? [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 4,
                          offset: const Offset(2, 2))
                    ]
                  : widget.filled
                      ? [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.38),
                              blurRadius: 0,
                              offset: const Offset(0, 5)),
                          BoxShadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 10,
                              offset: const Offset(0, 8)),
                          BoxShadow(
                              color: Colors.white.withOpacity(0.08),
                              blurRadius: 4,
                              offset: const Offset(0, -2))
                        ]
                      : [
                          const BoxShadow(
                              color: Color(0xFFBEBECF),
                              blurRadius: 0,
                              offset: Offset(0, 4)),
                          const BoxShadow(
                              color: Color(0xFFBEBECF),
                              blurRadius: 8,
                              offset: Offset(4, 4)),
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

// ── Neo Form Text Field ───────────────────────────────────────────────────────
class _NeoFormTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int maxLines;
  final String? Function(String?)? validator;
  const _NeoFormTextField(
      {required this.controller,
      required this.hint,
      required this.icon,
      this.maxLines = 1,
      this.validator});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: const Color(0xFFEEEEF5),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                  color: Color(0xFFBEBECF),
                  blurRadius: 6,
                  offset: Offset(3, 3)),
              BoxShadow(
                  color: Colors.white, blurRadius: 6, offset: Offset(-3, -3))
            ]),
        child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          style: const TextStyle(fontSize: 14, color: Color(0xFF333355)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFAAAACC), fontSize: 13),
            prefixIcon: Icon(icon, color: const Color(0xFF7777AA), size: 20),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      );
}

// ── Neo Form Submit Button ────────────────────────────────────────────────────
class _NeoFormSubmitButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _NeoFormSubmitButton({required this.label, required this.onTap});
  @override
  State<_NeoFormSubmitButton> createState() => _NeoFormSubmitButtonState();
}

class _NeoFormSubmitButtonState extends State<_NeoFormSubmitButton>
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
                  colors: [Color(0xFF0A1628), Color(0xFF051F20)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
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
                          color: Colors.black.withOpacity(0.20),
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
