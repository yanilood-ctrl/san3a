import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/presentation/providers/app_providers.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../help/presentation/screens/help_center_screen.dart';
import 'contractor_chat_screen.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../../shared/widgets/profile_photo_menu.dart';
import '../../../../shared/widgets/profile_field_selectors.dart';
import '../../../../shared/widgets/category_requests_screen.dart';
import '../../../../shared/widgets/complaint_details_dialog.dart';
import '../../../../shared/widgets/provider_content_translate_action.dart';
import '../../../translation/data/translation_repository.dart'
    show TranslationContentType;
import 'contractor_order_detail_screen.dart';
import 'contractor_home_screen.dart' show ContractorNotificationsScreen;
import '../theme/contractor_design.dart';

// ── Navy palette (same as rest of Contractor screens) ─────────────────────────
class _B {
  static const darkest = ContractorColors.darkest;
  static const dark = ContractorColors.dark;
  static const mid = ContractorColors.mid;
  static const light = ContractorColors.light;
  static const warm = ContractorColors.warm;
  static const surface = Color(0xFFFDF6EC);
}

// ─── Main Screen ──────────────────────────────────────────────────────────────
class ContractorProfileScreen extends ConsumerStatefulWidget {
  const ContractorProfileScreen({super.key});
  @override
  ConsumerState<ContractorProfileScreen> createState() =>
      _ContractorProfileScreenState();
}

class _ContractorProfileScreenState
    extends ConsumerState<ContractorProfileScreen> with WidgetsBindingObserver {
  bool _pickingPhoto = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Same defensive-only refresh already proven for the Customer Provider
  // Profile screen (see provider_profile_screen.dart): a backgrounded
  // Flutter Web tab's already-open providerReviewsProvider listener has
  // been observed to not promptly redeliver a Firestore change (e.g. Admin
  // hiding a review) made while this tab was backgrounded. Recreating just
  // this provider's stream the moment the tab returns to the foreground
  // guarantees a fresh read without waiting on that listener's own timing.
  // Uses the same user-resolution fallback already used by _pickPhoto()
  // below, matching exactly what build() watches
  // (providerReviewsProvider(user.id)).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final user = ref.read(liveCurrentUserProvider).valueOrNull ??
          ref.read(authProvider);
      ref.invalidate(providerReviewsProvider(user?.id ?? ''));
    }
  }

  Future<void> _pickPhoto() async {
    final user =
        ref.read(liveCurrentUserProvider).valueOrNull ?? ref.read(authProvider);
    if (user == null || _pickingPhoto) return;
    setState(() => _pickingPhoto = true);
    try {
      await showProfilePhotoActionSheet(
        context: context,
        ref: ref,
        user: user,
        accent: _B.mid,
      );
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  // ── Edit basic info ────────────────────────────────────────────────────────
  void _editBasicInfo(UserModel user) {
    final l = AppLocalizations.of(context);
    final nameCtrl = TextEditingController(text: user.fullName);
    final emailCtrl = TextEditingController(text: user.email);
    final phoneCtrl = TextEditingController(text: user.phone);
    final expCtrl =
        TextEditingController(text: user.experienceYears?.toString() ?? '');
    final compCtrl = TextEditingController(text: user.companyName ?? '');
    final formKey = GlobalKey<FormState>();
    const accent = _B.dark;

    // Also include additional info fields (response, languages, bio).
    // Hours come from user.effectiveWork* so the edit sheet always reflects
    // the same resolved schedule as the rest of the app.
    final desc = user.serviceDescription ?? '';
    String bio = '', response = 'Usually within an hour';
    if (desc.contains('hours:')) {
      for (final p in desc.split('|')) {
        final t = p.trim();
        if (t.startsWith('hours:')) {
          // handled via user.effectiveWorkingHoursLabel
        } else if (t.startsWith('response:'))
          response = t.replaceFirst('response:', '').trim();
        else if (t.isNotEmpty) bio = t;
      }
    } else {
      bio = desc;
    }
    final bioCtrl = TextEditingController(text: bio);
    final workAreaKey = GlobalKey<WorkAreaFieldState>();
    final hoursKey = GlobalKey<WorkingHoursFieldState>();
    final workingDaysKey = GlobalKey<WorkingDaysFieldState>();
    final responseKey = GlobalKey<ResponseTimeFieldState>();
    final languagesKey = GlobalKey<LanguagesFieldState>();

    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(text,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFA85428))),
        );

    _showEditSheet(
      title: l.get('edit_basic_info'),
      icon: Icons.person_outline_rounded,
      fields: [
        _Field(
            ctrl: nameCtrl,
            label: l.get('full_name'),
            icon: Icons.badge_outlined,
            required: true),
        _Field(
            ctrl: expCtrl,
            label: l.get('experience_years'),
            icon: Icons.work_history_outlined,
            keyboard: TextInputType.number),
        _Field(
            ctrl: emailCtrl,
            label: l.get('email'),
            icon: Icons.email_outlined,
            keyboard: TextInputType.emailAddress),
        _Field(
            ctrl: phoneCtrl,
            label: l.get('phone'),
            icon: Icons.phone_outlined,
            keyboard: TextInputType.phone),
        _Field(
            ctrl: compCtrl,
            label: l.get('company_name'),
            icon: Icons.business_outlined),
        _Field(
            ctrl: bioCtrl,
            label: l.get('about_me'),
            icon: Icons.notes_rounded,
            maxLines: 3),
      ],
      extraFields: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            label(l.get('work_area')),
            WorkAreaField(
                key: workAreaKey,
                initialValue: user.workArea ?? '',
                accentColor: accent),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            label('Working Hours (e.g. 08:00 – 18:00)'),
            WorkingHoursField(
                key: hoursKey,
                initialRange: user.effectiveWorkingHoursLabel,
                accentColor: accent),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            label('Working Days'),
            WorkingDaysField(
                key: workingDaysKey,
                initialValue: user.effectiveWorkingDays,
                accentColor: accent),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            label('Response Time'),
            ResponseTimeField(
                key: responseKey, initialValue: response, accentColor: accent),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            label('Languages'),
            LanguagesField(
                key: languagesKey,
                initialValue: user.languages,
                accentColor: accent),
          ]),
        ),
      ],
      formKey: formKey,
      onSave: () async {
        if (!formKey.currentState!.validate()) return false;
        final hoursValue = hoursKey.currentState!.validate();
        if (hoursValue == null) return false;
        final workingDaysValue = workingDaysKey.currentState!.validate();
        if (workingDaysValue == null) return false;
        final responseValue = responseKey.currentState!.value;
        final langs = languagesKey.currentState!.value;
        final workAreaValue = workAreaKey.currentState!.value;
        final hoursParts = splitWorkingHoursRange(hoursValue);
        final newDesc = [
          if (bioCtrl.text.trim().isNotEmpty) bioCtrl.text.trim(),
          'hours: $hoursValue',
          'response: $responseValue',
        ].join(' | ');
        await ref
            .read(authProvider.notifier)
            .updateContractorProfile(user.copyWith(
              fullName: nameCtrl.text.trim(),
              email: emailCtrl.text.trim(),
              phone: phoneCtrl.text.trim(),
              workArea: workAreaValue,
              companyName: compCtrl.text.trim(),
              experienceYears: int.tryParse(expCtrl.text.trim()),
              serviceDescription: newDesc.isEmpty ? null : newDesc,
              languages: langs,
              workingDays: workingDaysValue,
              workStartTime: hoursParts?[0],
              workEndTime: hoursParts?[1],
            ));
        return true;
      },
    );
  }

  // ── Request New Category ────────────────────────────────────────────────────
  void _showRequestCategorySheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF6EFE6),
            borderRadius: BorderRadius.circular(32),
            boxShadow: const [
              BoxShadow(
                  color: Color(0xFFD9C6B2),
                  blurRadius: 20,
                  offset: Offset(8, 8)),
              BoxShadow(
                  color: Colors.white, blurRadius: 20, offset: Offset(-8, -8)),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle + X
                    Row(children: [
                      Expanded(
                          child: Center(
                              child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD9C6B2),
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.white,
                                blurRadius: 2,
                                offset: Offset(-1, -1)),
                            BoxShadow(
                                color: Color(0xFFD9C6B2),
                                blurRadius: 2,
                                offset: Offset(1, 1))
                          ],
                        ),
                      ))),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFF6EFE6),
                            boxShadow: [
                              BoxShadow(
                                  color: Color(0xFFD9C6B2),
                                  blurRadius: 6,
                                  offset: Offset(3, 3)),
                              BoxShadow(
                                  color: Colors.white,
                                  blurRadius: 6,
                                  offset: Offset(-3, -3))
                            ],
                          ),
                          child: const Icon(Icons.close_rounded,
                              size: 16, color: Color(0xFF9A8676)),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    // Title
                    Row(children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFF6EFE6),
                          boxShadow: [
                            BoxShadow(
                                color: Color(0xFFD9C6B2),
                                blurRadius: 8,
                                offset: Offset(4, 4)),
                            BoxShadow(
                                color: Colors.white,
                                blurRadius: 8,
                                offset: Offset(-4, -4))
                          ],
                        ),
                        child: const Icon(Icons.category_rounded,
                            color: Color(0xFFA85428), size: 22),
                      ),
                      const SizedBox(width: 14),
                      const Text('Request New Category',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF7A3E1E))),
                    ]),
                    const SizedBox(height: 18),
                    // Info card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6EFE6),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0xFFD9C6B2),
                              blurRadius: 6,
                              offset: Offset(3, 3)),
                          BoxShadow(
                              color: Colors.white,
                              blurRadius: 6,
                              offset: Offset(-3, -3))
                        ],
                      ),
                      child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded,
                                color: Color(0xFFA85428), size: 18),
                            SizedBox(width: 10),
                            Expanded(
                                child: Text(
                                    "Can't find the category you need? Send us a request and the admin will review it.",
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFFA85428),
                                        height: 1.5))),
                          ]),
                    ),
                    const SizedBox(height: 20),
                    const Text('Category Name',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFA85428))),
                    const SizedBox(height: 8),
                    _CtrNeoInputField(
                        controller: nameCtrl,
                        hint: 'e.g. Interior Design, HVAC Technician...',
                        icon: Icons.category_outlined,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Please enter a category name'
                            : null),
                    const SizedBox(height: 14),
                    const Text('Description (Optional)',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFA85428))),
                    const SizedBox(height: 8),
                    _CtrNeoInputField(
                        controller: descCtrl,
                        hint: 'Describe what this category covers...',
                        icon: Icons.description_outlined,
                        maxLines: 3),
                    const SizedBox(height: 28),
                    _CtrNeoSendButton(
                      label: 'Send Request',
                      icon: Icons.send_rounded,
                      onTap: () async {
                        if (!formKey.currentState!.validate()) return;
                        final user = ref.read(authProvider);
                        final name = nameCtrl.text.trim();
                        final desc = descCtrl.text.trim();
                        Navigator.pop(ctx);
                        try {
                          final req = CategoryRequestModel(
                            id: '',
                            requesterId: user?.id ?? '',
                            requesterName: user?.fullName ?? '',
                            requesterRole: 'contractor',
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
                        } catch (_) {}
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Row(children: [
                              const Icon(Icons.check_circle_rounded,
                                  color: Colors.white),
                              const SizedBox(width: 8),
                              Text('Request for "$name" sent!'),
                            ]),
                            backgroundColor: const Color(0xFFA85428),
                            behavior: SnackBarBehavior.fixed,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ));
                        }
                      },
                    ),
                  ]),
            ),
          ),
        ),
      ),
    );
  }

  // ── Specialties three-dots menu ───────────────────────────────────────────
  void _showSpecialtiesMenu(
      BuildContext context, UserModel user, AppLocalizations l) {
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
              leading: const Icon(Icons.edit_rounded, color: Color(0xFFA85428)),
              title: Text(l.get('edit_specialties'),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.pop(context);
                _editSpecialties(user);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline_rounded,
                  color: Color(0xFFA85428)),
              title: const Text('Request a New Category',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.pop(context);
                _showRequestCategorySheet(context);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.list_alt_rounded, color: Color(0xFF0EA5E9)),
              title: const Text('My Category Requests',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CategoryRequestsScreen(
                              gradientStart: _B.darkest,
                              gradientEnd: _B.dark,
                              secondaryColor: _B.mid,
                              scaffoldBackgroundColor: Color(0xFFF6EFE6),
                            )));
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Edit specialties ───────────────────────────────────────────────────────
  void _editSpecialties(UserModel user) {
    final allCats = ref.read(categoriesProvider).value ?? [];
    // Seed the sheet's selection with canonical nameKeys resolved from the
    // live category list only — an invalid/deleted/inactive stored
    // specialty must never end up silently selected (it wouldn't render a
    // chip to un-toggle, yet would still be written back on Save).
    final selected = <String>{
      for (final c in _resolveProviderServiceCategories(allCats, user))
        c.nameKey
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setSt) {
        final l = AppLocalizations.of(ctx);
        return Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _SheetHandle(),
            const SizedBox(height: 20),
            _SheetTitle(
                title: l.get('edit_specialties'),
                icon: Icons.category_outlined),
            const SizedBox(height: 16),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children: allCats.map((cat) {
                  final key = cat.nameKey;
                  final isSel = selected.contains(key);
                  return GestureDetector(
                    onTap: () => setSt(
                        () => isSel ? selected.remove(key) : selected.add(key)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel ? _B.darkest : _B.warm,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: isSel ? _B.darkest : _B.mid.withOpacity(0.4),
                            width: 1.5),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(cat.icon, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(l.get(key),
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isSel ? Colors.white : _B.darkest)),
                      ]),
                    ),
                  );
                }).toList()),
            const SizedBox(height: 24),
            _SaveBtn(onSave: () {
              // Write canonical nameKeys in categoriesProvider display order
              // for deterministic Firestore data; anything left in
              // `selected` that no longer matches a live category (there
              // shouldn't be any, since selection only ever came from
              // allCats) is naturally dropped here too.
              final orderedSelected = allCats
                  .where((c) => selected.contains(c.nameKey))
                  .map((c) => c.nameKey)
                  .toList();
              ref.read(authProvider.notifier).saveSpecialties(orderedSelected);
              Navigator.pop(context);
              _showSnack(l.get('specialties_updated'));
            }),
          ]),
        );
      }),
    );
  }

  // Resolves the real, currently-active Firestore categories this
  // provider's specialties actually correspond to, using the exact same
  // normalized (trim + lowercase) category.id/category.nameKey vs
  // specialties equality already used by categoryProvidersStreamProvider
  // (app_providers.dart) — including its same legacy fallback to the single
  // `specialty` field when `specialties` is empty. Never guesses a category
  // from the service name and never offers an unrelated category as a
  // fallback. Identical to the Professional-side helper of the same name in
  // professional_home_screen.dart so both roles apply the same rule.
  List<CategoryModel> _resolveProviderServiceCategories(
      List<CategoryModel> activeCategories, UserModel user) {
    final rawSpecialties = user.specialties.isNotEmpty
        ? user.specialties
        : (user.specialty != null ? [user.specialty!] : const <String>[]);
    final normalizedSpecialties = rawSpecialties
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toSet();
    if (normalizedSpecialties.isEmpty) return const [];
    return activeCategories.where((c) {
      final normId = c.id.trim().toLowerCase();
      final normName = c.nameKey.trim().toLowerCase();
      return normalizedSpecialties.contains(normId) ||
          normalizedSpecialties.contains(normName);
    }).toList();
  }

  // ── Edit service ───────────────────────────────────────────────────────────
  void _editService(UserModel user, {ServiceModel? existing}) {
    final l = AppLocalizations.of(context);
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final priceCtrl =
        TextEditingController(text: existing?.price.toStringAsFixed(0) ?? '');
    final formKey = GlobalKey<FormState>();
    final isEdit = existing != null;

    // Real Firestore categories this provider's specialties actually
    // resolve to — read once when the sheet opens, mirroring the same
    // one-shot pattern already used for nameCtrl/descCtrl/priceCtrl above.
    final activeCategories =
        ref.read(categoriesProvider).value ?? const <CategoryModel>[];
    final eligibleCategories =
        _resolveProviderServiceCategories(activeCategories, user);
    String? selectedCategoryId = (existing?.categoryId != null &&
            eligibleCategories.any((c) => c.id == existing!.categoryId))
        ? existing!.categoryId
        : null;
    bool categoryError = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx2, setModalState) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF6EFE6),
              borderRadius: BorderRadius.circular(32),
              boxShadow: const [
                BoxShadow(
                    color: Color(0xFFD9C6B2),
                    blurRadius: 20,
                    offset: Offset(8, 8)),
                BoxShadow(
                    color: Colors.white,
                    blurRadius: 20,
                    offset: Offset(-8, -8)),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle + X
                      Row(children: [
                        Expanded(
                            child: Center(
                                child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD9C6B2),
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: const [
                              BoxShadow(
                                  color: Colors.white,
                                  blurRadius: 2,
                                  offset: Offset(-1, -1)),
                              BoxShadow(
                                  color: Color(0xFFD9C6B2),
                                  blurRadius: 2,
                                  offset: Offset(1, 1))
                            ],
                          ),
                        ))),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFF6EFE6),
                              boxShadow: [
                                BoxShadow(
                                    color: Color(0xFFD9C6B2),
                                    blurRadius: 6,
                                    offset: Offset(3, 3)),
                                BoxShadow(
                                    color: Colors.white,
                                    blurRadius: 6,
                                    offset: Offset(-3, -3))
                              ],
                            ),
                            child: const Icon(Icons.close_rounded,
                                size: 16, color: Color(0xFF9A8676)),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      // Title
                      Row(children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFF6EFE6),
                            boxShadow: [
                              BoxShadow(
                                  color: Color(0xFFD9C6B2),
                                  blurRadius: 8,
                                  offset: Offset(4, 4)),
                              BoxShadow(
                                  color: Colors.white,
                                  blurRadius: 8,
                                  offset: Offset(-4, -4))
                            ],
                          ),
                          child: Icon(
                              isEdit
                                  ? Icons.edit_rounded
                                  : Icons.build_circle_rounded,
                              color: const Color(0xFFA85428),
                              size: 22),
                        ),
                        const SizedBox(width: 14),
                        Text(
                            isEdit
                                ? l.get('edit_service')
                                : l.get('add_new_service'),
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF7A3E1E))),
                      ]),
                      const SizedBox(height: 18),
                      // Info card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6EFE6),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0xFFD9C6B2),
                                blurRadius: 6,
                                offset: Offset(3, 3)),
                            BoxShadow(
                                color: Colors.white,
                                blurRadius: 6,
                                offset: Offset(-3, -3))
                          ],
                        ),
                        child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  color: Color(0xFFA85428), size: 18),
                              SizedBox(width: 10),
                              Expanded(
                                  child: Text(
                                      'Fill in the service details to display it on your profile.',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFFA85428),
                                          height: 1.5))),
                            ]),
                      ),
                      const SizedBox(height: 20),
                      Text(l.get('service_name'),
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFA85428))),
                      const SizedBox(height: 8),
                      _CtrNeoInputField(
                          controller: nameCtrl,
                          hint: 'e.g. Electrical Wiring, Painting...',
                          icon: Icons.label_outline_rounded,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Please enter service name'
                              : null),
                      const SizedBox(height: 14),
                      Text(l.get('service_desc'),
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFA85428))),
                      const SizedBox(height: 8),
                      _CtrNeoInputField(
                          controller: descCtrl,
                          hint: 'Describe the service briefly...',
                          icon: Icons.description_outlined,
                          maxLines: 3,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Please enter description'
                              : null),
                      const SizedBox(height: 14),
                      Text(l.get('price_ils'),
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFA85428))),
                      const SizedBox(height: 8),
                      _CtrNeoInputField(
                          controller: priceCtrl,
                          hint: 'e.g. 150',
                          icon: Icons.payments_outlined,
                          keyboard: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty)
                              return 'Please enter the price';
                            if (double.tryParse(v.trim()) == null)
                              return 'Enter a valid number';
                            return null;
                          }),
                      const SizedBox(height: 14),
                      Text(l.get('categories'),
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFA85428))),
                      const SizedBox(height: 8),
                      if (eligibleCategories.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6EFE6),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0xFFD9C6B2),
                                  blurRadius: 6,
                                  offset: Offset(3, 3)),
                              BoxShadow(
                                  color: Colors.white,
                                  blurRadius: 6,
                                  offset: Offset(-3, -3)),
                            ],
                          ),
                          child: Text(l.get('no_specialties_yet'),
                              style: const TextStyle(
                                  fontSize: 12.5, color: Color(0xFFA85428))),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: eligibleCategories.map((cat) {
                            final selected = selectedCategoryId == cat.id;
                            return GestureDetector(
                              onTap: () => setModalState(() {
                                selectedCategoryId = cat.id;
                                categoryError = false;
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 9),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? const Color(0xFFA85428)
                                      : const Color(0xFFF6EFE6),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: selected
                                      ? null
                                      : const [
                                          BoxShadow(
                                              color: Color(0xFFD9C6B2),
                                              blurRadius: 5,
                                              offset: Offset(3, 3)),
                                          BoxShadow(
                                              color: Colors.white,
                                              blurRadius: 5,
                                              offset: Offset(-3, -3)),
                                        ],
                                ),
                                child: Text(l.get(cat.nameKey),
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: selected
                                            ? Colors.white
                                            : const Color(0xFF7A3E1E))),
                              ),
                            );
                          }).toList(),
                        ),
                      if (categoryError) ...[
                        const SizedBox(height: 6),
                        const Text('Please select a category',
                            style: TextStyle(
                                fontSize: 11.5, color: Color(0xFFEF4444))),
                      ],
                      const SizedBox(height: 28),
                      _CtrNeoSendButton(
                        label: isEdit
                            ? l.get('save_changes')
                            : l.get('add_service'),
                        icon: isEdit ? Icons.check_rounded : Icons.add_rounded,
                        onTap: () async {
                          if (!formKey.currentState!.validate()) return;
                          if (eligibleCategories.isEmpty ||
                              selectedCategoryId == null) {
                            setModalState(() => categoryError = true);
                            return;
                          }
                          final price =
                              double.tryParse(priceCtrl.text.trim()) ?? 0;
                          final newService = ServiceModel(
                            id: existing?.id ??
                                'svc_${DateTime.now().millisecondsSinceEpoch}',
                            name: nameCtrl.text.trim(),
                            description: descCtrl.text.trim(),
                            price: price,
                            categoryId: selectedCategoryId,
                          );
                          List<ServiceModel> updated;
                          if (existing == null) {
                            updated = [...(user.servicesList), newService];
                          } else {
                            updated = user.servicesList
                                .map(
                                    (s) => s.id == existing.id ? newService : s)
                                .toList();
                          }
                          final nav = Navigator.of(ctx);
                          try {
                            await ref
                                .read(authProvider.notifier)
                                .saveServicesList(
                                    user.copyWith(servicesList: updated));
                            if (!mounted) return;
                            nav.pop();
                            _showSnack(existing == null
                                ? l.get('service_added')
                                : l.get('service_updated'));
                          } catch (e) {
                            debugPrint(
                                '[ContractorProfile] saveService error: $e');
                            if (!mounted) return;
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(
                              content: Row(children: [
                                Icon(Icons.error_rounded, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                    'Failed to save service. Please try again.'),
                              ]),
                              backgroundColor: Color(0xFFEF4444),
                              behavior: SnackBarBehavior.fixed,
                            ));
                          }
                        },
                      ),
                    ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _deleteService(UserModel user, ServiceModel svc) {
    final l = AppLocalizations.of(context);
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text(l.get('delete_service'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: _B.darkest)),
              content: Text(
                '"${svc.name}" — ${l.get("delete_confirm_service")}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l.get('cancel'),
                        style:
                            const TextStyle(color: AppColors.textSecondary))),
                ElevatedButton(
                  onPressed: () async {
                    final updated =
                        user.servicesList.where((s) => s.id != svc.id).toList();
                    Navigator.pop(context);
                    try {
                      await ref.read(authProvider.notifier).saveServicesList(
                          user.copyWith(servicesList: updated));
                      if (mounted) _showSnack(l.get('service_deleted'));
                    } catch (e) {
                      debugPrint('[ContractorProfile] deleteService error: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                          content: Row(children: [
                            Icon(Icons.error_rounded, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Failed to delete service.'),
                          ]),
                          backgroundColor: Color(0xFFEF4444),
                          behavior: SnackBarBehavior.fixed,
                        ));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  child: Text(l.get('delete'),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            ));
  }

  // ── Edit additional info ───────────────────────────────────────────────────
  void _editAdditional(UserModel user) {
    final descCtrl = TextEditingController(text: user.serviceDescription ?? '');
    final langsCtrl = TextEditingController(text: user.languages.join(', '));
    final formKey = GlobalKey<FormState>();

    _showEditSheet(
      title: AppLocalizations.of(context).get('edit_additional'),
      icon: Icons.info_outline_rounded,
      fields: [
        _Field(
            ctrl: descCtrl,
            label: 'Bio / Service Description',
            icon: Icons.notes_rounded,
            maxLines: 4),
        _Field(
            ctrl: langsCtrl,
            label: 'Languages (e.g. English, Arabic, Hebrew)',
            icon: Icons.language_outlined),
      ],
      formKey: formKey,
      onSave: () async {
        final langs = langsCtrl.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        await ref
            .read(authProvider.notifier)
            .updateContractorProfile(user.copyWith(
              serviceDescription: descCtrl.text.trim(),
              languages: langs,
            ));
        return true;
      },
    );
  }

  // ── Generic edit sheet ─────────────────────────────────────────────────────
  void _showEditSheet({
    required String title,
    required IconData icon,
    required List<_Field> fields,
    required GlobalKey<FormState> formKey,
    required Future<bool> Function() onSave,
    List<Widget>? extraFields,
  }) {
    bool saving = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.88),
          decoration: const BoxDecoration(
            color: Color(0xFFF6EFE6),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                  color: Color(0xFFD9C6B2),
                  blurRadius: 20,
                  offset: Offset(8, 8)),
              BoxShadow(
                  color: Colors.white, blurRadius: 20, offset: Offset(-8, -8)),
            ],
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Center(
                      child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9C6B2),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.white,
                            blurRadius: 2,
                            offset: Offset(-1, -1)),
                        BoxShadow(
                            color: Color(0xFFD9C6B2),
                            blurRadius: 2,
                            offset: Offset(1, 1)),
                      ],
                    ),
                  )),
                ),

                // Header row
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Row(children: [
                    // Neo icon container
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6EFE6),
                        borderRadius: BorderRadius.circular(17),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0xFFD9C6B2),
                              blurRadius: 0,
                              offset: Offset(0, 4)),
                          BoxShadow(
                              color: Color(0xFFD9C6B2),
                              blurRadius: 10,
                              offset: Offset(5, 5)),
                          BoxShadow(
                              color: Colors.white,
                              blurRadius: 10,
                              offset: Offset(-5, -5)),
                        ],
                      ),
                      child:
                          Icon(icon, color: const Color(0xFFA85428), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Text(title,
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF7A3E1E),
                                letterSpacing: -0.3))),
                    // Close button
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6EFE6),
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0xFFD9C6B2),
                                blurRadius: 4,
                                offset: Offset(3, 3)),
                            BoxShadow(
                                color: Colors.white,
                                blurRadius: 4,
                                offset: Offset(-3, -3)),
                          ],
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: Color(0xFFA85428), size: 17),
                      ),
                    ),
                  ]),
                ),

                // Info banner
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6EFE6),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0xFFD9C6B2),
                            blurRadius: 4,
                            offset: Offset(2, 2),
                            spreadRadius: -1),
                        BoxShadow(
                            color: Colors.white,
                            blurRadius: 4,
                            offset: Offset(-2, -2),
                            spreadRadius: -1),
                      ],
                    ),
                    child: Row(children: [
                      const Icon(Icons.info_outline_rounded,
                          color: Color(0xFFA85428), size: 15),
                      const SizedBox(width: 9),
                      Expanded(
                          child: Text(
                              'Fill in your information and tap Save to update your profile.',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFA85428),
                                  height: 1.4))),
                    ]),
                  ),
                ),

                // Fields list
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: Column(children: [
                      ...fields.map((f) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _CtrNeoField(
                                ctrl: f.ctrl,
                                label: f.label,
                                icon: f.icon,
                                required: f.required,
                                keyboard: f.keyboard,
                                maxLines: f.maxLines),
                          )),
                      if (extraFields != null) ...extraFields,
                      const SizedBox(height: 8),
                    ]),
                  ),
                ),

                // Save button
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  child: StatefulBuilder(
                    builder: (ctx, setBtnState) => _CtrNeoSendButton(
                      label: 'Save Changes',
                      icon: Icons.check_rounded,
                      loading: saving,
                      onTap: () async {
                        if (saving) return;
                        setBtnState(() => saving = true);
                        try {
                          final success = await onSave();
                          if (success) {
                            if (!mounted) return;
                            Navigator.pop(context);
                            _showSnack(AppLocalizations.of(context)
                                .get('changes_saved'));
                          } else {
                            setBtnState(() => saving = false);
                          }
                        } catch (e) {
                          debugPrint('[ContractorProfile] save error: $e');
                          setBtnState(() => saving = false);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                            content: Row(children: [
                              Icon(Icons.error_rounded, color: Colors.white),
                              SizedBox(width: 8),
                              Text('Failed to save. Please try again.'),
                            ]),
                            backgroundColor: Color(0xFFEF4444),
                            behavior: SnackBarBehavior.fixed,
                          ));
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white),
        const SizedBox(width: 8),
        Text(msg),
      ]),
      backgroundColor: _B.dark,
      behavior: SnackBarBehavior.fixed,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final user = ref.watch(liveCurrentUserProvider).valueOrNull ??
        ref.watch(authProvider);

    if (user == null) return const SizedBox();

    final reviewsAsync = ref.watch(providerReviewsProvider(user.id));
    final allOrders =
        ref.watch(contractorFirestoreOrdersProvider).valueOrNull ??
            const <OrderModel>[];
    final completedOrders =
        allOrders.where((o) => o.status == OrderStatus.completed).length;

    // Parse the saved response-time preference from serviceDescription
    // (same pipe-separated format written by _editBasicInfo below).
    String responseTime = 'Usually within an hour';
    final descForResponse = user.serviceDescription ?? '';
    if (descForResponse.contains('response:')) {
      for (final p in descForResponse.split('|')) {
        final t = p.trim();
        if (t.startsWith('response:')) {
          responseTime = t.replaceFirst('response:', '').trim();
        }
      }
    }

    final allCats = ref.watch(categoriesProvider).value ?? [];
    // Resolved once per build (not per service row) so each service card can
    // look up its category by id without its own ref.watch call.
    final categoriesById = {for (final c in allCats) c.id: c};
    // Only ever the live, active CategoryModel objects this provider's raw
    // specialties/specialty actually resolve to — never a fallback built
    // from an unmatched raw string (see _resolveProviderServiceCategories).
    final resolvedSpecialtyCategories =
        _resolveProviderServiceCategories(allCats, user);

    final allReviews = reviewsAsync.valueOrNull ?? const <ReviewModel>[];
    final avgRating = allReviews.isEmpty
        ? 0.0
        : allReviews.map((r) => r.rating).reduce((a, b) => a + b) /
            allReviews.length;
    final activeCriteria =
        ref.watch(reviewCriteriaProvider).where((c) => c.isActive).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF6EFE6),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Hero ──────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF7A3E1E),
                    Color(0xFFA85428),
                    Color(0xFFA85428)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.0, 0.5, 1.0],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: Column(children: [
                      // top bar
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('My Profile',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3)),
                            _CtrNeoLogoutBtn(
                              onTap: () {
                                ref.read(authProvider.notifier).logout();
                                Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const LoginScreen()),
                                    (r) => false);
                              },
                            ),
                          ]),
                      const SizedBox(height: 20),
                      // avatar
                      Stack(alignment: Alignment.bottomRight, children: [
                        Container(
                          width: 86,
                          height: 86,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFDC7D4E), Color(0xFFFFDD8D)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.45),
                                width: 2.5),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x55000000),
                                  blurRadius: 18,
                                  offset: Offset(0, 7))
                            ],
                          ),
                          child: ProfileAvatarImage(
                            imageUrl: user.avatar,
                            size: 86,
                            fallbackText:
                                user.fullName.isNotEmpty ? user.fullName : 'C',
                            fallbackTextStyle: const TextStyle(
                                color: Color(0xFF7A3E1E),
                                fontSize: 34,
                                fontWeight: FontWeight.w900),
                          ),
                        ),
                        GestureDetector(
                          onTap: _pickingPhoto ? null : _pickPhoto,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC7D4E),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFFF6EFE6), width: 2.5),
                              boxShadow: const [
                                BoxShadow(
                                    color: Color(0x44000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 3))
                              ],
                            ),
                            child: _pickingPhoto
                                ? const Padding(
                                    padding: EdgeInsets.all(5),
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.camera_alt_rounded,
                                    color: Colors.white, size: 12),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Text(user.fullName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3)),
                      const SizedBox(height: 3),
                      if (user.companyName != null &&
                          user.companyName!.isNotEmpty)
                        Text(user.companyName!,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 12)),
                      const SizedBox(height: 3),
                      Text(
                          'Contractor · ${user.role == UserRole.contractor ? l.get("company_contractor") : l.get("individual")}',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 11)),
                      const SizedBox(height: 16),
                      // stats strip
                      Container(
                        decoration: BoxDecoration(
                          border: Border(
                              top: BorderSide(
                                  color: Colors.white.withOpacity(0.09))),
                        ),
                        child: Row(children: [
                          _CtrHeroStat(
                              icon: Icons.star_rounded,
                              value: avgRating.toStringAsFixed(1),
                              label: 'Rating',
                              color: const Color(0xFFFFCA28)),
                          _CtrHeroStat(
                              icon: Icons.check_circle_rounded,
                              value: '$completedOrders',
                              label: 'Completed',
                              color: const Color(0xFF5DCAA5)),
                          _CtrHeroStat(
                              icon: Icons.receipt_long_rounded,
                              value: '${allOrders.length}',
                              label: 'Orders',
                              color: const Color(0xFFFFDD8D)),
                          _CtrHeroStat(
                              icon: Icons.work_history_rounded,
                              value: '${user.experienceYears ?? 0}',
                              label: 'Yrs exp.',
                              color: const Color(0xFFDC7D4E),
                              isLast: true),
                        ]),
                      ),
                    ]),
                  )),
            ),
          ),

          // ── Body ──────────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
                delegate: SliverChildListDelegate([
              // mini stats
              Row(children: [
                Expanded(
                    child: _CtrMiniStat(
                        value:
                            '${completedOrders > 0 ? ((completedOrders / (allOrders.isEmpty ? 1 : allOrders.length)) * 100).round() : 0}%',
                        label: 'Completion rate',
                        color: const Color(0xFFA85428))),
                const SizedBox(width: 10),
                Expanded(
                    child: _CtrMiniStat(
                        value: responseTime,
                        label: 'Response time',
                        color: const Color(0xFFA85428),
                        maxLines: 2)),
              ]),
              const SizedBox(height: 18),

              // ── SECTION 1: Basic info ──────────────────────────────────
              _CtrSectionHead(
                  icon: Icons.person_outline_rounded,
                  iconColor: const Color(0xFFA85428),
                  title: l.get('basic_info'),
                  action: _CtrSectionPill(
                      label: l.get('edit'),
                      icon: Icons.edit_rounded,
                      color: const Color(0xFFA85428),
                      onTap: () => _editBasicInfo(user))),
              const SizedBox(height: 10),
              _CtrCard(children: [
                _CtrInfoRow(
                    icon: Icons.person_outline_rounded,
                    iconColor: const Color(0xFFA85428),
                    label: l.get('full_name'),
                    value: user.fullName),
                if (user.companyName != null && user.companyName!.isNotEmpty)
                  _CtrInfoRow(
                      icon: Icons.business_outlined,
                      iconColor: const Color(0xFF7A3E1E),
                      label: l.get('company'),
                      value: user.companyName!),
                _CtrInfoRow(
                    icon: Icons.email_outlined,
                    iconColor: const Color(0xFFA85428),
                    label: l.get('email'),
                    value: user.email),
                _CtrInfoRow(
                    icon: Icons.phone_outlined,
                    iconColor: const Color(0xFFA85428),
                    label: l.get('phone'),
                    value: user.phone),
                _CtrInfoRow(
                    icon: Icons.map_outlined,
                    iconColor: const Color(0xFFDC7D4E),
                    label: l.get('work_area'),
                    value: user.workArea?.isNotEmpty == true
                        ? l.translateRegion(user.workArea!)
                        : '—'),
                _CtrInfoRow(
                    icon: Icons.work_history_outlined,
                    iconColor: const Color(0xFFA85428),
                    label: l.get('experience'),
                    value: '${user.experienceYears ?? 0} ${l.get("years")}'),
                _CtrInfoRow(
                    icon: Icons.language_outlined,
                    iconColor: const Color(0xFFA85428),
                    label: 'Languages',
                    value: user.languages.isNotEmpty
                        ? user.languages.join(', ')
                        : '—'),
                _CtrInfoRow(
                    icon: Icons.event_available_rounded,
                    iconColor: const Color(0xFFDC7D4E),
                    label: 'Working Days',
                    value: formatWorkingDaysLabel(user.effectiveWorkingDays)),
                _CtrInfoRow(
                    icon: Icons.access_time_rounded,
                    iconColor: const Color(0xFFA85428),
                    label: 'Working hours',
                    value: user.effectiveWorkingHoursLabel,
                    isLast: true),
              ]),
              const SizedBox(height: 10),
              _CtrInsetCard(
                  child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  () {
                    final desc = user.serviceDescription ?? '';
                    if (desc.isEmpty || desc.trim().length <= 1)
                      return 'No description added yet.';
                    if (desc.contains('|')) {
                      final bio = desc
                          .split('|')
                          .map((p) => p.trim())
                          .where((p) =>
                              !p.startsWith('hours:') &&
                              !p.startsWith('response:'))
                          .join(' ')
                          .trim();
                      return bio.isEmpty ? 'No description added yet.' : bio;
                    }
                    return desc.startsWith('hours:') ||
                            desc.startsWith('response:')
                        ? 'No description added yet.'
                        : desc;
                  }(),
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFFA85428), height: 1.6),
                ),
              )),
              const SizedBox(height: 20),

              // ── SECTION 2: Specialties ─────────────────────────────────
              _CtrSectionHead(
                icon: Icons.category_outlined,
                iconColor: const Color(0xFF7A3E1E),
                title: l.get('specialties'),
                action: _CtrNeoDotsBtn(
                  onTap: () => _showSpecialtiesMenu(context, user, l),
                ),
              ),
              const SizedBox(height: 10),
              _CtrCard(children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: resolvedSpecialtyCategories.isEmpty
                      ? Center(
                          child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text('Tap Edit to add specialties',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: const Color(0xFFC7B29C)))))
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: resolvedSpecialtyCategories.map((cat) {
                            return _CtrNeoChip(
                                emoji: cat.icon,
                                label: l.get(cat.nameKey),
                                color: const Color(0xFFA85428));
                          }).toList()),
                ),
              ]),
              const SizedBox(height: 20),

              // ── SECTION 3: Services ────────────────────────────────────
              _CtrSectionHead(
                  icon: Icons.build_circle_outlined,
                  iconColor: const Color(0xFFA85428),
                  title: l.get('services_prices'),
                  action: _CtrNeoSpecialtyBtn(
                      label: l.get('add'),
                      icon: Icons.add_rounded,
                      color: const Color(0xFFA85428),
                      onTap: () => _editService(user))),
              const SizedBox(height: 10),
              _CtrCard(
                  children: user.servicesList.isNotEmpty
                      ? user.servicesList
                          .map((svc) => _CtrServiceRow(
                              service: svc,
                              user: user,
                              category: categoriesById[svc.categoryId],
                              onEdit: () => _editService(user, existing: svc),
                              onDelete: () => _deleteService(user, svc)))
                          .toList()
                      : [
                          Padding(
                              padding: const EdgeInsets.all(16),
                              child: Center(
                                  child: Text('Tap + to add services',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: const Color(0xFFC7B29C)))))
                        ]),
              const SizedBox(height: 20),

              // ── SECTION 4: Ratings ─────────────────────────────────────
              _CtrSectionHead(
                  icon: Icons.star_rounded,
                  iconColor: const Color(0xFFBA7517),
                  title: l.get('rating')),
              const SizedBox(height: 10),
              _CtrCard(children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(avgRating.toStringAsFixed(1),
                              style: const TextStyle(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF7A3E1E),
                                  letterSpacing: -2,
                                  height: 1)),
                          Row(
                              children: List.generate(
                                  5,
                                  (i) => Icon(
                                      i < avgRating.round()
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      color: const Color(0xFFFFCA28),
                                      size: 14))),
                          const SizedBox(height: 4),
                          Text('${allReviews.length} ${l.get("rating")}',
                              style: const TextStyle(
                                  fontSize: 10, color: Color(0xFFA85428))),
                        ]),
                        const SizedBox(width: 18),
                        Expanded(
                            child: Column(children: [
                          for (var i = 0; i < activeCriteria.length; i++) ...[
                            _CtrRatingBar(
                                label: activeCriteria[i].name,
                                value: _ctrAvgForCriterion(
                                    allReviews, activeCriteria[i]),
                                maxRating: activeCriteria[i].maxRating),
                            if (i != activeCriteria.length - 1)
                              const SizedBox(height: 8),
                          ],
                        ])),
                      ]),
                ),
              ]),
              const SizedBox(height: 10),
              _CtrCard(
                  children: allReviews
                      .asMap()
                      .entries
                      .map((e) => _CtrReviewCard(
                          review: e.value,
                          isLast: e.key == allReviews.length - 1))
                      .toList()),
              const SizedBox(height: 20),

              // ── SECTION 5: Quick Actions ───────────────────────────────
              _CtrSectionHead(
                  icon: Icons.bolt_rounded,
                  iconColor: const Color(0xFFA85428),
                  title: 'Quick actions'),
              const SizedBox(height: 10),
              _CtrCard(children: [
                _CtrActionRow(
                    icon: Icons.receipt_long_rounded,
                    iconColor: const Color(0xFFA85428),
                    label: 'My orders',
                    onTap: () => ref.read(navIndexProvider.notifier).state = 0),
                _CtrActionRow(
                    icon: Icons.flag_rounded,
                    iconColor: const Color(0xFFD97706),
                    label: 'Complaints',
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ContractorComplaintsPage()))),
                _CtrActionRow(
                    icon: Icons.notifications_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                    label: 'Notifications',
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const ContractorNotificationsScreen()))),
                _CtrActionRow(
                    icon: Icons.help_outline_rounded,
                    iconColor: const Color(0xFFA85428),
                    label: 'Help & support',
                    isLast: true,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const HelpCenterScreen(
                                userRole: UserRole.contractor,
                                accentColor: Color(0xFFA85428),
                                gradientStart: Color(0xFF7A3E1E),
                                gradientEnd: Color(0xFFA85428))))),
              ]),
              SizedBox(height: 36 + 92 + MediaQuery.of(context).padding.bottom),
            ])),
          ),
        ],
      ),
    );
  }
}

// ─── Contractor Neo Helper Widgets ────────────────────────────────────────────

const _cNeoBase = Color(0xFFF6EFE6);
const List<BoxShadow> _cNeoRaised = [
  BoxShadow(color: Color(0xFFD9C6B2), blurRadius: 0, offset: Offset(0, 4)),
  BoxShadow(color: Color(0xFFD9C6B2), blurRadius: 14, offset: Offset(6, 6)),
  BoxShadow(color: Colors.white, blurRadius: 14, offset: Offset(-6, -6)),
];
const List<BoxShadow> _cNeoInset = [
  BoxShadow(
      color: Color(0xFFD9C6B2),
      blurRadius: 6,
      offset: Offset(3, 3),
      spreadRadius: -1),
  BoxShadow(
      color: Colors.white,
      blurRadius: 6,
      offset: Offset(-3, -3),
      spreadRadius: -1),
];
const List<BoxShadow> _cNeoBtnRaised = [
  BoxShadow(color: Color(0xFFD9C6B2), blurRadius: 0, offset: Offset(0, 3)),
  BoxShadow(color: Color(0xFFD9C6B2), blurRadius: 9, offset: Offset(4, 4)),
  BoxShadow(color: Colors.white, blurRadius: 9, offset: Offset(-4, -4)),
];

// ── Neo Logout Button (hero top-right) ───────────────────────────────────────
class _CtrNeoLogoutBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _CtrNeoLogoutBtn({required this.onTap});
  @override
  State<_CtrNeoLogoutBtn> createState() => _CtrNeoLogoutBtnState();
}

class _CtrNeoLogoutBtnState extends State<_CtrNeoLogoutBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _p = false;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 110));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          setState(() => _p = true);
          _ctrl.forward();
        },
        onTapUp: (_) {
          setState(() => _p = false);
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () {
          setState(() => _p = false);
          _ctrl.reverse();
        },
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.08 * _ctrl.value, child: child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _cNeoBase,
              borderRadius: BorderRadius.circular(14),
              boxShadow: _p
                  ? [
                      const BoxShadow(
                          color: Color(0xFFD9C6B2),
                          blurRadius: 6,
                          offset: Offset(3, 3),
                          spreadRadius: -1),
                      const BoxShadow(
                          color: Colors.white,
                          blurRadius: 6,
                          offset: Offset(-3, -3),
                          spreadRadius: -1)
                    ]
                  : [
                      const BoxShadow(
                          color: Color(0xFFD9C6B2),
                          blurRadius: 0,
                          offset: Offset(0, 3)),
                      const BoxShadow(
                          color: Color(0xFFD9C6B2),
                          blurRadius: 8,
                          offset: Offset(4, 4)),
                      const BoxShadow(
                          color: Colors.white,
                          blurRadius: 8,
                          offset: Offset(-4, -4))
                    ],
            ),
            child: const Icon(Icons.logout_rounded,
                color: Color(0xFFA32D2D), size: 20),
          ),
        ),
      );
}

// ── Hero stat ─────────────────────────────────────────────────────────────────
class _CtrHeroStat extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color color;
  final bool isLast;
  const _CtrHeroStat(
      {required this.icon,
      required this.value,
      required this.label,
      required this.color,
      this.isLast = false});
  @override
  Widget build(BuildContext context) => Expanded(
          child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
            border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.09)),
          right: isLast
              ? BorderSide.none
              : BorderSide(color: Colors.white.withOpacity(0.07)),
        )),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          Text(label,
              style:
                  TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 9),
              textAlign: TextAlign.center),
        ]),
      ));
}

// ── Mini stat ─────────────────────────────────────────────────────────────────
class _CtrMiniStat extends StatelessWidget {
  final String value, label;
  final Color color;
  final int maxLines;
  const _CtrMiniStat(
      {required this.value,
      required this.label,
      required this.color,
      this.maxLines = 1});
  @override
  Widget build(BuildContext context) {
    // Single-line stats (percentages, counts) keep the original 22px size;
    // multi-line stats (e.g. a saved response-time sentence) shrink just
    // enough to fit 2 lines without truncating the value's meaning.
    final fontSize = maxLines <= 1
        ? 22.0
        : value.length > 26
            ? 12.0
            : value.length > 18
                ? 14.0
                : 18.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
          color: _cNeoBase,
          borderRadius: BorderRadius.circular(18),
          boxShadow: _cNeoRaised),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                maxLines: maxLines,
                overflow: TextOverflow.visible,
                softWrap: true,
                style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w900,
                    color: color,
                    height: 1.15)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 10, color: Color(0xFFA85428))),
          ]),
    );
  }
}

// ── Section head ──────────────────────────────────────────────────────────────
class _CtrSectionHead extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget? action;
  const _CtrSectionHead(
      {required this.icon,
      required this.iconColor,
      required this.title,
      this.action});
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: _cNeoBase,
                borderRadius: BorderRadius.circular(11),
                boxShadow: _cNeoBtnRaised),
            child: Icon(icon, color: iconColor, size: 17)),
        const SizedBox(width: 10),
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF7A3E1E),
                    letterSpacing: -0.2))),
        if (action != null) action!,
      ]);
}

// ── Section pill ──────────────────────────────────────────────────────────────
class _CtrSectionPill extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _CtrSectionPill(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});
  @override
  State<_CtrSectionPill> createState() => _CtrSectionPillState();
}

class _CtrSectionPillState extends State<_CtrSectionPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _p = false;
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
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          setState(() => _p = true);
          _ctrl.forward();
        },
        onTapUp: (_) {
          setState(() => _p = false);
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () {
          setState(() => _p = false);
          _ctrl.reverse();
        },
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.05 * _ctrl.value, child: child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
            decoration: BoxDecoration(
                color: _cNeoBase,
                borderRadius: BorderRadius.circular(20),
                boxShadow: _p ? _cNeoInset : _cNeoBtnRaised),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(widget.icon, size: 12, color: widget.color),
              const SizedBox(width: 5),
              Text(widget.label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: widget.color)),
            ]),
          ),
        ),
      );
}

// ── Neo icon button ───────────────────────────────────────────────────────────
class _CtrIconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _CtrIconBtn({required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
            color: _cNeoBase,
            borderRadius: BorderRadius.circular(10),
            boxShadow: _cNeoBtnRaised),
        child: Icon(icon, color: color, size: 18),
      );
}

// ── Neo Card ──────────────────────────────────────────────────────────────────
class _CtrCard extends StatelessWidget {
  final List<Widget> children;
  const _CtrCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: _cNeoBase,
            borderRadius: BorderRadius.circular(22),
            boxShadow: _cNeoRaised),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
}

// ── Inset card ────────────────────────────────────────────────────────────────
class _CtrInsetCard extends StatelessWidget {
  final Widget child;
  const _CtrInsetCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
            color: _cNeoBase,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                  color: Color(0xFFD9C6B2),
                  blurRadius: 8,
                  offset: Offset(4, 4),
                  spreadRadius: -1),
              BoxShadow(
                  color: Colors.white,
                  blurRadius: 8,
                  offset: Offset(-4, -4),
                  spreadRadius: -1),
            ]),
        child: child,
      );
}

// ── Info row ──────────────────────────────────────────────────────────────────
class _CtrInfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label, value;
  final bool isLast;
  const _CtrInfoRow(
      {required this.icon,
      required this.iconColor,
      required this.label,
      required this.value,
      this.isLast = false});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
            border: isLast
                ? null
                : const Border(bottom: BorderSide(color: Color(0x0A000000)))),
        child: Row(children: [
          Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                  color: _cNeoBase,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: _cNeoBtnRaised),
              child: Icon(icon, color: iconColor, size: 15)),
          const SizedBox(width: 11),
          Expanded(
              child: Text(label,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFFA85428)))),
          Flexible(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF7A3E1E)),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
        ]),
      );
}

// ── Chip ──────────────────────────────────────────────────────────────────────
class _CtrChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _CtrChip(
      {required this.icon, required this.label, required this.color});
  @override
  State<_CtrChip> createState() => _CtrChipState();
}

class _CtrChipState extends State<_CtrChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _p = false;
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
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          HapticFeedback.selectionClick();
          setState(() => _p = true);
          _ctrl.forward();
        },
        onTapUp: (_) {
          setState(() => _p = false);
          _ctrl.reverse();
        },
        onTapCancel: () {
          setState(() => _p = false);
          _ctrl.reverse();
        },
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.06 * _ctrl.value, child: child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
                color: _cNeoBase,
                borderRadius: BorderRadius.circular(20),
                boxShadow: _p ? _cNeoInset : _cNeoBtnRaised),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(widget.icon, size: 14, color: widget.color),
              const SizedBox(width: 6),
              Text(widget.label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: widget.color)),
            ]),
          ),
        ),
      );
}

// ── Service row ───────────────────────────────────────────────────────────────
class _CtrServiceRow extends StatelessWidget {
  final ServiceModel service;
  final UserModel user;
  final CategoryModel? category;
  final VoidCallback onEdit, onDelete;
  const _CtrServiceRow(
      {required this.service,
      required this.user,
      required this.category,
      required this.onEdit,
      required this.onDelete});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0x0A000000)))),
        child: Row(children: [
          Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  color: Color(0xFFA85428), shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(service.name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7A3E1E))),
                _ServiceCategoryBadge(
                    category: category, color: const Color(0xFFA85428)),
                if (service.description.isNotEmpty)
                  Text(service.description,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFFA85428)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ])),
          Text('₪${service.price.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFA85428))),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (_) => Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                          color: _cNeoBase,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0xFFD9C6B2),
                                blurRadius: 20,
                                offset: Offset(8, 8)),
                            BoxShadow(
                                color: Colors.white,
                                blurRadius: 20,
                                offset: Offset(-8, -8))
                          ]),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const SizedBox(height: 14),
                        Center(
                            child: Container(
                                width: 40,
                                height: 5,
                                decoration: BoxDecoration(
                                    color: const Color(0xFFE0CFBC),
                                    borderRadius: BorderRadius.circular(3)))),
                        const SizedBox(height: 16),
                        ListTile(
                            leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                    color: _cNeoBase,
                                    borderRadius: BorderRadius.circular(11),
                                    boxShadow: _cNeoBtnRaised),
                                child: const Icon(Icons.edit_rounded,
                                    color: Color(0xFFA85428), size: 18)),
                            title: const Text('Edit',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF7A3E1E))),
                            onTap: () {
                              Navigator.pop(context);
                              onEdit();
                            }),
                        ListTile(
                            leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                    color: _cNeoBase,
                                    borderRadius: BorderRadius.circular(11),
                                    boxShadow: _cNeoBtnRaised),
                                child: const Icon(Icons.delete_outline_rounded,
                                    color: Color(0xFFA32D2D), size: 18)),
                            title: const Text('Delete',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFA32D2D))),
                            onTap: () {
                              Navigator.pop(context);
                              onDelete();
                            }),
                        const SizedBox(height: 16),
                      ]),
                    )),
            child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                    color: _cNeoBase,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: _cNeoBtnRaised),
                child: const Icon(Icons.more_vert_rounded,
                    size: 15, color: Color(0xFFC7B29C))),
          ),
        ]),
      );
}

// ── Service category badge ─────────────────────────────────────────────────────
// Small, secondary, single-line label showing the service's live Firestore
// category (never guessed from name/specialty). Renders nothing when the
// service has no categoryId, or that id doesn't match a currently loaded
// category — never shows a placeholder like "Unknown Category".
class _ServiceCategoryBadge extends StatelessWidget {
  final CategoryModel? category;
  final Color color;
  const _ServiceCategoryBadge({required this.category, required this.color});
  @override
  Widget build(BuildContext context) {
    final cat = category;
    if (cat == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final icon = cat.icon.trim();
    return Padding(
      padding: const EdgeInsets.only(top: 1, bottom: 2),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon.isNotEmpty) ...[
          Text(icon, style: const TextStyle(fontSize: 10)),
          const SizedBox(width: 3),
        ],
        Flexible(
          child: Text(l.get(cat.nameKey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ),
      ]),
    );
  }
}

// ── Rating bar ────────────────────────────────────────────────────────────────
// Reads the criterion's own maxRating (Firestore-configurable, no longer a
// hardcoded 5) so bars stay proportionally correct and never overflow.
double? _ctrCriterionScore(ReviewModel r, ReviewCriteriaModel c) {
  final v = r.criteriaRatings[c.id];
  if (v != null) return v;
  switch (c.name.trim().toLowerCase()) {
    case 'speed':
      return r.speedRating;
    case 'quality':
      return r.qualityRating;
    case 'communication':
      return r.communicationRating;
    default:
      return null;
  }
}

double _ctrAvgForCriterion(List<ReviewModel> reviews, ReviewCriteriaModel c) {
  final scores =
      reviews.map((r) => _ctrCriterionScore(r, c)).whereType<double>().toList();
  if (scores.isEmpty) return 0.0;
  return scores.reduce((a, b) => a + b) / scores.length;
}

class _CtrRatingBar extends StatelessWidget {
  final String label;
  final double value;
  final int maxRating;
  const _CtrRatingBar(
      {required this.label, required this.value, this.maxRating = 5});
  @override
  Widget build(BuildContext context) {
    final safeMax = maxRating > 0 ? maxRating : 5;
    final progress = (value / safeMax).clamp(0.0, 1.0);
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      SizedBox(
          width: 92,
          child: Text(label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Color(0xFFA85428)))),
      const SizedBox(width: 6),
      Expanded(
          child: Container(
              height: 6,
              decoration: BoxDecoration(
                  color: _cNeoBase,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0xFFD9C6B2),
                        blurRadius: 4,
                        offset: Offset(2, 2),
                        spreadRadius: -1),
                    BoxShadow(
                        color: Colors.white,
                        blurRadius: 4,
                        offset: Offset(-2, -2),
                        spreadRadius: -1)
                  ]),
              child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(
                      decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFDC7D4E), Color(0xFFA85428)]),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFFA85428).withOpacity(0.45),
                          blurRadius: 6,
                          offset: const Offset(0, 2))
                    ],
                  ))))),
      const SizedBox(width: 8),
      SizedBox(
          width: 30,
          child: Text(value.toStringAsFixed(1),
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF7A3E1E)),
              textAlign: TextAlign.right)),
    ]);
  }
}

// ── Review card ───────────────────────────────────────────────────────────────
class _CtrReviewCard extends ConsumerWidget {
  final ReviewModel review;
  final bool isLast;
  const _CtrReviewCard({required this.review, this.isLast = false});

  void _showReviewReport(BuildContext context, WidgetRef ref) {
    final subjectCtrl =
        TextEditingController(text: 'Unfair Review – ${review.customerName}');
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF6EFE6),
            borderRadius: BorderRadius.circular(32),
            boxShadow: const [
              BoxShadow(
                  color: Color(0xFFD9C6B2),
                  blurRadius: 20,
                  offset: Offset(8, 8)),
              BoxShadow(
                  color: Colors.white, blurRadius: 20, offset: Offset(-8, -8)),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Form(
              key: formKey,
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle + X
                    Row(children: [
                      Expanded(
                          child: Center(
                              child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                            color: const Color(0xFFD9C6B2),
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: const [
                              BoxShadow(
                                  color: Colors.white,
                                  blurRadius: 2,
                                  offset: Offset(-1, -1)),
                              BoxShadow(
                                  color: Color(0xFFD9C6B2),
                                  blurRadius: 2,
                                  offset: Offset(1, 1))
                            ]),
                      ))),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                            width: 34,
                            height: 34,
                            decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFF6EFE6),
                                boxShadow: [
                                  BoxShadow(
                                      color: Color(0xFFD9C6B2),
                                      blurRadius: 6,
                                      offset: Offset(3, 3)),
                                  BoxShadow(
                                      color: Colors.white,
                                      blurRadius: 6,
                                      offset: Offset(-3, -3))
                                ]),
                            child: const Icon(Icons.close_rounded,
                                size: 16, color: Color(0xFF9A8676))),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    // Title
                    Row(children: [
                      Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFF6EFE6),
                              boxShadow: [
                                BoxShadow(
                                    color: Color(0xFFD9C6B2),
                                    blurRadius: 8,
                                    offset: Offset(4, 4)),
                                BoxShadow(
                                    color: Colors.white,
                                    blurRadius: 8,
                                    offset: Offset(-4, -4))
                              ]),
                          child: const Icon(Icons.flag_rounded,
                              color: Color(0xFFEF4444), size: 22)),
                      const SizedBox(width: 14),
                      const Text('Report Review',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF7A3E1E))),
                    ]),
                    const SizedBox(height: 14),
                    // Review preview
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF6EFE6),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0xFFD9C6B2),
                                blurRadius: 6,
                                offset: Offset(3, 3)),
                            BoxShadow(
                                color: Colors.white,
                                blurRadius: 6,
                                offset: Offset(-3, -3))
                          ]),
                      child: Row(children: [
                        const Icon(Icons.star_rounded,
                            color: Color(0xFFFFCA28), size: 15),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(
                          '${review.customerName}  •  ${review.comment.isNotEmpty ? (review.comment.length > 40 ? "${review.comment.substring(0, 40)}..." : review.comment) : "No comment"}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFFA85428)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    const Text('Subject',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFA85428))),
                    const SizedBox(height: 8),
                    _CtrNeoInputField(
                        controller: subjectCtrl,
                        hint: 'Reason for reporting...',
                        icon: Icons.flag_outlined,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Please enter a subject'
                            : null),
                    const SizedBox(height: 14),
                    const Text('Details (Optional)',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFA85428))),
                    const SizedBox(height: 8),
                    _CtrNeoInputField(
                        controller: descCtrl,
                        hint: 'Describe why this review is unfair...',
                        icon: Icons.description_outlined,
                        maxLines: 3),
                    const SizedBox(height: 24),
                    _CtrNeoSendButton(
                      label: 'Send Report',
                      icon: Icons.send_rounded,
                      onTap: () async {
                        if (!formKey.currentState!.validate()) return;
                        Navigator.pop(ctx);
                        final currentUser = ref.read(authProvider);
                        if (currentUser == null) return;
                        final title = subjectCtrl.text.trim();
                        final description = descCtrl.text.trim();
                        try {
                          await addComplaintInFirestore(ComplaintModel(
                            id: '',
                            userId: currentUser.id,
                            userName: currentUser.fullName,
                            complainantRole: 'contractor',
                            type: ComplaintType.reviewReport,
                            targetId: review.id,
                            targetName: review.customerName,
                            targetUserId: review.customerId,
                            targetUserName: review.customerName,
                            targetUserRole: 'customer',
                            reason: title,
                            description: description,
                            relatedReviewId: review.id,
                            relatedProviderId: currentUser.id,
                            relatedProviderName: currentUser.fullName,
                            sourceContext: 'review_report',
                            createdAt: DateTime.now(),
                          ));
                          await reportReviewInFirestore(review.id, title);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: const Row(children: [
                                Icon(Icons.check_circle_rounded,
                                    color: Colors.white),
                                SizedBox(width: 8),
                                Text('Report submitted')
                              ]),
                              backgroundColor: const Color(0xFFA85428),
                              behavior: SnackBarBehavior.fixed,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ));
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Failed to submit report: $e')));
                          }
                        }
                      },
                    ),
                  ])),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avg = (review.speedRating +
            review.qualityRating +
            review.communicationRating) /
        3;
    final initials = review.customerName
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0] : '')
        .join();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: Color(0x0A000000)))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: _cNeoBase,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _cNeoBtnRaised),
              child: Center(
                  child: Text(initials,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFA85428))))),
          const SizedBox(width: 9),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(review.customerName,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF7A3E1E))),
                const SizedBox(height: 2),
                Row(children: [
                  ...List.generate(
                      5,
                      (i) => Icon(
                          i < avg.round()
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: const Color(0xFFFFCA28),
                          size: 11)),
                  const SizedBox(width: 5),
                  Text('${review.createdAt.day}/${review.createdAt.month}',
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFFC7B29C))),
                ]),
              ])),
          const SizedBox(width: 8),
          _CtrReviewFlagBtn(onTap: () => _showReviewReport(context, ref)),
        ]),
        if (review.comment.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(review.comment,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFFA85428), height: 1.5)),
          if (review.comment.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            ProviderContentTranslateAction(
              contentType: TranslationContentType.reviewComment,
              sourceDocId: review.id,
              currentSourceText: review.comment,
              entryLabelKey: 'translate_review',
            ),
          ],
        ],
      ]),
    );
  }
}

// ── Review Flag Button ────────────────────────────────────────────────────────
class _CtrReviewFlagBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _CtrReviewFlagBtn({required this.onTap});
  @override
  State<_CtrReviewFlagBtn> createState() => _CtrReviewFlagBtnState();
}

class _CtrReviewFlagBtnState extends State<_CtrReviewFlagBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _p = false;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          setState(() => _p = true);
          _ctrl.forward();
        },
        onTapUp: (_) {
          setState(() => _p = false);
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () {
          setState(() => _p = false);
          _ctrl.reverse();
        },
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.10 * _ctrl.value, child: child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _cNeoBase,
              borderRadius: BorderRadius.circular(11),
              boxShadow: _p
                  ? [
                      const BoxShadow(
                          color: Color(0xFFD9C6B2),
                          blurRadius: 4,
                          offset: Offset(2, 2),
                          spreadRadius: -1),
                      const BoxShadow(
                          color: Colors.white,
                          blurRadius: 4,
                          offset: Offset(-2, -2),
                          spreadRadius: -1)
                    ]
                  : _cNeoBtnRaised,
            ),
            child: Icon(_p ? Icons.flag_rounded : Icons.flag_outlined,
                color: _p ? const Color(0xFFEF4444) : const Color(0xFFC7B29C),
                size: 16),
          ),
        ),
      );
}

// ── Action row ────────────────────────────────────────────────────────────────
class _CtrActionRow extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color? labelColor;
  final bool isLast;
  final VoidCallback onTap;
  const _CtrActionRow(
      {required this.icon,
      required this.iconColor,
      required this.label,
      this.labelColor,
      this.isLast = false,
      required this.onTap});
  @override
  State<_CtrActionRow> createState() => _CtrActionRowState();
}

class _CtrActionRowState extends State<_CtrActionRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _p = false;
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
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          setState(() => _p = true);
          _ctrl.forward();
        },
        onTapUp: (_) {
          setState(() => _p = false);
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () {
          setState(() => _p = false);
          _ctrl.reverse();
        },
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.02 * _ctrl.value, child: child),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
                border: widget.isLast
                    ? null
                    : const Border(
                        bottom: BorderSide(color: Color(0x0A000000)))),
            child: Row(children: [
              AnimatedContainer(
                  duration: const Duration(milliseconds: 80),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: _cNeoBase,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: _p ? _cNeoInset : _cNeoBtnRaised),
                  child: Icon(widget.icon, color: widget.iconColor, size: 18)),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(widget.label,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color:
                              widget.labelColor ?? const Color(0xFF7A3E1E)))),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 13, color: Color(0xFFC7B29C)),
            ]),
          ),
        ),
      );
}
// ─── Sheet & Form Helper Widgets (used by edit sheets) ───────────────────────

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: const Color(0xFFDC7D4E).withOpacity(0.4),
                borderRadius: BorderRadius.circular(2))),
      );
}

class _SheetTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SheetTitle({required this.title, required this.icon});
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF7A3E1E), Color(0xFFA85428)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: Colors.white, size: 20)),
        const SizedBox(width: 12),
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF7A3E1E)))),
      ]);
}

class _SaveBtn extends StatelessWidget {
  final VoidCallback onSave;
  const _SaveBtn({required this.onSave});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: onSave,
          icon: const Icon(Icons.save_alt_rounded, size: 18),
          label: Text(AppLocalizations.of(context).get('save_changes'),
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7A3E1E),
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );
}

class _FieldWidget extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final bool required;
  final TextInputType? keyboard;
  final int maxLines;
  const _FieldWidget(
      {required this.ctrl,
      required this.label,
      required this.icon,
      this.required = false,
      this.keyboard,
      this.maxLines = 1});
  @override
  Widget build(BuildContext context) => TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        maxLines: maxLines,
        validator: required
            ? (v) => (v == null || v.trim().isEmpty)
                ? AppLocalizations.of(context).get('required_field')
                : null
            : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 18, color: const Color(0xFFA85428)),
          filled: true,
          fillColor: const Color(0xFFFDF6EC),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: const Color(0xFFDC7D4E).withOpacity(0.4))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: const Color(0xFFDC7D4E).withOpacity(0.35))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFA85428), width: 2)),
          labelStyle: const TextStyle(
              color: Color(0xFFA85428),
              fontSize: 13,
              fontWeight: FontWeight.w500),
        ),
      );
}

class _Field {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final bool required;
  final TextInputType? keyboard;
  final int maxLines;
  const _Field(
      {required this.ctrl,
      required this.label,
      required this.icon,
      this.required = false,
      this.keyboard,
      this.maxLines = 1});
}

// ── Categories helper ─────────────────────────────────────────────────────────
// ── Section three-dots menu trigger ───────────────────────────────────────────
class _CtrNeoDotsBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _CtrNeoDotsBtn({required this.onTap});
  @override
  State<_CtrNeoDotsBtn> createState() => _CtrNeoDotsBtnState();
}

class _CtrNeoDotsBtnState extends State<_CtrNeoDotsBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _p = false;
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
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          setState(() => _p = true);
          _ctrl.forward();
        },
        onTapUp: (_) {
          setState(() => _p = false);
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () {
          setState(() => _p = false);
          _ctrl.reverse();
        },
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.07 * _ctrl.value, child: child),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _cNeoBase,
              borderRadius: BorderRadius.circular(11),
              boxShadow: _p ? _cNeoInset : _cNeoBtnRaised,
            ),
            child: const Icon(Icons.more_vert_rounded,
                size: 18, color: Color(0xFFA85428)),
          ),
        ),
      );
}

// ── Neo Specialty Action Button (used by the Services & Prices "Add" action) ──
class _CtrNeoSpecialtyBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _CtrNeoSpecialtyBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
  @override
  State<_CtrNeoSpecialtyBtn> createState() => _CtrNeoSpecialtyBtnState();
}

class _CtrNeoSpecialtyBtnState extends State<_CtrNeoSpecialtyBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _p = false;
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
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          setState(() => _p = true);
          _ctrl.forward();
        },
        onTapUp: (_) {
          setState(() => _p = false);
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () {
          setState(() => _p = false);
          _ctrl.reverse();
        },
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.07 * _ctrl.value, child: child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: _cNeoBase,
              borderRadius: BorderRadius.circular(20),
              boxShadow: _p ? _cNeoInset : _cNeoBtnRaised,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: _cNeoBase,
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: _p ? _cNeoInset : _cNeoBtnRaised,
                ),
                child: Icon(widget.icon, size: 12, color: widget.color),
              ),
              const SizedBox(width: 7),
              Text(widget.label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: widget.color)),
            ]),
          ),
        ),
      );
}

// ── Neo Specialty Chip (display) ──────────────────────────────────────────────
class _CtrNeoChip extends StatelessWidget {
  final String emoji, label;
  final Color color;
  const _CtrNeoChip(
      {required this.emoji, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _cNeoBase,
          borderRadius: BorderRadius.circular(20),
          boxShadow: _cNeoBtnRaised,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ]),
      );
}

// ── Edit Specialties Full Screen ──────────────────────────────────────────────
class _CtrEditSpecialtiesScreen extends ConsumerStatefulWidget {
  final UserModel user;
  const _CtrEditSpecialtiesScreen({required this.user});
  @override
  ConsumerState<_CtrEditSpecialtiesScreen> createState() =>
      _CtrEditSpecialtiesScreenState();
}

class _CtrEditSpecialtiesScreenState
    extends ConsumerState<_CtrEditSpecialtiesScreen> {
  late List<String> _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.user.specialties);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cats = ref.watch(categoriesProvider).value ?? [];
    return Scaffold(
      backgroundColor: _cNeoBase,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            backgroundColor: const Color(0xFF7A3E1E),
            foregroundColor: Colors.white,
            elevation: 0,
            automaticallyImplyLeading: false,
            leading: _CtrNeoBackBtnWhite(),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: _CtrNeoSaveSpecialtiesBtn(
                    count: _selected.length, saving: _saving, onTap: _save),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  // Contractor brand gradient — onBrand ink, not white.
                  gradient: ContractorColors.brandGradient,
                  borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28)),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 46, 20, 16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text('Edit Specialties',
                              style: TextStyle(
                                  color: ContractorColors.onBrand,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5)),
                          const SizedBox(height: 4),
                          Text('${_selected.length} selected · tap to toggle',
                              style: const TextStyle(
                                  color: ContractorColors.onBrandMuted,
                                  fontSize: 13)),
                        ]),
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.82,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final cat = cats[i];
                  final key = cat.nameKey;
                  final sel = _selected.contains(key);
                  return _CtrNeoSpecialtyCard(
                    emoji: cat.icon,
                    label: l.get(cat.nameKey),
                    selected: sel,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (sel)
                          _selected.remove(key);
                        else
                          _selected.add(key);
                      });
                    },
                  );
                },
                childCount: cats.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  void _save() async {
    setState(() => _saving = true);
    await ref.read(authProvider.notifier).saveSpecialties(_selected.toList());
    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.white),
          SizedBox(width: 8),
          Text('Specialties saved')
        ]),
        backgroundColor: const Color(0xFFA85428),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }
}

// ── Specialty Grid Card ───────────────────────────────────────────────────────
class _CtrNeoSpecialtyCard extends StatefulWidget {
  final String emoji, label;
  final bool selected;
  final VoidCallback onTap;
  const _CtrNeoSpecialtyCard(
      {required this.emoji,
      required this.label,
      required this.selected,
      required this.onTap});
  @override
  State<_CtrNeoSpecialtyCard> createState() => _CtrNeoSpecialtyCardState();
}

class _CtrNeoSpecialtyCardState extends State<_CtrNeoSpecialtyCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _p = false;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 130));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          setState(() => _p = true);
          _ctrl.forward();
        },
        onTapUp: (_) {
          setState(() => _p = false);
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () {
          setState(() => _p = false);
          _ctrl.reverse();
        },
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.04 * _ctrl.value, child: child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: _cNeoBase,
              border: widget.selected
                  ? Border.all(color: const Color(0xFFA85428), width: 2.5)
                  : Border.all(color: Colors.transparent, width: 2.5),
              boxShadow: _p
                  ? [
                      const BoxShadow(
                          color: Color(0xFFD9C6B2),
                          blurRadius: 6,
                          offset: Offset(2, 2)),
                      const BoxShadow(
                          color: Colors.white,
                          blurRadius: 6,
                          offset: Offset(-2, -2)),
                    ]
                  : [
                      const BoxShadow(
                          color: Color(0xFFD9C6B2),
                          blurRadius: 14,
                          offset: Offset(6, 6)),
                      const BoxShadow(
                          color: Colors.white,
                          blurRadius: 14,
                          offset: Offset(-6, -6)),
                    ],
            ),
            child: Stack(children: [
              if (widget.selected)
                Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                          color: Color(0xFFA85428),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Color(0x55A85428),
                                blurRadius: 6,
                                offset: Offset(0, 2))
                          ]),
                      child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 11),
                    )),
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: _cNeoBase,
                          boxShadow: widget.selected
                              ? [
                                  const BoxShadow(
                                      color: Color(0x55A85428),
                                      blurRadius: 10,
                                      offset: Offset(0, 4)),
                                ]
                              : _p
                                  ? [
                                      const BoxShadow(
                                          color: Color(0xFFD9C6B2),
                                          blurRadius: 4,
                                          offset: Offset(2, 2)),
                                      const BoxShadow(
                                          color: Colors.white,
                                          blurRadius: 4,
                                          offset: Offset(-2, -2)),
                                    ]
                                  : [
                                      const BoxShadow(
                                          color: Color(0xFFD9C6B2),
                                          blurRadius: 8,
                                          offset: Offset(4, 4)),
                                      const BoxShadow(
                                          color: Colors.white,
                                          blurRadius: 8,
                                          offset: Offset(-4, -4)),
                                    ],
                        ),
                        child: Center(
                            child: Text(widget.emoji,
                                style: const TextStyle(fontSize: 26))),
                      ),
                      const SizedBox(height: 8),
                      Text(widget.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: widget.selected
                                ? const Color(0xFFA85428)
                                : const Color(0xFFA8927F),
                            letterSpacing: 0.1,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ]),
              ),
            ]),
          ),
        ),
      );
}

// ── Save button for specialties screen ───────────────────────────────────────
class _CtrNeoSaveSpecialtiesBtn extends StatefulWidget {
  final int count;
  final bool saving;
  final VoidCallback onTap;
  const _CtrNeoSaveSpecialtiesBtn(
      {required this.count, required this.saving, required this.onTap});
  @override
  State<_CtrNeoSaveSpecialtiesBtn> createState() => _CtrNeoSaveBtnState();
}

class _CtrNeoSaveBtnState extends State<_CtrNeoSaveSpecialtiesBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
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
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          if (!widget.saving) {
            HapticFeedback.mediumImpact();
            _ctrl.forward();
          }
        },
        onTapUp: (_) {
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.07 * _ctrl.value, child: child),
          // Sits on the brand gradient header — white scrim + onBrand ink.
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.42),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: Colors.white.withOpacity(0.65), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: ContractorColors.darkest.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(2, 3)),
                BoxShadow(
                    color: Colors.white.withOpacity(0.35),
                    blurRadius: 4,
                    offset: const Offset(-1, -1)),
              ],
            ),
            child: widget.saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: ContractorColors.onBrand, strokeWidth: 2))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check_rounded,
                        color: ContractorColors.onBrand, size: 16),
                    const SizedBox(width: 6),
                    Text('Save (${widget.count})',
                        style: const TextStyle(
                            color: ContractorColors.onBrand,
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                  ]),
          ),
        ),
      );
}

// ── Neo Back Button (white, for full screens) ─────────────────────────────────
class _CtrNeoBackBtnWhite extends StatefulWidget {
  @override
  State<_CtrNeoBackBtnWhite> createState() => _CtrNeoBackBtnWhiteState();
}

class _CtrNeoBackBtnWhiteState extends State<_CtrNeoBackBtnWhite>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 110));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          _ctrl.forward();
        },
        onTapUp: (_) {
          _ctrl.reverse();
          Navigator.of(context).pop();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, child) =>
                Transform.scale(scale: 1.0 - 0.08 * _ctrl.value, child: child),
            // Sits on the brand gradient header, so it uses a white scrim
            // with onBrand ink rather than white-on-translucent.
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.42),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                    color: Colors.white.withOpacity(0.65), width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: ContractorColors.darkest.withOpacity(0.22),
                      blurRadius: 0,
                      offset: const Offset(0, 3)),
                  BoxShadow(
                      color: ContractorColors.darkest.withOpacity(0.14),
                      blurRadius: 8,
                      offset: const Offset(3, 4)),
                  BoxShadow(
                      color: Colors.white.withOpacity(0.35),
                      blurRadius: 6,
                      offset: const Offset(-2, -2)),
                ],
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: ContractorColors.onBrand, size: 18),
            ),
          ),
        ),
      );
}

// ── Neo Input Field for contractor sheets ─────────────────────────────────────
class _CtrNeoInputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool required;
  final TextInputType? keyboard;
  final int maxLines;
  final String? Function(String?)? validator;
  const _CtrNeoInputField(
      {required this.controller,
      required this.hint,
      required this.icon,
      this.required = false,
      this.keyboard,
      this.maxLines = 1,
      this.validator});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: _cNeoBase,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: Color(0xFFD9C6B2), blurRadius: 6, offset: Offset(3, 3)),
            BoxShadow(
                color: Colors.white, blurRadius: 6, offset: Offset(-3, -3)),
          ],
        ),
        child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboard,
          style: const TextStyle(fontSize: 14, color: Color(0xFF7A3E1E)),
          validator: validator ??
              (required
                  ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
                  : null),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFC7B29C), fontSize: 13),
            prefixIcon: Icon(icon, color: const Color(0xFFA85428), size: 19),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      );
}

// ── Neo Send / Save Button for contractor sheets ──────────────────────────────
class _CtrNeoSendButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool loading;
  const _CtrNeoSendButton(
      {required this.label,
      required this.icon,
      required this.onTap,
      this.loading = false});
  @override
  State<_CtrNeoSendButton> createState() => _CtrNeoSendButtonState();
}

class _CtrNeoSendButtonState extends State<_CtrNeoSendButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _p = false;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 110));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          if (!widget.loading) {
            HapticFeedback.mediumImpact();
            setState(() => _p = true);
            _ctrl.forward();
          }
        },
        onTapUp: (_) {
          setState(() => _p = false);
          _ctrl.reverse();
          if (!widget.loading) widget.onTap();
        },
        onTapCancel: () {
          setState(() => _p = false);
          _ctrl.reverse();
        },
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.03 * _ctrl.value, child: child),
          child: Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(27),
              gradient: const LinearGradient(
                  colors: [Color(0xFF7A3E1E), Color(0xFFA85428)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              boxShadow: _p
                  ? [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 4,
                          offset: const Offset(2, 2))
                    ]
                  : [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.38),
                          blurRadius: 0,
                          offset: const Offset(0, 5)),
                      BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 8)),
                      BoxShadow(
                          color: Colors.white.withOpacity(0.07),
                          blurRadius: 4,
                          offset: const Offset(0, -2))
                    ],
            ),
            child: Stack(alignment: Alignment.center, children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 27,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(27),
                        topRight: Radius.circular(27)),
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.12),
                          Colors.transparent
                        ]),
                  ),
                ),
              ),
              if (widget.loading)
                const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
              else
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(widget.icon, color: Colors.white, size: 17),
                  const SizedBox(width: 8),
                  Text(widget.label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3)),
                ]),
            ]),
          ),
        ),
      );
}

// ── Neo Text Field for contractor sheets ─────────────────────────────────────
class _CtrNeoField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final bool required;
  final TextInputType? keyboard;
  final int maxLines;
  const _CtrNeoField(
      {required this.ctrl,
      required this.label,
      required this.icon,
      this.required = false,
      this.keyboard,
      this.maxLines = 1});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFFA85428))),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF6EFE6),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                  color: Color(0xFFD9C6B2),
                  blurRadius: 6,
                  offset: Offset(3, 3)),
              BoxShadow(
                  color: Colors.white, blurRadius: 6, offset: Offset(-3, -3)),
            ],
          ),
          child: TextFormField(
            controller: ctrl,
            maxLines: maxLines,
            keyboardType: keyboard,
            style: const TextStyle(fontSize: 14, color: Color(0xFF7A3E1E)),
            validator: required
                ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
                : null,
            decoration: InputDecoration(
              hintText: label,
              hintStyle:
                  const TextStyle(color: Color(0xFFC7B29C), fontSize: 13),
              prefixIcon: Icon(icon, color: const Color(0xFFA85428), size: 19),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ]);
}

// ── Contractor Notification Model ────────────────────────────────────────────
class _CtrNotif {
  final IconData icon;
  final Color iconColor;
  final Color bg;
  final String title;
  final String subtitle;
  final String time;
  final bool isNew;
  final String notifType; // 'order', 'message', 'worker', 'rating', 'reminder'
  final String? relatedOrderId;
  const _CtrNotif({
    required this.icon,
    required this.iconColor,
    required this.bg,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.isNew,
    this.notifType = 'other',
    this.relatedOrderId,
  });
}

// ── Contractor Notifications Page ─────────────────────────────────────────────
class _ContractorNotificationsPage extends ConsumerWidget {
  const _ContractorNotificationsPage();

  static const _notifs = [
    _CtrNotif(
      icon: Icons.assignment_rounded,
      iconColor: Color(0xFFFFB800),
      bg: Color(0xFFFFF8E1),
      title: 'New project request',
      subtitle: 'Sami Arab — Build Exterior Wall',
      time: '15 min ago',
      isNew: true,
      notifType: 'order',
      relatedOrderId: 'cd1',
    ),
    _CtrNotif(
      icon: Icons.chat_bubble_rounded,
      iconColor: Color(0xFFA85428),
      bg: Color(0xFFFFDD8D),
      title: 'New Message',
      subtitle: 'Layla Hassan sent you a message',
      time: '30 min ago',
      isNew: true,
      notifType: 'message',
      relatedOrderId: 'cd5',
    ),
    _CtrNotif(
      icon: Icons.engineering_rounded,
      iconColor: Color(0xFF7A3E1E),
      bg: Color(0xFFFDF6EC),
      title: 'Worker assigned',
      subtitle: 'Khalid Nassar assigned to Kitchen Installation',
      time: '1 hour ago',
      isNew: true,
      notifType: 'worker',
      relatedOrderId: 'cd5',
    ),
    _CtrNotif(
      icon: Icons.check_circle_rounded,
      iconColor: Color(0xFF00C853),
      bg: Color(0xFFE8F5E9),
      title: 'Project completed',
      subtitle: 'New Apartment Finishing — Akka',
      time: '2 hours ago',
      isNew: false,
      notifType: 'order',
      relatedOrderId: 'cd3',
    ),
    _CtrNotif(
      icon: Icons.info_rounded,
      iconColor: Color(0xFFA85428),
      bg: Color(0xFFFFDD8D),
      title: 'Reminder: Project scheduled today',
      subtitle: 'Wooden Kitchen Installation — Haifa 14:30',
      time: 'Today 09:00',
      isNew: false,
      notifType: 'reminder',
      relatedOrderId: 'cd5',
    ),
  ];

  void _handleTap(BuildContext context, WidgetRef ref, _CtrNotif n) {
    final allOrders = ref.read(ordersProvider);
    if ((n.notifType == 'order' ||
            n.notifType == 'reminder' ||
            n.notifType == 'worker') &&
        n.relatedOrderId != null) {
      final order = allOrders
          .cast<OrderModel?>()
          .firstWhere((o) => o?.id == n.relatedOrderId, orElse: () => null);
      if (order != null) {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ContractorOrderDetailScreen(order: order)));
        return;
      }
    }
    if (n.notifType == 'message' && n.relatedOrderId != null) {
      final order = allOrders
          .cast<OrderModel?>()
          .firstWhere((o) => o?.id == n.relatedOrderId, orElse: () => null);
      if (order != null) {
        final customer = UserModel(
          id: order.customerId,
          fullName:
              order.customerName.isNotEmpty ? order.customerName : 'Customer',
          email: '',
          phone: '',
          city: order.area,
          role: UserRole.customer,
        );
        ref.read(conversationsProvider.notifier).startConversation(customer);
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ContractorChatScreen(otherUser: customer)));
        return;
      }
    }
    // Fallback: go back to home
    Navigator.of(context).pop();
    ref.read(navIndexProvider.notifier).state = 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newCount = _notifs.where((n) => n.isNew).length;
    return Scaffold(
      backgroundColor: _B.warm,
      appBar: AppBar(
        title: const Text('Notifications',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontSize: 17)),
        backgroundColor: _B.darkest,
        elevation: 0,
        centerTitle: false,
        leading: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        actions: [
          if (newCount > 0)
            Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12)),
              child: Text('$newCount new',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        itemCount: _notifs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final n = _notifs[i];
          return GestureDetector(
            onTap: () => _handleTap(context, ref, n),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: n.isNew ? const Color(0xFFFDF6EC) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: n.isNew
                        ? _B.mid.withOpacity(0.45)
                        : _B.mid.withOpacity(0.2),
                    width: 1.2),
                boxShadow: [
                  BoxShadow(
                      color: _B.darkest.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3)),
                ],
              ),
              child: Row(children: [
                Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                        color: n.bg, borderRadius: BorderRadius.circular(14)),
                    child: Icon(n.icon, color: n.iconColor, size: 22)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        Expanded(
                            child: Text(n.title,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: n.isNew ? _B.darkest : _B.dark))),
                        if (n.isNew)
                          Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                  color: _B.dark, shape: BoxShape.circle)),
                      ]),
                      const SizedBox(height: 4),
                      Text(n.subtitle,
                          style: TextStyle(
                              fontSize: 12,
                              color: _B.dark.withOpacity(0.75),
                              height: 1.3)),
                      const SizedBox(height: 4),
                      Text(n.time,
                          style: TextStyle(
                              fontSize: 11,
                              color: _B.dark.withOpacity(0.55),
                              fontWeight: FontWeight.w500)),
                    ])),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded,
                    color: _B.mid.withOpacity(0.6), size: 18),
              ]),
            ),
          );
        },
      ),
    );
  }
}

// ── Contractor Quick Action Tile ──────────────────────────────────────────────
class _ContractorQuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ContractorQuickAction(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: color, size: 18)),
        title: Text(label,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: color)),
        trailing: Icon(Icons.chevron_right_rounded, color: _B.mid, size: 18),
      );
}

class ContractorComplaintsPage extends ConsumerStatefulWidget {
  // Set from a notification tap so the matching complaint's tab is
  // auto-selected and its card is visually highlighted on open.
  final String? highlightComplaintId;
  const ContractorComplaintsPage({super.key, this.highlightComplaintId});
  @override
  ConsumerState<ContractorComplaintsPage> createState() =>
      _ContractorComplaintsPageState();
}

class _ContractorComplaintsPageState
    extends ConsumerState<ContractorComplaintsPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _tabAnim;
  int _selectedTab = 0; // 0 = Pending, 1 = Resolved, 2 = Rejected
  bool _initialComplaintOpened = false;

  @override
  void initState() {
    super.initState();
    _tabAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400))
      ..forward();
  }

  @override
  void dispose() {
    _tabAnim.dispose();
    super.dispose();
  }

  void _openNewComplaintSheet() {
    final user = ref.read(authProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 12,
            right: 12),
        child: _CtrNewComplaintSheet(user: user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final complaintsAsync = ref.watch(userComplaintsProvider(user?.id ?? ''));
    final loading =
        complaintsAsync.isLoading && complaintsAsync.valueOrNull == null;
    final hasError = complaintsAsync.hasError;
    final allComplaints =
        complaintsAsync.valueOrNull ?? const <ComplaintModel>[];
    final pending = allComplaints
        .where((c) =>
            c.status == ComplaintStatus.open ||
            c.status == ComplaintStatus.inReview)
        .toList();
    final resolved = allComplaints
        .where((c) => c.status == ComplaintStatus.resolved)
        .toList();
    final rejected = allComplaints
        .where((c) => c.status == ComplaintStatus.rejected)
        .toList();

    // A notification tap may pass a specific complaint to open — jump to
    // whichever tab it lives in and auto-open its details dialog once, the
    // first time it shows up in the stream, so the user's own later tab taps
    // and dialog opens/closes aren't overridden.
    if (widget.highlightComplaintId != null && !_initialComplaintOpened) {
      final match = allComplaints
          .where((c) => c.id == widget.highlightComplaintId)
          .toList();
      if (match.isNotEmpty) {
        _initialComplaintOpened = true;
        final matchedComplaint = match.first;
        final targetTab = matchedComplaint.status == ComplaintStatus.resolved
            ? 1
            : matchedComplaint.status == ComplaintStatus.rejected
                ? 2
                : 0;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (targetTab != _selectedTab) {
            setState(() => _selectedTab = targetTab);
          }
          showComplaintDetailsDialog(context, matchedComplaint,
              accentColor: const Color(0xFFA85428));
        });
      }
    }

    final list = _selectedTab == 0
        ? pending
        : _selectedTab == 1
            ? resolved
            : rejected;

    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F1),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Header ────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 130,
            backgroundColor: const Color(0xFF7A3E1E),
            foregroundColor: Colors.white,
            elevation: 0,
            automaticallyImplyLeading: false,
            leading: _CtrNeoBackBtnWhite(),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 14, top: 8, bottom: 8),
                child: _CtrComplaintsNewBtn(onTap: _openNewComplaintSheet),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  // Contractor brand gradient — onBrand ink, not white.
                  gradient: ContractorColors.brandGradient,
                  borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28)),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(children: [
                            Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.42),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.65),
                                      width: 1),
                                ),
                                child: const Icon(Icons.flag_rounded,
                                    color: ContractorColors.onBrand, size: 22)),
                            const SizedBox(width: 12),
                            const Text('My Complaints',
                                style: TextStyle(
                                    color: ContractorColors.onBrand,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5)),
                          ]),
                        ]),
                  ),
                ),
              ),
            ),
          ),

          // ── Pill tab selector ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: _CtrComplaintsStepBar(
                selectedIndex: _selectedTab,
                pendingCount: pending.length,
                resolvedCount: resolved.length,
                rejectedCount: rejected.length,
                onTap: (i) => setState(() {
                  _selectedTab = i;
                  _tabAnim.forward(from: 0);
                }),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── List ───────────────────────────────────────────────────────
          if (loading)
            const SliverFillRemaining(
              child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFA85428))),
            )
          else if (hasError)
            const SliverFillRemaining(
              child: Center(
                child: Text('Failed to load complaints',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7A3E1E))),
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
                        color: Color(0xFFF6EFE6),
                        borderRadius: BorderRadius.all(Radius.circular(26)),
                        boxShadow: [
                          BoxShadow(
                              color: Color(0xFFD9C6B2),
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
                              ? Icons.flag_outlined
                              : _selectedTab == 1
                                  ? Icons.history_rounded
                                  : Icons.cancel_outlined,
                          size: 36,
                          color: const Color(0xFFA85428)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _selectedTab == 0
                          ? 'No pending complaints'
                          : _selectedTab == 1
                              ? 'No resolved complaints'
                              : 'No rejected complaints',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7A3E1E)),
                    ),
                  ])),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _CtrComplaintNeo3DCard(
                    complaint: list[i],
                    highlighted: list[i].id == widget.highlightComplaintId,
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

// ── Contractor Complaints Pill Tab Bar ────────────────────────────────────────
class _CtrComplaintsStepBar extends StatefulWidget {
  final int selectedIndex, pendingCount, resolvedCount, rejectedCount;
  final void Function(int) onTap;
  const _CtrComplaintsStepBar(
      {required this.selectedIndex,
      required this.pendingCount,
      required this.resolvedCount,
      required this.rejectedCount,
      required this.onTap});
  @override
  State<_CtrComplaintsStepBar> createState() => _CtrComplaintsStepBarState();
}

class _CtrComplaintsStepBarState extends State<_CtrComplaintsStepBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideCtrl;
  static const _tabData = [
    (
      label: 'Pending',
      icon: Icons.hourglass_top_rounded,
      activeColor: Color(0xFFF59E0B),
      darkColor: Color(0xFFB45309)
    ),
    (
      label: 'Resolved',
      icon: Icons.check_circle_outline_rounded,
      activeColor: Color(0xFFA85428),
      darkColor: Color(0xFFA85428)
    ),
    (
      label: 'Rejected',
      icon: Icons.cancel_outlined,
      activeColor: Color(0xFFEF4444),
      darkColor: Color(0xFF991B1B)
    ),
  ];
  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void didUpdateWidget(_CtrComplaintsStepBar old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex != widget.selectedIndex) _slideCtrl.forward(from: 0);
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final counts = [
      widget.pendingCount,
      widget.resolvedCount,
      widget.rejectedCount
    ];
    return Container(
      height: 56,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF6EFE6),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
              color: Color(0xFFD9C6B2), blurRadius: 0, offset: Offset(0, 5)),
          BoxShadow(
              color: Color(0xFFD9C6B2), blurRadius: 14, offset: Offset(6, 6)),
          BoxShadow(
              color: Colors.white, blurRadius: 14, offset: Offset(-6, -6)),
        ],
      ),
      child: Row(
          children: List.generate(3, (i) {
        final isActive = widget.selectedIndex == i;
        final tab = _tabData[i];
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onTap(i);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                color: isActive ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(23),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                            color: tab.activeColor.withOpacity(0.18),
                            blurRadius: 12,
                            offset: const Offset(0, 4)),
                        const BoxShadow(
                            color: Color(0xFFD9C6B2),
                            blurRadius: 4,
                            offset: Offset(2, 2)),
                        const BoxShadow(
                            color: Colors.white,
                            blurRadius: 4,
                            offset: Offset(-2, -2)),
                      ]
                    : [],
              ),
              child: Center(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  width: isActive ? 28 : 22,
                  height: isActive ? 28 : 22,
                  decoration: BoxDecoration(
                    gradient: isActive
                        ? LinearGradient(
                            colors: [tab.activeColor, tab.darkColor],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight)
                        : null,
                    color: isActive ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(isActive ? 9 : 7),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                                color: tab.activeColor.withOpacity(0.45),
                                blurRadius: 6,
                                offset: const Offset(0, 3)),
                            BoxShadow(
                                color: tab.darkColor,
                                blurRadius: 0,
                                offset: const Offset(0, 2)),
                          ]
                        : [],
                  ),
                  child: Center(
                      child: Icon(tab.icon,
                          size: isActive ? 15 : 13,
                          color: isActive
                              ? Colors.white
                              : const Color(0xFFA8927F))),
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 220),
                    style: TextStyle(
                        fontSize: isActive ? 13 : 12,
                        fontWeight:
                            isActive ? FontWeight.w800 : FontWeight.w600,
                        color: isActive
                            ? const Color(0xFF33200F)
                            : const Color(0xFFA8927F),
                        letterSpacing: -0.2),
                    child: Text(tab.label,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
                if (counts[i] > 0) ...[
                  const SizedBox(width: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color:
                          isActive ? tab.activeColor : const Color(0xFFD9C6B2),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                  color: tab.activeColor.withOpacity(0.4),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2)),
                              BoxShadow(
                                  color: tab.darkColor,
                                  blurRadius: 0,
                                  offset: const Offset(0, 2)),
                            ]
                          : [],
                    ),
                    child: Text('${counts[i]}',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isActive
                                ? Colors.white
                                : const Color(0xFF6E5645))),
                  ),
                ],
              ])),
            ),
          ),
        );
      })),
    );
  }
}

// ── New Complaint button (header) ─────────────────────────────────────────────
class _CtrComplaintsNewBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _CtrComplaintsNewBtn({required this.onTap});
  @override
  State<_CtrComplaintsNewBtn> createState() => _CtrComplaintsNewBtnState();
}

class _CtrComplaintsNewBtnState extends State<_CtrComplaintsNewBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 110));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          _c.forward();
        },
        onTapUp: (_) {
          _c.reverse();
          widget.onTap();
        },
        onTapCancel: () => _c.reverse(),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.08 * _c.value, child: child),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFF6EFE6),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                    color: Color(0xFFD9C6B2),
                    blurRadius: 0,
                    offset: Offset(0, 4)),
                BoxShadow(
                    color: Color(0xFFD9C6B2),
                    blurRadius: 8,
                    offset: Offset(4, 4)),
                BoxShadow(
                    color: Colors.white, blurRadius: 8, offset: Offset(-4, -4)),
              ],
              border:
                  Border.all(color: Colors.white.withOpacity(0.9), width: 1),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_rounded, color: Color(0xFFA85428), size: 16),
              SizedBox(width: 5),
              Text('New',
                  style: TextStyle(
                      color: Color(0xFFA85428),
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      );
}

// ── Contractor Complaint Neo 3D Card ──────────────────────────────────────────
class _CtrComplaintNeo3DCard extends ConsumerStatefulWidget {
  final ComplaintModel complaint;
  final bool highlighted;
  const _CtrComplaintNeo3DCard(
      {required this.complaint, this.highlighted = false});
  @override
  ConsumerState<_CtrComplaintNeo3DCard> createState() =>
      _CtrComplaintNeo3DCardState();
}

class _CtrComplaintNeo3DCardState extends ConsumerState<_CtrComplaintNeo3DCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _dotsCtrl;

  static const _statusColors = {
    ComplaintStatus.open: Color(0xFFF59E0B),
    ComplaintStatus.inReview: Color(0xFFA85428),
    ComplaintStatus.resolved: Color(0xFF5DCAA5),
    ComplaintStatus.rejected: Color(0xFFEF4444),
    ComplaintStatus.deleted: Color(0xFFC7B29C),
  };
  static const _statusLabels = {
    ComplaintStatus.open: 'Pending',
    ComplaintStatus.inReview: 'In Review',
    ComplaintStatus.resolved: 'Resolved',
    ComplaintStatus.rejected: 'Rejected',
    ComplaintStatus.deleted: 'Deleted',
  };

  bool get _canEditOrDelete =>
      widget.complaint.status == ComplaintStatus.open ||
      widget.complaint.status == ComplaintStatus.inReview;

  @override
  void initState() {
    super.initState();
    _dotsCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
  }

  @override
  void dispose() {
    _dotsCtrl.dispose();
    super.dispose();
  }

  void _openDotsMenu() {
    HapticFeedback.lightImpact();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        final box = context.findRenderObject() as RenderBox?;
        final pos = box?.localToGlobal(Offset.zero);
        final screenH = MediaQuery.of(ctx).size.height;
        const panelH = 2 * 58.0 + 20;
        double topPos = (pos?.dy ?? 200) + 10;
        if (topPos + panelH > screenH - 16)
          topPos = (pos?.dy ?? 200) - panelH + 10;
        topPos = topPos.clamp(16.0, screenH - panelH - 16);
        return Stack(children: [
          Positioned.fill(
              child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(color: Colors.transparent))),
          Positioned(
            top: topPos,
            right: 20,
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(0.4, -0.2), end: Offset.zero)
                  .animate(curved),
              child: FadeTransition(
                  opacity: anim,
                  child: _CtrComplaintDotsPanel(
                    onEdit: () {
                      Navigator.pop(ctx);
                      _openEditSheet();
                    },
                    onDelete: () {
                      Navigator.pop(ctx);
                      _confirmDelete();
                    },
                  )),
            ),
          ),
        ]);
      },
    );
  }

  void _openEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 12,
            right: 12),
        child: _CtrNewComplaintSheet(existing: widget.complaint),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Complaint',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Are you sure you want to delete this complaint?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFFA85428)))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await softDeleteComplaintInFirestore(widget.complaint.id);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Failed to delete complaint: $e')));
                }
              }
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
    final c = widget.complaint;
    final color = _statusColors[c.status] ?? const Color(0xFFA85428);
    final label = _statusLabels[c.status] ?? '';

    // Visual-quality reference: the Contractor Order card (white surface,
    // status-accent top bar, thin accent-tinted outer border, soft
    // status-tinted shadow) — reused here for design consistency only.
    // Content/fields/actions/status logic below are all unchanged.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showComplaintDetailsDialog(context, c,
          accentColor: const Color(0xFFA85428)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.all(Radius.circular(24)),
          border: widget.highlighted
              ? Border.all(color: const Color(0xFFA85428), width: 2.5)
              : Border.all(color: color.withOpacity(0.18), width: 1),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.20),
                blurRadius: 0,
                offset: const Offset(0, 5)),
            BoxShadow(
                color: color.withOpacity(0.10),
                blurRadius: 16,
                offset: const Offset(0, 8)),
            BoxShadow(
                color: Colors.white.withOpacity(0.90),
                blurRadius: 4,
                offset: const Offset(0, -1)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(children: [
            // Top accent bar — mirrors the Contractor Order card's status
            // accent bar.
            Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [color, color.withOpacity(0.4)]),
                    ))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    Row(children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [
                                color.withOpacity(0.65),
                                color.withOpacity(0.35)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                                color: color.withOpacity(0.35),
                                blurRadius: 0,
                                offset: const Offset(0, 3)),
                            BoxShadow(
                                color: color.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 5)),
                            const BoxShadow(
                                color: Colors.white,
                                blurRadius: 3,
                                offset: Offset(0, -1)),
                          ],
                          border: Border.all(
                              color: Colors.white.withOpacity(0.6), width: 1.5),
                        ),
                        child: const Center(
                            child: Icon(Icons.flag_rounded,
                                color: Colors.white, size: 20)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(c.reason,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF7A3E1E))),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.10),
                                borderRadius:
                                    BorderRadius.all(Radius.circular(20)),
                                border:
                                    Border.all(color: color.withOpacity(0.3)),
                              ),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                        width: 5,
                                        height: 5,
                                        decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle)),
                                    const SizedBox(width: 5),
                                    Text(label,
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: color)),
                                  ]),
                            ),
                          ])),
                      // 3-dot menu (only when the complaint can still be
                      // edited/deleted)
                      if (_canEditOrDelete)
                        GestureDetector(
                          onTapDown: (_) {
                            HapticFeedback.lightImpact();
                            _dotsCtrl.forward();
                          },
                          onTapUp: (_) {
                            _dotsCtrl.reverse();
                            _openDotsMenu();
                          },
                          onTapCancel: () => _dotsCtrl.reverse(),
                          child: AnimatedBuilder(
                            animation: _dotsCtrl,
                            builder: (_, child) => Transform.scale(
                                scale: 1.0 - 0.08 * _dotsCtrl.value,
                                child: child),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                  color: Colors.white,
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(12)),
                                  border: Border.fromBorderSide(
                                      BorderSide(color: Color(0x26A85428))),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Color(0x1FA85428),
                                        blurRadius: 10,
                                        offset: Offset(0, 3)),
                                    BoxShadow(
                                        color: Color(0x14000000),
                                        blurRadius: 4,
                                        offset: Offset(0, 1)),
                                  ]),
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(
                                      3,
                                      (i) => Container(
                                          width: 4,
                                          height: 4,
                                          margin: const EdgeInsets.symmetric(
                                              vertical: 1.5),
                                          decoration: const BoxDecoration(
                                              color: Color(0xFFA85428),
                                              shape: BoxShape.circle)))),
                            ),
                          ),
                        ),
                    ]),

                    // Related
                    if (c.targetName != null &&
                        c.targetName!.isNotEmpty &&
                        c.targetName != 'General') ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        const Icon(Icons.link_rounded,
                            size: 13, color: Color(0xFFC7B29C)),
                        const SizedBox(width: 5),
                        Text('Related to: ${c.targetName}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFC7B29C),
                                fontWeight: FontWeight.w600)),
                      ]),
                    ],

                    const SizedBox(height: 12),
                    // Gradient divider — mirrors the Contractor Order card's
                    // status-accent divider.
                    Container(
                        height: 1,
                        decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                          Colors.transparent,
                          color.withOpacity(0.25),
                          Colors.transparent
                        ]))),
                    const SizedBox(height: 10),

                    // Description
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: const Color(0xFFFDF8F1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color:
                                  const Color(0xFFA85428).withOpacity(0.08))),
                      child: Text(c.description,
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFA85428),
                              height: 1.5),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis),
                    ),

                    const SizedBox(height: 10),
                    // Date
                    Row(children: [
                      Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                              color: const Color(0xFFA85428).withOpacity(0.06),
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(9))),
                          child: const Icon(Icons.calendar_today_rounded,
                              size: 13, color: Color(0xFFC7B29C))),
                      const SizedBox(width: 8),
                      Text(
                          '${c.createdAt.day}/${c.createdAt.month}/${c.createdAt.year}',
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFC7B29C),
                              fontWeight: FontWeight.w600)),
                    ]),

                    // Admin reply
                    if (c.replyText != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFFA85428), Color(0xFFA85428)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0xFFA85428),
                                blurRadius: 0,
                                offset: Offset(0, 3)),
                            BoxShadow(
                                color: Color(0x55A85428),
                                blurRadius: 8,
                                offset: Offset(0, 4))
                          ],
                        ),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.reply_rounded,
                                  size: 16, color: Colors.white),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(c.replyText!,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                          height: 1.4))),
                            ]),
                      ),
                    ],
                    // Admin note
                    if (c.adminNote != null &&
                        c.adminNote!.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDF8F1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: const Color(0xFFA85428).withOpacity(0.3)),
                        ),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.sticky_note_2_outlined,
                                  size: 16, color: Color(0xFFA85428)),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(c.adminNote!,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFA85428),
                                          height: 1.4))),
                            ]),
                      ),
                    ],
                  ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Complaint Dots Panel ──────────────────────────────────────────────────────
class _CtrComplaintDotsPanel extends StatefulWidget {
  final VoidCallback onEdit, onDelete;
  const _CtrComplaintDotsPanel({required this.onEdit, required this.onDelete});
  @override
  State<_CtrComplaintDotsPanel> createState() => _CtrComplaintDotsPanelState();
}

class _CtrComplaintDotsPanelState extends State<_CtrComplaintDotsPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320))
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.edit_rounded, const Color(0xFF7C3AED), widget.onEdit),
      (Icons.delete_rounded, const Color(0xFFEF4444), widget.onDelete),
    ];
    return Container(
      width: 68,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          color: const Color(0xFFF6EFE6),
          boxShadow: const [
            BoxShadow(
                color: Color(0xFFD9C6B2), blurRadius: 16, offset: Offset(6, 6)),
            BoxShadow(
                color: Colors.white, blurRadius: 16, offset: Offset(-6, -6))
          ]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(items.length, (i) {
          final (icon, color, onTap) = items[i];
          final anim = CurvedAnimation(
              parent: _ctrl,
              curve: Interval((i / items.length).clamp(0.0, 1.0),
                  ((i + 1) / items.length).clamp(0.0, 1.0),
                  curve: Curves.easeOutBack));
          return AnimatedBuilder(
            animation: anim,
            builder: (_, child) => Opacity(
                opacity: anim.value.clamp(0.0, 1.0),
                child: Transform.scale(
                    scale: 0.6 + 0.4 * anim.value.clamp(0.0, 1.0),
                    child: child)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF6EFE6),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0xFFD9C6B2),
                              blurRadius: 6,
                              offset: Offset(3, 3)),
                          BoxShadow(
                              color: Colors.white,
                              blurRadius: 6,
                              offset: Offset(-3, -3))
                        ]),
                    child: Icon(icon, color: color, size: 22)),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── New / Edit Complaint Sheet ────────────────────────────────────────────────
class _CtrNewComplaintSheet extends ConsumerStatefulWidget {
  final ComplaintModel? existing;
  final UserModel? user;
  const _CtrNewComplaintSheet({this.existing, this.user});
  @override
  ConsumerState<_CtrNewComplaintSheet> createState() =>
      _CtrNewComplaintSheetState();
}

class _CtrNewComplaintSheetState extends ConsumerState<_CtrNewComplaintSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descCtrl;
  String? _selectedReason;
  bool _loading = false;

  static const _reasons = [
    'Customer Behavior',
    'Payment Issue',
    'Platform Problem',
    'Incorrect Order Info',
    'Service Quality',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(text: widget.existing?.description ?? '');
    _selectedReason = widget.existing?.reason;
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Please select a reason'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
      return;
    }
    setState(() => _loading = true);
    final currentUser = widget.user ?? ref.read(authProvider);

    try {
      if (widget.existing != null) {
        await updateComplaintInFirestore(widget.existing!.copyWith(
            reason: _selectedReason!, description: _descCtrl.text.trim()));
      } else {
        await addComplaintInFirestore(ComplaintModel(
          id: '',
          userId: currentUser?.id ?? '',
          userName: currentUser?.fullName ?? '',
          complainantRole: 'contractor',
          type: ComplaintType.general,
          targetId: 'general',
          targetName: null,
          reason: _selectedReason!,
          description: _descCtrl.text.trim(),
          sourceContext: 'my_complaints',
          createdAt: DateTime.now(),
        ));
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(widget.existing != null
                ? 'Complaint updated'
                : 'Complaint submitted')
          ]),
          backgroundColor: const Color(0xFFA85428),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to submit complaint: $e')));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: const BoxDecoration(
        color: Color(0xFFF6EFE6),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
              color: Color(0xFFD9C6B2), blurRadius: 20, offset: Offset(8, 8)),
          BoxShadow(color: Colors.white, blurRadius: 20, offset: Offset(-8, -8))
        ],
      ),
      child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Handle
              Center(
                  child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                    color: const Color(0xFFD9C6B2),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.white,
                          blurRadius: 2,
                          offset: Offset(-1, -1)),
                      BoxShadow(
                          color: Color(0xFFD9C6B2),
                          blurRadius: 2,
                          offset: Offset(1, 1))
                    ]),
              )),
              const SizedBox(height: 20),
              // Header
              Row(children: [
                Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFF6EFE6),
                        boxShadow: [
                          BoxShadow(
                              color: Color(0xFFD9C6B2),
                              blurRadius: 8,
                              offset: Offset(4, 4)),
                          BoxShadow(
                              color: Colors.white,
                              blurRadius: 8,
                              offset: Offset(-4, -4))
                        ]),
                    child: Icon(
                        isEdit ? Icons.edit_rounded : Icons.flag_rounded,
                        color: isEdit
                            ? const Color(0xFF7C3AED)
                            : const Color(0xFFEF4444),
                        size: 22)),
                const SizedBox(width: 14),
                Text(isEdit ? 'Edit Complaint' : 'Submit Complaint',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF7A3E1E))),
              ]),
              const SizedBox(height: 20),
              // Reason
              const Text('Select Reason',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFA85428))),
              const SizedBox(height: 10),
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _reasons.map((r) {
                    final sel = _selectedReason == r;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _selectedReason = r);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6EFE6),
                          borderRadius: BorderRadius.circular(20),
                          gradient: sel
                              ? const LinearGradient(
                                  colors: [
                                      Color(0xFFEF4444),
                                      Color(0xFF991B1B)
                                    ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight)
                              : null,
                          boxShadow: sel
                              ? const [
                                  BoxShadow(
                                      color: Color(0x99EF4444),
                                      blurRadius: 8,
                                      offset: Offset(0, 4)),
                                  BoxShadow(
                                      color: Color(0xFF991B1B),
                                      blurRadius: 0,
                                      offset: Offset(0, 3))
                                ]
                              : const [
                                  BoxShadow(
                                      color: Color(0xFFD9C6B2),
                                      blurRadius: 5,
                                      offset: Offset(3, 3)),
                                  BoxShadow(
                                      color: Colors.white,
                                      blurRadius: 5,
                                      offset: Offset(-3, -3))
                                ],
                        ),
                        child: Text(r,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: sel
                                    ? Colors.white
                                    : const Color(0xFFA85428))),
                      ),
                    );
                  }).toList()),
              const SizedBox(height: 20),
              // Description
              const Text('Describe the issue',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFA85428))),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                    color: const Color(0xFFF6EFE6),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0xFFD9C6B2),
                          blurRadius: 6,
                          offset: Offset(3, 3)),
                      BoxShadow(
                          color: Colors.white,
                          blurRadius: 6,
                          offset: Offset(-3, -3))
                    ]),
                child: TextFormField(
                  controller: _descCtrl,
                  maxLines: 4,
                  style:
                      const TextStyle(fontSize: 14, color: Color(0xFF7A3E1E)),
                  decoration: const InputDecoration(
                    hintText: 'Describe the issue in detail...',
                    hintStyle:
                        TextStyle(color: Color(0xFFC7B29C), fontSize: 13),
                    prefixIcon: Icon(Icons.description_outlined,
                        color: Color(0xFFA85428), size: 20),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please describe the issue'
                      : null,
                ),
              ),
              const SizedBox(height: 28),
              _CtrNeoSendButton(
                label: _loading ? 'Submitting...' : 'Save Changes',
                icon: Icons.check_rounded,
                onTap: _loading ? () {} : _submit,
              ),
            ]),
          )),
    );
  }
}
