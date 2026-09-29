// ─── Image Source Picker ─────────────────────────────────────────────────────
// Single shared "Camera or Gallery?" affordance for every flow in San3a that
// lets the user attach a photo (chat attachments, profile photo, order photos
// on creation and afterwards). Before this existed each flow hardcoded
// ImageSource.gallery — the chat attach sheet even had a Camera tile that only
// showed a "will be connected in a later phase" snack — so taking a new
// picture was impossible anywhere in the app on a real device.
//
// This file owns only the *choice* and the ImagePicker call. It deliberately
// does not upload, resize beyond what the caller asks for, or touch
// Firestore/Storage: each call site keeps its own existing upload/validation
// pipeline exactly as it was.
//
// Android permissions: image_picker launches the system camera app through
// MediaStore.ACTION_IMAGE_CAPTURE and writes into its own FileProvider
// (declared by image_picker_android's manifest, merged automatically). No
// android.permission.CAMERA is needed — and it must NOT be declared, because
// Android only demands the runtime CAMERA grant from apps that declare it,
// which would turn a working capture into a SecurityException until the user
// accepts a permission the app doesn't otherwise use.
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Shows the Camera / Gallery chooser and returns the user's pick, or null if
/// they dismissed the sheet.
Future<ImageSource?> showImageSourceSheet({
  required BuildContext context,
  required Color accent,
  String title = 'Add a Photo',
  String cameraLabel = 'Take a Photo',
  String galleryLabel = 'Choose from Gallery',
}) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _ImageSourceSheet(
      accent: accent,
      title: title,
      cameraLabel: cameraLabel,
      galleryLabel: galleryLabel,
    ),
  );
}

/// Asks for a source, then picks the image. Returns null when the user
/// dismissed the chooser, cancelled the camera/gallery, or when the platform
/// refused access (a denied camera/photos permission surfaces here as a
/// PlatformException, which is reported through [onError] rather than thrown,
/// so no call site has to special-case it).
///
/// [imageQuality]/[maxWidth]/[maxHeight] are forwarded untouched so each call
/// site keeps the compression it already used.
Future<XFile?> pickImageWithSourceChoice({
  required BuildContext context,
  required Color accent,
  int? imageQuality,
  double? maxWidth,
  double? maxHeight,
  String title = 'Add a Photo',
  void Function(Object error)? onError,
}) async {
  final source = await showImageSourceSheet(
      context: context, accent: accent, title: title);
  if (source == null) return null;
  return pickImageFromSource(
    source: source,
    imageQuality: imageQuality,
    maxWidth: maxWidth,
    maxHeight: maxHeight,
    onError: onError,
  );
}

/// Picks from an already-chosen [source]. Returns null on cancellation or on a
/// platform failure (permission denied, no camera available, …), reporting the
/// failure through [onError] so callers can show their own message in their own
/// style instead of the picker throwing into their UI code.
Future<XFile?> pickImageFromSource({
  required ImageSource source,
  int? imageQuality,
  double? maxWidth,
  double? maxHeight,
  void Function(Object error)? onError,
}) async {
  try {
    return await ImagePicker().pickImage(
      source: source,
      imageQuality: imageQuality,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
  } catch (e) {
    debugPrint('IMAGE_PICK_ERROR source=$source error=$e');
    onError?.call(e);
    return null;
  }
}

class _ImageSourceSheet extends StatelessWidget {
  final Color accent;
  final String title;
  final String cameraLabel;
  final String galleryLabel;
  const _ImageSourceSheet({
    required this.accent,
    required this.title,
    required this.cameraLabel,
    required this.galleryLabel,
  });

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
          Text(title,
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: accent)),
          const SizedBox(height: 14),
          _SourceTile(
            icon: Icons.camera_alt_rounded,
            label: cameraLabel,
            color: accent,
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          const SizedBox(height: 10),
          _SourceTile(
            icon: Icons.photo_library_rounded,
            label: galleryLabel,
            color: accent,
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ]),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SourceTile(
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
          // Flexible so a long label wraps instead of overflowing the tile on
          // narrow phones.
          Flexible(
            child: Text(label,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          ),
        ]),
      ),
    );
  }
}
