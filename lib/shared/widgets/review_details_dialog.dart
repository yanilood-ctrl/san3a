import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../../features/auth/presentation/providers/app_providers.dart';

// ── Review Details Dialog ───────────────────────────────────────────────────
// Read-only, centered detail view for a single review, opened from a
// notification tap (relatedReviewId). Deliberately has no moderation/edit
// actions — those stay Admin-only in their existing screens.
void showReviewDetailsDialog(
  BuildContext context,
  ReviewModel review, {
  Color accentColor = const Color(0xFF052659),
}) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.45),
    builder: (ctx) =>
        _ReviewDetailsDialog(review: review, accentColor: accentColor),
  );
}

String _twoDigits(int n) => n.toString().padLeft(2, '0');

String _reviewTimeLabel(DateTime dt) {
  return '${dt.day}/${dt.month}/${dt.year} • ${_twoDigits(dt.hour)}:${_twoDigits(dt.minute)}';
}

class _ReviewDetailsDialog extends ConsumerWidget {
  final ReviewModel review;
  final Color accentColor;
  const _ReviewDetailsDialog({required this.review, required this.accentColor});

  Widget _stars(double rating, {double size = 18}) {
    final full = rating.round().clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < full ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: const Color(0xFFFFB800),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = review;
    final darkColor = Color.lerp(accentColor, Colors.black, 0.35)!;
    final criteria = ref.watch(reviewCriteriaProvider);
    final isHidden = r.isHidden || r.status == 'hidden';

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
                  child: const Icon(Icons.star_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Review Details',
                    style: TextStyle(
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
                    Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.customerName.isNotEmpty
                                  ? r.customerName
                                  : 'Customer',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              r.providerName.isNotEmpty
                                  ? 'for ${r.providerName}'
                                  : '',
                              style: const TextStyle(
                                  fontSize: 12.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _stars(r.overallRating, size: 20),
                          const SizedBox(height: 2),
                          Text(r.overallRating.toStringAsFixed(1),
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFFFB800))),
                        ],
                      ),
                    ]),
                    const SizedBox(height: 16),
                    if (r.criteriaRatings.isNotEmpty)
                      ...r.criteriaRatings.entries.map((e) {
                        final match =
                            criteria.where((c) => c.id == e.key).toList();
                        final label =
                            match.isNotEmpty ? match.first.name : e.key;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(children: [
                            Expanded(
                              child: Text(label,
                                  style: const TextStyle(
                                      fontSize: 13, color: Color(0xFF334155))),
                            ),
                            _stars(e.value, size: 15),
                          ]),
                        );
                      })
                    else ...[
                      _criteriaRow('Speed', r.speedRating),
                      _criteriaRow('Quality', r.qualityRating),
                      _criteriaRow('Communication', r.communicationRating),
                    ],
                    const SizedBox(height: 12),
                    if (r.comment.trim().isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          r.comment,
                          style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.45,
                              color: Color(0xFF334155)),
                        ),
                      ),
                    const SizedBox(height: 14),
                    Row(children: [
                      Icon(Icons.schedule_rounded,
                          size: 16, color: accentColor.withOpacity(0.8)),
                      const SizedBox(width: 6),
                      Text(_reviewTimeLabel(r.createdAt),
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: accentColor.withOpacity(0.8))),
                    ]),
                    if (isHidden) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: const Row(children: [
                          Icon(Icons.visibility_off_rounded,
                              size: 18, color: Color(0xFF991B1B)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text('This review is currently hidden.',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF991B1B))),
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

  Widget _criteriaRow(String label, double value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
          ),
          _stars(value, size: 15),
        ]),
      );
}
