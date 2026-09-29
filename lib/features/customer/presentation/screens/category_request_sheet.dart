import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/localization/app_localizations.dart';
import '../theme/customer_design.dart';
import '../../../auth/presentation/providers/app_providers.dart';
import '../../../../shared/models/models.dart';

// ── Request / Edit Category Request Sheet ─────────────────────────────────────
// Shared by All Categories ("Request a New Category") and My Category
// Requests ("Edit" on a Pending request), so the form UI, validation and
// Firestore submit behavior only exist in one place.
void showCategoryRequestSheet(
  BuildContext context,
  WidgetRef ref, {
  CategoryRequestModel? existing,
}) {
  final l = AppLocalizations.of(context);
  final isEdit = existing != null;
  final nameCtrl = TextEditingController(text: existing?.requestedName ?? '');
  final descCtrl =
      TextEditingController(text: existing?.requestedDescription ?? '');
  final formKey = GlobalKey<FormState>();
  bool isSubmitting = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: StatefulBuilder(
        builder: (ctx, setSheetState) => _RequestCategorySheet(
          l: l,
          isEdit: isEdit,
          loading: isSubmitting,
          nameCtrl: nameCtrl,
          descCtrl: descCtrl,
          formKey: formKey,
          onSubmit: () async {
            if (isSubmitting) return;
            if (!formKey.currentState!.validate()) return;
            setSheetState(() => isSubmitting = true);

            final name = nameCtrl.text.trim();
            final desc = descCtrl.text.trim();

            try {
              if (isEdit) {
                // Update the same document by its stable ID; only the two
                // editable fields are touched — ownership, status, and
                // createdAt are left untouched.
                await updateCategoryRequestInFirestore(
                  requestId: existing.id,
                  requestedName: name,
                  requestedDescription: desc,
                );
              } else {
                final user = ref.read(authProvider);
                final req = CategoryRequestModel(
                  id: '',
                  requesterId: user?.id ?? '',
                  requesterName: (user?.fullName.trim().isNotEmpty ?? false)
                      ? user!.fullName
                      : (user?.email ?? 'Unknown'),
                  requesterRole: user?.role.name ?? 'customer',
                  requestedName: name,
                  requestedDescription: desc,
                  createdAt: DateTime.now(),
                );

                final reqRef = await FirebaseFirestore.instance
                    .collection('category_requests')
                    .add(req.toMap());

                createCategoryRequestNotification(
                  targetRole: 'admin',
                  title: 'New Category Request',
                  message: 'A user requested a new category.',
                  categoryRequestId: reqRef.id,
                );
              }

              // Only clear/close the form once Firestore confirms the write.
              nameCtrl.clear();
              descCtrl.clear();

              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.white),
                      const SizedBox(width: 8),
                      Text(isEdit
                          ? 'Category request updated'
                          : l.get('category_request_sent')),
                    ]),
                    backgroundColor: CustomerColors.dark,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                );
              }
            } catch (e) {
              debugPrint('CATEGORY_REQUEST_SUBMIT_ERROR: $e');
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Row(children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(isEdit
                              ? 'Failed to update your request. Please try again.'
                              : 'Failed to submit your request. Please try again.')),
                    ]),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                );
              }
              setSheetState(() => isSubmitting = false);
            }
          },
        ),
      ),
    ),
  );
}

// ── Request Category Sheet (3D Neomorphism) ───────────────────────────────────
class _RequestCategorySheet extends StatelessWidget {
  final AppLocalizations l;
  final bool isEdit;
  final bool loading;
  final TextEditingController nameCtrl;
  final TextEditingController descCtrl;
  final GlobalKey<FormState> formKey;
  final VoidCallback onSubmit;

  const _RequestCategorySheet({
    required this.l,
    required this.isEdit,
    required this.loading,
    required this.nameCtrl,
    required this.descCtrl,
    required this.formKey,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEF5),
        borderRadius: BorderRadius.circular(32),
        // Neomorphism 3D raised sheet
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFBEBECF),
            blurRadius: 20,
            offset: Offset(8, 8),
          ),
          BoxShadow(
            color: Colors.white,
            blurRadius: 20,
            offset: Offset(-8, -8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Form(
        key: formKey,
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
                        offset: Offset(1, 1)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header row
            Row(children: [
              // Neomorphism icon badge
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEEEEF5),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0xFFBEBECF),
                        blurRadius: 8,
                        offset: Offset(4, 4)),
                    BoxShadow(
                        color: Colors.white,
                        blurRadius: 8,
                        offset: Offset(-4, -4)),
                  ],
                ),
                child: Icon(
                    isEdit ? Icons.edit_rounded : Icons.category_rounded,
                    color: const Color(0xFF5555AA),
                    size: 22),
              ),
              const SizedBox(width: 14),
              Text(
                isEdit
                    ? 'Edit Category Request'
                    : l.get('request_category_title'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF333355),
                ),
              ),
            ]),
            const SizedBox(height: 18),

            // Info banner — neomorphism inset
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEEEEF5),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  // inset shadow for pressed look
                  BoxShadow(
                      color: Color(0xFFBEBECF),
                      blurRadius: 6,
                      offset: Offset(3, 3)),
                  BoxShadow(
                      color: Colors.white,
                      blurRadius: 6,
                      offset: Offset(-3, -3)),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Color(0xFF5555AA), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isEdit
                          ? 'Update your request details below. Only Pending requests can be edited.'
                          : "Can't find the service category you need? Send us a request and the admin will review it.",
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF555577),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Label
            const Text('Category Name',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7777AA))),
            const SizedBox(height: 8),
            // Neo input field
            _NeoTextField(
              controller: nameCtrl,
              hint: 'e.g. Interior Design',
              icon: Icons.category_outlined,
              maxLines: 1,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? l.get('category_name_required')
                  : null,
            ),
            const SizedBox(height: 16),

            const Text('Description (Optional)',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7777AA))),
            const SizedBox(height: 8),
            _NeoTextField(
              controller: descCtrl,
              hint: 'Describe what this category covers...',
              icon: Icons.description_outlined,
              maxLines: 3,
            ),
            const SizedBox(height: 28),

            // Submit button — 3D pressed effect
            _NeoSubmitButton(
              label: isEdit ? 'Save Changes' : l.get('submit_request'),
              loading: loading,
              onTap: onSubmit,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Neo Input Field ───────────────────────────────────────────────────────────
class _NeoTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int maxLines;
  final String? Function(String?)? validator;

  const _NeoTextField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.maxLines,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEF5),
        borderRadius: BorderRadius.circular(16),
        // Inset / pressed neomorphism for input
        boxShadow: const [
          BoxShadow(
              color: Color(0xFFBEBECF), blurRadius: 6, offset: Offset(3, 3)),
          BoxShadow(color: Colors.white, blurRadius: 6, offset: Offset(-3, -3)),
        ],
      ),
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
}

// ── Neo Submit Button ─────────────────────────────────────────────────────────
class _NeoSubmitButton extends StatefulWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  const _NeoSubmitButton(
      {required this.label, required this.loading, required this.onTap});

  @override
  State<_NeoSubmitButton> createState() => _NeoSubmitButtonState();
}

class _NeoSubmitButtonState extends State<_NeoSubmitButton>
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
        if (widget.loading) return;
        setState(() => _pressed = true);
        _ctrl.forward();
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        _ctrl.reverse();
        if (!widget.loading) widget.onTap();
      },
      onTapCancel: () {
        setState(() => _pressed = false);
        _ctrl.reverse();
      },
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => Transform.scale(
          scale: 1.0 - 0.03 * _ctrl.value,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(27),
              gradient: const LinearGradient(
                colors: [Color(0xFF0A1628), Color(0xFF052659)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: _pressed
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.40),
                        blurRadius: 4,
                        offset: const Offset(2, 2),
                      ),
                    ]
                  : [
                      // 3D raised effect
                      BoxShadow(
                        color: Colors.black.withOpacity(0.40),
                        blurRadius: 0,
                        offset: const Offset(0, 5),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.20),
                        blurRadius: 10,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.08),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
            ),
            child: Center(
              child: widget.loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
