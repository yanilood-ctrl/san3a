// admin_complaints_screen.dart
// Drop this file into:
//   lib/features/admin/presentation/screens/admin_complaints_screen.dart
// and make sure admin_complaints_screen.dart is imported wherever AdminComplaintsScreen is used.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/admin_providers.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/shared_widgets.dart' show ProfileAvatarImage;
import '../../../../features/auth/presentation/providers/app_providers.dart';
import 'admin_users_screen.dart' show showAdminUserDetails;
import 'admin_review_management_screen.dart' show AdminReviewManagementScreen;

// ══════════════════════════════════════════════════════════════════════════════
//  CONSTANTS & MAPS
// ══════════════════════════════════════════════════════════════════════════════

const Map<ComplaintPriority, String> _priorityLabels = {
  ComplaintPriority.urgent: 'Urgent',
  ComplaintPriority.high: 'High',
  ComplaintPriority.medium: 'Medium',
  ComplaintPriority.low: 'Low',
};
const Map<ComplaintPriority, Color> _priorityColors = {
  ComplaintPriority.urgent: Color(0xFF991B1B),
  ComplaintPriority.high: Color(0xFFDC2626),
  ComplaintPriority.medium: Color(0xFFF59E0B),
  ComplaintPriority.low: Color(0xFF059669),
};
const Map<ComplaintPriority, IconData> _priorityIcons = {
  ComplaintPriority.urgent: Icons.priority_high_rounded,
  ComplaintPriority.high: Icons.keyboard_double_arrow_up_rounded,
  ComplaintPriority.medium: Icons.remove_rounded,
  ComplaintPriority.low: Icons.keyboard_double_arrow_down_rounded,
};
const Map<ComplaintStatus, String> _statusLabels = {
  ComplaintStatus.open: 'Open',
  ComplaintStatus.inReview: 'In Review',
  ComplaintStatus.resolved: 'Resolved',
  ComplaintStatus.rejected: 'Rejected',
  ComplaintStatus.deleted: 'Deleted',
};
const Map<ComplaintStatus, Color> _statusColors = {
  ComplaintStatus.open: Color(0xFFDC2626),
  ComplaintStatus.inReview: Color(0xFF0EA5E9),
  ComplaintStatus.resolved: Color(0xFF059669),
  ComplaintStatus.rejected: Color(0xFFDC2626),
  ComplaintStatus.deleted: Color(0xFF6B7280),
};
const Map<ComplaintStatus, IconData> _statusIcons = {
  ComplaintStatus.open: Icons.error_outline_rounded,
  ComplaintStatus.inReview: Icons.rate_review_outlined,
  ComplaintStatus.resolved: Icons.check_circle_outline_rounded,
  ComplaintStatus.rejected: Icons.cancel_outlined,
  ComplaintStatus.deleted: Icons.delete_outline_rounded,
};
const Map<ComplaintStatus, Color> _statusBg = {
  ComplaintStatus.open: Color(0xFFFFF0F0),
  ComplaintStatus.inReview: Color(0xFFE0F2FE),
  ComplaintStatus.resolved: Color(0xFFF0FDF4),
  ComplaintStatus.rejected: Color(0xFFFEE2E2),
  ComplaintStatus.deleted: Color(0xFFF3F4F6),
};

// ── Party role metadata (Complaint Summary "Parties Involved" cards) ─────────
// Same label/color values as admin_users_screen.dart's private
// _roleLabels/_roleColors (kept as a small local copy here rather than
// exporting from that screen, so it stays untouched) — used so a party
// card's role label/icon/tint always matches the color an Admin already
// associates with that role elsewhere in the app.
const Map<UserRole, String> _partyRoleLabels = {
  UserRole.customer: 'Customer',
  UserRole.professional: 'Professional',
  UserRole.contractor: 'Contractor',
  UserRole.admin: 'Admin',
};
const Map<UserRole, Color> _partyRoleColors = {
  UserRole.customer: AppColors.primary,
  UserRole.professional: AppColors.success,
  UserRole.contractor: Color(0xFF7C3AED),
  UserRole.admin: AppAdmin.dark,
};
const Map<UserRole, IconData> _partyRoleIcons = {
  UserRole.customer: Icons.person_rounded,
  UserRole.professional: Icons.engineering_rounded,
  UserRole.contractor: Icons.engineering_rounded,
  UserRole.admin: Icons.admin_panel_settings_rounded,
};

/// Parses a stored role string ('customer'/'professional'/'contractor'/
/// 'admin', as written to ComplaintModel.complainantRole/targetUserRole) —
/// returns null for anything else rather than guessing.
UserRole? _parsePartyRole(String? raw) {
  switch (raw?.trim().toLowerCase()) {
    case 'customer':
      return UserRole.customer;
    case 'professional':
      return UserRole.professional;
    case 'contractor':
      return UserRole.contractor;
    case 'admin':
      return UserRole.admin;
    default:
      return null;
  }
}

// ── Extended Complaint Categories (for UI display) ────────────────────────────
enum _CxType { userReport, orderProblem, reviewReport, chatReport, systemBug }

const _cxTypeLabels = {
  _CxType.userReport: 'User Report',
  _CxType.orderProblem: 'Order Problem',
  _CxType.reviewReport: 'Review Report',
  _CxType.chatReport: 'Chat Report',
  _CxType.systemBug: 'System Bug',
};
const _cxTypeIcons = {
  _CxType.userReport: Icons.person_off_outlined,
  _CxType.orderProblem: Icons.receipt_long_outlined,
  _CxType.reviewReport: Icons.star_border_rounded,
  _CxType.chatReport: Icons.chat_bubble_outline_rounded,
  _CxType.systemBug: Icons.bug_report_outlined,
};
const _cxTypeColors = {
  _CxType.userReport: AppAdmin.accent,
  _CxType.orderProblem: Color(0xFFF97316),
  _CxType.reviewReport: Color(0xFFF59E0B),
  _CxType.chatReport: Color(0xFF0077B6),
  _CxType.systemBug: Color(0xFFDC2626),
};

_CxType _toCxType(ComplaintType t) {
  switch (t) {
    case ComplaintType.provider:
      return _CxType.userReport;
    case ComplaintType.customer:
      return _CxType.userReport;
    case ComplaintType.order:
      return _CxType.orderProblem;
    case ComplaintType.category:
      return _CxType.reviewReport;
    case ComplaintType.reviewReport:
      return _CxType.reviewReport;
    case ComplaintType.general:
      return _CxType.systemBug;
  }
}

const Map<ComplaintType, String> _typeLabels = {
  ComplaintType.order: 'Order Problem',
  ComplaintType.provider: 'User Report',
  ComplaintType.customer: 'Customer Report',
  ComplaintType.category: 'Review Report',
  ComplaintType.reviewReport: 'Review Report',
  ComplaintType.general: 'System Bug',
};

// ══════════════════════════════════════════════════════════════════════════════
//  SMART ACTIONS per complaint type
// ══════════════════════════════════════════════════════════════════════════════

class _SmartAction {
  final String label;
  final IconData icon;
  final Color color;
  final String subtitle;
  final void Function(BuildContext, ComplaintModel, WidgetRef) onTap;
  const _SmartAction(
      this.label, this.icon, this.color, this.subtitle, this.onTap);
}

List<_SmartAction> _actionsFor(ComplaintType type) {
  switch (type) {
    case ComplaintType.provider:
      return [
        _SmartAction(
            'View User Profile',
            Icons.person_outlined,
            AppAdmin.dark,
            'Open user details page',
            (ctx, c, ref) => _openUserProfile(ctx, c, ref)),
        _SmartAction(
            'Warn User',
            Icons.warning_amber_rounded,
            const Color(0xFFF59E0B),
            'Send warning to user',
            (ctx, c, ref) => _warnUserDialog(ctx, c, ref)),
        _SmartAction(
            'Suspend Account',
            Icons.pause_circle_outline_rounded,
            const Color(0xFFEA580C),
            'Temporarily suspend the account',
            (ctx, c, ref) => _suspendAccountDialog(ctx, c, ref)),
        _SmartAction(
            'Block User',
            Icons.block_rounded,
            const Color(0xFFDC2626),
            'Permanently block this user',
            (ctx, c, ref) => _blockUserFromComplaint(ctx, c, ref)),
        _SmartAction(
            'Resolve',
            Icons.check_circle_outline_rounded,
            const Color(0xFF059669),
            'Mark complaint as resolved ✓',
            (ctx, c, ref) => _resolveAction(ctx, ref, c)),
      ];
    case ComplaintType.customer:
      return [
        _SmartAction(
            'View User Profile',
            Icons.person_outlined,
            AppAdmin.dark,
            'Open user details page',
            (ctx, c, ref) => _openUserProfile(ctx, c, ref)),
        _SmartAction(
            'Warn User',
            Icons.warning_amber_rounded,
            const Color(0xFFF59E0B),
            'Send warning to user',
            (ctx, c, ref) => _warnUserDialog(ctx, c, ref)),
        _SmartAction(
            'Resolve',
            Icons.check_circle_outline_rounded,
            const Color(0xFF059669),
            'Mark complaint as resolved ✓',
            (ctx, c, ref) => _resolveAction(ctx, ref, c)),
      ];
    case ComplaintType.order:
      return [
        _SmartAction(
            'View Order Details',
            Icons.receipt_long_outlined,
            AppAdmin.dark,
            'Open the related order',
            (ctx, c, ref) => _openOrderDetails(ctx, c, ref)),
        _SmartAction(
            'Reassign Professional / Contractor',
            Icons.swap_horiz_rounded,
            AppAdmin.accent,
            'Assign to another professional or contractor',
            (ctx, c, ref) => _reassignOrder(ctx, c, ref)),
        _SmartAction(
            'Cancel Order',
            Icons.cancel_outlined,
            const Color(0xFFDC2626),
            'Cancel this order',
            (ctx, c, ref) => _cancelOrder(ctx, c, ref)),
        _SmartAction(
            'Resolve',
            Icons.check_circle_outline_rounded,
            const Color(0xFF059669),
            'Mark complaint as resolved ✓',
            (ctx, c, ref) => _resolveAction(ctx, ref, c)),
      ];
    case ComplaintType.category:
    case ComplaintType.reviewReport:
      return [
        _SmartAction(
            'View Review',
            Icons.rate_review_outlined,
            AppAdmin.dark,
            'See the reported review',
            (ctx, c, ref) => _openReviewDetails(ctx, c, ref)),
        _SmartAction(
            'Delete Review',
            Icons.delete_outline_rounded,
            const Color(0xFFDC2626),
            'Remove the reported review',
            (ctx, c, ref) => _deleteReview(ctx, c, ref)),
        _SmartAction(
            'Edit Review',
            Icons.edit_outlined,
            AppAdmin.accent,
            'Modify the reported review',
            (ctx, c, ref) => _editReview(ctx, c, ref)),
        _SmartAction(
            'Warn User',
            Icons.warning_amber_rounded,
            const Color(0xFFF59E0B),
            'Send warning to user who wrote it',
            (ctx, c, ref) => _doAction(
                ctx, ref, c, 'User has been warned', const Color(0xFFF59E0B))),
        _SmartAction(
            'Keep Review',
            Icons.thumb_up_outlined,
            const Color(0xFF059669),
            'Keep the review as is',
            (ctx, c, ref) => _doAction(
                ctx, ref, c, 'Review kept as is', const Color(0xFF059669))),
        _SmartAction(
            'Resolve',
            Icons.check_circle_outline_rounded,
            const Color(0xFF059669),
            'Mark complaint as resolved ✓',
            (ctx, c, ref) => _resolveAction(ctx, ref, c)),
      ];
    case ComplaintType.general:
      return [
        _SmartAction(
            'View System Details',
            Icons.bug_report_outlined,
            AppAdmin.accent,
            'See technical details',
            (ctx, c, ref) => _openSystemDetails(ctx, c, ref)),
        _SmartAction(
            'Send to Dev Team',
            Icons.code_rounded,
            AppAdmin.accent,
            'Forward to development team',
            (ctx, c, ref) => _doAction(
                ctx, ref, c, 'Sent to development team', AppAdmin.accent)),
        _SmartAction(
            'Mark Known Issue',
            Icons.info_outline_rounded,
            AppAdmin.dark,
            'Mark as a known issue',
            (ctx, c, ref) =>
                _doAction(ctx, ref, c, 'Marked as known issue', AppAdmin.dark)),
        _SmartAction(
            'Assign Developer',
            Icons.person_add_outlined,
            const Color(0xFFF59E0B),
            'Assign a developer to this',
            (ctx, c, ref) => _doAction(
                ctx, ref, c, 'Developer assigned', const Color(0xFFF59E0B))),
        _SmartAction(
            'Resolve',
            Icons.check_circle_outline_rounded,
            const Color(0xFF059669),
            'Mark complaint as resolved ✓',
            (ctx, c, ref) => _resolveAction(ctx, ref, c)),
      ];
  }
}

// ── Action Handlers ────────────────────────────────────────────────────────────

void _doAction(BuildContext ctx, WidgetRef ref, ComplaintModel c, String msg,
    Color color) {
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: color,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ));
}

void _resolveAction(BuildContext ctx, WidgetRef ref, ComplaintModel c) {
  setComplaintStatusInFirestore(c, ComplaintStatus.resolved);
  _doAction(ctx, ref, c, 'Complaint resolved successfully ✓',
      const Color(0xFF059669));
}

// ── User profile ───────────────────────────────────────────────────────────────
void _openUserProfile(BuildContext ctx, ComplaintModel c, WidgetRef ref) {
  final users = ref.read(adminUsersProvider);
  final user = c.targetId != null
      ? users.firstWhere((u) => u.id == c.targetId,
          orElse: () => users.firstWhere(
              (u) => u.fullName
                  .toLowerCase()
                  .contains((c.targetName ?? '').toLowerCase()),
              orElse: () => users.first))
      : null;
  if (user == null) {
    _doAction(ctx, ref, c, 'User not found', Colors.grey);
    return;
  }
  showAdminUserDetails(ctx, user, ref);
}

void _blockUserFromComplaint(
    BuildContext ctx, ComplaintModel c, WidgetRef ref) {
  final name = c.targetName ?? 'this user';
  showDialog(
    context: ctx,
    builder: (d) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Block $name?',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      content: Text('This will permanently block $name from the platform.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          onPressed: () {
            Navigator.pop(d);
            _doAction(ctx, ref, c, '$name has been blocked from the platform',
                const Color(0xFFDC2626));
          },
          child: const Text('Block User',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

// ── Warn User Dialog ───────────────────────────────────────────────────────────
void _warnUserDialog(BuildContext ctx, ComplaintModel c, WidgetRef ref) {
  final nameCtrl = TextEditingController(
      text:
          'Your behavior regarding "${c.reason}" has been flagged. Please follow platform guidelines or your account may be suspended.');
  final name = c.targetName ?? 'this user';

  showDialog(
    context: ctx,
    builder: (d) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFF59E0B), size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
            child: Text('Warn $name',
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                overflow: TextOverflow.ellipsis)),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text(
            'This warning will be visible to the user in their notifications.',
            style: TextStyle(fontSize: 12, color: AppAdmin.mid)),
        const SizedBox(height: 12),
        TextField(
          controller: nameCtrl,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Warning message...',
            filled: true,
            fillColor: const Color(0xFFF9F9F9),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200)),
          ),
          style: const TextStyle(fontSize: 13),
        ),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          onPressed: () {
            final msg = nameCtrl.text.trim();
            if (msg.isEmpty) return;
            Navigator.pop(d);
            // Find user and add warning
            if (c.targetId != null) {
              ref.read(adminUsersProvider.notifier).warnUser(c.targetId!, msg);
            }
            _doAction(ctx, ref, c, '⚠ Warning sent to $name',
                const Color(0xFFF59E0B));
          },
          child: const Text('Send Warning',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

// ── Suspend Account Dialog ─────────────────────────────────────────────────────
void _suspendAccountDialog(BuildContext ctx, ComplaintModel c, WidgetRef ref) {
  final name = c.targetName ?? 'this user';
  int _selectedDays = 3; // default

  showDialog(
    context: ctx,
    builder: (d) => StatefulBuilder(
      builder: (ctx2, setDlgState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFEA580C).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.pause_circle_outline_rounded,
                color: Color(0xFFEA580C), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text('Suspend $name',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15),
                  overflow: TextOverflow.ellipsis)),
        ]),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select suspension duration:',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppAdmin.darkest)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [1, 3, 7, 14, 30].map((days) {
                  final sel = _selectedDays == days;
                  return GestureDetector(
                    onTap: () => setDlgState(() => _selectedDays = days),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel
                            ? const Color(0xFFEA580C)
                            : const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel
                              ? const Color(0xFFEA580C)
                              : const Color(0xFFEA580C).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        days == 1
                            ? '1 Day'
                            : days == 30
                                ? '1 Month'
                                : '$days Days',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : const Color(0xFFEA580C),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEA580C).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: Color(0xFFEA580C)),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(
                    'Account will be suspended until ${_formatSuspendDate(_selectedDays)}',
                    style:
                        const TextStyle(fontSize: 11, color: Color(0xFFEA580C)),
                  )),
                ]),
              ),
            ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              Navigator.pop(d);
              final until = DateTime.now().add(Duration(days: _selectedDays));
              if (c.targetId != null) {
                ref
                    .read(adminUsersProvider.notifier)
                    .suspendUser(c.targetId!, until);
              }
              _doAction(
                  ctx,
                  ref,
                  c,
                  '⏸ $name suspended for $_selectedDays day${_selectedDays > 1 ? 's' : ''}',
                  const Color(0xFFEA580C));
            },
            child: const Text('Suspend',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ),
  );
}

String _formatSuspendDate(int days) {
  final d = DateTime.now().add(Duration(days: days));
  return '${d.day}/${d.month}/${d.year}';
}

// ── Order details ──────────────────────────────────────────────────────────────
// Robust lookup for a complaint's related order:
//  1) search the already-loaded live Firestore orders list (fast path), then
//  2) fall back to a direct Firestore document fetch by id.
// Real orders are stored with a custom document id (see new_order_screen.dart),
// so `orders/{orderId}` is always the correct path to try.
Future<OrderModel?> _findRelatedOrder(WidgetRef ref, String orderId) async {
  final loaded = ref.read(adminFirestoreOrdersProvider).valueOrNull;
  if (loaded != null) {
    for (final o in loaded) {
      if (o.id == orderId) return o;
    }
  }
  try {
    final doc = await FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .get();
    final data = doc.data();
    if (doc.exists && data != null) {
      return OrderModel.fromMap(data, id: doc.id);
    }
  } catch (_) {}
  return null;
}

void _openOrderDetails(
    BuildContext ctx, ComplaintModel c, WidgetRef ref) async {
  final orderId = c.relatedOrderId ?? c.targetId;
  final order = (orderId != null && orderId.isNotEmpty)
      ? await _findRelatedOrder(ref, orderId)
      : null;
  if (!ctx.mounted) return;

  showModalBottomSheet(
    context: ctx,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _OrderDetailSheet(order: order, complaint: c, ref: ref),
  );
}

void _reassignOrder(BuildContext ctx, ComplaintModel c, WidgetRef ref) {
  final orders = ref.read(ordersProvider);
  final order = c.targetId != null
      ? orders.firstWhere((o) => o.id == c.targetId,
          orElse: () => orders.isEmpty ? null as OrderModel : orders.first)
      : null;
  final providers = ref
      .read(adminUsersProvider)
      .where((u) =>
          u.role == UserRole.professional || u.role == UserRole.contractor)
      .toList();

  showModalBottomSheet(
    context: ctx,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReassignSheet(
        order: order, providers: providers, complaint: c, ref: ref),
  );
}

void _cancelOrder(BuildContext ctx, ComplaintModel c, WidgetRef ref) {
  final name = c.targetName ?? 'this order';
  showDialog(
    context: ctx,
    builder: (d) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFDC2626).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.cancel_outlined,
              color: Color(0xFFDC2626), size: 18),
        ),
        const SizedBox(width: 10),
        const Expanded(
            child: Text('Cancel Order?',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
      ]),
      content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: const Color(0xFFDC2626).withOpacity(0.2)),
              ),
              child: Text('"$name"',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFFDC2626))),
            ),
            const SizedBox(height: 10),
            Text('⚠ This action will:',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700)),
            const SizedBox(height: 6),
            _BulletRow('Permanently cancel the order'),
            _BulletRow('Notify the customer via the app'),
            _BulletRow('Remove it from the active orders list'),
            const SizedBox(height: 4),
            Text('This cannot be undone.',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic)),
          ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Back', style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          onPressed: () {
            Navigator.pop(d);
            // Persist through the same Firestore writer the Admin Orders
            // screen's Cancel action uses (cancelAdminOrderInFirestore), so
            // this really cancels the order. The previous call was
            // ordersProvider.cancelOrder(), which only mutated the in-memory
            // DummyData-seeded list — the dialog claimed the order was
            // cancelled while Firestore was never touched.
            if (c.targetId != null) {
              ref
                  .read(ordersProvider.notifier)
                  .cancelAdminOrderInFirestore(
                    orderId: c.targetId!,
                    reason: 'Admin cancelled due to complaint',
                  )
                  .catchError((_) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content:
                          Text('Failed to cancel order. Please try again.'),
                      behavior: SnackBarBehavior.floating));
                }
              });
            }
            _doAction(ctx, ref, c, 'Order "$name" has been cancelled',
                const Color(0xFFDC2626));
          },
          child: const Text('Yes, Cancel Order',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

// ── Review details ─────────────────────────────────────────────────────────────
// Robust lookup for a complaint's related review:
//  1) search the already-loaded live Firestore reviews list (fast path), then
//  2) fall back to a direct Firestore document fetch by id.
// A review's `id` is always its real Firestore document id (see
// addReviewInFirestore in app_providers.dart) — never falls back to
// mock/static review data.
Future<ReviewModel?> _findRelatedReview(WidgetRef ref, String reviewId) async {
  final loaded = ref.read(allReviewsProvider).valueOrNull;
  if (loaded != null) {
    for (final r in loaded) {
      if (r.id == reviewId) return r;
    }
  }
  try {
    final doc = await FirebaseFirestore.instance
        .collection('reviews')
        .doc(reviewId)
        .get();
    final data = doc.data();
    if (doc.exists && data != null) {
      return ReviewModel.fromFirestore(data, id: doc.id);
    }
  } catch (_) {}
  return null;
}

void _openReviewDetails(
    BuildContext ctx, ComplaintModel c, WidgetRef ref) async {
  final reviewId = c.relatedReviewId ?? c.targetId;
  final review = (reviewId != null && reviewId.isNotEmpty)
      ? await _findRelatedReview(ref, reviewId)
      : null;
  if (!ctx.mounted) return;

  showModalBottomSheet(
    context: ctx,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReviewDetailSheet(review: review, complaint: c, ref: ref),
  );
}

void _deleteReview(BuildContext ctx, ComplaintModel c, WidgetRef ref) {
  showDialog(
    context: ctx,
    builder: (d) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Delete Review?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      content: Text('This will permanently delete the reported review.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          onPressed: () async {
            Navigator.pop(d);
            final reviewId = c.relatedReviewId ?? c.targetId;
            if (reviewId != null && reviewId.isNotEmpty) {
              await deleteReviewInFirestore(reviewId);
            }
            setComplaintStatusInFirestore(c, ComplaintStatus.resolved);
            if (!ctx.mounted) return;
            _doAction(ctx, ref, c, 'Review deleted successfully',
                const Color(0xFFDC2626));
          },
          child: const Text('Delete',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

void _editReview(BuildContext ctx, ComplaintModel c, WidgetRef ref) async {
  final reviewId = c.relatedReviewId ?? c.targetId;
  final review = (reviewId != null && reviewId.isNotEmpty)
      ? await _findRelatedReview(ref, reviewId)
      : null;
  if (!ctx.mounted) return;

  showModalBottomSheet(
    context: ctx,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EditReviewSheet(review: review, complaint: c, ref: ref),
  );
}

// ── System details ─────────────────────────────────────────────────────────────
void _openSystemDetails(BuildContext ctx, ComplaintModel c, WidgetRef ref) {
  showModalBottomSheet(
    context: ctx,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SystemDetailSheet(complaint: c, ref: ref),
  );
}

// ─── Public helper to open complaint summary from other screens ──────────────
void showAdminComplaintSummary(BuildContext context, ComplaintModel complaint,
    WidgetRef ref, List<UserModel> users) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _ComplaintSummarySheet(complaint: complaint, ref: ref, users: users),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  MAIN SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class AdminComplaintsScreen extends ConsumerStatefulWidget {
  const AdminComplaintsScreen({super.key});
  @override
  ConsumerState<AdminComplaintsScreen> createState() =>
      _AdminComplaintsScreenState();
}

class _AdminComplaintsScreenState extends ConsumerState<AdminComplaintsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  String _search = '';
  ComplaintPriority? _filterPriority;
  _CxType? _filterType;
  final _searchCtrl = TextEditingController();

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

  List<ComplaintModel> _filter(List<ComplaintModel> list) {
    return list.where((c) {
      final q = _search.toLowerCase();
      final matchQ = q.isEmpty ||
          c.reason.toLowerCase().contains(q) ||
          c.description.toLowerCase().contains(q) ||
          c.userName.toLowerCase().contains(q) ||
          (c.targetName?.toLowerCase().contains(q) ?? false) ||
          (c.targetId?.toLowerCase().contains(q) ?? false) ||
          c.id.toLowerCase().contains(q);
      final matchP = _filterPriority == null || c.priority == _filterPriority;
      final matchT = _filterType == null || _toCxType(c.type) == _filterType;
      return matchQ && matchP && matchT;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(adminComplaintsProvider);
    final users = ref.watch(adminUsersProvider);
    final open =
        _filter(all.where((c) => c.status == ComplaintStatus.open).toList());
    final inReview = _filter(
        all.where((c) => c.status == ComplaintStatus.inReview).toList());
    final resolved = _filter(
        all.where((c) => c.status == ComplaintStatus.resolved).toList());
    final rejected = _filter(
        all.where((c) => c.status == ComplaintStatus.rejected).toList());

    final openCount = all.where((c) => c.status == ComplaintStatus.open).length;
    final inRevCount =
        all.where((c) => c.status == ComplaintStatus.inReview).length;
    final resolvedCount =
        all.where((c) => c.status == ComplaintStatus.resolved).length;
    final highPrio =
        all.where((c) => c.priority == ComplaintPriority.high).length;

    return Scaffold(
      backgroundColor: AppAdmin.warm,
      body: Column(children: [
        // ── Header (title / subtitle / Open count / Rejected action — the
        // status nav for Open/In Review/Resolved lives below it, as its own
        // elevated component; Rejected stays a premium standalone control
        // inside the header itself, next to the other header badges). ──
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('🛡 Complaints Center',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white)),
                            Text(
                                'Central inbox for all reports and complaints.',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.white60)),
                          ]),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (openCount > 0)
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626),
                                  borderRadius: BorderRadius.circular(20)),
                              child: Text('$openCount Open',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800))),
                        if (openCount > 0) const SizedBox(height: 8),
                        _RejectedComplaintsButton(
                          count: rejected.length,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => _FilteredComplaintsPage(
                                  title: 'Rejected Complaints',
                                  complaints: rejected,
                                  statusColor:
                                      _statusColors[ComplaintStatus.rejected]!,
                                  icon: Icons.block_rounded,
                                  ref: ref,
                                  users: users,
                                ),
                              )),
                        ),
                      ],
                    ),
                  ],
                ),
              )),
        ),

        // ── Status navigation — separate premium elevated segmented bar,
        // same visual language as the redesigned Admin Orders stepper bar.
        // Rejected is intentionally NOT here — it lives in the header. ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: _ComplaintsStepperBar(
            controller: _tab,
            openCount: open.length,
            inReviewCount: inReview.length,
            resolvedCount: resolved.length,
          ),
        ),

        // ── Search + Filter Button ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(children: [
            // Search field
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
                    onChanged: (v) => setState(() => _search = v),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppAdmin.inkDarkest),
                    decoration: InputDecoration(
                      hintText: 'Search complaints...',
                      hintStyle: TextStyle(
                          color: AppAdmin.inkLight.withOpacity(0.8),
                          fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      suffixIcon: _search.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchCtrl.clear();
                                setState(() => _search = '');
                              },
                              child: const Icon(Icons.close_rounded,
                                  size: 16, color: AppAdmin.inkLight))
                          : null,
                    ),
                  )),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            // Filter button
            _ComplaintFilterButton(
              filterType: _filterType,
              filterPriority: _filterPriority,
              onChanged: (type, priority) => setState(() {
                _filterType = type;
                _filterPriority = priority;
              }),
            ),
          ]),
        ),

        // ── Tab Content ──
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _ComplaintsList(complaints: open, ref: ref, users: users),
              _ComplaintsList(complaints: inReview, ref: ref, users: users),
              _ComplaintsList(complaints: resolved, ref: ref, users: users),
            ],
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  STATUS NAVIGATION — separate elevated segmented bar (Open / In Review /
//  Resolved only — Rejected lives in its own standalone action beside it).
//  Same neumorphic pill-tab language as the redesigned Admin Orders stepper
//  bar: purely presentational, driven by the screen's own TabController.
// ══════════════════════════════════════════════════════════════════════════════

class _ComplaintStatusTabData {
  final String label;
  final IconData icon;
  final Color activeColor;
  final Color darkColor;
  const _ComplaintStatusTabData(
      {required this.label,
      required this.icon,
      required this.activeColor,
      required this.darkColor});
}

class _ComplaintsStepperBar extends StatefulWidget {
  final TabController controller;
  final int openCount;
  final int inReviewCount;
  final int resolvedCount;
  const _ComplaintsStepperBar({
    required this.controller,
    required this.openCount,
    required this.inReviewCount,
    required this.resolvedCount,
  });
  @override
  State<_ComplaintsStepperBar> createState() => _ComplaintsStepperBarState();
}

class _ComplaintsStepperBarState extends State<_ComplaintsStepperBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideCtrl;
  int _prevIndex = 0;

  // Semantic status colors: Open = red/attention, In Review = light blue,
  // Resolved = green — same tokens as _statusColors, kept as their own
  // small local copy so this presentational bar doesn't need to import the
  // full status-color map for just three entries.
  static const _tabs = [
    _ComplaintStatusTabData(
        label: 'Open',
        icon: Icons.error_outline_rounded,
        activeColor: Color(0xFFDC2626),
        darkColor: Color(0xFF991B1B)),
    _ComplaintStatusTabData(
        label: 'In Review',
        icon: Icons.rate_review_outlined,
        activeColor: Color(0xFF0EA5E9),
        darkColor: Color(0xFF0369A1)),
    _ComplaintStatusTabData(
        label: 'Resolved',
        icon: Icons.check_circle_outline_rounded,
        activeColor: Color(0xFF059669),
        darkColor: Color(0xFF065F46)),
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
          widget.openCount,
          widget.inReviewCount,
          widget.resolvedCount,
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
                    widget.controller.animateTo(i);
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

// ══════════════════════════════════════════════════════════════════════════════
//  REJECTED — standalone premium action button that lives inside the purple
//  header (separate from the Open/In Review/Resolved nav below it). Same
//  frosted-glass header-control language as the Admin Orders header menu
//  button. Same tap destination/status filtering as before: pushes a full
//  page of complaints whose status is exactly ComplaintStatus.rejected,
//  unchanged.
// ══════════════════════════════════════════════════════════════════════════════

class _RejectedComplaintsButton extends StatefulWidget {
  final int count;
  final VoidCallback onTap;
  const _RejectedComplaintsButton({required this.count, required this.onTap});
  @override
  State<_RejectedComplaintsButton> createState() =>
      _RejectedComplaintsButtonState();
}

class _RejectedComplaintsButtonState extends State<_RejectedComplaintsButton>
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
    // A lighter red reads cleanly against the dark purple header gradient
    // (the darker 0xFFDC2626 used for the on-card status/badge red is kept
    // for the count badge itself, where it sits on a light chip instead).
    const iconRed = Color(0xFFFF6B6B);
    const badgeRed = Color(0xFFDC2626);
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.white.withOpacity(0.20),
              Colors.white.withOpacity(0.08)
            ], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.28), width: 1),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.22),
                  blurRadius: 8,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.block_rounded, color: iconRed, size: 14),
            const SizedBox(width: 6),
            const Text('Rejected',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            if (widget.count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                constraints: const BoxConstraints(minWidth: 18),
                decoration: BoxDecoration(
                  color: badgeRed,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    BoxShadow(
                        color: badgeRed.withOpacity(0.5),
                        blurRadius: 4,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: Text('${widget.count}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Rejected Complaints — full filtered page, same premium header language as
//  the redesigned Admin Orders "Completed/Cancelled" filtered pages. Status
//  filtering itself is unchanged — this only renders whatever `complaints`
//  list (already filtered to ComplaintStatus.rejected by the caller) is
//  passed in.
// ══════════════════════════════════════════════════════════════════════════════

class _FilteredComplaintsPage extends StatelessWidget {
  final String title;
  final List<ComplaintModel> complaints;
  final Color statusColor;
  final IconData icon;
  final WidgetRef ref;
  final List<UserModel> users;
  const _FilteredComplaintsPage({
    required this.title,
    required this.complaints,
    required this.statusColor,
    required this.icon,
    required this.ref,
    required this.users,
  });

  @override
  Widget build(BuildContext context) {
    final headerDeep = Color.lerp(AppAdmin.darkest, statusColor, 0.20)!;
    final headerMid = Color.lerp(AppAdmin.darkest, statusColor, 0.55)!;

    return Scaffold(
      backgroundColor: AppAdmin.warm,
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
            child: Text('${complaints.length}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900)),
          ),
        ],
      ),
      body: _ComplaintsList(complaints: complaints, ref: ref, users: users),
    );
  }
}

// ─── Complaint Filter Button (neo-3D, opens bottom sheet) ────────────────────
class _ComplaintFilterButton extends StatefulWidget {
  final _CxType? filterType;
  final ComplaintPriority? filterPriority;
  final void Function(_CxType? type, ComplaintPriority? priority) onChanged;
  const _ComplaintFilterButton(
      {required this.filterType,
      required this.filterPriority,
      required this.onChanged});
  @override
  State<_ComplaintFilterButton> createState() => _ComplaintFilterButtonState();
}

class _ComplaintFilterButtonState extends State<_ComplaintFilterButton>
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

  bool get _hasFilter =>
      widget.filterType != null || widget.filterPriority != null;

  void _open() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(
        filterType: widget.filterType,
        filterPriority: widget.filterPriority,
        onApply: widget.onChanged,
      ),
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
            Transform.scale(scale: 1.0 - 0.05 * _ctrl.value, child: child),
        child: Stack(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _hasFilter ? AppAdmin.dark : AppAdmin.surfaceTint,
              borderRadius: BorderRadius.circular(14),
              boxShadow: _hasFilter
                  ? [
                      BoxShadow(
                          color: AppAdmin.dark.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4)),
                      BoxShadow(
                          color: AppAdmin.darkest.withOpacity(0.9),
                          blurRadius: 0,
                          offset: const Offset(0, 3)),
                    ]
                  : const [
                      BoxShadow(
                          color: AppAdmin.borderSoft,
                          blurRadius: 0,
                          offset: Offset(0, 4)),
                      BoxShadow(
                          color: AppAdmin.borderSoft,
                          blurRadius: 8,
                          offset: Offset(4, 4)),
                      BoxShadow(
                          color: Colors.white,
                          blurRadius: 8,
                          offset: Offset(-3, -3)),
                    ],
            ),
            child: Icon(Icons.tune_rounded,
                color: _hasFilter ? Colors.white : AppAdmin.inkMid, size: 22),
          ),
          if (_hasFilter)
            Positioned(
                right: 2,
                top: 2,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: AppAdmin.accent,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: AppAdmin.surfaceTint, width: 1.5)),
                )),
        ]),
      ),
    );
  }
}

// ─── Filter Sheet (neo, request-category style) ───────────────────────────────
class _FilterSheet extends StatefulWidget {
  final _CxType? filterType;
  final ComplaintPriority? filterPriority;
  final void Function(_CxType? type, ComplaintPriority? priority) onApply;
  const _FilterSheet(
      {required this.filterType,
      required this.filterPriority,
      required this.onApply});
  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  _CxType? _type;
  ComplaintPriority? _priority;

  @override
  void initState() {
    super.initState();
    _type = widget.filterType;
    _priority = widget.filterPriority;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
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
            const SizedBox(height: 20),
            // Header
            Row(children: [
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
                          offset: Offset(-4, -4))
                    ]),
                child: const Icon(Icons.tune_rounded,
                    color: AppAdmin.inkMid, size: 22),
              ),
              const SizedBox(width: 14),
              const Text('Filter Complaints',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppAdmin.inkDark)),
            ]),
            const SizedBox(height: 20),
            // Info
            Container(
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
                        color: Colors.white,
                        blurRadius: 6,
                        offset: Offset(-3, -3))
                  ]),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppAdmin.inkMid, size: 16),
                const SizedBox(width: 8),
                const Expanded(
                    child: Text(
                        'Select complaint type and priority to filter results.',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppAdmin.inkMid,
                            height: 1.4))),
              ]),
            ),
            const SizedBox(height: 20),
            // Type filter
            const Text('Complaint Type',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppAdmin.inkMid)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _NeoFilterChip(
                label: 'All Types',
                icon: Icons.all_inclusive_rounded,
                selected: _type == null,
                color: AppAdmin.dark,
                onTap: () => setState(() => _type = null),
              ),
              for (final t in _CxType.values)
                _NeoFilterChip(
                  label: _cxTypeLabels[t]!,
                  icon: _cxTypeIcons[t]!,
                  selected: _type == t,
                  color: _cxTypeColors[t]!,
                  onTap: () => setState(() => _type = _type == t ? null : t),
                ),
            ]),
            const SizedBox(height: 18),
            // Priority filter
            const Text('Priority',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppAdmin.inkMid)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _NeoFilterChip(
                label: 'All',
                icon: Icons.all_inclusive_rounded,
                selected: _priority == null,
                color: AppAdmin.dark,
                onTap: () => setState(() => _priority = null),
              ),
              for (final p in ComplaintPriority.values)
                _NeoFilterChip(
                  label: _priorityLabels[p]!,
                  icon: _priorityIcons[p]!,
                  selected: _priority == p,
                  color: _priorityColors[p]!,
                  onTap: () =>
                      setState(() => _priority = _priority == p ? null : p),
                ),
            ]),
            const SizedBox(height: 24),
            // Buttons
            Row(children: [
              Expanded(
                  child: GestureDetector(
                onTap: () {
                  setState(() {
                    _type = null;
                    _priority = null;
                  });
                  widget.onApply(null, null);
                  Navigator.pop(context);
                },
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                      color: AppAdmin.surfaceTint,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: const [
                        BoxShadow(
                            color: AppAdmin.borderSoft,
                            blurRadius: 0,
                            offset: Offset(0, 4)),
                        BoxShadow(
                            color: AppAdmin.borderSoft,
                            blurRadius: 6,
                            offset: Offset(4, 4)),
                        BoxShadow(
                            color: Colors.white,
                            blurRadius: 6,
                            offset: Offset(-3, -3))
                      ]),
                  child: const Center(
                      child: Text('Clear',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppAdmin.inkMid))),
                ),
              )),
              const SizedBox(width: 12),
              Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () {
                      widget.onApply(_type, _priority);
                      Navigator.pop(context);
                    },
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        gradient: const LinearGradient(
                            colors: [AppAdmin.dark, AppAdmin.darkest],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                        boxShadow: [
                          BoxShadow(
                              color: AppAdmin.dark.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 4)),
                          BoxShadow(
                              color: AppAdmin.darkest.withOpacity(0.9),
                              blurRadius: 0,
                              offset: const Offset(0, 3)),
                        ],
                      ),
                      child: const Center(
                          child: Text('Apply Filters',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white))),
                    ),
                  )),
            ]),
          ]),
    );
  }
}

// ─── Neo Filter Chip (like the example image) ─────────────────────────────────
class _NeoFilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _NeoFilterChip(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : AppAdmin.surfaceTint,
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4)),
                  BoxShadow(
                      color: Color.lerp(color, Colors.black, 0.3)!
                          .withOpacity(0.9),
                      blurRadius: 0,
                      offset: const Offset(0, 3)),
                ]
              : const [
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
                ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: selected ? Colors.white : color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppAdmin.inkMid)),
        ]),
      ),
    );
  }
}

// ─── Stat Badge ───────────────────────────────────────────────────────────────
class _StatBadge extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatBadge(
      {required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
          child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.08))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w900, color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 9,
                  color: Colors.white60,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
      ));
}

// ─── Filter Chip (flat) ───────────────────────────────────────────────────────
class _FChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _FChip(
      {required this.label,
      required this.selected,
      required this.color,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: selected ? color : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? color : AppAdmin.lightest)),
          child: Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppAdmin.dark)),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
//  PRIORITY CHIP
// ══════════════════════════════════════════════════════════════════════════════

class _PriorityChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  const _PriorityChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? color : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: selected ? color : AppAdmin.lightest, width: 1.5),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 13, color: selected ? Colors.white : color),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : color)),
            ]),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
//  ORDER DETAIL SHEET
// ══════════════════════════════════════════════════════════════════════════════

class _OrderDetailSheet extends StatefulWidget {
  final OrderModel? order;
  final ComplaintModel complaint;
  final WidgetRef ref;
  const _OrderDetailSheet(
      {this.order, required this.complaint, required this.ref});
  @override
  State<_OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<_OrderDetailSheet> {
  OrderModel? _order;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  Color _statusColor(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
        return const Color(0xFFF59E0B);
      case OrderStatus.inProgress:
        return const Color(0xFF059669);
      case OrderStatus.completed:
        return AppAdmin.dark;
      case OrderStatus.cancelled:
        return const Color(0xFFDC2626);
    }
  }

  String _statusLabel(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.inProgress:
        return 'In Progress';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(children: [
        // Handle
        const SizedBox(height: 12),
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppAdmin.lightest,
                borderRadius: BorderRadius.circular(2))),
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(children: [
            Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppAdmin.darkest, AppAdmin.dark]),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.receipt_long_outlined,
                    color: Colors.white, size: 22)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Order Details',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppAdmin.darkest)),
                  Text(
                      'Related to: ${widget.complaint.targetName ?? "Unknown"}',
                      style:
                          const TextStyle(fontSize: 12, color: AppAdmin.mid)),
                ])),
            IconButton(
                icon: const Icon(Icons.close_rounded, color: AppAdmin.mid),
                onPressed: () => Navigator.pop(context)),
          ]),
        ),
        const Divider(height: 24),
        if (o == null)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _EmptyDetail(
                      icon: Icons.receipt_long_outlined,
                      message: 'This order may be old or no longer exists.',
                    ),
                    const SizedBox(height: 16),
                    _DlgSectionLabel('Details from complaint record'),
                    const SizedBox(height: 8),
                    _InfoCard(children: [
                      _InfoRow(
                          Icons.title_rounded,
                          'Order Title',
                          widget.complaint.relatedOrderTitle?.isNotEmpty == true
                              ? widget.complaint.relatedOrderTitle!
                              : 'N/A'),
                      _InfoRow(
                          Icons.tag_rounded,
                          'Order ID',
                          widget.complaint.relatedOrderId?.isNotEmpty == true
                              ? widget.complaint.relatedOrderId!
                              : (widget.complaint.targetId ?? 'N/A')),
                      _InfoRow(Icons.person_outlined, 'Complainant',
                          widget.complaint.userName),
                      _InfoRow(
                          Icons.person_pin_outlined,
                          'Target User',
                          widget.complaint.targetUserName?.isNotEmpty == true
                              ? widget.complaint.targetUserName!
                              : (widget.complaint.targetName ?? 'N/A')),
                      _InfoRow(Icons.report_outlined, 'Complaint Title',
                          widget.complaint.reason),
                    ]),
                    if (widget.complaint.description.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _DlgSectionLabel('Complaint Description'),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: AppAdmin.warm,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppAdmin.lightest)),
                        child: Text(widget.complaint.description,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppAdmin.darkest,
                                height: 1.5)),
                      ),
                    ],
                  ]),
            ),
          )
        else
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status badge
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: _statusColor(o.status).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color:
                                    _statusColor(o.status).withOpacity(0.3))),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.circle,
                              size: 8, color: _statusColor(o.status)),
                          const SizedBox(width: 6),
                          Text(_statusLabel(o.status),
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _statusColor(o.status))),
                        ]),
                      ),
                      const Spacer(),
                      Text('#${o.id}',
                          style: const TextStyle(
                              fontSize: 11, color: AppAdmin.mid)),
                    ]),
                    const SizedBox(height: 16),
                    // Order info card
                    _InfoCard(children: [
                      _InfoRow(Icons.title_rounded, 'Title', o.title),
                      _InfoRow(
                          Icons.person_outlined, 'Customer', o.customerName),
                      _InfoRow(Icons.engineering_outlined, 'Professional',
                          o.providerName),
                      _InfoRow(Icons.location_on_outlined, 'Area', o.area),
                      _InfoRow(Icons.build_outlined, 'Service Type',
                          o.serviceType ?? 'N/A'),
                      _InfoRow(Icons.calendar_today_outlined, 'Date',
                          '${o.serviceDate.day}/${o.serviceDate.month}/${o.serviceDate.year}'),
                    ]),
                    const SizedBox(height: 16),
                    if (o.description.isNotEmpty) ...[
                      _DlgSectionLabel('Description'),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: AppAdmin.warm,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppAdmin.lightest)),
                        child: Text(o.description,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppAdmin.darkest,
                                height: 1.5)),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Quick actions
                    _DlgSectionLabel('Quick Actions'),
                    const SizedBox(height: 10),
                    Row(children: [
                      _QuickActionBtn(
                        icon: Icons.swap_horiz_rounded,
                        label: 'Reassign',
                        color: AppAdmin.accent,
                        onTap: () {
                          Navigator.pop(context);
                          _reassignOrder(context, widget.complaint, widget.ref);
                        },
                      ),
                      const SizedBox(width: 8),
                      _QuickActionBtn(
                        icon: Icons.cancel_outlined,
                        label: 'Cancel',
                        color: const Color(0xFFDC2626),
                        onTap: () {
                          Navigator.pop(context);
                          _cancelOrder(context, widget.complaint, widget.ref);
                        },
                      ),
                    ]),
                  ]),
            ),
          ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  REASSIGN SHEET
// ══════════════════════════════════════════════════════════════════════════════

class _ReassignSheet extends StatefulWidget {
  final OrderModel? order;
  final List<UserModel> providers;
  final ComplaintModel complaint;
  final WidgetRef ref;
  const _ReassignSheet(
      {this.order,
      required this.providers,
      required this.complaint,
      required this.ref});
  @override
  State<_ReassignSheet> createState() => _ReassignSheetState();
}

class _ReassignSheetState extends State<_ReassignSheet> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(children: [
        const SizedBox(height: 12),
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppAdmin.lightest,
                borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(children: [
            Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: AppAdmin.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.swap_horiz_rounded,
                    color: AppAdmin.accent, size: 22)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Reassign Professional / Contractor',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppAdmin.darkest)),
                  Text(
                      'Order: ${widget.order?.title ?? widget.complaint.targetName ?? "Unknown"}',
                      style: const TextStyle(fontSize: 12, color: AppAdmin.mid),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ])),
            IconButton(
                icon: const Icon(Icons.close_rounded, color: AppAdmin.mid),
                onPressed: () => Navigator.pop(context)),
          ]),
        ),
        const Divider(height: 24),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text('Select new professional:',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppAdmin.darkest)),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.providers.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: Colors.grey.shade100),
            itemBuilder: (_, i) {
              final p = widget.providers[i];
              final sel = _selectedId == p.id;
              return ListTile(
                onTap: () => setState(() => _selectedId = p.id),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [AppAdmin.darkest, AppAdmin.dark]),
                      shape: BoxShape.circle),
                  child: ProfileAvatarImage(
                      imageUrl: p.avatar,
                      size: 40,
                      fallbackText: p.fullName,
                      fallbackTextStyle: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800)),
                ),
                title: Text(p.fullName,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: sel ? AppAdmin.dark : AppAdmin.darkest)),
                subtitle: Text(
                    p.role == UserRole.professional
                        ? 'Professional'
                        : 'Contractor',
                    style: const TextStyle(fontSize: 11, color: AppAdmin.mid)),
                trailing: sel
                    ? const Icon(Icons.check_circle_rounded,
                        color: AppAdmin.dark)
                    : const Icon(Icons.radio_button_unchecked,
                        color: AppAdmin.lightest),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedId == null
                  ? null
                  : () {
                      final pro = widget.providers
                          .firstWhere((p) => p.id == _selectedId);
                      Navigator.pop(context);
                      _doAction(
                          context,
                          widget.ref,
                          widget.complaint,
                          'Order reassigned to ${pro.fullName}',
                          AppAdmin.accent);
                    },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppAdmin.dark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  disabledBackgroundColor: Colors.grey.shade200,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0),
              child: const Text('Confirm Reassignment',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  REVIEW DETAIL SHEET
// ══════════════════════════════════════════════════════════════════════════════

class _ReviewDetailSheet extends StatelessWidget {
  final ReviewModel? review;
  final ComplaintModel complaint;
  final WidgetRef ref;
  const _ReviewDetailSheet(
      {this.review, required this.complaint, required this.ref});

  @override
  Widget build(BuildContext context) {
    final r = review;
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(children: [
        const SizedBox(height: 12),
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppAdmin.lightest,
                borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(children: [
            Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: AppAdmin.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.rate_review_outlined,
                    color: AppAdmin.accent, size: 22)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Reported Review',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppAdmin.darkest)),
                  Text('Filed by: ${complaint.userName}',
                      style:
                          const TextStyle(fontSize: 12, color: AppAdmin.mid)),
                ])),
            IconButton(
                icon: const Icon(Icons.close_rounded, color: AppAdmin.mid),
                onPressed: () => Navigator.pop(context)),
          ]),
        ),
        const Divider(height: 24),
        if (r == null)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _EmptyDetail(
                      icon: Icons.rate_review_outlined,
                      message: 'This review may be old or no longer exists.',
                    ),
                    const SizedBox(height: 16),
                    _DlgSectionLabel('Details from complaint record'),
                    const SizedBox(height: 8),
                    _InfoCard(children: [
                      _InfoRow(
                          Icons.tag_rounded,
                          'Review ID',
                          complaint.relatedReviewId?.isNotEmpty == true
                              ? complaint.relatedReviewId!
                              : (complaint.targetId ?? 'N/A')),
                      _InfoRow(Icons.person_outlined, 'Reported By',
                          complaint.userName),
                      _InfoRow(
                          Icons.person_pin_outlined,
                          'Reported Against',
                          complaint.targetUserName?.isNotEmpty == true
                              ? complaint.targetUserName!
                              : (complaint.targetName ?? 'N/A')),
                      _InfoRow(Icons.flag_outlined, 'Reason', complaint.reason),
                    ]),
                    if (complaint.description.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _DlgSectionLabel('Complaint Description'),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: AppAdmin.warm,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppAdmin.lightest)),
                        child: Text(complaint.description,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppAdmin.darkest,
                                height: 1.5)),
                      ),
                    ],
                  ]),
            ),
          )
        else
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Review card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8F0),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0xFFF59E0B).withOpacity(0.3)),
                      ),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [
                                        Color(0xFF059669),
                                        Color(0xFF10B981)
                                      ]),
                                      shape: BoxShape.circle),
                                  child: Consumer(builder: (context, ref, _) {
                                    final reviewer = r.customerId.isNotEmpty
                                        ? ref
                                            .watch(
                                                userByIdProvider(r.customerId))
                                            .valueOrNull
                                        : null;
                                    return ProfileAvatarImage(
                                      imageUrl: reviewer?.avatar,
                                      size: 40,
                                      fallbackText: r.customerName,
                                      fallbackTextStyle: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800),
                                    );
                                  })),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(r.customerName,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AppAdmin.darkest)),
                                    Text(
                                        '${r.createdAt.day}/${r.createdAt.month}/${r.createdAt.year}',
                                        style: const TextStyle(
                                            fontSize: 11, color: AppAdmin.mid)),
                                  ])),
                              // Star rating
                              Row(children: [
                                const Icon(Icons.star_rounded,
                                    color: Color(0xFFF59E0B), size: 16),
                                const SizedBox(width: 3),
                                Text(r.overallRating.toStringAsFixed(1),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: AppAdmin.darkest)),
                              ]),
                            ]),
                            const SizedBox(height: 12),
                            Text(r.comment,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppAdmin.darkest,
                                    height: 1.5)),
                            const SizedBox(height: 12),
                            // Sub ratings
                            _RatingBar('Speed', r.speedRating),
                            const SizedBox(height: 4),
                            _RatingBar('Quality', r.qualityRating),
                            const SizedBox(height: 4),
                            _RatingBar('Communication', r.communicationRating),
                          ]),
                    ),
                    const SizedBox(height: 16),
                    // Complaint reason
                    _InfoCard(children: [
                      _InfoRow(Icons.flag_outlined, 'Reason', complaint.reason),
                      _InfoRow(Icons.person_outlined, 'Reported By',
                          complaint.userName),
                      _InfoRow(Icons.description_outlined, 'Details',
                          complaint.description),
                    ]),
                    const SizedBox(height: 16),
                    // Actions
                    _DlgSectionLabel('Actions'),
                    const SizedBox(height: 10),
                    Row(children: [
                      _QuickActionBtn(
                        icon: Icons.delete_outline_rounded,
                        label: 'Delete',
                        color: const Color(0xFFDC2626),
                        onTap: () {
                          Navigator.pop(context);
                          _deleteReview(context, complaint, ref);
                        },
                      ),
                      const SizedBox(width: 8),
                      _QuickActionBtn(
                        icon: Icons.edit_outlined,
                        label: 'Edit',
                        color: AppAdmin.accent,
                        onTap: () {
                          Navigator.pop(context);
                          _editReview(context, complaint, ref);
                        },
                      ),
                      const SizedBox(width: 8),
                      _QuickActionBtn(
                        icon: Icons.thumb_up_outlined,
                        label: 'Keep',
                        color: const Color(0xFF059669),
                        onTap: () async {
                          Navigator.pop(context);
                          await markReviewSafeInFirestore(r.id);
                          setComplaintStatusInFirestore(
                              complaint, ComplaintStatus.resolved);
                          if (!context.mounted) return;
                          _doAction(
                              context,
                              ref,
                              complaint,
                              'Review kept — report dismissed',
                              const Color(0xFF059669));
                        },
                      ),
                    ]),
                  ]),
            ),
          ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  EDIT REVIEW SHEET
// ══════════════════════════════════════════════════════════════════════════════

class _EditReviewSheet extends StatefulWidget {
  final ReviewModel? review;
  final ComplaintModel complaint;
  final WidgetRef ref;
  const _EditReviewSheet(
      {this.review, required this.complaint, required this.ref});
  @override
  State<_EditReviewSheet> createState() => _EditReviewSheetState();
}

class _EditReviewSheetState extends State<_EditReviewSheet> {
  late TextEditingController _commentCtrl;

  @override
  void initState() {
    super.initState();
    _commentCtrl = TextEditingController(text: widget.review?.comment ?? '');
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppAdmin.lightest,
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: AppAdmin.accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.edit_outlined,
                      color: AppAdmin.accent, size: 22)),
              const SizedBox(width: 12),
              const Expanded(
                  child: Text('Edit Review Comment',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppAdmin.darkest))),
              IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppAdmin.mid),
                  onPressed: () => Navigator.pop(context)),
            ]),
          ),
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Review Comment',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppAdmin.mid)),
              const SizedBox(height: 8),
              TextField(
                controller: _commentCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Edit review comment...',
                  hintStyle: const TextStyle(color: AppAdmin.mid, fontSize: 13),
                  filled: true,
                  fillColor: AppAdmin.warm,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppAdmin.lightest)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppAdmin.lightest)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppAdmin.dark, width: 2)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final review = widget.review;
                    Navigator.pop(context);
                    if (review == null) {
                      _doAction(context, widget.ref, widget.complaint,
                          'Review not found — nothing to save', Colors.grey);
                      return;
                    }
                    await updateReviewInFirestore(
                        review.copyWith(comment: _commentCtrl.text.trim()));
                    if (!context.mounted) return;
                    _doAction(context, widget.ref, widget.complaint,
                        'Review comment updated successfully', AppAdmin.accent);
                  },
                  icon: const Icon(Icons.save_outlined, size: 16),
                  label: const Text('Save Changes',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppAdmin.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SYSTEM DETAIL SHEET
// ══════════════════════════════════════════════════════════════════════════════

class _SystemDetailSheet extends StatelessWidget {
  final ComplaintModel complaint;
  final WidgetRef ref;
  const _SystemDetailSheet({required this.complaint, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.80),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(children: [
        const SizedBox(height: 12),
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppAdmin.lightest,
                borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(children: [
            Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: AppAdmin.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.bug_report_outlined,
                    color: AppAdmin.accent, size: 22)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('System Issue Details',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppAdmin.darkest)),
                  Text('Reported by: ${complaint.userName}',
                      style:
                          const TextStyle(fontSize: 12, color: AppAdmin.mid)),
                ])),
            IconButton(
                icon: const Icon(Icons.close_rounded, color: AppAdmin.mid),
                onPressed: () => Navigator.pop(context)),
          ]),
        ),
        const Divider(height: 24),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Issue summary
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppAdmin.surfaceTint,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppAdmin.accent.withOpacity(0.2)),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: AppAdmin.accent, size: 18),
                        const SizedBox(width: 8),
                        Text(complaint.reason,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppAdmin.dark)),
                      ]),
                      const SizedBox(height: 10),
                      Text(complaint.description,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppAdmin.darkest,
                              height: 1.5)),
                    ]),
              ),
              const SizedBox(height: 16),
              _InfoCard(children: [
                _InfoRow(
                    Icons.person_outlined, 'Reported By', complaint.userName),
                _InfoRow(
                    Icons.calendar_today_outlined,
                    'Date',
                    '${complaint.createdAt.day}/${complaint.createdAt.month}/${complaint.createdAt.year}  '
                        '${complaint.createdAt.hour.toString().padLeft(2, '0')}:${complaint.createdAt.minute.toString().padLeft(2, '0')}'),
                _InfoRow(Icons.tag_rounded, 'Complaint ID', '#${complaint.id}'),
                _InfoRow(
                    Icons.priority_high_rounded,
                    'Priority',
                    complaint.priority == ComplaintPriority.high
                        ? 'High'
                        : complaint.priority == ComplaintPriority.medium
                            ? 'Medium'
                            : 'Low'),
              ]),
              const SizedBox(height: 16),
              // Technical info section
              _DlgSectionLabel('Technical Info'),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CodeLine('issue_type', complaint.reason),
                      _CodeLine('reported_by', complaint.userId),
                      _CodeLine(
                          'timestamp', complaint.createdAt.toIso8601String()),
                      _CodeLine('status', complaint.status.name),
                      _CodeLine('priority', complaint.priority.name),
                      if (complaint.targetId != null)
                        _CodeLine('related_id', complaint.targetId!),
                    ]),
              ),
              const SizedBox(height: 16),
              _DlgSectionLabel('Dev Actions'),
              const SizedBox(height: 10),
              Row(children: [
                _QuickActionBtn(
                  icon: Icons.code_rounded,
                  label: 'Send to Dev',
                  color: AppAdmin.accent,
                  onTap: () {
                    Navigator.pop(context);
                    _doAction(context, ref, complaint, 'Sent to dev team',
                        AppAdmin.accent);
                  },
                ),
                const SizedBox(width: 8),
                _QuickActionBtn(
                  icon: Icons.info_outline_rounded,
                  label: 'Known Issue',
                  color: AppAdmin.dark,
                  onTap: () {
                    Navigator.pop(context);
                    _doAction(context, ref, complaint, 'Marked as known issue',
                        AppAdmin.dark);
                  },
                ),
                const SizedBox(width: 8),
                _QuickActionBtn(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Resolve',
                  color: const Color(0xFF059669),
                  onTap: () {
                    Navigator.pop(context);
                    _resolveAction(context, ref, complaint);
                  },
                ),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── Shared small widgets ───────────────────────────────────────────────────────

class _EmptyDetail extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyDetail({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 52, color: AppAdmin.lightest),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: AppAdmin.mid, height: 1.6)),
        ]),
      );
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
            color: AppAdmin.warm,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppAdmin.lightest)),
        child: Column(
          children: children
              .asMap()
              .entries
              .map((e) => Column(
                    children: [
                      e.value,
                      if (e.key < children.length - 1)
                        Divider(
                            height: 1,
                            color: Colors.grey.shade100,
                            indent: 14,
                            endIndent: 14),
                    ],
                  ))
              .toList(),
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: AppAdmin.lightest,
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 16, color: AppAdmin.dark)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10,
                        color: AppAdmin.mid,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 1),
                Text(value,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppAdmin.darkest),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ])),
        ]),
      );
}

class _QuickActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickActionBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.25))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ]),
          ),
        ),
      );
}

class _RatingBar extends StatelessWidget {
  final String label;
  final double value;
  const _RatingBar(this.label, this.value);

  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(fontSize: 11, color: AppAdmin.mid))),
        Expanded(
            child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value / 5,
            backgroundColor: AppAdmin.lightest,
            color: const Color(0xFFF59E0B),
            minHeight: 6,
          ),
        )),
        const SizedBox(width: 8),
        Text(value.toStringAsFixed(1),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppAdmin.darkest)),
      ]);
}

class _CodeLine extends StatelessWidget {
  final String codeKey;
  final String value;
  const _CodeLine(this.codeKey, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          Text('$codeKey: ',
              style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                  fontFamily: 'monospace')),
          Expanded(
              child: Text('"$value"',
                  style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF4ADE80),
                      fontFamily: 'monospace'),
                  overflow: TextOverflow.ellipsis)),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
//  COMPLAINTS LIST
// ══════════════════════════════════════════════════════════════════════════════

class _ComplaintsList extends StatelessWidget {
  final List<ComplaintModel> complaints;
  final WidgetRef ref;
  final List<UserModel> users;
  const _ComplaintsList(
      {required this.complaints, required this.ref, required this.users});

  @override
  Widget build(BuildContext context) {
    if (complaints.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 52, color: AppAdmin.lightest),
          const SizedBox(height: 12),
          const Text('No complaints yet',
              style:
                  TextStyle(color: AppAdmin.mid, fontWeight: FontWeight.w600)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: complaints.length,
      itemBuilder: (ctx, i) =>
          _ComplaintCard(complaint: complaints[i], ref: ref, users: users),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  COMPLAINT CARD (with avatar photos + smart actions)
// ══════════════════════════════════════════════════════════════════════════════

class _ComplaintCard extends StatelessWidget {
  final ComplaintModel complaint;
  final WidgetRef ref;
  final List<UserModel> users;
  const _ComplaintCard(
      {required this.complaint, required this.ref, required this.users});

  UserModel? _findUser(String name) {
    try {
      return users.firstWhere(
          (u) => u.fullName.toLowerCase().contains(name.toLowerCase()));
    } catch (_) {
      return null;
    }
  }

  void _openUserDetails(BuildContext ctx, String name) {
    final u = _findUser(name);
    if (u == null) return;
    showAdminUserDetails(ctx, u, ref);
  }

  @override
  Widget build(BuildContext context) {
    final sc = _statusColors[complaint.status]!;
    final sl = _statusLabels[complaint.status]!;
    final si = _statusIcons[complaint.status]!;
    final sbg = _statusBg[complaint.status]!;
    final pc = _priorityColors[complaint.priority]!;
    final pl = _priorityLabels[complaint.priority]!;
    final pi = _priorityIcons[complaint.priority]!;

    // Smart recommendation: user with multiple complaints
    final userComplaintCount = ref
        .read(adminComplaintsProvider)
        .where((c) => c.userId == complaint.userId)
        .length;
    final showWarning = userComplaintCount >= 2;

    final c2 = Color.lerp(sc, Colors.black, 0.35)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppAdmin.surfaceTint,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: sc.withOpacity(0.16), width: 1),
        boxShadow: [
          BoxShadow(
              color: sc.withOpacity(0.16),
              blurRadius: 18,
              offset: const Offset(0, 8)),
          const BoxShadow(
              color: AppAdmin.borderSoft, blurRadius: 0, offset: Offset(0, 5)),
          const BoxShadow(
              color: AppAdmin.borderSoft, blurRadius: 14, offset: Offset(5, 5)),
          const BoxShadow(
              color: Colors.white, blurRadius: 14, offset: Offset(-4, -4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () =>
              showAdminComplaintSummary(context, complaint, ref, users),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Slim semantic top accent strip (same structural language
            // as the redesigned Admin Orders card — accent strip + light
            // body, rather than a full-width colored banner) ──
            Container(
              height: 5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [sc, sc.withOpacity(0.35)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight),
              ),
            ),

            // ── Structured header — 3D status icon avatar + title/subtype
            // + status/priority pills + three-dots, all on the card's own
            // light surface (no more full-color gradient banner) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                    child: Icon(_cxTypeIcons[_toCxType(complaint.type)]!,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(complaint.reason,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppAdmin.inkDarkest,
                                  letterSpacing: -0.2),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(_cxTypeLabels[_toCxType(complaint.type)]!,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppAdmin.inkLight,
                                  fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ]),
                  ),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: sc.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: sc.withOpacity(0.30)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(si, size: 10, color: sc),
                          const SizedBox(width: 3),
                          Text(sl,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: sc)),
                        ]),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: pc.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: pc.withOpacity(0.30)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(pi, size: 10, color: pc),
                          const SizedBox(width: 3),
                          Text(pl,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: pc)),
                        ]),
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  _ComplaintThreeDotsMenu(
                      complaint: complaint,
                      ref: ref,
                      users: users,
                      statusColor: sc),
                ],
              ),
            ),

            const SizedBox(height: 12),
            // Gradient divider — separates header from body, tinted by status
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

            // ── Body — tinted with a subtle status accent background ──
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: sbg,
                borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Smart warning/recommendation banner ──
                    if (showWarning)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFF59E0B).withOpacity(0.4)),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x22F59E0B),
                                blurRadius: 6,
                                offset: Offset(0, 3)),
                          ],
                        ),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withOpacity(0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.warning_amber_rounded,
                                size: 14, color: Color(0xFFF59E0B)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This user has $userComplaintCount complaints. Recommended: Suspend account.',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF92400E),
                                  fontWeight: FontWeight.w600,
                                  height: 1.3),
                            ),
                          ),
                        ]),
                      ),

                    // ── Description — a readable multi-line preview; the
                    // full untruncated text is always available in the
                    // complaint summary sheet opened by tapping the card ──
                    Text(complaint.description,
                        softWrap: true,
                        style: const TextStyle(
                            fontSize: 12, color: AppAdmin.inkMid, height: 1.45),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis),

                    const SizedBox(height: 12),

                    // ── USER AVATARS ROW ──
                    _AvatarRow(
                      complaint: complaint,
                      users: users,
                      onTapUser: (name) => _openUserDetails(context, name),
                    ),

                    const SizedBox(height: 10),

                    // ── Chips row ──
                    Wrap(spacing: 8, runSpacing: 6, children: [
                      _Neo3DChipC(
                          icon: Icons.calendar_today_outlined,
                          label:
                              '${complaint.createdAt.day}/${complaint.createdAt.month}/${complaint.createdAt.year}',
                          color: const Color(0xFF0EA5E9)),
                      if (complaint.targetId != null &&
                          complaint.targetId!.isNotEmpty)
                        _Neo3DChipC(
                            icon: _cxTypeIcons[_toCxType(complaint.type)]!,
                            label: complaint.type == ComplaintType.order
                                ? 'Order #${complaint.targetId}'
                                : complaint.type == ComplaintType.category
                                    ? 'Review #${complaint.targetId}'
                                    : complaint.type == ComplaintType.general
                                        ? 'Issue #${complaint.targetId}'
                                        : (complaint.targetName?.isNotEmpty ==
                                                true
                                            ? complaint.targetName!
                                            : 'User #${complaint.targetId}'),
                            color: _cxTypeColors[_toCxType(complaint.type)]!),
                      if (complaint.relatedOrderId != null &&
                          complaint.relatedOrderId!.isNotEmpty)
                        _Neo3DChipC(
                            icon: Icons.receipt_long_outlined,
                            label:
                                complaint.relatedOrderTitle?.isNotEmpty == true
                                    ? complaint.relatedOrderTitle!
                                    : 'Order #${complaint.relatedOrderId}',
                            color: const Color(0xFFF97316)),
                      if (complaint.replyText != null)
                        _Neo3DChipC(
                            icon: Icons.reply_rounded,
                            label: 'Replied',
                            color: const Color(0xFF059669)),
                    ]),
                    if (_hasRelatedTarget(complaint)) ...[
                      const SizedBox(height: 10),
                      // ── Open Related Page button ──
                      GestureDetector(
                        onTap: () => _openRelatedPage(context, complaint, ref),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                                color: _cxTypeColors[_toCxType(complaint.type)]!
                                    .withOpacity(0.35),
                                width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                  color:
                                      _cxTypeColors[_toCxType(complaint.type)]!
                                          .withOpacity(0.14),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(_cxTypeIcons[_toCxType(complaint.type)]!,
                                    size: 14,
                                    color: _cxTypeColors[
                                        _toCxType(complaint.type)]!),
                                const SizedBox(width: 7),
                                Text('Open Related Page',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: _cxTypeColors[
                                            _toCxType(complaint.type)]!)),
                              ]),
                        ),
                      ),
                    ],
                  ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Navigate to Related Page ─────────────────────────────────────────────────
// Priority order: related order -> related review -> reported-against user ->
// no supported related entity. Review is checked before target user so
// review-report complaints (which set both targetUserId and relatedReviewId)
// open the review, not the user profile. Chat reports are intentionally NOT
// handled here — they're managed only in Admin -> Chat Management -> Requests.
//
// Order/User: hand off to the real Admin Orders/Users tab via the existing
// adminNavIndexProvider + adminPendingOrderDetailsIdProvider /
// adminPendingUserDetailsIdProvider one-shot pattern (same mechanism already
// used by Category -> Provider -> Admin Users), so the normal Admin bottom
// navigation stays visible and each section's own live Firestore provider
// resolves the exact entity by its stable id once loaded.
// Review: Review Management isn't part of the IndexedStack shell (it's
// reached via Navigator.push, same as everywhere else in the app it's
// opened from), so it gets the same one-shot pending-id hand-off but via
// adminPendingReviewDetailsIdProvider, consumed by
// AdminReviewManagementScreen after its live reviews provider has loaded.
bool _hasRelatedTarget(ComplaintModel c) {
  if (c.relatedOrderId != null && c.relatedOrderId!.isNotEmpty) return true;
  if (c.relatedReviewId != null && c.relatedReviewId!.isNotEmpty) return true;
  final targetUserId = c.targetUserId ?? c.targetId;
  return targetUserId != null && targetUserId.isNotEmpty;
}

void _noRelatedPage(BuildContext ctx) {
  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
      content: Text('No related page is available for this complaint.'),
      backgroundColor: Color(0xFF334155),
      behavior: SnackBarBehavior.floating));
}

void _openRelatedPage(BuildContext ctx, ComplaintModel c, WidgetRef ref) {
  if (c.relatedOrderId != null && c.relatedOrderId!.isNotEmpty) {
    ref.read(adminPendingOrderDetailsIdProvider.notifier).state =
        c.relatedOrderId;
    ref.read(adminNavIndexProvider.notifier).state = 2; // Orders tab
    return;
  }

  if (c.relatedReviewId != null && c.relatedReviewId!.isNotEmpty) {
    ref.read(adminPendingReviewDetailsIdProvider.notifier).state =
        c.relatedReviewId;
    Navigator.push(ctx,
        MaterialPageRoute(builder: (_) => const AdminReviewManagementScreen()));
    return;
  }

  final targetUserId = c.targetUserId ?? c.targetId;
  if (targetUserId != null && targetUserId.isNotEmpty) {
    ref.read(adminPendingUserDetailsIdProvider.notifier).state = targetUserId;
    ref.read(adminNavIndexProvider.notifier).state = 1; // Users tab
    return;
  }

  _noRelatedPage(ctx);
}

// ─── Complaint Popup Menu ─────────────────────────────────────────────────────
class _ComplaintPopupMenu extends StatelessWidget {
  final ComplaintModel complaint;
  final WidgetRef ref;
  final List<UserModel> users;
  final BuildContext context;
  const _ComplaintPopupMenu(
      {required this.complaint,
      required this.ref,
      required this.users,
      required this.context});

  @override
  Widget build(BuildContext _) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded,
          color: AppColors.textSecondary, size: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 4,
      onSelected: (val) {
        switch (val) {
          case 'summary':
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _ComplaintSummarySheet(
                  complaint: complaint, ref: ref, users: users),
            );
            break;
          case 'inreview':
            setComplaintStatusInFirestore(complaint, ComplaintStatus.inReview);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Marked as In Review'),
                backgroundColor: Color(0xFFF59E0B),
                behavior: SnackBarBehavior.floating));
            break;
          case 'resolved':
            setComplaintStatusInFirestore(complaint, ComplaintStatus.resolved);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Complaint resolved ✓'),
                backgroundColor: Color(0xFF059669),
                behavior: SnackBarBehavior.floating));
            break;
          case 'reject':
            setComplaintStatusInFirestore(complaint, ComplaintStatus.rejected);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Complaint rejected'),
                backgroundColor: Color(0xFF6B7280),
                behavior: SnackBarBehavior.floating));
            break;
          case 'copy':
            Clipboard.setData(ClipboardData(text: complaint.id));
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Copied: ${complaint.id}'),
                behavior: SnackBarBehavior.floating));
            break;
          case 'delete':
            softDeleteComplaintInFirestore(complaint.id);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Complaint deleted'),
                backgroundColor: Color(0xFFDC2626),
                behavior: SnackBarBehavior.floating));
            break;
        }
      },
      itemBuilder: (_) => [
        _mi(
            value: 'summary',
            icon: Icons.summarize_outlined,
            label: 'View Complaint Summary',
            iconColor: AppAdmin.dark),
        const PopupMenuDivider(height: 1),
        _mi(
            value: 'inreview',
            icon: Icons.rate_review_outlined,
            label: 'Mark In Review',
            iconColor: const Color(0xFFF59E0B)),
        _mi(
            value: 'resolved',
            icon: Icons.check_circle_outline_rounded,
            label: 'Mark Resolved',
            iconColor: const Color(0xFF059669)),
        _mi(
            value: 'reject',
            icon: Icons.cancel_outlined,
            label: 'Reject Complaint',
            iconColor: const Color(0xFF6B7280)),
        const PopupMenuDivider(height: 1),
        _mi(
            value: 'copy',
            icon: Icons.copy_rounded,
            label: 'Copy Complaint ID',
            iconColor: AppAdmin.dark),
        _mi(
            value: 'delete',
            icon: Icons.delete_outline_rounded,
            label: 'Delete Complaint',
            iconColor: const Color(0xFFDC2626)),
      ],
    );
  }

  PopupMenuItem<String> _mi(
          {required String value,
          required IconData icon,
          required String label,
          Color iconColor = AppAdmin.dark}) =>
      PopupMenuItem<String>(
          value: value,
          height: 44,
          child: Row(children: [
            Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 16, color: iconColor)),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: iconColor == AppAdmin.dark
                        ? AppAdmin.darkest
                        : iconColor)),
          ]));
}

// ─── Neo-3D Info Chip for Complaints ─────────────────────────────────────────
class _Neo3DChipC extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Neo3DChipC(
      {required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.22), width: 1),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.12),
                blurRadius: 0,
                offset: const Offset(0, 2)),
            BoxShadow(
                color: color.withOpacity(0.10),
                blurRadius: 4,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          // Bounded so a single long label (e.g. an order/service title)
          // can never make one chip wide enough to push past the card's
          // edge — Wrap only reflows *between* chips, it doesn't itself
          // constrain an individual child's width.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color.withOpacity(0.9))),
          ),
        ]),
      );
}

// ─── Shared Menu Data & Panel (copied from admin_screens) ────────────────────
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

class _AdminMenuPanel extends StatefulWidget {
  final List<_AdminMenuItemData> items;
  // Set only when the panel wouldn't otherwise fully fit above or below the
  // trigger within the viewport — constrains the item column to the actual
  // available space and makes it scrollable so every action stays reachable
  // instead of being clipped off-screen. Null (the common case) keeps the
  // previous unconstrained, non-scrolling layout unchanged.
  final double? maxHeight;
  const _AdminMenuPanel({required this.items, this.maxHeight});
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
    // Same premium neumorphic panel — the only difference is that when
    // [maxHeight] is set (the panel wouldn't otherwise fully fit above or
    // below the trigger), the item column scrolls within that bound instead
    // of overflowing off-screen. When null (the common case), layout is
    // identical to before.
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
      width: 60,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
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

// ─── Complaint Three-Dots Menu (customer orders style) ───────────────────────
class _ComplaintThreeDotsMenu extends StatefulWidget {
  final ComplaintModel complaint;
  final WidgetRef ref;
  final List<UserModel> users;
  final Color statusColor;
  const _ComplaintThreeDotsMenu(
      {required this.complaint,
      required this.ref,
      required this.users,
      required this.statusColor});
  @override
  State<_ComplaintThreeDotsMenu> createState() =>
      _ComplaintThreeDotsMenuState();
}

class _ComplaintThreeDotsMenuState extends State<_ComplaintThreeDotsMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _busy = false;

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

  // Awaits the real Firestore write so success/error is reported truthfully,
  // and guards against duplicate taps while a write is in flight. The live
  // Firestore stream (allComplaintsProvider/userComplaintsProvider) is the
  // only source of truth for the UI once this completes.
  Future<void> _updateStatus(
    ScaffoldMessengerState scaffoldMsg,
    ComplaintStatus status,
    String successMessage,
    Color color,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await setComplaintStatusInFirestore(widget.complaint, status);
      if (!mounted) return;
      scaffoldMsg.showSnackBar(SnackBar(
          content: Text(successMessage),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    } catch (_) {
      if (!mounted) return;
      scaffoldMsg.showSnackBar(SnackBar(
          content: const Text('Failed to update complaint. Please try again.'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _open(BuildContext context) {
    if (_busy) return;
    HapticFeedback.lightImpact();
    final scaffoldMsg = ScaffoldMessenger.of(context);
    final status = widget.complaint.status;

    final items = <_AdminMenuItemData>[
      if (status == ComplaintStatus.open)
        _AdminMenuItemData(
          icon: Icons.rate_review_outlined,
          label: 'In Review',
          color: const Color(0xFFF59E0B),
          onTap: () => _updateStatus(scaffoldMsg, ComplaintStatus.inReview,
              'Marked as In Review', const Color(0xFFF59E0B)),
        ),
      if (status == ComplaintStatus.open ||
          status == ComplaintStatus.inReview) ...[
        _AdminMenuItemData(
          icon: Icons.check_circle_outline_rounded,
          label: 'Resolve',
          color: const Color(0xFF059669),
          onTap: () => _updateStatus(scaffoldMsg, ComplaintStatus.resolved,
              'Complaint resolved ✓', const Color(0xFF059669)),
        ),
        _AdminMenuItemData(
          icon: Icons.cancel_outlined,
          label: 'Reject',
          color: const Color(0xFF6B7280),
          onTap: () => _updateStatus(scaffoldMsg, ComplaintStatus.rejected,
              'Complaint rejected', const Color(0xFF6B7280)),
        ),
      ],
      _AdminMenuItemData(
        icon: Icons.copy_rounded,
        label: 'Copy ID',
        color: AppAdmin.dark,
        onTap: () {
          Clipboard.setData(ClipboardData(text: widget.complaint.id));
          scaffoldMsg.showSnackBar(SnackBar(
              content: Text('Copied: ${widget.complaint.id}'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))));
        },
      ),
    ];

    final box = context.findRenderObject() as RenderBox?;
    final pos = box?.localToGlobal(Offset.zero) ?? Offset.zero;
    final size = box?.size ?? Size.zero;

    // Viewport-aware direction/height so the panel never renders below the
    // screen, underneath the Admin bottom navigation, or above the safe top
    // area — same fix already applied to Admin Users' per-user three-dots
    // panel. Not coupled to the real bottom-nav widget/height on purpose —
    // a generous fixed safety margin on top of the device's own safe-area
    // inset keeps this correct even if the bottom nav's height changes.
    final mq = MediaQuery.of(context);
    const edgeMargin = 14.0;
    const bottomNavSafetyMargin = 84.0;
    final topSafeBound = mq.padding.top + edgeMargin;
    final bottomSafeBound =
        mq.size.height - mq.padding.bottom - bottomNavSafetyMargin - edgeMargin;

    // Estimated from the panel's own fixed layout formula (outer vertical
    // padding + a fixed per-item row height) — only used to pick a
    // direction and a safe max height. The panel itself still clamps to
    // whatever space is actually available and scrolls if needed, so an
    // estimate mismatch can never cause real overflow.
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
      // Neither direction fully fits — use whichever side has more room and
      // let the panel's own item column scroll internally so every action
      // stays reachable instead of being clipped off-screen.
      openDownward = spaceBelow >= spaceAbove;
      final available = openDownward ? spaceBelow : spaceAbove;
      maxPanelHeight = available.clamp(0.0, estimatedPanelHeight);
    }

    // Horizontal: same right-aligned anchor as before, but never let the
    // panel's fixed width push past the left screen edge on very narrow
    // viewports.
    const panelWidth = 60.0;
    const rightInset = 14.0;
    final wouldOverflowLeft =
        mq.size.width - rightInset - panelWidth < edgeMargin;
    final rightOffset = wouldOverflowLeft ? edgeMargin : rightInset;

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
            right: rightOffset,
            top: openDownward ? pos.dy + size.height - 20 : null,
            bottom: openDownward ? null : mq.size.height - pos.dy - 20,
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: Offset(0.3, openDownward ? -0.2 : 0.2),
                      end: Offset.zero)
                  .animate(curved),
              child: FadeTransition(
                  opacity: anim,
                  child:
                      _AdminMenuPanel(items: items, maxHeight: maxPanelHeight)),
            ),
          ),
        ]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Neumorphic light-surface trigger — the card header is now the card's
    // own light body (accent strip + light content, matching Admin Orders)
    // rather than a full-color gradient banner, so the trigger needs the
    // same raised-on-light treatment as the redesigned Admin Orders/Users
    // per-card triggers instead of the old translucent-white-on-color chip.
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
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppAdmin.surfaceTint,
            borderRadius: BorderRadius.circular(10),
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
                (_) => Container(
                      width: 3.5,
                      height: 3.5,
                      margin: const EdgeInsets.symmetric(vertical: 1.2),
                      decoration: BoxDecoration(
                          color: widget.statusColor.withOpacity(0.75),
                          shape: BoxShape.circle),
                    )),
          ),
        ),
      ),
    );
  }
}

// ─── Complaint Summary Sheet (neo-morphism, Admin Order Details style) ────────
// Visual structure only mirrors _OrderDetailsSheet (admin_screens.dart): the
// floating rounded neo-card, drag handle, header icon/title/badge/close
// layout, section labels and inset detail rows, and the gradient action
// button. None of its business logic is shared or duplicated.
class _ComplaintSummarySheet extends StatelessWidget {
  final ComplaintModel complaint;
  final WidgetRef ref;
  final List<UserModel> users;
  const _ComplaintSummarySheet(
      {required this.complaint, required this.ref, required this.users});

  // Prefer an exact id match (the real key), falling back to a best-effort
  // name match only for older records — same precedence _AvatarRow already
  // uses elsewhere in this file. Never falls back to an arbitrary/"first"
  // user — a miss here means the party is genuinely unresolved.
  UserModel? _findUserById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final u in users) {
      if (u.id == id) return u;
    }
    return null;
  }

  UserModel? _findUserByName(String? name) {
    if (name == null || name.trim().isEmpty) return null;
    final needle = name.trim().toLowerCase();
    for (final u in users) {
      if (u.fullName.toLowerCase().contains(needle)) return u;
    }
    return null;
  }

  bool get _hasReportedAgainstUser =>
      (complaint.targetUserId?.trim().isNotEmpty ?? false) ||
      (complaint.targetUserName?.trim().isNotEmpty ?? false);

  // Builds one "Parties Involved" card. [resolved] is looked up by the
  // real userId first (falling back to a name match for older records
  // written before targetUserId/complainantRole existed); when no
  // UserModel can be resolved at all, the card stays read-only (no chevron,
  // no onTap) and shows the stored name/role verbatim plus a small
  // "User unavailable" subtitle — never inventing a user or opening the
  // wrong profile.
  Widget _partyCard({
    required UserModel? resolved,
    required String storedName,
    required String? storedRole,
    required BuildContext context,
  }) {
    final role = resolved?.role ?? _parsePartyRole(storedRole);
    final label = role != null ? _partyRoleLabels[role]! : 'User';
    final color = role != null ? _partyRoleColors[role]! : AppAdmin.mid;
    final icon =
        role != null ? _partyRoleIcons[role]! : Icons.person_outline_rounded;
    final name = storedName.trim().isNotEmpty
        ? storedName.trim()
        : (resolved?.fullName.isNotEmpty == true ? resolved!.fullName : '—');

    return _CxPartyCard(
      icon: icon,
      label: label,
      name: name,
      roleColor: color,
      avatarUrl: resolved?.avatar,
      subtitle: resolved == null ? 'User unavailable' : null,
      onTap: resolved != null
          ? () => showAdminUserDetails(context, resolved, ref)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cxt = _toCxType(complaint.type);
    final tc = _cxTypeColors[cxt]!;
    final sc = _statusColors[complaint.status]!;
    final pc = _priorityColors[complaint.priority]!;

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
                      color: tc.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(4, 4)),
                  const BoxShadow(
                      color: Colors.white,
                      blurRadius: 8,
                      offset: Offset(-4, -4)),
                ],
              ),
              child: Icon(_cxTypeIcons[cxt]!, color: tc, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Complaint Summary',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppAdmin.inkDark)),
                  const SizedBox(height: 2),
                  Text(_cxTypeLabels[cxt]!,
                      style: TextStyle(
                          fontSize: 11,
                          color: tc,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
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
                    child: Text(_statusLabels[complaint.status]!,
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
            _CxNeoSectionLabel(label: 'Complaint Details', color: tc),
            const SizedBox(height: 10),
            _CxNeoDetailRow(
                icon: Icons.tag_rounded,
                label: 'Complaint ID',
                value: complaint.id,
                color: tc,
                trailing: complaint.id.isNotEmpty
                    ? _CxDetailCopyButton(
                        value: complaint.id,
                        snackText: 'Complaint ID copied.',
                        color: tc)
                    : null),
            const SizedBox(height: 18),
            _CxNeoSectionLabel(label: 'Parties Involved', color: tc),
            const SizedBox(height: 10),
            _partyCard(
                resolved: _findUserById(complaint.userId) ??
                    _findUserByName(complaint.userName),
                storedName: complaint.userName,
                storedRole: complaint.complainantRole,
                context: context),
            if (_hasReportedAgainstUser) ...[
              const SizedBox(height: 10),
              _partyCard(
                  resolved: _findUserById(complaint.targetUserId) ??
                      _findUserByName(complaint.targetUserName),
                  storedName: complaint.targetUserName ?? '',
                  storedRole: complaint.targetUserRole,
                  context: context),
            ],
            const SizedBox(height: 18),
            _CxNeoDetailRow(
                icon: Icons.link_rounded,
                label: 'Related Entity',
                value:
                    complaint.targetId != null ? '#${complaint.targetId}' : '—',
                color: tc,
                trailing:
                    complaint.targetId != null && complaint.targetId!.isNotEmpty
                        ? _CxDetailCopyButton(
                            value: complaint.targetId!,
                            snackText: 'Related entity ID copied.',
                            color: tc)
                        : null),
            _CxNeoDetailRow(
                icon: Icons.calendar_today_outlined,
                label: 'Date',
                value:
                    '${complaint.createdAt.day}/${complaint.createdAt.month}/${complaint.createdAt.year}',
                color: tc),
            _CxNeoDetailRow(
              icon: Icons.flag_outlined,
              label: 'Priority',
              color: tc,
              valueChip: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: pc.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(_priorityLabels[complaint.priority]!,
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w800, color: pc)),
              ),
            ),
            const SizedBox(height: 18),
            _CxNeoSectionLabel(label: 'Full Description', color: tc),
            const SizedBox(height: 10),
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
              child: Text(complaint.description,
                  style: const TextStyle(
                      fontSize: 13, color: AppAdmin.inkMid, height: 1.5)),
            ),
            const SizedBox(height: 24),
          ]),
        )),
        // Footer — Open Related Page (unchanged condition/callback, restyled
        // to match _NeoActionButton's gradient pill from Order Details).
        if (_hasRelatedTarget(complaint))
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: _CxNeoActionButton(
              label: 'Open Related Page',
              icon: _cxTypeIcons[cxt]!,
              gradient: [tc, _darken(tc)],
              onTap: () {
                // Close the Summary sheet first, then navigate, so the
                // target details never open behind this modal.
                Navigator.pop(context);
                _openRelatedPage(context, complaint, ref);
              },
            ),
          ),
      ]),
    );
  }
}

Color _darken(Color c, [double amount = .25]) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}

// ─── Parties Involved card (Complaint Summary) ────────────────────────────────
// Read-only tappable user card: role-colored icon/avatar, role label above
// the name, small chevron button — same neo card language already used by
// Admin Order Details' own "Parties Involved" section, kept as a local copy
// here (rather than importing that screen's private widget) so Order
// Details stays completely untouched. When [onTap] is null (no real
// UserModel could be resolved) the chevron is omitted entirely and the card
// is not tappable.
class _CxPartyCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String name;
  final Color roleColor;
  final String? avatarUrl;
  final String? subtitle;
  final VoidCallback? onTap;
  const _CxPartyCard({
    required this.icon,
    required this.label,
    required this.name,
    required this.roleColor,
    this.avatarUrl,
    this.subtitle,
    this.onTap,
  });

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
                    color: roleColor.withValues(alpha: 0.25),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppAdmin.inkDark)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppAdmin.inkLight,
                          fontStyle: FontStyle.italic)),
                ],
              ])),
          if (onTap != null)
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: AppAdmin.surfaceTint,
                shape: BoxShape.circle,
                boxShadow: [
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

class _CxNeoSectionLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _CxNeoSectionLabel({required this.label, required this.color});
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

// Detail row for the Complaint Summary sheet: either a plain text value or,
// for Priority, a colored chip via [valueChip] — mirrors _NeoDetailRow's
// inset-card look from Order Details while keeping the badge/chip styling
// Status and Priority already used.
class _CxNeoDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? valueChip;
  final Color color;
  // Optional small trailing action (e.g. a copy-ID button) rendered after
  // the value/chip. Existing rows that don't pass it are unaffected.
  final Widget? trailing;
  const _CxNeoDetailRow({
    required this.icon,
    required this.label,
    this.value,
    this.valueChip,
    required this.color,
    this.trailing,
  });
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppAdmin.surfaceTint,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
                color: AppAdmin.borderSoft,
                blurRadius: 4,
                offset: Offset(2, 2)),
            BoxShadow(
                color: Colors.white, blurRadius: 4, offset: Offset(-2, -2)),
          ],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppAdmin.inkMid,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          Flexible(
              child: valueChip ??
                  Text(value ?? '—',
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
}

// Copies [value] to the clipboard and shows [snackText]. No Firestore access.
class _CxDetailCopyButton extends StatelessWidget {
  final String value;
  final String snackText;
  final Color color;
  const _CxDetailCopyButton(
      {required this.value, required this.snackText, required this.color});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: value));
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(snackText), behavior: SnackBarBehavior.floating));
        },
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
              shape: BoxShape.circle, color: color.withOpacity(0.12)),
          child: Icon(Icons.copy_rounded, size: 14, color: color),
        ),
      );
}

// Gradient action button matching _NeoActionButton (Order Details) — visual
// copy only, kept local since it's used once here.
class _CxNeoActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;
  const _CxNeoActionButton(
      {required this.label,
      required this.icon,
      required this.gradient,
      required this.onTap});
  @override
  State<_CxNeoActionButton> createState() => _CxNeoActionButtonState();
}

class _CxNeoActionButtonState extends State<_CxNeoActionButton>
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

// ══════════════════════════════════════════════════════════════════════════════
//  USER AVATAR ROW  (complainant → target)
// ══════════════════════════════════════════════════════════════════════════════

class _AvatarRow extends StatelessWidget {
  final ComplaintModel complaint;
  final List<UserModel> users;
  final void Function(String name) onTapUser;
  const _AvatarRow(
      {required this.complaint, required this.users, required this.onTapUser});

  UserModel? _findUserById(String? id) {
    if (id == null || id.isEmpty) return null;
    try {
      return users.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  // Legacy fallback for older complaint docs written before targetUserId
  // was captured — name matching is best-effort only, never the primary key.
  UserModel? _findUserByName(String name) {
    try {
      return users.firstWhere(
          (u) => u.fullName.toLowerCase().contains(name.toLowerCase()));
    } catch (_) {
      return null;
    }
  }

  // Avatar + name + role-subtitle block for one party. Wrapped by the
  // caller in a Flexible/full-width slot so the name can wrap (never
  // overflow) instead of pushing content outside the card.
  Widget _partyBlock({
    required UserModel? user,
    required String name,
    required String? role,
    required String roleLabelPrefix,
    required Color nameColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(user: user, fallbackName: name, size: 36),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: nameColor)),
                Text(
                    role != null ? '$roleLabelPrefix ($role)' : roleLabelPrefix,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: AppAdmin.mid)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _vsChip() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626).withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Text('vs',
              style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.w800)),
          SizedBox(width: 3),
          Icon(Icons.arrow_forward_rounded, size: 10, color: Color(0xFFDC2626)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final complainant =
        _findUserById(complaint.userId) ?? _findUserByName(complaint.userName);
    final target = complaint.targetName != null
        ? (_findUserById(complaint.targetUserId) ??
            _findUserByName(complaint.targetName!))
        : null;

    final complainantBlock = _partyBlock(
      user: complainant,
      name: complaint.userName,
      role: complaint.complainantRole,
      roleLabelPrefix: 'Filed by',
      nameColor: AppAdmin.darkest,
      onTap: () => onTapUser(complaint.userName),
    );

    if (complaint.targetName == null) return complainantBlock;

    final targetBlock = _partyBlock(
      user: target,
      name: complaint.targetName!,
      role: complaint.targetUserRole,
      roleLabelPrefix: 'Against',
      nameColor: const Color(0xFFDC2626),
      onTap: () => onTapUser(complaint.targetName!),
    );

    // Wide enough to fit both parties + the "vs" connector on one line;
    // otherwise stack vertically so avatars/names never get squeezed or
    // pushed outside the card on narrow/mobile widths.
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= 300) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(child: complainantBlock),
            const SizedBox(width: 8),
            Padding(padding: const EdgeInsets.only(top: 6), child: _vsChip()),
            const SizedBox(width: 8),
            Flexible(child: targetBlock),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          complainantBlock,
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _vsChip()),
          targetBlock,
        ],
      );
    });
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  AVATAR WIDGET
// ══════════════════════════════════════════════════════════════════════════════

class _Avatar extends StatelessWidget {
  final UserModel? user;
  final String fallbackName;
  final double size;
  const _Avatar(
      {required this.user, required this.fallbackName, required this.size});

  Widget _initialsAvatar() {
    final initials = fallbackName.isNotEmpty
        ? fallbackName
            .trim()
            .split(' ')
            .take(2)
            .map((w) => w[0])
            .join()
            .toUpperCase()
        : '?';

    // Gradient initials avatar
    final colors = [
      [AppAdmin.darkest, AppAdmin.dark],
      [AppAdmin.accent, AppAdmin.mid],
      [const Color(0xFF059669), const Color(0xFF10B981)],
      [const Color(0xFFDC2626), const Color(0xFFEF4444)],
    ];
    final colorPair = colors[fallbackName.isNotEmpty
        ? fallbackName.codeUnitAt(0) % colors.length
        : 0];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
            colors: colorPair,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        boxShadow: [
          BoxShadow(
              color: colorPair[0].withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Center(
        child: Text(initials,
            style: TextStyle(
                fontSize: size * 0.33,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = user?.avatar?.trim();
    if (url == null || url.isEmpty) return _initialsAvatar();

    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : _initialsAvatar(),
        errorBuilder: (context, error, stack) => _initialsAvatar(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ACTION BUTTONS — Details button + 3-dot menu that opens actions sheet
// ══════════════════════════════════════════════════════════════════════════════

class _ActionButtons extends StatelessWidget {
  final ComplaintModel complaint;
  final WidgetRef ref;
  final VoidCallback onDetails;
  const _ActionButtons(
      {required this.complaint, required this.ref, required this.onDetails});

  void _showActionsSheet(BuildContext context) {
    final actions = _actionsFor(complaint.type);
    // For OPEN status: only Details & Start Review
    // For RESOLVED: only Details
    // For IN_REVIEW: full smart actions list

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppAdmin.lightest,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [AppAdmin.darkest, AppAdmin.dark]),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.tune_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Actions',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppAdmin.darkest)),
                      Text(complaint.reason,
                          style: const TextStyle(
                              fontSize: 12, color: AppAdmin.mid),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  )),
                ]),
              ),
              const SizedBox(height: 12),
              Divider(color: Colors.grey.shade100, height: 1),

              // Actions list
              if (complaint.status == ComplaintStatus.open) ...[
                _SheetActionTile(
                  icon: Icons.visibility_outlined,
                  label: 'Details',
                  subtitle: 'View full complaint details',
                  color: AppAdmin.dark,
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    onDetails();
                  },
                ),
                Divider(height: 1, indent: 56, color: Colors.grey.shade100),
                _SheetActionTile(
                  icon: Icons.rate_review_outlined,
                  label: 'Start Review',
                  subtitle: 'Move complaint to In Review',
                  color: const Color(0xFFF59E0B),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    setComplaintStatusInFirestore(
                        complaint, ComplaintStatus.inReview);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: const Text('Moved to In Review'),
                      backgroundColor: const Color(0xFFF59E0B),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ));
                  },
                ),
              ] else if (complaint.status == ComplaintStatus.inReview) ...[
                _SheetActionTile(
                  icon: Icons.visibility_outlined,
                  label: 'Details',
                  subtitle: 'View full complaint details',
                  color: AppAdmin.dark,
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    onDetails();
                  },
                ),
                ...actions.asMap().entries.map((entry) {
                  final i = entry.key;
                  final a = entry.value;
                  final isLast = i == actions.length - 1;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Divider(
                          height: 1, indent: 56, color: Colors.grey.shade100),
                      _SheetActionTile(
                        icon: a.icon,
                        label: a.label,
                        subtitle: a.subtitle,
                        color: a.color,
                        isLast: isLast,
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          a.onTap(context, complaint, ref);
                        },
                      ),
                    ],
                  );
                }),
              ] else ...[
                // RESOLVED
                _SheetActionTile(
                  icon: Icons.visibility_outlined,
                  label: 'Details',
                  subtitle: 'View full complaint details',
                  color: AppAdmin.dark,
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    onDetails();
                  },
                ),
              ],

              // Cancel
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    onPressed: () => Navigator.pop(sheetCtx),
                    child: const Text('Cancel',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppAdmin.darkest)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      // Details button
      Expanded(
        child: OutlinedButton.icon(
          onPressed: onDetails,
          icon: const Icon(Icons.visibility_outlined, size: 14),
          label: const Text('Details', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppAdmin.dark,
            side: BorderSide(color: AppAdmin.dark.withOpacity(0.4)),
            backgroundColor: AppAdmin.warm,
            padding: const EdgeInsets.symmetric(vertical: 9),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      const SizedBox(width: 8),
      // 3-dots actions button
      GestureDetector(
        onTap: () => _showActionsSheet(context),
        child: Container(
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            gradient:
                const LinearGradient(colors: [AppAdmin.darkest, AppAdmin.dark]),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                  color: AppAdmin.darkest.withOpacity(0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3))
            ],
          ),
          child: const Icon(Icons.more_vert_rounded,
              color: Colors.white, size: 20),
        ),
      ),
    ]);
  }
}

// ── Sheet Action Tile ─────────────────────────────────────────────────────────
class _SheetActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool isLast;
  const _SheetActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color == const Color(0xFFDC2626) ||
                                color == const Color(0xFFEA580C)
                            ? color
                            : AppAdmin.darkest)),
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      style:
                          const TextStyle(fontSize: 11, color: AppAdmin.mid)),
              ],
            )),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: Colors.grey.shade300),
          ]),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
//  COMPLAINT DETAILS DIALOG (Tabs: Details / Actions / Timeline / Evidence)
// ══════════════════════════════════════════════════════════════════════════════

class _ComplaintDetailsDialog extends StatefulWidget {
  final ComplaintModel complaint;
  final WidgetRef ref;
  final List<UserModel> users;
  const _ComplaintDetailsDialog(
      {required this.complaint, required this.ref, required this.users});
  @override
  State<_ComplaintDetailsDialog> createState() =>
      _ComplaintDetailsDialogState();
}

class _ComplaintDetailsDialogState extends State<_ComplaintDetailsDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  late ComplaintModel _c;
  final _replyCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _showReplyField = false;
  bool _showNoteField = false;

  // Timeline events (simulated for demo)
  late List<_TimelineEvent> _timeline;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _c = widget.complaint;
    _replyCtrl.text = _c.replyText ?? '';
    _noteCtrl.text = _c.adminNote ?? '';
    _timeline = _buildTimeline();
  }

  List<_TimelineEvent> _buildTimeline() {
    final events = <_TimelineEvent>[
      _TimelineEvent(
        label: 'Complaint Created',
        icon: Icons.flag_outlined,
        color: const Color(0xFFDC2626),
        date: _c.createdAt,
        desc: 'Submitted by ${_c.userName}',
      ),
    ];
    if (_c.status == ComplaintStatus.inReview ||
        _c.status == ComplaintStatus.resolved) {
      events.add(_TimelineEvent(
        label: 'Under Review',
        icon: Icons.rate_review_outlined,
        color: const Color(0xFFF59E0B),
        date: _c.createdAt.add(const Duration(hours: 2)),
        desc: 'Admin started reviewing the complaint',
      ));
    }
    if (_c.replyText != null) {
      events.add(_TimelineEvent(
        label: 'Admin Replied',
        icon: Icons.reply_rounded,
        color: AppAdmin.accent,
        date: _c.repliedAt ?? _c.createdAt.add(const Duration(hours: 5)),
        desc: _c.repliedBy ?? 'Admin',
      ));
    }
    if (_c.adminNote != null) {
      events.add(_TimelineEvent(
        label: 'Note Added',
        icon: Icons.sticky_note_2_outlined,
        color: AppAdmin.dark,
        date: _c.createdAt.add(const Duration(hours: 3)),
        desc: 'Internal note recorded by admin',
      ));
    }
    if (_c.status == ComplaintStatus.resolved) {
      events.add(_TimelineEvent(
        label: 'Resolved',
        icon: Icons.check_circle_outline_rounded,
        color: const Color(0xFF059669),
        date: _c.repliedAt ?? _c.createdAt.add(const Duration(hours: 6)),
        desc: 'Complaint marked as resolved',
      ));
    }
    return events;
  }

  @override
  void dispose() {
    _tab.dispose();
    _replyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _update(ComplaintModel updated) {
    updateComplaintInFirestore(updated);
    setState(() {
      _c = updated;
      _timeline = _buildTimeline();
    });
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppAdmin.mid, fontSize: 13),
        filled: true,
        fillColor: AppAdmin.warm,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppAdmin.lightest, width: 1.5)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppAdmin.lightest, width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppAdmin.dark, width: 2)),
      );

  @override
  Widget build(BuildContext context) {
    final sc = _statusColors[_c.status]!;
    final sbg = _statusBg[_c.status]!;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: AppAdmin.darkest.withOpacity(0.18),
                blurRadius: 32,
                offset: const Offset(0, 8))
          ],
        ),
        child: Column(children: [
          // ── Header ──
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [sc.withOpacity(0.9), sc],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 0),
            child: Column(children: [
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(_statusIcons[_c.status]!,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_c.reason,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Row(children: [
                          _WhiteBadge(_statusLabels[_c.status]!),
                          const SizedBox(width: 5),
                          _WhiteBadge(_priorityLabels[_c.priority]!),
                          const SizedBox(width: 5),
                          _WhiteBadge(_typeLabels[_c.type]!),
                        ]),
                      ]),
                ),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white70, size: 22)),
              ]),
              const SizedBox(height: 10),
              // Tab bar
              TabBar(
                controller: _tab,
                indicatorColor: Colors.white,
                indicatorWeight: 2.5,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                labelStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                unselectedLabelStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                tabs: const [
                  Tab(text: 'Details'),
                  Tab(text: 'Actions'),
                  Tab(text: 'Timeline'),
                ],
              ),
            ]),
          ),

          // ── Tab Body ──
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                // ── TAB 1: Details ──
                SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar row
                        _AvatarRow(
                          complaint: _c,
                          users: widget.users,
                          onTapUser: (name) {
                            final u = widget.users.firstWhere(
                                (u) => u.fullName
                                    .toLowerCase()
                                    .contains(name.toLowerCase()),
                                orElse: () => widget.users.first);
                            Navigator.pop(context);
                            showAdminUserDetails(context, u, widget.ref);
                          },
                        ),
                        const SizedBox(height: 16),

                        _DlgSectionLabel('Complaint Details'),
                        const SizedBox(height: 10),
                        _DlgRow(
                            icon: Icons.category_outlined,
                            label: 'Type',
                            value: _typeLabels[_c.type]!),
                        _DlgRow(
                            icon: Icons.calendar_today_outlined,
                            label: 'Date',
                            value:
                                '${_c.createdAt.day}/${_c.createdAt.month}/${_c.createdAt.year}  ${_c.createdAt.hour.toString().padLeft(2, '0')}:${_c.createdAt.minute.toString().padLeft(2, '0')}'),

                        const SizedBox(height: 12),
                        _DlgSectionLabel('Description'),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                              color: sbg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: sc.withOpacity(0.2))),
                          child: Text(_c.description,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppAdmin.darkest,
                                  height: 1.5)),
                        ),

                        // Reply section
                        const SizedBox(height: 16),
                        _DlgSectionLabel('Reply to User'),
                        const SizedBox(height: 8),
                        if (_c.replyText != null && !_showReplyField)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(0xFF059669)
                                        .withOpacity(0.25))),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    const Icon(Icons.reply_rounded,
                                        size: 14, color: Color(0xFF059669)),
                                    const SizedBox(width: 6),
                                    Text('From: ${_c.repliedBy ?? "Admin"}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF059669))),
                                    const Spacer(),
                                    GestureDetector(
                                        onTap: () => setState(
                                            () => _showReplyField = true),
                                        child: const Icon(Icons.edit_outlined,
                                            size: 14, color: AppAdmin.dark)),
                                  ]),
                                  const SizedBox(height: 6),
                                  Text(_c.replyText!,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppAdmin.darkest)),
                                ]),
                          ),
                        if (_showReplyField || _c.replyText == null)
                          Column(children: [
                            TextField(
                              controller: _replyCtrl,
                              maxLines: 3,
                              decoration:
                                  _dec('Write your reply to the user...'),
                            ),
                            const SizedBox(height: 8),
                            Row(children: [
                              if (_showReplyField)
                                TextButton(
                                    onPressed: () =>
                                        setState(() => _showReplyField = false),
                                    child: const Text('Cancel',
                                        style: TextStyle(color: AppAdmin.mid))),
                              const Spacer(),
                              ElevatedButton.icon(
                                onPressed: () {
                                  if (_replyCtrl.text.trim().isEmpty) return;
                                  _update(_c.copyWith(
                                    replyText: _replyCtrl.text.trim(),
                                    repliedAt: DateTime.now(),
                                    repliedBy: 'System Admin',
                                  ));
                                  setState(() => _showReplyField = false);
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: const Text('Reply sent ✓'),
                                    backgroundColor: const Color(0xFF059669),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ));
                                },
                                icon: const Icon(Icons.send_rounded, size: 14),
                                label: const Text('Send Reply',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ]),
                          ]),

                        // Admin Note
                        const SizedBox(height: 16),
                        _DlgSectionLabel('Internal Note (Admin Only)'),
                        const SizedBox(height: 8),
                        if (_c.adminNote != null && !_showNoteField)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: AppAdmin.warm,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppAdmin.lightest)),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.sticky_note_2_outlined,
                                      size: 16, color: AppAdmin.dark),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text(_c.adminNote!,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppAdmin.darkest))),
                                  GestureDetector(
                                      onTap: () =>
                                          setState(() => _showNoteField = true),
                                      child: const Icon(Icons.edit_outlined,
                                          size: 14, color: AppAdmin.dark)),
                                ]),
                          ),
                        if (_showNoteField || _c.adminNote == null)
                          Column(children: [
                            TextField(
                              controller: _noteCtrl,
                              maxLines: 2,
                              decoration: _dec(
                                  'Internal note (not visible to user)...'),
                            ),
                            const SizedBox(height: 8),
                            Row(children: [
                              if (_showNoteField)
                                TextButton(
                                    onPressed: () =>
                                        setState(() => _showNoteField = false),
                                    child: const Text('Cancel',
                                        style: TextStyle(color: AppAdmin.mid))),
                              const Spacer(),
                              ElevatedButton.icon(
                                onPressed: () {
                                  if (_noteCtrl.text.trim().isEmpty) return;
                                  _update(_c.copyWith(
                                      adminNote: _noteCtrl.text.trim()));
                                  setState(() => _showNoteField = false);
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: const Text('Note saved'),
                                    backgroundColor: AppAdmin.dark,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ));
                                },
                                icon: const Icon(Icons.save_outlined, size: 14),
                                label: const Text('Save',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppAdmin.dark,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ]),
                          ]),
                      ]),
                ),

                // ── TAB 2: Actions ──
                SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Change status
                        _DlgSectionLabel('Change Status'),
                        const SizedBox(height: 10),
                        Row(
                            children: ComplaintStatus.values.map((s) {
                          final sel = _c.status == s;
                          final c = _statusColors[s]!;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: GestureDetector(
                                onTap: () {
                                  _update(_c.copyWith(status: s));
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content:
                                        Text('Status → ${_statusLabels[s]}'),
                                    backgroundColor: c,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ));
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: sel ? c : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: sel ? c : AppAdmin.lightest,
                                        width: 1.5),
                                  ),
                                  child: Column(children: [
                                    Icon(_statusIcons[s]!,
                                        size: 16,
                                        color: sel ? Colors.white : c),
                                    const SizedBox(height: 4),
                                    Text(_statusLabels[s]!,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: sel ? Colors.white : c)),
                                  ]),
                                ),
                              ),
                            ),
                          );
                        }).toList()),

                        const SizedBox(height: 16),

                        // Change priority
                        _DlgSectionLabel('Priority'),
                        const SizedBox(height: 10),
                        Row(
                            children: ComplaintPriority.values.map((p) {
                          final sel = _c.priority == p;
                          final c = _priorityColors[p]!;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: GestureDetector(
                                onTap: () => _update(_c.copyWith(priority: p)),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: sel ? c : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: sel ? c : AppAdmin.lightest,
                                        width: 1.5),
                                  ),
                                  child: Column(children: [
                                    Icon(_priorityIcons[p]!,
                                        size: 16,
                                        color: sel ? Colors.white : c),
                                    const SizedBox(height: 4),
                                    Text(_priorityLabels[p]!,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: sel ? Colors.white : c)),
                                  ]),
                                ),
                              ),
                            ),
                          );
                        }).toList()),

                        const SizedBox(height: 20),

                        // Smart actions for in-review
                        if (_c.status == ComplaintStatus.inReview) ...[
                          _DlgSectionLabel('Smart Actions'),
                          const SizedBox(height: 10),
                          Column(
                            children: _actionsFor(_c.type)
                                .map<Widget>((a) => Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _SheetActionTile(
                                          icon: a.icon,
                                          label: a.label,
                                          subtitle: a.subtitle,
                                          color: a.color,
                                          onTap: () {
                                            a.onTap(context, _c, widget.ref);
                                            if (a.label == 'Resolve') {
                                              Navigator.pop(context);
                                            }
                                          },
                                        ),
                                        Divider(
                                            height: 1,
                                            indent: 56,
                                            color: Colors.grey.shade100),
                                      ],
                                    ))
                                .toList(),
                          ),
                        ],
                      ]),
                ),

                // ── TAB 3: Timeline ──
                SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DlgSectionLabel('Complaint Timeline'),
                        const SizedBox(height: 16),
                        ..._timeline.asMap().entries.map((entry) {
                          final i = entry.key;
                          final ev = entry.value;
                          final isLast = i == _timeline.length - 1;
                          return _TimelineTile(event: ev, isLast: isLast);
                        }),
                      ]),
                ),
              ],
            ),
          ),

          // ── Footer ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppAdmin.dark,
                  side: const BorderSide(color: AppAdmin.dark),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Close',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  TIMELINE TILE
// ══════════════════════════════════════════════════════════════════════════════

class _TimelineEvent {
  final String label;
  final IconData icon;
  final Color color;
  final DateTime date;
  final String desc;
  const _TimelineEvent(
      {required this.label,
      required this.icon,
      required this.color,
      required this.date,
      required this.desc});
}

class _TimelineTile extends StatelessWidget {
  final _TimelineEvent event;
  final bool isLast;
  const _TimelineTile({required this.event, required this.isLast});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line + dot
          Column(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: event.color.withOpacity(0.12),
                shape: BoxShape.circle,
                border:
                    Border.all(color: event.color.withOpacity(0.3), width: 1.5),
              ),
              child: Icon(event.icon, size: 16, color: event.color),
            ),
            if (!isLast)
              Container(width: 2, height: 32, color: AppAdmin.lightest),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.label,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: event.color)),
                    const SizedBox(height: 2),
                    Text(event.desc,
                        style:
                            const TextStyle(fontSize: 12, color: AppAdmin.mid)),
                    const SizedBox(height: 3),
                    Text(
                      '${event.date.day}/${event.date.month}/${event.date.year}  ${event.date.hour.toString().padLeft(2, '0')}:${event.date.minute.toString().padLeft(2, '0')}',
                      style:
                          const TextStyle(fontSize: 10.5, color: AppAdmin.mid),
                    ),
                  ]),
            ),
          ),
        ],
      );
}

// ══════════════════════════════════════════════════════════════════════════════
//  EVIDENCE CHIP
// ══════════════════════════════════════════════════════════════════════════════

// ── Bullet Row helper ─────────────────────────────────────────────────────────
class _BulletRow extends StatelessWidget {
  final String text;
  const _BulletRow(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('• ',
              style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.w700)),
          Expanded(
              child: Text(text,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700))),
        ]),
      );
}

class _EvidenceChip extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;
  const _EvidenceChip(
      {required this.name, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppAdmin.lightest),
        ),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppAdmin.darkest)),
          ),
          const Icon(Icons.download_outlined, size: 18, color: AppAdmin.mid),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
//  SMALL SHARED WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _Badge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
  const _Badge(
      {required this.label,
      required this.icon,
      required this.color,
      required this.bg});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: color)),
        ]),
      );
}

class _WhiteBadge extends StatelessWidget {
  final String label;
  const _WhiteBadge(this.label);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
      );
}

class _CChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _CChip({required this.icon, required this.label, this.color});
  @override
  Widget build(BuildContext context) {
    final c = color ?? AppAdmin.mid;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: c),
      const SizedBox(width: 4),
      Text(label,
          style:
              TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w500)),
    ]);
  }
}

class _DlgSectionLabel extends StatelessWidget {
  final String label;
  const _DlgSectionLabel(this.label);
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 4,
          height: 15,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppAdmin.darkest, AppAdmin.accent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppAdmin.darkest)),
      ]);
}

class _DlgRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color? valueColor;
  const _DlgRow(
      {required this.icon,
      required this.label,
      required this.value,
      this.valueColor});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
                color: AppAdmin.lightest,
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 15, color: AppAdmin.dark),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 10,
                      color: AppAdmin.mid,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: valueColor ?? AppAdmin.darkest)),
            ]),
          ),
        ]),
      );
}
