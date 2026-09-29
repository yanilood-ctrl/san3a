import 'package:flutter/material.dart';
import '../models/models.dart';

// ── Notification Details Dialog ─────────────────────────────────────────────
// Read-only fallback shown when a notification tap has no valid destination
// to deep-link to (informational notifications, or a related item that no
// longer exists). Replaces the generic "No related page available" snackbar
// that used to appear in this situation across all three roles.
IconData notificationTypeIcon(NotificationType type) {
  switch (type) {
    case NotificationType.orderUpdate:
      return Icons.assignment_rounded;
    case NotificationType.chat:
      return Icons.chat_bubble_rounded;
    case NotificationType.complaint:
      return Icons.flag_rounded;
    case NotificationType.review:
      return Icons.star_rounded;
    case NotificationType.broadcast:
      return Icons.campaign_rounded;
    case NotificationType.system:
      return Icons.info_rounded;
    case NotificationType.categoryRequest:
      return Icons.category_rounded;
    case NotificationType.general:
      return Icons.notifications_rounded;
  }
}

String _twoDigits(int n) => n.toString().padLeft(2, '0');

String _detailsTimeLabel(DateTime dt) {
  return '${dt.day}/${dt.month}/${dt.year} • ${_twoDigits(dt.hour)}:${_twoDigits(dt.minute)}';
}

void showNotificationDetailsDialog(
  BuildContext context,
  NotificationModel notification, {
  Color accentColor = const Color(0xFF052659),
  String? unavailableNote,
}) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.45),
    builder: (ctx) => _NotificationDetailsDialog(
      notification: notification,
      accentColor: accentColor,
      unavailableNote: unavailableNote,
    ),
  );
}

class _NotificationDetailsDialog extends StatelessWidget {
  final NotificationModel notification;
  final Color accentColor;
  final String? unavailableNote;
  const _NotificationDetailsDialog({
    required this.notification,
    required this.accentColor,
    this.unavailableNote,
  });

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final darkColor = Color.lerp(accentColor, Colors.black, 0.35)!;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 12)),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [darkColor, accentColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.35)),
                  ),
                  child: Icon(notificationTypeIcon(n.type),
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    n.title.isNotEmpty ? n.title : 'Notification',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
              ]),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.message.isNotEmpty
                          ? n.message
                          : 'No additional details.',
                      style: const TextStyle(
                          fontSize: 14.5,
                          height: 1.45,
                          color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      Icon(Icons.schedule_rounded,
                          size: 16, color: accentColor.withOpacity(0.8)),
                      const SizedBox(width: 6),
                      Text(_detailsTimeLabel(n.createdAt),
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: accentColor.withOpacity(0.8))),
                    ]),
                    if (n.createdByName != null &&
                        n.createdByName!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        Icon(Icons.person_rounded,
                            size: 16, color: accentColor.withOpacity(0.8)),
                        const SizedBox(width: 6),
                        Text('From ${n.createdByName}',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: accentColor.withOpacity(0.8))),
                      ]),
                    ],
                    if (unavailableNote != null &&
                        unavailableNote!.trim().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 18, color: Color(0xFF92400E)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(unavailableNote!,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF92400E))),
                          ),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Text('Close',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14.5)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
