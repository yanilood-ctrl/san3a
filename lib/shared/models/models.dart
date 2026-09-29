// ─── User Model ───────────────────────────────────────────────────────────────
import 'dart:typed_data';

enum UserRole { customer, professional, contractor, admin }

// ─── Provider availability (Firestore: workingDays/workStartTime/workEndTime) ─
// Canonical lowercase day keys stored on users/{id}.workingDays, always in
// Sunday-first order to match the region's calendar convention.
const List<String> kCanonicalWorkingDays = [
  'sunday',
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
];

const Map<String, String> kWorkingDayLabels = {
  'sunday': 'Sunday',
  'monday': 'Monday',
  'tuesday': 'Tuesday',
  'wednesday': 'Wednesday',
  'thursday': 'Thursday',
  'friday': 'Friday',
  'saturday': 'Saturday',
};

// Maps DateTime.weekday (1=Monday..7=Sunday) to the canonical day key, so
// date validation never depends on localized weekday names.
const Map<int, String> kWeekdayToCanonicalDay = {
  DateTime.monday: 'monday',
  DateTime.tuesday: 'tuesday',
  DateTime.wednesday: 'wednesday',
  DateTime.thursday: 'thursday',
  DateTime.friday: 'friday',
  DateTime.saturday: 'saturday',
  DateTime.sunday: 'sunday',
};

/// Formats canonical day keys as a readable, comma-separated label in
/// Sunday-Saturday order, e.g. ["monday","sunday"] -> "Sunday, Monday".
String formatWorkingDaysLabel(List<String> days) => kCanonicalWorkingDays
    .where((d) => days.contains(d))
    .map((d) => kWorkingDayLabels[d]!)
    .join(', ');

class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String city;
  final String streetNumber;
  final UserRole role;
  final String? avatar;
  final String? companyName;
  final String? workArea;
  final int? experienceYears;
  final String? specialty;
  final List<String> specialties;
  final String? serviceDescription;
  final double rating;
  final int totalJobs;
  final List<String> services;
  final List<WorkerModel> team;
  final List<ServiceModel> servicesList;
  final List<String> languages;
  final List<String> warnings;
  // Structured provider availability. Canonical lowercase day keys and
  // HH:mm times — see effectiveWorkingDays/effectiveWorkStartTime/
  // effectiveWorkEndTime/effectiveWorkingHoursLabel below for the
  // backward-compatible resolved schedule every screen should read.
  final List<String> workingDays;
  final String? workStartTime;
  final String? workEndTime;
  final DateTime? suspendedUntil;
  final List<String> preferredContactHours;
  final DateTime? _joinDate;
  DateTime get joinDate => _joinDate ?? DateTime(2024, 1, 1);
  final List<String> favoriteServices;
  // Indefinite account restriction set by Admin Users → Block/Unblock.
  // Unrelated to ConversationModel.isBlocked, which blocks a single chat
  // conversation, not the whole account.
  final bool isBlocked;
  // Soft delete / account deactivation set by Admin Users → Delete/Restore.
  // The users/{id} document, Firebase Auth account, and every linked record
  // (orders, reviews, conversations, etc.) are preserved — only these two
  // fields change. Independent of isBlocked/suspendedUntil, which are
  // preserved across a delete+restore cycle.
  final bool isDeleted;
  final DateTime? deletedAt;

  const UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.city,
    required this.role,
    this.streetNumber = '',
    this.avatar,
    this.companyName,
    this.workArea,
    this.experienceYears,
    this.specialty,
    this.specialties = const [],
    this.serviceDescription,
    this.rating = 0,
    this.totalJobs = 0,
    this.services = const [],
    this.team = const [],
    this.servicesList = const [],
    this.languages = const [],
    this.warnings = const [],
    this.workingDays = const [],
    this.workStartTime,
    this.workEndTime,
    this.suspendedUntil,
    this.preferredContactHours = const [],
    DateTime? joinDate,
    this.favoriteServices = const [],
    this.isBlocked = false,
    this.isDeleted = false,
    this.deletedAt,
  }) : _joinDate = joinDate;

  /// Returns the full address combining city and street number.
  String get fullAddress {
    if (streetNumber.trim().isEmpty) return city;
    if (city.trim().isEmpty) return streetNumber;
    return '$city, Street $streetNumber';
  }

  /// True while suspendedUntil is set and still in the future. Derived on
  /// every read (no stored "isSuspended" flag) so an expired suspension
  /// resolves itself the next time this is checked — no manual admin
  /// unsuspend action or background timer/polling required.
  bool get isActivelySuspended =>
      suspendedUntil != null && suspendedUntil!.isAfter(DateTime.now());

  // ── Effective availability ────────────────────────────────────────────────
  // Resolves the provider's real schedule with full backward compatibility:
  // structured fields win when present and valid, otherwise the legacy
  // "hours: HH:mm – HH:mm" segment inside serviceDescription is parsed, and
  // finally 08:00–18:00 / all seven days. Every screen that needs a
  // provider's schedule should read these instead of re-parsing
  // serviceDescription itself.

  /// A provider with no structured workingDays is treated as working every
  /// day (pre-existing accounts had no concept of a day off).
  List<String> get effectiveWorkingDays => workingDays.isNotEmpty
      ? workingDays
      : List<String>.from(kCanonicalWorkingDays);

  List<String>? get _structuredHoursPair {
    final s = workStartTime, e = workEndTime;
    if (s == null || e == null) return null;
    final ns = _normalizeHHmm(s);
    final ne = _normalizeHHmm(e);
    return (ns != null && ne != null) ? [ns, ne] : null;
  }

  List<String> get _effectiveHoursPair =>
      _structuredHoursPair ??
      _legacyHoursPairFromDescription(serviceDescription) ??
      const ['08:00', '18:00'];

  String get effectiveWorkStartTime => _effectiveHoursPair[0];
  String get effectiveWorkEndTime => _effectiveHoursPair[1];
  String get effectiveWorkingHoursLabel =>
      '${_effectiveHoursPair[0]} – ${_effectiveHoursPair[1]}';

  /// Minute-of-day precision (0-1439) for range comparisons — start is
  /// inclusive, end is exclusive wherever this is used for validation.
  int get effectiveWorkStartMinutes =>
      _minutesFromHHmm(effectiveWorkStartTime) ?? 8 * 60;
  int get effectiveWorkEndMinutes =>
      _minutesFromHHmm(effectiveWorkEndTime) ?? 18 * 60;

  static int? _minutesFromHHmm(String? s) {
    if (s == null) return null;
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(s.trim());
    if (m == null) return null;
    final h = int.tryParse(m.group(1)!);
    final mi = int.tryParse(m.group(2)!);
    if (h == null || mi == null || h > 23 || mi > 59) return null;
    return h * 60 + mi;
  }

  static String? _normalizeHHmm(String s) {
    final mins = _minutesFromHHmm(s);
    if (mins == null) return null;
    return '${(mins ~/ 60).toString().padLeft(2, '0')}:'
        '${(mins % 60).toString().padLeft(2, '0')}';
  }

  // Extracts "hours: HH:mm – HH:mm" from the legacy pipe-separated
  // serviceDescription format used by Professional/Contractor Edit Profile
  // before structured availability existed (e.g. "bio | hours: 08:00 – 18:00
  // | response: ...").
  static List<String>? _legacyHoursPairFromDescription(String? desc) {
    if (desc == null || !desc.contains('hours:')) return null;
    for (final part in desc.split('|')) {
      final t = part.trim();
      if (!t.startsWith('hours:')) continue;
      final range = t.replaceFirst('hours:', '').trim();
      final parts = range.split(RegExp(r'[–-]')).map((s) => s.trim()).toList();
      if (parts.length != 2) continue;
      final s = _normalizeHHmm(parts[0]);
      final e = _normalizeHHmm(parts[1]);
      if (s != null && e != null) return [s, e];
    }
    return null;
  }

  static List<String> _parseWorkingDays(dynamic v) {
    if (v is! List) return const [];
    final seen = <String>{};
    final result = <String>[];
    for (final e in v) {
      if (e == null) continue;
      final s = e.toString().trim().toLowerCase();
      if (kCanonicalWorkingDays.contains(s) && seen.add(s)) result.add(s);
    }
    return result;
  }

  UserModel copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? city,
    String? streetNumber,
    String? avatar,
    String? companyName,
    String? workArea,
    int? experienceYears,
    String? specialty,
    List<String>? specialties,
    String? serviceDescription,
    double? rating,
    int? totalJobs,
    List<String>? services,
    List<WorkerModel>? team,
    List<ServiceModel>? servicesList,
    List<String>? languages,
    List<String>? warnings,
    List<String>? workingDays,
    String? workStartTime,
    String? workEndTime,
    DateTime? suspendedUntil,
    bool clearSuspension = false,
    List<String>? preferredContactHours,
    DateTime? joinDate,
    List<String>? favoriteServices,
    bool? isBlocked,
    bool? isDeleted,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) =>
      UserModel(
        id: id,
        fullName: fullName ?? this.fullName,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        city: city ?? this.city,
        role: role,
        streetNumber: streetNumber ?? this.streetNumber,
        avatar: avatar ?? this.avatar,
        companyName: companyName ?? this.companyName,
        workArea: workArea ?? this.workArea,
        experienceYears: experienceYears ?? this.experienceYears,
        specialty: specialty ?? this.specialty,
        specialties: specialties ?? this.specialties,
        serviceDescription: serviceDescription ?? this.serviceDescription,
        rating: rating ?? this.rating,
        totalJobs: totalJobs ?? this.totalJobs,
        services: services ?? this.services,
        team: team ?? this.team,
        servicesList: servicesList ?? this.servicesList,
        languages: languages ?? this.languages,
        warnings: warnings ?? this.warnings,
        workingDays: workingDays ?? this.workingDays,
        workStartTime: workStartTime ?? this.workStartTime,
        workEndTime: workEndTime ?? this.workEndTime,
        suspendedUntil:
            clearSuspension ? null : (suspendedUntil ?? this.suspendedUntil),
        preferredContactHours:
            preferredContactHours ?? this.preferredContactHours,
        joinDate: joinDate ?? _joinDate,
        favoriteServices: favoriteServices ?? this.favoriteServices,
        isBlocked: isBlocked ?? this.isBlocked,
        isDeleted: isDeleted ?? this.isDeleted,
        deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      );

  // ── Firestore serialization ───────────────────────────────────────────────

  static UserRole _roleFromString(String? s) {
    switch (s) {
      case 'professional':
        return UserRole.professional;
      case 'contractor':
        return UserRole.contractor;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.customer;
    }
  }

  static String _roleToString(UserRole r) {
    switch (r) {
      case UserRole.professional:
        return 'professional';
      case UserRole.contractor:
        return 'contractor';
      case UserRole.admin:
        return 'admin';
      case UserRole.customer:
        return 'customer';
    }
  }

  // Handles ISO-8601 strings and millisecond ints (both appear in Firestore).
  static DateTime? _parseDateTime(dynamic val) {
    if (val == null) return null;
    if (val is String) return DateTime.tryParse(val);
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    return null;
  }

  factory UserModel.fromMap(Map<String, dynamic> map, {String? id}) =>
      UserModel(
        id: id ?? map['id'] as String? ?? '',
        fullName: map['fullName'] as String? ?? '',
        email: map['email'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        city: map['city'] as String? ?? '',
        streetNumber: map['streetNumber'] as String? ?? '',
        role: _roleFromString(map['role'] as String?),
        avatar: map['avatar'] as String?,
        companyName: map['companyName'] as String?,
        workArea: map['workArea'] as String?,
        experienceYears: (map['experienceYears'] as num?)?.toInt(),
        specialty: map['specialty'] as String?,
        specialties: List<String>.from(map['specialties'] as List? ?? const []),
        serviceDescription: map['serviceDescription'] as String?,
        rating: (map['rating'] as num?)?.toDouble() ?? 0,
        totalJobs: (map['totalJobs'] as num?)?.toInt() ?? 0,
        services: List<String>.from(map['services'] as List? ?? const []),
        languages: List<String>.from(map['languages'] as List? ?? const []),
        warnings: List<String>.from(map['warnings'] as List? ?? const []),
        workingDays: _parseWorkingDays(map['workingDays']),
        workStartTime: map['workStartTime'] as String?,
        workEndTime: map['workEndTime'] as String?,
        suspendedUntil: _parseDateTime(map['suspendedUntil']),
        preferredContactHours: List<String>.from(
            map['preferredContactHours'] as List? ?? const []),
        joinDate: _parseDateTime(map['joinDate']),
        favoriteServices:
            List<String>.from(map['favoriteServices'] as List? ?? const []),
        servicesList: (map['servicesList'] as List? ?? [])
            .map((e) =>
                ServiceModel.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        isBlocked: map['isBlocked'] as bool? ?? false,
        // Old users without these fields parse as isDeleted == false,
        // deletedAt == null — fully backward compatible.
        isDeleted: map['isDeleted'] as bool? ?? false,
        deletedAt: _parseDateTime(map['deletedAt']),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'city': city,
        'streetNumber': streetNumber,
        'role': _roleToString(role),
        if (avatar != null) 'avatar': avatar,
        if (companyName != null) 'companyName': companyName,
        if (workArea != null) 'workArea': workArea,
        if (experienceYears != null) 'experienceYears': experienceYears,
        if (specialty != null) 'specialty': specialty,
        'specialties': specialties,
        if (serviceDescription != null)
          'serviceDescription': serviceDescription,
        'rating': rating,
        'totalJobs': totalJobs,
        'services': services,
        'languages': languages,
        'warnings': warnings,
        'workingDays': workingDays,
        if (workStartTime != null) 'workStartTime': workStartTime,
        if (workEndTime != null) 'workEndTime': workEndTime,
        if (suspendedUntil != null)
          'suspendedUntil': suspendedUntil!.toIso8601String(),
        'preferredContactHours': preferredContactHours,
        'joinDate': joinDate.toIso8601String(),
        'favoriteServices': favoriteServices,
        'servicesList': servicesList.map((s) => s.toMap()).toList(),
        'isBlocked': isBlocked,
        'isDeleted': isDeleted,
        if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
      };
}

// ─── Service Model (for providers) ───────────────────────────────────────────
class ServiceModel {
  final String id;
  final String name;
  final String description;
  final double price;
  // Real Firestore `categories` document id this service belongs to.
  // Optional/backward-compatible — services created before this field
  // existed have no reliable category link and simply parse as null; never
  // guessed from name/specialty. See San3a AI Budget Matching Phase 1.
  final String? categoryId;

  const ServiceModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.categoryId,
  });

  Map<String, dynamic> toMap() {
    final trimmedCategoryId = categoryId?.trim();
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      if (trimmedCategoryId != null && trimmedCategoryId.isNotEmpty)
        'categoryId': trimmedCategoryId,
    };
  }

  factory ServiceModel.fromMap(Map<String, dynamic> map) {
    final trimmedCategoryId = (map['categoryId'] as String?)?.trim();
    return ServiceModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      categoryId: (trimmedCategoryId == null || trimmedCategoryId.isEmpty)
          ? null
          : trimmedCategoryId,
    );
  }
}

// ─── Worker Model ─────────────────────────────────────────────────────────────
enum WorkerStatus { available, busy, offline }

class WorkerModel {
  final String id;
  final String name;
  // Legacy single value — kept in sync as the first entry of [specialties]
  // for compatibility with code that has not been migrated to the list.
  final String specialty;
  // Canonical category nameKeys, resolved against the owning contractor's
  // own valid (live, active) specialty categories. May contain more than
  // one value — see contractor_suppliers_screen.dart for how these are
  // populated/edited.
  final List<String> specialties;
  final String? phone;
  final String? email;
  final String? city;
  // Structured work-area value (region key or free text), mirroring
  // UserModel.workArea. Always written alongside [city] for backward
  // compatibility with any existing reads of the `city` field.
  final String? workArea;
  final List<String> languages;
  final String? imageUrl;
  final double rating;
  final int totalJobs;
  final int currentJobs;
  final int yearsExperience;
  final List<String> skills;
  // Legacy free-text working-hours string — kept in sync with
  // [workStartTime]/[workEndTime] as a "HH:mm – HH:mm" label so old
  // display code paths that only know about [workHours] keep working.
  final String? workHours;
  final String? workStartTime;
  final String? workEndTime;
  final WorkerStatus status;
  final String? description;
  // Owning contractor's user id, as stored in the contractor_workers
  // document. Only populated when read via fromFirestore (used for
  // ownership checks) — not settable through copyWith.
  final String? contractorId;

  const WorkerModel({
    required this.id,
    required this.name,
    required this.specialty,
    this.specialties = const [],
    this.phone,
    this.email,
    this.city,
    this.workArea,
    this.languages = const [],
    this.imageUrl,
    this.rating = 0,
    this.totalJobs = 0,
    this.currentJobs = 0,
    this.yearsExperience = 0,
    this.skills = const [],
    this.workHours,
    this.workStartTime,
    this.workEndTime,
    this.status = WorkerStatus.available,
    this.description,
    this.contractorId,
  });

  /// "HH:mm – HH:mm" if structured hours are set, otherwise the legacy
  /// free-text [workHours] string (may be null/empty if neither is set).
  String? get effectiveWorkingHoursLabel {
    if (workStartTime != null &&
        workStartTime!.isNotEmpty &&
        workEndTime != null &&
        workEndTime!.isNotEmpty) {
      return '$workStartTime – $workEndTime';
    }
    return workHours;
  }

  WorkerModel copyWith({
    String? name,
    String? specialty,
    List<String>? specialties,
    String? phone,
    String? email,
    String? city,
    String? workArea,
    List<String>? languages,
    String? imageUrl,
    double? rating,
    int? totalJobs,
    int? currentJobs,
    int? yearsExperience,
    List<String>? skills,
    String? workHours,
    String? workStartTime,
    String? workEndTime,
    WorkerStatus? status,
    String? description,
  }) =>
      WorkerModel(
        id: id,
        name: name ?? this.name,
        specialty: specialty ?? this.specialty,
        specialties: specialties ?? this.specialties,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        city: city ?? this.city,
        workArea: workArea ?? this.workArea,
        languages: languages ?? this.languages,
        imageUrl: imageUrl ?? this.imageUrl,
        rating: rating ?? this.rating,
        totalJobs: totalJobs ?? this.totalJobs,
        currentJobs: currentJobs ?? this.currentJobs,
        yearsExperience: yearsExperience ?? this.yearsExperience,
        skills: skills ?? this.skills,
        workHours: workHours ?? this.workHours,
        workStartTime: workStartTime ?? this.workStartTime,
        workEndTime: workEndTime ?? this.workEndTime,
        status: status ?? this.status,
        description: description ?? this.description,
      );

  // ── Firestore serialization ───────────────────────────────────────────────

  static WorkerStatus _statusFromString(String? s) {
    switch (s) {
      case 'busy':
        return WorkerStatus.busy;
      case 'offline':
        return WorkerStatus.offline;
      default:
        return WorkerStatus.available;
    }
  }

  static String _statusToString(WorkerStatus s) {
    switch (s) {
      case WorkerStatus.available:
        return 'available';
      case WorkerStatus.busy:
        return 'busy';
      case WorkerStatus.offline:
        return 'offline';
    }
  }

  factory WorkerModel.fromFirestore(Map<String, dynamic> data, {String? id}) {
    String? ne(String? v) => (v == null || v.isEmpty) ? null : v;
    final legacySpecialty = data['specialty'] as String? ?? '';
    final storedSpecialties =
        List<String>.from(data['specialties'] as List? ?? const []);
    // Backward compatibility: old worker docs only ever wrote the single
    // `specialty` string — fold it in as the sole entry so existing
    // workers still load with their specialty selected once it's matched
    // against the contractor's current valid categories by the caller.
    final specialties = storedSpecialties.isNotEmpty
        ? storedSpecialties
        : (legacySpecialty.isNotEmpty ? [legacySpecialty] : const <String>[]);
    return WorkerModel(
      id: id ?? data['id'] as String? ?? '',
      name: data['fullName'] as String? ?? '',
      specialty: legacySpecialty,
      specialties: specialties,
      phone: ne(data['phone'] as String?),
      email: ne(data['email'] as String?),
      city: ne(data['city'] as String?),
      workArea: ne(data['workArea'] as String?) ?? ne(data['city'] as String?),
      languages: List<String>.from(data['languages'] as List? ?? const []),
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      totalJobs: (data['completedJobs'] as num?)?.toInt() ?? 0,
      currentJobs: 0,
      yearsExperience: (data['experienceYears'] as num?)?.toInt() ?? 0,
      workHours: ne(data['workHours'] as String?),
      workStartTime: ne(data['workStartTime'] as String?),
      workEndTime: ne(data['workEndTime'] as String?),
      status: _statusFromString(data['status'] as String?),
      skills: List<String>.from(data['skills'] as List? ?? const []),
      description: ne(data['description'] as String?),
      contractorId: ne(data['contractorId'] as String?),
    );
  }

  Map<String, dynamic> toFirestoreMap({
    required String contractorId,
    required String contractorName,
  }) =>
      {
        'id': id,
        'contractorId': contractorId,
        'contractorName': contractorName,
        'fullName': name,
        'specialty': specialty,
        'specialties': specialties,
        'phone': phone ?? '',
        'email': email ?? '',
        'city': city ?? '',
        'workArea': workArea ?? city ?? '',
        'languages': languages,
        'experienceYears': yearsExperience,
        'workHours': workHours ?? '',
        if (workStartTime != null) 'workStartTime': workStartTime,
        if (workEndTime != null) 'workEndTime': workEndTime,
        'status': _statusToString(status),
        'rating': rating,
        'completedJobs': totalJobs,
        'skills': skills,
        if (description != null && description!.isNotEmpty)
          'description': description,
      };
}

// ─── Assigned Worker Snapshot ─────────────────────────────────────────────────
// Minimal, typed snapshot of a worker captured at assignment time, stored in
// OrderModel.assignedWorkers. Deliberately small (id/name/specialties only —
// no live status/phone/etc.) so it never goes stale in a way that matters:
// matching and job-counters only ever need the id, and the specialties are
// just for display. Additive/backward-compatible — legacy orders simply
// parse this as an empty list and keep using assignedWorkerId/Name.
class AssignedWorkerSnapshot {
  final String id;
  final String name;
  final List<String> specialties;

  const AssignedWorkerSnapshot({
    required this.id,
    required this.name,
    this.specialties = const [],
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'specialties': specialties,
      };

  /// Returns null for a malformed entry (missing/blank id) instead of
  /// throwing, so one bad entry in the array never crashes order parsing.
  static AssignedWorkerSnapshot? fromMap(Map<String, dynamic> map) {
    final id = map['id'];
    final idStr = id is String ? id.trim() : (id?.toString().trim() ?? '');
    if (idStr.isEmpty) return null;
    final name = map['name'];
    final nameStr = name is String ? name : (name?.toString() ?? '');
    final specialties = map['specialties'];
    return AssignedWorkerSnapshot(
      id: idStr,
      name: nameStr,
      specialties: specialties is List
          ? specialties.map((e) => e.toString()).toList()
          : const [],
    );
  }
}

// ─── Order Model ──────────────────────────────────────────────────────────────
enum OrderStatus { pending, inProgress, completed, cancelled }

enum OrderPriority { normal, urgent }

class OrderModel {
  final String id;
  final String customerId;
  final String customerName;
  final String providerId;
  final String providerName;
  final String title;
  final String description;
  final String area;
  final String? serviceType;
  final String? selectedServiceId;
  final String? selectedServiceName;
  final double? selectedServicePrice;
  // Full multi-service snapshot (San3a multi-service selection). Additive and
  // backward-compatible: legacy single-service orders simply parse this as
  // an empty list, and the legacy selectedServiceId/Name/Price fields above
  // are still populated for existing single-service consumers.
  final List<ServiceModel> selectedServices;
  final DateTime serviceDate;
  final OrderStatus status;
  final OrderPriority priority;
  final String? photoPath;
  final Uint8List? photoBytes; // local UI only — excluded from toMap()
  final DateTime createdAt;
  final String? rejectReason;
  final String? assignedWorkerId;
  final String? assignedWorkerName;
  final String? assignedWorkerPhone;
  final String? assignedWorkerSpecialty;
  final String? assignedWorkerEmail;
  // Backward-compatible multi-worker assignment. Additive: legacy orders
  // parse this as an empty list and keep working off assignedWorkerId/Name
  // above, which always mirror the first entry here once it's non-empty.
  final List<AssignedWorkerSnapshot> assignedWorkers;
  // Firestore-only fields
  final String? providerRole;
  final String? categoryId;
  final String? categoryNameKey;
  final DateTime? updatedAt;
  final String? customerPhone;
  final String? providerPhone;
  final String? cancelReason;
  final String? cancelledBy;
  final DateTime? cancelledAt;
  final String? acceptedBy;
  final DateTime? acceptedAt;
  final String? completedBy;
  final DateTime? completedAt;
  final String? editedBy;
  final DateTime? editedAt;
  // Firebase Storage download URLs for images attached at order creation.
  final List<String> imageUrls;

  const OrderModel({
    required this.id,
    required this.customerId,
    this.customerName = '',
    required this.providerId,
    required this.providerName,
    required this.title,
    required this.description,
    required this.area,
    this.serviceType,
    this.selectedServiceId,
    this.selectedServiceName,
    this.selectedServicePrice,
    this.selectedServices = const [],
    required this.serviceDate,
    required this.status,
    this.priority = OrderPriority.normal,
    this.photoPath,
    this.photoBytes,
    required this.createdAt,
    this.rejectReason,
    this.assignedWorkerId,
    this.assignedWorkerName,
    this.assignedWorkerPhone,
    this.assignedWorkerSpecialty,
    this.assignedWorkerEmail,
    this.assignedWorkers = const [],
    this.providerRole,
    this.categoryId,
    this.categoryNameKey,
    this.updatedAt,
    this.customerPhone,
    this.providerPhone,
    this.cancelReason,
    this.cancelledBy,
    this.cancelledAt,
    this.acceptedBy,
    this.acceptedAt,
    this.completedBy,
    this.completedAt,
    this.editedBy,
    this.editedAt,
    this.imageUrls = const [],
  });

  OrderModel copyWith({
    OrderStatus? status,
    String? title,
    String? description,
    String? area,
    DateTime? serviceDate,
    String? rejectReason,
    OrderPriority? priority,
    String? assignedWorkerId,
    String? assignedWorkerName,
    String? assignedWorkerPhone,
    String? assignedWorkerSpecialty,
    String? assignedWorkerEmail,
    List<AssignedWorkerSnapshot>? assignedWorkers,
    String? selectedServiceId,
    String? selectedServiceName,
    double? selectedServicePrice,
    List<ServiceModel>? selectedServices,
    String? photoPath,
    Uint8List? photoBytes,
    String? providerId,
    String? providerName,
    bool clearPhoto = false,
    String? providerRole,
    String? categoryId,
    String? categoryNameKey,
    DateTime? updatedAt,
    String? customerPhone,
    String? providerPhone,
    String? cancelReason,
    String? cancelledBy,
    DateTime? cancelledAt,
    String? acceptedBy,
    DateTime? acceptedAt,
    String? completedBy,
    DateTime? completedAt,
    String? editedBy,
    DateTime? editedAt,
    List<String>? imageUrls,
  }) =>
      OrderModel(
        id: id,
        customerId: customerId,
        customerName: customerName,
        providerId: providerId ?? this.providerId,
        providerName: providerName ?? this.providerName,
        title: title ?? this.title,
        description: description ?? this.description,
        area: area ?? this.area,
        serviceType: serviceType,
        selectedServiceId: selectedServiceId ?? this.selectedServiceId,
        selectedServiceName: selectedServiceName ?? this.selectedServiceName,
        selectedServicePrice: selectedServicePrice ?? this.selectedServicePrice,
        selectedServices: selectedServices ?? this.selectedServices,
        serviceDate: serviceDate ?? this.serviceDate,
        status: status ?? this.status,
        priority: priority ?? this.priority,
        photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
        photoBytes: clearPhoto ? null : (photoBytes ?? this.photoBytes),
        createdAt: createdAt,
        rejectReason: rejectReason ?? this.rejectReason,
        assignedWorkerId: assignedWorkerId ?? this.assignedWorkerId,
        assignedWorkerName: assignedWorkerName ?? this.assignedWorkerName,
        assignedWorkerPhone: assignedWorkerPhone ?? this.assignedWorkerPhone,
        assignedWorkerSpecialty:
            assignedWorkerSpecialty ?? this.assignedWorkerSpecialty,
        assignedWorkerEmail: assignedWorkerEmail ?? this.assignedWorkerEmail,
        assignedWorkers: assignedWorkers ?? this.assignedWorkers,
        providerRole: providerRole ?? this.providerRole,
        categoryId: categoryId ?? this.categoryId,
        categoryNameKey: categoryNameKey ?? this.categoryNameKey,
        updatedAt: updatedAt ?? this.updatedAt,
        customerPhone: customerPhone ?? this.customerPhone,
        providerPhone: providerPhone ?? this.providerPhone,
        cancelReason: cancelReason ?? this.cancelReason,
        cancelledBy: cancelledBy ?? this.cancelledBy,
        cancelledAt: cancelledAt ?? this.cancelledAt,
        acceptedBy: acceptedBy ?? this.acceptedBy,
        acceptedAt: acceptedAt ?? this.acceptedAt,
        completedBy: completedBy ?? this.completedBy,
        completedAt: completedAt ?? this.completedAt,
        editedBy: editedBy ?? this.editedBy,
        editedAt: editedAt ?? this.editedAt,
        imageUrls: imageUrls ?? this.imageUrls,
      );

  // ── Firestore serialization ───────────────────────────────────────────────

  static OrderStatus _statusFromString(String? s) {
    switch (s) {
      case 'inProgress':
        return OrderStatus.inProgress;
      case 'completed':
        return OrderStatus.completed;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }

  static String _statusToString(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
        return 'pending';
      case OrderStatus.inProgress:
        return 'inProgress';
      case OrderStatus.completed:
        return 'completed';
      case OrderStatus.cancelled:
        return 'cancelled';
    }
  }

  static OrderPriority _priorityFromString(String? s) =>
      s == 'urgent' ? OrderPriority.urgent : OrderPriority.normal;

  static String _priorityToString(OrderPriority p) =>
      p == OrderPriority.urgent ? 'urgent' : 'normal';

  static DateTime? _parseTs(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is double) return DateTime.fromMillisecondsSinceEpoch(v.round());
    try {
      return (v as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }

  static double? _parsePrice(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  // Coerces any Firestore value to a nullable String instead of using a hard
  // `as String?` cast, which throws if a document ever stores the wrong type
  // (e.g. a number) for a field — that single bad field must not crash parsing.
  static String? _asString(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    return v.toString();
  }

  // Parses the `selectedServices` list defensively: a missing field yields an
  // empty list (old orders keep parsing normally), and any entry that isn't a
  // map or fails to parse is skipped rather than crashing the whole order.
  static List<ServiceModel> _parseSelectedServices(dynamic v) {
    if (v is! List) return const [];
    final result = <ServiceModel>[];
    for (final entry in v) {
      if (entry is Map) {
        try {
          result.add(ServiceModel.fromMap(Map<String, dynamic>.from(entry)));
        } catch (_) {
          // Skip malformed entry.
        }
      }
    }
    return result;
  }

  // Parses `assignedWorkers` defensively: missing/non-list => empty list,
  // and any entry that isn't a map or fails to parse (e.g. blank id) is
  // skipped rather than crashing the whole order — same rule already used
  // for `selectedServices` above.
  static List<AssignedWorkerSnapshot> _parseAssignedWorkers(dynamic v) {
    if (v is! List) return const [];
    final result = <AssignedWorkerSnapshot>[];
    for (final entry in v) {
      if (entry is Map) {
        final snapshot =
            AssignedWorkerSnapshot.fromMap(Map<String, dynamic>.from(entry));
        if (snapshot != null) result.add(snapshot);
      }
    }
    return result;
  }

  factory OrderModel.fromMap(Map<String, dynamic> map, {String? id}) {
    // Fall back to epoch(0) (not DateTime.now()) so malformed/missing
    // createdAt sorts to the bottom of a descending list instead of the top.
    final createdAt =
        _parseTs(map['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
    final selectedServiceName = _asString(map['selectedServiceName']);
    final rawTitle = _asString(map['title']);
    final title = (rawTitle != null && rawTitle.isNotEmpty)
        ? rawTitle
        : (selectedServiceName != null && selectedServiceName.isNotEmpty
            ? selectedServiceName
            : 'Untitled Order');
    return OrderModel(
      id: id ?? _asString(map['id']) ?? '',
      customerId: _asString(map['customerId']) ?? '',
      customerName: _asString(map['customerName']) ?? '',
      providerId: _asString(map['providerId']) ?? '',
      providerName: _asString(map['providerName']) ?? '',
      title: title,
      description: _asString(map['description']) ?? '',
      area: _asString(map['area']) ?? '',
      serviceType: _asString(map['serviceType']),
      selectedServiceId: _asString(map['selectedServiceId']),
      selectedServiceName: selectedServiceName,
      selectedServicePrice: _parsePrice(map['selectedServicePrice']),
      selectedServices: _parseSelectedServices(map['selectedServices']),
      serviceDate: _parseTs(map['serviceDate']) ?? DateTime.now(),
      status: _statusFromString(_asString(map['status'])),
      priority: _priorityFromString(_asString(map['priority'])),
      photoPath: _asString(map['photoPath']),
      createdAt: createdAt,
      rejectReason: _asString(map['rejectReason']),
      assignedWorkerId: _asString(map['assignedWorkerId']),
      assignedWorkerName: _asString(map['assignedWorkerName']),
      assignedWorkerPhone: _asString(map['assignedWorkerPhone']),
      assignedWorkerSpecialty: _asString(map['assignedWorkerSpecialty']),
      assignedWorkerEmail: _asString(map['assignedWorkerEmail']),
      assignedWorkers: _parseAssignedWorkers(map['assignedWorkers']),
      providerRole: _asString(map['providerRole']),
      categoryId: _asString(map['categoryId']),
      categoryNameKey: _asString(map['categoryNameKey']),
      updatedAt: _parseTs(map['updatedAt']) ?? createdAt,
      customerPhone: _asString(map['customerPhone']),
      providerPhone: _asString(map['providerPhone']),
      cancelReason: _asString(map['cancelReason']),
      cancelledBy: _asString(map['cancelledBy']),
      cancelledAt: _parseTs(map['cancelledAt']),
      acceptedBy: _asString(map['acceptedBy']),
      acceptedAt: _parseTs(map['acceptedAt']),
      completedBy: _asString(map['completedBy']),
      completedAt: _parseTs(map['completedAt']),
      editedBy: _asString(map['editedBy']),
      editedAt: _parseTs(map['editedAt']),
      imageUrls:
          (map['imageUrls'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'customerId': customerId,
        'customerName': customerName,
        'providerId': providerId,
        'providerName': providerName,
        'title': title,
        'description': description,
        'area': area,
        if (serviceType != null) 'serviceType': serviceType,
        if (selectedServiceId != null) 'selectedServiceId': selectedServiceId,
        if (selectedServiceName != null)
          'selectedServiceName': selectedServiceName,
        if (selectedServicePrice != null)
          'selectedServicePrice': selectedServicePrice,
        if (selectedServices.isNotEmpty)
          'selectedServices': selectedServices.map((s) => s.toMap()).toList(),
        'serviceDate': serviceDate.toIso8601String(),
        'status': _statusToString(status),
        'priority': _priorityToString(priority),
        if (photoPath != null) 'photoPath': photoPath,
        // photoBytes intentionally excluded
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': (updatedAt ?? createdAt).toIso8601String(),
        if (rejectReason != null) 'rejectReason': rejectReason,
        if (assignedWorkerId != null) 'assignedWorkerId': assignedWorkerId,
        if (assignedWorkerName != null)
          'assignedWorkerName': assignedWorkerName,
        if (assignedWorkerPhone != null)
          'assignedWorkerPhone': assignedWorkerPhone,
        if (assignedWorkerSpecialty != null)
          'assignedWorkerSpecialty': assignedWorkerSpecialty,
        if (assignedWorkerEmail != null)
          'assignedWorkerEmail': assignedWorkerEmail,
        if (assignedWorkers.isNotEmpty)
          'assignedWorkers': assignedWorkers.map((w) => w.toMap()).toList(),
        if (providerRole != null) 'providerRole': providerRole,
        if (categoryId != null) 'categoryId': categoryId,
        if (categoryNameKey != null) 'categoryNameKey': categoryNameKey,
        if (customerPhone != null) 'customerPhone': customerPhone,
        if (providerPhone != null) 'providerPhone': providerPhone,
        if (cancelReason != null) 'cancelReason': cancelReason,
        if (cancelledBy != null) 'cancelledBy': cancelledBy,
        if (cancelledAt != null) 'cancelledAt': cancelledAt!.toIso8601String(),
        if (acceptedBy != null) 'acceptedBy': acceptedBy,
        if (acceptedAt != null) 'acceptedAt': acceptedAt!.toIso8601String(),
        if (completedBy != null) 'completedBy': completedBy,
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
        if (editedBy != null) 'editedBy': editedBy,
        if (editedAt != null) 'editedAt': editedAt!.toIso8601String(),
        if (imageUrls.isNotEmpty) 'imageUrls': imageUrls,
      };
}

// ─── Message / Conversation ───────────────────────────────────────────────────
// ─── Message Type ─────────────────────────────────────────────────────────────
enum MessageType { text, image, voice, adminWarning }

class MessageModel {
  final String id;
  final String conversationId; // Firestore-only — '' for legacy local messages
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime sentAt;
  final bool isRead;
  final bool isDeleted;
  final bool isEdited;
  final MessageType type;
  final String? mediaPath; // local file path for image/voice
  final int? voiceDurationSec; // voice message duration in seconds
  final Uint8List? mediaBytes; // raw image bytes for Web-safe display
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final String? deletedBy;
  // ── Phase 6E: Firebase Storage image messages ─────────────────────────────
  final String? imageUrl; // Firebase Storage download URL
  final String?
      mediaUrl; // alias of imageUrl/voiceUrl, kept for model compatibility
  final String?
      storagePath; // Storage object path (chat_images|chat_voice/{conversationId}/{messageId}_{fileName})
  final String? fileName;
  // ── Phase 6F: Firebase Storage voice messages ─────────────────────────────
  final String? voiceUrl; // Firebase Storage download URL for voice messages
  final String? audioUrl; // alias of voiceUrl, kept for model compatibility
  // ── Admin moderation: warning messages ────────────────────────────────────
  // Which real participant UID(s) may see this MessageType.adminWarning
  // message. Empty for every other message type (never written to Firestore
  // for them). Not used to restrict visibility of normal messages.
  final List<String> targetUserIds;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.sentAt,
    this.isRead = false,
    this.isDeleted = false,
    this.isEdited = false,
    this.type = MessageType.text,
    this.mediaPath,
    this.voiceDurationSec,
    this.mediaBytes,
    this.conversationId = '',
    this.editedAt,
    this.deletedAt,
    this.deletedBy,
    this.imageUrl,
    this.mediaUrl,
    this.storagePath,
    this.fileName,
    this.voiceUrl,
    this.audioUrl,
    this.targetUserIds = const [],
  });

  MessageModel copyWith({
    String? text,
    bool? isDeleted,
    bool? isEdited,
    bool? isRead,
    String? mediaPath,
    int? voiceDurationSec,
    MessageType? type,
    Uint8List? mediaBytes,
    DateTime? editedAt,
    DateTime? deletedAt,
    String? deletedBy,
    String? imageUrl,
    String? mediaUrl,
    String? storagePath,
    String? fileName,
    String? voiceUrl,
    String? audioUrl,
    List<String>? targetUserIds,
  }) =>
      MessageModel(
        id: id,
        senderId: senderId,
        receiverId: receiverId,
        text: text ?? this.text,
        sentAt: sentAt,
        isRead: isRead ?? this.isRead,
        isDeleted: isDeleted ?? this.isDeleted,
        isEdited: isEdited ?? this.isEdited,
        type: type ?? this.type,
        mediaPath: mediaPath ?? this.mediaPath,
        voiceDurationSec: voiceDurationSec ?? this.voiceDurationSec,
        mediaBytes: mediaBytes ?? this.mediaBytes,
        conversationId: conversationId,
        editedAt: editedAt ?? this.editedAt,
        deletedAt: deletedAt ?? this.deletedAt,
        deletedBy: deletedBy ?? this.deletedBy,
        imageUrl: imageUrl ?? this.imageUrl,
        mediaUrl: mediaUrl ?? this.mediaUrl,
        storagePath: storagePath ?? this.storagePath,
        fileName: fileName ?? this.fileName,
        voiceUrl: voiceUrl ?? this.voiceUrl,
        audioUrl: audioUrl ?? this.audioUrl,
        targetUserIds: targetUserIds ?? this.targetUserIds,
      );

  // ── Firestore serialization ───────────────────────────────────────────────

  static MessageType _typeFromString(String? s) {
    switch (s) {
      case 'image':
        return MessageType.image;
      case 'voice':
        return MessageType.voice;
      case 'adminWarning':
        return MessageType.adminWarning;
      default:
        return MessageType.text;
    }
  }

  static String _typeToString(MessageType t) {
    switch (t) {
      case MessageType.image:
        return 'image';
      case MessageType.voice:
        return 'voice';
      case MessageType.adminWarning:
        return 'adminWarning';
      case MessageType.text:
        return 'text';
    }
  }

  // Handles Firestore Timestamp (duck-typed via toDate()), DateTime, ISO
  // strings, and millisecond int/double — mirrors OrderModel._parseTs.
  static DateTime? _parseTs(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is double) return DateTime.fromMillisecondsSinceEpoch(v.round());
    try {
      return (v as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }

  // Coerces any Firestore value to a nullable String instead of using a hard
  // `as String?` cast, which throws (and would drop the whole message via the
  // provider's per-doc try/catch) if a document ever stores the wrong type
  // for a field — mirrors OrderModel._asString.
  static String? _asString(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    return v.toString();
  }

  // Same reasoning as _asString but for bool fields — accepts bool, and
  // tolerantly coerces num (0/1) or "true"/"false" strings instead of
  // throwing on an unexpected type.
  static bool _asBool(dynamic v, {bool fallback = false}) {
    if (v == null) return fallback;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v.toLowerCase() == 'true';
    return fallback;
  }

  // Coerces any Firestore value to a nullable int instead of a hard
  // `as num?` cast, which throws if the field is ever stored as something
  // else (e.g. a String) — same reasoning as _asString/_asBool.
  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  factory MessageModel.fromMap(Map<String, dynamic> map, {String? id}) =>
      MessageModel(
        id: id ?? _asString(map['id']) ?? '',
        conversationId: _asString(map['conversationId']) ?? '',
        senderId: _asString(map['senderId']) ?? '',
        receiverId: _asString(map['receiverId']) ?? '',
        text: _asString(map['text']) ?? '',
        sentAt:
            _parseTs(map['sentAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        isRead: _asBool(map['isRead']),
        isDeleted: _asBool(map['isDeleted']),
        isEdited: _asBool(map['isEdited']),
        type: _typeFromString(_asString(map['type'])),
        mediaPath: _asString(map['mediaPath']),
        voiceDurationSec: _asInt(map['voiceDurationSec']) ??
            _asInt(map['voice_duration_sec']),
        editedAt: _parseTs(map['editedAt']),
        deletedAt: _parseTs(map['deletedAt']),
        deletedBy: _asString(map['deletedBy']),
        // Legacy snake_case keys (image_url/media_url/storage_path/file_name/
        // voice_url/audio_url/voice_duration_sec) are checked as a fallback only
        // — current writes use camelCase.
        imageUrl: _asString(map['imageUrl']) ?? _asString(map['image_url']),
        mediaUrl: _asString(map['mediaUrl']) ?? _asString(map['media_url']),
        storagePath:
            _asString(map['storagePath']) ?? _asString(map['storage_path']),
        fileName: _asString(map['fileName']) ?? _asString(map['file_name']),
        voiceUrl: _asString(map['voiceUrl']) ?? _asString(map['voice_url']),
        audioUrl: _asString(map['audioUrl']) ?? _asString(map['audio_url']),
        // Tolerant of missing/malformed values: anything that isn't a List
        // (including null, for every pre-existing document) resolves to the
        // empty default rather than throwing.
        targetUserIds: (map['targetUserIds'] is List)
            ? (map['targetUserIds'] as List).map((e) => e.toString()).toList()
            : const [],
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'conversationId': conversationId,
        'senderId': senderId,
        'receiverId': receiverId,
        'text': text,
        'type': _typeToString(type),
        'sentAt': sentAt.toIso8601String(),
        'isRead': isRead,
        'isEdited': isEdited,
        'isDeleted': isDeleted,
        if (mediaPath != null) 'mediaPath': mediaPath,
        if (voiceDurationSec != null) 'voiceDurationSec': voiceDurationSec,
        if (editedAt != null) 'editedAt': editedAt!.toIso8601String(),
        if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
        if (deletedBy != null) 'deletedBy': deletedBy,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (mediaUrl != null) 'mediaUrl': mediaUrl,
        if (storagePath != null) 'storagePath': storagePath,
        if (fileName != null) 'fileName': fileName,
        if (voiceUrl != null) 'voiceUrl': voiceUrl,
        if (audioUrl != null) 'audioUrl': audioUrl,
        if (targetUserIds.isNotEmpty) 'targetUserIds': targetUserIds,
        // mediaBytes intentionally excluded — not Firestore-serializable
      };
}

class ConversationModel {
  // ── Legacy local (in-memory) fields ───────────────────────────────────────
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;
  final int unreadCount;
  final bool isOnline;
  final List<MessageModel> messages;

  // ── Shared fields ──────────────────────────────────────────────────────────
  final String lastMessage;
  final DateTime lastMessageTime;
  final bool isBlocked;

  // ── Firestore-only fields ─────────────────────────────────────────────────
  final String id;
  final List<String> participantIds;
  final Map<String, String> participantNames;
  final Map<String, String> participantRoles;
  final String? lastMessageSenderId;
  final Map<String, int>
      unreadCounts; // Firestore key: 'unreadCount' (per-user map)
  final String? blockedBy;
  final DateTime? blockedAt;
  final String? unblockedBy;
  final DateTime? unblockedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ConversationModel({
    this.otherUserId = '',
    this.otherUserName = '',
    this.otherUserAvatar,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.isOnline = false,
    this.messages = const [],
    this.isBlocked = false,
    this.id = '',
    this.participantIds = const [],
    this.participantNames = const {},
    this.participantRoles = const {},
    this.lastMessageSenderId,
    this.unreadCounts = const {},
    this.blockedBy,
    this.blockedAt,
    this.unblockedBy,
    this.unblockedAt,
    this.createdAt,
    this.updatedAt,
  });

  ConversationModel copyWith({
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    bool? isOnline,
    List<MessageModel>? messages,
    bool? isBlocked,
    String? blockedBy,
    DateTime? blockedAt,
    String? unblockedBy,
    DateTime? unblockedAt,
  }) =>
      ConversationModel(
        otherUserId: otherUserId,
        otherUserName: otherUserName,
        otherUserAvatar: otherUserAvatar,
        lastMessage: lastMessage ?? this.lastMessage,
        lastMessageTime: lastMessageTime ?? this.lastMessageTime,
        unreadCount: unreadCount ?? this.unreadCount,
        isOnline: isOnline ?? this.isOnline,
        messages: messages ?? this.messages,
        isBlocked: isBlocked ?? this.isBlocked,
        id: id,
        participantIds: participantIds,
        participantNames: participantNames,
        participantRoles: participantRoles,
        lastMessageSenderId: lastMessageSenderId,
        unreadCounts: unreadCounts,
        blockedBy: blockedBy ?? this.blockedBy,
        blockedAt: blockedAt ?? this.blockedAt,
        unblockedBy: unblockedBy ?? this.unblockedBy,
        unblockedAt: unblockedAt ?? this.unblockedAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  // ── Firestore-conversation helpers ────────────────────────────────────────
  // Derive "the other participant" relative to the current user — Firestore
  // conversations are keyed by participantIds/participantNames rather than a
  // single otherUserId (which only exists on legacy local conversations).

  String otherParticipantId(String currentUserId) => participantIds
      .firstWhere((id) => id != currentUserId, orElse: () => otherUserId);

  String otherParticipantName(String currentUserId) {
    final id = otherParticipantId(currentUserId);
    return participantNames[id] ?? otherUserName;
  }

  String? otherParticipantRole(String currentUserId) =>
      participantRoles[otherParticipantId(currentUserId)];

  int unreadCountFor(String userId) => unreadCounts[userId] ?? 0;

  // ── Firestore serialization ───────────────────────────────────────────────

  static DateTime? _parseTs(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is double) return DateTime.fromMillisecondsSinceEpoch(v.round());
    try {
      return (v as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }

  factory ConversationModel.fromMap(Map<String, dynamic> map, {String? id}) {
    final unreadCounts = <String, int>{};
    final rawUnread = map['unreadCount'];
    if (rawUnread is Map) {
      rawUnread.forEach((k, v) {
        unreadCounts[k.toString()] = (v as num?)?.toInt() ?? 0;
      });
    }
    return ConversationModel(
      id: id ?? map['id'] as String? ?? '',
      participantIds:
          List<String>.from(map['participantIds'] as List? ?? const []),
      participantNames:
          Map<String, String>.from(map['participantNames'] as Map? ?? const {}),
      participantRoles:
          Map<String, String>.from(map['participantRoles'] as Map? ?? const {}),
      lastMessage: map['lastMessage'] as String? ?? '',
      lastMessageTime: _parseTs(map['lastMessageTime']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      lastMessageSenderId: map['lastMessageSenderId'] as String?,
      unreadCounts: unreadCounts,
      isBlocked: map['isBlocked'] as bool? ?? false,
      blockedBy: map['blockedBy'] as String?,
      blockedAt: _parseTs(map['blockedAt']),
      unblockedBy: map['unblockedBy'] as String?,
      unblockedAt: _parseTs(map['unblockedAt']),
      createdAt: _parseTs(map['createdAt']),
      updatedAt: _parseTs(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'participantIds': participantIds,
        'participantNames': participantNames,
        'participantRoles': participantRoles,
        'lastMessage': lastMessage,
        'lastMessageTime': lastMessageTime.toIso8601String(),
        if (lastMessageSenderId != null)
          'lastMessageSenderId': lastMessageSenderId,
        'unreadCount': unreadCounts,
        'isBlocked': isBlocked,
        if (blockedBy != null) 'blockedBy': blockedBy,
        if (blockedAt != null) 'blockedAt': blockedAt!.toIso8601String(),
        if (unblockedBy != null) 'unblockedBy': unblockedBy,
        if (unblockedAt != null) 'unblockedAt': unblockedAt!.toIso8601String(),
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
      };
}

// ─── Quick Reply Model (Phase 6H) ─────────────────────────────────────────────
class QuickReplyModel {
  final String id;
  final String text;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final bool isActive;
  // Empty (or containing 'all') means visible to every role.
  final List<String> roles;

  const QuickReplyModel({
    required this.id,
    required this.text,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.isActive = true,
    this.roles = const [],
  });

  bool visibleToRole(String? role) =>
      roles.isEmpty ||
      roles.contains('all') ||
      (role != null && roles.contains(role));

  // ── Firestore serialization ───────────────────────────────────────────────

  static DateTime? _parseTs(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is double) return DateTime.fromMillisecondsSinceEpoch(v.round());
    try {
      return (v as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }

  static String? _asString(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    return v.toString();
  }

  static bool _asBool(dynamic v, {bool fallback = false}) {
    if (v == null) return fallback;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v.toLowerCase() == 'true';
    return fallback;
  }

  factory QuickReplyModel.fromMap(Map<String, dynamic> map, {String? id}) =>
      QuickReplyModel(
        id: id ?? _asString(map['id']) ?? '',
        text: _asString(map['text']) ?? '',
        createdAt: _parseTs(map['createdAt']),
        updatedAt: _parseTs(map['updatedAt']),
        createdBy: _asString(map['createdBy']),
        isActive: _asBool(map['isActive'], fallback: true),
        roles: map['roles'] is List
            ? List<String>.from((map['roles'] as List).map((e) => e.toString()))
            : const [],
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
        if (createdBy != null) 'createdBy': createdBy,
        'isActive': isActive,
        'roles': roles,
      };
}

// ─── Chat Report Model (Phase 6I) ─────────────────────────────────────────────
// Reports/requests raised from user chat screens ("Request Admin Help") and
// consumed by the Admin → Manage Chats → Requests tab. Status/priority are
// kept as plain strings (not enums) to match the Firestore field values
// directly and stay tolerant of any future value added server-side.
class ChatReportModel {
  final String id;
  final String conversationId;
  final String reporterId;
  final String reporterName;
  final String reporterRole;
  final String? reportedUserId;
  final String? reportedUserName;
  final String? reportedUserRole;
  final String? messageId;
  final String reason;
  final String? description;
  final String status; // open | in_review | resolved | rejected
  final String priority; // low | medium | high
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? adminNote;
  final bool isSeenByAdmin;

  const ChatReportModel({
    required this.id,
    required this.conversationId,
    required this.reporterId,
    required this.reporterName,
    required this.reporterRole,
    this.reportedUserId,
    this.reportedUserName,
    this.reportedUserRole,
    this.messageId,
    required this.reason,
    this.description,
    this.status = 'open',
    this.priority = 'medium',
    this.createdAt,
    this.updatedAt,
    this.adminNote,
    this.isSeenByAdmin = false,
  });

  ChatReportModel copyWith({
    String? status,
    String? adminNote,
    DateTime? updatedAt,
    bool? isSeenByAdmin,
  }) =>
      ChatReportModel(
        id: id,
        conversationId: conversationId,
        reporterId: reporterId,
        reporterName: reporterName,
        reporterRole: reporterRole,
        reportedUserId: reportedUserId,
        reportedUserName: reportedUserName,
        reportedUserRole: reportedUserRole,
        messageId: messageId,
        reason: reason,
        description: description,
        status: status ?? this.status,
        priority: priority,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        adminNote: adminNote ?? this.adminNote,
        isSeenByAdmin: isSeenByAdmin ?? this.isSeenByAdmin,
      );

  // ── Firestore serialization ───────────────────────────────────────────────

  static DateTime? _parseTs(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is double) return DateTime.fromMillisecondsSinceEpoch(v.round());
    try {
      return (v as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }

  static String? _asString(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    return v.toString();
  }

  factory ChatReportModel.fromMap(Map<String, dynamic> map, {String? id}) =>
      ChatReportModel(
        id: id ?? _asString(map['id']) ?? '',
        conversationId: _asString(map['conversationId']) ?? '',
        reporterId: _asString(map['reporterId']) ?? '',
        reporterName: _asString(map['reporterName']) ?? 'Unknown',
        reporterRole: _asString(map['reporterRole']) ?? 'customer',
        reportedUserId: _asString(map['reportedUserId']),
        reportedUserName: _asString(map['reportedUserName']),
        reportedUserRole: _asString(map['reportedUserRole']),
        messageId: _asString(map['messageId']),
        reason: _asString(map['reason']) ?? 'Other',
        description: _asString(map['description']),
        status: _asString(map['status']) ?? 'open',
        priority: _asString(map['priority']) ?? 'medium',
        createdAt: _parseTs(map['createdAt']),
        updatedAt: _parseTs(map['updatedAt']),
        adminNote: _asString(map['adminNote']),
        isSeenByAdmin: map['isSeenByAdmin'] == true,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'conversationId': conversationId,
        'reporterId': reporterId,
        'reporterName': reporterName,
        'reporterRole': reporterRole,
        if (reportedUserId != null) 'reportedUserId': reportedUserId,
        if (reportedUserName != null) 'reportedUserName': reportedUserName,
        if (reportedUserRole != null) 'reportedUserRole': reportedUserRole,
        if (messageId != null) 'messageId': messageId,
        'reason': reason,
        if (description != null) 'description': description,
        'status': status,
        'priority': priority,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
        if (adminNote != null) 'adminNote': adminNote,
        'isSeenByAdmin': isSeenByAdmin,
      };
}

// ─── Category Model ───────────────────────────────────────────────────────────
class CategoryModel {
  final String id;
  final String nameKey;
  final String icon;
  final int providerCount;
  final String? description;
  // isActive: if false the category is hidden from registration.
  // Defaults to true so categories without this field still appear.
  final bool isActive;
  // order: lower number appears first; null means sort by nameKey.
  final int? order;

  const CategoryModel({
    required this.id,
    required this.nameKey,
    required this.icon,
    required this.providerCount,
    this.description,
    this.isActive = true,
    this.order,
  });

  CategoryModel copyWith({
    String? nameKey,
    String? icon,
    int? providerCount,
    String? description,
    bool? isActive,
    int? order,
  }) =>
      CategoryModel(
        id: id,
        nameKey: nameKey ?? this.nameKey,
        icon: icon ?? this.icon,
        providerCount: providerCount ?? this.providerCount,
        description: description ?? this.description,
        isActive: isActive ?? this.isActive,
        order: order ?? this.order,
      );

  factory CategoryModel.fromMap(Map<String, dynamic> map, {String? id}) =>
      CategoryModel(
        id: id ?? map['id'] as String? ?? '',
        nameKey: map['nameKey'] as String? ?? '',
        icon: map['icon'] as String? ?? '📦',
        providerCount: (map['providerCount'] as num?)?.toInt() ?? 0,
        description: map['description'] as String?,
        isActive: map['isActive'] as bool? ?? true,
        order: (map['order'] as num?)?.toInt(),
      );

  Map<String, dynamic> toMap() => {
        'nameKey': nameKey,
        'icon': icon,
        'providerCount': providerCount,
        if (description != null) 'description': description,
        'isActive': isActive,
        if (order != null) 'order': order,
      };
}

// ─── Complaint Model ──────────────────────────────────────────────────────────
// `customer` was added to support professional/contractor complaints filed
// against a customer from Order Details (Firestore type: 'customer_report').
// `reviewReport` supports professional/contractor reporting an unfair review
// (Firestore type: 'review_report').
enum ComplaintType {
  order,
  provider,
  customer,
  category,
  general,
  reviewReport
}

// `rejected`/`deleted` were added for the Admin Complaints Center Rejected tab
// and soft-delete from My Complaints (Firestore statuses: 'rejected'/'deleted').
enum ComplaintStatus { open, inReview, resolved, rejected, deleted }

// `urgent` was added to match the Firestore complaints schema priority set.
enum ComplaintPriority { low, medium, high, urgent }

class ComplaintModel {
  final String id;
  final String userId; // complainantId
  final String userName; // complainantName
  final String? complainantRole; // customer / professional / contractor / admin
  final ComplaintType type;
  final String? targetId; // legacy generic target (provider/order id)
  final String? targetName; // legacy generic target name
  final String? targetUserId;
  final String? targetUserName;
  final String? targetUserRole; // customer / professional / contractor
  final String reason; // short title
  final String description;
  final ComplaintStatus status;
  final ComplaintPriority priority;
  final String? relatedOrderId;
  final String? relatedOrderTitle;
  final String? relatedProviderId;
  final String? relatedProviderName;
  final String? relatedReviewId;
  final String? relatedConversationId;
  final String?
      sourceContext; // provider_profile / order_details / my_complaints / other
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? resolvedAt;
  final bool isDeleted;
  final String? replyText;
  final DateTime? repliedAt;
  final String? repliedBy;
  final String? adminNote;

  const ComplaintModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.complainantRole,
    required this.type,
    this.targetId,
    this.targetName,
    this.targetUserId,
    this.targetUserName,
    this.targetUserRole,
    required this.reason,
    required this.description,
    this.status = ComplaintStatus.open,
    this.priority = ComplaintPriority.medium,
    this.relatedOrderId,
    this.relatedOrderTitle,
    this.relatedProviderId,
    this.relatedProviderName,
    this.relatedReviewId,
    this.relatedConversationId,
    this.sourceContext,
    required this.createdAt,
    this.updatedAt,
    this.resolvedAt,
    this.isDeleted = false,
    this.replyText,
    this.repliedAt,
    this.repliedBy,
    this.adminNote,
  });

  String get title => reason;
  String get complainantId => userId;
  String get complainantName => userName;

  ComplaintModel copyWith({
    ComplaintStatus? status,
    ComplaintPriority? priority,
    String? replyText,
    DateTime? repliedAt,
    String? repliedBy,
    String? adminNote,
    String? reason,
    String? description,
    DateTime? updatedAt,
    DateTime? resolvedAt,
    bool? isDeleted,
  }) =>
      ComplaintModel(
        id: id,
        userId: userId,
        userName: userName,
        complainantRole: complainantRole,
        type: type,
        targetId: targetId,
        targetName: targetName,
        targetUserId: targetUserId,
        targetUserName: targetUserName,
        targetUserRole: targetUserRole,
        reason: reason ?? this.reason,
        description: description ?? this.description,
        status: status ?? this.status,
        priority: priority ?? this.priority,
        relatedOrderId: relatedOrderId,
        relatedOrderTitle: relatedOrderTitle,
        relatedProviderId: relatedProviderId,
        relatedProviderName: relatedProviderName,
        relatedReviewId: relatedReviewId,
        relatedConversationId: relatedConversationId,
        sourceContext: sourceContext,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        resolvedAt: resolvedAt ?? this.resolvedAt,
        isDeleted: isDeleted ?? this.isDeleted,
        replyText: replyText ?? this.replyText,
        repliedAt: repliedAt ?? this.repliedAt,
        repliedBy: repliedBy ?? this.repliedBy,
        adminNote: adminNote ?? this.adminNote,
      );

  static ComplaintType typeFromString(String? s) {
    switch (s) {
      case 'provider_report':
        return ComplaintType.provider;
      case 'customer_report':
        return ComplaintType.customer;
      case 'order_problem':
        return ComplaintType.order;
      case 'service_problem':
        return ComplaintType.category;
      case 'review_report':
        return ComplaintType.reviewReport;
      case 'general_complaint':
        return ComplaintType.general;
      default:
        return ComplaintType.general;
    }
  }

  static String typeToString(ComplaintType t) {
    switch (t) {
      case ComplaintType.provider:
        return 'provider_report';
      case ComplaintType.customer:
        return 'customer_report';
      case ComplaintType.order:
        return 'order_problem';
      case ComplaintType.category:
        return 'service_problem';
      case ComplaintType.reviewReport:
        return 'review_report';
      case ComplaintType.general:
        return 'general_complaint';
    }
  }

  static ComplaintStatus statusFromString(String? s) {
    switch (s) {
      case 'in_review':
        return ComplaintStatus.inReview;
      case 'resolved':
        return ComplaintStatus.resolved;
      case 'rejected':
        return ComplaintStatus.rejected;
      case 'deleted':
        return ComplaintStatus.deleted;
      default:
        return ComplaintStatus.open;
    }
  }

  static String statusToString(ComplaintStatus s) {
    switch (s) {
      case ComplaintStatus.open:
        return 'open';
      case ComplaintStatus.inReview:
        return 'in_review';
      case ComplaintStatus.resolved:
        return 'resolved';
      case ComplaintStatus.rejected:
        return 'rejected';
      case ComplaintStatus.deleted:
        return 'deleted';
    }
  }

  static ComplaintPriority priorityFromString(String? s) {
    switch (s) {
      case 'low':
        return ComplaintPriority.low;
      case 'high':
        return ComplaintPriority.high;
      case 'urgent':
        return ComplaintPriority.urgent;
      default:
        return ComplaintPriority.medium;
    }
  }

  static String priorityToString(ComplaintPriority p) {
    switch (p) {
      case ComplaintPriority.low:
        return 'low';
      case ComplaintPriority.medium:
        return 'medium';
      case ComplaintPriority.high:
        return 'high';
      case ComplaintPriority.urgent:
        return 'urgent';
    }
  }

  static DateTime? _parseTs(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    try {
      return (v as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }

  factory ComplaintModel.fromFirestore(Map<String, dynamic> map,
          {String? id}) =>
      ComplaintModel(
        id: id ?? map['id'] as String? ?? '',
        userId:
            map['complainantId'] as String? ?? map['userId'] as String? ?? '',
        userName: map['complainantName'] as String? ??
            map['userName'] as String? ??
            '',
        complainantRole: map['complainantRole'] as String?,
        type: typeFromString(map['type'] as String?),
        targetId: map['targetId'] as String? ?? map['targetUserId'] as String?,
        targetName:
            map['targetName'] as String? ?? map['targetUserName'] as String?,
        targetUserId: map['targetUserId'] as String?,
        targetUserName: map['targetUserName'] as String?,
        targetUserRole: map['targetUserRole'] as String?,
        reason: map['title'] as String? ?? map['reason'] as String? ?? '',
        description: map['description'] as String? ?? '',
        status: statusFromString(map['status'] as String?),
        priority: priorityFromString(map['priority'] as String?),
        relatedOrderId: map['relatedOrderId'] as String?,
        relatedOrderTitle: map['relatedOrderTitle'] as String?,
        relatedProviderId: map['relatedProviderId'] as String?,
        relatedProviderName: map['relatedProviderName'] as String?,
        relatedReviewId: map['relatedReviewId'] as String?,
        relatedConversationId: map['relatedConversationId'] as String?,
        sourceContext: map['sourceContext'] as String?,
        createdAt: _parseTs(map['createdAt']) ?? DateTime.now(),
        updatedAt: _parseTs(map['updatedAt']),
        resolvedAt: _parseTs(map['resolvedAt']),
        isDeleted: map['isDeleted'] as bool? ?? false,
        replyText: map['replyText'] as String?,
        repliedAt: _parseTs(map['repliedAt']),
        repliedBy: map['repliedBy'] as String?,
        adminNote: map['adminNote'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'complainantId': userId,
        'complainantName': userName,
        if (complainantRole != null) 'complainantRole': complainantRole,
        'type': typeToString(type),
        if (targetId != null) 'targetId': targetId,
        if (targetName != null) 'targetName': targetName,
        if (targetUserId != null) 'targetUserId': targetUserId,
        if (targetUserName != null) 'targetUserName': targetUserName,
        if (targetUserRole != null) 'targetUserRole': targetUserRole,
        'title': reason,
        'reason': reason,
        'description': description,
        'status': statusToString(status),
        'priority': priorityToString(priority),
        if (relatedOrderId != null) 'relatedOrderId': relatedOrderId,
        if (relatedOrderTitle != null) 'relatedOrderTitle': relatedOrderTitle,
        if (relatedProviderId != null) 'relatedProviderId': relatedProviderId,
        if (relatedProviderName != null)
          'relatedProviderName': relatedProviderName,
        if (relatedReviewId != null) 'relatedReviewId': relatedReviewId,
        if (relatedConversationId != null)
          'relatedConversationId': relatedConversationId,
        if (sourceContext != null) 'sourceContext': sourceContext,
        'createdAt': createdAt.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
        if (resolvedAt != null) 'resolvedAt': resolvedAt!.toIso8601String(),
        'isDeleted': isDeleted,
        if (replyText != null) 'replyText': replyText,
        if (repliedAt != null) 'repliedAt': repliedAt!.toIso8601String(),
        if (repliedBy != null) 'repliedBy': repliedBy,
        if (adminNote != null) 'adminNote': adminNote,
      };
}

// ─── Notification Model ───────────────────────────────────────────────────────
// Firestore collection: `notifications`. A notification is visible to a user
// when userId == current user id, OR targetRole == current user's role,
// OR targetRole == 'all'. Broadcasts (Phase 9A) use targetRole only — never
// one document per user.
enum NotificationType {
  general,
  broadcast,
  orderUpdate,
  chat,
  complaint,
  review,
  system,
  categoryRequest
}

class NotificationModel {
  final String id;
  final String? userId; // specific target user, if any
  final String?
      targetRole; // customer / professional / contractor / admin / all
  final String title;
  final String message;
  final NotificationType type;
  final String? relatedOrderId;
  final String? relatedConversationId;
  final String? relatedComplaintId;
  final String? relatedReviewId;
  final String? relatedUserId;
  final String? relatedCategoryRequestId;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;
  final bool isDeleted;
  final String? createdById;
  final String? createdByName;
  final String? createdByRole;

  const NotificationModel({
    required this.id,
    this.userId,
    this.targetRole,
    required this.title,
    required this.message,
    this.type = NotificationType.general,
    this.relatedOrderId,
    this.relatedConversationId,
    this.relatedComplaintId,
    this.relatedReviewId,
    this.relatedUserId,
    this.relatedCategoryRequestId,
    this.isRead = false,
    required this.createdAt,
    this.readAt,
    this.isDeleted = false,
    this.createdById,
    this.createdByName,
    this.createdByRole,
  });

  NotificationModel copyWith({
    bool? isRead,
    DateTime? readAt,
    bool? isDeleted,
  }) =>
      NotificationModel(
        id: id,
        userId: userId,
        targetRole: targetRole,
        title: title,
        message: message,
        type: type,
        relatedOrderId: relatedOrderId,
        relatedConversationId: relatedConversationId,
        relatedComplaintId: relatedComplaintId,
        relatedReviewId: relatedReviewId,
        relatedUserId: relatedUserId,
        relatedCategoryRequestId: relatedCategoryRequestId,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
        readAt: readAt ?? this.readAt,
        isDeleted: isDeleted ?? this.isDeleted,
        createdById: createdById,
        createdByName: createdByName,
        createdByRole: createdByRole,
      );

  static NotificationType typeFromString(String? s) {
    switch (s) {
      case 'broadcast':
        return NotificationType.broadcast;
      case 'order_update':
        return NotificationType.orderUpdate;
      case 'chat':
        return NotificationType.chat;
      case 'complaint':
        return NotificationType.complaint;
      case 'review':
        return NotificationType.review;
      case 'system':
        return NotificationType.system;
      case 'category_request':
        return NotificationType.categoryRequest;
      default:
        return NotificationType.general;
    }
  }

  static String typeToString(NotificationType t) {
    switch (t) {
      case NotificationType.broadcast:
        return 'broadcast';
      case NotificationType.orderUpdate:
        return 'order_update';
      case NotificationType.chat:
        return 'chat';
      case NotificationType.complaint:
        return 'complaint';
      case NotificationType.review:
        return 'review';
      case NotificationType.system:
        return 'system';
      case NotificationType.categoryRequest:
        return 'category_request';
      case NotificationType.general:
        return 'general';
    }
  }

  // 'all' is a valid targetRole (broadcast to everyone) but is not a UserRole,
  // so it's handled separately from this per-role conversion.
  static String roleToString(UserRole r) {
    switch (r) {
      case UserRole.professional:
        return 'professional';
      case UserRole.contractor:
        return 'contractor';
      case UserRole.admin:
        return 'admin';
      case UserRole.customer:
        return 'customer';
    }
  }

  static DateTime? _parseTs(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    try {
      return (v as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }

  factory NotificationModel.fromFirestore(Map<String, dynamic> map,
          {String? id}) =>
      NotificationModel(
        id: id ?? map['id'] as String? ?? '',
        userId: map['userId'] as String?,
        targetRole: map['targetRole'] as String?,
        title: map['title'] as String? ?? '',
        message: map['message'] as String? ?? '',
        type: typeFromString(map['type'] as String?),
        relatedOrderId: map['relatedOrderId'] as String?,
        relatedConversationId: map['relatedConversationId'] as String?,
        relatedComplaintId: map['relatedComplaintId'] as String?,
        relatedReviewId: map['relatedReviewId'] as String?,
        relatedUserId: map['relatedUserId'] as String?,
        relatedCategoryRequestId: map['relatedCategoryRequestId'] as String?,
        isRead: map['isRead'] as bool? ?? false,
        createdAt: _parseTs(map['createdAt']) ?? DateTime.now(),
        readAt: _parseTs(map['readAt']),
        isDeleted: map['isDeleted'] as bool? ?? false,
        createdById: map['createdById'] as String?,
        createdByName: map['createdByName'] as String?,
        createdByRole: map['createdByRole'] as String?,
      );

  Map<String, dynamic> toMap() => {
        if (userId != null) 'userId': userId,
        if (targetRole != null) 'targetRole': targetRole,
        'title': title,
        'message': message,
        'type': typeToString(type),
        if (relatedOrderId != null) 'relatedOrderId': relatedOrderId,
        if (relatedConversationId != null)
          'relatedConversationId': relatedConversationId,
        if (relatedComplaintId != null)
          'relatedComplaintId': relatedComplaintId,
        if (relatedReviewId != null) 'relatedReviewId': relatedReviewId,
        if (relatedUserId != null) 'relatedUserId': relatedUserId,
        if (relatedCategoryRequestId != null)
          'relatedCategoryRequestId': relatedCategoryRequestId,
        'isRead': isRead,
        'createdAt': createdAt.toIso8601String(),
        if (readAt != null) 'readAt': readAt!.toIso8601String(),
        'isDeleted': isDeleted,
        if (createdById != null) 'createdById': createdById,
        if (createdByName != null) 'createdByName': createdByName,
        if (createdByRole != null) 'createdByRole': createdByRole,
      };
}

// ─── Per-user Notification State (Phase 5C1B / 5C2) ────────────────────────────
// Firestore collection: `users/{uid}/notification_states/{notificationId}`.
// notifications/{id} content is immutable and shared across every recipient
// of a targetRole/'all' notification; read/delete state must never live on
// that shared document (see Phase 5C1B) — this is the per-user overlay
// instead. Never serialized back onto notifications/{id}.
class NotificationStateView {
  final bool isRead;
  final bool isDeleted;
  final DateTime? readAt;

  const NotificationStateView({
    this.isRead = false,
    this.isDeleted = false,
    this.readAt,
  });

  factory NotificationStateView.fromFirestore(Map<String, dynamic> map) =>
      NotificationStateView(
        isRead: map['isRead'] as bool? ?? false,
        isDeleted: map['isDeleted'] as bool? ?? false,
        readAt: NotificationModel._parseTs(map['readAt']),
      );
}

// Overlays a user's own NotificationStateView onto a shared NotificationModel
// for display — the shape every notification-consuming screen works with.
// isRead/isDeleted/readAt here are the *effective* per-user values (default
// unread/not-deleted when no state document exists yet), never the legacy
// shared fields serialized on NotificationModel itself.
class UserNotificationView {
  final NotificationModel notification;
  final bool isRead;
  final bool isDeleted;
  final DateTime? readAt;

  const UserNotificationView({
    required this.notification,
    this.isRead = false,
    this.isDeleted = false,
    this.readAt,
  });

  String get id => notification.id;
}

// ─── Review Model ─────────────────────────────────────────────────────────────
class ReviewModel {
  final String id;
  final String? orderId;
  final String customerId;
  final String customerName;
  final String providerId;
  final String providerName;
  final String providerRole; // 'professional' | 'contractor'
  final double speedRating;
  final double qualityRating;
  final double communicationRating;
  // Per-criterion ratings keyed by review_criteria doc id, populated for
  // reviews submitted through the dynamic criteria form. Empty for legacy
  // reviews, which fall back to the speed/quality/communication fields below.
  final Map<String, double> criteriaRatings;
  final String comment;
  final String? relatedService;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String status; // 'visible' | 'hidden' | 'deleted'
  final bool isHidden;
  final int reportCount;
  final String? reportReason;

  const ReviewModel({
    required this.id,
    this.orderId,
    required this.customerId,
    required this.customerName,
    required this.providerId,
    this.providerName = '',
    this.providerRole = 'professional',
    required this.speedRating,
    required this.qualityRating,
    required this.communicationRating,
    this.criteriaRatings = const {},
    required this.comment,
    this.relatedService,
    required this.createdAt,
    this.updatedAt,
    this.status = 'visible',
    this.isHidden = false,
    this.reportCount = 0,
    this.reportReason,
  });

  // New reviews derive the overall rating from whatever dynamic criteria
  // were shown at submit time; old reviews (no criteriaRatings) keep the
  // original speed/quality/communication average unchanged.
  double get overallRating => criteriaRatings.isNotEmpty
      ? criteriaRatings.values.reduce((a, b) => a + b) / criteriaRatings.length
      : (speedRating + qualityRating + communicationRating) / 3;
  double get rating => overallRating;

  ReviewModel copyWith({
    String? id,
    String? orderId,
    String? customerId,
    String? customerName,
    String? providerId,
    String? providerName,
    String? providerRole,
    double? speedRating,
    double? qualityRating,
    double? communicationRating,
    Map<String, double>? criteriaRatings,
    String? comment,
    String? relatedService,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
    bool? isHidden,
    int? reportCount,
    String? reportReason,
  }) =>
      ReviewModel(
        id: id ?? this.id,
        orderId: orderId ?? this.orderId,
        customerId: customerId ?? this.customerId,
        customerName: customerName ?? this.customerName,
        providerId: providerId ?? this.providerId,
        providerName: providerName ?? this.providerName,
        providerRole: providerRole ?? this.providerRole,
        speedRating: speedRating ?? this.speedRating,
        qualityRating: qualityRating ?? this.qualityRating,
        communicationRating: communicationRating ?? this.communicationRating,
        criteriaRatings: criteriaRatings ?? this.criteriaRatings,
        comment: comment ?? this.comment,
        relatedService: relatedService ?? this.relatedService,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        status: status ?? this.status,
        isHidden: isHidden ?? this.isHidden,
        reportCount: reportCount ?? this.reportCount,
        reportReason: reportReason ?? this.reportReason,
      );

  // Handles Firestore Timestamp (duck-typed via toDate()), DateTime, ISO
  // strings, and millisecond int/double — mirrors OrderModel._parseTs.
  static DateTime? _parseTs(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is double) return DateTime.fromMillisecondsSinceEpoch(v.round());
    try {
      return (v as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }

  // Coerces any Firestore value to a nullable String instead of using a hard
  // `as String?` cast, which throws if a document ever stores the wrong type
  // for a field — a single bad field must not crash the whole reviews stream.
  static String? _asString(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    return v.toString();
  }

  static bool _asBool(dynamic v, {bool fallback = false}) {
    if (v == null) return fallback;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v.toLowerCase() == 'true';
    return fallback;
  }

  static double _asDouble(dynamic v, {double fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  // Missing/malformed criteriaRatings must never crash the reviews stream —
  // old reviews simply have no per-criterion breakdown.
  static Map<String, double> _asCriteriaRatings(dynamic v) {
    if (v is Map) {
      final out = <String, double>{};
      v.forEach((key, value) {
        if (key is String) out[key] = _asDouble(value);
      });
      return out;
    }
    return const {};
  }

  factory ReviewModel.fromFirestore(Map<String, dynamic> map, {String? id}) {
    final speed = _asDouble(map['speedRating']);
    final quality = _asDouble(map['qualityRating']);
    final communication = _asDouble(map['communicationRating']);
    // status/isHidden default to visible/false when absent so legacy or
    // partially-written docs still show up instead of vanishing.
    final rawStatus = _asString(map['status']);
    final status =
        (rawStatus == null || rawStatus.isEmpty) ? 'visible' : rawStatus;
    return ReviewModel(
      id: id ?? _asString(map['id']) ?? '',
      orderId: _asString(map['orderId']),
      customerId: _asString(map['customerId']) ?? '',
      customerName: _asString(map['customerName']) ?? '',
      providerId: _asString(map['providerId']) ?? '',
      providerName: _asString(map['providerName']) ?? '',
      providerRole: _asString(map['providerRole']) ?? 'professional',
      speedRating: speed,
      qualityRating: quality,
      communicationRating: communication,
      criteriaRatings: _asCriteriaRatings(map['criteriaRatings']),
      comment: _asString(map['comment']) ?? '',
      relatedService: _asString(map['relatedService']),
      createdAt: _parseTs(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseTs(map['updatedAt']),
      status: status,
      isHidden: _asBool(map['isHidden']),
      reportCount: (map['reportCount'] as num?)?.toInt() ?? 0,
      reportReason: _asString(map['reportReason']),
    );
  }

  Map<String, dynamic> toMap() => {
        'customerId': customerId,
        'customerName': customerName,
        'providerId': providerId,
        'providerName': providerName,
        'providerRole': providerRole,
        if (orderId != null) 'orderId': orderId,
        'speedRating': speedRating,
        'qualityRating': qualityRating,
        'communicationRating': communicationRating,
        if (criteriaRatings.isNotEmpty) 'criteriaRatings': criteriaRatings,
        'rating': overallRating,
        'comment': comment,
        if (relatedService != null) 'relatedService': relatedService,
        'createdAt': createdAt.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
        'status': status,
        'isHidden': isHidden,
        'reportCount': reportCount,
        if (reportReason != null) 'reportReason': reportReason,
      };
}

// ─── Review Criteria Model ────────────────────────────────────────────────────
// Firestore field names differ from the Dart-side names kept for UI
// compatibility: 'title' <-> name, 'order' <-> sortOrder.
class ReviewCriteriaModel {
  final String id;
  final String name;
  final String description;
  final String icon;
  final bool isActive;
  final bool isRequired;
  final int maxRating;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ReviewCriteriaModel({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.isActive = true,
    this.isRequired = false,
    this.maxRating = 5,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  ReviewCriteriaModel copyWith({
    String? name,
    String? description,
    String? icon,
    bool? isActive,
    bool? isRequired,
    int? maxRating,
    int? sortOrder,
  }) =>
      ReviewCriteriaModel(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        icon: icon ?? this.icon,
        isActive: isActive ?? this.isActive,
        isRequired: isRequired ?? this.isRequired,
        maxRating: maxRating ?? this.maxRating,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  static DateTime? _parseTs(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    try {
      return (v as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }

  factory ReviewCriteriaModel.fromFirestore(Map<String, dynamic> map,
          {String? id}) =>
      ReviewCriteriaModel(
        id: id ?? map['id'] as String? ?? '',
        name: map['title'] as String? ?? map['name'] as String? ?? '',
        description: map['description'] as String? ?? '',
        icon: map['icon'] as String? ?? '⭐',
        isActive: map['isActive'] as bool? ?? true,
        isRequired: map['isRequired'] as bool? ?? false,
        maxRating: (map['maxRating'] as num?)?.toInt() ?? 5,
        sortOrder: (map['order'] as num?)?.toInt() ??
            (map['sortOrder'] as num?)?.toInt() ??
            0,
        createdAt: _parseTs(map['createdAt']),
        updatedAt: _parseTs(map['updatedAt']),
      );

  Map<String, dynamic> toMap() => {
        'title': name,
        'description': description,
        'icon': icon,
        'isActive': isActive,
        'isRequired': isRequired,
        'maxRating': maxRating,
        'order': sortOrder,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };
}

// ─── Category Request Model ───────────────────────────────────────────────────
class CategoryRequestModel {
  final String id;
  final String requesterId;
  final String requesterName;
  final String requesterRole;
  final String requestedName;
  final String requestedDescription;
  final String status;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? adminNote;

  const CategoryRequestModel({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    required this.requesterRole,
    required this.requestedName,
    required this.requestedDescription,
    this.status = 'pending',
    required this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
    this.adminNote,
  });

  static DateTime? _parseTs(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    try {
      return (v as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }

  factory CategoryRequestModel.fromMap(Map<String, dynamic> map,
          {String? id}) =>
      CategoryRequestModel(
        id: id ?? '',
        requesterId: map['requesterId'] as String? ?? '',
        requesterName: map['requesterName'] as String? ?? '',
        requesterRole: map['requesterRole'] as String? ?? 'professional',
        requestedName: map['requestedName'] as String? ?? '',
        requestedDescription: map['requestedDescription'] as String? ?? '',
        status: map['status'] as String? ?? 'pending',
        createdAt: _parseTs(map['createdAt']) ?? DateTime.now(),
        reviewedAt: _parseTs(map['reviewedAt']),
        reviewedBy: map['reviewedBy'] as String?,
        adminNote: map['adminNote'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'requesterId': requesterId,
        'requesterName': requesterName,
        'requesterRole': requesterRole,
        'requestedName': requestedName,
        'requestedDescription': requestedDescription,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        if (reviewedAt != null) 'reviewedAt': reviewedAt!.toIso8601String(),
        if (reviewedBy != null) 'reviewedBy': reviewedBy,
        if (adminNote != null) 'adminNote': adminNote,
      };
}

// ─── Favorite Model ───────────────────────────────────────────────────────────
class FavoriteModel {
  final String id;
  final String customerId;
  final String providerId;
  final String providerName;
  final String providerRole;
  final String? providerCategory;
  final String? providerImageUrl;
  final DateTime createdAt;

  const FavoriteModel({
    required this.id,
    required this.customerId,
    required this.providerId,
    required this.providerName,
    required this.providerRole,
    this.providerCategory,
    this.providerImageUrl,
    required this.createdAt,
  });

  static DateTime _parseTs(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    try {
      return (v as dynamic).toDate() as DateTime;
    } catch (_) {
      return DateTime.now();
    }
  }

  factory FavoriteModel.fromFirestore(Map<String, dynamic> map, {String? id}) =>
      FavoriteModel(
        id: id ?? map['id'] as String? ?? '',
        customerId: map['customerId'] as String? ?? '',
        providerId: map['providerId'] as String? ?? '',
        providerName: map['providerName'] as String? ?? '',
        providerRole: map['providerRole'] as String? ?? '',
        providerCategory: map['providerCategory'] as String?,
        providerImageUrl: map['providerImageUrl'] as String?,
        createdAt: _parseTs(map['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'customerId': customerId,
        'providerId': providerId,
        'providerName': providerName,
        'providerRole': providerRole,
        if (providerCategory != null) 'providerCategory': providerCategory,
        if (providerImageUrl != null) 'providerImageUrl': providerImageUrl,
        'createdAt': createdAt.toIso8601String(),
      };
}
