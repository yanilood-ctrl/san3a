import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/models/models.dart';
import '../../../auth/presentation/providers/app_providers.dart';

final adminNavIndexProvider = StateProvider<int>((ref) => 0);

// Set by other Admin sections (e.g. Category Details) to request that the
// Admin Users tab open a specific user's details once it becomes visible.
// Consumed and reset to null by AdminUsersScreen — a non-null value here is
// a one-shot "please open this user" signal, not persistent selection state.
final adminPendingUserDetailsIdProvider = StateProvider<String?>((ref) => null);

// Set by Admin Complaints Center ("Open Related Page") to request that the
// Admin Orders tab open a specific order's details once it becomes visible.
// Consumed and reset to null by AdminOrdersScreen — same one-shot pattern as
// adminPendingUserDetailsIdProvider.
final adminPendingOrderDetailsIdProvider =
    StateProvider<String?>((ref) => null);

// Set by Admin Complaints Center ("Open Related Page") to request that
// Review Management open a specific review's details once it becomes
// visible. Consumed and reset to null by AdminReviewManagementScreen —
// same one-shot pattern as adminPendingUserDetailsIdProvider.
final adminPendingReviewDetailsIdProvider =
    StateProvider<String?>((ref) => null);

// ─── Firestore users stream ───────────────────────────────────────────────────
final firestoreUsersStreamProvider = StreamProvider<List<UserModel>>((ref) {
  return FirebaseFirestore.instance.collection('users').snapshots().map(
      (snap) =>
          snap.docs.map((d) => UserModel.fromMap(d.data(), id: d.id)).toList());
});

// ─── Users ────────────────────────────────────────────────────────────────────
class AdminUsersNotifier extends StateNotifier<List<UserModel>> {
  AdminUsersNotifier() : super([]);

  // Replaces the full list whenever the Firestore stream emits new data.
  void setUsers(List<UserModel> users) => state = users;

  void updateUser(UserModel updated) {
    state = state.map((u) => u.id == updated.id ? updated : u).toList();
  }

  /// Persists an Admin-initiated partial edit (Edit User dialog) straight to
  /// Firestore using update() (merge semantics — only the given keys are
  /// touched, everything else in the document is left alone). Unlike
  /// [updateUser] above, which only mutates local state and is never picked
  /// back up unless the Firestore stream happens to re-emit, this is the
  /// single source of truth for Admin Edit User saves; [state] refreshes
  /// itself afterwards via the live firestoreUsersStreamProvider listener,
  /// so no local mutation is done here.
  Future<void> updateUserFields(
      String userId, Map<String, dynamic> changes) async {
    if (changes.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update(changes);
  }

  /// Sets/clears the indefinite account block (Admin Users → Block/Unblock).
  /// Real partial Firestore write — only 'isBlocked' is touched, independent
  /// of suspendedUntil so an active suspension survives an unblock and vice
  /// versa. [state] refreshes via the live firestoreUsersStreamProvider
  /// listener, same as [updateUserFields].
  Future<void> setUserBlocked(String userId, bool blocked) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({'isBlocked': blocked});
  }

  /// Suspends a user until [until] (Admin Users → Suspend). Stored as an
  /// ISO-8601 string to match UserModel.toMap()'s existing convention for
  /// this field — UserModel._parseDateTime does not understand a raw
  /// Firestore Timestamp, so writing one here would silently fail to parse
  /// back on the next read.
  Future<void> suspendUserFirestore(String userId, DateTime until) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({'suspendedUntil': until.toIso8601String()});
  }

  /// Lifts a suspension early. In normal operation a suspension simply
  /// expires on its own (see UserModel.isActivelySuspended), but this is
  /// kept available for a manual admin override.
  Future<void> unsuspendUserFirestore(String userId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({'suspendedUntil': null});
  }

  /// Soft delete / deactivate (Admin Users → Delete User). Real partial
  /// Firestore write — only 'isDeleted'/'deletedAt' are touched. The
  /// users/{userId} document, the Firebase Auth account, and every linked
  /// record (orders, reviews, conversations, complaints, notifications,
  /// favorites, contractor_workers) are left completely alone; nothing is
  /// deleted or rewritten. [state] refreshes via the live
  /// firestoreUsersStreamProvider listener, same as [updateUserFields].
  ///
  /// Defensive guard (not just a UI/menu-level check): refuses to write
  /// isDeleted for an admin account, looked up from the current live
  /// [state] rather than trusting the caller.
  Future<void> softDeleteUser(String userId) async {
    final target = state.where((u) => u.id == userId);
    if (target.isNotEmpty && target.first.role == UserRole.admin) {
      throw Exception('Admin accounts cannot be deactivated.');
    }
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'isDeleted': true,
      'deletedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Restores a soft-deleted user (Admin Users → Restore User). Clears only
  /// isDeleted/deletedAt — isBlocked, suspendedUntil, role, and every other
  /// field are left exactly as they were, so a previously-blocked or
  /// still-suspended account stays blocked/suspended after restore.
  Future<void> restoreDeletedUser(String userId) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'isDeleted': false,
      'deletedAt': null,
    });
  }

  /// Local-state-only (see [updateUser]) — kept for backward compat but no
  /// longer called; use [softDeleteUser] instead.
  void deleteUser(String id) {
    state = state.where((u) => u.id != id).toList();
  }

  void addUser(UserModel user) {
    state = [...state, user];
  }

  /// Send a warning message to the user (appends to their warnings list)
  void warnUser(String userId, String warningMessage) {
    state = state.map((u) {
      if (u.id != userId) return u;
      return u.copyWith(warnings: [...u.warnings, warningMessage]);
    }).toList();
  }

  /// Suspend user until [until] datetime.
  /// Local-state-only (see [updateUser]) — kept for backward compat but no
  /// longer called; use [suspendUserFirestore] instead.
  void suspendUser(String userId, DateTime until) {
    state = state.map((u) {
      if (u.id != userId) return u;
      return u.copyWith(suspendedUntil: until);
    }).toList();
  }

  /// Lift suspension.
  /// Local-state-only (see [updateUser]) — kept for backward compat but no
  /// longer called; use [unsuspendUserFirestore] instead.
  void unsuspendUser(String userId) {
    state = state.map((u) {
      if (u.id != userId) return u;
      return u.copyWith(clearSuspension: true);
    }).toList();
  }
}

final adminUsersProvider =
    StateNotifierProvider<AdminUsersNotifier, List<UserModel>>((ref) {
  final notifier = AdminUsersNotifier();
  ref.listen<AsyncValue<List<UserModel>>>(
    firestoreUsersStreamProvider,
    (_, next) => next.whenData((users) => notifier.setUsers(users)),
    fireImmediately: true,
  );
  return notifier;
});

// ─── Blocked Users ────────────────────────────────────────────────────────────
// Derived live from the Firestore-backed adminUsersProvider list (was
// previously a bare local StateProvider<Set<String>> that Block/Unblock only
// ever mutated in memory — never persisted, reset to empty on every app
// restart, and invisible to the blocked user's own session). Keeping the
// same name/Set<String> shape means every existing read site (tab
// filtering, card styling, dashboard badge count) keeps working unchanged.
final blockedUsersProvider = Provider<Set<String>>((ref) {
  return ref
      .watch(adminUsersProvider)
      .where((u) => u.isBlocked)
      .map((u) => u.id)
      .toSet();
});

// ─── Categories ───────────────────────────────────────────────────────────────
class AdminCategoriesNotifier extends StateNotifier<List<CategoryModel>> {
  AdminCategoriesNotifier() : super([]);

  void sync(List<CategoryModel> cats) => state = cats;

  Future<void> addCategory(CategoryModel cat) async {
    final id = cat.id.isNotEmpty
        ? cat.id
        : cat.nameKey.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    await FirebaseFirestore.instance
        .collection('categories')
        .doc(id)
        .set(cat.toMap());
  }

  Future<void> updateCategory(CategoryModel updated) async {
    await FirebaseFirestore.instance
        .collection('categories')
        .doc(updated.id)
        .update(updated.toMap());
  }

  Future<void> deleteCategory(String id) async {
    await FirebaseFirestore.instance.collection('categories').doc(id).delete();
  }
}

final adminCategoriesProvider =
    StateNotifierProvider<AdminCategoriesNotifier, List<CategoryModel>>((ref) {
  final notifier = AdminCategoriesNotifier();
  ref.listen<AsyncValue<List<CategoryModel>>>(
    categoriesProvider,
    (_, next) => next.whenData((cats) => notifier.sync(cats)),
    fireImmediately: true,
  );
  return notifier;
});

// ─── Complaints (Firestore) ────────────────────────────────────────────────────
// Admin Complaints Center reads all non-deleted complaints from Firestore.
final adminComplaintsProvider = Provider<List<ComplaintModel>>((ref) {
  return ref.watch(allComplaintsProvider).valueOrNull ??
      const <ComplaintModel>[];
});

// ─── Broadcast Messages ───────────────────────────────────────────────────────
enum BroadcastTarget { all, customers, professionals, contractors }

class BroadcastMessage {
  final String id;
  final String text;

  /// Every audience this broadcast was sent to. A broadcast used to carry
  /// exactly one target; it can now carry several (e.g. Customers +
  /// Professionals). Always normalized — see [normalizeBroadcastTargets] —
  /// so it is either the single [BroadcastTarget.all] or one or more
  /// specific roles, never both.
  final Set<BroadcastTarget> targets;
  final DateTime createdAt;
  final String sender;

  const BroadcastMessage({
    required this.id,
    required this.text,
    required this.targets,
    required this.createdAt,
    required this.sender,
  });

  /// Back-compat accessor for the pre-multi-select single-target model:
  /// reports [BroadcastTarget.all] for an everyone broadcast, otherwise the
  /// first selected role.
  BroadcastTarget get target => targets.contains(BroadcastTarget.all)
      ? BroadcastTarget.all
      : (targets.isEmpty ? BroadcastTarget.all : targets.first);
}

class BroadcastNotifier extends StateNotifier<List<BroadcastMessage>> {
  BroadcastNotifier() : super([]);

  void send(String text, Set<BroadcastTarget> targets,
      {String senderName = 'System Admin'}) {
    state = [
      BroadcastMessage(
        id: 'bc_${DateTime.now().millisecondsSinceEpoch}',
        text: text,
        targets: normalizeBroadcastTargets(targets),
        createdAt: DateTime.now(),
        sender: senderName,
      ),
      ...state,
    ];
  }
}

/// Collapses a raw multi-select into the canonical audience set.
///
/// "All Users" already means everyone, so it can never sensibly coexist with
/// an individual group — if it is present the result is exactly
/// {[BroadcastTarget.all]}. Selecting all three individual groups is likewise
/// everyone, so it collapses to "All Users" too, which keeps delivery to one
/// notification document instead of three equivalent ones.
Set<BroadcastTarget> normalizeBroadcastTargets(Set<BroadcastTarget> raw) {
  if (raw.contains(BroadcastTarget.all)) return {BroadcastTarget.all};
  final specific = raw.where((t) => t != BroadcastTarget.all).toSet();
  if (specific.length >= 3) return {BroadcastTarget.all};
  return specific;
}

// Maps the admin's local broadcast-target choice to the Firestore
// NotificationModel.targetRole string used by sendBroadcastNotificationInFirestore.
String broadcastTargetToRoleString(BroadcastTarget t) {
  switch (t) {
    case BroadcastTarget.all:
      return 'all';
    case BroadcastTarget.customers:
      return 'customer';
    case BroadcastTarget.professionals:
      return 'professional';
    case BroadcastTarget.contractors:
      return 'contractor';
  }
}

/// The distinct Firestore `targetRole` strings a multi-audience broadcast
/// must be written for. Normalizing first is what guarantees no user can be
/// reached twice: a user has exactly one role, and each role appears at most
/// once here (and 'all' is never mixed with a specific role).
List<String> broadcastTargetsToRoleStrings(Set<BroadcastTarget> targets) =>
    normalizeBroadcastTargets(targets)
        .map(broadcastTargetToRoleString)
        .toSet()
        .toList();

final broadcastProvider =
    StateNotifierProvider<BroadcastNotifier, List<BroadcastMessage>>(
  (ref) => BroadcastNotifier(),
);

// ─── Category Requests ────────────────────────────────────────────────────────
enum CategoryRequestStatus { pending, approved, rejected }

class CategoryRequest {
  final String id;
  final String categoryName;
  final String requestedByUserId;
  final String requestedByUserName;
  final UserRole requestedByRole;
  final String? message;
  final DateTime createdAt;
  CategoryRequestStatus status;
  bool isRead;

  CategoryRequest({
    required this.id,
    required this.categoryName,
    required this.requestedByUserId,
    required this.requestedByUserName,
    required this.requestedByRole,
    this.message,
    required this.createdAt,
    this.status = CategoryRequestStatus.pending,
    this.isRead = false,
  });
}

// ─── Firestore Category Requests Stream ──────────────────────────────────────
final firestoreCategoryRequestsStreamProvider =
    StreamProvider<List<CategoryRequestModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('category_requests')
      .snapshots()
      .map((snap) {
    final list = snap.docs
        .map((d) => CategoryRequestModel.fromMap(d.data(), id: d.id))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  });
});

class CategoryRequestsNotifier extends StateNotifier<List<CategoryRequest>> {
  CategoryRequestsNotifier() : super([]);

  static UserRole _roleFromStr(String s) {
    if (s == 'professional') return UserRole.professional;
    if (s == 'contractor') return UserRole.contractor;
    return UserRole.customer;
  }

  void setFromFirestore(List<CategoryRequestModel> items) {
    state = items
        .map((r) => CategoryRequest(
              id: r.id,
              categoryName: r.requestedName,
              requestedByUserId: r.requesterId,
              requestedByUserName: r.requesterName,
              requestedByRole: _roleFromStr(r.requesterRole),
              message: r.requestedDescription.isEmpty
                  ? null
                  : r.requestedDescription,
              createdAt: r.createdAt,
              status: r.status == 'approved'
                  ? CategoryRequestStatus.approved
                  : r.status == 'rejected'
                      ? CategoryRequestStatus.rejected
                      : CategoryRequestStatus.pending,
              isRead: r.status != 'pending',
            ))
        .toList();
  }

  void addRequest(CategoryRequest req) => state = [req, ...state];

  Future<void> approveInFirestore(String id,
      {CategoryModel? newCategory}) async {
    // Category creation + request approval must succeed or fail together —
    // a single WriteBatch commit, so a failed write never leaves the
    // category created with the request still Pending (or vice versa).
    final batch = FirebaseFirestore.instance.batch();
    if (newCategory != null) {
      final catId = newCategory.nameKey
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_');
      batch.set(FirebaseFirestore.instance.collection('categories').doc(catId),
          newCategory.toMap());
    }
    batch.update(
        FirebaseFirestore.instance.collection('category_requests').doc(id), {
      'status': 'approved',
      'reviewedAt': DateTime.now().toIso8601String(),
      'reviewedBy': 'Admin',
    });
    await batch.commit();
  }

  Future<void> rejectInFirestore(String id) async {
    await FirebaseFirestore.instance
        .collection('category_requests')
        .doc(id)
        .update({
      'status': 'rejected',
      'reviewedAt': DateTime.now().toIso8601String(),
      'reviewedBy': 'Admin',
    });
  }

  void approve(String id) {
    state = state
        .map((r) =>
            r.id == id ? (r..status = CategoryRequestStatus.approved) : r)
        .toList();
  }

  void reject(String id) {
    state = state
        .map((r) =>
            r.id == id ? (r..status = CategoryRequestStatus.rejected) : r)
        .toList();
  }

  void markRead(String id) {
    state = state.map((r) => r.id == id ? (r..isRead = true) : r).toList();
  }

  void markAllRead() {
    state = state.map((r) => r..isRead = true).toList();
  }

  int get unreadCount => state
      .where((r) => !r.isRead && r.status == CategoryRequestStatus.pending)
      .length;
}

final categoryRequestsProvider =
    StateNotifierProvider<CategoryRequestsNotifier, List<CategoryRequest>>(
        (ref) {
  final notifier = CategoryRequestsNotifier();
  ref.listen<AsyncValue<List<CategoryRequestModel>>>(
    firestoreCategoryRequestsStreamProvider,
    (_, next) => next.whenData((items) => notifier.setFromFirestore(items)),
    fireImmediately: true,
  );
  return notifier;
});

final categoryRequestsUnreadProvider = Provider<int>((ref) {
  return ref.watch(categoryRequestsProvider.notifier).unreadCount;
});

// Tracks category-request IDs currently being approved/rejected, so a fast
// repeat tap on the same request (before the Firestore round-trip rebuilds
// the dialog and hides its buttons) is a no-op instead of writing the status
// twice and creating a second decision notification.
final categoryRequestActionInFlightProvider =
    StateProvider<Set<String>>((ref) => <String>{});

// ─── Notifications (Firestore) ────────────────────────────────────────────────
// Admin Notifications Sheet reads real notifications from Firestore via
// userNotificationsProvider (userId == admin id OR targetRole == admin/all).
final adminUnreadCountProvider = Provider<int>((ref) {
  final admin = ref.watch(authProvider);
  final catRequests = ref.watch(categoryRequestsProvider);
  final notifUnread = admin == null
      ? 0
      : ref.watch(unreadNotificationsCountProvider(
          (userId: admin.id, role: UserRole.admin)));
  final catUnread = catRequests
      .where((r) => !r.isRead && r.status == CategoryRequestStatus.pending)
      .length;
  // chat requests counted separately via adminChatRequestsProvider in chat_admin_provider
  return notifUnread + catUnread;
});
