import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';

/// Builds a Google Calendar "add event" URL from an [OrderModel] and
/// opens it with [url_launcher].
///
/// Falls back to a SnackBar error if the URL cannot be launched.
Future<void> addOrderToGoogleCalendar(
    BuildContext context,
    OrderModel order,
    ) async {
  final d = order.serviceDate;

  // ── Format dates to Google Calendar's YYYYMMDDTHHmmssZ format ──────────
  String pad(int n) => n.toString().padLeft(2, '0');

  // Start: serviceDate rounded to its hour/minute
  final startDt =
      '${d.year}${pad(d.month)}${pad(d.day)}T${pad(d.hour)}${pad(d.minute)}00';

  // End: start + 1 hour  (Google Calendar default window)
  final endDate = d.add(const Duration(hours: 1));
  final endDt =
      '${endDate.year}${pad(endDate.month)}${pad(endDate.day)}T${pad(endDate.hour)}${pad(endDate.minute)}00';

  // ── Build description string ────────────────────────────────────────────
  final descParts = <String>[
    if (order.description.isNotEmpty) order.description,
    if (order.customerName.isNotEmpty) 'Customer: ${order.customerName}',
    if (order.serviceType != null) 'Service: ${order.serviceType}',
    if (order.selectedServiceName != null)
      'Service type: ${order.selectedServiceName}',
    if (order.selectedServicePrice != null)
      'Budget: ₪${order.selectedServicePrice!.toStringAsFixed(0)}',
  ];

  final title = Uri.encodeComponent(order.title);
  final description = Uri.encodeComponent(descParts.join('\n'));
  final location = Uri.encodeComponent(order.area);
  final dates = Uri.encodeComponent('$startDt/$endDt');

  final url =
      'https://calendar.google.com/calendar/render?action=TEMPLATE'
      '&text=$title'
      '&dates=$dates'
      '&details=$description'
      '&location=$location';

  final uri = Uri.parse(url);

  try {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      _showError(context, 'Could not open Google Calendar.');
    }
  } catch (e) {
    if (context.mounted) {
      _showError(context, 'Could not open Google Calendar: $e');
    }
  }
}

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ]),
      backgroundColor: const Color(0xFFB71C1C),
      behavior: SnackBarBehavior.fixed,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ),
  );
}
