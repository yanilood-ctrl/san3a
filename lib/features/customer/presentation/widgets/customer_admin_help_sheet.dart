// ─────────────────────────────────────────────────────────────────────────────
// Customer Admin Help Sheet — Customer-owned copy of the shared
// showAdminChatRequestSheet / _AdminChatRequestSheet (lib/features/customer/
// presentation/screens/customer_messages_screen.dart), restyled to the
// Customer UI Kit / Order-Complaint visual language. The shared original is
// also used by Professional and Contractor chat screens (kept byte-for-byte
// untouched here); this copy exists so the Customer chat redesign never
// changes what those other roles see. Same request-document creation path
// (createChatReportInFirestore, same param mapping), same issue types,
// labels and enable/disable rule, same optional-details behavior — visuals
// only differ.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/app_providers.dart';
import '../../../../shared/models/models.dart';
import '../theme/customer_design.dart';

void showCustomerAdminChatRequestSheet(
  BuildContext context,
  ConversationModel conv,
  WidgetRef ref, {
  String? reportedUserRole,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: CustomerColors.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(CustomerRadii.sheet)),
    ),
    builder: (_) => _CustomerAdminChatRequestSheet(
      conv: conv,
      ref: ref,
      reportedUserRole: reportedUserRole,
    ),
  );
}

class _AdminHelpRequestType {
  final IconData icon;
  final String label;
  final Color color;
  const _AdminHelpRequestType(
      {required this.icon, required this.label, required this.color});
}

class _CustomerAdminChatRequestSheet extends StatefulWidget {
  final ConversationModel conv;
  final WidgetRef ref;
  final String? reportedUserRole;
  const _CustomerAdminChatRequestSheet(
      {required this.conv, required this.ref, this.reportedUserRole});

  @override
  State<_CustomerAdminChatRequestSheet> createState() =>
      _CustomerAdminChatRequestSheetState();
}

class _CustomerAdminChatRequestSheetState
    extends State<_CustomerAdminChatRequestSheet> {
  int _selectedType = -1;
  final _descCtrl = TextEditingController();

  // Same 4 options, same labels/values as the shared sheet — only the
  // accent colors are aligned to Customer design tokens.
  final _types = const [
    _AdminHelpRequestType(
        icon: Icons.edit_outlined,
        label: 'Edit a Message',
        color: CustomerColors.primaryDark),
    _AdminHelpRequestType(
        icon: Icons.delete_outline,
        label: 'Delete a Message',
        color: CustomerColors.error),
    _AdminHelpRequestType(
        icon: Icons.report_gmailerrorred_outlined,
        label: 'Inappropriate Messages',
        color: CustomerColors.warning),
    _AdminHelpRequestType(
        icon: Icons.help_outline_rounded,
        label: 'Other Issue',
        color: Color(0xFF7B2FBE)),
  ];

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: CustomerColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF7B2FBE).withOpacity(0.1),
                borderRadius: BorderRadius.circular(CustomerRadii.sm),
              ),
              child: const Icon(Icons.support_agent_rounded,
                  color: Color(0xFF7B2FBE), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Request Admin Help',
                      style: CustomerText.title
                          .copyWith(fontSize: 18, fontWeight: FontWeight.w800)),
                  Text('Regarding: ${widget.conv.otherUserName}',
                      style: CustomerText.secondary),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 20),

          // Section label
          const Text('What do you need help with?',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: CustomerColors.textPrimary)),
          const SizedBox(height: 10),

          // Reason cards — same 4 options/order/values as the shared sheet
          ..._types.asMap().entries.map((e) {
            final sel = _selectedType == e.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => setState(() => _selectedType = e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: sel
                        ? e.value.color.withOpacity(0.08)
                        : CustomerColors.background,
                    borderRadius: BorderRadius.circular(CustomerRadii.md),
                    border: Border.all(
                      color: sel ? e.value.color : CustomerColors.border,
                      width: sel ? 1.5 : 1,
                    ),
                  ),
                  child: Row(children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                          color: e.value.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(e.value.icon, color: e.value.color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(e.value.label,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: sel
                                  ? e.value.color
                                  : CustomerColors.textPrimary)),
                    ),
                    if (sel)
                      Icon(Icons.check_circle_rounded,
                          color: e.value.color, size: 18),
                  ]),
                ),
              ),
            );
          }),
          const SizedBox(height: 10),

          // Description field — same optional-details behavior
          const Text('Details (optional)',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: CustomerColors.textPrimary)),
          const SizedBox(height: 10),
          TextField(
            controller: _descCtrl,
            maxLines: 3,
            minLines: 2,
            decoration: customerInputDecoration(
                hint: 'Describe the issue (optional)...'),
          ),
          const SizedBox(height: 22),

          // Buttons — same enable/disable rule and submit path
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: CustomerColors.textPrimary,
                  side: const BorderSide(color: CustomerColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(CustomerRadii.md)),
                ),
                child: const Text('Cancel',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _selectedType < 0
                    ? null
                    : () async {
                        final currentUser = widget.ref.read(authProvider);
                        if (currentUser == null) return;
                        final issueLabel = _types[_selectedType].label;
                        final desc = _descCtrl.text.trim();
                        final conversationId = getConversationId(
                            currentUser.id, widget.conv.otherUserId);
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(context);
                        try {
                          await createChatReportInFirestore(
                            conversationId: conversationId,
                            reporterId: currentUser.id,
                            reporterName: currentUser.fullName,
                            reporterRole: currentUser.role.name,
                            reportedUserId: widget.conv.otherUserId,
                            reportedUserName: widget.conv.otherUserName,
                            reportedUserRole: widget.reportedUserRole,
                            reason: issueLabel,
                            description: desc.isEmpty ? null : desc,
                          );
                          messenger.showSnackBar(SnackBar(
                            content: const Text(
                                'Your request was sent to the admin.'),
                            backgroundColor: const Color(0xFF7B2FBE),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(CustomerRadii.sm)),
                          ));
                        } catch (e) {
                          messenger.showSnackBar(SnackBar(
                            content: const Text(
                                'Failed to send request. Please try again.'),
                            backgroundColor: CustomerColors.error,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(CustomerRadii.sm)),
                          ));
                        }
                      },
                icon: const Icon(Icons.send_rounded, size: 16),
                label: const Text('Send Request',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedType >= 0
                      ? const Color(0xFF7B2FBE)
                      : CustomerColors.border,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(CustomerRadii.md)),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
