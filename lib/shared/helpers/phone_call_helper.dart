import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Normalizes a displayed phone number into a dialable number for a `tel:`
/// URI: strips spaces, parentheses and hyphens while preserving a leading
/// "+" for international numbers. Returns null when there is nothing
/// dialable (empty, the "—" placeholder, or no digits at all).
String? normalizedTelNumber(String? phone) {
  if (phone == null) return null;
  final trimmed = phone.trim();
  if (trimmed.isEmpty || trimmed == '—') return null;
  final hasPlus = trimmed.startsWith('+');
  final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  return hasPlus ? '+$digits' : digits;
}

/// Opens the device dialer (never places the call automatically) with a
/// `tel:` URI built from [phone]. Safe to call even if [phone] turns out to
/// be unusable — shows a SnackBar and returns quietly instead of throwing.
Future<void> launchPhoneCall(BuildContext context, String? phone) async {
  final number = normalizedTelNumber(phone);
  if (number == null) return;
  final uri = Uri(scheme: 'tel', path: number);
  try {
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      _showCallUnavailable(context);
    }
  } catch (_) {
    if (context.mounted) _showCallUnavailable(context);
  }
}

void _showCallUnavailable(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
    content: Text('Calling is not supported on this device.'),
    behavior: SnackBarBehavior.floating,
  ));
}
