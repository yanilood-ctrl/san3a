import 'package:flutter/material.dart';
import '../models/models.dart';

// ── Category Request Details Dialog ─────────────────────────────────────────
// Read-only, centered detail view for a single category request. Shared by
// the manual "tap a request card" flow (CategoryRequestsScreen) and the
// notification-tap auto-open flow, so there is a single request-details
// design instead of one per role. Edit/Delete stay on the existing "⋮" menu
// (Pending-only), unaffected by this dialog.
const Map<String, Color> _categoryRequestStatusColors = {
  'pending': Color(0xFFF59E0B),
  'approved': Color(0xFF10B981),
  'rejected': Color(0xFFEF4444),
};
const Map<String, String> _categoryRequestStatusLabels = {
  'pending': 'Pending',
  'approved': 'Approved',
  'rejected': 'Rejected',
};

String _twoDigits(int n) => n.toString().padLeft(2, '0');

String _categoryRequestDateLabel(DateTime dt) =>
    '${dt.day}/${dt.month}/${dt.year} • ${_twoDigits(dt.hour)}:${_twoDigits(dt.minute)}';

void showCategoryRequestDetailsDialog(
  BuildContext context,
  CategoryRequestModel request, {
  Color accentColor = const Color(0xFF052659),
}) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.45),
    builder: (ctx) => _CategoryRequestDetailsDialog(
      request: request,
      accentColor: accentColor,
    ),
  );
}

class _CategoryRequestDetailsDialog extends StatelessWidget {
  final CategoryRequestModel request;
  final Color accentColor;
  const _CategoryRequestDetailsDialog(
      {required this.request, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final r = request;
    final statusColor = _categoryRequestStatusColors[r.status] ?? accentColor;
    final statusLabel = _categoryRequestStatusLabels[r.status] ?? r.status;
    final darkColor = Color.lerp(accentColor, Colors.black, 0.35)!;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 620),
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
                  child: const Icon(Icons.category_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    r.requestedName.isNotEmpty
                        ? r.requestedName
                        : 'Category Request',
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withOpacity(0.4)),
                      ),
                      child: Text(statusLabel,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: statusColor)),
                    ),
                    if (r.requestedDescription.trim().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          r.requestedDescription,
                          style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.45,
                              color: Color(0xFF334155)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(children: [
                      Icon(Icons.schedule_rounded,
                          size: 16, color: accentColor.withOpacity(0.8)),
                      const SizedBox(width: 6),
                      Text(_categoryRequestDateLabel(r.createdAt),
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: accentColor.withOpacity(0.8))),
                    ]),
                    if (r.reviewedAt != null) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        Icon(Icons.fact_check_rounded,
                            size: 16, color: accentColor.withOpacity(0.8)),
                        const SizedBox(width: 6),
                        Text(
                            'Reviewed ${_categoryRequestDateLabel(r.reviewedAt!)}',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: accentColor.withOpacity(0.8))),
                      ]),
                    ],
                    if (r.adminNote != null &&
                        r.adminNote!.trim().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: const Color(0xFF0EA5E9).withOpacity(0.3)),
                        ),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.sticky_note_2_outlined,
                                  size: 16, color: Color(0xFF0EA5E9)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(r.adminNote!,
                                    style: const TextStyle(
                                        fontSize: 12.5,
                                        color: Color(0xFF334155),
                                        height: 1.4)),
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
