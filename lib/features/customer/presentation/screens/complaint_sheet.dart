import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/presentation/providers/app_providers.dart';
import '../../../../shared/models/models.dart';
import '../theme/customer_design.dart';

void showComplaintSheet(
  BuildContext context, {
  required ComplaintType type,
  required String targetId,
  required String targetName,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _ComplaintSheet(type: type, targetId: targetId, targetName: targetName),
  );
}

class _ComplaintSheet extends ConsumerStatefulWidget {
  final ComplaintType type;
  final String targetId;
  final String targetName;
  const _ComplaintSheet({required this.type, required this.targetId, required this.targetName});

  @override
  ConsumerState<_ComplaintSheet> createState() => _ComplaintSheetState();
}

class _ComplaintSheetState extends ConsumerState<_ComplaintSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  String? _selectedReason;
  bool _loading = false;

  List<String> _getReasons(AppLocalizations l) => [l.get('reason_bad_conduct'), l.get('reason_delay'), l.get('reason_bad_work'), l.get('reason_fraud'), l.get('reason_incomplete'), l.get('reason_other')];

  @override
  void dispose() { _descCtrl.dispose(); super.dispose(); }

  String _typeLabel() {
    switch (widget.type) {
      case ComplaintType.order: return 'Order';
      case ComplaintType.provider: return 'Service Provider';
      case ComplaintType.category: return 'Category';
      default: return 'General';
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).get('select_reason_error')),
          backgroundColor: CustomerColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CustomerRadii.sm)),
        ),
      );
      return;
    }
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    final user = ref.read(authProvider);
    final complaint = ComplaintModel(
      id: 'cmp_${DateTime.now().millisecondsSinceEpoch}',
      userId: user?.id ?? 'current_user',
      userName: user?.fullName ?? 'User',
      type: widget.type,
      targetId: widget.targetId,
      targetName: widget.targetName,
      reason: _selectedReason!,
      description: _descCtrl.text,
      createdAt: DateTime.now(),
    );
    ref.read(complaintsProvider.notifier).addComplaint(complaint);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:  Row(children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text(AppLocalizations.of(context).get('complaint_sent')),
          ]),
          backgroundColor: CustomerColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CustomerRadii.sm)),
        ),
      );
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 12, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: CustomerColors.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Row(children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: CustomerColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(CustomerRadii.sm)),
              child: const Icon(Icons.flag_rounded, color: CustomerColors.error, size: 20)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(AppLocalizations.of(context).get('complaint_send'), style: CustomerText.title.copyWith(fontSize: 18, fontWeight: FontWeight.w800)),
              Text('${_typeLabel()}: ${widget.targetName}', style: CustomerText.secondary),
            ]),
          ]),
          const SizedBox(height: 20),
          Text(AppLocalizations.of(context).get('complaint_reason'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextPrimary : CustomerColors.textPrimary)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: _getReasons(AppLocalizations.of(context)).map((r) {
            final sel = _selectedReason == r;
            return GestureDetector(
              onTap: () => setState(() => _selectedReason = r),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? CustomerColors.error : (isDark ? AppColors.darkSurface : CustomerColors.lightBlueSection),
                  borderRadius: BorderRadius.circular(CustomerRadii.pill),
                  border: Border.all(color: sel ? CustomerColors.error : (isDark ? AppColors.darkBorder : Colors.transparent)),
                ),
                child: Text(r, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: sel ? Colors.white : (isDark ? AppColors.darkTextSecondary : CustomerColors.primaryDark))),
              ),
            );
          }).toList()),
          const SizedBox(height: 18),
          Text(AppLocalizations.of(context).get('complaint_details'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextPrimary : CustomerColors.textPrimary)),
          const SizedBox(height: 10),
          TextFormField(
            controller: _descCtrl,
            maxLines: 3,
            decoration: customerInputDecoration(hint: AppLocalizations.of(context).get('complaint_hint')),
            validator: (v) => (v == null || v.trim().isEmpty) ? AppLocalizations.of(context).get('complaint_required') : null,
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: CustomerColors.error,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CustomerRadii.md)),
                textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
              ),
              child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.send_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Submit Complaint'),
                    ]),
            ),
          ),
        ]),
      ),
    );
  }
}
