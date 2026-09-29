import 'package:flutter/material.dart';

/// Returns the Flutter [IconData] to render for a service category.
///
/// Looks up by [nameKey] first, falling back to [id], so the same icon is
/// shown everywhere regardless of how the category was created (seeded
/// constant list vs. an admin-approved category request). Categories that
/// aren't in the table fall back to [Icons.category] instead of a
/// misleading default like a wrench/tool icon.
IconData categoryIconFor({String? id, String? nameKey, String? icon}) {
  final key = (nameKey ?? id ?? '').trim().toLowerCase();
  switch (key) {
    case 'ac_technician':
      return Icons.ac_unit;
    case 'electrician':
      return Icons.electrical_services;
    case 'carpenter':
      return Icons.carpenter;
    case 'plumber':
      return Icons.plumbing;
    case 'painter':
      return Icons.format_paint;
    case 'mason':
      return Icons.construction;
    case 'gardener':
      return Icons.grass;
    case 'mechanic':
      return Icons.build;
    case 'welder':
      return Icons.local_fire_department;
    case 'blacksmith':
      return Icons.hardware;
    case 'tailor':
      return Icons.checkroom;
    case 'cleaner':
      return Icons.cleaning_services;
    case 'other_services':
      return Icons.miscellaneous_services;
    case 'car':
      return Icons.directions_car;
    case 'fix_home_keys':
      return Icons.vpn_key;
    case 'test_qa_cleaning':
      return Icons.inventory_2;
    default:
      return Icons.category;
  }
}
