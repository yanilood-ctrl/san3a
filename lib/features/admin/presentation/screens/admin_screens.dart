import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../providers/admin_providers.dart';
import '../../../auth/presentation/providers/app_providers.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../../shared/widgets/selected_services_sheet.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import 'admin_users_screen.dart' show showAdminUserDetails;
import 'admin_complaints_screen.dart';

import 'admin_chat_screen.dart';

// ─── Shared Admin Search Bar ──────────────────────────────────────────────────
class AdminSearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final String query;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const AdminSearchBar(
      {super.key,
      required this.ctrl,
      required this.query,
      required this.hint,
      required this.onChanged,
      required this.onClear});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isDark
                  ? AppAdmin.dark.withOpacity(0.4)
                  : AppAdmin.mid.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
                color: AppAdmin.darkest.withOpacity(0.07),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              gradient:
                  LinearGradient(colors: [AppAdmin.dark, AppAdmin.darkest]),
              borderRadius: BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                  topLeft: Radius.circular(6),
                  bottomLeft: Radius.circular(6)),
            ),
            child:
                const Icon(Icons.search_rounded, color: Colors.white, size: 22),
          ),
          Expanded(
            child: TextField(
              controller: ctrl,
              onChanged: onChanged,
              style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : AppAdmin.darkest),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : AppAdmin.mid,
                    fontSize: 13),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            size: 18, color: AppAdmin.dark),
                        onPressed: onClear)
                    : null,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Admin Section Header ─────────────────────────────────────────────────────
class AdminSectionHeader extends StatelessWidget {
  final String title;
  const AdminSectionHeader({super.key, required this.title});
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: [AppAdmin.darkest, AppAdmin.dark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
                color: Color(0x4072348A), blurRadius: 16, offset: Offset(0, 6))
          ],
        ),
        child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5)),
            )),
      );
}

// ─── ORDERS SCREEN ────────────────────────────────────────────────────────────

// ─── Public helper to open order details from other screens ──────────────────
void showAdminOrderDetails(
    BuildContext context, OrderModel order, WidgetRef ref) {
  final l = AppLocalizations.of(context);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _OrderDetailsSheet(order: order, l: l, ref: ref),
  );
}

Future<void> _copyOrderId(BuildContext context, String orderId) async {
  await Clipboard.setData(ClipboardData(text: orderId));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
    content: Text('Order ID copied.'),
    behavior: SnackBarBehavior.floating,
  ));
}

// Opens a standard HTTPS Google Maps search URL for [area] — works for both
// place names and "lat,lng" coordinate strings. No location permission or
// device-location access is used.
Future<void> _openAreaInMaps(BuildContext context, String area) async {
  final query = area.trim();
  if (query.isEmpty || query == '—') return;
  final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
  try {
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) _showMapsUnavailable(context);
  } catch (_) {
    if (context.mounted) _showMapsUnavailable(context);
  }
}

void _showMapsUnavailable(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
    content: Text('Could not open Maps.'),
    behavior: SnackBarBehavior.floating,
  ));
}

// ─── Order Details Sheet (neo-morphism, request-category style) ───────────────
class _OrderDetailsSheet extends StatelessWidget {
  final OrderModel order;
  final AppLocalizations l;
  final WidgetRef ref;
  const _OrderDetailsSheet(
      {required this.order, required this.l, required this.ref});

  Color _sc(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
        return const Color(0xFFF59E0B);
      case OrderStatus.inProgress:
        // Light blue — matches the In Progress stepper tab and the
        // Customer Orders status language, not the lilac admin brand.
        return const Color(0xFF0EA5E9);
      case OrderStatus.completed:
        return const Color(0xFF059669);
      case OrderStatus.cancelled:
        return AppColors.error;
    }
  }

  String _sl(OrderStatus s) {
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

  IconData _si(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
        return Icons.hourglass_top_rounded;
      case OrderStatus.inProgress:
        return Icons.autorenew_rounded;
      case OrderStatus.completed:
        return Icons.check_circle_outline_rounded;
      case OrderStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }

  void _navigateToUser(
      BuildContext context, String userId, String fallbackName, UserRole role) {
    final users = ref.read(adminUsersProvider);
    final found = users.where((u) => u.id == userId).toList();
    final user = found.isNotEmpty
        ? found.first
        : UserModel(
            id: userId,
            fullName: fallbackName.isNotEmpty ? fallbackName : 'Unknown User',
            email: '',
            phone: '—',
            city: '—',
            role: role,
          );
    showAdminUserDetails(context, user, ref);
  }

  @override
  Widget build(BuildContext context) {
    final sc = _sc(order.status);
    final sl = _sl(order.status);
    final si = _si(order.status);
    // Older orders may not have providerRole set — same default used by the
    // orders list role filter (_matchesRoleFilter) and at order creation.
    final isContractorOrder =
        (order.providerRole ?? 'professional') == 'contractor';
    final usableImageUrl = order.imageUrls
        .map((u) => u.trim())
        .firstWhere((u) => u.isNotEmpty, orElse: () => '');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: BoxDecoration(
        color: AppAdmin.surfaceTint,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
              color: AppAdmin.borderSoft, blurRadius: 20, offset: Offset(8, 8)),
          BoxShadow(
              color: Colors.white, blurRadius: 20, offset: Offset(-8, -8)),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        const SizedBox(height: 14),
        Center(
            child: Container(
          width: 44,
          height: 5,
          decoration: BoxDecoration(
            color: AppAdmin.borderSoft,
            borderRadius: BorderRadius.circular(3),
            boxShadow: const [
              BoxShadow(
                  color: Colors.white, blurRadius: 2, offset: Offset(-1, -1)),
              BoxShadow(
                  color: AppAdmin.borderSoft,
                  blurRadius: 2,
                  offset: Offset(1, 1)),
            ],
          ),
        )),
        const SizedBox(height: 16),
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppAdmin.surfaceTint,
                boxShadow: [
                  BoxShadow(
                      color: sc.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(4, 4)),
                  const BoxShadow(
                      color: Colors.white,
                      blurRadius: 8,
                      offset: Offset(-4, -4)),
                ],
              ),
              child: Icon(si, color: sc, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(order.title,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppAdmin.inkDark),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: sc.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: sc.withOpacity(0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    child: Text(sl,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: sc)),
                  ),
                ])),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppAdmin.surfaceTint,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                        color: AppAdmin.borderSoft,
                        blurRadius: 4,
                        offset: Offset(2, 2)),
                    BoxShadow(
                        color: Colors.white,
                        blurRadius: 4,
                        offset: Offset(-2, -2)),
                  ],
                ),
                child: const Icon(Icons.close_rounded,
                    size: 16, color: AppAdmin.inkMid),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        // Body
        Flexible(
            child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Info banner (inset neo)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppAdmin.surfaceTint,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                      color: AppAdmin.borderSoft,
                      blurRadius: 6,
                      offset: Offset(3, 3)),
                  BoxShadow(
                      color: Colors.white,
                      blurRadius: 6,
                      offset: Offset(-3, -3)),
                ],
              ),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline_rounded, color: sc, size: 18),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(order.description,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppAdmin.inkMid,
                              height: 1.5)),
                    ])),
              ]),
            ),
            const SizedBox(height: 18),
            // Parties
            _NeoSectionLabel(label: 'Parties Involved', color: sc),
            const SizedBox(height: 10),
            Consumer(builder: (context, ref, _) {
              final customerUser = order.customerId.isNotEmpty
                  ? ref.watch(userByIdProvider(order.customerId)).valueOrNull
                  : null;
              return _NeoUserCard(
                  icon: Icons.person_rounded,
                  label: 'Customer',
                  name:
                      order.customerName.isNotEmpty ? order.customerName : '—',
                  roleColor: AppColors.primary,
                  avatarUrl: customerUser?.avatar,
                  onTap: order.customerId.isNotEmpty
                      ? () => _navigateToUser(context, order.customerId,
                          order.customerName, UserRole.customer)
                      : null);
            }),
            const SizedBox(height: 8),
            Consumer(builder: (context, ref, _) {
              final providerUser = order.providerId.isNotEmpty
                  ? ref.watch(userByIdProvider(order.providerId)).valueOrNull
                  : null;
              return _NeoUserCard(
                  icon: Icons.engineering_rounded,
                  label: isContractorOrder
                      ? 'Contractor'
                      : 'Professional / Provider',
                  name:
                      order.providerName.isNotEmpty ? order.providerName : '—',
                  roleColor: AppColors.success,
                  avatarUrl: providerUser?.avatar,
                  onTap: order.providerId.isNotEmpty
                      ? () => _navigateToUser(
                          context,
                          order.providerId,
                          order.providerName,
                          isContractorOrder
                              ? UserRole.contractor
                              : UserRole.professional)
                      : null);
            }),
            const SizedBox(height: 18),
            // Details
            _NeoSectionLabel(label: 'Order Details', color: sc),
            const SizedBox(height: 10),
            _NeoDetailRow(
                icon: Icons.tag_rounded,
                label: 'Order ID',
                value: order.id,
                color: sc,
                trailing: _NeoRowIconBtn(
                  icon: Icons.copy_rounded,
                  color: sc,
                  onTap: () => _copyOrderId(context, order.id),
                )),
            _NeoDetailRow(
                icon: Icons.location_on_outlined,
                label: 'Area',
                value: order.area,
                color: sc,
                trailing:
                    order.area.trim().isNotEmpty && order.area.trim() != '—'
                        ? _NeoRowIconBtn(
                            icon: Icons.map_outlined,
                            color: sc,
                            onTap: () => _openAreaInMaps(context, order.area),
                          )
                        : null),
            _NeoDetailRow(
                icon: Icons.calendar_today_outlined,
                label: 'Service Date',
                value:
                    '${order.serviceDate.day}/${order.serviceDate.month}/${order.serviceDate.year}',
                color: sc),
            _NeoDetailRow(
                icon: Icons.access_time_outlined,
                label: 'Service Time',
                value:
                    '${order.serviceDate.hour.toString().padLeft(2, '0')}:${order.serviceDate.minute.toString().padLeft(2, '0')}',
                color: sc),
            if (orderHasSelectedServicesDetail(order))
              _NeoDetailRow(
                  icon: Icons.miscellaneous_services_outlined,
                  label: 'Service',
                  value: orderSelectedServicesSummary(order),
                  color: sc,
                  trailing: Icon(Icons.chevron_right_rounded,
                      size: 18, color: sc.withValues(alpha: 0.7)),
                  onTap: () => showSelectedServicesSheet(
                        context: context,
                        order: order,
                        accent: sc,
                        surfaceColor: AppAdmin.surfaceTint,
                        shadowTint: AppAdmin.borderSoft,
                      )),
            if (order.selectedServicePrice != null)
              _NeoDetailRow(
                  icon: Icons.payments_outlined,
                  label: 'Price',
                  value: '₪${order.selectedServicePrice!.toStringAsFixed(0)}',
                  color: sc),
            if (order.status == OrderStatus.cancelled &&
                order.rejectReason != null &&
                order.rejectReason!.isNotEmpty)
              _NeoDetailRow(
                  icon: Icons.notes_outlined,
                  label: 'Cancellation / Rejection Reason',
                  value: order.rejectReason!,
                  color: sc),
            if (usableImageUrl.isNotEmpty) ...[
              const SizedBox(height: 18),
              _NeoSectionLabel(label: 'Attached Photo', color: sc),
              const SizedBox(height: 10),
              _NeoOrderPhoto(imageUrl: usableImageUrl),
            ],
            if (order.assignedWorkerName != null &&
                order.assignedWorkerName!.isNotEmpty) ...[
              const SizedBox(height: 18),
              _NeoSectionLabel(label: 'Assigned Worker', color: sc),
              const SizedBox(height: 10),
              _NeoDetailRow(
                  icon: Icons.badge_outlined,
                  label: 'Worker',
                  value: order.assignedWorkerName!,
                  color: sc),
              if (order.assignedWorkerSpecialty != null &&
                  order.assignedWorkerSpecialty!.isNotEmpty)
                _NeoDetailRow(
                    icon: Icons.work_outline_rounded,
                    label: 'Specialty',
                    value: order.assignedWorkerSpecialty!,
                    color: sc),
              if (order.assignedWorkerPhone != null &&
                  order.assignedWorkerPhone!.isNotEmpty)
                _NeoDetailRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: order.assignedWorkerPhone!,
                    color: sc),
            ],
            const SizedBox(height: 24),
          ]),
        )),
        // Footer
        if (order.status == OrderStatus.pending ||
            order.status == OrderStatus.inProgress)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: Row(children: [
              Expanded(
                  child: _NeoActionButton(
                label: 'Cancel',
                icon: Icons.cancel_outlined,
                gradient: [AppColors.error, const Color(0xFF991B1B)],
                onTap: () {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  ref
                      .read(ordersProvider.notifier)
                      .cancelAdminOrderInFirestore(orderId: order.id)
                      .then((_) {
                    messenger.showSnackBar(SnackBar(
                      content: const Text('Order cancelled successfully'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ));
                  }).catchError((_) {
                    messenger.showSnackBar(SnackBar(
                      content: const Text(
                          'Failed to cancel order. Please try again.'),
                      backgroundColor: AppAdmin.dark,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ));
                  });
                },
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: _NeoActionButton(
                label: order.status == OrderStatus.pending
                    ? 'Approve'
                    : 'Complete',
                icon: order.status == OrderStatus.pending
                    ? Icons.check_circle_outline_rounded
                    : Icons.done_all_rounded,
                gradient: [const Color(0xFF059669), const Color(0xFF065F46)],
                onTap: () {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  final isPending = order.status == OrderStatus.pending;
                  final op = isPending
                      ? ref
                          .read(ordersProvider.notifier)
                          .approveAdminOrderInFirestore(order.id)
                      : ref
                          .read(ordersProvider.notifier)
                          .completeAdminOrderInFirestore(order.id);
                  op.then((_) {
                    createOrderNotification(
                      userId: order.customerId,
                      title:
                          isPending ? 'Order In Progress' : 'Order Completed',
                      message: isPending
                          ? 'Your order is now in progress.'
                          : 'Your order was completed successfully.',
                      orderId: order.id,
                    );
                    messenger.showSnackBar(SnackBar(
                      content: Text(isPending
                          ? 'Order approved successfully'
                          : 'Order completed successfully'),
                      backgroundColor: const Color(0xFF059669),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ));
                  }).catchError((_) {
                    messenger.showSnackBar(SnackBar(
                      content: Text(isPending
                          ? 'Failed to approve order. Please try again.'
                          : 'Failed to complete order. Please try again.'),
                      backgroundColor: AppAdmin.dark,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ));
                  });
                },
              )),
            ]),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: _NeoActionButton(
              label: 'Close',
              icon: Icons.close_rounded,
              gradient: [AppAdmin.dark, AppAdmin.darkest],
              onTap: () => Navigator.pop(context),
            ),
          ),
      ]),
    );
  }
}

// ─── Edit Order Sheet (neo-morphism, request-category style) ──────────────────
class _EditOrderSheet extends StatefulWidget {
  final OrderModel order;
  final AppLocalizations l;
  final WidgetRef ref;
  const _EditOrderSheet(
      {required this.order, required this.l, required this.ref});
  @override
  State<_EditOrderSheet> createState() => _EditOrderSheetState();
}

class _EditOrderSheetState extends State<_EditOrderSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _areaCtrl;
  late final TextEditingController _priceCtrl;
  OrderStatus? _selectedStatus;
  DateTime? _selectedDate;

  static const Map<OrderStatus, String> _statusLabels = {
    OrderStatus.pending: 'Pending',
    OrderStatus.inProgress: 'In Progress',
    OrderStatus.completed: 'Completed',
    OrderStatus.cancelled: 'Cancelled',
  };
  static const Map<OrderStatus, Color> _statusColors = {
    OrderStatus.pending: Color(0xFFF59E0B),
    // Light blue — matches the In Progress stepper tab and the Customer
    // Orders status language, not the lilac admin brand.
    OrderStatus.inProgress: Color(0xFF0EA5E9),
    OrderStatus.completed: Color(0xFF059669),
    OrderStatus.cancelled: AppColors.error,
  };

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.order.title);
    _descCtrl = TextEditingController(text: widget.order.description);
    _areaCtrl = TextEditingController(text: widget.order.area);
    _priceCtrl = TextEditingController(
        text: widget.order.selectedServicePrice?.toStringAsFixed(0) ?? '');
    _selectedStatus = widget.order.status;
    _selectedDate = widget.order.serviceDate;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _areaCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      decoration: BoxDecoration(
        color: AppAdmin.surfaceTint,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
              color: AppAdmin.borderSoft, blurRadius: 20, offset: Offset(8, 8)),
          BoxShadow(
              color: Colors.white, blurRadius: 20, offset: Offset(-8, -8)),
        ],
      ),
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 14),
          Center(
              child: Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
                color: AppAdmin.borderSoft,
                borderRadius: BorderRadius.circular(3),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.white,
                      blurRadius: 2,
                      offset: Offset(-1, -1)),
                  BoxShadow(
                      color: AppAdmin.borderSoft,
                      blurRadius: 2,
                      offset: Offset(1, 1))
                ]),
          )),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppAdmin.surfaceTint,
                  boxShadow: const [
                    BoxShadow(
                        color: AppAdmin.borderSoft,
                        blurRadius: 8,
                        offset: Offset(4, 4)),
                    BoxShadow(
                        color: Colors.white,
                        blurRadius: 8,
                        offset: Offset(-4, -4)),
                  ],
                ),
                child: const Icon(Icons.edit_document,
                    color: AppAdmin.inkMid, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Edit Order',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppAdmin.inkDark)),
                    Text(widget.order.title,
                        style: const TextStyle(
                            fontSize: 12, color: AppAdmin.inkMid),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ])),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      color: AppAdmin.surfaceTint,
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                            color: AppAdmin.borderSoft,
                            blurRadius: 4,
                            offset: Offset(2, 2)),
                        BoxShadow(
                            color: Colors.white,
                            blurRadius: 4,
                            offset: Offset(-2, -2))
                      ]),
                  child: const Icon(Icons.close_rounded,
                      size: 16, color: AppAdmin.inkMid),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          Flexible(
              child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Order Title',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppAdmin.inkMid)),
              const SizedBox(height: 8),
              _NeoInputField(
                  controller: _titleCtrl,
                  hint: 'Order title...',
                  icon: Icons.title_outlined,
                  maxLines: 1,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null),
              const SizedBox(height: 14),
              const Text('Description',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppAdmin.inkMid)),
              const SizedBox(height: 8),
              _NeoInputField(
                  controller: _descCtrl,
                  hint: 'Describe the order...',
                  icon: Icons.description_outlined,
                  maxLines: 3),
              const SizedBox(height: 14),
              const Text('Area',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppAdmin.inkMid)),
              const SizedBox(height: 8),
              _NeoInputField(
                  controller: _areaCtrl,
                  hint: 'e.g. Tel Aviv',
                  icon: Icons.location_on_outlined,
                  maxLines: 1,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null),
              const SizedBox(height: 14),
              const Text('Price (₪)',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppAdmin.inkMid)),
              const SizedBox(height: 8),
              Opacity(
                opacity: 0.45,
                child: IgnorePointer(
                  child: _NeoInputField(
                      controller: _priceCtrl,
                      hint: 'e.g. 500',
                      icon: Icons.payments_outlined,
                      maxLines: 1,
                      keyboardType: TextInputType.number),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Status',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppAdmin.inkMid)),
              const SizedBox(height: 8),
              Opacity(
                opacity: 0.45,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppAdmin.surfaceTint,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                            color: AppAdmin.borderSoft,
                            blurRadius: 6,
                            offset: Offset(3, 3)),
                        BoxShadow(
                            color: Colors.white,
                            blurRadius: 6,
                            offset: Offset(-3, -3)),
                      ],
                    ),
                    child: DropdownButtonFormField<OrderStatus>(
                      value: _selectedStatus,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        prefixIcon: Icon(Icons.flag_outlined,
                            color: AppAdmin.inkMid, size: 20),
                      ),
                      dropdownColor: AppAdmin.surfaceTint,
                      borderRadius: BorderRadius.circular(16),
                      items: OrderStatus.values.map((s) {
                        final color = _statusColors[s]!;
                        return DropdownMenuItem(
                            value: s,
                            child: Row(children: [
                              Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                      color: color, shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Text(_statusLabels[s]!,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: color,
                                      fontWeight: FontWeight.w700)),
                            ]));
                      }).toList(),
                      onChanged: null,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Service Date',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppAdmin.inkMid)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    builder: (ctx, child) => Theme(
                      data: Theme.of(ctx).copyWith(
                          colorScheme: const ColorScheme.light(
                              primary: AppAdmin.dark, onPrimary: Colors.white)),
                      child: child!,
                    ),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppAdmin.surfaceTint,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                          color: AppAdmin.borderSoft,
                          blurRadius: 6,
                          offset: Offset(3, 3)),
                      BoxShadow(
                          color: Colors.white,
                          blurRadius: 6,
                          offset: Offset(-3, -3)),
                    ],
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_outlined,
                        color: AppAdmin.inkMid, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      _selectedDate != null
                          ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                          : 'Select Date',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _selectedDate != null
                              ? AppAdmin.inkDark
                              : AppAdmin.inkLight),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppAdmin.inkLight, size: 20),
                  ]),
                ),
              ),
              const SizedBox(height: 28),
            ]),
          )),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: _NeoActionButton(
              label: 'Save Changes',
              icon: Icons.save_outlined,
              gradient: const [AppAdmin.inkDarkest, AppAdmin.dark],
              onTap: () {
                final title = _titleCtrl.text.trim();
                final desc = _descCtrl.text.trim();
                final area = _areaCtrl.text.trim();
                if (title.isEmpty || desc.isEmpty || area.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('Please fill all required fields.'),
                    backgroundColor: AppAdmin.dark,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ));
                  return;
                }
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                widget.ref
                    .read(ordersProvider.notifier)
                    .updateAdminOrderFieldsInFirestore(
                      orderId: widget.order.id,
                      title: title,
                      description: desc,
                      area: area,
                      serviceDate: _selectedDate ?? widget.order.serviceDate,
                    )
                    .then((_) {
                  messenger.showSnackBar(SnackBar(
                    content: const Text('Order updated successfully'),
                    backgroundColor: AppAdmin.dark,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ));
                }).catchError((_) {
                  messenger.showSnackBar(SnackBar(
                    content:
                        const Text('Failed to update order. Please try again.'),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ));
                });
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Neo Helpers (shared across sheets) ──────────────────────────────────────
class _NeoSectionLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _NeoSectionLabel({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppAdmin.inkDark)),
      ]);
}

// ── Admin Order Photo (customer-attached order image) ─────────────────────────
class _NeoOrderPhoto extends StatelessWidget {
  final String imageUrl;
  const _NeoOrderPhoto({required this.imageUrl});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => showDialog(
          context: context,
          barrierColor: Colors.black.withOpacity(0.85),
          builder: (ctx) => GestureDetector(
            onTap: () => Navigator.pop(ctx),
            child: Scaffold(
                backgroundColor: Colors.transparent,
                body: Center(
                    child: InteractiveViewer(
                        child: Image.network(imageUrl, fit: BoxFit.contain)))),
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
                            strokeWidth: 2, color: AppAdmin.accent))),
            errorBuilder: (context, error, stack) => Container(
              height: 180,
              alignment: Alignment.center,
              color: AppAdmin.surfaceTint,
              child: const Icon(Icons.broken_image_outlined,
                  color: AppAdmin.inkLight, size: 32),
            ),
          ),
        ),
      );
}

class _NeoDetailRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  // Optional small trailing action (e.g. copy/maps icon button, or a plain
  // chevron when the whole row is tappable via [onTap]) rendered after the
  // value. Existing rows that don't pass it are unaffected.
  final Widget? trailing;
  // Optional whole-row tap target (e.g. opening the Selected Services
  // sheet). Existing rows that don't pass it keep their current
  // non-interactive appearance/behavior unchanged.
  final VoidCallback? onTap;
  const _NeoDetailRow(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color,
      this.trailing,
      this.onTap});
  @override
  Widget build(BuildContext context) {
    final row = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppAdmin.surfaceTint,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: AppAdmin.borderSoft, blurRadius: 4, offset: Offset(2, 2)),
          BoxShadow(color: Colors.white, blurRadius: 4, offset: Offset(-2, -2)),
        ],
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                color: AppAdmin.inkMid,
                fontWeight: FontWeight.w600)),
        const Spacer(),
        Flexible(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppAdmin.inkDark),
                textAlign: TextAlign.end)),
        if (trailing != null) ...[
          const SizedBox(width: 6),
          trailing!,
        ],
      ]),
    );
    if (onTap == null) return row;
    return GestureDetector(
        onTap: onTap, behavior: HitTestBehavior.opaque, child: row);
  }
}

// Small round icon button for a _NeoDetailRow's optional trailing action
// (e.g. copy Order ID, open Area in Maps).
class _NeoRowIconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _NeoRowIconBtn(
      {required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
              shape: BoxShape.circle, color: color.withOpacity(0.12)),
          child: Icon(icon, size: 14, color: color),
        ),
      );
}

class _NeoUserCard extends StatelessWidget {
  final IconData icon;
  final String label, name;
  final Color roleColor;
  final VoidCallback? onTap;
  final String? avatarUrl;
  const _NeoUserCard(
      {required this.icon,
      required this.label,
      required this.name,
      required this.roleColor,
      this.onTap,
      this.avatarUrl});
  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    final hasPhoto = url != null && url.isNotEmpty;
    final fallbackIcon = Icon(icon, color: roleColor, size: 20);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppAdmin.surfaceTint,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: AppAdmin.borderSoft,
                blurRadius: 6,
                offset: Offset(3, 3)),
            BoxShadow(
                color: Colors.white, blurRadius: 6, offset: Offset(-3, -3)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppAdmin.surfaceTint,
              boxShadow: [
                BoxShadow(
                    color: roleColor.withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(3, 3)),
                const BoxShadow(
                    color: Colors.white, blurRadius: 6, offset: Offset(-3, -3)),
              ],
            ),
            child: hasPhoto
                ? ClipOval(
                    child: Image.network(
                      url,
                      width: 42,
                      height: 42,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) =>
                          progress == null ? child : fallbackIcon,
                      errorBuilder: (context, error, stack) => fallbackIcon,
                    ),
                  )
                : fallbackIcon,
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        color: roleColor,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(name,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppAdmin.inkDark)),
              ])),
          if (onTap != null)
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppAdmin.surfaceTint,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                      color: AppAdmin.borderSoft,
                      blurRadius: 4,
                      offset: Offset(2, 2)),
                  BoxShadow(
                      color: Colors.white,
                      blurRadius: 4,
                      offset: Offset(-2, -2)),
                ],
              ),
              child: Icon(Icons.arrow_forward_ios_rounded,
                  size: 12, color: roleColor),
            ),
        ]),
      ),
    );
  }
}

class _NeoInputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  const _NeoInputField(
      {required this.controller,
      required this.hint,
      required this.icon,
      required this.maxLines,
      this.keyboardType,
      this.validator});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppAdmin.surfaceTint,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: AppAdmin.borderSoft,
                blurRadius: 6,
                offset: Offset(3, 3)),
            BoxShadow(
                color: Colors.white, blurRadius: 6, offset: Offset(-3, -3)),
          ],
        ),
        child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(fontSize: 14, color: AppAdmin.inkDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppAdmin.inkLight, fontSize: 13),
            prefixIcon: Icon(icon, color: AppAdmin.inkMid, size: 20),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      );
}

class _NeoActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;
  const _NeoActionButton(
      {required this.label,
      required this.icon,
      required this.gradient,
      required this.onTap});
  @override
  State<_NeoActionButton> createState() => _NeoActionButtonState();
}

class _NeoActionButtonState extends State<_NeoActionButton>
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
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: LinearGradient(
                  colors: widget.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              boxShadow: _pressed
                  ? [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 4,
                          offset: const Offset(2, 2))
                    ]
                  : [
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
                          offset: const Offset(0, -2)),
                    ],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(widget.icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(widget.label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3)),
            ]),
          ),
        ),
      );
}

// ─── Admin Orders Filter Sheet ──────────────────────────────────────────────────
class _OrdersFilterSheet extends StatefulWidget {
  final String initialStatus;
  final String initialRole;
  const _OrdersFilterSheet(
      {required this.initialStatus, required this.initialRole});
  @override
  State<_OrdersFilterSheet> createState() => _OrdersFilterSheetState();
}

class _OrdersFilterSheetState extends State<_OrdersFilterSheet> {
  late String _status;
  late String _role;

  static const _statusOptions = [
    ['all', 'All'],
    ['pending', 'Pending'],
    ['inProgress', 'In Progress'],
    ['completed', 'Completed'],
    ['cancelled', 'Cancelled/Rejected'],
  ];
  static const _roleOptions = [
    ['all', 'All'],
    ['professional', 'Professional'],
    ['contractor', 'Contractor'],
  ];

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    _role = widget.initialRole;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      decoration: BoxDecoration(
        color: AppAdmin.surfaceTint,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
              color: AppAdmin.borderSoft, blurRadius: 20, offset: Offset(8, 8)),
          BoxShadow(
              color: Colors.white, blurRadius: 20, offset: Offset(-8, -8)),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 14),
        Center(
            child: Container(
          width: 44,
          height: 5,
          decoration: BoxDecoration(
            color: AppAdmin.borderSoft,
            borderRadius: BorderRadius.circular(3),
            boxShadow: const [
              BoxShadow(
                  color: Colors.white, blurRadius: 2, offset: Offset(-1, -1)),
              BoxShadow(
                  color: AppAdmin.borderSoft,
                  blurRadius: 2,
                  offset: Offset(1, 1)),
            ],
          ),
        )),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Row(children: [
            const Expanded(
                child: Text('Filter Orders',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppAdmin.inkDark))),
            GestureDetector(
              onTap: () => setState(() {
                _status = 'all';
                _role = 'all';
              }),
              child: const Text('Clear Filters',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppAdmin.dark)),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Status',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppAdmin.inkMid)),
              const SizedBox(height: 10),
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _statusOptions
                      .map((opt) => _AdminFilterChip(
                            label: opt[1],
                            selected: _status == opt[0],
                            onTap: () => setState(() => _status = opt[0]),
                          ))
                      .toList()),
              const SizedBox(height: 20),
              const Text('Provider Type',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppAdmin.inkMid)),
              const SizedBox(height: 10),
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _roleOptions
                      .map((opt) => _AdminFilterChip(
                            label: opt[1],
                            selected: _role == opt[0],
                            onTap: () => setState(() => _role = opt[0]),
                          ))
                      .toList()),
              const SizedBox(height: 24),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: _NeoActionButton(
            label: 'Apply Filters',
            icon: Icons.check_rounded,
            gradient: const [AppAdmin.dark, AppAdmin.darkest],
            onTap: () =>
                Navigator.pop(context, {'status': _status, 'role': _role}),
          ),
        ),
      ]),
    );
  }
}

class _AdminFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _AdminFilterChip(
      {required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppAdmin.dark : AppAdmin.surfaceTint,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
                color: selected ? AppAdmin.dark : AppAdmin.borderSoft,
                width: 1.2),
            boxShadow: selected
                ? null
                : const [
                    BoxShadow(
                        color: AppAdmin.borderSoft,
                        blurRadius: 4,
                        offset: Offset(2, 2)),
                    BoxShadow(
                        color: Colors.white,
                        blurRadius: 4,
                        offset: Offset(-2, -2)),
                  ],
          ),
          child: Text(label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppAdmin.inkMid,
              )),
        ),
      );
}

// ─── Admin Orders Screen ───────────────────────────────────────────────────────
class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key});
  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _searchCtrl = TextEditingController();
  String _query = '';
  // Filters applied in-memory on top of the loaded orders + search query.
  String _statusFilter =
      'all'; // all | pending | inProgress | completed | cancelled
  String _roleFilter = 'all'; // all | professional | contractor
  // Guards against re-showing details for the same pending-id request across
  // rebuilds (same one-shot pattern as _AdminUsersScreenState).
  String? _lastHandledPendingOrderId;

  bool get _filtersActive => _statusFilter != 'all' || _roleFilter != 'all';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matchesStatusFilter(OrderModel o) {
    switch (_statusFilter) {
      case 'pending':
        return o.status == OrderStatus.pending;
      case 'inProgress':
        return o.status == OrderStatus.inProgress;
      case 'completed':
        return o.status == OrderStatus.completed;
      case 'cancelled':
        return o.status == OrderStatus.cancelled;
      default:
        return true;
    }
  }

  bool _matchesRoleFilter(OrderModel o) {
    if (_roleFilter == 'all') return true;
    // Older orders may not have providerRole set — treat those as
    // "professional" since that was the only role before contractors
    // were introduced (same default used when orders are created).
    final role = o.providerRole ?? 'professional';
    return role == _roleFilter;
  }

  void _openFiltersSheet() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrdersFilterSheet(
        initialStatus: _statusFilter,
        initialRole: _roleFilter,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _statusFilter = result['status'] ?? 'all';
        _roleFilter = result['role'] ?? 'all';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ordersAsync = ref.watch(adminFirestoreOrdersProvider);

    if (ordersAsync.isLoading) {
      return const Scaffold(
        backgroundColor: AppAdmin.surfaceTint,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (ordersAsync.hasError) {
      debugPrint('ORDERS_LOAD_ERROR [AdminOrdersScreen]: ${ordersAsync.error}');
      debugPrint(
          'ORDERS_LOAD_STACK [AdminOrdersScreen]: ${ordersAsync.stackTrace}');
      return Scaffold(
        backgroundColor: AppAdmin.surfaceTint,
        body: Center(
          child: Text('Error loading orders',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 14)),
        ),
      );
    }

    final allOrders = ordersAsync.value ?? [];

    // Open the order requested by Admin Complaints ("Open Related Page")
    // once the live orders list has loaded, then never again for this same
    // request (guards against Riverpod rebuilds re-opening the sheet).
    final pendingOrderId = ref.watch(adminPendingOrderDetailsIdProvider);
    if (pendingOrderId != null &&
        pendingOrderId != _lastHandledPendingOrderId) {
      _lastHandledPendingOrderId = pendingOrderId;
      final matches = allOrders.where((o) => o.id == pendingOrderId).toList();
      final matched = matches.isNotEmpty ? matches.first : null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Reset to null so this is a one-shot signal, not persistent state.
        ref.read(adminPendingOrderDetailsIdProvider.notifier).state = null;
        if (!context.mounted) return;
        if (matched != null) {
          showAdminOrderDetails(context, matched, ref);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Related order could not be found.'),
              behavior: SnackBarBehavior.floating));
        }
      });
    }

    final searched = _query.isEmpty
        ? allOrders
        : allOrders.where((o) {
            final q = _query.toLowerCase();
            return o.title.toLowerCase().contains(q) ||
                o.customerName.toLowerCase().contains(q) ||
                o.providerName.toLowerCase().contains(q) ||
                o.id.toLowerCase().contains(q);
          }).toList();
    final orders = searched
        .where((o) => _matchesStatusFilter(o) && _matchesRoleFilter(o))
        .toList();

    final all = orders;
    final pending =
        orders.where((o) => o.status == OrderStatus.pending).toList();
    final inProgress =
        orders.where((o) => o.status == OrderStatus.inProgress).toList();
    final completed =
        orders.where((o) => o.status == OrderStatus.completed).toList();
    final cancelled =
        orders.where((o) => o.status == OrderStatus.cancelled).toList();

    final pendingCount = pending.length;
    final inProgCount = inProgress.length;
    final completedCount = completed.length;
    final cancelledCount = cancelled.length;

    return Scaffold(
      backgroundColor: AppAdmin.surfaceTint,
      body: Column(children: [
        // ── Header ──────────────────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [AppAdmin.inkDarkest, AppAdmin.darkest, AppAdmin.dark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                  color: Color(0x60321143),
                  blurRadius: 28,
                  offset: Offset(0, 12)),
            ],
          ),
          child: SafeArea(
              bottom: false,
              child: Column(children: [
                // Title row
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 16, 0),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppAdmin.accent, AppAdmin.dark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: [
                          BoxShadow(
                              color: AppAdmin.accent.withOpacity(0.45),
                              blurRadius: 10,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: const Icon(Icons.receipt_long_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text('Orders',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)),
                    const Spacer(),
                    // Completed & Cancelled — premium 3D floating menu
                    // (same interaction/animation language as the per-card
                    // three-dots menu). Same two actions, same navigation
                    // destinations and counts as before — presentation only.
                    _OrdersHeaderMenuButton(
                      completedCount: completedCount,
                      cancelledCount: cancelledCount,
                      onCompleted: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _FilteredOrdersPage(
                              title: 'Completed Orders',
                              orders: completed,
                              statusColor: const Color(0xFF059669),
                              icon: Icons.check_circle_outline_rounded,
                              l: l,
                              ref: ref,
                            ),
                          )),
                      onCancelled: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _FilteredOrdersPage(
                              title: 'Cancelled Orders',
                              orders: cancelled,
                              statusColor: AppColors.error,
                              icon: Icons.cancel_outlined,
                              l: l,
                              ref: ref,
                            ),
                          )),
                    ),
                  ]),
                ),
                const SizedBox(height: 18),
              ])),
        ),

        // ── Status Tabs — moved outside/below the purple header, as its
        // own separate elevated component on the light page background
        // (matches the Customer Orders layout: SliverAppBar ends, then a
        // padded stepper bar). Same _AdminOrderStepperBar widget, same
        // counts, same TabController — filtering/count behavior unchanged.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: _AdminOrderStepperBar(
            controller: _tab,
            allCount: all.length,
            pendingCount: pendingCount,
            inProgressCount: inProgCount,
            onTabChanged: (i) => setState(() => _tab.animateTo(i)),
          ),
        ),

        // ── Search + Filter ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppAdmin.surfaceTint,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                        color: AppAdmin.borderSoft,
                        blurRadius: 0,
                        offset: Offset(0, 5)),
                    BoxShadow(
                        color: AppAdmin.borderSoft,
                        blurRadius: 12,
                        offset: Offset(5, 5)),
                    BoxShadow(
                        color: Colors.white,
                        blurRadius: 12,
                        offset: Offset(-4, -4)),
                  ],
                ),
                child: Row(children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [AppAdmin.dark, AppAdmin.darkest],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: AppAdmin.dark.withOpacity(0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3)),
                      ],
                    ),
                    child: const Icon(Icons.search_rounded,
                        color: Colors.white, size: 20),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _query = v),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppAdmin.inkDarkest),
                      decoration: InputDecoration(
                        hintText: 'Search by customer name or order...',
                        hintStyle: TextStyle(
                            color: AppAdmin.inkLight.withOpacity(0.8),
                            fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        suffixIcon: _query.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _searchCtrl.clear();
                                  setState(() => _query = '');
                                },
                                child: const Icon(Icons.close_rounded,
                                    size: 18, color: AppAdmin.inkLight))
                            : null,
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _openFiltersSheet,
              child: Stack(clipBehavior: Clip.none, children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color:
                        _filtersActive ? AppAdmin.dark : AppAdmin.surfaceTint,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: _filtersActive
                        ? [
                            BoxShadow(
                                color: AppAdmin.dark.withOpacity(0.45),
                                blurRadius: 10,
                                offset: const Offset(0, 4))
                          ]
                        : const [
                            BoxShadow(
                                color: AppAdmin.borderSoft,
                                blurRadius: 0,
                                offset: Offset(0, 5)),
                            BoxShadow(
                                color: AppAdmin.borderSoft,
                                blurRadius: 12,
                                offset: Offset(5, 5)),
                            BoxShadow(
                                color: Colors.white,
                                blurRadius: 12,
                                offset: Offset(-4, -4)),
                          ],
                  ),
                  child: Icon(Icons.filter_list_rounded,
                      color: _filtersActive ? Colors.white : AppAdmin.inkLight,
                      size: 22),
                ),
                if (_filtersActive)
                  Positioned(
                      top: -3,
                      right: -3,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: AppAdmin.surfaceTint, width: 2),
                        ),
                      )),
              ]),
            ),
          ]),
        ),

        // ── TabBarView ────────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [all, pending, inProgress]
                .map((list) => _AdminOrdersList(orders: list, l: l, ref: ref))
                .toList(),
          ),
        ),
      ]),
    );
  }
}

// ─── Orders Header Three-Dots Menu (premium 3D, floating neo panel) ───────────
// Presentation-only replacement for the old PopupMenuButton: same trigger
// position, same two actions (Completed / Cancelled) with the same counts
// and navigation destinations, wrapped in the same elevated floating-panel
// language used by the per-card three-dots menu / Customer Orders header.
class _OrdersHeaderMenuButton extends StatefulWidget {
  final int completedCount;
  final int cancelledCount;
  final VoidCallback onCompleted;
  final VoidCallback onCancelled;
  const _OrdersHeaderMenuButton({
    required this.completedCount,
    required this.cancelledCount,
    required this.onCompleted,
    required this.onCancelled,
  });

  @override
  State<_OrdersHeaderMenuButton> createState() =>
      _OrdersHeaderMenuButtonState();
}

class _OrdersHeaderMenuButtonState extends State<_OrdersHeaderMenuButton>
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

  void _open(BuildContext context) {
    HapticFeedback.lightImpact();
    final items = [
      _HeaderMenuItemData(
        icon: Icons.check_circle_outline_rounded,
        label: 'Completed',
        color: const Color(0xFF059669),
        count: widget.completedCount,
        onTap: widget.onCompleted,
      ),
      _HeaderMenuItemData(
        icon: Icons.cancel_outlined,
        label: 'Cancelled',
        color: AppColors.error,
        count: widget.cancelledCount,
        onTap: widget.onCancelled,
      ),
    ];

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.18),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return Stack(children: [
          Positioned.fill(
              child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(color: Colors.transparent))),
          Positioned(
            right: 14,
            top: 70,
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(0.4, -0.3), end: Offset.zero)
                  .animate(curved),
              child: FadeTransition(
                  opacity: anim, child: _HeaderMenuPanel(items: items)),
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
        _open(context);
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
            gradient: LinearGradient(colors: [
              Colors.white.withOpacity(0.22),
              Colors.white.withOpacity(0.10)
            ], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.30), width: 1),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 4)),
              BoxShadow(
                  color: Colors.white.withOpacity(0.12),
                  blurRadius: 6,
                  offset: const Offset(-2, -2)),
            ],
          ),
          child: const Icon(Icons.more_horiz_rounded,
              color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _HeaderMenuItemData {
  final IconData icon;
  final String label;
  final Color color;
  final int count;
  final VoidCallback onTap;
  const _HeaderMenuItemData({
    required this.icon,
    required this.label,
    required this.color,
    required this.count,
    required this.onTap,
  });
}

// ─── Header Menu Panel (floating, staggered animation, neo-3D rows) ───────────
class _HeaderMenuPanel extends StatefulWidget {
  final List<_HeaderMenuItemData> items;
  const _HeaderMenuPanel({required this.items});
  @override
  State<_HeaderMenuPanel> createState() => _HeaderMenuPanelState();
}

class _HeaderMenuPanelState extends State<_HeaderMenuPanel>
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

  // Same neumorphic floating-panel language as the per-card three-dots menu
  // (_AdminMenuPanel): identical panel shadow/radius, and each action is
  // the exact same 48x48 neumorphic circle (same color, same shadow
  // values, direct icon coloring) as the per-card action buttons — just
  // with a label alongside (needed here since Completed/Cancelled aren't
  // self-evident the way per-card action icons are) and a small count
  // badge overlaid on the circle.
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: AppAdmin.surfaceTint,
        boxShadow: const [
          BoxShadow(
              color: AppAdmin.borderSoft, blurRadius: 16, offset: Offset(6, 6)),
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
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  item.onTap();
                },
                child: Row(children: [
                  Stack(clipBehavior: Clip.none, children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppAdmin.surfaceTint,
                        boxShadow: const [
                          BoxShadow(
                              color: AppAdmin.borderSoft,
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
                                  offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Center(
                            child: Text('${item.count}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ),
                  ]),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(item.label,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppAdmin.inkDarkest))),
                ]),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Admin Order Stepper Bar (identical design to customer) ───────────────────
class _OrderTabData {
  final String label;
  final IconData icon;
  final Color activeColor, darkColor;
  const _OrderTabData(
      {required this.label,
      required this.icon,
      required this.activeColor,
      required this.darkColor});
}

class _AdminOrderStepperBar extends StatefulWidget {
  final TabController controller;
  final int allCount, pendingCount, inProgressCount;
  final ValueChanged<int> onTabChanged;
  const _AdminOrderStepperBar({
    required this.controller,
    required this.allCount,
    required this.pendingCount,
    required this.inProgressCount,
    required this.onTabChanged,
  });
  @override
  State<_AdminOrderStepperBar> createState() => _AdminOrderStepperBarState();
}

class _AdminOrderStepperBarState extends State<_AdminOrderStepperBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideCtrl;
  int _prevIndex = 0;

  // Color mapping mirrors Customer Orders' stepper bar: All = green,
  // Pending = amber/orange, In Progress = blue.
  static const _tabs = [
    _OrderTabData(
        label: 'All',
        icon: Icons.list_alt_rounded,
        activeColor: Color(0xFF10B981),
        darkColor: Color(0xFF065F46)),
    _OrderTabData(
        label: 'Pending',
        icon: Icons.hourglass_top_rounded,
        activeColor: Color(0xFFF59E0B),
        darkColor: Color(0xFFB45309)),
    _OrderTabData(
        label: 'In Progress',
        icon: Icons.autorenew_rounded,
        activeColor: Color(0xFF0EA5E9),
        darkColor: Color(0xFF0369A1)),
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
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final current = widget.controller.index;
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
            color: AppAdmin.surfaceTint,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                  color: AppAdmin.borderSoft,
                  blurRadius: 0,
                  offset: Offset(0, 5)),
              BoxShadow(
                  color: AppAdmin.borderSoft,
                  blurRadius: 14,
                  offset: Offset(6, 6)),
              BoxShadow(
                  color: Colors.white, blurRadius: 14, offset: Offset(-6, -6)),
            ],
          ),
          child: Row(
            children: List.generate(_tabs.length, (i) {
              final isActive = current == i;
              final tab = _tabs[i];
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onTabChanged(i);
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
                                  color: AppAdmin.borderSoft,
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
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 260),
                            width: isActive ? 26 : 20,
                            height: isActive ? 26 : 20,
                            decoration: BoxDecoration(
                              gradient: isActive
                                  ? LinearGradient(
                                      colors: [tab.activeColor, tab.darkColor],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight)
                                  : null,
                              color: isActive ? null : Colors.transparent,
                              borderRadius:
                                  BorderRadius.circular(isActive ? 9 : 7),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                          color:
                                              tab.activeColor.withOpacity(0.45),
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
                              child: Icon(tab.icon,
                                  key: ValueKey(isActive),
                                  size: isActive ? 14 : 12,
                                  color: isActive
                                      ? Colors.white
                                      : AppAdmin.inkLight),
                            )),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                              child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 220),
                            style: TextStyle(
                              fontSize: isActive ? 12 : 11,
                              fontWeight:
                                  isActive ? FontWeight.w800 : FontWeight.w600,
                              color: isActive
                                  ? AppAdmin.inkDarkest
                                  : AppAdmin.inkLight,
                              letterSpacing: -0.2,
                            ),
                            child: Text(tab.label,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          )),
                          if (counts[i] > 0) ...[
                            const SizedBox(width: 5),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 260),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? tab.activeColor
                                    : AppAdmin.borderSoft,
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
                              child: Text('${counts[i]}',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: isActive
                                          ? Colors.white
                                          : AppAdmin.inkMid)),
                            ),
                          ],
                        ]),
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

// ─── Filtered Orders Page (Completed / Cancelled) ─────────────────────────────
class _FilteredOrdersPage extends StatelessWidget {
  final String title;
  final List<OrderModel> orders;
  final Color statusColor;
  final IconData icon;
  final AppLocalizations l;
  final WidgetRef ref;
  const _FilteredOrdersPage(
      {required this.title,
      required this.orders,
      required this.statusColor,
      required this.icon,
      required this.l,
      required this.ref});

  @override
  Widget build(BuildContext context) {
    // Status-tinted header — a deep, saturated shade of the page's own
    // status color (green for Completed, red for Cancelled) instead of
    // the near-black AppAdmin.darkest, so the header reads as clearly
    // "completed" / "cancelled" rather than flat and unclear, while still
    // matching the Admin Orders header's dark-premium language.
    final headerDeep = Color.lerp(AppAdmin.darkest, statusColor, 0.20)!;
    final headerMid = Color.lerp(AppAdmin.darkest, statusColor, 0.55)!;

    return Scaffold(
      backgroundColor: AppAdmin.surfaceTint,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 6,
        shadowColor: statusColor.withOpacity(0.35),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [headerDeep, headerMid],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        // Explicit white back button — the global AppBarTheme sets its own
        // dark iconTheme which otherwise wins over AppBar.foregroundColor
        // for the automatic back arrow, rendering it black on this dark
        // header. Wrapped in the same translucent chip treatment as the
        // title icon for a consistent premium look.
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.20),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: Colors.white.withOpacity(0.30)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 6,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: const BackButton(color: Colors.white),
          ),
        ),
        title: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.20),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: Colors.white.withOpacity(0.30)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 6,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ]),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.35)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: Text('${orders.length}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900)),
          ),
        ],
      ),
      body: orders.isEmpty
          ? Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20)),
                      child: Icon(icon,
                          size: 30, color: statusColor.withOpacity(0.5))),
                  const SizedBox(height: 12),
                  Text('No ${title.toLowerCase()} yet',
                      style: TextStyle(
                          color: statusColor.withOpacity(0.6),
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ]))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: orders.length,
              itemBuilder: (ctx, i) =>
                  _AdminOrderCard(order: orders[i], l: l, ref: ref),
            ),
    );
  }
}

// ─── Orders List ──────────────────────────────────────────────────────────────
class _AdminOrdersList extends StatelessWidget {
  final List<OrderModel> orders;
  final AppLocalizations l;
  final WidgetRef ref;
  const _AdminOrdersList(
      {required this.orders, required this.l, required this.ref});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty)
      return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
                color: AppAdmin.lightest,
                borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.receipt_long_outlined,
                size: 32, color: AppAdmin.dark)),
        const SizedBox(height: 12),
        const Text('No orders found',
            style: TextStyle(
                color: AppAdmin.dark,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
      ]));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: orders.length,
      itemBuilder: (ctx, i) =>
          _AdminOrderCard(order: orders[i], l: l, ref: ref),
    );
  }
}

// ─── Admin Order Card (neo-3D) ─────────────────────────────────────────────────
class _AdminOrderCard extends StatelessWidget {
  final OrderModel order;
  final AppLocalizations l;
  final WidgetRef ref;
  const _AdminOrderCard(
      {required this.order, required this.l, required this.ref});

  Color _statusColor(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
        return const Color(0xFFF59E0B);
      case OrderStatus.inProgress:
        // Light blue — matches the In Progress stepper tab and the
        // Customer Orders status language, not the lilac admin brand.
        return const Color(0xFF0EA5E9);
      case OrderStatus.completed:
        return const Color(0xFF059669);
      case OrderStatus.cancelled:
        return AppColors.error;
    }
  }

  String _statusLabel(OrderStatus s) {
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

  IconData _statusIcon(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
        return Icons.hourglass_top_rounded;
      case OrderStatus.inProgress:
        return Icons.autorenew_rounded;
      case OrderStatus.completed:
        return Icons.check_circle_outline_rounded;
      case OrderStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }

  void _showReassign(BuildContext context) {
    if (order.providerRole != 'contractor') {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            const Text('Workers can only be assigned to contractor orders.'),
        backgroundColor: AppAdmin.dark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    if (order.status == OrderStatus.completed ||
        order.status == OrderStatus.cancelled) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text(
            'Cannot reassign worker for completed or cancelled orders.'),
        backgroundColor: AppAdmin.dark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReassignWorkerSheet(order: order, ref: ref),
    );
  }

  void _showDetails(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderDetailsSheet(order: order, l: l, ref: ref));

  // Completed/cancelled orders are final, read-only records — no Edit,
  // Reassign, Approve, Complete, or Cancel action ever applies to them, so
  // the three-dot menu has nothing to show and is hidden entirely.
  bool get _hasAnyMenuAction =>
      order.status == OrderStatus.pending ||
      order.status == OrderStatus.inProgress;

  void _showEdit(BuildContext context) {
    if (order.status == OrderStatus.completed ||
        order.status == OrderStatus.cancelled) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Completed or cancelled orders cannot be edited.'),
        backgroundColor: AppAdmin.dark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _EditOrderSheet(order: order, l: l, ref: ref));
  }

  @override
  Widget build(BuildContext context) {
    final sc = _statusColor(order.status);
    final sl = _statusLabel(order.status);
    final si = _statusIcon(order.status);
    final c2 = Color.lerp(sc, Colors.black, 0.35)!;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppAdmin.surfaceTint,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: sc.withOpacity(0.16), width: 1),
        boxShadow: [
          BoxShadow(
              color: sc.withOpacity(0.26),
              blurRadius: 0,
              offset: const Offset(0, 6)),
          BoxShadow(
              color: sc.withOpacity(0.16),
              blurRadius: 22,
              offset: const Offset(0, 10)),
          BoxShadow(
              color: Colors.white.withOpacity(0.9),
              blurRadius: 8,
              offset: const Offset(-4, -4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _showDetails(context),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Top accent bar — refined slim treatment, same premium
            // language as Customer Orders' card (a thin gradient strip
            // instead of a full-height color block).
            Container(
              height: 5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [sc, sc.withOpacity(0.35)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight),
              ),
            ),

            // ── Header row ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // 3D status icon avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [sc, c2],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.6), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                          color: sc.withOpacity(0.40),
                          blurRadius: 0,
                          offset: const Offset(0, 3)),
                      BoxShadow(
                          color: sc.withOpacity(0.20),
                          blurRadius: 10,
                          offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Icon(si, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order.title,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppAdmin.inkDarkest,
                                letterSpacing: -0.3),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Text(order.providerName,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppAdmin.inkLight,
                                fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ]),
                ),
                const SizedBox(width: 8),
                // Status badge — premium pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: sc.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sc.withOpacity(0.30)),
                    boxShadow: [
                      BoxShadow(
                          color: sc.withOpacity(0.18),
                          blurRadius: 6,
                          offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(si, size: 11, color: sc),
                    const SizedBox(width: 4),
                    Text(sl,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: sc)),
                  ]),
                ),
                // 3-dot menu — hidden entirely when no action applies
                // (e.g. completed/cancelled orders are read-only).
                if (_hasAnyMenuAction) ...[
                  const SizedBox(width: 6),
                  _OrderThreeDotsMenu(
                    order: order,
                    l: l,
                    ref: ref,
                    accentColor: sc,
                    onShowEdit: () => _showEdit(context),
                    onReassign: () => _showReassign(context),
                  ),
                ],
              ]),
            ),

            const SizedBox(height: 12),
            // Gradient divider — visually separates the header from the
            // body, matching Customer Orders' card structure.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.transparent,
                    sc.withOpacity(0.30),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),

            // ── Body ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description
                    Text(order.description,
                        style: const TextStyle(
                            fontSize: 12, color: AppAdmin.inkMid, height: 1.4),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 10),

                    // Info chips
                    Wrap(spacing: 8, runSpacing: 6, children: [
                      if (order.customerName.isNotEmpty)
                        _Neo3DChip(
                            icon: Icons.person_outline,
                            label: order.customerName,
                            color: AppAdmin.dark),
                      _Neo3DChip(
                          icon: Icons.engineering_outlined,
                          label: order.providerName,
                          color: AppAdmin.accent),
                      _Neo3DChip(
                          icon: Icons.location_on_outlined,
                          label: order.area,
                          color: const Color(0xFF059669)),
                      _Neo3DChip(
                          icon: Icons.calendar_today_outlined,
                          label:
                              '${order.serviceDate.day}/${order.serviceDate.month}/${order.serviceDate.year}',
                          color: const Color(0xFF0EA5E9)),
                      if (order.selectedServicePrice != null)
                        _Neo3DChip(
                            icon: Icons.payments_outlined,
                            label:
                                '₪${order.selectedServicePrice!.toStringAsFixed(0)}',
                            color: AppAdmin.accent),
                      if (order.assignedWorkerName != null &&
                          order.assignedWorkerName!.isNotEmpty)
                        _Neo3DChip(
                            icon: Icons.badge_outlined,
                            label: order.assignedWorkerName!,
                            color: AppAdmin.dark),
                    ]),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Order Three-Dots Menu (same style as customer orders) ────────────────────
class _OrderThreeDotsMenu extends StatefulWidget {
  final OrderModel order;
  final AppLocalizations l;
  final WidgetRef ref;
  final VoidCallback onShowEdit;
  final VoidCallback onReassign;
  final Color accentColor;
  const _OrderThreeDotsMenu(
      {required this.order,
      required this.l,
      required this.ref,
      required this.onShowEdit,
      required this.onReassign,
      this.accentColor = AppAdmin.dark});
  @override
  State<_OrderThreeDotsMenu> createState() => _OrderThreeDotsMenuState();
}

class _OrderThreeDotsMenuState extends State<_OrderThreeDotsMenu>
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

  void _open(BuildContext context) {
    HapticFeedback.lightImpact();
    final isPending = widget.order.status == OrderStatus.pending;
    final scaffoldMsg = ScaffoldMessenger.of(context);

    void phaseMsg() {
      scaffoldMsg.showSnackBar(SnackBar(
        content: const Text('This action will be connected in the next phase.'),
        backgroundColor: AppAdmin.dark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }

    void doApprove() {
      widget.ref
          .read(ordersProvider.notifier)
          .approveAdminOrderInFirestore(widget.order.id)
          .then((_) {
        createOrderNotification(
          userId: widget.order.customerId,
          title: 'Order In Progress',
          message: 'Your order is now in progress.',
          orderId: widget.order.id,
        );
        scaffoldMsg.showSnackBar(SnackBar(
          content: const Text('Order approved successfully'),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }).catchError((_) {
        scaffoldMsg.showSnackBar(SnackBar(
          content: const Text('Failed to approve order. Please try again.'),
          backgroundColor: AppAdmin.dark,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      });
    }

    void doComplete() {
      widget.ref
          .read(ordersProvider.notifier)
          .completeAdminOrderInFirestore(widget.order.id)
          .then((_) {
        createOrderNotification(
          userId: widget.order.customerId,
          title: 'Order Completed',
          message: 'Your order was completed successfully.',
          orderId: widget.order.id,
        );
        scaffoldMsg.showSnackBar(SnackBar(
          content: const Text('Order completed successfully'),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }).catchError((_) {
        scaffoldMsg.showSnackBar(SnackBar(
          content: const Text('Failed to complete order. Please try again.'),
          backgroundColor: AppAdmin.dark,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      });
    }

    void doCancel() {
      widget.ref
          .read(ordersProvider.notifier)
          .cancelAdminOrderInFirestore(orderId: widget.order.id)
          .then((_) {
        scaffoldMsg.showSnackBar(SnackBar(
          content: const Text('Order cancelled successfully'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }).catchError((_) {
        scaffoldMsg.showSnackBar(SnackBar(
          content: const Text('Failed to cancel order. Please try again.'),
          backgroundColor: AppAdmin.dark,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      });
    }

    final isInProgress = widget.order.status == OrderStatus.inProgress;
    // Completed/cancelled orders are final and read-only: no Edit, no
    // Reassign. Reassign additionally only applies to Contractor orders —
    // the existing worker-reassignment flow has no concept of a
    // Professional-order worker.
    final isFinal = widget.order.status == OrderStatus.completed ||
        widget.order.status == OrderStatus.cancelled;
    final isContractorOrder = widget.order.providerRole == 'contractor';

    final items = <_AdminMenuItemData>[
      if (!isFinal)
        _AdminMenuItemData(
            icon: Icons.edit_outlined,
            label: 'Edit Order',
            color: AppAdmin.dark,
            onTap: widget.onShowEdit),
      if (!isFinal && isContractorOrder)
        _AdminMenuItemData(
            icon: Icons.swap_horiz_rounded,
            label: 'Reassign',
            color: AppColors.primary,
            onTap: widget.onReassign),
      if (isPending) ...[
        _AdminMenuItemData(
            icon: Icons.check_circle_outline_rounded,
            label: 'Approve',
            color: const Color(0xFF059669),
            onTap: doApprove),
        _AdminMenuItemData(
            icon: Icons.cancel_outlined,
            label: 'Cancel',
            color: AppColors.error,
            onTap: doCancel),
      ],
      if (isInProgress) ...[
        _AdminMenuItemData(
            icon: Icons.done_all_rounded,
            label: 'Complete',
            color: const Color(0xFF059669),
            onTap: doComplete),
        _AdminMenuItemData(
            icon: Icons.cancel_outlined,
            label: 'Cancel',
            color: AppColors.error,
            onTap: doCancel),
      ],
    ];

    final box = context.findRenderObject() as RenderBox?;
    final pos = box?.localToGlobal(Offset.zero) ?? Offset.zero;
    final size = box?.size ?? Size.zero;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.18),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return Stack(children: [
          Positioned.fill(
              child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(color: Colors.transparent))),
          Positioned(
            right: 14,
            top: pos.dy + size.height - 20,
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(0.3, -0.2), end: Offset.zero)
                  .animate(curved),
              child: FadeTransition(
                  opacity: anim, child: _AdminMenuPanel(items: items)),
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
        _open(context);
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
            color: AppAdmin.surfaceTint,
            borderRadius: BorderRadius.circular(11),
            boxShadow: const [
              BoxShadow(
                  color: AppAdmin.borderSoft,
                  blurRadius: 0,
                  offset: Offset(0, 3)),
              BoxShadow(
                  color: AppAdmin.borderSoft,
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
                          color: widget.accentColor.withOpacity(0.75),
                          shape: BoxShape.circle),
                    )),
          ),
        ),
      ),
    );
  }
}

// ─── Admin Menu Data ──────────────────────────────────────────────────────────
class _AdminMenuItemData {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AdminMenuItemData(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
}

// ─── Admin Menu Panel (floating, staggered animation) ─────────────────────────
class _AdminMenuPanel extends StatefulWidget {
  final List<_AdminMenuItemData> items;
  const _AdminMenuPanel({required this.items});
  @override
  State<_AdminMenuPanel> createState() => _AdminMenuPanelState();
}

class _AdminMenuPanelState extends State<_AdminMenuPanel>
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
        color: AppAdmin.surfaceTint,
        boxShadow: const [
          BoxShadow(
              color: AppAdmin.borderSoft, blurRadius: 16, offset: Offset(6, 6)),
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
              padding: const EdgeInsets.symmetric(vertical: 4),
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
                    color: AppAdmin.surfaceTint,
                    boxShadow: const [
                      BoxShadow(
                          color: AppAdmin.borderSoft,
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

// ─── Neo-3D Info Chip ────────────────────────────────────────────────────────
class _Neo3DChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Neo3DChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
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
              color: color.withOpacity(0.08),
              blurRadius: 4,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color.withOpacity(0.9))),
      ]),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _IconActionButton(
      {required this.icon,
      required this.color,
      required this.tooltip,
      required this.onTap});
  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      );
}

// ─── Reassign Worker Bottom Sheet ─────────────────────────────────────────────
class _ReassignWorkerSheet extends ConsumerStatefulWidget {
  final OrderModel order;
  final WidgetRef ref;
  const _ReassignWorkerSheet({required this.order, required this.ref});
  @override
  ConsumerState<_ReassignWorkerSheet> createState() =>
      _ReassignWorkerSheetState();
}

class _ReassignWorkerSheetState extends ConsumerState<_ReassignWorkerSheet> {
  String? _selectedWorkerId;
  WorkerModel? _selectedWorker;

  static const _workerColor = AppAdmin.dark;

  @override
  Widget build(BuildContext context) {
    final workersAsync =
        ref.watch(contractorWorkersByIdProvider(widget.order.providerId));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        color: AppAdmin.surfaceTint,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
              color: AppAdmin.borderSoft, blurRadius: 20, offset: Offset(8, 8)),
          BoxShadow(
              color: Colors.white, blurRadius: 20, offset: Offset(-8, -8)),
        ],
      ),
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 14),
        Center(
            child: Container(
          width: 44,
          height: 5,
          decoration: BoxDecoration(
              color: AppAdmin.borderSoft,
              borderRadius: BorderRadius.circular(3),
              boxShadow: const [
                BoxShadow(
                    color: Colors.white, blurRadius: 2, offset: Offset(-1, -1)),
                BoxShadow(
                    color: AppAdmin.borderSoft,
                    blurRadius: 2,
                    offset: Offset(1, 1))
              ]),
        )),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppAdmin.surfaceTint,
                boxShadow: [
                  BoxShadow(
                      color: AppColors.primary.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(4, 4)),
                  const BoxShadow(
                      color: Colors.white,
                      blurRadius: 8,
                      offset: Offset(-4, -4)),
                ],
              ),
              child: const Icon(Icons.swap_horiz_rounded,
                  color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Reassign Worker',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppAdmin.inkDark)),
                  Text(widget.order.title,
                      style:
                          const TextStyle(fontSize: 12, color: AppAdmin.inkMid),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ])),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                    color: AppAdmin.surfaceTint,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                          color: AppAdmin.borderSoft,
                          blurRadius: 4,
                          offset: Offset(2, 2)),
                      BoxShadow(
                          color: Colors.white,
                          blurRadius: 4,
                          offset: Offset(-2, -2))
                    ]),
                child: const Icon(Icons.close_rounded,
                    size: 16, color: AppAdmin.inkMid),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        // Info banner
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppAdmin.surfaceTint,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                    color: AppAdmin.borderSoft,
                    blurRadius: 6,
                    offset: Offset(3, 3)),
                BoxShadow(
                    color: Colors.white, blurRadius: 6, offset: Offset(-3, -3)),
              ],
            ),
            child: const Row(children: [
              Icon(Icons.info_outline_rounded,
                  color: AppColors.primary, size: 16),
              SizedBox(width: 8),
              Expanded(
                  child: Text(
                      'Select a worker from this contractor to handle the order.',
                      style: TextStyle(
                          fontSize: 12, color: AppAdmin.inkMid, height: 1.4))),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: const Text('Select worker:',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppAdmin.inkMid)),
        ),
        const SizedBox(height: 8),
        // Workers list
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: workersAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, __) => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Failed to load workers.',
                    style: TextStyle(color: AppColors.error)),
              ),
            ),
            data: (workers) {
              if (workers.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No workers found for this contractor.',
                      style: TextStyle(fontSize: 13, color: AppAdmin.inkMid),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: workers.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppAdmin.lightest),
                itemBuilder: (_, i) {
                  final w = workers[i];
                  final selected = _selectedWorkerId == w.id;
                  return InkWell(
                    onTap: () => setState(() {
                      _selectedWorkerId = w.id;
                      _selectedWorker = w;
                    }),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppAdmin.surfaceTint,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                    color: _workerColor.withOpacity(0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4)),
                                const BoxShadow(
                                    color: AppAdmin.borderSoft,
                                    blurRadius: 4,
                                    offset: Offset(3, 3)),
                                const BoxShadow(
                                    color: Colors.white,
                                    blurRadius: 4,
                                    offset: Offset(-3, -3)),
                              ]
                            : const [
                                BoxShadow(
                                    color: AppAdmin.borderSoft,
                                    blurRadius: 4,
                                    offset: Offset(2, 2)),
                                BoxShadow(
                                    color: Colors.white,
                                    blurRadius: 4,
                                    offset: Offset(-2, -2)),
                              ],
                        border: selected
                            ? Border.all(
                                color: _workerColor.withOpacity(0.3),
                                width: 1.5)
                            : null,
                      ),
                      child: Row(children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppAdmin.surfaceTint,
                            boxShadow: [
                              BoxShadow(
                                  color: _workerColor.withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: const Offset(3, 3)),
                              const BoxShadow(
                                  color: Colors.white,
                                  blurRadius: 6,
                                  offset: Offset(-3, -3)),
                            ],
                          ),
                          child: Center(
                              child: Text(w.name.isNotEmpty ? w.name[0] : '?',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: _workerColor))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(w.name,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppAdmin.inkDark)),
                              const SizedBox(height: 2),
                              if (w.specialty.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: _workerColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10)),
                                  child: Text(w.specialty,
                                      style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: _workerColor)),
                                ),
                              if (w.phone != null && w.phone!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(w.phone!,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppAdmin.inkMid)),
                                ),
                            ])),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: selected
                                    ? _workerColor
                                    : AppAdmin.borderSoft,
                                width: selected ? 6 : 2),
                          ),
                        ),
                      ]),
                    ),
                  );
                },
              );
            },
          ),
        ),
        // Confirm button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedWorkerId == null
                  ? null
                  : () {
                      final messenger = ScaffoldMessenger.of(context);
                      final w = _selectedWorker!;
                      Navigator.pop(context);
                      widget.ref
                          .read(ordersProvider.notifier)
                          .reassignWorkerByAdminInFirestore(
                            orderId: widget.order.id,
                            workerId: w.id,
                            workerName: w.name,
                            workerPhone: w.phone,
                            workerSpecialty:
                                w.specialty.isNotEmpty ? w.specialty : null,
                            workerEmail: w.email,
                            currentStatus: widget.order.status,
                          )
                          .then((_) {
                        messenger.showSnackBar(SnackBar(
                          content: const Text('Worker reassigned successfully'),
                          backgroundColor: const Color(0xFF059669),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ));
                      }).catchError((_) {
                        messenger.showSnackBar(SnackBar(
                          content: const Text(
                              'Failed to reassign worker. Please try again.'),
                          backgroundColor: AppColors.error,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ));
                      });
                    },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppAdmin.lightest,
                  elevation: 0,
                  minimumSize: const Size(0, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              child: const Text('Confirm Reassignment',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ),
      ]),
    );
  }
}

class _AdminChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _AdminChip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: AppAdmin.dark),
        const SizedBox(width: 3),
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                color: AppAdmin.dark,
                fontWeight: FontWeight.w500)),
      ]);
}

// ─── CATEGORIES SCREEN ────────────────────────────────────────────────────────
class AdminCategoriesScreen extends ConsumerStatefulWidget {
  const AdminCategoriesScreen({super.key});
  @override
  ConsumerState<AdminCategoriesScreen> createState() =>
      _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends ConsumerState<AdminCategoriesScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showAddDialog(BuildContext context) {
    showCategoryModal(
        context: context, builder: (_) => _CategoryFormDialog(ref: ref));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categories = ref.watch(categoriesProvider).value ?? [];
    final allUsers = ref.watch(adminUsersProvider);
    final filtered = _query.isEmpty
        ? categories
        : categories
            .where((c) =>
                c.nameKey.toLowerCase().contains(_query.toLowerCase()) ||
                (c.description ?? '')
                    .toLowerCase()
                    .contains(_query.toLowerCase()))
            .toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppAdmin.surfaceTint,
      body: Column(children: [
        // ── Header ──
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [AppAdmin.darkest, AppAdmin.dark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28)),
          ),
          child: SafeArea(
              bottom: false,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                  child: Row(children: [
                    const Expanded(
                        child: Text('Categories',
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white))),
                    const SizedBox(width: 10),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text('${categories.length} Categories',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700))),
                    const SizedBox(width: 10),
                    // ── 3-dots overflow menu (premium floating panel) ──
                    _CategoryThreeDotsMenu(
                      trigger: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.more_horiz_rounded,
                              color: Colors.white, size: 20)),
                      itemsBuilder: () {
                        final unread = ref
                            .read(categoryRequestsProvider.notifier)
                            .unreadCount;
                        return [
                          _CategoryMenuItemData(
                              icon: Icons.add_rounded,
                              label: 'Add New Category',
                              colors: const [AppAdmin.dark, AppAdmin.darkest],
                              onTap: () => _showAddDialog(context)),
                          _CategoryMenuItemData(
                              icon: Icons.notifications_outlined,
                              label: 'Category Requests',
                              colors: const [AppAdmin.accent, AppAdmin.dark],
                              badge: unread,
                              onTap: () {
                                // Pass this screen's own long-lived `ref`
                                // (same one _showAddDialog already uses)
                                // through to the Approve flow's Add Category
                                // form, instead of a ref scoped to this
                                // soon-to-be-popped dialog — see
                                // _CategoryRequestsDialog.
                                showCategoryModal(
                                    context: context,
                                    builder: (_) => _CategoryRequestsDialog(
                                        screenRef: ref));
                              }),
                        ];
                      },
                    ),
                  ]),
                ),
              ])),
        ),
        AdminSearchBar(
            ctrl: _searchCtrl,
            query: _query,
            hint: 'Search categories...',
            onChanged: (v) => setState(() => _query = v),
            onClear: () {
              _searchCtrl.clear();
              setState(() => _query = '');
            }),

        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                              color: AppAdmin.lightest,
                              borderRadius: BorderRadius.circular(20)),
                          child: const Icon(Icons.category_outlined,
                              size: 32, color: AppAdmin.dark)),
                      const SizedBox(height: 12),
                      const Text('No categories found',
                          style: TextStyle(
                              color: AppAdmin.dark,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
                    ]))
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.15,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => _CategoryCard(
                    category: filtered[i],
                    allUsers: allUsers,
                    ref: ref,
                  ),
                ),
        ),
      ]),
    );
  }
}

// Mirrors categoryProvidersStreamProvider's matching rules exactly (see
// app_providers.dart) — role must be professional/contractor, soft-deleted
// providers are excluded, and the match is against the normalised
// specialties list with a legacy single-specialty fallback, checked against
// both category.nameKey and category.id. Used to gate Delete Category so a
// category can't be removed while it's still assigned to an active provider.
bool _userMatchesCategoryForDelete(UserModel u, CategoryModel category) {
  if (u.role != UserRole.professional && u.role != UserRole.contractor) {
    return false;
  }
  if (u.isDeleted) return false;
  final normName = category.nameKey.trim().toLowerCase();
  final normId = category.id.trim().toLowerCase();
  final matched = u.specialties.any((s) {
    final ns = s.trim().toLowerCase();
    return ns == normName || (normId.isNotEmpty && ns == normId);
  });
  if (matched) return true;
  if (u.specialties.isEmpty && u.specialty != null) {
    final ns = u.specialty!.trim().toLowerCase();
    return ns == normName || (normId.isNotEmpty && ns == normId);
  }
  return false;
}

List<UserModel> _activeLinkedProviders(
        CategoryModel category, List<UserModel> allUsers) =>
    allUsers.where((u) => _userMatchesCategoryForDelete(u, category)).toList();

// ─── Premium modal shell (Categories) ──────────────────────────────────────
// Same bottom-sheet chrome/visual language as _ChatModalShell (Admin Chat's
// Send Warning etc.) — rounded-top surfaceTint sheet, drag handle, gradient
// header with icon badge/title/subtitle/close button, flexible scrollable
// body, footer slot. Mirrored locally (private to this file) so every
// Categories dialog can share it without touching any other admin screen.
// Presentation-only: no Firestore/provider/callback logic lives here.
Future<T?> showCategoryModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    builder: builder,
  );
}

class _CategoryModalShell extends StatelessWidget {
  final IconData? icon;
  // Overrides [icon] when set — used for the category-emoji header badge in
  // Category Details, which isn't representable as a Material IconData.
  final Widget? iconWidget;
  final String title;
  final String? subtitle;
  final Color accentColor;
  final Widget body;
  final Widget? footer;
  final double maxWidth;
  const _CategoryModalShell({
    this.icon,
    this.iconWidget,
    required this.title,
    this.subtitle,
    required this.accentColor,
    required this.body,
    this.footer,
    this.maxWidth = 480,
  }) : assert(icon != null || iconWidget != null);

  @override
  Widget build(BuildContext context) {
    final headerDeep = Color.lerp(AppAdmin.darkest, accentColor, 0.20)!;
    final headerMid = Color.lerp(AppAdmin.darkest, accentColor, 0.55)!;
    return Padding(
      // Keeps the sheet above the keyboard.
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.88),
            decoration: const BoxDecoration(
              color: AppAdmin.surfaceTint,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                    color: AppAdmin.borderSoft,
                    blurRadius: 24,
                    offset: Offset(0, -8)),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                      color: AppAdmin.borderSoft,
                      borderRadius: BorderRadius.circular(3)),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [headerDeep, headerMid],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  boxShadow: [
                    BoxShadow(
                        color: headerDeep.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 5)),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.25))),
                    child:
                        iconWidget ?? Icon(icon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        if (subtitle != null)
                          Text(subtitle!,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white70),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                      ])),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(11),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.25)),
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ]),
              ),
              Flexible(child: body),
              if (footer != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: footer!,
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── Premium floating action panel (Categories three-dots) ────────────────
// Same 3D/neumorphic floating-panel language as Admin Complaints/Users'
// viewport-aware _AdminMenuPanel + three-dots trigger, adapted with a label
// alongside each icon (matching this screen's existing _catMenuItem/
// _headerCatItem gradient-badge rows) since "Edit"/"Delete"/"Add New
// Category"/"Category Requests" aren't self-evident from an icon alone.
// Private to this file — no shared widget is modified, so Orders' own
// _AdminMenuPanel/_OrderThreeDotsMenu are untouched.
class _CategoryMenuItemData {
  final IconData icon;
  final String label;
  final List<Color> colors;
  final int badge;
  final VoidCallback onTap;
  const _CategoryMenuItemData({
    required this.icon,
    required this.label,
    required this.colors,
    this.badge = 0,
    required this.onTap,
  });
}

class _CategoryMenuPanel extends StatefulWidget {
  final List<_CategoryMenuItemData> items;
  // Set only when the panel wouldn't otherwise fully fit above or below the
  // trigger within the viewport — constrains the item column to the actual
  // available space and makes it scrollable so every action stays reachable
  // instead of being clipped off-screen.
  final double? maxHeight;
  const _CategoryMenuPanel({required this.items, this.maxHeight});
  @override
  State<_CategoryMenuPanel> createState() => _CategoryMenuPanelState();
}

class _CategoryMenuPanelState extends State<_CategoryMenuPanel>
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

  List<Widget> _buildItems() {
    return List.generate(widget.items.length, (i) {
      final item = widget.items[i];
      final n = widget.items.length;
      final anim = CurvedAnimation(
        parent: _ctrl,
        curve: Interval((i / n).clamp(0.0, 1.0), ((i + 1) / n).clamp(0.0, 1.0),
            curve: Curves.easeOutBack),
      );
      return AnimatedBuilder(
        animation: anim,
        builder: (_, child) => Opacity(
          opacity: anim.value.clamp(0.0, 1.0),
          child: Transform.scale(
              scale: 0.6 + 0.4 * anim.value.clamp(0.0, 1.0), child: child),
        ),
        child: GestureDetector(
          onTap: () {
            Navigator.pop(context);
            item.onTap();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: item.colors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: [
                      BoxShadow(
                          color: item.colors[0].withOpacity(0.4),
                          blurRadius: 5,
                          offset: const Offset(0, 3)),
                      BoxShadow(
                          color: item.colors[1],
                          blurRadius: 0,
                          offset: const Offset(0, 2)),
                    ]),
                child: Stack(children: [
                  Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                          height: 14,
                          decoration: BoxDecoration(
                              borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(9),
                                  topRight: Radius.circular(9)),
                              gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withOpacity(0.22),
                                    Colors.transparent
                                  ])))),
                  Center(child: Icon(item.icon, color: Colors.white, size: 15)),
                ]),
              ),
              const SizedBox(width: 12),
              Text(item.label,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppAdmin.inkDarkest)),
              if (item.badge > 0) ...[
                const SizedBox(width: 8),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFFEF4444), Color(0xFF991B1B)]),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text('${item.badge}',
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white))),
              ],
            ]),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget list = widget.maxHeight == null
        ? Column(mainAxisSize: MainAxisSize.min, children: _buildItems())
        : ConstrainedBox(
            constraints: BoxConstraints(maxHeight: widget.maxHeight!),
            child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min, children: _buildItems()),
            ),
          );

    return Container(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 260),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: AppAdmin.surfaceTint,
        boxShadow: const [
          BoxShadow(
              color: AppAdmin.borderSoft, blurRadius: 16, offset: Offset(6, 6)),
          BoxShadow(
              color: Colors.white, blurRadius: 16, offset: Offset(-6, -6)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: list,
    );
  }
}

// Trigger + viewport-aware positioning, identical math to Admin Complaints'
// _ComplaintThreeDotsMenu._open (never renders below the screen, underneath
// the Admin bottom navigation, or above the safe top area; falls back to an
// internally-scrolling panel if neither direction fully fits).
class _CategoryThreeDotsMenu extends StatefulWidget {
  final Widget trigger;
  final List<_CategoryMenuItemData> Function() itemsBuilder;
  const _CategoryThreeDotsMenu(
      {required this.trigger, required this.itemsBuilder});
  @override
  State<_CategoryThreeDotsMenu> createState() => _CategoryThreeDotsMenuState();
}

class _CategoryThreeDotsMenuState extends State<_CategoryThreeDotsMenu>
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

  void _open(BuildContext context) {
    HapticFeedback.lightImpact();
    final items = widget.itemsBuilder();

    final box = context.findRenderObject() as RenderBox?;
    final pos = box?.localToGlobal(Offset.zero) ?? Offset.zero;
    final size = box?.size ?? Size.zero;

    final mq = MediaQuery.of(context);
    const edgeMargin = 14.0;
    const bottomNavSafetyMargin = 84.0;
    final topSafeBound = mq.padding.top + edgeMargin;
    final bottomSafeBound =
        mq.size.height - mq.padding.bottom - bottomNavSafetyMargin - edgeMargin;

    const panelVerticalPadding = 20.0;
    const itemRowHeight = 48.0;
    final estimatedPanelHeight =
        panelVerticalPadding + items.length * itemRowHeight;

    final spaceBelow = bottomSafeBound - (pos.dy + size.height);
    final spaceAbove = pos.dy - topSafeBound;

    final bool openDownward;
    double? maxPanelHeight;
    if (spaceBelow >= estimatedPanelHeight) {
      openDownward = true;
    } else if (spaceAbove >= estimatedPanelHeight) {
      openDownward = false;
    } else {
      openDownward = spaceBelow >= spaceAbove;
      final available = openDownward ? spaceBelow : spaceAbove;
      maxPanelHeight = available.clamp(0.0, estimatedPanelHeight);
    }

    // Horizontal: anchor to the tapped trigger's own global position (not a
    // fixed screen-edge offset) so the panel opens beside the exact card
    // that was tapped instead of always snapping to the same screen-relative
    // spot — the previous fixed `right: rightInset` ignored `pos.dx`
    // entirely, so every card (including left-column ones) opened its panel
    // pinned to the screen's right edge, making it appear to belong to a
    // neighboring card.
    const panelWidth = 260.0;
    final triggerLeft = pos.dx;
    final triggerRight = pos.dx + size.width;
    // Prefer opening to the right of the trigger (panel's left edge flush
    // with the trigger's left edge); fall back to opening to the left of
    // the trigger (panel's right edge flush with the trigger's right edge)
    // when there isn't enough room on the right.
    final spaceRight = mq.size.width - edgeMargin - triggerLeft;
    final spaceLeft = triggerRight - edgeMargin;
    final openRight = spaceRight >= panelWidth || spaceRight >= spaceLeft;
    var leftOffset = openRight ? triggerLeft : triggerRight - panelWidth;
    const minLeft = edgeMargin;
    final rawMaxLeft = mq.size.width - edgeMargin - panelWidth;
    final maxLeft = rawMaxLeft < minLeft ? minLeft : rawMaxLeft;
    leftOffset = leftOffset.clamp(minLeft, maxLeft);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.18),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return Stack(children: [
          Positioned.fill(
              child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(color: Colors.transparent))),
          Positioned(
            left: leftOffset,
            top: openDownward ? pos.dy + size.height - 20 : null,
            bottom: openDownward ? null : mq.size.height - pos.dy - 20,
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: Offset(
                          openRight ? 0.3 : -0.3, openDownward ? -0.2 : 0.2),
                      end: Offset.zero)
                  .animate(curved),
              child: FadeTransition(
                  opacity: anim,
                  child: _CategoryMenuPanel(
                      items: items, maxHeight: maxPanelHeight)),
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
        _open(context);
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) =>
            Transform.scale(scale: 1.0 - 0.08 * _ctrl.value, child: child),
        child: widget.trigger,
      ),
    );
  }
}

// ─── Category Card Menu — compact Orders-style floating panel ─────────────
// Distinct from _CategoryMenuItemData/_CategoryMenuPanel/_CategoryThreeDotsMenu
// above (which stay exactly as-is for the header's Add/Requests menu). The
// per-card Edit/Delete menu instead mirrors _AdminMenuItemData/_AdminMenuPanel
// (Admin Orders' per-card action menu) exactly: icon-only 48x48 circles in a
// compact 64-wide floating column, not a wide labeled panel.
class _CategoryCardMenuItemData {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _CategoryCardMenuItemData(
      {required this.icon, required this.color, required this.onTap});
}

class _CategoryCardMenuPanel extends StatefulWidget {
  final List<_CategoryCardMenuItemData> items;
  // Set only when the panel wouldn't otherwise fully fit above or below the
  // trigger within the viewport — same viewport-safety contract as
  // _CategoryMenuPanel.maxHeight.
  final double? maxHeight;
  const _CategoryCardMenuPanel({required this.items, this.maxHeight});
  @override
  State<_CategoryCardMenuPanel> createState() => _CategoryCardMenuPanelState();
}

class _CategoryCardMenuPanelState extends State<_CategoryCardMenuPanel>
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

  List<Widget> _buildItems() {
    return List.generate(widget.items.length, (i) {
      final item = widget.items[i];
      final n = widget.items.length;
      final anim = CurvedAnimation(
        parent: _ctrl,
        curve: Interval((i / n).clamp(0.0, 1.0), ((i + 1) / n).clamp(0.0, 1.0),
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
          padding: const EdgeInsets.symmetric(vertical: 4),
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
                color: AppAdmin.surfaceTint,
                boxShadow: const [
                  BoxShadow(
                      color: AppAdmin.borderSoft,
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget list = widget.maxHeight == null
        ? Column(mainAxisSize: MainAxisSize.min, children: _buildItems())
        : ConstrainedBox(
            constraints: BoxConstraints(maxHeight: widget.maxHeight!),
            child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min, children: _buildItems()),
            ),
          );

    return Container(
      width: 64,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: AppAdmin.surfaceTint,
        boxShadow: const [
          BoxShadow(
              color: AppAdmin.borderSoft, blurRadius: 16, offset: Offset(6, 6)),
          BoxShadow(
              color: Colors.white, blurRadius: 16, offset: Offset(-6, -6)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: list,
    );
  }
}

// Trigger + viewport-aware positioning for the compact per-card panel above.
// Same anchor-to-trigger/flip/clamp/scroll math as _CategoryThreeDotsMenu,
// just sized for the narrower 64-wide icon-only panel instead of the
// 260-wide labeled one.
class _CategoryCardThreeDotsMenu extends StatefulWidget {
  final Widget trigger;
  final List<_CategoryCardMenuItemData> Function() itemsBuilder;
  const _CategoryCardThreeDotsMenu(
      {required this.trigger, required this.itemsBuilder});
  @override
  State<_CategoryCardThreeDotsMenu> createState() =>
      _CategoryCardThreeDotsMenuState();
}

class _CategoryCardThreeDotsMenuState extends State<_CategoryCardThreeDotsMenu>
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

  void _open(BuildContext context) {
    HapticFeedback.lightImpact();
    final items = widget.itemsBuilder();

    final box = context.findRenderObject() as RenderBox?;
    final pos = box?.localToGlobal(Offset.zero) ?? Offset.zero;
    final size = box?.size ?? Size.zero;

    final mq = MediaQuery.of(context);
    const edgeMargin = 14.0;
    const bottomNavSafetyMargin = 84.0;
    final topSafeBound = mq.padding.top + edgeMargin;
    final bottomSafeBound =
        mq.size.height - mq.padding.bottom - bottomNavSafetyMargin - edgeMargin;

    const panelVerticalPadding = 20.0;
    const itemRowHeight = 56.0;
    final estimatedPanelHeight =
        panelVerticalPadding + items.length * itemRowHeight;

    final spaceBelow = bottomSafeBound - (pos.dy + size.height);
    final spaceAbove = pos.dy - topSafeBound;

    final bool openDownward;
    double? maxPanelHeight;
    if (spaceBelow >= estimatedPanelHeight) {
      openDownward = true;
    } else if (spaceAbove >= estimatedPanelHeight) {
      openDownward = false;
    } else {
      openDownward = spaceBelow >= spaceAbove;
      final available = openDownward ? spaceBelow : spaceAbove;
      maxPanelHeight = available.clamp(0.0, estimatedPanelHeight);
    }

    // Horizontal: anchor to the tapped trigger's own global position (same
    // fix as _CategoryThreeDotsMenu) so the compact panel opens beside the
    // exact card that was tapped.
    const panelWidth = 64.0;
    final triggerLeft = pos.dx;
    final triggerRight = pos.dx + size.width;
    final spaceRight = mq.size.width - edgeMargin - triggerLeft;
    final spaceLeft = triggerRight - edgeMargin;
    final openRight = spaceRight >= panelWidth || spaceRight >= spaceLeft;
    var leftOffset = openRight ? triggerLeft : triggerRight - panelWidth;
    const minLeft = edgeMargin;
    final rawMaxLeft = mq.size.width - edgeMargin - panelWidth;
    final maxLeft = rawMaxLeft < minLeft ? minLeft : rawMaxLeft;
    leftOffset = leftOffset.clamp(minLeft, maxLeft);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.18),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return Stack(children: [
          Positioned.fill(
              child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(color: Colors.transparent))),
          Positioned(
            left: leftOffset,
            top: openDownward ? pos.dy + size.height - 20 : null,
            bottom: openDownward ? null : mq.size.height - pos.dy - 20,
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: Offset(
                          openRight ? 0.3 : -0.3, openDownward ? -0.2 : 0.2),
                      end: Offset.zero)
                  .animate(curved),
              child: FadeTransition(
                  opacity: anim,
                  child: _CategoryCardMenuPanel(
                      items: items, maxHeight: maxPanelHeight)),
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
        _open(context);
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) =>
            Transform.scale(scale: 1.0 - 0.08 * _ctrl.value, child: child),
        child: widget.trigger,
      ),
    );
  }
}

// ─── Category Card ─────────────────────────────────────────────────────────────
class _CategoryCard extends StatelessWidget {
  final CategoryModel category;
  final List<UserModel> allUsers;
  final WidgetRef ref;
  const _CategoryCard(
      {required this.category, required this.allUsers, required this.ref});

  List<UserModel> get _linkedUsers => allUsers
      .where((u) =>
          u.specialty == category.nameKey ||
          u.specialties.contains(category.nameKey))
      .toList();

  void _showDetails(BuildContext context) {
    showCategoryModal(
        context: context,
        builder: (_) => _CategoryDetailsDialog(
            category: category, linkedUsers: _linkedUsers));
  }

  void _showEdit(BuildContext context) {
    showCategoryModal(
        context: context,
        builder: (_) => _CategoryFormDialog(category: category, ref: ref));
  }

  // Zero-linked-providers path only (Part 4). Delete is gated in onSelected:
  // this is never invoked while _activeLinkedProviders is non-empty — see
  // _showInUseDialog for that path (Part 3), which never calls Firestore.
  void _confirmDelete(BuildContext context) {
    bool isDeleting = false;
    String? error;
    showCategoryModal(
      context: context,
      // Destructive action — require an explicit Cancel/Delete tap rather
      // than tap-outside/swipe dismissal, same intent as the previous
      // Dialog's `barrierDismissible: !isDeleting` + PopScope guard.
      isDismissible: false,
      enableDrag: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => PopScope(
          canPop: !isDeleting,
          child: _CategoryModalShell(
            icon: Icons.delete_forever_rounded,
            title: 'Delete Category',
            subtitle: category.nameKey,
            accentColor: AppColors.error,
            body: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(
                            fontSize: 13, color: AppAdmin.darkest, height: 1.5),
                        children: [
                          const TextSpan(text: 'Category: '),
                          TextSpan(
                              text: category.nameKey,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          TextSpan(
                              text:
                                  '\nCurrent provider count: ${category.providerCount}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                        'This category will be removed from category browsing and future registration options.',
                        style: TextStyle(
                            fontSize: 12, color: AppAdmin.dark, height: 1.4)),
                    const SizedBox(height: 6),
                    const Text(
                        'Historical orders, reviews, chats, and other existing records will not be modified.',
                        style: TextStyle(
                            fontSize: 12, color: AppAdmin.dark, height: 1.4)),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(10)),
                        child: Text('Error: $error',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.error)),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ]),
            ),
            footer: Row(children: [
              Expanded(
                  child: GestureDetector(
                onTap: isDeleting ? null : () => Navigator.pop(dialogCtx),
                child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                        color: AppAdmin.surfaceTint,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: const [
                          BoxShadow(
                              color: AppAdmin.borderSoft,
                              blurRadius: 6,
                              offset: Offset(3, 3)),
                          BoxShadow(
                              color: Colors.white,
                              blurRadius: 6,
                              offset: Offset(-3, -3)),
                        ]),
                    child: const Center(
                        child: Text('Cancel',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppAdmin.inkLight)))),
              )),
              const SizedBox(width: 12),
              Expanded(
                child: isDeleting
                    ? Container(
                        height: 52,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(26),
                            gradient: const LinearGradient(colors: [
                              Color(0xFFEF4444),
                              Color(0xFF991B1B)
                            ])),
                        child: const Center(
                            child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.white)))),
                      )
                    : _CatNeoButton(
                        label: 'Delete',
                        icon: Icons.delete_outline_rounded,
                        isDanger: true,
                        onTap: () async {
                          if (isDeleting) return;
                          setDialogState(() {
                            isDeleting = true;
                            error = null;
                          });
                          try {
                            await ref
                                .read(adminCategoriesProvider.notifier)
                                .deleteCategory(category.id);
                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(
                                      'Category "${category.nameKey}" deleted'),
                                  backgroundColor: AppColors.error,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12))));
                            }
                          } catch (e) {
                            setDialogState(() {
                              isDeleting = false;
                              error = e.toString();
                            });
                          }
                        },
                      ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // Part 3 — one or more active providers are linked. Delete is never
  // attempted from here: no Firestore call, no provider-profile mutation.
  // Rows reuse the exact same "open Admin Users → Admin User Details while
  // keeping the bottom nav visible" hand-off that _CategoryDetailsDialog
  // already uses (adminPendingUserDetailsIdProvider + adminNavIndexProvider).
  void _showInUseDialog(BuildContext context, List<UserModel> linked) {
    showCategoryModal(
      context: context,
      builder: (_) => _CategoryModalShell(
        icon: Icons.warning_amber_rounded,
        title: 'Category Is In Use',
        subtitle: category.nameKey,
        accentColor: const Color(0xFFF59E0B),
        body: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
                'This category is currently assigned to ${linked.length} provider(s). Remove or change their specialty before deleting the category.',
                style: const TextStyle(
                    fontSize: 12.5, color: AppAdmin.darkest, height: 1.4)),
          ),
          const SizedBox(height: 4),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              itemCount: linked.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final u = linked[i];
                final roleLabel = u.role == UserRole.contractor
                    ? 'Contractor'
                    : 'Professional';
                final roleColor = u.role == UserRole.contractor
                    ? const Color(0xFF7C3AED)
                    : AppColors.success;
                return Container(
                  decoration: BoxDecoration(
                      color: AppAdmin.surfaceTint,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                            color: AppAdmin.borderSoft,
                            blurRadius: 0,
                            offset: Offset(0, 3)),
                        BoxShadow(
                            color: AppAdmin.borderSoft,
                            blurRadius: 6,
                            offset: Offset(3, 3)),
                        BoxShadow(
                            color: Colors.white,
                            blurRadius: 6,
                            offset: Offset(-3, -3)),
                      ]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          // Close this dialog, then hand off to the
                          // existing Admin Users tab (same pattern as
                          // Category Details → provider row tap).
                          Navigator.of(context).pop();
                          ref
                              .read(adminPendingUserDetailsIdProvider.notifier)
                              .state = u.id;
                          ref.read(adminNavIndexProvider.notifier).state = 1;
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                  color: roleColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12)),
                              child: ProfileAvatarImage(
                                imageUrl: u.avatar,
                                size: 40,
                                borderRadius: 12,
                                fallbackText:
                                    u.fullName.isNotEmpty ? u.fullName : '?',
                                fallbackTextStyle: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: roleColor),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Expanded(
                                          child: Text(u.fullName,
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppAdmin.darkest),
                                              overflow: TextOverflow.ellipsis)),
                                      Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                              color: roleColor.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(20)),
                                          child: Text(roleLabel,
                                              style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                  color: roleColor))),
                                    ]),
                                    if (u.email.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Row(children: [
                                        const Icon(Icons.email_outlined,
                                            size: 11, color: AppAdmin.mid),
                                        const SizedBox(width: 4),
                                        Expanded(
                                            child: Text(u.email,
                                                style: const TextStyle(
                                                    fontSize: 10,
                                                    color: AppAdmin.mid),
                                                overflow:
                                                    TextOverflow.ellipsis)),
                                      ]),
                                    ],
                                    if (u.phone.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Row(children: [
                                        const Icon(Icons.phone_outlined,
                                            size: 11, color: AppAdmin.dark),
                                        const SizedBox(width: 4),
                                        Text(u.phone,
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color: AppAdmin.dark)),
                                      ]),
                                    ],
                                  ]),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                size: 18, color: AppAdmin.mid),
                          ]),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ]),
        footer: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                  color: AppAdmin.surfaceTint,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: const [
                    BoxShadow(
                        color: AppAdmin.borderSoft,
                        blurRadius: 6,
                        offset: Offset(3, 3)),
                    BoxShadow(
                        color: Colors.white,
                        blurRadius: 6,
                        offset: Offset(-3, -3)),
                  ]),
              child: const Center(
                  child: Text('Close',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppAdmin.inkLight)))),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final linked = _linkedUsers;
    final realCount =
        linked.isNotEmpty ? linked.length : category.providerCount;
    bool _pressed = false;

    return StatefulBuilder(
      builder: (context, setCardState) {
        return GestureDetector(
          onTapDown: (_) {
            HapticFeedback.lightImpact();
            setCardState(() => _pressed = true);
          },
          onTapUp: (_) {
            setCardState(() => _pressed = false);
            _showDetails(context);
          },
          onTapCancel: () => setCardState(() => _pressed = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: AppAdmin.surfaceTint,
              boxShadow: _pressed
                  ? const [
                      BoxShadow(
                          color: AppAdmin.borderSoft,
                          blurRadius: 6,
                          offset: Offset(2, 2)),
                      BoxShadow(
                          color: Colors.white,
                          blurRadius: 6,
                          offset: Offset(-2, -2)),
                    ]
                  : const [
                      BoxShadow(
                          color: AppAdmin.borderSoft,
                          blurRadius: 14,
                          offset: Offset(6, 6)),
                      BoxShadow(
                          color: Colors.white,
                          blurRadius: 14,
                          offset: Offset(-6, -6)),
                    ],
            ),
            child: Stack(children: [
              // ── Main content centered ──
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Icon inset neumorphic
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: AppAdmin.surfaceTint,
                          boxShadow: _pressed
                              ? const [
                                  BoxShadow(
                                      color: AppAdmin.borderSoft,
                                      blurRadius: 4,
                                      offset: Offset(2, 2)),
                                  BoxShadow(
                                      color: Colors.white,
                                      blurRadius: 4,
                                      offset: Offset(-2, -2)),
                                ]
                              : const [
                                  BoxShadow(
                                      color: AppAdmin.borderSoft,
                                      blurRadius: 8,
                                      offset: Offset(4, 4)),
                                  BoxShadow(
                                      color: Colors.white,
                                      blurRadius: 8,
                                      offset: Offset(-4, -4)),
                                ],
                        ),
                        child: Center(
                          child: Text(category.icon,
                              style: const TextStyle(fontSize: 22)),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          category.nameKey,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppAdmin.inkDarkest,
                              letterSpacing: 0.1),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // providers count chip
                      Align(
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: AppAdmin.surfaceTint,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(
                                    color: AppAdmin.borderSoft,
                                    blurRadius: 0,
                                    offset: Offset(0, 2)),
                                BoxShadow(
                                    color: AppAdmin.borderSoft,
                                    blurRadius: 5,
                                    offset: Offset(2, 2)),
                                BoxShadow(
                                    color: Colors.white,
                                    blurRadius: 5,
                                    offset: Offset(-2, -2)),
                              ]),
                          child: Text('$realCount providers',
                              style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppAdmin.inkLight)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Provider count badge top-left ──
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                      color: AppAdmin.surfaceTint,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                            color: AppAdmin.borderSoft,
                            blurRadius: 0,
                            offset: Offset(0, 2)),
                        BoxShadow(
                            color: Colors.white,
                            blurRadius: 4,
                            offset: Offset(-2, -2)),
                      ]),
                  child: Text('$realCount',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppAdmin.inkDarkest)),
                ),
              ),

              // ── Three-dot menu top-right (premium floating panel) ──
              Positioned(
                top: 6,
                right: 6,
                child: _CategoryCardThreeDotsMenu(
                  trigger: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                        color: AppAdmin.surfaceTint,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: const [
                          BoxShadow(
                              color: AppAdmin.borderSoft,
                              blurRadius: 0,
                              offset: Offset(0, 3)),
                          BoxShadow(
                              color: AppAdmin.borderSoft,
                              blurRadius: 5,
                              offset: Offset(3, 3)),
                          BoxShadow(
                              color: Colors.white,
                              blurRadius: 5,
                              offset: Offset(-3, -3)),
                        ]),
                    child: const Icon(Icons.more_horiz_rounded,
                        color: AppAdmin.inkLight, size: 16),
                  ),
                  itemsBuilder: () => [
                    _CategoryCardMenuItemData(
                        icon: Icons.edit_outlined,
                        color: AppAdmin.dark,
                        onTap: () => _showEdit(context)),
                    _CategoryCardMenuItemData(
                        icon: Icons.delete_outline_rounded,
                        color: AppColors.error,
                        onTap: () {
                          final activeLinked =
                              _activeLinkedProviders(category, allUsers);
                          if (activeLinked.isNotEmpty) {
                            _showInUseDialog(context, activeLinked);
                          } else {
                            _confirmDelete(context);
                          }
                        }),
                  ],
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

// ─── Small icon button for category card ──────────────────────────────────────
class _CatIconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _CatIconBtn(
      {required this.icon,
      required this.color,
      required this.tooltip,
      required this.onTap});
  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 15, color: color),
          ),
        ),
      );
}

// ─── Category Form Dialog (Add + Edit) ────────────────────────────────────────
class _CategoryFormDialog extends StatefulWidget {
  final CategoryModel? category; // null = add mode
  final WidgetRef ref;
  // Set only when this form was opened by pressing "Approve" on a pending
  // Category Request (see _CategoryRequestsDialog) — Name/Description
  // preload from it, and a successful Save approves the originating
  // request (via the existing combined CategoryRequestsNotifier.
  // approveInFirestore) instead of the normal AdminCategoriesNotifier.
  // addCategory path. Opening this form never touches the request itself;
  // only a successful Save does.
  final CategoryRequest? sourceRequest;
  const _CategoryFormDialog(
      {this.category, required this.ref, this.sourceRequest});
  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _iconCtrl;
  late final TextEditingController _descCtrl;
  bool _saving = false;

  bool get _isEdit => widget.category != null;
  bool get _isFromRequest => widget.sourceRequest != null;

  // Common emojis for quick pick
  static const List<String> _quickEmojis = [
    '⚡',
    '🔨',
    '🔧',
    '🖌️',
    '🧱',
    '🌿',
    '❄️',
    '🔩',
    '🔥',
    '⚒️',
    '🧵',
    '🧹',
    '✨',
    '🏠',
    '🚗',
    '💻',
    '📱',
    '🎨',
    '🌟',
    '🛠️',
    '⭐',
    '🏗️',
    '🌊',
    '🪴',
    '🔑',
  ];

  @override
  void initState() {
    super.initState();
    final req = widget.sourceRequest;
    // Category Name/Description preload from the originating request when
    // opened via Approve; the request model stores no icon at all, so icon
    // always starts empty/default here regardless of source, same as a
    // normal Add Category — Admin picks it.
    _nameCtrl = TextEditingController(
        text: widget.category?.nameKey ?? req?.categoryName ?? '');
    _iconCtrl = TextEditingController(text: widget.category?.icon ?? '');
    _descCtrl = TextEditingController(
        text: widget.category?.description ?? req?.message ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _iconCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  InputDecoration _neoDec(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppAdmin.inkLight, fontSize: 13),
        prefixIcon: Icon(icon, color: AppAdmin.inkMid, size: 20),
        border: InputBorder.none,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );

  @override
  Widget build(BuildContext context) {
    return _CategoryModalShell(
      icon: _isEdit ? Icons.edit_outlined : Icons.add_rounded,
      title: _isEdit ? 'Edit Category' : 'Add New Category',
      accentColor: AppAdmin.dark,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Reviewing-request context banner (Approve → Add Category) ──
          if (_isFromRequest)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                    color: AppAdmin.surfaceTint,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                          color: AppAdmin.borderSoft,
                          blurRadius: 4,
                          offset: Offset(2, 2)),
                      BoxShadow(
                          color: Colors.white,
                          blurRadius: 4,
                          offset: Offset(-2, -2)),
                    ]),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 15, color: AppAdmin.inkMid),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(
                          'Reviewing category request from '
                          '${widget.sourceRequest!.requestedByUserName}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppAdmin.inkMid))),
                ]),
              ),
            ),

          // ── Form ──
          Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon preview
                  Center(
                      child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                        color: AppAdmin.surfaceTint,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [
                          BoxShadow(
                              color: AppAdmin.borderSoft,
                              blurRadius: 10,
                              offset: Offset(5, 5)),
                          BoxShadow(
                              color: Colors.white,
                              blurRadius: 10,
                              offset: Offset(-5, -5)),
                        ]),
                    child: Center(
                        child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _iconCtrl,
                      builder: (_, val, __) => Text(
                          val.text.isEmpty ? '📦' : val.text,
                          style: const TextStyle(fontSize: 34)),
                    )),
                  )),
                  const SizedBox(height: 18),

                  // Quick emoji picker label
                  const Text('Quick icon pick:',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppAdmin.inkMid)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: _quickEmojis
                        .map((e) => GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() => _iconCtrl.text = e);
                              },
                              child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 120),
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                      color: AppAdmin.surfaceTint,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: _iconCtrl.text == e
                                          ? const [
                                              BoxShadow(
                                                  color: AppAdmin.borderSoft,
                                                  blurRadius: 3,
                                                  offset: Offset(2, 2)),
                                              BoxShadow(
                                                  color: Colors.white,
                                                  blurRadius: 3,
                                                  offset: Offset(-2, -2)),
                                            ]
                                          : const [
                                              BoxShadow(
                                                  color: AppAdmin.borderSoft,
                                                  blurRadius: 6,
                                                  offset: Offset(3, 3)),
                                              BoxShadow(
                                                  color: Colors.white,
                                                  blurRadius: 6,
                                                  offset: Offset(-3, -3)),
                                            ]),
                                  child: Center(
                                      child: Text(e,
                                          style:
                                              const TextStyle(fontSize: 19)))),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 18),

                  // Emoji input
                  const Text('Or type an emoji manually',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppAdmin.inkMid)),
                  const SizedBox(height: 8),
                  Container(
                      decoration: BoxDecoration(
                          color: AppAdmin.surfaceTint,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                                color: AppAdmin.borderSoft,
                                blurRadius: 6,
                                offset: Offset(3, 3)),
                            BoxShadow(
                                color: Colors.white,
                                blurRadius: 6,
                                offset: Offset(-3, -3)),
                          ]),
                      child: TextFormField(
                        controller: _iconCtrl,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                            fontSize: 14, color: AppAdmin.inkDark),
                        decoration:
                            _neoDec('e.g. 🏠', Icons.emoji_emotions_outlined),
                      )),
                  const SizedBox(height: 16),

                  // Name input
                  const Text('Category Name',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppAdmin.inkMid)),
                  const SizedBox(height: 8),
                  Container(
                      decoration: BoxDecoration(
                          color: AppAdmin.surfaceTint,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                                color: AppAdmin.borderSoft,
                                blurRadius: 6,
                                offset: Offset(3, 3)),
                            BoxShadow(
                                color: Colors.white,
                                blurRadius: 6,
                                offset: Offset(-3, -3)),
                          ]),
                      child: TextFormField(
                        controller: _nameCtrl,
                        style: const TextStyle(
                            fontSize: 14, color: AppAdmin.inkDark),
                        decoration: _neoDec(
                            'Category Name', Icons.label_outline_rounded),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      )),
                  const SizedBox(height: 16),

                  // Description input
                  const Text('Category Description (optional)',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppAdmin.inkMid)),
                  const SizedBox(height: 8),
                  Container(
                      decoration: BoxDecoration(
                          color: AppAdmin.surfaceTint,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                                color: AppAdmin.borderSoft,
                                blurRadius: 6,
                                offset: Offset(3, 3)),
                            BoxShadow(
                                color: Colors.white,
                                blurRadius: 6,
                                offset: Offset(-3, -3)),
                          ]),
                      child: TextFormField(
                        controller: _descCtrl,
                        maxLines: 2,
                        style: const TextStyle(
                            fontSize: 14, color: AppAdmin.inkDark),
                        decoration: _neoDec('Description (optional)',
                            Icons.description_outlined),
                      )),
                  const SizedBox(height: 8),
                ],
              )),
        ]),
      ),
      footer: Row(children: [
        // Cancel — neumorphic outline
        Expanded(
            child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
              height: 52,
              decoration: BoxDecoration(
                  color: AppAdmin.surfaceTint,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: const [
                    BoxShadow(
                        color: AppAdmin.borderSoft,
                        blurRadius: 6,
                        offset: Offset(3, 3)),
                    BoxShadow(
                        color: Colors.white,
                        blurRadius: 6,
                        offset: Offset(-3, -3)),
                  ]),
              child: const Center(
                  child: Text('Cancel',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppAdmin.inkLight)))),
        )),
        const SizedBox(width: 12),
        // Save — 3D dark button
        Expanded(
            child: _CatNeoButton(
          label: _isEdit ? 'Save Changes' : 'Add Category',
          icon: _isEdit ? Icons.save_outlined : Icons.add_rounded,
          onTap: _save,
        )),
      ]),
    );
  }

  void _save() {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    final icon = _iconCtrl.text.trim().isEmpty ? '📦' : _iconCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final desc = _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();
    _doSave(name: name, icon: icon, desc: desc);
  }

  void _errorSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  Future<void> _doSave(
      {required String name, required String icon, String? desc}) async {
    setState(() => _saving = true);
    // Set only if the atomic commit above already succeeded but the
    // best-effort notification afterward failed — must never turn a
    // successful approval into a reported error.
    var notificationFailed = false;
    try {
      if (_isEdit) {
        await widget.ref.read(adminCategoriesProvider.notifier).updateCategory(
            widget.category!
                .copyWith(nameKey: name, icon: icon, description: desc));
      } else {
        final id = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
        final newCat = CategoryModel(
          id: id,
          nameKey: name,
          icon: icon,
          providerCount: 0,
          description: desc,
        );

        final req = widget.sourceRequest;
        if (req != null) {
          // Same normalized nameKey comparison the old inline Approve flow
          // already used — now it blocks creation (keeping the request
          // pending and this form open) instead of silently skipping
          // category creation while still marking the request approved.
          final liveCats = widget.ref.read(categoriesProvider).valueOrNull ??
              const <CategoryModel>[];
          final alreadyExists = liveCats
              .any((c) => c.nameKey.toLowerCase() == name.toLowerCase());
          if (alreadyExists) {
            setState(() => _saving = false);
            _errorSnack('A category named "$name" already exists.');
            return;
          }
          // Category creation + request approval commit as a single atomic
          // WriteBatch — see CategoryRequestsNotifier.approveInFirestore.
          // Either both writes land or neither does. A thrown failure here
          // is caught by the outer catch below — the request stays Pending
          // and no category exists, so the notification is never reached.
          await widget.ref
              .read(categoryRequestsProvider.notifier)
              .approveInFirestore(req.id, newCategory: newCat);
          // From here on the commit is the source of truth: the category
          // exists and the request is Approved no matter what happens next.
          // Same wording the old inline Approve flow already sent, now in
          // its own try/catch so a notification failure is logged and
          // surfaced as a non-destructive warning instead of being reported
          // as an approval failure, and never rolls back the writes above.
          try {
            await createCategoryRequestNotification(
              userId: req.requestedByUserId,
              title: 'Category Request Approved',
              message: 'Your request for "${req.categoryName}" was approved.',
              categoryRequestId: req.id,
            );
          } catch (e) {
            notificationFailed = true;
            debugPrint('Category request approval notification failed: $e');
          }
        } else {
          await widget.ref
              .read(adminCategoriesProvider.notifier)
              .addCategory(newCat);
        }
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(notificationFailed
                ? 'Category approved, but the notification could not be sent.'
                : (_isEdit
                    ? 'Category updated successfully'
                    : 'Category added successfully')),
            backgroundColor: AppAdmin.dark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))));
      }
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      _errorSnack('Error: $e');
    }
  }
}

// ─── Neo Action Button (used in category dialogs) ────────────────────────────
class _CatNeoButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool isDanger;
  const _CatNeoButton(
      {required this.label,
      this.icon,
      required this.onTap,
      this.isDanger = false});
  @override
  State<_CatNeoButton> createState() => _CatNeoButtonState();
}

class _CatNeoButtonState extends State<_CatNeoButton>
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
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              colors: widget.isDanger
                  ? [const Color(0xFFEF4444), const Color(0xFF991B1B)]
                  : [AppAdmin.inkDarkest, AppAdmin.dark],
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
                        offset: const Offset(0, 4)),
                    BoxShadow(
                        color: Colors.black.withOpacity(0.20),
                        blurRadius: 8,
                        offset: const Offset(0, 7)),
                    BoxShadow(
                        color: Colors.white.withOpacity(0.08),
                        blurRadius: 3,
                        offset: const Offset(0, -2)),
                  ],
          ),
          child: Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, color: Colors.white, size: 17),
              const SizedBox(width: 7),
            ],
            Text(widget.label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3)),
          ])),
        ),
      ),
    );
  }
}

// ─── Category Requests Dialog ─────────────────────────────────────────────────
class _CategoryRequestsDialog extends ConsumerWidget {
  // The Admin Categories screen's own long-lived ConsumerState ref — passed
  // in so the Approve flow can hand it to _CategoryFormDialog instead of
  // this dialog's own `watchRef`, which becomes invalid once this dialog is
  // popped in the Approve onTap below (before the form's Save is even
  // pressed, let alone before its Firestore writes complete).
  final WidgetRef screenRef;
  const _CategoryRequestsDialog({required this.screenRef});

  @override
  Widget build(BuildContext context, WidgetRef watchRef) {
    final requests = watchRef.watch(categoryRequestsProvider);

    return _CategoryModalShell(
      icon: Icons.notifications_outlined,
      title: 'Category Requests',
      subtitle: '${requests.length} requests total',
      accentColor: AppAdmin.accent,
      body: requests.isEmpty
          ? const Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  Icon(Icons.notifications_none_rounded,
                      size: 56, color: AppAdmin.lightest),
                  SizedBox(height: 12),
                  Text('No category requests yet',
                      style: TextStyle(
                          color: AppAdmin.mid,
                          fontSize: 14,
                          fontWeight: FontWeight.w600))
                ]))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final req = requests[i];
                if (!req.isRead) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    watchRef
                        .read(categoryRequestsProvider.notifier)
                        .markRead(req.id);
                  });
                }

                final statusColor = req.status == CategoryRequestStatus.approved
                    ? AppColors.success
                    : req.status == CategoryRequestStatus.rejected
                        ? AppColors.error
                        : const Color(0xFFF59E0B);
                final statusLabel = req.status == CategoryRequestStatus.approved
                    ? 'Approved'
                    : req.status == CategoryRequestStatus.rejected
                        ? 'Rejected'
                        : 'Pending';
                final roleLabel = req.requestedByRole == UserRole.customer
                    ? 'Customer'
                    : req.requestedByRole == UserRole.professional
                        ? 'Professional'
                        : 'Contractor';
                final roleColor = req.requestedByRole == UserRole.customer
                    ? AppColors.primary
                    : req.requestedByRole == UserRole.professional
                        ? AppColors.success
                        : const Color(0xFF7C3AED);

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: AppAdmin.surfaceTint,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                            color: statusColor.withOpacity(0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 3)),
                        const BoxShadow(
                            color: AppAdmin.borderSoft,
                            blurRadius: 0,
                            offset: Offset(0, 4)),
                        const BoxShadow(
                            color: AppAdmin.borderSoft,
                            blurRadius: 8,
                            offset: Offset(4, 4)),
                        const BoxShadow(
                            color: Colors.white,
                            blurRadius: 8,
                            offset: Offset(-4, -4)),
                      ]),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text(req.categoryName,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: AppAdmin.darkest))),
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [
                                    statusColor,
                                    statusColor.withOpacity(0.7)
                                  ]),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                        color: statusColor.withOpacity(0.35),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2)),
                                  ]),
                              child: Text(statusLabel,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white))),
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                  color: roleColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20)),
                              child: Text(roleLabel,
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: roleColor))),
                          const SizedBox(width: 6),
                          Text(req.requestedByUserName,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppAdmin.dark,
                                  fontWeight: FontWeight.w600)),
                        ]),
                        if (req.message?.isNotEmpty == true) ...[
                          const SizedBox(height: 6),
                          Text(req.message!,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppAdmin.mid,
                                  height: 1.4),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ],
                        const SizedBox(height: 4),
                        Text(
                            '${req.createdAt.day}/${req.createdAt.month}/${req.createdAt.year}  '
                            '${req.createdAt.hour.toString().padLeft(2, '0')}:${req.createdAt.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                                fontSize: 10, color: AppAdmin.mid)),
                        if (req.status == CategoryRequestStatus.pending) ...[
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                                child: GestureDetector(
                              onTap: () async {
                                final inFlight = watchRef.read(
                                    categoryRequestActionInFlightProvider);
                                if (inFlight.contains(req.id)) return;
                                watchRef
                                    .read(categoryRequestActionInFlightProvider
                                        .notifier)
                                    .state = {...inFlight, req.id};
                                try {
                                  await watchRef
                                      .read(categoryRequestsProvider.notifier)
                                      .rejectInFirestore(req.id);
                                  createCategoryRequestNotification(
                                    userId: req.requestedByUserId,
                                    title: 'Category Request Rejected',
                                    message:
                                        'Your request for "${req.categoryName}" was rejected.',
                                    categoryRequestId: req.id,
                                  );
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                            content:
                                                const Text('Request rejected'),
                                            backgroundColor: AppColors.error,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        12))));
                                  }
                                } catch (e) {
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                            content: Text('Error: $e'),
                                            backgroundColor: AppColors.error,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        12))));
                                  }
                                } finally {
                                  final cur = watchRef.read(
                                      categoryRequestActionInFlightProvider);
                                  watchRef
                                      .read(
                                          categoryRequestActionInFlightProvider
                                              .notifier)
                                      .state = {...cur}..remove(req.id);
                                }
                              },
                              child: Container(
                                height: 42,
                                decoration: BoxDecoration(
                                    color: AppAdmin.surfaceTint,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: const Color(0xFFEF4444)
                                            .withOpacity(0.4)),
                                    boxShadow: const [
                                      BoxShadow(
                                          color: AppAdmin.borderSoft,
                                          blurRadius: 0,
                                          offset: Offset(0, 3)),
                                      BoxShadow(
                                          color: AppAdmin.borderSoft,
                                          blurRadius: 6,
                                          offset: Offset(3, 3)),
                                      BoxShadow(
                                          color: Colors.white,
                                          blurRadius: 6,
                                          offset: Offset(-3, -3)),
                                    ]),
                                child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.close_rounded,
                                          size: 14, color: Color(0xFFEF4444)),
                                      SizedBox(width: 6),
                                      Text('Reject',
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFFEF4444))),
                                    ]),
                              ),
                            )),
                            const SizedBox(width: 8),
                            Expanded(
                                child: GestureDetector(
                              // No longer creates the category or
                              // touches the request directly — opens
                              // the existing Add New Category form
                              // (prefilled from this request) so
                              // Admin can review/edit icon/name/
                              // description first. The request stays
                              // Pending until that form's own Save
                              // succeeds (see _CategoryFormDialog.
                              // _doSave) — Cancel/close/failure leaves
                              // it untouched.
                              onTap: () {
                                Navigator.pop(context);
                                showDialog(
                                  context: context,
                                  // screenRef (the Admin Categories
                                  // screen's own ref), not watchRef —
                                  // watchRef belongs to this dialog,
                                  // which is popped above and will be
                                  // fully disposed long before Save is
                                  // pressed in the form that opens.
                                  builder: (_) => _CategoryFormDialog(
                                      ref: screenRef, sourceRequest: req),
                                );
                              },
                              child: Container(
                                height: 42,
                                decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF10B981),
                                          Color(0xFF065F46)
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: const [
                                      BoxShadow(
                                          color: Color(0x5510B981),
                                          blurRadius: 8,
                                          offset: Offset(0, 4)),
                                      BoxShadow(
                                          color: Color(0xFF065F46),
                                          blurRadius: 0,
                                          offset: Offset(0, 3)),
                                    ]),
                                child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_rounded,
                                          size: 14, color: Colors.white),
                                      SizedBox(width: 6),
                                      Text('Approve',
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white)),
                                    ]),
                              ),
                            )),
                          ]),
                        ],
                      ]),
                );
              }),
      footer: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
                color: AppAdmin.surfaceTint,
                borderRadius: BorderRadius.circular(26),
                boxShadow: const [
                  BoxShadow(
                      color: AppAdmin.borderSoft,
                      blurRadius: 6,
                      offset: Offset(3, 3)),
                  BoxShadow(
                      color: Colors.white,
                      blurRadius: 6,
                      offset: Offset(-3, -3)),
                ]),
            child: const Center(
                child: Text('Close',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppAdmin.inkLight)))),
      ),
    );
  }
}

// ─── Category Details Dialog ──────────────────────────────────────────────────
class _CategoryDetailsDialog extends ConsumerWidget {
  final CategoryModel category;
  final List<UserModel> linkedUsers;
  const _CategoryDetailsDialog(
      {required this.category, required this.linkedUsers});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count =
        linkedUsers.isEmpty ? category.providerCount : linkedUsers.length;
    return _CategoryModalShell(
      iconWidget: Text(category.icon, style: const TextStyle(fontSize: 20)),
      title: category.nameKey,
      subtitle:
          (category.description != null && category.description!.isNotEmpty)
              ? category.description
              : '$count providers',
      accentColor: AppAdmin.dark,
      body: Column(children: [
        // ── Provider count chip ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: AppAdmin.surfaceTint,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                          color: AppAdmin.borderSoft,
                          blurRadius: 0,
                          offset: Offset(0, 2)),
                      BoxShadow(
                          color: AppAdmin.borderSoft,
                          blurRadius: 5,
                          offset: Offset(2, 2)),
                      BoxShadow(
                          color: Colors.white,
                          blurRadius: 5,
                          offset: Offset(-2, -2)),
                    ]),
                child: Text('$count providers',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppAdmin.inkMid))),
          ),
        ),

        // Body — providers list
        Expanded(
          child: linkedUsers.isEmpty
              ? Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                                color: AppAdmin.lightest,
                                borderRadius: BorderRadius.circular(16)),
                            child: const Icon(Icons.people_outline,
                                size: 28, color: AppAdmin.dark)),
                        const SizedBox(height: 12),
                        const Text('No providers in this category',
                            style: TextStyle(
                                color: AppAdmin.dark,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                            'Approximate count: ${category.providerCount} providers',
                            style: const TextStyle(
                                color: AppAdmin.mid, fontSize: 11)),
                      ]),
                )
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                    child: Row(children: [
                      Container(
                          width: 4,
                          height: 16,
                          decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [AppAdmin.darkest, AppAdmin.accent],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter),
                              borderRadius: BorderRadius.circular(4))),
                      const SizedBox(width: 8),
                      Text('Providers (${linkedUsers.length})',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppAdmin.darkest)),
                    ]),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: linkedUsers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final u = linkedUsers[i];
                        final roleLabel = u.role == UserRole.contractor
                            ? 'Contractor'
                            : 'Professional';
                        final roleColor = u.role == UserRole.contractor
                            ? const Color(0xFF7C3AED)
                            : AppColors.success;
                        return Container(
                          decoration: BoxDecoration(
                              color: AppAdmin.surfaceTint,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(
                                    color: AppAdmin.borderSoft,
                                    blurRadius: 0,
                                    offset: Offset(0, 3)),
                                BoxShadow(
                                    color: AppAdmin.borderSoft,
                                    blurRadius: 6,
                                    offset: Offset(3, 3)),
                                BoxShadow(
                                    color: Colors.white,
                                    blurRadius: 6,
                                    offset: Offset(-3, -3)),
                              ]),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  // Close Category Details, then switch
                                  // to the existing Admin Users tab
                                  // through the normal Admin nav-index
                                  // shell (keeps the bottom nav bar
                                  // visible) and hand it this user's id
                                  // so it opens showAdminUserDetails.
                                  Navigator.of(context).pop();
                                  ref
                                      .read(adminPendingUserDetailsIdProvider
                                          .notifier)
                                      .state = u.id;
                                  ref
                                      .read(adminNavIndexProvider.notifier)
                                      .state = 1;
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                          color: roleColor.withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      child: ProfileAvatarImage(
                                        imageUrl: u.avatar,
                                        size: 42,
                                        borderRadius: 12,
                                        fallbackText: u.fullName.isNotEmpty
                                            ? u.fullName
                                            : '?',
                                        fallbackTextStyle: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: roleColor),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(children: [
                                              Expanded(
                                                  child: Text(u.fullName,
                                                      style: const TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: AppAdmin
                                                              .darkest))),
                                              Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 7,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                      color: roleColor
                                                          .withOpacity(0.1),
                                                      borderRadius: BorderRadius
                                                          .circular(20)),
                                                  child: Text(roleLabel,
                                                      style: TextStyle(
                                                          fontSize: 9,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: roleColor))),
                                            ]),
                                            const SizedBox(height: 4),
                                            Row(children: [
                                              const Icon(Icons.phone_outlined,
                                                  size: 11,
                                                  color: AppAdmin.dark),
                                              const SizedBox(width: 4),
                                              Text(u.phone,
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      color: AppAdmin.dark)),
                                              const SizedBox(width: 10),
                                              const Icon(
                                                  Icons.location_on_outlined,
                                                  size: 11,
                                                  color: AppAdmin.dark),
                                              const SizedBox(width: 4),
                                              Text(u.city,
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      color: AppAdmin.dark)),
                                            ]),
                                            if (u.email.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Row(children: [
                                                const Icon(Icons.email_outlined,
                                                    size: 11,
                                                    color: AppAdmin.mid),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                    child: Text(u.email,
                                                        style: const TextStyle(
                                                            fontSize: 10,
                                                            color:
                                                                AppAdmin.mid),
                                                        overflow: TextOverflow
                                                            .ellipsis)),
                                              ]),
                                            ],
                                          ]),
                                    ),
                                  ]),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ]),
        ),
      ]),
      footer: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
                color: AppAdmin.surfaceTint,
                borderRadius: BorderRadius.circular(26),
                boxShadow: const [
                  BoxShadow(
                      color: AppAdmin.borderSoft,
                      blurRadius: 6,
                      offset: Offset(3, 3)),
                  BoxShadow(
                      color: Colors.white,
                      blurRadius: 6,
                      offset: Offset(-3, -3)),
                ]),
            child: const Center(
                child: Text('Close',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppAdmin.inkLight)))),
      ),
    );
  }
}

// ─── PROFILE SCREEN ───────────────────────────────────────────────────────────
// Color constants - exact match with customer neo-3D theme
const _adminBg = AppAdmin.surfaceTint;
const _adminShadowDark = AppAdmin.borderSoft;
const _adminShadowLight = Colors.white;

class AdminProfileScreen extends ConsumerStatefulWidget {
  const AdminProfileScreen({super.key});
  @override
  ConsumerState<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends ConsumerState<AdminProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final users = ref.watch(adminUsersProvider);
    final orders = ref.watch(ordersProvider);
    final complaints = ref.watch(adminComplaintsProvider);
    final broadcasts = ref.watch(broadcastProvider);

    final openComplaints =
        complaints.where((c) => c.status == ComplaintStatus.open).length;
    final pendingOrders =
        orders.where((o) => o.status == OrderStatus.pending).length;
    final completedOrders =
        orders.where((o) => o.status == OrderStatus.completed).length;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : _adminBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _AdminProfileHeader(
              // The former three-dots menu's Logout callback, unchanged
              // except for the leading Navigator.pop(ctx) that used to close
              // the menu dialog — there is no dialog to close now, and
              // keeping it would have popped this screen instead.
              onLogout: () {
                ref.read(authProvider.notifier).logout();
                Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (r) => false);
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Stats Row ──────────────────────────────────────────────
                  _AdminNeo3DStatsRow(
                    totalOrders: orders.length,
                    completedOrders: completedOrders,
                    inProgressOrders: pendingOrders,
                  ),
                  const SizedBox(height: 24),

                  // ── Send Broadcast ─────────────────────────────────────────
                  const _AdminSectionLabel(label: 'Broadcast'),
                  const SizedBox(height: 10),
                  _AdminNeo3DCard(
                    child: _AdminNeo3DActionTile(
                      icon: Icons.campaign_rounded,
                      iconColors: const [AppAdmin.accent, AppAdmin.darkest],
                      label: 'Send Broadcast Message',
                      subtitle: broadcasts.isEmpty
                          ? 'Notify all users or a specific group'
                          : '${broadcasts.length} message(s) sent so far',
                      onTap: () => showDialog(
                        context: context,
                        builder: (_) => _BroadcastDialog(ref: ref),
                      ),
                    ),
                  ),

                  // ── Recent Broadcasts ──────────────────────────────────────
                  if (broadcasts.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const _AdminSectionLabel(label: 'Recent Broadcasts'),
                    const SizedBox(height: 10),
                    _AdminNeo3DCard(
                      child: Column(
                        children: [
                          ...broadcasts
                              .take(3)
                              .map((b) => _BroadcastHistoryTile(msg: b)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // ── Quick Actions ──────────────────────────────────────────
                  const _AdminSectionLabel(label: 'Quick Actions'),
                  const SizedBox(height: 10),
                  _AdminNeo3DCard(
                    child: Column(children: [
                      _AdminNeo3DActionTile(
                        icon: Icons.people_rounded,
                        iconColors: [AppAdmin.accent, AppAdmin.darkest],
                        label: 'Manage Users',
                        onTap: () =>
                            ref.read(adminNavIndexProvider.notifier).state = 1,
                      ),
                      const _AdminNeo3DDivider(),
                      _AdminNeo3DActionTile(
                        icon: Icons.receipt_long_rounded,
                        iconColors: [AppAdmin.dark, AppAdmin.darkest],
                        label: 'Manage Orders',
                        onTap: () =>
                            ref.read(adminNavIndexProvider.notifier).state = 2,
                      ),
                      const _AdminNeo3DDivider(),
                      _AdminNeo3DActionTile(
                        icon: Icons.category_rounded,
                        iconColors: [
                          const Color(0xFF10B981),
                          const Color(0xFF065F46)
                        ],
                        label: 'Manage Categories',
                        onTap: () =>
                            ref.read(adminNavIndexProvider.notifier).state = 3,
                      ),
                      const _AdminNeo3DDivider(),
                      _AdminNeo3DActionTile(
                        icon: Icons.shield_rounded,
                        iconColors: [
                          const Color(0xFFEF4444),
                          const Color(0xFF991B1B)
                        ],
                        label: 'Manage Complaints',
                        onTap: () =>
                            ref.read(adminNavIndexProvider.notifier).state = 4,
                      ),
                      const _AdminNeo3DDivider(),
                      _AdminNeo3DActionTile(
                        icon: Icons.chat_rounded,
                        iconColors: [
                          const Color(0xFF0077B6),
                          const Color(0xFF023E8A)
                        ],
                        label: 'Manage Chats',
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AdminChatScreen())),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // ── Logout ─────────────────────────────────────────────────
                  _AdminNeo3DCard(
                    child: _AdminNeo3DActionTile(
                      icon: Icons.logout_rounded,
                      iconColors: [
                        const Color(0xFFEF4444),
                        const Color(0xFF991B1B)
                      ],
                      label: 'Logout',
                      isDestructive: true,
                      onTap: () {
                        ref.read(authProvider.notifier).logout();
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                          (r) => false,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditAdminSheet(BuildContext context, {required String field}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _EditAdminSheet(field: field),
      ),
    );
  }
}

// ─── Edit Admin Sheet (Email / Password) ─────────────────────────────────────
class _EditAdminSheet extends StatefulWidget {
  final String field; // 'email' or 'password'
  const _EditAdminSheet({required this.field});
  @override
  State<_EditAdminSheet> createState() => _EditAdminSheetState();
}

class _EditAdminSheetState extends State<_EditAdminSheet> {
  final _formKey = GlobalKey<FormState>();
  final _ctrl = TextEditingController();
  final _ctrl2 = TextEditingController(); // confirm password
  bool _obscure = true;
  bool _obscure2 = true;

  bool get _isEmail => widget.field == 'email';

  @override
  void dispose() {
    _ctrl.dispose();
    _ctrl2.dispose();
    super.dispose();
  }

  InputDecoration _dec(String hint, IconData icon,
          {bool obscure = false, VoidCallback? onToggle}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppAdmin.inkLight, fontSize: 13),
        filled: true,
        fillColor: _adminBg,
        prefixIcon: Container(
          margin: const EdgeInsets.all(10),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isEmail
                  ? [const Color(0xFF0EA5E9), const Color(0xFF0369A1)]
                  : [AppAdmin.mid, AppAdmin.darkest],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: (_isEmail ? const Color(0xFF0EA5E9) : AppAdmin.mid)
                    .withOpacity(0.35),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        suffixIcon: onToggle != null
            ? IconButton(
                icon: Icon(
                    obscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: AppAdmin.inkLight,
                    size: 18),
                onPressed: onToggle,
              )
            : null,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _adminShadowDark, width: 1)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _adminShadowDark, width: 1)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppAdmin.accent, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2)),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _adminBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _adminShadowDark,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Header row
            Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isEmail
                        ? [const Color(0xFF0EA5E9), const Color(0xFF0369A1)]
                        : [AppAdmin.mid, AppAdmin.darkest],
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: (_isEmail ? const Color(0xFF0EA5E9) : AppAdmin.mid)
                          .withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  _isEmail ? Icons.email_rounded : Icons.lock_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _isEmail ? 'Change Email' : 'Change Password',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppAdmin.inkDarkest),
                ),
                Text(
                  _isEmail
                      ? 'Update admin email address'
                      : 'Update admin password',
                  style:
                      const TextStyle(fontSize: 12, color: AppAdmin.inkLight),
                ),
              ]),
            ]),
            const SizedBox(height: 24),
            // Info box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppAdmin.lightest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppAdmin.mid.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppAdmin.dark, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _isEmail
                        ? "Can't find the service category you need?\nSend us a request and the admin will review it."
                        : 'Password must be at least 8 characters.\nUse a mix of letters, numbers & symbols.',
                    style: const TextStyle(
                        fontSize: 12, color: AppAdmin.dark, height: 1.5),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            // Form
            Form(
              key: _formKey,
              child: Column(children: [
                if (_isEmail) ...[
                  Container(
                    decoration: const BoxDecoration(
                      color: _adminBg,
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      boxShadow: [
                        BoxShadow(
                            color: _adminShadowDark,
                            blurRadius: 0,
                            offset: Offset(0, 4)),
                        BoxShadow(
                            color: _adminShadowDark,
                            blurRadius: 8,
                            offset: Offset(4, 4)),
                        BoxShadow(
                            color: _adminShadowLight,
                            blurRadius: 8,
                            offset: Offset(-3, -3)),
                      ],
                    ),
                    child: TextFormField(
                      controller: _ctrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration:
                          _dec('New email address', Icons.email_rounded),
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppAdmin.inkDarkest),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'Email is required';
                        if (!v.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                  ),
                ] else ...[
                  Container(
                    decoration: const BoxDecoration(
                      color: _adminBg,
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      boxShadow: [
                        BoxShadow(
                            color: _adminShadowDark,
                            blurRadius: 0,
                            offset: Offset(0, 4)),
                        BoxShadow(
                            color: _adminShadowDark,
                            blurRadius: 8,
                            offset: Offset(4, 4)),
                        BoxShadow(
                            color: _adminShadowLight,
                            blurRadius: 8,
                            offset: Offset(-3, -3)),
                      ],
                    ),
                    child: TextFormField(
                      controller: _ctrl,
                      obscureText: _obscure,
                      decoration: _dec('New password', Icons.lock_rounded,
                          obscure: _obscure,
                          onToggle: () => setState(() => _obscure = !_obscure)),
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppAdmin.inkDarkest),
                      validator: (v) {
                        if (v == null || v.isEmpty)
                          return 'Password is required';
                        if (v.length < 8) return 'At least 8 characters';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: const BoxDecoration(
                      color: _adminBg,
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      boxShadow: [
                        BoxShadow(
                            color: _adminShadowDark,
                            blurRadius: 0,
                            offset: Offset(0, 4)),
                        BoxShadow(
                            color: _adminShadowDark,
                            blurRadius: 8,
                            offset: Offset(4, 4)),
                        BoxShadow(
                            color: _adminShadowLight,
                            blurRadius: 8,
                            offset: Offset(-3, -3)),
                      ],
                    ),
                    child: TextFormField(
                      controller: _ctrl2,
                      obscureText: _obscure2,
                      decoration: _dec(
                          'Confirm new password', Icons.lock_outline_rounded,
                          obscure: _obscure2,
                          onToggle: () =>
                              setState(() => _obscure2 = !_obscure2)),
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppAdmin.inkDarkest),
                      validator: (v) {
                        if (v != _ctrl.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 24),
            // Buttons
            Row(children: [
              Expanded(
                child: _AdminNeo3DButton(
                  label: 'Cancel',
                  isOutlined: true,
                  onTap: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _AdminNeo3DButton(
                  label: _isEmail ? 'Update Email' : 'Update Password',
                  onTap: () {
                    if (_formKey.currentState!.validate()) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Row(children: [
                          const Icon(Icons.check_circle_rounded,
                              color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Text(_isEmail
                              ? 'Email updated successfully'
                              : 'Password updated successfully'),
                        ]),
                        backgroundColor: AppAdmin.dark,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ));
                    }
                  },
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ─── Admin Profile Header ─────────────────────────────────────────────────────
class _AdminProfileHeader extends StatelessWidget {
  final VoidCallback onLogout;
  const _AdminProfileHeader({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppAdmin.inkDarkest, AppAdmin.darkest, AppAdmin.dark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Account',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5)),
              // Permanent Logout button — replaces the former three-dots
              // trigger and its floating action stack. Same rounded 38×38
              // container and white-on-purple treatment the trigger used, so
              // it still sits in the Admin header's gradient identity; only
              // the glyph and the tap destination changed.
              Semantics(
                button: true,
                label: 'Logout',
                child: GestureDetector(
                  onTap: onLogout,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.22), width: 1),
                    ),
                    child: const Icon(Icons.logout_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 24),
            Row(children: [
              Stack(children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppAdmin.accent, AppAdmin.dark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                          color: AppAdmin.accent.withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Stack(children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(22),
                              topRight: Radius.circular(22)),
                          gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withOpacity(0.2),
                                Colors.transparent
                              ]),
                        ),
                      ),
                    ),
                    const Center(
                      child: Icon(Icons.admin_panel_settings_rounded,
                          color: Colors.white, size: 38),
                    ),
                  ]),
                ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppAdmin.darkest, width: 2),
                    ),
                    child: const Icon(Icons.verified_rounded,
                        color: Colors.white, size: 14),
                  ),
                ),
              ]),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('System Admin',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('admin@san3a.com',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFFD97706), Color(0xFFF59E0B)]),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                                color: const Color(0xFFF59E0B).withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 3))
                          ],
                        ),
                        child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shield_rounded,
                                  color: Colors.white, size: 12),
                              SizedBox(width: 4),
                              Text('Super Admin',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800)),
                            ]),
                      ),
                    ]),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ─── Admin Stats Row ──────────────────────────────────────────────────────────
class _AdminNeo3DStatsRow extends StatelessWidget {
  final int totalOrders;
  final int completedOrders;
  final int inProgressOrders;
  const _AdminNeo3DStatsRow({
    required this.totalOrders,
    required this.completedOrders,
    required this.inProgressOrders,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      child: Row(children: [
        _AdminNeo3DStatCard(
          icon: Icons.receipt_long_rounded,
          value: '$totalOrders',
          label: 'Orders',
          colors: [AppAdmin.dark, AppAdmin.darkest],
        ),
        const SizedBox(width: 10),
        _AdminNeo3DStatCard(
          icon: Icons.check_circle_rounded,
          value: '$completedOrders',
          label: 'Completed',
          colors: [const Color(0xFF10B981), const Color(0xFF065F46)],
        ),
        const SizedBox(width: 10),
        _AdminNeo3DStatCard(
          icon: Icons.sync_rounded,
          value: '$inProgressOrders',
          label: 'Pending',
          colors: [const Color(0xFF0EA5E9), const Color(0xFF0369A1)],
        ),
      ]),
    );
  }
}

class _AdminNeo3DStatCard extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final List<Color> colors;
  const _AdminNeo3DStatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: const BoxDecoration(
          color: _adminBg,
          borderRadius: BorderRadius.all(Radius.circular(20)),
          boxShadow: [
            BoxShadow(
                color: _adminShadowDark, blurRadius: 0, offset: Offset(0, 5)),
            BoxShadow(
                color: _adminShadowDark, blurRadius: 12, offset: Offset(5, 5)),
            BoxShadow(
                color: _adminShadowLight,
                blurRadius: 12,
                offset: Offset(-5, -5)),
          ],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: colors[0].withOpacity(0.45),
                    blurRadius: 10,
                    offset: const Offset(0, 5)),
                BoxShadow(
                    color: colors[1].withOpacity(0.9),
                    blurRadius: 0,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: Stack(children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 21,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(14),
                        topRight: Radius.circular(14)),
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.22),
                          Colors.transparent
                        ]),
                  ),
                ),
              ),
              Center(child: Icon(icon, color: Colors.white, size: 20)),
            ]),
          ),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                foreground: Paint()
                  ..shader = LinearGradient(colors: colors)
                      .createShader(const Rect.fromLTWH(0, 0, 80, 30)),
              )),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: AppAdmin.inkMid,
                  fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

// ─── Neo-3D Card ──────────────────────────────────────────────────────────────
class _AdminNeo3DCard extends StatelessWidget {
  final Widget child;
  const _AdminNeo3DCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: _adminBg,
          borderRadius: BorderRadius.all(Radius.circular(24)),
          boxShadow: [
            BoxShadow(
                color: _adminShadowDark, blurRadius: 0, offset: Offset(0, 6)),
            BoxShadow(
                color: _adminShadowDark, blurRadius: 16, offset: Offset(6, 6)),
            BoxShadow(
                color: _adminShadowLight,
                blurRadius: 16,
                offset: Offset(-6, -6)),
          ],
        ),
        child: child,
      );
}

// ─── Neo-3D Info Row (read-only) ──────────────────────────────────────────────
class _AdminNeo3DInfoRow extends StatelessWidget {
  final IconData icon;
  final List<Color> iconColors;
  final String label, value;
  final VoidCallback? onTap;
  const _AdminNeo3DInfoRow({
    required this.icon,
    required this.iconColors,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c2 = iconColors[1];
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: iconColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                    color: iconColors[0].withOpacity(0.45),
                    blurRadius: 8,
                    offset: const Offset(0, 4)),
                BoxShadow(
                    color: c2.withOpacity(0.9),
                    blurRadius: 0,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: Stack(children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 20,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(13),
                        topRight: Radius.circular(13)),
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.2),
                          Colors.transparent
                        ]),
                  ),
                ),
              ),
              Center(child: Icon(icon, color: Colors.white, size: 18)),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppAdmin.inkLight,
                      letterSpacing: 0.5)),
              const SizedBox(height: 3),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppAdmin.inkDarkest),
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: _adminBg,
              borderRadius: BorderRadius.all(Radius.circular(10)),
              boxShadow: [
                BoxShadow(
                    color: _adminShadowDark,
                    blurRadius: 0,
                    offset: Offset(0, 3)),
                BoxShadow(
                    color: _adminShadowDark,
                    blurRadius: 5,
                    offset: Offset(3, 3)),
                BoxShadow(
                    color: _adminShadowLight,
                    blurRadius: 5,
                    offset: Offset(-3, -3)),
              ],
            ),
            child: const Icon(Icons.arrow_forward_ios_rounded,
                size: 12, color: AppAdmin.inkMid),
          ),
        ]),
      ),
    );
  }
}

// ─── Neo-3D Action Tile (with press animation) ────────────────────────────────
class _AdminNeo3DActionTile extends StatefulWidget {
  final IconData icon;
  final List<Color> iconColors;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isDestructive;
  const _AdminNeo3DActionTile({
    required this.icon,
    required this.iconColors,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.isDestructive = false,
  });
  @override
  State<_AdminNeo3DActionTile> createState() => _AdminNeo3DActionTileState();
}

class _AdminNeo3DActionTileState extends State<_AdminNeo3DActionTile>
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
    final c2 = widget.iconColors[1];
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
            Transform.scale(scale: 1.0 - 0.03 * _ctrl.value, child: child),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: widget.iconColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(13),
                boxShadow: [
                  BoxShadow(
                      color: widget.iconColors[0].withOpacity(0.45),
                      blurRadius: 8,
                      offset: const Offset(0, 4)),
                  BoxShadow(
                      color: c2.withOpacity(0.9),
                      blurRadius: 0,
                      offset: const Offset(0, 3)),
                ],
              ),
              child: Stack(children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(13),
                          topRight: Radius.circular(13)),
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withOpacity(0.2),
                            Colors.transparent
                          ]),
                    ),
                  ),
                ),
                Center(child: Icon(widget.icon, color: Colors.white, size: 18)),
              ]),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.label,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: widget.isDestructive
                                ? const Color(0xFFEF4444)
                                : AppAdmin.inkDarkest)),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(widget.subtitle!,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppAdmin.inkLight,
                              fontWeight: FontWeight.w500)),
                    ],
                  ]),
            ),
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: _adminBg,
                borderRadius: BorderRadius.all(Radius.circular(10)),
                boxShadow: [
                  BoxShadow(
                      color: _adminShadowDark,
                      blurRadius: 0,
                      offset: Offset(0, 3)),
                  BoxShadow(
                      color: _adminShadowDark,
                      blurRadius: 5,
                      offset: Offset(3, 3)),
                  BoxShadow(
                      color: _adminShadowLight,
                      blurRadius: 5,
                      offset: Offset(-3, -3)),
                ],
              ),
              child: Icon(Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: widget.isDestructive
                      ? const Color(0xFFEF4444)
                      : AppAdmin.inkMid),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Neo-3D Divider ───────────────────────────────────────────────────────────
class _AdminNeo3DDivider extends StatelessWidget {
  const _AdminNeo3DDivider();
  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: const EdgeInsets.only(left: 70, right: 16),
        color: _adminShadowDark.withOpacity(0.5),
      );
}

// ─── Section Label ────────────────────────────────────────────────────────────
class _AdminSectionLabel extends StatelessWidget {
  final String label;
  const _AdminSectionLabel({required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppAdmin.accent, AppAdmin.darkest],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                  color: AppAdmin.accent.withOpacity(0.5),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(label.toUpperCase(),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppAdmin.inkDark,
                letterSpacing: 1.5)),
      ]);
}

// ─── Account Settings Page ────────────────────────────────────────────────────
class _AdminAccountSettingsPage extends StatefulWidget {
  const _AdminAccountSettingsPage();
  @override
  State<_AdminAccountSettingsPage> createState() =>
      _AdminAccountSettingsPageState();
}

class _AdminAccountSettingsPageState extends State<_AdminAccountSettingsPage> {
  final _emailFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String hint, IconData icon, List<Color> gradColors,
          {bool obscure = false, VoidCallback? onToggle}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppAdmin.inkLight, fontSize: 13),
        filled: true,
        fillColor: _adminBg,
        prefixIcon: Container(
          margin: const EdgeInsets.all(10),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradColors),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                  color: gradColors[0].withOpacity(0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        suffixIcon: onToggle != null
            ? IconButton(
                icon: Icon(
                    obscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: AppAdmin.inkLight,
                    size: 18),
                onPressed: onToggle,
              )
            : null,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _adminShadowDark, width: 1)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _adminShadowDark, width: 1)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppAdmin.accent, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2)),
      );

  Widget _fieldWithShadow({required Widget child}) => Container(
        decoration: const BoxDecoration(
          color: _adminBg,
          borderRadius: BorderRadius.all(Radius.circular(16)),
          boxShadow: [
            BoxShadow(
                color: _adminShadowDark, blurRadius: 0, offset: Offset(0, 4)),
            BoxShadow(
                color: _adminShadowDark, blurRadius: 8, offset: Offset(4, 4)),
            BoxShadow(
                color: _adminShadowLight,
                blurRadius: 8,
                offset: Offset(-3, -3)),
          ],
        ),
        child: child,
      );

  void _saveEmail() {
    if (!_emailFormKey.currentState!.validate()) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(children: [
        Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
        SizedBox(width: 8),
        Text('Email updated successfully'),
      ]),
      backgroundColor: AppAdmin.dark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _savePassword() {
    if (!_passwordFormKey.currentState!.validate()) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(children: [
        Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
        SizedBox(width: 8),
        Text('Password updated successfully'),
      ]),
      backgroundColor: AppAdmin.dark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _adminBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Header ──
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppAdmin.inkDarkest,
                    AppAdmin.darkest,
                    AppAdmin.dark
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back_ios_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text('Account Settings',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5)),
                    ),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [AppAdmin.accent, AppAdmin.dark]),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: AppAdmin.accent.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: const Icon(Icons.manage_accounts_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ]),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ══ CHANGE EMAIL ══════════════════════════════════════════
                  const _AdminSectionLabel(label: 'Change Email'),
                  const SizedBox(height: 10),
                  _AdminNeo3DCard(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header row
                            Row(children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [
                                    Color(0xFF0EA5E9),
                                    Color(0xFF0369A1)
                                  ]),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                        color: const Color(0xFF0EA5E9)
                                            .withOpacity(0.4),
                                        blurRadius: 10,
                                        offset: const Offset(0, 5))
                                  ],
                                ),
                                child: const Icon(Icons.email_rounded,
                                    color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Change Email',
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: AppAdmin.inkDarkest)),
                                    Text('Update admin email address',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: AppAdmin.inkLight)),
                                  ]),
                            ]),
                            const SizedBox(height: 14),
                            // Info box
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppAdmin.lightest,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppAdmin.mid.withOpacity(0.3)),
                              ),
                              child: const Row(children: [
                                Icon(Icons.info_outline_rounded,
                                    color: AppAdmin.dark, size: 15),
                                SizedBox(width: 8),
                                Expanded(
                                    child: Text(
                                  "Can't find the service category you need?\nSend us a request and the admin will review it.",
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppAdmin.dark,
                                      height: 1.5),
                                )),
                              ]),
                            ),
                            const SizedBox(height: 16),
                            // Field
                            Form(
                              key: _emailFormKey,
                              child: _fieldWithShadow(
                                child: TextFormField(
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: _dec('New email address',
                                      Icons.email_rounded, [
                                    const Color(0xFF0EA5E9),
                                    const Color(0xFF0369A1)
                                  ]),
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppAdmin.inkDarkest),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty)
                                      return 'Email is required';
                                    if (!v.contains('@'))
                                      return 'Enter a valid email';
                                    return null;
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Buttons
                            Row(children: [
                              Expanded(
                                  child: _AdminNeo3DButton(
                                      label: 'Cancel',
                                      isOutlined: true,
                                      onTap: () => Navigator.pop(context))),
                              const SizedBox(width: 12),
                              Expanded(
                                  flex: 2,
                                  child: _AdminNeo3DButton(
                                      label: 'Update Email',
                                      onTap: _saveEmail)),
                            ]),
                          ]),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ══ CHANGE PASSWORD ═══════════════════════════════════════
                  const _AdminSectionLabel(label: 'Change Password'),
                  const SizedBox(height: 10),
                  _AdminNeo3DCard(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header row
                            Row(children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                      colors: [AppAdmin.mid, AppAdmin.darkest]),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                        color: AppAdmin.mid.withOpacity(0.4),
                                        blurRadius: 10,
                                        offset: const Offset(0, 5))
                                  ],
                                ),
                                child: const Icon(Icons.lock_rounded,
                                    color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Change Password',
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: AppAdmin.inkDarkest)),
                                    Text('Update admin password',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: AppAdmin.inkLight)),
                                  ]),
                            ]),
                            const SizedBox(height: 14),
                            // Info box
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppAdmin.lightest,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppAdmin.mid.withOpacity(0.3)),
                              ),
                              child: const Row(children: [
                                Icon(Icons.info_outline_rounded,
                                    color: AppAdmin.dark, size: 15),
                                SizedBox(width: 8),
                                Expanded(
                                    child: Text(
                                  'Password must be at least 8 characters.\nUse a mix of letters, numbers & symbols.',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppAdmin.dark,
                                      height: 1.5),
                                )),
                              ]),
                            ),
                            const SizedBox(height: 16),
                            // Fields
                            Form(
                              key: _passwordFormKey,
                              child: Column(children: [
                                _fieldWithShadow(
                                  child: TextFormField(
                                    controller: _newPassCtrl,
                                    obscureText: _obscureNew,
                                    decoration: _dec(
                                        'New password',
                                        Icons.lock_rounded,
                                        [AppAdmin.mid, AppAdmin.darkest],
                                        obscure: _obscureNew,
                                        onToggle: () => setState(
                                            () => _obscureNew = !_obscureNew)),
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppAdmin.inkDarkest),
                                    validator: (v) {
                                      if (v == null || v.isEmpty)
                                        return 'Password is required';
                                      if (v.length < 8)
                                        return 'At least 8 characters';
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _fieldWithShadow(
                                  child: TextFormField(
                                    controller: _confirmPassCtrl,
                                    obscureText: _obscureConfirm,
                                    decoration: _dec(
                                        'Confirm new password',
                                        Icons.lock_outline_rounded,
                                        [AppAdmin.mid, AppAdmin.darkest],
                                        obscure: _obscureConfirm,
                                        onToggle: () => setState(() =>
                                            _obscureConfirm =
                                                !_obscureConfirm)),
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppAdmin.inkDarkest),
                                    validator: (v) {
                                      if (v != _newPassCtrl.text)
                                        return 'Passwords do not match';
                                      return null;
                                    },
                                  ),
                                ),
                              ]),
                            ),
                            const SizedBox(height: 16),
                            // Buttons
                            Row(children: [
                              Expanded(
                                  child: _AdminNeo3DButton(
                                      label: 'Cancel',
                                      isOutlined: true,
                                      onTap: () => Navigator.pop(context))),
                              const SizedBox(width: 12),
                              Expanded(
                                  flex: 2,
                                  child: _AdminNeo3DButton(
                                      label: 'Update Password',
                                      onTap: _savePassword)),
                            ]),
                          ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Admin Neo-3D Button ──────────────────────────────────────────────────────
class _AdminNeo3DButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isOutlined;
  const _AdminNeo3DButton(
      {required this.label, required this.onTap, this.isOutlined = false});
  @override
  State<_AdminNeo3DButton> createState() => _AdminNeo3DButtonState();
}

class _AdminNeo3DButtonState extends State<_AdminNeo3DButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 90));
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
        builder: (_, child) => Transform.translate(
          offset: Offset(0, _ctrl.value * 3),
          child: child,
        ),
        child: Container(
          height: 50,
          decoration: widget.isOutlined
              ? BoxDecoration(
                  color: _adminBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _adminShadowDark, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                        color: _adminShadowDark,
                        blurRadius: 0,
                        offset: Offset(0, 4)),
                    BoxShadow(
                        color: _adminShadowDark,
                        blurRadius: 8,
                        offset: Offset(4, 4)),
                    BoxShadow(
                        color: _adminShadowLight,
                        blurRadius: 8,
                        offset: Offset(-3, -3)),
                  ],
                )
              : BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppAdmin.accent, AppAdmin.darkest],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: AppAdmin.accent.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 5)),
                    BoxShadow(
                        color: AppAdmin.darkest.withOpacity(0.8),
                        blurRadius: 0,
                        offset: const Offset(0, 4)),
                  ],
                ),
          child: Center(
            child: Text(widget.label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color:
                        widget.isOutlined ? AppAdmin.inkDark : Colors.white)),
          ),
        ),
      ),
    );
  }
}

// ─── Broadcast Feature Card ───────────────────────────────────────────────────
class _BroadcastCard extends StatefulWidget {
  final int sentCount;
  final VoidCallback onTap;
  const _BroadcastCard({required this.sentCount, required this.onTap});
  @override
  State<_BroadcastCard> createState() => _BroadcastCardState();
}

class _BroadcastCardState extends State<_BroadcastCard>
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
        builder: (_, child) => Transform.translate(
            offset: Offset(0, _ctrl.value * 3), child: child),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: _adminBg,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                  color: _adminShadowDark, blurRadius: 0, offset: Offset(0, 6)),
              BoxShadow(
                  color: _adminShadowDark,
                  blurRadius: 16,
                  offset: Offset(6, 6)),
              BoxShadow(
                  color: _adminShadowLight,
                  blurRadius: 16,
                  offset: Offset(-6, -6)),
            ],
          ),
          child: Column(children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
              child: Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppAdmin.accent, AppAdmin.darkest],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: AppAdmin.accent.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 5)),
                      BoxShadow(
                          color: AppAdmin.darkest.withOpacity(0.9),
                          blurRadius: 0,
                          offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Stack(children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 23,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(14),
                              topRight: Radius.circular(14)),
                          gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withOpacity(0.2),
                                Colors.transparent
                              ]),
                        ),
                      ),
                    ),
                    const Center(
                        child: Icon(Icons.campaign_rounded,
                            color: Colors.white, size: 22)),
                  ]),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text('Send Broadcast Message',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppAdmin.inkDarkest)),
                ),
                Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: _adminBg,
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    boxShadow: [
                      BoxShadow(
                          color: _adminShadowDark,
                          blurRadius: 0,
                          offset: Offset(0, 3)),
                      BoxShadow(
                          color: _adminShadowDark,
                          blurRadius: 5,
                          offset: Offset(3, 3)),
                      BoxShadow(
                          color: _adminShadowLight,
                          blurRadius: 5,
                          offset: Offset(-3, -3)),
                    ],
                  ),
                  child: const Icon(Icons.arrow_forward_ios_rounded,
                      size: 12, color: AppAdmin.inkMid),
                ),
              ]),
            ),
            // ── Info box ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppAdmin.lightest,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppAdmin.mid.withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppAdmin.dark, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.sentCount == 0
                          ? "Can't find the right audience?\nSend a notification to all users or a specific group."
                          : "${widget.sentCount} message(s) sent so far.\nSend a new broadcast to your users.",
                      style: const TextStyle(
                          fontSize: 12, color: AppAdmin.dark, height: 1.5),
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Broadcast History Tile ───────────────────────────────────────────────────
class _BroadcastHistoryTile extends StatelessWidget {
  final BroadcastMessage msg;
  const _BroadcastHistoryTile({required this.msg});

  static const Map<BroadcastTarget, String> _targetLabels = {
    BroadcastTarget.all: 'All',
    BroadcastTarget.customers: 'Customers',
    BroadcastTarget.professionals: 'Professionals',
    BroadcastTarget.contractors: 'Contractors',
  };

  // A broadcast can now have several audiences — listed in the enum's own
  // order so the badge reads the same way every time.
  String get _targetsLabel {
    final labels = BroadcastTarget.values
        .where(msg.targets.contains)
        .map((t) => _targetLabels[t]!)
        .toList();
    return labels.isEmpty
        ? _targetLabels[BroadcastTarget.all]!
        : labels.join(' + ');
  }

  @override
  Widget build(BuildContext context) {
    final d = msg.createdAt;
    final timeStr =
        '${d.day}/${d.month}/${d.year}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppAdmin.accent, AppAdmin.darkest],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(
                  color: AppAdmin.accent.withOpacity(0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: const Icon(Icons.campaign_outlined,
              size: 17, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(msg.text,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppAdmin.inkDarkest),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              // Flexible + ellipsis: a combined label like
              // "Customers + Professionals" is much wider than the old
              // single-word one and must not push the row into an overflow
              // on narrow screens.
              Flexible(
                child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: AppAdmin.lightest,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(_targetsLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppAdmin.dark))),
              ),
            ]),
            const SizedBox(height: 4),
            Text(timeStr,
                style: const TextStyle(fontSize: 11, color: AppAdmin.inkLight)),
          ]),
        ),
      ]),
    );
  }
}

// ─── Broadcast Dialog (Request a New Category style) ─────────────────────────
class _BroadcastDialog extends StatefulWidget {
  final WidgetRef ref;
  const _BroadcastDialog({required this.ref});
  @override
  State<_BroadcastDialog> createState() => _BroadcastDialogState();
}

class _BroadcastDialogState extends State<_BroadcastDialog> {
  final _formKey = GlobalKey<FormState>();
  final _msgCtrl = TextEditingController();

  // Multi-select. "All Users" is exclusive with the individual groups (it
  // already means everyone), and picking all three individual groups is the
  // same thing — normalizeBroadcastTargets in admin_providers.dart owns both
  // rules so the UI and the send path can never disagree.
  Set<BroadcastTarget> _targets = {BroadcastTarget.all};

  // Only shown after a Send Now with nothing selected, so the dialog doesn't
  // open in an error state.
  bool _showAudienceError = false;

  static const Map<BroadcastTarget, _TargetOption> _options = {
    BroadcastTarget.all: _TargetOption(
        icon: Icons.groups_rounded,
        label: 'All Users',
        sub: 'Customers + Professionals + Contractors'),
    BroadcastTarget.customers: _TargetOption(
        icon: Icons.person_rounded,
        label: 'Customers',
        sub: 'Service requesters'),
    BroadcastTarget.professionals: _TargetOption(
        icon: Icons.engineering_rounded,
        label: 'Professionals',
        sub: 'Service providers'),
    BroadcastTarget.contractors: _TargetOption(
        icon: Icons.construction_rounded,
        label: 'Contractors',
        sub: 'Construction companies & contractors'),
  };

  void _toggleTarget(BroadcastTarget t) {
    setState(() {
      _showAudienceError = false;
      if (t == BroadcastTarget.all) {
        // Tapping All Users selects everyone and drops any individual picks;
        // tapping it again clears the selection entirely.
        _targets = _targets.contains(BroadcastTarget.all)
            ? <BroadcastTarget>{}
            : {BroadcastTarget.all};
        return;
      }
      // Any individual pick switches out of All Users first.
      final next = _targets.where((x) => x != BroadcastTarget.all).toSet();
      if (!next.remove(t)) next.add(t);
      _targets = normalizeBroadcastTargets(next);
    });
  }

  bool _isSelected(BroadcastTarget t) =>
      _targets.contains(t) ||
      // With All Users active every individual group is implicitly included,
      // so they read as selected too.
      (t != BroadcastTarget.all && _targets.contains(BroadcastTarget.all));

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    if (_targets.isEmpty) {
      setState(() => _showAudienceError = true);
      return;
    }
    final admin = widget.ref.read(authProvider);
    final text = _msgCtrl.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final roles = broadcastTargetsToRoleStrings(_targets);
    try {
      await sendBroadcastNotificationsInFirestore(
        message: text,
        targetRoles: roles,
        createdById: admin?.id,
        createdByName: admin?.fullName,
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: const Text('Failed to send broadcast. Please try again.'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    // Local history is recorded only once the Firestore write succeeded, so
    // "Recent Broadcasts" can't show a message that was never delivered.
    widget.ref
        .read(broadcastProvider.notifier)
        .send(text, _targets, senderName: admin?.fullName ?? 'System Admin');
    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(SnackBar(
      content: const Row(children: [
        Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
        SizedBox(width: 10),
        Expanded(child: Text('Message sent successfully')),
      ]),
      backgroundColor: AppAdmin.dark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: const BoxDecoration(
          color: _adminBg,
          borderRadius: BorderRadius.all(Radius.circular(28)),
          boxShadow: [
            BoxShadow(
                color: _adminShadowDark, blurRadius: 0, offset: Offset(0, 8)),
            BoxShadow(
                color: _adminShadowDark, blurRadius: 24, offset: Offset(8, 8)),
            BoxShadow(
                color: _adminShadowLight,
                blurRadius: 24,
                offset: Offset(-8, -8)),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ── Top drag handle ──
          const SizedBox(height: 12),
          Center(
              child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: _adminShadowDark,
                borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 16),

          // ── Header ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [AppAdmin.accent, AppAdmin.darkest],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: AppAdmin.accent.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 5)),
                    BoxShadow(
                        color: AppAdmin.darkest.withOpacity(0.9),
                        blurRadius: 0,
                        offset: const Offset(0, 3)),
                  ],
                ),
                child: const Icon(Icons.campaign_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text('Send Broadcast Message',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppAdmin.inkDarkest)),
              ),
            ]),
          ),
          const SizedBox(height: 14),

          // ── Info box ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppAdmin.lightest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppAdmin.mid.withOpacity(0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline_rounded,
                    color: AppAdmin.dark, size: 16),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Can't find the right audience?\nSend a notification to all users or a specific group.",
                    style: TextStyle(
                        fontSize: 12, color: AppAdmin.dark, height: 1.5),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 20),

          // ── Body ──
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Target label
                      const _AdminSectionLabel(label: 'Target Audience'),
                      const SizedBox(height: 4),
                      const Text(
                          'Pick one or more groups — or All Users for everyone.',
                          style: TextStyle(
                              fontSize: 11, color: AppAdmin.inkLight)),
                      const SizedBox(height: 12),

                      // Target options — multi-select
                      ...BroadcastTarget.values.map((t) {
                        final opt = _options[t]!;
                        final selected = _isSelected(t);
                        final c2 =
                            Color.lerp(AppAdmin.accent, Colors.black, 0.35)!;
                        return GestureDetector(
                          onTap: () => _toggleTarget(t),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 11),
                            decoration: BoxDecoration(
                              color: _adminBg,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                          color:
                                              AppAdmin.accent.withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4)),
                                      BoxShadow(
                                          color: c2.withOpacity(0.8),
                                          blurRadius: 0,
                                          offset: const Offset(0, 3)),
                                    ]
                                  : const [
                                      BoxShadow(
                                          color: _adminShadowDark,
                                          blurRadius: 0,
                                          offset: Offset(0, 3)),
                                      BoxShadow(
                                          color: _adminShadowDark,
                                          blurRadius: 6,
                                          offset: Offset(3, 3)),
                                      BoxShadow(
                                          color: _adminShadowLight,
                                          blurRadius: 6,
                                          offset: Offset(-3, -3)),
                                    ],
                              border: selected
                                  ? Border.all(
                                      color: AppAdmin.accent, width: 1.5)
                                  : null,
                            ),
                            child: Row(children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  gradient: selected
                                      ? const LinearGradient(colors: [
                                          AppAdmin.accent,
                                          AppAdmin.darkest
                                        ])
                                      : null,
                                  color: selected ? null : AppAdmin.lightest,
                                  borderRadius: BorderRadius.circular(11),
                                  boxShadow: selected
                                      ? [
                                          BoxShadow(
                                              color: AppAdmin.accent
                                                  .withOpacity(0.4),
                                              blurRadius: 6,
                                              offset: const Offset(0, 3)),
                                        ]
                                      : null,
                                ),
                                child: Icon(opt.icon,
                                    size: 18,
                                    color: selected
                                        ? Colors.white
                                        : AppAdmin.dark),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(opt.label,
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: selected
                                                ? AppAdmin.darkest
                                                : AppAdmin.inkDarkest)),
                                    Text(opt.sub,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppAdmin.inkLight)),
                                  ])),
                              if (selected)
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                      color: AppAdmin.accent,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.check_rounded,
                                      size: 12, color: Colors.white),
                                ),
                            ]),
                          ),
                        );
                      }),

                      if (_showAudienceError) ...[
                        const SizedBox(height: 2),
                        Row(children: [
                          const Icon(Icons.error_outline_rounded,
                              size: 14, color: AppColors.error),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text('Select at least one target audience.',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.error)),
                          ),
                        ]),
                      ],

                      const SizedBox(height: 16),
                      const _AdminSectionLabel(label: 'Message Text'),
                      const SizedBox(height: 12),

                      // Message field
                      Container(
                        decoration: const BoxDecoration(
                          color: _adminBg,
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                          boxShadow: [
                            BoxShadow(
                                color: _adminShadowDark,
                                blurRadius: 0,
                                offset: Offset(0, 4)),
                            BoxShadow(
                                color: _adminShadowDark,
                                blurRadius: 8,
                                offset: Offset(4, 4)),
                            BoxShadow(
                                color: _adminShadowLight,
                                blurRadius: 8,
                                offset: Offset(-3, -3)),
                          ],
                        ),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(14),
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [
                                      AppAdmin.dark,
                                      AppAdmin.darkest
                                    ]),
                                    borderRadius: BorderRadius.circular(11),
                                    boxShadow: [
                                      BoxShadow(
                                          color:
                                              AppAdmin.dark.withOpacity(0.35),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3))
                                    ],
                                  ),
                                  child: const Icon(Icons.campaign_rounded,
                                      color: Colors.white, size: 17),
                                ),
                              ),
                              Expanded(
                                child: TextFormField(
                                  controller: _msgCtrl,
                                  maxLines: 4,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppAdmin.inkDarkest),
                                  decoration: const InputDecoration(
                                    hintText:
                                        'Write your broadcast message here...',
                                    hintStyle: TextStyle(
                                        color: AppAdmin.inkLight, fontSize: 13),
                                    border: InputBorder.none,
                                    contentPadding:
                                        EdgeInsets.fromLTRB(0, 14, 14, 14),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty)
                                      return 'Message cannot be empty';
                                    if (v.trim().length < 5)
                                      return 'Too short (min 5 chars)';
                                    return null;
                                  },
                                ),
                              ),
                            ]),
                      ),
                      const SizedBox(height: 8),
                    ]),
              ),
            ),
          ),

          // ── Footer ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Row(children: [
              Expanded(
                child: _AdminNeo3DButton(
                  label: 'Cancel',
                  isOutlined: true,
                  onTap: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _AdminNeo3DButton(
                  label: 'Send Now',
                  onTap: _send,
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// Simple data holder for target options
class _TargetOption {
  final IconData icon;
  final String label;
  final String sub;
  const _TargetOption(
      {required this.icon, required this.label, required this.sub});
}

// ─── USERS SCREEN ─────────────────────────────────────────────────────────────
// (exported from admin_users_screen.dart - no changes needed to logic, only style)
