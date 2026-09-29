import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/presentation/providers/app_providers.dart';
import '../../../../shared/helpers/image_source_picker.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/shared_widgets.dart' show ProfileAvatarImage;
import '../theme/customer_design.dart';

const _nBg = Color(0xFFEEEEF5);
const _nDark = Color(0xFFBEBECF);
const _nLight = Colors.white;

/// Finds the first date on/after [from] (clamped to [firstDate]) for which
/// [isSelectable] is true, without exceeding [lastDate]. The provider's
/// effective working days are never empty (backward-compat default is all
/// seven), so this always resolves within a week in practice; [firstDate] is
/// returned as a last-resort fallback if it somehow doesn't.
DateTime _nearestSelectableDate(
  DateTime from,
  DateTime firstDate,
  DateTime lastDate,
  bool Function(DateTime) isSelectable,
) {
  var d = from.isBefore(firstDate) ? firstDate : from;
  while (!isSelectable(d)) {
    d = d.add(const Duration(days: 1));
    if (d.isAfter(lastDate)) return firstDate;
  }
  return d;
}

class NewOrderScreen extends ConsumerStatefulWidget {
  final UserModel provider;
  final String? categoryId;
  final String? categoryNameKey;
  // Optional AI Service Assistant prefill (Phase 5). When either is
  // non-empty after trimming, the Custom Request title/description fields
  // are pre-populated and Custom Request is preselected — the Customer can
  // still edit or replace either field before submitting.
  final String? initialTitle;
  final String? initialDescription;
  // AI Service Assistant category context (separate from [categoryId], which
  // is also used by the unrelated category-browsing flow via
  // ProviderProfileScreen and must keep showing every provider service).
  // When non-null/non-empty, only services whose ServiceModel.categoryId
  // matches this — and the header subtitle — are affected; see build().
  final String? matchedCategoryId;
  const NewOrderScreen({
    super.key,
    required this.provider,
    this.categoryId,
    this.categoryNameKey,
    this.initialTitle,
    this.initialDescription,
    this.matchedCategoryId,
  });
  @override
  ConsumerState<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends ConsumerState<NewOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _profileAddress = '';
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _loading = false;
  // Selected services, in the order the customer tapped them (San3a
  // multi-service selection). Mutually exclusive with Custom Request.
  List<ServiceModel> _selectedServices = [];
  bool _isCustomRequest = false;
  String? _timeError;
  Uint8List? _photoBytes;
  String? _photoPath;
  bool _pickingPhoto = false;
  OrderPriority _priority = OrderPriority.normal;

  // Live provider availability (backward-compatible defaults resolved by
  // UserModel.effectiveWork*), refreshed every build from userByIdProvider.
  List<String> _providerWorkingDays = List<String>.from(kCanonicalWorkingDays);
  String _providerWorkStart = '08:00';
  String _providerWorkEnd = '18:00';
  int _providerStartMinutes = 8 * 60;
  int _providerEndMinutes = 18 * 60;
  String get _workingHoursLabel => '$_providerWorkStart – $_providerWorkEnd';

  bool _isWorkingDay(DateTime d) =>
      _providerWorkingDays.contains(kWeekdayToCanonicalDay[d.weekday]);

  bool _isTimeWithinRange(TimeOfDay t) {
    final mins = t.hour * 60 + t.minute;
    return mins >= _providerStartMinutes && mins < _providerEndMinutes;
  }

  /// Applies the given provider's effective schedule to local state, and
  /// drops a previously selected date/time that's no longer valid (e.g. the
  /// provider's live schedule changed) instead of silently keeping it.
  void _syncProviderSchedule(UserModel effectiveProvider) {
    _providerWorkingDays = effectiveProvider.effectiveWorkingDays;
    _providerWorkStart = effectiveProvider.effectiveWorkStartTime;
    _providerWorkEnd = effectiveProvider.effectiveWorkEndTime;
    _providerStartMinutes = effectiveProvider.effectiveWorkStartMinutes;
    _providerEndMinutes = effectiveProvider.effectiveWorkEndMinutes;
    if (_selectedDate != null && !_isWorkingDay(_selectedDate!)) {
      _selectedDate = null;
    }
    if (_selectedTime != null && !_isTimeWithinRange(_selectedTime!)) {
      _selectedTime = null;
      _timeError = null;
    }
  }

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider);
    if (user != null) {
      _nameCtrl.text = user.fullName;
      _profileAddress = user.fullAddress;
    }

    final trimmedInitialTitle = widget.initialTitle?.trim() ?? '';
    final trimmedInitialDescription = widget.initialDescription?.trim() ?? '';
    if (trimmedInitialTitle.isNotEmpty ||
        trimmedInitialDescription.isNotEmpty) {
      _isCustomRequest = true;
      _selectedServices = [];
      if (trimmedInitialTitle.isNotEmpty) _titleCtrl.text = trimmedInitialTitle;
      if (trimmedInitialDescription.isNotEmpty) {
        _descCtrl.text = trimmedInitialDescription;
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // Lets the customer either take a new photo of the problem or choose an
  // existing one — the same compression/limits are applied to both, and the
  // rest of the order-creation upload flow is untouched.
  Future<void> _pickOrderPhoto() async {
    if (_pickingPhoto) return;
    setState(() => _pickingPhoto = true);
    try {
      final picked = await pickImageWithSourceChoice(
        context: context,
        accent: CustomerColors.dark,
        title: 'Add a Photo',
        imageQuality: 70,
        maxWidth: 1280,
        maxHeight: 1280,
        onError: (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Could not pick image. Check permissions.')));
          }
        },
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _photoBytes = bytes;
          _photoPath = picked.path;
        });
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not pick image')));
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  void _removePhoto() => setState(() {
        _photoBytes = null;
        _photoPath = null;
      });

  Future<void> _openGoogleMaps() async {
    final query = _profileAddress.trim();
    if (query.isEmpty) return;
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
    if (await canLaunchUrl(uri))
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // Short title summary for the selected services, in selection order:
  // one service -> its name; two or more -> "First Name +N more".
  static String _serviceSelectionSummary(List<ServiceModel> services) {
    if (services.isEmpty) return '';
    if (services.length == 1) return services.first.name;
    return '${services.first.name} +${services.length - 1} more';
  }

  // Readable multi-line description built from the selected services, in
  // selection order (e.g. "Service One: First description").
  static String _serviceSelectionDescription(List<ServiceModel> services) =>
      services.map((s) => '${s.name}: ${s.description}').join('\n');

  void _toggleService(ServiceModel svc) {
    HapticFeedback.lightImpact();
    setState(() {
      _isCustomRequest = false;
      final idx = _selectedServices.indexWhere((s) => s.id == svc.id);
      if (idx >= 0) {
        _selectedServices.removeAt(idx);
      } else {
        _selectedServices.add(svc);
      }
      if (_selectedServices.isEmpty) {
        _titleCtrl.clear();
        _descCtrl.clear();
      } else {
        _titleCtrl.text = _serviceSelectionSummary(_selectedServices);
        _descCtrl.text = _serviceSelectionDescription(_selectedServices);
      }
    });
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_profileAddress.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please set your address in profile first.'),
          backgroundColor: CustomerColors.error));
      return;
    }
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context).get('required_field'))));
      return;
    }
    if (!_isWorkingDay(_selectedDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'This provider is not available on the selected date. Available: ${formatWorkingDaysLabel(_providerWorkingDays)}.'),
          backgroundColor: CustomerColors.error));
      return;
    }
    if (_selectedTime == null || !_isTimeWithinRange(_selectedTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Please select a time between $_providerWorkStart and $_providerWorkEnd.'),
          backgroundColor: CustomerColors.error));
      return;
    }
    setState(() => _loading = true);
    final t = _selectedTime!;
    final fullDate = DateTime(_selectedDate!.year, _selectedDate!.month,
        _selectedDate!.day, t.hour, t.minute);
    final user = ref.read(authProvider);
    final now = DateTime.now();
    final orderId = 'order_${now.millisecondsSinceEpoch}';
    // Phase 6B2: same uid used for both the Storage path's {customerUid}
    // segment and OrderModel.customerId below, so Storage Rules'
    // request.auth.uid == customerUid check always matches the value that
    // ends up in orders/{orderId}.customerId once the order document exists.
    final customerUid = user?.id ?? 'current_user';
    final providerRole = widget.provider.role == UserRole.contractor
        ? 'contractor'
        : 'professional';

    // Upload the attached photo (if any) to Firebase Storage first, so we
    // never show success without the image actually being persisted.
    List<String> imageUrls = const [];
    if (_photoBytes != null) {
      try {
        final storageRef = FirebaseStorage.instance.ref().child(
            'orders/$customerUid/$orderId/images/main_${now.millisecondsSinceEpoch}.jpg');
        await storageRef.putData(
          _photoBytes!,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        imageUrls = [await storageRef.getDownloadURL()];
      } catch (e) {
        debugPrint('ORDER_IMAGE_UPLOAD_ERROR: $e');
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Row(children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                  child: Text('Failed to upload photo. Please try again.')),
            ]),
            backgroundColor: CustomerColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        }
        return;
      }
    }

    final selectedServicesSnapshot = List<ServiceModel>.from(_selectedServices);
    final totalServicePrice =
        selectedServicesSnapshot.fold<double>(0, (sum, s) => sum + s.price);

    final order = OrderModel(
      id: orderId,
      customerId: customerUid,
      customerName: _nameCtrl.text.isNotEmpty
          ? _nameCtrl.text
          : (user?.fullName ?? 'Customer'),
      customerPhone:
          (user != null && user.phone.isNotEmpty) ? user.phone : null,
      providerId: widget.provider.id,
      providerName: widget.provider.fullName,
      providerPhone:
          widget.provider.phone.isNotEmpty ? widget.provider.phone : null,
      providerRole: providerRole,
      title: _titleCtrl.text,
      description: _descCtrl.text,
      area: _profileAddress,
      selectedServiceId: selectedServicesSnapshot.length == 1
          ? selectedServicesSnapshot.first.id
          : null,
      selectedServiceName: selectedServicesSnapshot.isEmpty
          ? null
          : _serviceSelectionSummary(selectedServicesSnapshot),
      selectedServicePrice:
          selectedServicesSnapshot.isEmpty ? null : totalServicePrice,
      selectedServices: selectedServicesSnapshot,
      serviceDate: fullDate,
      status: OrderStatus.pending,
      priority: _priority,
      photoPath: _photoPath,
      photoBytes: _photoBytes,
      createdAt: now,
      updatedAt: now,
      categoryId: widget.categoryId,
      categoryNameKey: widget.categoryNameKey,
      imageUrls: imageUrls,
    );
    try {
      await ref.read(ordersProvider.notifier).createOrderInFirestore(order);
      ref.read(ordersProvider.notifier).addOrder(order);
      createOrderNotification(
        userId: order.providerId,
        title: 'New Order',
        message: 'You received a new order request.',
        orderId: order.id,
      );
    } catch (e) {
      debugPrint('ORDER_CREATE_WITH_IMAGE_ERROR: $e');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text('Failed to submit order. Please try again.')),
          ]),
          backgroundColor: CustomerColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
      return;
    }
    if (mounted) setState(() => _loading = false);
    if (mounted) {
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 8),
          Text(l.get('order_sent')),
        ]),
        backgroundColor: const Color(0xFF052659),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      Navigator.of(context).popUntil((route) => route.isFirst);
      ref.read(navIndexProvider.notifier).state = 2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    // AI Service Assistant category context: when present, restrict the
    // displayed services to this category only (trim/lowercase-normalized so
    // minor casing/whitespace differences between the AI result and Firestore
    // still match) and drop legacy services with no categoryId at all.
    // Normal flows (matchedCategoryId not passed) keep showing every service,
    // exactly as before.
    final normalizedMatchedCategoryId =
        widget.matchedCategoryId?.trim().toLowerCase();
    final hasMatchedCategory = normalizedMatchedCategoryId != null &&
        normalizedMatchedCategoryId.isNotEmpty;
    final displayedServices = hasMatchedCategory
        ? widget.provider.servicesList.where((svc) {
            final svcCategoryId = svc.categoryId?.trim().toLowerCase();
            return svcCategoryId != null &&
                svcCategoryId.isNotEmpty &&
                svcCategoryId == normalizedMatchedCategoryId;
          }).toList()
        : widget.provider.servicesList;
    final hasServices = displayedServices.isNotEmpty;

    // Watched once per build (not per service card) so each card can look up
    // its category by id without its own ref.watch call.
    final categories =
        ref.watch(categoriesProvider).valueOrNull ?? const <CategoryModel>[];
    final categoriesById = {for (final c in categories) c.id: c};

    // Resolve the matched category's display name from the already-loaded
    // Firestore categories stream (never hardcoded) for the header subtitle.
    String? matchedCategoryLabel;
    if (hasMatchedCategory) {
      for (final c in categories) {
        if (c.id.trim().toLowerCase() == normalizedMatchedCategoryId) {
          matchedCategoryLabel = l.get(c.nameKey);
          break;
        }
      }
    }

    // Live provider document (real UID, not name-matched) so availability
    // enforcement uses the provider's current schedule; falls back to the
    // passed-in provider while the stream is initially loading or errors.
    final effectiveProvider =
        ref.watch(userByIdProvider(widget.provider.id)).valueOrNull ??
            widget.provider;
    _syncProviderSchedule(effectiveProvider);

    return Scaffold(
      backgroundColor: _nBg,
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── HEADER ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
                child: _NeoHeader(
              provider: widget.provider,
              l: l,
              subtitleOverride: matchedCategoryLabel,
            )),

            // ── BODY ────────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                child: Form(
                  key: _formKey,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── 1. Service selection ───────────────────────────────
                        if (hasServices) ...[
                          _NeoSectionLabel(l.get('choose_service')),
                          const SizedBox(height: 10),
                          ...displayedServices.map((svc) {
                            final sel = !_isCustomRequest &&
                                _selectedServices.any((s) => s.id == svc.id);
                            return _NeoServiceTile(
                              service: svc,
                              category: categoriesById[svc.categoryId],
                              isSelected: sel,
                              onTap: () => _toggleService(svc),
                            );
                          }),
                          _NeoCustomRequestTile(
                            isSelected: _isCustomRequest,
                            onTap: () {
                              // Already on Custom Request — do not wipe out
                              // an AI-prefilled (or manually edited) title/
                              // description just because the tile is tapped
                              // again.
                              if (_isCustomRequest) return;
                              HapticFeedback.lightImpact();
                              setState(() {
                                _isCustomRequest = true;
                                _selectedServices = [];
                                _titleCtrl.clear();
                                _descCtrl.clear();
                              });
                            },
                            l: l,
                          ),
                        ],

                        // ── 2. Full name ───────────────────────────────────────
                        _NeoSectionLabel(l.get('full_name')),
                        const SizedBox(height: 8),
                        _NeoTextField(
                          controller: _nameCtrl,
                          hint: 'Your full name',
                          icon: Icons.person_rounded,
                          iconColor: const Color(0xFF7C3AED),
                          validator: (v) => (v == null || v.isEmpty)
                              ? l.get('required_name')
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // ── 3. Address ─────────────────────────────────────────
                        _NeoSectionLabel('Address'),
                        const SizedBox(height: 8),
                        _NeoAddressTile(
                          address: _profileAddress,
                          onTap: _profileAddress.trim().isEmpty
                              ? null
                              : _openGoogleMaps,
                        ),
                        const SizedBox(height: 16),

                        // ── 4. Title ───────────────────────────────────────────
                        _NeoSectionLabel(l.get('order_title')),
                        const SizedBox(height: 8),
                        _NeoTextField(
                          controller: _titleCtrl,
                          hint: 'e.g. Fix electrical panel',
                          icon: Icons.title_rounded,
                          iconColor: const Color(0xFF0EA5E9),
                          validator: (v) => (v == null || v.isEmpty)
                              ? l.get('required_field')
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // ── 5. Description ─────────────────────────────────────
                        _NeoSectionLabel(l.get('order_desc')),
                        const SizedBox(height: 8),
                        _NeoTextField(
                          controller: _descCtrl,
                          hint: 'Describe your request in detail...',
                          icon: Icons.description_outlined,
                          iconColor: const Color(0xFF10B981),
                          maxLines: 4,
                          validator: (v) => (v == null || v.isEmpty)
                              ? l.get('required_field')
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // ── 6. Date ─────────────────────────────────────────────
                        _NeoSectionLabel(l.get('order_date')),
                        const SizedBox(height: 8),
                        _NeoDateField(
                          selectedDate: _selectedDate,
                          workingDays: _providerWorkingDays,
                          onChanged: (d) => setState(() => _selectedDate = d),
                        ),
                        const SizedBox(height: 16),

                        // ── 7. Time ─────────────────────────────────────────────
                        _NeoSectionLabel(l.get('order_service_time')),
                        const SizedBox(height: 8),
                        _NeoTimeField(
                          selectedTime: _selectedTime,
                          hasError: _timeError != null,
                          fallbackInitialTime: TimeOfDay(
                              hour: _providerStartMinutes ~/ 60,
                              minute: _providerStartMinutes % 60),
                          onChanged: (t) {
                            if (!_isTimeWithinRange(t)) {
                              setState(() {
                                _timeError =
                                    'Please select a time between $_providerWorkStart and $_providerWorkEnd.';
                              });
                            } else {
                              setState(() {
                                _selectedTime = t;
                                _timeError = null;
                              });
                            }
                          },
                        ),
                        if (_timeError != null) ...[
                          const SizedBox(height: 8),
                          Row(children: [
                            const Icon(Icons.warning_rounded,
                                size: 13, color: CustomerColors.error),
                            const SizedBox(width: 5),
                            Expanded(
                                child: Text(_timeError!,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: CustomerColors.error))),
                          ]),
                        ],
                        const SizedBox(height: 10),
                        _AvailabilityInfoLine(
                          workingDays: _providerWorkingDays,
                          hoursLabel: _workingHoursLabel,
                        ),
                        const SizedBox(height: 16),

                        // ── 8. Priority ────────────────────────────────────────
                        _NeoSectionLabel('Priority'),
                        const SizedBox(height: 8),
                        _NeoPrioritySelector(
                          selected: _priority,
                          onChanged: (p) {
                            HapticFeedback.lightImpact();
                            setState(() => _priority = p);
                          },
                        ),
                        const SizedBox(height: 16),

                        // ── 9. Photo ───────────────────────────────────────────
                        _NeoSectionLabel(l.get('attach_photo')),
                        const SizedBox(height: 8),
                        _NeoPhotoTile(
                          photoBytes: _photoBytes,
                          pickingPhoto: _pickingPhoto,
                          onPick: _pickOrderPhoto,
                          onRemove: _removePhoto,
                          l: l,
                        ),
                        const SizedBox(height: 16),

                        // ── 10. Price summary ───────────────────────────────────
                        if (_selectedServices.isNotEmpty) ...[
                          _NeoPriceBanner(
                              price: _selectedServices.fold<double>(
                                  0, (sum, s) => sum + s.price)),
                          const SizedBox(height: 16),
                        ],

                        // ── 11. Submit ─────────────────────────────────────────
                        _NeoSubmitButton(
                            loading: _loading, onTap: _submit, l: l),
                        const SizedBox(height: 32),
                      ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _NeoHeader extends StatelessWidget {
  final UserModel provider;
  final AppLocalizations l;
  // AI Service Assistant matched category display name (already localized).
  // When null, falls back to the provider's own specialty — unchanged from
  // prior behavior.
  final String? subtitleOverride;
  const _NeoHeader(
      {required this.provider, required this.l, this.subtitleOverride});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        // Light blue direction matching the Customer Notifications header
        // (see NotificationsScreen's SliverAppBar), not the dark Home header.
        gradient: LinearGradient(
          colors: [CustomerColors.darkest, CustomerColors.dark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Stack(children: [
        Positioned(
            top: -40,
            right: -40,
            child:
                _Orb(size: 180, color: const Color(0xFF0EA5E9), opacity: 0.15)),
        Positioned(
            bottom: -20,
            left: -20,
            child:
                _Orb(size: 130, color: const Color(0xFF7C3AED), opacity: 0.12)),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // back
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.22)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 16),
                ),
              ),
              const SizedBox(height: 18),
              Row(children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: const Icon(Icons.receipt_long_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.get('new_order'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5)),
                        Text(provider.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.65),
                                fontSize: 13)),
                      ]),
                ),
              ]),
              const SizedBox(height: 20),
              // Provider chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: Row(children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ProfileAvatarImage(
                      imageUrl: provider.avatar,
                      size: 38,
                      borderRadius: 12,
                      fallbackText: provider.fullName.isNotEmpty
                          ? provider.fullName
                          : '?',
                      fallbackTextStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(provider.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                          Text(subtitleOverride ?? (provider.specialty ?? ''),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.65),
                                  fontSize: 12)),
                        ]),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C853).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF00C853).withOpacity(0.5)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                              color: Color(0xFF00C853),
                              shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      const Text('Available',
                          style: TextStyle(
                              color: Color(0xFF00C853),
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Orb extends StatelessWidget {
  final double size, opacity;
  final Color color;
  const _Orb({required this.size, required this.color, required this.opacity});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
              colors: [color.withOpacity(opacity), Colors.transparent]),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// ── SECTION LABEL
// ─────────────────────────────────────────────────────────────────────────────
class _NeoSectionLabel extends StatelessWidget {
  final String text;
  const _NeoSectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 4,
          height: 15,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF4C1D95)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF7C3AED).withOpacity(0.45),
                  blurRadius: 5,
                  offset: const Offset(0, 2))
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(text.toUpperCase(),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF444466),
                letterSpacing: 1.4)),
      ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// ── NEO CARD wrapper
// ─────────────────────────────────────────────────────────────────────────────
class _NeoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  const _NeoCard({required this.child, this.padding});
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: const BoxDecoration(
          color: _nBg,
          borderRadius: BorderRadius.all(Radius.circular(20)),
          boxShadow: [
            BoxShadow(color: _nDark, blurRadius: 0, offset: Offset(0, 5)),
            BoxShadow(color: _nDark, blurRadius: 14, offset: Offset(6, 6)),
            BoxShadow(color: _nLight, blurRadius: 14, offset: Offset(-6, -6)),
          ],
        ),
        child: child,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// ── TEXT FIELD (Neo style)
// ─────────────────────────────────────────────────────────────────────────────
class _NeoTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final Color iconColor;
  final int maxLines;
  final String? Function(String?)? validator;
  const _NeoTextField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.iconColor,
    this.maxLines = 1,
    this.validator,
  });

  Color get _dark => Color.lerp(iconColor, Colors.black, 0.35)!;

  @override
  Widget build(BuildContext context) => _NeoCard(
        child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF22224A)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9999BB), fontSize: 13),
            prefixIcon: Padding(
              padding: EdgeInsets.only(
                  left: 14,
                  right: 10,
                  bottom: maxLines > 1 ? (maxLines * 18.0) : 0),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [iconColor, _dark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: iconColor.withOpacity(0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 3)),
                    BoxShadow(
                        color: _dark.withOpacity(0.9),
                        blurRadius: 0,
                        offset: const Offset(0, 3)),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 62),
            filled: true,
            fillColor: _nBg,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide:
                    const BorderSide(color: Color(0xFF7C3AED), width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide:
                    const BorderSide(color: CustomerColors.error, width: 1.5)),
            contentPadding: EdgeInsets.symmetric(
                horizontal: 16, vertical: maxLines > 1 ? 16 : 0),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// ── ADDRESS TILE
// ─────────────────────────────────────────────────────────────────────────────
class _NeoAddressTile extends StatelessWidget {
  final String address;
  final VoidCallback? onTap;
  const _NeoAddressTile({required this.address, this.onTap});
  @override
  Widget build(BuildContext context) {
    final empty = address.trim().isEmpty;
    return GestureDetector(
      onTap: onTap,
      child: _NeoCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: empty
                        ? [const Color(0xFFEF4444), const Color(0xFF991B1B)]
                        : [const Color(0xFFF59E0B), const Color(0xFFB45309)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: (empty
                              ? const Color(0xFFEF4444)
                              : const Color(0xFFF59E0B))
                          .withOpacity(0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 3)),
                  BoxShadow(
                      color: (empty
                              ? const Color(0xFF991B1B)
                              : const Color(0xFFB45309))
                          .withOpacity(0.9),
                      blurRadius: 0,
                      offset: const Offset(0, 3)),
                ],
              ),
              child: const Icon(Icons.location_on_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Text(
              empty ? 'No address set — update your profile first.' : address,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color:
                    empty ? const Color(0xFFEF4444) : const Color(0xFF22224A),
              ),
            )),
            if (!empty)
              const Icon(Icons.open_in_new_rounded,
                  size: 14, color: Color(0xFF9999BB)),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── SERVICE TILE
// ─────────────────────────────────────────────────────────────────────────────
class _NeoServiceTile extends StatefulWidget {
  final ServiceModel service;
  final CategoryModel? category;
  final bool isSelected;
  final VoidCallback onTap;
  const _NeoServiceTile(
      {required this.service,
      required this.category,
      required this.isSelected,
      required this.onTap});
  @override
  State<_NeoServiceTile> createState() => _NeoServiceTileState();
}

class _NeoServiceTileState extends State<_NeoServiceTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 80));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) =>
            Transform.scale(scale: 1.0 - 0.02 * _ctrl.value, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: _nBg,
            borderRadius: BorderRadius.circular(18),
            border: widget.isSelected
                ? Border.all(color: const Color(0xFF052659), width: 2)
                : null,
            boxShadow: widget.isSelected
                ? const [
                    BoxShadow(
                        color: _nDark, blurRadius: 2, offset: Offset(2, 2)),
                    BoxShadow(
                        color: _nLight, blurRadius: 2, offset: Offset(-2, -2)),
                  ]
                : const [
                    BoxShadow(
                        color: _nDark, blurRadius: 0, offset: Offset(0, 5)),
                    BoxShadow(
                        color: _nDark, blurRadius: 12, offset: Offset(5, 5)),
                    BoxShadow(
                        color: _nLight, blurRadius: 12, offset: Offset(-5, -5)),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              // service icon
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.isSelected
                        ? [const Color(0xFF052659), const Color(0xFF0A3D7A)]
                        : [const Color(0xFF0EA5E9), const Color(0xFF0369A1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                        color: (widget.isSelected
                                ? const Color(0xFF052659)
                                : const Color(0xFF0EA5E9))
                            .withOpacity(0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 3)),
                    BoxShadow(
                        color: widget.isSelected
                            ? const Color(0xFF021024)
                            : const Color(0xFF0369A1),
                        blurRadius: 0,
                        offset: const Offset(0, 3)),
                  ],
                ),
                child: const Icon(Icons.build_circle_outlined,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(widget.service.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: widget.isSelected
                                ? const Color(0xFF052659)
                                : const Color(0xFF22224A))),
                    _ServiceCategoryBadge(
                        category: widget.category,
                        color: const Color(0xFF0369A1)),
                    const SizedBox(height: 2),
                    Text(widget.service.description,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF9999BB)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ])),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF052659), Color(0xFF0A3D7A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0xFF021024),
                          blurRadius: 0,
                          offset: Offset(0, 3)),
                    ],
                  ),
                  child: Text('₪${widget.service.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
                if (widget.isSelected) ...[
                  const SizedBox(height: 4),
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF052659), size: 16),
                ],
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── SERVICE CATEGORY BADGE
// Small, secondary, single-line label showing the service's live Firestore
// category (never guessed from name/specialty). Renders nothing when the
// service has no categoryId, or that id doesn't match a currently loaded
// category — never shows a placeholder like "Unknown Category".
// ─────────────────────────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────
// ── CUSTOM REQUEST TILE
// ─────────────────────────────────────────────────────────────────────────────
class _NeoCustomRequestTile extends StatefulWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final AppLocalizations l;
  const _NeoCustomRequestTile(
      {required this.isSelected, required this.onTap, required this.l});
  @override
  State<_NeoCustomRequestTile> createState() => _NeoCustomRequestTileState();
}

class _NeoCustomRequestTileState extends State<_NeoCustomRequestTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 80));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) {
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.02 * _ctrl.value, child: child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _nBg,
              borderRadius: BorderRadius.circular(18),
              border: widget.isSelected
                  ? Border.all(color: const Color(0xFF7C3AED), width: 2)
                  : null,
              boxShadow: widget.isSelected
                  ? const [
                      BoxShadow(
                          color: _nDark, blurRadius: 2, offset: Offset(2, 2)),
                      BoxShadow(
                          color: _nLight, blurRadius: 2, offset: Offset(-2, -2))
                    ]
                  : const [
                      BoxShadow(
                          color: _nDark, blurRadius: 0, offset: Offset(0, 4)),
                      BoxShadow(
                          color: _nDark, blurRadius: 10, offset: Offset(4, 4)),
                      BoxShadow(
                          color: _nLight,
                          blurRadius: 10,
                          offset: Offset(-4, -4))
                    ],
            ),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.isSelected
                        ? [const Color(0xFF7C3AED), const Color(0xFF4C1D95)]
                        : [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF7C3AED).withOpacity(0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 3)),
                    const BoxShadow(
                        color: Color(0xFF4C1D95),
                        blurRadius: 0,
                        offset: Offset(0, 3)),
                  ],
                ),
                child: const Icon(Icons.tune_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(widget.l.get('custom_request'),
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: widget.isSelected
                                ? const Color(0xFF7C3AED)
                                : const Color(0xFF22224A))),
                    const Text('Describe a custom service',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF9999BB))),
                  ])),
              if (widget.isSelected)
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF7C3AED), size: 18),
            ]),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// ── AVAILABILITY INFO LINE — small hint under date/time showing the
// provider's declared working days/hours (informational only; no booking-
// conflict/occupied-slot detection here).
// ─────────────────────────────────────────────────────────────────────────────
class _AvailabilityInfoLine extends StatelessWidget {
  final List<String> workingDays;
  final String hoursLabel;
  const _AvailabilityInfoLine(
      {required this.workingDays, required this.hoursLabel});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 13, color: Color(0xFF9999BB)),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              'Available: ${formatWorkingDaysLabel(workingDays)} • $hoursLabel',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF9999BB)),
            ),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// ── DATE FIELD — standard Material showDatePicker, Neo-styled trigger row
// ─────────────────────────────────────────────────────────────────────────────
class _NeoDateField extends StatelessWidget {
  final DateTime? selectedDate;
  final List<String> workingDays;
  final ValueChanged<DateTime> onChanged;
  const _NeoDateField(
      {required this.selectedDate,
      required this.workingDays,
      required this.onChanged});

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];

  bool _isSelectable(DateTime d) =>
      workingDays.contains(kWeekdayToCanonicalDay[d.weekday]);

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDate = today;
    final lastDate = today.add(const Duration(days: 365));
    final desiredInitial = today.add(const Duration(days: 1));
    // Never hand showDatePicker a disabled initialDate — that trips an
    // assertion — so find the nearest working day on/after the normal
    // default (or the current selection, if it's still valid).
    final baseline = (selectedDate != null && _isSelectable(selectedDate!))
        ? selectedDate!
        : desiredInitial;
    final initialDate =
        _nearestSelectableDate(baseline, firstDate, lastDate, _isSelectable);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      selectableDayPredicate: _isSelectable,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final d = selectedDate;
    final label = d == null
        ? 'Select a date'
        : '${d.day} ${_months[d.month - 1]} ${d.year}';
    return GestureDetector(
      onTap: () => _pick(context),
      child: _NeoCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF0EA5E9), Color(0xFF0369A1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x660EA5E9),
                      blurRadius: 6,
                      offset: Offset(0, 3)),
                  BoxShadow(
                      color: Color(0xFF0369A1),
                      blurRadius: 0,
                      offset: Offset(0, 3)),
                ],
              ),
              child: const Icon(Icons.calendar_today_rounded,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: d == null
                          ? const Color(0xFF9999BB)
                          : const Color(0xFF22224A),
                    ))),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: Color(0xFF9999BB)),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── TIME FIELD — standard Material showTimePicker, Neo-styled trigger row
// ─────────────────────────────────────────────────────────────────────────────
class _NeoTimeField extends StatelessWidget {
  final TimeOfDay? selectedTime;
  final bool hasError;
  final TimeOfDay fallbackInitialTime;
  final ValueChanged<TimeOfDay> onChanged;
  const _NeoTimeField(
      {required this.selectedTime,
      required this.hasError,
      required this.fallbackInitialTime,
      required this.onChanged});

  Future<void> _pick(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? fallbackInitialTime,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final t = selectedTime;
    final label = t == null ? 'Select a time' : t.format(context);
    final iconColors = hasError
        ? const [CustomerColors.error, Color(0xFF991B1B)]
        : const [Color(0xFF10B981), Color(0xFF065F46)];
    return GestureDetector(
      onTap: () => _pick(context),
      child: _NeoCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: iconColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: iconColors[0].withOpacity(0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 3)),
                  BoxShadow(
                      color: iconColors[1],
                      blurRadius: 0,
                      offset: const Offset(0, 3)),
                ],
              ),
              child: const Icon(Icons.access_time_rounded,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: t == null
                          ? const Color(0xFF9999BB)
                          : const Color(0xFF22224A),
                    ))),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: Color(0xFF9999BB)),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── PRIORITY SELECTOR
// ─────────────────────────────────────────────────────────────────────────────
class _NeoPrioritySelector extends StatelessWidget {
  final OrderPriority selected;
  final ValueChanged<OrderPriority> onChanged;
  const _NeoPrioritySelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(children: [
        _PriorityChip(
          label: 'Normal',
          icon: Icons.flag_outlined,
          colors: [const Color(0xFF10B981), const Color(0xFF065F46)],
          isSelected: selected == OrderPriority.normal,
          onTap: () => onChanged(OrderPriority.normal),
        ),
        const SizedBox(width: 10),
        _PriorityChip(
          label: 'Urgent',
          icon: Icons.priority_high_rounded,
          colors: [const Color(0xFFEF4444), const Color(0xFF991B1B)],
          isSelected: selected == OrderPriority.urgent,
          onTap: () => onChanged(OrderPriority.urgent),
        ),
      ]);
}

class _PriorityChip extends StatefulWidget {
  final String label;
  final IconData icon;
  final List<Color> colors;
  final bool isSelected;
  final VoidCallback onTap;
  const _PriorityChip(
      {required this.label,
      required this.icon,
      required this.colors,
      required this.isSelected,
      required this.onTap});
  @override
  State<_PriorityChip> createState() => _PriorityChipState();
}

class _PriorityChipState extends State<_PriorityChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 80));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTapDown: (_) => _ctrl.forward(),
          onTapUp: (_) {
            _ctrl.reverse();
            widget.onTap();
          },
          onTapCancel: () => _ctrl.reverse(),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, child) =>
                Transform.scale(scale: 1.0 - 0.03 * _ctrl.value, child: child),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _nBg,
                borderRadius: BorderRadius.circular(16),
                border: widget.isSelected
                    ? Border.all(color: widget.colors[0], width: 2)
                    : null,
                boxShadow: widget.isSelected
                    ? [
                        BoxShadow(
                            color: _nDark,
                            blurRadius: 2,
                            offset: const Offset(2, 2)),
                        const BoxShadow(
                            color: _nLight,
                            blurRadius: 2,
                            offset: Offset(-2, -2))
                      ]
                    : const [
                        BoxShadow(
                            color: _nDark, blurRadius: 0, offset: Offset(0, 4)),
                        BoxShadow(
                            color: _nDark,
                            blurRadius: 10,
                            offset: Offset(4, 4)),
                        BoxShadow(
                            color: _nLight,
                            blurRadius: 10,
                            offset: Offset(-4, -4))
                      ],
              ),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: widget.colors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: [
                      BoxShadow(
                          color: widget.colors[0].withOpacity(0.4),
                          blurRadius: 5,
                          offset: const Offset(0, 3)),
                      BoxShadow(
                          color: widget.colors[1],
                          blurRadius: 0,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Icon(widget.icon, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
                Text(widget.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: widget.isSelected
                          ? widget.colors[0]
                          : const Color(0xFF555577),
                    )),
              ]),
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// ── PHOTO TILE
// ─────────────────────────────────────────────────────────────────────────────
class _NeoPhotoTile extends StatefulWidget {
  final Uint8List? photoBytes;
  final bool pickingPhoto;
  final VoidCallback onPick, onRemove;
  final AppLocalizations l;
  const _NeoPhotoTile(
      {required this.photoBytes,
      required this.pickingPhoto,
      required this.onPick,
      required this.onRemove,
      required this.l});
  @override
  State<_NeoPhotoTile> createState() => _NeoPhotoTileState();
}

class _NeoPhotoTileState extends State<_NeoPhotoTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 80));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        GestureDetector(
          onTapDown: (_) => _ctrl.forward(),
          onTapUp: (_) {
            _ctrl.reverse();
            if (!widget.pickingPhoto) widget.onPick();
          },
          onTapCancel: () => _ctrl.reverse(),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, child) =>
                Transform.scale(scale: 1.0 - 0.02 * _ctrl.value, child: child),
            child: _NeoCard(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: widget.pickingPhoto
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                            SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Color(0xFF0EA5E9))),
                            SizedBox(width: 10),
                            Text('Loading...',
                                style: TextStyle(
                                    color: Color(0xFF9999BB),
                                    fontWeight: FontWeight.w600)),
                          ])
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF0EA5E9),
                                      Color(0xFF0369A1)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Color(0xFF0369A1),
                                      blurRadius: 0,
                                      offset: Offset(0, 3)),
                                  BoxShadow(
                                      color: Color(0x660EA5E9),
                                      blurRadius: 8,
                                      offset: Offset(0, 4))
                                ],
                              ),
                              child: Icon(
                                  widget.photoBytes != null
                                      ? Icons.swap_horiz_rounded
                                      : Icons.add_photo_alternate_outlined,
                                  color: Colors.white,
                                  size: 18),
                            ),
                            const SizedBox(width: 10),
                            Text(
                                widget.photoBytes != null
                                    ? 'Change Photo'
                                    : widget.l.get('attach_photo'),
                                style: const TextStyle(
                                    color: Color(0xFF22224A),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                          ]),
              ),
            ),
          ),
        ),
        if (widget.photoBytes != null) ...[
          const SizedBox(height: 10),
          Stack(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(widget.photoBytes!,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                  cacheWidth: 800,
                  gaplessPlayback: true),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: widget.onRemove,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 16),
                ),
              ),
            ),
          ]),
        ],
      ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// ── PRICE BANNER
// ─────────────────────────────────────────────────────────────────────────────
class _NeoPriceBanner extends StatelessWidget {
  final double price;
  const _NeoPriceBanner({required this.price});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF021024), Color(0xFF052659), Color(0xFF0A3D7A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
                color: Color(0xFF021024), blurRadius: 0, offset: Offset(0, 5)),
            BoxShadow(
                color: Color(0x88052659), blurRadius: 14, offset: Offset(0, 8)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: const Icon(Icons.payments_outlined,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          const Text('Total Price',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
          const Spacer(),
          Text('₪${price.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// ── SUBMIT BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _NeoSubmitButton extends StatefulWidget {
  final bool loading;
  final VoidCallback onTap;
  final AppLocalizations l;
  const _NeoSubmitButton(
      {required this.loading, required this.onTap, required this.l});
  @override
  State<_NeoSubmitButton> createState() => _NeoSubmitButtonState();
}

class _NeoSubmitButtonState extends State<_NeoSubmitButton>
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
        onTapDown: widget.loading ? null : (_) => _ctrl.forward(),
        onTapUp: widget.loading
            ? null
            : (_) {
                _ctrl.reverse();
                widget.onTap();
              },
        onTapCancel: () => _ctrl.reverse(),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.03 * _ctrl.value, child: child),
          child: Container(
            width: double.infinity,
            height: 58,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF052659), Color(0xFF0A3D7A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                    color: Color(0xFF021024),
                    blurRadius: 0,
                    offset: Offset(0, 6)),
                BoxShadow(
                    color: Color(0x88052659),
                    blurRadius: 16,
                    offset: Offset(0, 10)),
              ],
            ),
            child: Center(
              child: widget.loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(9)),
                        child: const Icon(Icons.send_rounded,
                            color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Text(widget.l.get('send_request'),
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.3)),
                    ]),
            ),
          ),
        ),
      );
}
