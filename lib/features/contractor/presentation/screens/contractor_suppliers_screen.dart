import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/presentation/providers/app_providers.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/profile_field_selectors.dart';
import '../theme/contractor_design.dart';

// ── Category resolution helpers (worker specialties) ──────────────────────
// Normalizes raw specialty strings (trim + lowercase) against a list of
// CategoryModel by id/nameKey — same rule already proven for Professional
// and Contractor profile specialties (see _resolveProviderServiceCategories
// in professional_home_screen.dart / contractor_profile_screen.dart). Never
// guesses a category and never fabricates a fallback CategoryModel from an
// unmatched raw string.
List<CategoryModel> _resolveCategoriesFromRaw(
    List<CategoryModel> categories, List<String> rawValues) {
  final normalized = rawValues
      .map((s) => s.trim().toLowerCase())
      .where((s) => s.isNotEmpty)
      .toSet();
  if (normalized.isEmpty) return const [];
  return categories.where((c) {
    final normId = c.id.trim().toLowerCase();
    final normName = c.nameKey.trim().toLowerCase();
    return normalized.contains(normId) || normalized.contains(normName);
  }).toList();
}

/// The live, active categories the contractor's own profile specialties
/// resolve to — the only options ever offered when picking a worker's
/// specialties (never all system categories).
List<CategoryModel> _resolveContractorSpecialtyCategories(
    List<CategoryModel> activeCategories, UserModel? contractor) {
  if (contractor == null) return const [];
  final raw = contractor.specialties.isNotEmpty
      ? contractor.specialties
      : (contractor.specialty != null
          ? [contractor.specialty!]
          : const <String>[]);
  return _resolveCategoriesFromRaw(activeCategories, raw);
}

/// Display label for a worker's specialty line: the localized name of the
/// first resolved category, plus "+N more" when there's more than one.
/// Falls back to '—' (never a raw nameKey or fabricated category) when
/// nothing resolves.
String _workerSpecialtyLabel(
    AppLocalizations l, List<CategoryModel> categories, WorkerModel worker) {
  final raw = worker.specialties.isNotEmpty
      ? worker.specialties
      : (worker.specialty.isNotEmpty ? [worker.specialty] : const <String>[]);
  final resolved = _resolveCategoriesFromRaw(categories, raw);
  if (resolved.isEmpty) return '—';
  final first = l.get(resolved.first.nameKey);
  return resolved.length > 1 ? '$first +${resolved.length - 1} more' : first;
}

/// Every currently selected specialty's localized label, in resolution
/// order — the uncollapsed counterpart of [_workerSpecialtyLabel], used only
/// by the full Worker Profile screen's Basic Information row so no selected
/// specialty is hidden behind "+N more". Reads the exact same
/// worker.specialties/specialty source and _resolveCategoriesFromRaw
/// resolution; never touches specialty storage/selection.
List<String> _workerSpecialtyLabels(
    AppLocalizations l, List<CategoryModel> categories, WorkerModel worker) {
  final raw = worker.specialties.isNotEmpty
      ? worker.specialties
      : (worker.specialty.isNotEmpty ? [worker.specialty] : const <String>[]);
  final resolved = _resolveCategoriesFromRaw(categories, raw);
  if (resolved.isEmpty) return const ['—'];
  return resolved.map((c) => l.get(c.nameKey)).toList();
}

// ── Re-use the same orange/gold palette defined in contractor_design.dart ────
class _Brown {
  static const darkest = ContractorColors.darkest;
  static const dark = ContractorColors.dark;
  static const mid = ContractorColors.mid;
  static const light = ContractorColors.light;
  static const warm = ContractorColors.warm;
}

// ─── Helpers for status (3-state) ─────────────────────────────────────────────
Color _statusColor(WorkerStatus s) {
  switch (s) {
    case WorkerStatus.available:
      return AppColors.accent;
    case WorkerStatus.busy:
      return AppColors.warning;
    case WorkerStatus.offline:
      return const Color(0xFF9CA3AF); // grey
  }
}

String _statusLabel(BuildContext ctx, WorkerStatus s) {
  final l = AppLocalizations.of(ctx);
  switch (s) {
    case WorkerStatus.available:
      return l.get('available');
    case WorkerStatus.busy:
      return l.get('busy');
    case WorkerStatus.offline:
      return l.get('offline');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class ContractorSuppliersScreen extends ConsumerStatefulWidget {
  const ContractorSuppliersScreen({super.key});

  @override
  ConsumerState<ContractorSuppliersScreen> createState() =>
      _ContractorSuppliersScreenState();
}

class _ContractorSuppliersScreenState
    extends ConsumerState<ContractorSuppliersScreen> {
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Add / Edit dialog ──────────────────────────────────────────────────────
  void _showWorkerForm({WorkerModel? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final yearsCtrl = TextEditingController(
        text: existing?.yearsExperience.toString() ?? '0');
    final skillsCtrl = TextEditingController(
        text: (existing?.skills ?? const <String>[]).join(', '));
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    WorkerStatus status = existing?.status ?? WorkerStatus.available;
    final formKey = GlobalKey<FormState>();
    final workAreaKey = GlobalKey<WorkAreaFieldState>();
    final hoursKey = GlobalKey<WorkingHoursFieldState>();
    final languagesKey = GlobalKey<LanguagesFieldState>();

    // Specialty choices are limited to the contractor's own valid (live,
    // active) categories — never the full system category list. Read once
    // when the sheet opens, same one-shot pattern as the other controllers.
    final contractor = ref.read(authProvider);
    final allCats =
        ref.read(categoriesProvider).value ?? const <CategoryModel>[];
    final eligibleCategories =
        _resolveContractorSpecialtyCategories(allCats, contractor);
    final existingSpecialtyRaw = existing?.specialties.isNotEmpty == true
        ? existing!.specialties
        : (existing?.specialty.isNotEmpty == true
            ? [existing!.specialty]
            : const <String>[]);
    final selectedSpecialties = <String>{
      for (final c in _resolveCategoriesFromRaw(
          eligibleCategories, existingSpecialtyRaw))
        c.nameKey
    };
    bool specialtiesError = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final l = AppLocalizations.of(ctx);
          return Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.92),
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
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle + X row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: Row(children: [
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
                    ),

                    // Title row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Row(children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [_Brown.darkest, _Brown.dark],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(17),
                            boxShadow: [
                              BoxShadow(
                                  color: _Brown.darkest.withOpacity(0.4),
                                  blurRadius: 0,
                                  offset: const Offset(0, 4)),
                              BoxShadow(
                                  color: _Brown.darkest.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(4, 5)),
                              BoxShadow(
                                  color: Colors.white.withOpacity(0.1),
                                  blurRadius: 6,
                                  offset: const Offset(-3, -3)),
                            ],
                          ),
                          child: Stack(children: [
                            Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                    height: 26,
                                    decoration: BoxDecoration(
                                      borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(17),
                                          topRight: Radius.circular(17)),
                                      gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.white.withOpacity(0.22),
                                            Colors.transparent
                                          ]),
                                    ))),
                            const Center(
                                child: Icon(Icons.person_add_alt_1_rounded,
                                    color: Colors.white, size: 24)),
                          ]),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Text(
                          existing == null
                              ? l.get('add_worker_supplier')
                              : l.get('edit_data'),
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF7A3E1E)),
                        )),
                      ]),
                    ),

                    // Info banner
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6EFE6),
                          borderRadius: BorderRadius.circular(16),
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
                          ],
                        ),
                        child: Row(children: [
                          const Icon(Icons.info_outline_rounded,
                              color: Color(0xFFA85428), size: 16),
                          const SizedBox(width: 9),
                          Expanded(
                              child: Text(
                            existing == null
                                ? 'Fill in the details to add a new worker or supplier.'
                                : 'Edit the worker information below.',
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFA85428),
                                height: 1.4),
                          )),
                        ]),
                      ),
                    ),

                    // Scrollable fields
                    Flexible(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                        child: Column(children: [
                          _NeoFormField(
                              ctrl: nameCtrl,
                              label: l.get('full_name'),
                              icon: Icons.person_outline_rounded,
                              required: true),
                          const SizedBox(height: 11),
                          _NeoFieldLabel(l.get('specialties')),
                          const SizedBox(height: 5),
                          if (eligibleCategories.isEmpty)
                            _NeoFieldNotice(l.get('no_specialties_yet'))
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: eligibleCategories.map((cat) {
                                final key = cat.nameKey;
                                final isSel = selectedSpecialties.contains(key);
                                return GestureDetector(
                                  onTap: () => setSheetState(() {
                                    isSel
                                        ? selectedSpecialties.remove(key)
                                        : selectedSpecialties.add(key);
                                    specialtiesError = false;
                                  }),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color:
                                          isSel ? _Brown.darkest : _Brown.warm,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: isSel
                                              ? _Brown.darkest
                                              : _Brown.mid.withOpacity(0.4),
                                          width: 1.5),
                                    ),
                                    child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(cat.icon,
                                              style: const TextStyle(
                                                  fontSize: 14)),
                                          const SizedBox(width: 6),
                                          Text(l.get(key),
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: isSel
                                                      ? Colors.white
                                                      : _Brown.darkest)),
                                        ]),
                                  ),
                                );
                              }).toList(),
                            ),
                          if (specialtiesError) ...[
                            const SizedBox(height: 6),
                            const Text('Please select at least one specialty',
                                style: TextStyle(
                                    fontSize: 11.5, color: Color(0xFFEF4444))),
                          ],
                          const SizedBox(height: 11),
                          _NeoFormField(
                              ctrl: phoneCtrl,
                              label: l.get('phone'),
                              icon: Icons.phone_outlined,
                              keyboard: TextInputType.phone),
                          const SizedBox(height: 11),
                          _NeoFormField(
                              ctrl: emailCtrl,
                              label: l.get('email'),
                              icon: Icons.email_outlined,
                              keyboard: TextInputType.emailAddress),
                          const SizedBox(height: 11),
                          _NeoFieldLabel(l.get('work_area')),
                          const SizedBox(height: 5),
                          WorkAreaField(
                              key: workAreaKey,
                              initialValue:
                                  existing?.workArea ?? existing?.city ?? '',
                              accentColor: _Brown.dark),
                          const SizedBox(height: 11),
                          _NeoFormField(
                              ctrl: yearsCtrl,
                              label: l.get('worker_experience'),
                              icon: Icons.workspace_premium_outlined,
                              keyboard: TextInputType.number),
                          const SizedBox(height: 11),
                          _NeoFieldLabel('Working Hours'),
                          const SizedBox(height: 5),
                          WorkingHoursField(
                              key: hoursKey,
                              initialRange:
                                  existing?.effectiveWorkingHoursLabel ?? '',
                              accentColor: _Brown.dark),
                          const SizedBox(height: 11),
                          _NeoFieldLabel('Languages'),
                          const SizedBox(height: 5),
                          LanguagesField(
                              key: languagesKey,
                              initialValue: existing?.languages ?? const [],
                              accentColor: _Brown.dark),
                          const SizedBox(height: 11),
                          _NeoFormField(
                              ctrl: skillsCtrl,
                              label:
                                  '${l.get('worker_skills')} (comma-separated)',
                              icon: Icons.star_border_rounded),
                          const SizedBox(height: 11),
                          _NeoFormField(
                              ctrl: descCtrl,
                              label: l.get('worker_about'),
                              icon: Icons.description_outlined,
                              maxLines: 3),
                          const SizedBox(height: 14),
                          // Status selector
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6EFE6),
                              borderRadius: BorderRadius.circular(18),
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
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                            color: Color(0xFFA85428),
                                            shape: BoxShape.circle)),
                                    const SizedBox(width: 8),
                                    Text(l.get('status'),
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFFA85428))),
                                  ]),
                                  const SizedBox(height: 10),
                                  Row(
                                      children: WorkerStatus.values.map((s) {
                                    final sel = s == status;
                                    final color = _statusColor(s);
                                    return Expanded(
                                        child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 3),
                                      child: GestureDetector(
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          setSheetState(() => status = s);
                                        },
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 180),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF6EFE6),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: sel
                                                ? Border.all(
                                                    color: color, width: 2)
                                                : null,
                                            boxShadow: sel
                                                ? [
                                                    BoxShadow(
                                                        color: color
                                                            .withOpacity(0.3),
                                                        blurRadius: 6,
                                                        offset:
                                                            const Offset(0, 3)),
                                                    BoxShadow(
                                                        color: color
                                                            .withOpacity(0.8),
                                                        blurRadius: 0,
                                                        offset:
                                                            const Offset(0, 3)),
                                                  ]
                                                : const [
                                                    BoxShadow(
                                                        color:
                                                            Color(0xFFD9C6B2),
                                                        blurRadius: 4,
                                                        offset: Offset(2, 2)),
                                                    BoxShadow(
                                                        color: Colors.white,
                                                        blurRadius: 4,
                                                        offset: Offset(-2, -2)),
                                                  ],
                                          ),
                                          child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration: BoxDecoration(
                                                        color: color,
                                                        shape:
                                                            BoxShape.circle)),
                                                const SizedBox(height: 5),
                                                Text(_statusLabel(ctx, s),
                                                    style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: sel
                                                            ? color
                                                            : const Color(
                                                                0xFFC7B29C))),
                                              ]),
                                        ),
                                      ),
                                    ));
                                  }).toList()),
                                ]),
                          ),
                          const SizedBox(height: 8),
                        ]),
                      ),
                    ),

                    // Save button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                      child: _NeoSaveWorkerBtn(
                        isEdit: existing != null,
                        onTap: () {
                          if (!formKey.currentState!.validate()) return;
                          final hoursValue = hoursKey.currentState!.validate();
                          if (hoursValue == null) return;
                          if (eligibleCategories.isEmpty ||
                              selectedSpecialties.isEmpty) {
                            setSheetState(() => specialtiesError = true);
                            return;
                          }
                          final orderedSpecialties = eligibleCategories
                              .where((c) =>
                                  selectedSpecialties.contains(c.nameKey))
                              .map((c) => c.nameKey)
                              .toList();
                          final workAreaValue = workAreaKey.currentState!.value;
                          final languagesValue =
                              languagesKey.currentState!.value;
                          final hoursParts = splitWorkingHoursRange(hoursValue);
                          final skills = skillsCtrl.text
                              .split(',')
                              .map((e) => e.trim())
                              .where((e) => e.isNotEmpty)
                              .toList();
                          final years =
                              int.tryParse(yearsCtrl.text.trim()) ?? 0;
                          final worker = WorkerModel(
                            id: existing?.id ?? '',
                            name: nameCtrl.text.trim(),
                            specialty: orderedSpecialties.first,
                            specialties: orderedSpecialties,
                            phone: phoneCtrl.text.trim().isEmpty
                                ? null
                                : phoneCtrl.text.trim(),
                            email: emailCtrl.text.trim().isEmpty
                                ? null
                                : emailCtrl.text.trim(),
                            city: workAreaValue.isEmpty ? null : workAreaValue,
                            workArea:
                                workAreaValue.isEmpty ? null : workAreaValue,
                            languages: languagesValue,
                            imageUrl: existing?.imageUrl,
                            yearsExperience: years,
                            skills: skills,
                            workHours: hoursValue,
                            workStartTime: hoursParts?[0],
                            workEndTime: hoursParts?[1],
                            description: descCtrl.text.trim().isEmpty
                                ? null
                                : descCtrl.text.trim(),
                            status: status,
                            rating: existing?.rating ?? 0,
                            totalJobs: existing?.totalJobs ?? 0,
                            currentJobs: existing?.currentJobs ?? 0,
                          );
                          final contractorId = contractor?.id ?? '';
                          final contractorName = contractor?.companyName ??
                              contractor?.fullName ??
                              '';
                          if (existing == null) {
                            ContractorWorkersService.add(
                              worker,
                              contractorId: contractorId,
                              contractorName: contractorName,
                            ).catchError(
                                (e) => debugPrint('add worker error: $e'));
                          } else {
                            ContractorWorkersService.update(
                              worker,
                              contractorId: contractorId,
                              contractorName: contractorName,
                            ).catchError(
                                (e) => debugPrint('update worker error: $e'));
                          }
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Row(children: [
                              const Icon(Icons.check_circle_rounded,
                                  color: Colors.white),
                              const SizedBox(width: 8),
                              Text(existing == null
                                  ? l.get('worker_added')
                                  : l.get('data_updated')),
                            ]),
                            backgroundColor: const Color(0xFFA85428),
                            behavior: SnackBarBehavior.fixed,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ));
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete(WorkerModel worker) {
    final l = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF6EFE6),
          borderRadius: BorderRadius.circular(32),
          boxShadow: const [
            BoxShadow(
                color: Color(0xFFD9C6B2), blurRadius: 20, offset: Offset(8, 8)),
            BoxShadow(
                color: Colors.white, blurRadius: 20, offset: Offset(-8, -8)),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
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
          // Icon + title
          Row(children: [
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
              child: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFEF4444), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(l.get('delete_worker'),
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF7A3E1E))),
                  const SizedBox(height: 2),
                  Text(worker.name,
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFA85428),
                          fontWeight: FontWeight.w600)),
                ])),
          ]),
          const SizedBox(height: 16),
          // Warning card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF6EFE6),
              borderRadius: BorderRadius.circular(16),
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
              ],
            ),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFEF4444), size: 18),
              const SizedBox(width: 10),
              Expanded(
                  child: RichText(
                      text: TextSpan(
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFFA85428), height: 1.4),
                children: [
                  TextSpan(
                      text:
                          '${l.get("delete_confirm_worker").split(" ").take(3).join(" ")} '),
                  TextSpan(
                      text: worker.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF7A3E1E))),
                  const TextSpan(
                      text: ' from the list?\nThis action cannot be undone.'),
                ],
              ))),
            ]),
          ),
          const SizedBox(height: 20),
          // Buttons row
          Row(children: [
            Expanded(
                child: _NeoOutlineBtn(
              label: l.get('cancel'),
              onTap: () => Navigator.pop(ctx),
            )),
            const SizedBox(width: 10),
            Expanded(
                child: _NeoDeleteBtn(
              label: l.get('delete'),
              onTap: () {
                ContractorWorkersService.delete(worker.id)
                    .catchError((e) => debugPrint('delete worker error: $e'));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Row(children: [
                    const Icon(Icons.delete_sweep_rounded, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(l.get('worker_deleted')),
                  ]),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.fixed,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ));
              },
            )),
          ]),
        ]),
      ),
    );
  }

  // ── Full Profile Screen (tap on card) ──────────────────────────────────────
  void _openFullProfile(WorkerModel w) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => WorkerProfileScreen(
        worker: w,
        onEdit: () {
          Navigator.pop(context);
          _showWorkerForm(existing: w);
        },
        onDelete: () {
          Navigator.pop(context);
          _confirmDelete(w);
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final workersAsync = ref.watch(contractorWorkersStreamProvider);
    final workers = workersAsync.valueOrNull ?? const <WorkerModel>[];
    final isFirstLoad = workersAsync.isLoading && !workersAsync.hasValue;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filtered = _search.isEmpty
        ? workers
        : workers.where((w) {
            final q = _search.toLowerCase();
            final statusLabel = _statusLabel(context, w.status).toLowerCase();
            return w.name.toLowerCase().contains(q) ||
                w.specialty.toLowerCase().contains(q) ||
                (w.phone?.toLowerCase().contains(q) ?? false) ||
                (w.email?.toLowerCase().contains(q) ?? false) ||
                (w.city?.toLowerCase().contains(q) ?? false) ||
                w.skills.any((s) => s.toLowerCase().contains(q)) ||
                statusLabel.contains(q);
          }).toList();

    final available =
        workers.where((w) => w.status == WorkerStatus.available).length;
    final busy = workers.where((w) => w.status == WorkerStatus.busy).length;
    final offline =
        workers.where((w) => w.status == WorkerStatus.offline).length;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFFDF6EC),
      body: SafeArea(
        child: Column(children: [
          // ── Navy gradient header ──────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_Brown.darkest, _Brown.dark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                  ),
                  child: const Icon(Icons.group_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Text(l.get('workers_suppliers'),
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.4)),
                const Spacer(),
                _NeoAddBtn(onTap: () => _showWorkerForm()),
              ]),
              const SizedBox(height: 14),
              // Search bar
              Container(
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.30)),
                ),
                child: Row(children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.search_rounded,
                      color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Theme(
                    data: Theme.of(context).copyWith(
                      inputDecorationTheme: const InputDecorationTheme(
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _search = v),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                      cursorColor: Colors.white,
                      decoration: InputDecoration(
                        hintText: l.get('search_name_specialty'),
                        hintStyle: const TextStyle(
                            color: Colors.white54, fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  )),
                  if (_search.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white70, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _search = '');
                      },
                    ),
                ]),
              ),
            ]),
          ),

          // ── Neo stat pills (outside brown header, above cards) ─────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(children: [
              _NeoStatPill(
                  icon: Icons.people_rounded,
                  label: l.get('total'),
                  value: '${workers.length}',
                  color: const Color(0xFFA85428)),
              const SizedBox(width: 8),
              _NeoStatPill(
                  icon: Icons.check_circle_rounded,
                  label: l.get('available'),
                  value: '$available',
                  color: AppColors.accent),
              const SizedBox(width: 8),
              _NeoStatPill(
                  icon: Icons.access_time_rounded,
                  label: l.get('busy'),
                  value: '$busy',
                  color: AppColors.warning),
              const SizedBox(width: 8),
              _NeoStatPill(
                  icon: Icons.power_settings_new_rounded,
                  label: l.get('offline'),
                  value: '$offline',
                  color: const Color(0xFF9CA3AF)),
            ]),
          ),

          // ── Body ─────────────────────────────────────────────────────
          Expanded(
            child: isFirstLoad
                ? const Center(
                    child: CircularProgressIndicator(color: _Brown.dark))
                : workers.isEmpty
                    ? _EmptyState(onAdd: _showWorkerForm)
                    : filtered.isEmpty
                        ? Center(
                            child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.search_off_rounded,
                                  size: 52, color: _Brown.mid),
                              const SizedBox(height: 10),
                              Text(l.get('no_results_found'),
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: _Brown.dark)),
                            ],
                          ))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                            itemCount: filtered.length,
                            itemBuilder: (ctx, i) => _WorkerCard(
                              worker: filtered[i],
                              onTap: () => _openFullProfile(filtered[i]),
                              onEdit: () =>
                                  _showWorkerForm(existing: filtered[i]),
                              onDelete: () => _confirmDelete(filtered[i]),
                            ),
                          ),
          ),
        ]),
      ),
    );
  }
}

// ─── Worker Card — Neo 3D ─────────────────────────────────────────────────────
class _WorkerCard extends ConsumerStatefulWidget {
  final WorkerModel worker;
  final VoidCallback onTap, onEdit, onDelete;
  const _WorkerCard(
      {required this.worker,
      required this.onTap,
      required this.onEdit,
      required this.onDelete});
  @override
  ConsumerState<_WorkerCard> createState() => _WorkerCardState();
}

class _WorkerCardState extends ConsumerState<_WorkerCard>
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
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final w = widget.worker;
    final statusColor = _statusColor(w.status);
    // Same semantic status color used for the card's top accent/border/
    // shadow/divider/chips — mirrors the Contractor Order card, where the
    // accent is likewise derived entirely from the item's existing status.
    final accent = statusColor;
    final initials = w.name.isNotEmpty ? w.name[0] : '?';
    final allCats =
        ref.watch(categoriesProvider).value ?? const <CategoryModel>[];
    final specialtyLabel = _workerSpecialtyLabel(l, allCats, w);

    return GestureDetector(
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
            Transform.scale(scale: 1.0 - 0.01 * _ctrl.value, child: child),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: accent.withOpacity(0.15), width: 1),
            boxShadow: _p
                ? [
                    BoxShadow(
                        color: accent.withOpacity(0.15),
                        blurRadius: 4,
                        offset: const Offset(1, 2)),
                  ]
                : [
                    BoxShadow(
                        color: accent.withOpacity(0.20),
                        blurRadius: 0,
                        offset: const Offset(0, 5)),
                    BoxShadow(
                        color: accent.withOpacity(0.10),
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
                            colors: [accent, accent.withOpacity(0.4)]),
                      ))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        // Avatar 3D
                        Stack(children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [_Brown.darkest, _Brown.dark],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                    color: _Brown.darkest.withOpacity(0.30),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4)),
                                const BoxShadow(
                                    color: Colors.white,
                                    blurRadius: 3,
                                    offset: Offset(0, -1)),
                              ],
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.6),
                                  width: 1.5),
                            ),
                            child: Stack(children: [
                              Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                      height: 26,
                                      decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(16),
                                            topRight: Radius.circular(16)),
                                        gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.white.withOpacity(0.22),
                                              Colors.transparent
                                            ]),
                                      ))),
                              Center(
                                  child: Text(initials,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900))),
                            ]),
                          ),
                          Positioned(
                            right: -1,
                            bottom: -1,
                            child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                          color: statusColor.withOpacity(0.4),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2))
                                    ])),
                          ),
                        ]),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(w.name,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: _Brown.darkest,
                                      letterSpacing: -0.3)),
                              const SizedBox(height: 3),
                              Row(children: [
                                const Icon(Icons.build_outlined,
                                    size: 12, color: _Brown.dark),
                                const SizedBox(width: 4),
                                Flexible(
                                    child: Text(specialtyLabel,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: _Brown.dark,
                                            fontWeight: FontWeight.w500),
                                        overflow: TextOverflow.ellipsis)),
                              ]),
                              const SizedBox(height: 5),
                              Row(children: [
                                if (w.rating > 0) ...[
                                  const Icon(Icons.star_rounded,
                                      size: 13, color: AppColors.warning),
                                  const SizedBox(width: 3),
                                  Text(w.rating.toStringAsFixed(1),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.warning)),
                                  const SizedBox(width: 10),
                                ],
                                _WorkerCardStatusChip(status: w.status),
                              ]),
                            ])),
                        // Neo 3-dots menu
                        _NeoWorkerDotsMenu(
                            worker: w,
                            onEdit: widget.onEdit,
                            onDelete: widget.onDelete),
                      ]),
                      if (w.phone != null ||
                          w.city != null ||
                          w.yearsExperience > 0) ...[
                        const SizedBox(height: 12),
                        // Gradient divider — accent-aware, mirrors the
                        // Contractor Order card's divider.
                        Container(
                            height: 1,
                            decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                              Colors.transparent,
                              accent.withOpacity(0.25),
                              Colors.transparent
                            ]))),
                        const SizedBox(height: 10),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          if (w.phone != null)
                            _WorkerCardMetaChip(
                                icon: Icons.phone_outlined,
                                text: w.phone!,
                                accent: accent),
                          if (w.city != null)
                            _WorkerCardMetaChip(
                                icon: Icons.location_on_outlined,
                                text: l.translateRegion(w.city!),
                                accent: accent),
                          if (w.yearsExperience > 0)
                            _WorkerCardMetaChip(
                                icon: Icons.workspace_premium_outlined,
                                text:
                                    '${w.yearsExperience} ${l.get('years_short')}',
                                accent: accent),
                          if (w.totalJobs > 0)
                            _WorkerCardMetaChip(
                                icon: Icons.check_circle_outline,
                                text: '${w.totalJobs} ${l.get('jobs_short')}',
                                accent: accent),
                        ]),
                      ],
                    ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── Worker Card Status Chip (list-card only) ─────────────────────────────────
// Same status value/label as the shared _StatusBadge (used elsewhere by the
// full Worker Profile screen, which is intentionally left untouched) —
// restyled here to match the Contractor Order card's icon-badge visual
// language. Status color/label logic is unchanged (_statusColor/
// _statusLabel).
class _WorkerCardStatusChip extends StatelessWidget {
  final WorkerStatus status;
  const _WorkerCardStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    final label = _statusLabel(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.18),
              blurRadius: 0,
              offset: const Offset(0, 2)),
          BoxShadow(
              color: color.withOpacity(0.10),
              blurRadius: 5,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

// ─── Worker Card Metadata Chip (list-card only) ───────────────────────────────
// Same phone/location/experience/jobs content as the shared _InfoChip (used
// elsewhere by the full Worker Profile screen, left untouched) — restyled
// as a compact accent-tinted pill matching the Order card's chip language.
class _WorkerCardMetaChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color accent;
  const _WorkerCardMetaChip(
      {required this.icon, required this.text, required this.accent});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withOpacity(0.18)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: accent),
          const SizedBox(width: 5),
          Text(text,
              style: const TextStyle(
                  fontSize: 11.5,
                  color: _Brown.dark,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

// ─── Neo 3-dot menu for worker card (like professional home screen) ────────────
class _NeoWorkerDotsMenu extends StatefulWidget {
  final WorkerModel worker;
  final VoidCallback onEdit, onDelete;
  const _NeoWorkerDotsMenu(
      {required this.worker, required this.onEdit, required this.onDelete});
  @override
  State<_NeoWorkerDotsMenu> createState() => _NeoWorkerDotsMenuState();
}

class _NeoWorkerDotsMenuState extends State<_NeoWorkerDotsMenu>
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

  // Restyled to sit cleanly on the redesigned worker card's white surface
  // (was a flat neumorphic grey square) — same trigger, size, icon, and tap
  // behavior, only the resting visual treatment changed.
  static const _neoBase = Colors.white;
  static const List<BoxShadow> _raised = [
    BoxShadow(color: Color(0x1FA85428), blurRadius: 10, offset: Offset(0, 3)),
    BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 1)),
  ];

  void _open() {
    HapticFeedback.lightImpact();
    final items = <_DotItem>[
      _DotItem(Icons.edit_rounded, const Color(0xFF7C3AED), widget.onEdit),
      _DotItem(Icons.delete_rounded, const Color(0xFFEF4444), widget.onDelete),
    ];

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.18),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        final box = context.findRenderObject() as RenderBox?;
        final pos = box?.localToGlobal(Offset.zero) ?? Offset.zero;
        final size = box?.size ?? Size.zero;
        final screenH = MediaQuery.of(ctx).size.height;
        final panelH = items.length * 58.0 + 20;
        double topPos = pos.dy + size.height - 30;
        if (topPos + panelH > screenH - 16) topPos = pos.dy - panelH + 30;
        topPos = topPos.clamp(16.0, screenH - panelH - 16);
        return Stack(children: [
          Positioned.fill(
              child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(color: Colors.transparent))),
          Positioned(
            right: 16,
            top: topPos,
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(0.3, -0.2), end: Offset.zero)
                  .animate(curved),
              child: FadeTransition(
                  opacity: anim, child: _NeoDotsPanel(items: items)),
            ),
          ),
        ]);
      },
    );
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          _ctrl.forward();
        },
        onTapUp: (_) {
          _ctrl.reverse();
          _open();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.08 * _ctrl.value, child: child),
          child: Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
                color: _neoBase,
                borderRadius: BorderRadius.all(Radius.circular(12)),
                border:
                    Border.fromBorderSide(BorderSide(color: Color(0x26A85428))),
                boxShadow: _raised),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                    3,
                    (i) => Container(
                        width: 3.5,
                        height: 3.5,
                        margin: const EdgeInsets.symmetric(vertical: 1.2),
                        decoration: const BoxDecoration(
                            color: Color(0xFFA85428),
                            shape: BoxShape.circle)))),
          ),
        ),
      );
}

class _DotItem {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _DotItem(this.icon, this.color, this.onTap);
}

class _NeoDotsPanel extends StatefulWidget {
  final List<_DotItem> items;
  const _NeoDotsPanel({required this.items});
  @override
  State<_NeoDotsPanel> createState() => _NeoDotsPanelState();
}

class _NeoDotsPanelState extends State<_NeoDotsPanel>
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
  Widget build(BuildContext context) => Container(
        width: 64,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            color: const Color(0xFFF6EFE6),
            boxShadow: const [
              BoxShadow(
                  color: Color(0xFFD9C6B2),
                  blurRadius: 16,
                  offset: Offset(6, 6)),
              BoxShadow(
                  color: Colors.white, blurRadius: 16, offset: Offset(-6, -6))
            ]),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(widget.items.length, (i) {
            final item = widget.items[i];
            final n = widget.items.length;
            final anim = CurvedAnimation(
                parent: _ctrl,
                curve: Interval((i / n).clamp(0, 1), ((i + 1) / n).clamp(0, 1),
                    curve: Curves.easeOutBack));
            return AnimatedBuilder(
              animation: anim,
              builder: (_, child) => Opacity(
                  opacity: anim.value.clamp(0, 1),
                  child: Transform.scale(
                      scale: 0.6 + 0.4 * anim.value.clamp(0, 1), child: child)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    item.onTap();
                  },
                  child: Container(
                      width: 48,
                      height: 48,
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
                      child: Icon(item.icon, color: item.color, size: 20)),
                ),
              ),
            );
          }),
        ),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// ─── FULL WORKER PROFILE SCREEN ──────────────────────────────────────────────
// ═════════════════════════════════════════════════════════════════════════════
class WorkerProfileScreen extends ConsumerWidget {
  final WorkerModel worker;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool readOnly;
  const WorkerProfileScreen({
    super.key,
    required this.worker,
    this.onEdit,
    this.onDelete,
    this.readOnly = false,
  });

  void _quickAction(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$label: ${worker.name}'),
      backgroundColor: _Brown.dark,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  /// A worker counts as assigned to an order when it appears in the new
  /// multi-worker `assignedWorkers` snapshot list, or — for a legacy order
  /// that has none — via the single legacy assignedWorkerId. Kept as one
  /// small helper so the counting logic below never has to know which shape
  /// a given order uses.
  static bool _isAssignedToWorker(OrderModel order, String workerId) =>
      order.assignedWorkers.isNotEmpty
          ? order.assignedWorkers.any((w) => w.id == workerId)
          : order.assignedWorkerId == workerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final statusColor = _statusColor(worker.status);
    final allCats =
        ref.watch(categoriesProvider).value ?? const <CategoryModel>[];
    final specialtyLabel = _workerSpecialtyLabel(l, allCats, worker);
    // Uncollapsed specialty list for the Basic Information row only — see
    // _workerSpecialtyLabels.
    final specialtyLabels = _workerSpecialtyLabels(l, allCats, worker);

    // Live job counters for the contractor-owned profile only. The
    // read-only customer-facing profile never queries contractor orders —
    // it keeps showing the worker's stored totalJobs/currentJobs, unchanged.
    // While contractorFirestoreOrdersProvider is still loading (or if it
    // errors), fall back to those same stored values rather than blocking
    // or crashing this screen.
    int completedJobsCount = worker.totalJobs;
    int currentJobsCount = worker.currentJobs;
    if (!readOnly) {
      final ordersAsync = ref.watch(contractorFirestoreOrdersProvider);
      if (ordersAsync.hasError) {
        debugPrint(
            'WORKER_ORDERS_LOAD_ERROR [WorkerProfileScreen]: ${ordersAsync.error}');
      }
      final orders = ordersAsync.valueOrNull;
      if (orders != null) {
        completedJobsCount = orders
            .where((o) =>
                _isAssignedToWorker(o, worker.id) &&
                o.status == OrderStatus.completed)
            .length;
        currentJobsCount = orders
            .where((o) =>
                _isAssignedToWorker(o, worker.id) &&
                o.status == OrderStatus.inProgress)
            .length;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6EFE6),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── SliverAppBar with neo back + 3-dot menu ───────────────────
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: _Brown.darkest,
            foregroundColor: Colors.white,
            elevation: 0,
            automaticallyImplyLeading: false,
            leading: _WorkerProfileBackBtn(),
            actions: [
              if (!readOnly && (onEdit != null || onDelete != null))
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _WorkerProfileDotsMenu(
                      onEdit: onEdit, onDelete: onDelete),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_Brown.darkest, Color(0xFFA85428), _Brown.dark],
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
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        // Avatar with 3D look
                        Stack(alignment: Alignment.bottomRight, children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [_Brown.dark, _Brown.mid],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight),
                              shape: BoxShape.circle,
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
                            child: Center(
                                child: Text(
                              worker.name.isNotEmpty
                                  ? worker.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 38,
                                  fontWeight: FontWeight.w900),
                            )),
                          ),
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFFF6EFE6), width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                    color: statusColor.withOpacity(0.4),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2))
                              ],
                            ),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        Text(worker.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3)),
                        const SizedBox(height: 3),
                        Text(specialtyLabel,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        _StatusBadge(status: worker.status),
                      ]),
                ),
              ),
            ),
          ),

          // ── Stats row (neo cards) ──────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(children: [
                Expanded(
                    child: _NeoStatCard(
                  icon: Icons.check_circle_outline,
                  value: '$completedJobsCount',
                  label: l.get('worker_completed'),
                  color: AppColors.accent,
                )),
                const SizedBox(width: 10),
                Expanded(
                    child: _NeoStatCard(
                  icon: Icons.work_outline_rounded,
                  value: '$currentJobsCount',
                  label: l.get('worker_current_jobs'),
                  color: _Brown.dark,
                )),
              ]),
            ),
          ),

          // ── Call / Message buttons ─────────────────────────────────────
          if (!readOnly && (worker.phone != null || worker.email != null))
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(children: [
                  if (worker.phone != null) ...[
                    Expanded(
                        child: _NeoActionButton(
                      icon: Icons.call_outlined,
                      label: l.get('call_worker'),
                      color: AppColors.accent,
                      onTap: () => _quickAction(context, l.get('call_worker')),
                    )),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                      child: _NeoActionButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: l.get('message_worker'),
                    color: _Brown.dark,
                    onTap: () => _quickAction(context, l.get('message_worker')),
                  )),
                ]),
              ),
            ),

          // ── Info sections ──────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            sliver: SliverList(
                delegate: SliverChildListDelegate([
              _NeoSection(title: l.get('basic_info'), children: [
                _NeoSpecialtiesRow(
                    icon: Icons.build_outlined,
                    iconColor: _Brown.dark,
                    label: l.get('worker_specialty'),
                    specialties: specialtyLabels),
                if (worker.phone != null)
                  _NeoDetailRow(
                      icon: Icons.phone_outlined,
                      iconColor: _Brown.dark,
                      label: l.get('worker_phone'),
                      value: worker.phone!),
                if (worker.email != null)
                  _NeoDetailRow(
                      icon: Icons.email_outlined,
                      iconColor: _Brown.mid,
                      label: l.get('worker_email'),
                      value: worker.email!),
                if (worker.city != null)
                  _NeoDetailRow(
                      icon: Icons.location_on_outlined,
                      iconColor: _Brown.mid,
                      label: l.get('worker_city'),
                      value: l.translateRegion(worker.city!)),
                _NeoDetailRow(
                    icon: Icons.circle,
                    iconColor: statusColor,
                    label: l.get('worker_status'),
                    value: _statusLabel(context, worker.status),
                    valueColor: statusColor,
                    isLast: true),
              ]),
              const SizedBox(height: 14),
              _NeoSection(title: l.get('additional_info'), children: [
                if (worker.yearsExperience > 0)
                  _NeoDetailRow(
                      icon: Icons.workspace_premium_outlined,
                      iconColor: _Brown.dark,
                      label: l.get('worker_experience'),
                      value:
                          '${worker.yearsExperience} ${l.get('years_short')}'),
                if (worker.workHours != null && worker.workHours!.isNotEmpty)
                  _NeoDetailRow(
                      icon: Icons.schedule_outlined,
                      iconColor: _Brown.mid,
                      label: l.get('worker_work_hours'),
                      value: worker.workHours!),
                _NeoDetailRow(
                    icon: Icons.check_circle_outline,
                    iconColor: AppColors.accent,
                    label: l.get('worker_completed'),
                    value: '$completedJobsCount'),
                _NeoDetailRow(
                    icon: Icons.work_outline_rounded,
                    iconColor: _Brown.dark,
                    label: l.get('worker_current_jobs'),
                    value: '$currentJobsCount',
                    isLast: true),
              ]),
              if (worker.skills.isNotEmpty) ...[
                const SizedBox(height: 14),
                _NeoSection(title: l.get('worker_skills'), children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: worker.skills
                          .map((s) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF6EFE6),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Color(0xFFD9C6B2),
                                        blurRadius: 4,
                                        offset: Offset(2, 2)),
                                    BoxShadow(
                                        color: Colors.white,
                                        blurRadius: 4,
                                        offset: Offset(-2, -2)),
                                  ],
                                ),
                                child: Text(s,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: _Brown.darkest)),
                              ))
                          .toList(),
                    ),
                  ),
                ]),
              ],
              if (worker.description != null &&
                  worker.description!.isNotEmpty) ...[
                const SizedBox(height: 14),
                _NeoSection(title: l.get('worker_about'), children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                    child: Text(worker.description!,
                        style: const TextStyle(
                            fontSize: 13, color: _Brown.darkest, height: 1.6)),
                  ),
                ]),
              ],
            ])),
          ),
        ],
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
        child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 90,
          height: 90,
          decoration:
              const BoxDecoration(color: _Brown.light, shape: BoxShape.circle),
          child: const Icon(Icons.group_add_rounded,
              size: 44, color: _Brown.darkest),
        ),
        const SizedBox(height: 20),
        Text(l.get('no_workers_yet'),
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _Brown.darkest)),
        const SizedBox(height: 8),
        Text(l.get('add_first_worker_hint'),
            style:
                const TextStyle(fontSize: 13, color: _Brown.dark, height: 1.5),
            textAlign: TextAlign.center),
        const SizedBox(height: 28),
        ElevatedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded),
          label: Text(l.get('add_first_worker'),
              style: const TextStyle(fontWeight: FontWeight.w800)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _Brown.darkest,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ]),
    ));
  }
}

// ─── Small helpers ────────────────────────────────────────────────────────────
class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatPill(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(value,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.7))),
      ]),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final WorkerStatus status;
  final bool compact;
  const _StatusBadge({required this.status, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    final label = _statusLabel(context, status);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 10, vertical: compact ? 2 : 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: compact ? 5.0 : 6.0,
            height: compact ? 5.0 : 6.0,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: compact ? 10.0 : 11.0,
                fontWeight: FontWeight.w700,
                color: color)),
      ]),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: _Brown.dark),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(
                fontSize: 12, color: _Brown.dark, fontWeight: FontWeight.w500)),
      ]);
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatCard(
      {required this.icon,
      required this.value,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _Brown.mid.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
                color: _Brown.darkest.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: _Brown.dark,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
      );
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _Brown.mid.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
                color: _Brown.darkest.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: _Brown.darkest)),
          const SizedBox(height: 10),
          Divider(height: 1, color: _Brown.mid.withOpacity(0.2)),
          const SizedBox(height: 6),
          child,
        ]),
      );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.4))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800, color: color)),
          ]),
        ),
      );
}

class _FormField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final bool required;
  final TextInputType? keyboardType;
  final int maxLines;
  const _FormField(
      {required this.ctrl,
      required this.label,
      required this.icon,
      this.required = false,
      this.keyboardType,
      this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: required
          ? (v) =>
              (v == null || v.trim().isEmpty) ? l.get('required_field') : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: _Brown.dark),
        filled: true,
        fillColor: _Brown.warm,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _Brown.mid.withOpacity(0.4))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _Brown.mid.withOpacity(0.35))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _Brown.dark, width: 2)),
        labelStyle: const TextStyle(
            color: _Brown.dark, fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _DetailItem(
      {required this.icon,
      required this.label,
      required this.value,
      this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: _Brown.light, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 17, color: _Brown.darkest)),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    color: _Brown.dark,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: valueColor ?? _Brown.darkest)),
          ]),
        ),
      ]),
    );
  }
}

// ── Neo Add Button (header) ───────────────────────────────────────────────────
class _NeoAddBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _NeoAddBtn({required this.onTap});
  @override
  State<_NeoAddBtn> createState() => _NeoAddBtnState();
}

class _NeoAddBtnState extends State<_NeoAddBtn>
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
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return GestureDetector(
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFF6EFE6),
            borderRadius: BorderRadius.circular(14),
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
                : [
                    const BoxShadow(
                        color: Color(0xFFD9C6B2),
                        blurRadius: 0,
                        offset: Offset(0, 4)),
                    const BoxShadow(
                        color: Color(0xFFD9C6B2),
                        blurRadius: 8,
                        offset: Offset(4, 4)),
                    const BoxShadow(
                        color: Colors.white,
                        blurRadius: 8,
                        offset: Offset(-4, -4))
                  ],
            border: Border.all(color: Colors.white.withOpacity(0.9), width: 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.add_rounded, color: Color(0xFFA85428), size: 17),
            const SizedBox(width: 5),
            Text(l.get('add'),
                style: const TextStyle(
                    color: Color(0xFFA85428),
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    );
  }
}

// ── Neo Stat Pill (outside header) ────────────────────────────────────────────
class _NeoStatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _NeoStatPill(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
          child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFF6EFE6),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: Color(0xFFD9C6B2), blurRadius: 0, offset: Offset(0, 4)),
            BoxShadow(
                color: Color(0xFFD9C6B2), blurRadius: 10, offset: Offset(4, 4)),
            BoxShadow(
                color: Colors.white, blurRadius: 10, offset: Offset(-4, -4)),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                  color: const Color(0xFFF6EFE6),
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    BoxShadow(
                        color: color.withOpacity(0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2)),
                    const BoxShadow(
                        color: Color(0xFFD9C6B2),
                        blurRadius: 0,
                        offset: Offset(0, 2))
                  ]),
              child: Icon(icon, size: 14, color: color)),
          const SizedBox(height: 5),
          Text(value,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w900, color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFC7B29C)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
      ));
}

// ── Neo Form Field for worker sheet ──────────────────────────────────────────
class _NeoFormField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final bool required;
  final TextInputType? keyboard;
  final int maxLines;
  const _NeoFormField(
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
        const SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
              color: const Color(0xFFF6EFE6),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                    color: Color(0xFFD9C6B2),
                    blurRadius: 5,
                    offset: Offset(3, 3)),
                BoxShadow(
                    color: Colors.white, blurRadius: 5, offset: Offset(-3, -3))
              ]),
          child: TextFormField(
            controller: ctrl,
            maxLines: maxLines,
            keyboardType: keyboard,
            style: const TextStyle(fontSize: 14, color: Color(0xFF7A3E1E)),
            validator: required
                ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
                : null,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: const Color(0xFFA85428), size: 18),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              hintText: label,
              hintStyle:
                  const TextStyle(color: Color(0xFFC7B29C), fontSize: 13),
            ),
          ),
        ),
      ]);
}

// ── Small label + notice used above structured worker-form fields ────────────
class _NeoFieldLabel extends StatelessWidget {
  final String text;
  const _NeoFieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFA85428)));
}

class _NeoFieldNotice extends StatelessWidget {
  final String text;
  const _NeoFieldNotice(this.text);
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
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
                  color: Colors.white, blurRadius: 6, offset: Offset(-3, -3))
            ]),
        child: Text(text,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFFA85428))),
      );
}

// ── Neo Save/Add Worker Button ────────────────────────────────────────────────
class _NeoSaveWorkerBtn extends StatefulWidget {
  final bool isEdit;
  final VoidCallback onTap;
  const _NeoSaveWorkerBtn({required this.isEdit, required this.onTap});
  @override
  State<_NeoSaveWorkerBtn> createState() => _NeoSaveWorkerBtnState();
}

class _NeoSaveWorkerBtnState extends State<_NeoSaveWorkerBtn>
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
          HapticFeedback.mediumImpact();
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
                      ))),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                    widget.isEdit
                        ? Icons.check_rounded
                        : Icons.person_add_rounded,
                    color: Colors.white,
                    size: 18),
                const SizedBox(width: 9),
                Text(widget.isEdit ? 'Save Changes' : 'Add Worker / Supplier',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2)),
              ]),
            ]),
          ),
        ),
      );
}

// ── Worker Profile Back Button ────────────────────────────────────────────────
class _WorkerProfileBackBtn extends StatefulWidget {
  @override
  State<_WorkerProfileBackBtn> createState() => _WorkerProfileBackBtnState();
}

class _WorkerProfileBackBtnState extends State<_WorkerProfileBackBtn>
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
          Navigator.of(context).pop();
        },
        onTapCancel: () => _c.reverse(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, child) =>
                Transform.scale(scale: 1.0 - 0.08 * _c.value, child: child),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                    color: Colors.white.withOpacity(0.35), width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.28),
                      blurRadius: 0,
                      offset: const Offset(0, 3)),
                  BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 8,
                      offset: const Offset(3, 4)),
                  BoxShadow(
                      color: Colors.white.withOpacity(0.12),
                      blurRadius: 6,
                      offset: const Offset(-2, -2)),
                ],
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ),
      );
}

// ── Worker Profile 3-dot Menu (header) ───────────────────────────────────────
class _WorkerProfileDotsMenu extends StatefulWidget {
  final VoidCallback? onEdit, onDelete;
  const _WorkerProfileDotsMenu({this.onEdit, this.onDelete});
  @override
  State<_WorkerProfileDotsMenu> createState() => _WorkerProfileDotsMenuState();
}

class _WorkerProfileDotsMenuState extends State<_WorkerProfileDotsMenu>
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

  void _open() {
    HapticFeedback.lightImpact();
    final items = <_DotItem>[
      if (widget.onEdit != null)
        _DotItem(Icons.edit_rounded, const Color(0xFF7C3AED), widget.onEdit!),
      if (widget.onDelete != null)
        _DotItem(
            Icons.delete_rounded, const Color(0xFFEF4444), widget.onDelete!),
    ];
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.18),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        final screenH = MediaQuery.of(ctx).size.height;
        final panelH = items.length * 58.0 + 20;
        const topPos = 80.0;
        return Stack(children: [
          Positioned.fill(
              child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(color: Colors.transparent))),
          Positioned(
            right: 16,
            top: topPos,
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(0.3, -0.2), end: Offset.zero)
                  .animate(curved),
              child: FadeTransition(
                  opacity: anim, child: _NeoDotsPanel(items: items)),
            ),
          ),
        ]);
      },
    );
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          _ctrl.forward();
        },
        onTapUp: (_) {
          _ctrl.reverse();
          _open();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.08 * _ctrl.value, child: child),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(13),
              border:
                  Border.all(color: Colors.white.withOpacity(0.35), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.28),
                    blurRadius: 0,
                    offset: const Offset(0, 3)),
                BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 8,
                    offset: const Offset(3, 4)),
                BoxShadow(
                    color: Colors.white.withOpacity(0.12),
                    blurRadius: 6,
                    offset: const Offset(-2, -2)),
              ],
            ),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                    3,
                    (i) => Container(
                          width: 3.5,
                          height: 3.5,
                          margin: const EdgeInsets.symmetric(vertical: 1.2),
                          decoration: const BoxDecoration(
                              color: Colors.white, shape: BoxShape.circle),
                        ))),
          ),
        ),
      );
}

// ── Neo Stat Card (profile) ───────────────────────────────────────────────────
class _NeoStatCard extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color color;
  const _NeoStatCard(
      {required this.icon,
      required this.value,
      required this.label,
      required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: const BoxDecoration(
          color: Color(0xFFF6EFE6),
          borderRadius: BorderRadius.all(Radius.circular(18)),
          boxShadow: [
            BoxShadow(
                color: Color(0xFFD9C6B2), blurRadius: 0, offset: Offset(0, 5)),
            BoxShadow(
                color: Color(0xFFD9C6B2), blurRadius: 14, offset: Offset(6, 6)),
            BoxShadow(
                color: Colors.white, blurRadius: 14, offset: Offset(-6, -6)),
          ],
        ),
        child: Column(children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFFA85428),
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
      );
}

// ── Neo Action Button (Call / Message) ────────────────────────────────────────
class _NeoActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _NeoActionButton(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
  @override
  State<_NeoActionButton> createState() => _NeoActionButtonState();
}

class _NeoActionButtonState extends State<_NeoActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  bool _p = false;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
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
          setState(() => _p = true);
          _c.forward();
        },
        onTapUp: (_) {
          setState(() => _p = false);
          _c.reverse();
          widget.onTap();
        },
        onTapCancel: () {
          setState(() => _p = false);
          _c.reverse();
        },
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.04 * _c.value, child: child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFFF6EFE6),
              borderRadius: BorderRadius.circular(16),
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
                          spreadRadius: -1),
                    ]
                  : [
                      BoxShadow(
                          color: widget.color.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3)),
                      const BoxShadow(
                          color: Color(0xFFD9C6B2),
                          blurRadius: 0,
                          offset: Offset(0, 4)),
                      const BoxShadow(
                          color: Color(0xFFD9C6B2),
                          blurRadius: 10,
                          offset: Offset(4, 4)),
                      const BoxShadow(
                          color: Colors.white,
                          blurRadius: 10,
                          offset: Offset(-4, -4)),
                    ],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(widget.icon, size: 16, color: widget.color),
              const SizedBox(width: 7),
              Text(widget.label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: widget.color)),
            ]),
          ),
        ),
      );
}

// ── Neo Section Card ──────────────────────────────────────────────────────────
class _NeoSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _NeoSection({required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF6EFE6),
          borderRadius: BorderRadius.all(Radius.circular(22)),
          boxShadow: [
            BoxShadow(
                color: Color(0xFFD9C6B2), blurRadius: 0, offset: Offset(0, 5)),
            BoxShadow(
                color: Color(0xFFD9C6B2), blurRadius: 14, offset: Offset(6, 6)),
            BoxShadow(
                color: Colors.white, blurRadius: 14, offset: Offset(-6, -6)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Text(title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: _Brown.darkest,
                    letterSpacing: -0.2)),
          ),
          const SizedBox(height: 8),
          Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                Colors.transparent,
                _Brown.mid.withOpacity(0.25),
                Colors.transparent
              ]))),
          ...children,
        ]),
      );
}

// ── Neo Detail Row ────────────────────────────────────────────────────────────
// ── Basic Information "Specialty" row (Worker Profile only) ────────────────────
// Same icon/label header language as _NeoDetailRow below (which stays
// unchanged for every other Basic/Additional Info row), but renders every
// selected specialty as a wrapping chip instead of collapsing extras into
// "+N more" — display only, see _workerSpecialtyLabels.
class _NeoSpecialtiesRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final List<String> specialties;
  const _NeoSpecialtiesRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.specialties,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0x0A000000)))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                      color: const Color(0xFFF6EFE6),
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0xFFD9C6B2),
                            blurRadius: 4,
                            offset: Offset(2, 2)),
                        BoxShadow(
                            color: Colors.white,
                            blurRadius: 4,
                            offset: Offset(-2, -2))
                      ]),
                  child: Icon(icon, color: iconColor, size: 14)),
              const SizedBox(width: 11),
              Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFFA85428)))),
            ]),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: specialties
                  .map((s) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: _Brown.mid.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: _Brown.mid.withOpacity(0.25)),
                        ),
                        child: Text(s,
                            style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: _Brown.darkest)),
                      ))
                  .toList(),
            ),
          ],
        ),
      );
}

class _NeoDetailRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label, value;
  final Color? valueColor;
  final bool isLast;
  const _NeoDetailRow(
      {required this.icon,
      required this.iconColor,
      required this.label,
      required this.value,
      this.valueColor,
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
                  color: const Color(0xFFF6EFE6),
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0xFFD9C6B2),
                        blurRadius: 4,
                        offset: Offset(2, 2)),
                    BoxShadow(
                        color: Colors.white,
                        blurRadius: 4,
                        offset: Offset(-2, -2))
                  ]),
              child: Icon(icon, color: iconColor, size: 14)),
          const SizedBox(width: 11),
          Expanded(
              child: Text(label,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFFA85428)))),
          Flexible(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: valueColor ?? _Brown.darkest),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
        ]),
      );
}

// ── Neo Outline Button (Cancel) ───────────────────────────────────────────────
class _NeoOutlineBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _NeoOutlineBtn({required this.label, required this.onTap});
  @override
  State<_NeoOutlineBtn> createState() => _NeoOutlineBtnState();
}

class _NeoOutlineBtnState extends State<_NeoOutlineBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  bool _p = false;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
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
          setState(() => _p = true);
          _c.forward();
        },
        onTapUp: (_) {
          setState(() => _p = false);
          _c.reverse();
          widget.onTap();
        },
        onTapCancel: () {
          setState(() => _p = false);
          _c.reverse();
        },
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.04 * _c.value, child: child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF6EFE6),
              borderRadius: BorderRadius.circular(16),
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
                          spreadRadius: -1),
                    ]
                  : [
                      const BoxShadow(
                          color: Color(0xFFD9C6B2),
                          blurRadius: 0,
                          offset: Offset(0, 3)),
                      const BoxShadow(
                          color: Color(0xFFD9C6B2),
                          blurRadius: 8,
                          offset: Offset(3, 3)),
                      const BoxShadow(
                          color: Colors.white,
                          blurRadius: 8,
                          offset: Offset(-3, -3)),
                    ],
            ),
            child: Text(widget.label,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFA85428))),
          ),
        ),
      );
}

// ── Neo Delete Button ─────────────────────────────────────────────────────────
class _NeoDeleteBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _NeoDeleteBtn({required this.label, required this.onTap});
  @override
  State<_NeoDeleteBtn> createState() => _NeoDeleteBtnState();
}

class _NeoDeleteBtnState extends State<_NeoDeleteBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  bool _p = false;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          HapticFeedback.mediumImpact();
          setState(() => _p = true);
          _c.forward();
        },
        onTapUp: (_) {
          setState(() => _p = false);
          _c.reverse();
          widget.onTap();
        },
        onTapCancel: () {
          setState(() => _p = false);
          _c.reverse();
        },
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.04 * _c.value, child: child),
          child: Container(
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                  colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              boxShadow: _p
                  ? [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 3,
                          offset: const Offset(1, 2))
                    ]
                  : [
                      const BoxShadow(
                          color: Color(0xFFB91C1C),
                          blurRadius: 0,
                          offset: Offset(0, 4)),
                      BoxShadow(
                          color: const Color(0xFFEF4444).withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 6))
                    ],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.delete_rounded, color: Colors.white, size: 17),
              const SizedBox(width: 7),
              Text(widget.label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ]),
          ),
        ),
      );
}
