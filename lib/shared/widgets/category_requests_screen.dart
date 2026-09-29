import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/providers/app_providers.dart';
import '../models/models.dart';
import '../../features/customer/presentation/screens/category_request_sheet.dart';
import 'category_request_details_dialog.dart';

// ══════════════════════════════════════════════════════════════════════════════
// ── My Category Requests Screen (shared across Customer/Professional/Contractor)
// ══════════════════════════════════════════════════════════════════════════════
// Verbatim port of the manually-verified CustomerCategoryRequestsScreen body,
// parameterized only by color so every role gets the identical tab/card/dots-
// menu behavior over the same `category_requests` collection (filtered by
// requesterId == signed-in user's Firebase Auth UID via
// customerCategoryRequestsProvider, which is already role-agnostic).
class CategoryRequestsScreen extends ConsumerStatefulWidget {
  final Color gradientStart;
  final Color gradientEnd;
  final Color secondaryColor;
  final Color scaffoldBackgroundColor;
  // Set from a notification tap so the matching request's tab is
  // auto-selected and its details dialog opens automatically.
  final String? initialRequestId;
  const CategoryRequestsScreen({
    super.key,
    required this.gradientStart,
    required this.gradientEnd,
    required this.secondaryColor,
    required this.scaffoldBackgroundColor,
    this.initialRequestId,
  });

  @override
  ConsumerState<CategoryRequestsScreen> createState() =>
      _CategoryRequestsScreenState();
}

class _CategoryRequestsScreenState
    extends ConsumerState<CategoryRequestsScreen> {
  int _selectedTab = 0; // 0 = Pending, 1 = Approved, 2 = Rejected
  bool _initialRequestOpened = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final requestsAsync = ref.watch(customerCategoryRequestsProvider);
    final loading =
        requestsAsync.isLoading && requestsAsync.valueOrNull == null;
    final hasError =
        requestsAsync.hasError && requestsAsync.valueOrNull == null;
    final all = requestsAsync.valueOrNull ?? const <CategoryRequestModel>[];

    final pending = all.where((r) => r.status == 'pending').toList();
    final approved = all.where((r) => r.status == 'approved').toList();
    final rejected = all.where((r) => r.status == 'rejected').toList();

    // A notification tap may pass a specific request to open — jump to
    // whichever tab it lives in and auto-open its details dialog once, the
    // first time it shows up in the stream, so the user's own later tab
    // taps and dialog opens/closes aren't overridden.
    if (widget.initialRequestId != null && !_initialRequestOpened) {
      final match = all.where((r) => r.id == widget.initialRequestId).toList();
      if (match.isNotEmpty) {
        _initialRequestOpened = true;
        final matchedRequest = match.first;
        final targetTab = matchedRequest.status == 'approved'
            ? 1
            : matchedRequest.status == 'rejected'
                ? 2
                : 0;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (targetTab != _selectedTab) {
            setState(() => _selectedTab = targetTab);
          }
          showCategoryRequestDetailsDialog(context, matchedRequest,
              accentColor: widget.gradientEnd);
        });
      }
    }

    final list = _selectedTab == 0
        ? pending
        : _selectedTab == 1
            ? approved
            : rejected;

    return Scaffold(
      backgroundColor: widget.scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Header ────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            backgroundColor: widget.gradientEnd,
            foregroundColor: Colors.white,
            elevation: 0,
            automaticallyImplyLeading: false,
            leading: const _CatReqBackButton(),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [widget.gradientStart, widget.gradientEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1),
                            ),
                            child: const Icon(Icons.category_rounded,
                                color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'My Category Requests',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Pill tab selector ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: _CategoryReqStepBar(
                selectedIndex: _selectedTab,
                pendingCount: pending.length,
                approvedCount: approved.length,
                rejectedCount: rejected.length,
                onTap: (i) => setState(() => _selectedTab = i),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── List / states ────────────────────────────────────────────
          if (user == null)
            const SliverFillRemaining(
              child:
                  Center(child: Text('Please sign in to view your requests')),
            )
          else if (loading)
            SliverFillRemaining(
              child: Center(
                  child: CircularProgressIndicator(color: widget.gradientEnd)),
            )
          else if (hasError)
            const SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Failed to load your category requests.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF555577)),
                  ),
                ),
              ),
            )
          else if (list.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEEEEF5),
                        borderRadius: BorderRadius.all(Radius.circular(26)),
                        boxShadow: [
                          BoxShadow(
                              color: Color(0xFFBEBECF),
                              blurRadius: 10,
                              offset: Offset(5, 5)),
                          BoxShadow(
                              color: Colors.white,
                              blurRadius: 10,
                              offset: Offset(-5, -5)),
                        ],
                      ),
                      child: Icon(
                        _selectedTab == 0
                            ? Icons.hourglass_top_rounded
                            : _selectedTab == 1
                                ? Icons.check_circle_outline_rounded
                                : Icons.cancel_outlined,
                        size: 36,
                        color: const Color(0xFF9999BB),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _selectedTab == 0
                          ? 'No pending category requests'
                          : _selectedTab == 1
                              ? 'No approved category requests'
                              : 'No rejected category requests',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF555577)),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _CategoryRequestCard(
                    request: list[i],
                    cancelColor: widget.secondaryColor,
                    accentColor: widget.gradientEnd,
                  ),
                  childCount: list.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// ── Pill-Style Tab Bar (Pending / Approved / Rejected) ────────────────────────
class _CategoryReqStepBar extends StatelessWidget {
  final int selectedIndex;
  final int pendingCount;
  final int approvedCount;
  final int rejectedCount;
  final ValueChanged<int> onTap;
  const _CategoryReqStepBar({
    required this.selectedIndex,
    required this.pendingCount,
    required this.approvedCount,
    required this.rejectedCount,
    required this.onTap,
  });

  static const _tabs = [
    (
      label: 'Pending',
      icon: Icons.hourglass_top_rounded,
      color: Color(0xFFF59E0B)
    ),
    (
      label: 'Approved',
      icon: Icons.check_circle_outline_rounded,
      color: Color(0xFF10B981)
    ),
    (label: 'Rejected', icon: Icons.cancel_outlined, color: Color(0xFFEF4444)),
  ];

  @override
  Widget build(BuildContext context) {
    final counts = [pendingCount, approvedCount, rejectedCount];
    return Container(
      height: 56,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEF5),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
              color: Color(0xFFBEBECF), blurRadius: 0, offset: Offset(0, 5)),
          BoxShadow(
              color: Color(0xFFBEBECF), blurRadius: 14, offset: Offset(6, 6)),
          BoxShadow(
              color: Colors.white, blurRadius: 14, offset: Offset(-6, -6)),
        ],
      ),
      child: Row(
        children: List.generate(3, (i) {
          final isActive = selectedIndex == i;
          final tab = _tabs[i];
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onTap(i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(23),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                              color: tab.color.withOpacity(0.18),
                              blurRadius: 12,
                              offset: const Offset(0, 4)),
                          const BoxShadow(
                              color: Color(0xFFBEBECF),
                              blurRadius: 4,
                              offset: Offset(2, 2)),
                          const BoxShadow(
                              color: Colors.white,
                              blurRadius: 4,
                              offset: Offset(-2, -2)),
                        ]
                      : const [],
                ),
                child: Center(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(tab.icon,
                        size: isActive ? 15 : 13,
                        color: isActive ? tab.color : const Color(0xFF9999BB)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        tab.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isActive ? 13 : 12,
                          fontWeight:
                              isActive ? FontWeight.w800 : FontWeight.w600,
                          color: isActive
                              ? const Color(0xFF22224A)
                              : const Color(0xFF9999BB),
                        ),
                      ),
                    ),
                    if (counts[i] > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isActive ? tab.color : const Color(0xFFBEBECF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${counts[i]}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isActive
                                ? Colors.white
                                : const Color(0xFF666688),
                          ),
                        ),
                      ),
                    ],
                  ]),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Neo Back Button ───────────────────────────────────────────────────────────
class _CatReqBackButton extends StatelessWidget {
  const _CatReqBackButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).pop();
        },
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(13),
            border:
                Border.all(color: Colors.white.withOpacity(0.35), width: 1.5),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

// ── Category Request Card ─────────────────────────────────────────────────────
class _CategoryRequestCard extends ConsumerStatefulWidget {
  final CategoryRequestModel request;
  final Color cancelColor;
  final Color accentColor;
  const _CategoryRequestCard(
      {required this.request,
      required this.cancelColor,
      required this.accentColor});

  @override
  ConsumerState<_CategoryRequestCard> createState() =>
      _CategoryRequestCardState();
}

class _CategoryRequestCardState extends ConsumerState<_CategoryRequestCard> {
  bool _busy = false;

  static const _statusColors = {
    'pending': Color(0xFFF59E0B),
    'approved': Color(0xFF10B981),
    'rejected': Color(0xFFEF4444),
  };
  static const _statusLabels = {
    'pending': 'Pending',
    'approved': 'Approved',
    'rejected': 'Rejected',
  };

  bool get _canEditOrDelete => widget.request.status == 'pending';

  void _openDotsMenu() {
    if (_busy) return;
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: Color(0xFF7C3AED)),
              title: const Text('Edit Request',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.pop(context);
                showCategoryRequestSheet(context, ref,
                    existing: widget.request);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_rounded, color: Color(0xFFEF4444)),
              title: const Text('Delete Request',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Category Request',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
            'Are you sure you want to delete this category request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: TextStyle(color: widget.cancelColor)),
          ),
          TextButton(
            onPressed: () async {
              if (_busy) return;
              setState(() => _busy = true);
              Navigator.pop(dialogCtx);
              try {
                await deleteCategoryRequestInFirestore(widget.request.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Category request deleted'),
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Failed to delete request: $e'),
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              }
              if (mounted) setState(() => _busy = false);
            },
            child: const Text('Delete',
                style: TextStyle(
                    color: Color(0xFFEF4444), fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final color = _statusColors[r.status] ?? widget.cancelColor;
    final label = _statusLabels[r.status] ?? r.status;
    final hasDescription = r.requestedDescription.trim().isNotEmpty;
    final createdStr =
        '${r.createdAt.day}/${r.createdAt.month}/${r.createdAt.year}  '
        '${r.createdAt.hour.toString().padLeft(2, '0')}:${r.createdAt.minute.toString().padLeft(2, '0')}';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showCategoryRequestDetailsDialog(context, r,
          accentColor: widget.accentColor),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: const BoxDecoration(
          color: Color(0xFFEEEEF5),
          borderRadius: BorderRadius.all(Radius.circular(24)),
          boxShadow: [
            BoxShadow(
                color: Color(0xFFBEBECF), blurRadius: 0, offset: Offset(0, 6)),
            BoxShadow(
                color: Color(0xFFBEBECF), blurRadius: 14, offset: Offset(6, 6)),
            BoxShadow(
                color: Colors.white, blurRadius: 14, offset: Offset(-6, -6)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Text(
                  r.requestedName.isNotEmpty
                      ? r.requestedName
                      : 'Untitled Category',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF222244)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_canEditOrDelete) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _busy ? null : _openDotsMenu,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEEEEF5),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Color(0xFFBEBECF),
                            blurRadius: 4,
                            offset: Offset(2, 2)),
                        BoxShadow(
                            color: Colors.white,
                            blurRadius: 4,
                            offset: Offset(-2, -2)),
                      ],
                    ),
                    child: Icon(Icons.more_vert_rounded,
                        color: _busy
                            ? const Color(0xFFBEBECF)
                            : const Color(0xFF7777AA),
                        size: 18),
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEEEEF5),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0xFFBEBECF),
                      blurRadius: 4,
                      offset: Offset(2, 2)),
                  BoxShadow(
                      color: Colors.white,
                      blurRadius: 4,
                      offset: Offset(-2, -2)),
                ],
              ),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800, color: color)),
            ),
            if (hasDescription) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEEEF5),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0xFFBEBECF),
                        blurRadius: 4,
                        offset: Offset(2, 2)),
                    BoxShadow(
                        color: Colors.white,
                        blurRadius: 4,
                        offset: Offset(-2, -2)),
                  ],
                ),
                child: Text(
                  r.requestedDescription,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF555577), height: 1.5),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 13, color: Color(0xFF9999BB)),
              const SizedBox(width: 6),
              Text(createdStr,
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9999BB),
                      fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
      ),
    );
  }
}
