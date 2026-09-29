// Shared Profile Photo action sheet — reused by Customer, Professional and
// Contractor profile screens' camera button so the choose/change/remove
// flow, validation and Firebase Storage/Firestore wiring exist in exactly
// one place (see uploadProfilePhoto/removeProfilePhoto in app_providers.dart
// for the actual write flow; this file only owns the picker + menu UX).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/presentation/providers/app_providers.dart';

const _kMaxProfilePhotoBytes = 5 * 1024 * 1024; // 5MB
const _kSupportedProfilePhotoExts = ['.jpg', '.jpeg', '.png', '.webp'];

void _showSnack(BuildContext context, String message, {bool isError = false}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
    behavior: SnackBarBehavior.fixed,
  ));
}

// Single entry point reused by all three role profile screens' camera
// button. Shows "Choose Profile Photo" when the user has none yet, or
// "Change" / "Remove" when one is already saved. Callers are expected to
// wrap this call with their own duplicate-tap guard (a bool flag flipped
// true before calling this and reset to false once it returns) so the
// camera button's own spinner covers the whole flow.
Future<void> showProfilePhotoActionSheet({
  required BuildContext context,
  required WidgetRef ref,
  required UserModel user,
  required Color accent,
}) async {
  final hasPhoto = user.avatar?.isNotEmpty ?? false;
  final action = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _ProfilePhotoMenuSheet(hasPhoto: hasPhoto, accent: accent),
  );
  if (action == null || !context.mounted) return;

  if (action == 'camera' || action == 'gallery') {
    await _pickAndUpload(
      context: context,
      user: user,
      source: action == 'camera' ? ImageSource.camera : ImageSource.gallery,
    );
  } else if (action == 'remove') {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Profile Photo?',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        content: const Text(
            'Your profile will show your name\'s initial instead. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel',
                style:
                    TextStyle(color: Colors.grey, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await removeProfilePhoto(uid: user.id, currentAvatarUrl: user.avatar);
      _showSnack(context, 'Profile photo removed');
    } catch (_) {
      _showSnack(context, 'Failed to remove photo. Please try again.',
          isError: true);
    }
  }
}

// [source] is whichever tile the user tapped in the sheet — camera or
// gallery. Everything after the pick (extension/size validation, upload,
// Firestore write, messaging) is deliberately shared between the two, so a
// captured photo goes through exactly the same pipeline as a chosen one.
Future<void> _pickAndUpload({
  required BuildContext context,
  required UserModel user,
  required ImageSource source,
}) async {
  XFile? picked;
  try {
    picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
  } catch (e) {
    // Covers a denied camera/photos permission and "no camera available" —
    // both surface as a PlatformException from pickImage.
    debugPrint('PROFILE_PHOTO_PICK_ERROR source=$source error=$e');
    _showSnack(
        context,
        source == ImageSource.camera
            ? 'Could not open the camera. Check permissions.'
            : 'Could not access media. Check permissions.',
        isError: true);
    return;
  }
  if (picked == null) return; // user cancelled the picker — no-op, no error

  final bytes = await picked.readAsBytes();
  final lowerName = picked.name.toLowerCase();
  final hasSupportedExt =
      _kSupportedProfilePhotoExts.any((ext) => lowerName.endsWith(ext));
  if (!hasSupportedExt) {
    _showSnack(context, 'Unsupported image type. Use JPG, PNG or WEBP.',
        isError: true);
    return;
  }
  if (bytes.isEmpty) {
    _showSnack(context, 'Could not read the selected image.', isError: true);
    return;
  }
  if (bytes.length > _kMaxProfilePhotoBytes) {
    _showSnack(context, 'Image is too large. Please choose a photo under 5MB.',
        isError: true);
    return;
  }

  if (!context.mounted) return;
  try {
    await uploadProfilePhoto(
      uid: user.id,
      bytes: bytes,
      fileName: picked.name,
      previousAvatarUrl: user.avatar,
    );
    _showSnack(context, 'Profile photo updated');
  } catch (_) {
    _showSnack(context, 'Failed to update photo. Please try again.',
        isError: true);
  }
}

class _ProfilePhotoMenuSheet extends StatelessWidget {
  final bool hasPhoto;
  final Color accent;
  const _ProfilePhotoMenuSheet({required this.hasPhoto, required this.accent});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, -6)),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 18),
          Text('Profile Photo',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: accent)),
          const SizedBox(height: 14),
          _MenuTile(
            icon: Icons.camera_alt_rounded,
            label: 'Take a Photo',
            color: accent,
            onTap: () => Navigator.pop(context, 'camera'),
          ),
          const SizedBox(height: 10),
          _MenuTile(
            icon: Icons.photo_library_rounded,
            label: hasPhoto ? 'Change Profile Photo' : 'Choose Profile Photo',
            color: accent,
            onTap: () => Navigator.pop(context, 'gallery'),
          ),
          if (hasPhoto) ...[
            const SizedBox(height: 10),
            _MenuTile(
              icon: Icons.delete_outline_rounded,
              label: 'Remove Profile Photo',
              color: Colors.red.shade600,
              onTap: () => Navigator.pop(context, 'remove'),
            ),
          ],
        ]),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MenuTile(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        ]),
      ),
    );
  }
}
