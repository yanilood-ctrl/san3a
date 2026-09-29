import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/shared_widgets.dart' show AppBlue;
import '../widgets/notification_details_dialog.dart';
import '../widgets/review_details_dialog.dart';
import '../widgets/category_requests_screen.dart';
import '../../features/auth/presentation/providers/app_providers.dart';
import '../../features/customer/presentation/screens/customer_orders_screen.dart'
    show openCustomerOrderDetail;
import '../../features/customer/presentation/screens/customer_chat_screen.dart';
import '../../features/customer/presentation/screens/customer_profile_screen.dart'
    show CustomerComplaintsScreen;
import '../../features/customer/presentation/screens/customer_category_requests_screen.dart';
import '../../features/professional/presentation/screens/professional_order_detail_screen.dart';
import '../../features/professional/presentation/screens/professional_chat_screen.dart';
import '../../features/professional/presentation/screens/professional_home_screen.dart'
    show ProfessionalComplaintsPage;
import '../../features/contractor/presentation/screens/contractor_order_detail_screen.dart';
import '../../features/contractor/presentation/screens/contractor_chat_screen.dart';
import '../../features/contractor/presentation/screens/contractor_profile_screen.dart'
    show ContractorComplaintsPage;

// ── Shared Notification Tap Router ──────────────────────────────────────────
// Single entry point used by Customer, Professional and Contractor
// notification UIs so all three roles route a tap the same way instead of
// keeping three drifting copies of this logic. See section-by-section
// routing below; every branch falls back to showNotificationDetailsDialog
// rather than the old "No related page available" snackbar.
//
// Contract: caller must pass the full overlaid UserNotificationView (not a
// reduced per-role display model) so every related-id field the notification
// was created with survives through to this router, and so isRead reflects
// this user's own per-user state (users/{uid}/notification_states/{id}) —
// never the shared, cross-user content document's legacy isRead field
// (Phase 5C1B/5C2).
Future<void> handleNotificationTap(
  BuildContext context,
  WidgetRef ref,
  UserNotificationView view,
  UserRole currentRole,
) async {
  final notification = view.notification;
  if (!view.isRead) {
    final uid = ref.read(authProvider)?.id;
    if (uid != null && uid.isNotEmpty) {
      try {
        await markNotificationReadInFirestore(uid, notification.id);
      } catch (e) {
        debugPrint('NOTIFICATION_MARK_READ_FAILED: $e');
      }
    }
  }
  if (!context.mounted) return;

  switch (notification.type) {
    case NotificationType.orderUpdate:
      await _routeOrder(context, ref, notification, currentRole);
      break;
    case NotificationType.chat:
      await _routeChat(context, ref, notification, currentRole);
      break;
    case NotificationType.review:
      await _routeReview(context, ref, notification, currentRole);
      break;
    case NotificationType.complaint:
      await _routeComplaint(context, ref, notification, currentRole);
      break;
    case NotificationType.categoryRequest:
      _routeCategoryRequest(
          context, currentRole, notification.relatedCategoryRequestId);
      break;
    case NotificationType.broadcast:
    case NotificationType.system:
    case NotificationType.general:
      showNotificationDetailsDialog(context, notification,
          accentColor: _accentForRole(currentRole));
      break;
  }
}

Color _accentForRole(UserRole role) {
  switch (role) {
    case UserRole.customer:
      return AppBlue.dark;
    case UserRole.professional:
      return AppGreen.dark;
    case UserRole.contractor:
      return const Color(0xFF8C6E63); // matches contractor AppBrown.dark
    case UserRole.admin:
      return AppBlue.dark;
  }
}

// ─── Orders ───────────────────────────────────────────────────────────────
Future<void> _routeOrder(BuildContext context, WidgetRef ref,
    NotificationModel notification, UserRole currentRole) async {
  final orderId = notification.relatedOrderId;
  if (orderId == null || orderId.isEmpty) {
    showNotificationDetailsDialog(context, notification,
        accentColor: _accentForRole(currentRole));
    return;
  }

  OrderModel? order;
  try {
    switch (currentRole) {
      case UserRole.customer:
        order =
            await _resolveOrder(ref, customerFirestoreOrdersProvider, orderId);
        break;
      case UserRole.professional:
        order = await _resolveOrder(
            ref, professionalFirestoreOrdersProvider, orderId);
        break;
      case UserRole.contractor:
        order = await _resolveOrder(
            ref, contractorFirestoreOrdersProvider, orderId);
        break;
      case UserRole.admin:
        order = null;
        break;
    }
  } catch (e) {
    debugPrint('NOTIFICATION_ORDER_LOOKUP_FAILED: $e');
    order = null;
  }

  if (!context.mounted) return;
  if (order == null) {
    showNotificationDetailsDialog(
      context,
      notification,
      accentColor: _accentForRole(currentRole),
      unavailableNote: 'The related order is no longer available.',
    );
    return;
  }

  switch (currentRole) {
    case UserRole.customer:
      openCustomerOrderDetail(context, ref, order);
      break;
    case UserRole.professional:
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ProfessionalOrderDetailScreen(order: order!)));
      break;
    case UserRole.contractor:
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ContractorOrderDetailScreen(order: order!)));
      break;
    case UserRole.admin:
      break;
  }
}

// Looks the order up in the already-loaded stream first (matches the
// pattern every role screen already used); only falls back to a one-shot
// wait on the stream's first value if it hasn't loaded yet.
Future<OrderModel?> _resolveOrder(
  WidgetRef ref,
  StreamProvider<List<OrderModel>> provider,
  String orderId,
) async {
  final loaded = ref.read(provider).valueOrNull;
  if (loaded != null) {
    return loaded
        .cast<OrderModel?>()
        .firstWhere((o) => o?.id == orderId, orElse: () => null);
  }
  final fetched = await ref.read(provider.future).timeout(
      const Duration(seconds: 8),
      onTimeout: () => const <OrderModel>[]);
  return fetched
      .cast<OrderModel?>()
      .firstWhere((o) => o?.id == orderId, orElse: () => null);
}

// ─── Chat ─────────────────────────────────────────────────────────────────
Future<void> _routeChat(BuildContext context, WidgetRef ref,
    NotificationModel notification, UserRole currentRole) async {
  final convId = notification.relatedConversationId;
  final me = ref.read(authProvider);
  if (convId == null || convId.isEmpty || me == null) {
    showNotificationDetailsDialog(context, notification,
        accentColor: _accentForRole(currentRole));
    return;
  }

  ConversationModel? conversation;
  try {
    conversation = await ref
        .read(conversationByIdProvider(convId).future)
        .timeout(const Duration(seconds: 8), onTimeout: () => null);
  } catch (e) {
    debugPrint('NOTIFICATION_CONVERSATION_LOOKUP_FAILED: $e');
    conversation = null;
  }
  if (!context.mounted) return;

  final otherUserId = conversation?.participantIds
      .firstWhere((id) => id != me.id, orElse: () => '');
  if (conversation == null || otherUserId == null || otherUserId.isEmpty) {
    showNotificationDetailsDialog(context, notification,
        accentColor: _accentForRole(currentRole));
    return;
  }

  UserModel? otherUser;
  try {
    otherUser = await ref
        .read(userByIdProvider(otherUserId).future)
        .timeout(const Duration(seconds: 8), onTimeout: () => null);
  } catch (e) {
    debugPrint('NOTIFICATION_CHAT_USER_LOOKUP_FAILED: $e');
    otherUser = null;
  }
  if (!context.mounted) return;
  if (otherUser == null) {
    showNotificationDetailsDialog(context, notification,
        accentColor: _accentForRole(currentRole));
    return;
  }

  switch (currentRole) {
    case UserRole.customer:
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => CustomerChatScreen(otherUser: otherUser!)));
      break;
    case UserRole.professional:
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ProfessionalChatScreen(otherUser: otherUser!)));
      break;
    case UserRole.contractor:
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ContractorChatScreen(otherUser: otherUser!)));
      break;
    case UserRole.admin:
      break;
  }
}

// ─── Reviews ──────────────────────────────────────────────────────────────
Future<void> _routeReview(BuildContext context, WidgetRef ref,
    NotificationModel notification, UserRole currentRole) async {
  final reviewId = notification.relatedReviewId;
  if (reviewId == null || reviewId.isEmpty) {
    showNotificationDetailsDialog(context, notification,
        accentColor: _accentForRole(currentRole));
    return;
  }

  ReviewModel? review;
  try {
    review = await ref
        .read(reviewByIdProvider(reviewId).future)
        .timeout(const Duration(seconds: 8), onTimeout: () => null);
  } catch (e) {
    debugPrint('NOTIFICATION_REVIEW_LOOKUP_FAILED: $e');
    review = null;
  }
  if (!context.mounted) return;

  if (review == null) {
    showNotificationDetailsDialog(
      context,
      notification,
      accentColor: _accentForRole(currentRole),
      unavailableNote: 'The related review is no longer available.',
    );
    return;
  }

  showReviewDetailsDialog(context, review,
      accentColor: _accentForRole(currentRole));
}

// ─── Complaints ───────────────────────────────────────────────────────────
Future<void> _routeComplaint(BuildContext context, WidgetRef ref,
    NotificationModel notification, UserRole currentRole) async {
  final complaintId = notification.relatedComplaintId;
  if (complaintId == null || complaintId.isEmpty) {
    showNotificationDetailsDialog(context, notification,
        accentColor: _accentForRole(currentRole));
    return;
  }

  final me = ref.read(authProvider);
  ComplaintModel? complaint;
  if (me != null) {
    final loaded = ref.read(userComplaintsProvider(me.id)).valueOrNull;
    complaint = (loaded ?? const <ComplaintModel>[])
        .cast<ComplaintModel?>()
        .firstWhere((c) => c?.id == complaintId, orElse: () => null);
    if (complaint == null) {
      try {
        final fetched = await ref
            .read(userComplaintsProvider(me.id).future)
            .timeout(const Duration(seconds: 8),
                onTimeout: () => const <ComplaintModel>[]);
        complaint = fetched
            .cast<ComplaintModel?>()
            .firstWhere((c) => c?.id == complaintId, orElse: () => null);
      } catch (e) {
        debugPrint('NOTIFICATION_COMPLAINT_LOOKUP_FAILED: $e');
      }
    }
  }
  if (!context.mounted) return;

  if (complaint == null) {
    showNotificationDetailsDialog(
      context,
      notification,
      accentColor: _accentForRole(currentRole),
      unavailableNote: 'The related complaint is no longer available.',
    );
    return;
  }

  switch (currentRole) {
    case UserRole.customer:
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  CustomerComplaintsScreen(highlightComplaintId: complaintId)));
      break;
    case UserRole.professional:
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ProfessionalComplaintsPage(
                  highlightComplaintId: complaintId)));
      break;
    case UserRole.contractor:
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  ContractorComplaintsPage(highlightComplaintId: complaintId)));
      break;
    case UserRole.admin:
      break;
  }
}

// ─── Category Requests ────────────────────────────────────────────────────
// Newer Category Request Approved/Rejected notifications carry a real
// relatedCategoryRequestId (see createCategoryRequestNotification /
// admin_screens.dart's approve+reject actions), which opens that exact
// request's details dialog. Older notifications without one still just open
// "My Category Requests" — the documented-sufficient fallback — never by
// name-matching the notification message/title.
void _routeCategoryRequest(
    BuildContext context, UserRole currentRole, String? categoryRequestId) {
  switch (currentRole) {
    case UserRole.customer:
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => CustomerCategoryRequestsScreen(
                  initialRequestId: categoryRequestId)));
      break;
    case UserRole.professional:
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => CategoryRequestsScreen(
                    gradientStart: AppGreen.darkest,
                    gradientEnd: AppGreen.dark,
                    secondaryColor: AppGreen.mid,
                    scaffoldBackgroundColor: const Color(0xFFEEEEF5),
                    initialRequestId: categoryRequestId,
                  )));
      break;
    case UserRole.contractor:
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => CategoryRequestsScreen(
                    gradientStart: const Color(0xFF3E2522),
                    gradientEnd: const Color(0xFF8C6E63),
                    secondaryColor: const Color(0xFFD3A376),
                    scaffoldBackgroundColor: const Color(0xFFEEEEF5),
                    initialRequestId: categoryRequestId,
                  )));
      break;
    case UserRole.admin:
      break;
  }
}
