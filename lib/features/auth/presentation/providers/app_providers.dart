import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:collection/collection.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/models/dummy_data.dart';
import 'dart:typed_data';

// ─── Auth Provider ────────────────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<UserModel?> {
  AuthNotifier() : super(null);

  bool get isLoggedIn => state != null;

  // True for the entire duration of this tab's own login()/register()/
  // logout() call — i.e. while THIS notifier is itself driving a Firebase
  // Auth transition end-to-end. authIdentitySyncProvider (below) must never
  // race ahead of that in-flight call and treat a not-yet-created
  // (register) or not-yet-read (login) users/{uid} document as a missing
  // profile, and _HomeRouter (main.dart) must keep rendering this
  // notifier's own state instead of blocking on the raw Firebase-Auth-UID
  // comparison while it's still catching up to what this call already
  // knows is correct.
  bool _selfManagingTransition = false;
  bool get isSelfManagingTransition => _selfManagingTransition;

  // Throws FirebaseAuthException on bad credentials, Exception if profile missing.
  Future<void> login(String email, String password) async {
    _selfManagingTransition = true;
    try {
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final uid = credential.user!.uid;
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!doc.exists || doc.data() == null) {
        await FirebaseAuth.instance.signOut();
        throw Exception('User profile not found. Please contact support.');
      }

      state = UserModel.fromMap(doc.data()!, id: uid);
    } finally {
      _selfManagingTransition = false;
    }
  }

  // Throws FirebaseAuthException on duplicate email / weak password.
  Future<void> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required UserRole role,
    String? workArea,
    int? experienceYears,
    String? specialty,
    List<String>? specialties,
    String? description,
    String? companyName,
    String? city,
    String? streetNumber,
  }) async {
    _selfManagingTransition = true;
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final uid = credential.user!.uid;
      final user = UserModel(
        id: uid,
        fullName: fullName,
        email: email,
        phone: phone,
        city: city ?? workArea ?? '',
        role: role,
        companyName: companyName,
        streetNumber: streetNumber ?? '',
        workArea: workArea,
        experienceYears: experienceYears,
        specialty: specialty,
        specialties: specialties ?? (specialty != null ? [specialty] : []),
        serviceDescription: description,
        rating: 0,
        totalJobs: 0,
        joinDate: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(user.toMap());

      state = user;
    } finally {
      _selfManagingTransition = false;
    }
  }

  void updateProfile(UserModel updated) => state = updated;

  // Used only by authIdentitySyncProvider to bring this notifier back in
  // line with the real signed-in Firebase Auth identity (e.g. another
  // browser tab signed in as a different account, or the session signed
  // out) — never called directly from a UI action.
  void setSyncedUser(UserModel user) => state = user;
  void clearSyncedUser() => state = null;

  Future<void> updateCustomerProfile(UserModel updated) async {
    state = updated;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(updated.id)
        .update({
      'fullName': updated.fullName,
      'email': updated.email,
      'phone': updated.phone,
      'city': updated.city,
      'streetNumber': updated.streetNumber,
      'languages': updated.languages,
      'preferredContactHours': updated.preferredContactHours,
      'favoriteServices': updated.favoriteServices,
    });
  }

  // Professional's only editable location value is workArea (there is no
  // separate "city" field in that screen) — AI Assistant "Same city as me"
  // reads UserModel.city, so city is kept synchronized to workArea here,
  // once, right before both the local state and the Firestore write, so
  // neither can ever observe the stale pre-edit city while workArea has
  // already moved on. A blank/whitespace-only workArea leaves the existing
  // city untouched rather than erasing it.
  Future<void> updateProfessionalProfile(UserModel updated) async {
    final trimmedWorkArea = updated.workArea?.trim() ?? '';
    final effectiveCity =
        trimmedWorkArea.isNotEmpty ? trimmedWorkArea : updated.city.trim();
    final normalized = updated.copyWith(city: effectiveCity);
    state = normalized;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(normalized.id)
        .update({
      'fullName': normalized.fullName,
      'email': normalized.email,
      'phone': normalized.phone,
      'workArea': normalized.workArea,
      'city': normalized.city,
      'experienceYears': normalized.experienceYears,
      'serviceDescription': normalized.serviceDescription,
      'languages': normalized.languages,
      'workingDays': normalized.workingDays,
      'workStartTime': normalized.workStartTime,
      'workEndTime': normalized.workEndTime,
    });
  }

  // Same workArea-to-city synchronization as updateProfessionalProfile
  // above, and for the same reason — Contractor's only editable location
  // value is also workArea.
  Future<void> updateContractorProfile(UserModel updated) async {
    final trimmedWorkArea = updated.workArea?.trim() ?? '';
    final effectiveCity =
        trimmedWorkArea.isNotEmpty ? trimmedWorkArea : updated.city.trim();
    final normalized = updated.copyWith(city: effectiveCity);
    state = normalized;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(normalized.id)
        .update({
      'fullName': normalized.fullName,
      'email': normalized.email,
      'phone': normalized.phone,
      'workArea': normalized.workArea,
      'city': normalized.city,
      'companyName': normalized.companyName,
      'experienceYears': normalized.experienceYears,
      'serviceDescription': normalized.serviceDescription,
      'languages': normalized.languages,
      'workingDays': normalized.workingDays,
      'workStartTime': normalized.workStartTime,
      'workEndTime': normalized.workEndTime,
    });
  }

  Future<void> saveServicesList(UserModel updated) async {
    state = updated;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(updated.id)
        .update({
      'servicesList': updated.servicesList.map((s) => s.toMap()).toList(),
    });
  }

  Future<void> saveSpecialties(List<String> specialties) async {
    if (state == null) return;
    final updated = state!.copyWith(
      specialties: specialties,
      specialty: specialties.isNotEmpty ? specialties.first : null,
    );
    state = updated;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(updated.id)
        .update({
      'specialties': specialties,
      'specialty': specialties.isNotEmpty ? specialties.first : null,
    });
  }

  Future<void> logout() async {
    _selfManagingTransition = true;
    try {
      await FirebaseAuth.instance.signOut();
      state = null;
    } finally {
      _selfManagingTransition = false;
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, UserModel?>(
  (ref) => AuthNotifier(),
);

// Reactive source of truth for "is Firebase Auth actually ready, and with
// which uid". Firestore security rules are evaluated against FirebaseAuth's
// own current user/ID token, not our app-level authProvider snapshot — a
// Firestore listener started while this is null gets permission-denied and,
// per the SDK, terminates for good. Chat Firestore streams (conversation /
// messages / quick replies) watch this instead of a one-time currentUser
// check so they both wait for auth on first load AND automatically
// resubscribe after any transient auth gap (token refresh, multi-tab auth
// persistence sync) instead of staying stuck in a dead permission-denied
// state. See conversationByIdProvider, messagesForConversationProvider and
// quickRepliesProvider below.
final firebaseAuthUidProvider = StreamProvider<String?>((ref) {
  return FirebaseAuth.instance.authStateChanges().map((u) => u?.uid);
});

// Central Firebase-Auth → authProvider synchronization. FirebaseAuth is the
// authoritative identity; this keeps authProvider from ever silently
// diverging from it — most importantly across browser tabs, where Firebase
// Auth Web's persisted session is shared per browser origin: signing in as
// a different account in another tab changes FirebaseAuth.instance.
// currentUser in THIS tab too, even though nothing here called login().
// Watched once from the app root (see main.dart's _HomeRouter) so it stays
// alive for as long as any screen is shown.
//
//  - real uid null               -> authProvider cleared to null.
//  - real uid == authProvider.id -> already in sync, no Firestore read.
//  - real uid != authProvider.id -> re-fetch users/{realUid} and adopt it,
//    or, if that profile doesn't exist, sign out and clear (the same
//    missing-profile handling login() already uses — never guesses a role).
//
// Skipped entirely while this tab's own login()/register()/logout() is
// itself in flight (AuthNotifier.isSelfManagingTransition) so it can never
// race a not-yet-created/not-yet-read profile document.
final authIdentitySyncProvider = StreamProvider<void>((ref) async* {
  await for (final firebaseUser in FirebaseAuth.instance.authStateChanges()) {
    final notifier = ref.read(authProvider.notifier);
    if (notifier.isSelfManagingTransition) {
      yield null;
      continue;
    }

    final realUid = firebaseUser?.uid;
    final localId = ref.read(authProvider)?.id;
    if (realUid == localId) {
      yield null;
      continue;
    }

    if (realUid == null) {
      notifier.clearSyncedUser();
      yield null;
      continue;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(realUid)
          .get();
      // A login()/register() call may have started — and already resolved
      // this exact transition itself — while this read was in flight; never
      // clobber it with a redundant/late write.
      if (notifier.isSelfManagingTransition) {
        yield null;
        continue;
      }
      if (!doc.exists || doc.data() == null) {
        await FirebaseAuth.instance.signOut();
        notifier.clearSyncedUser();
      } else {
        notifier.setSyncedUser(UserModel.fromMap(doc.data()!, id: doc.id));
      }
    } catch (e) {
      // A transient network/Firestore failure here is not proof the profile
      // is missing — signing out or clearing the last known-valid UserModel
      // on a mere fetch error would log a legitimately authenticated user
      // out over a blip. Leave authProvider and the Firebase Auth session
      // untouched: realUid != localId still holds, so _HomeRouter's
      // mismatch gate keeps any stale role screen non-interactive, and the
      // next authStateChanges event (or a future provider rebuild) gets
      // another attempt — never guessing a role in the meantime.
      debugPrint('AUTH_IDENTITY_SYNC_FETCH_ERROR uid=$realUid: $e');
    }
    yield null;
  }
});

// ─── Profile Photo — Firebase Storage + Firestore (shared: Customer /
// Professional / Contractor) ────────────────────────────────────────────────
// Single field, single flow, reused by all three roles: UserModel.avatar /
// users/{uid}.avatar (String? download URL). Do not add a role-specific
// field — see UserModel.avatar in models.dart.

// Defensive ownership check run before ever deleting a Storage object: only
// ever delete a file that resolves to this exact user's own
// profile_images/{uid}/ folder — never trust name/email, never touch another
// user's file or a different feature's folder (chat_images, order images).
bool _isOwnProfileImageStoragePath(String url, String uid) {
  try {
    final path = FirebaseStorage.instance.refFromURL(url).fullPath;
    return path.startsWith('profile_images/$uid/');
  } catch (_) {
    // Not a resolvable Storage URL (e.g. a non-Storage/default image) —
    // never safe to delete.
    return false;
  }
}

// Uploads [bytes] to this user's own profile_images/{uid}/ folder, then
// updates users/{uid}.avatar and only returns once that Firestore write is
// confirmed — callers must not show success before this completes. Only
// after Firestore succeeds does this best-effort delete [previousAvatarUrl]
// (if it safely resolves to this same user's own folder); a cleanup failure
// is logged and swallowed — the new photo stays active either way.
Future<String> uploadProfilePhoto({
  required String uid,
  required Uint8List bytes,
  required String fileName,
  String? previousAvatarUrl,
}) async {
  final lowerName = fileName.toLowerCase();
  final ext = lowerName.endsWith('.png')
      ? 'png'
      : lowerName.endsWith('.webp')
          ? 'webp'
          : 'jpg';
  final contentType = ext == 'png'
      ? 'image/png'
      : ext == 'webp'
          ? 'image/webp'
          : 'image/jpeg';

  final storagePath =
      'profile_images/$uid/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
  final storageRef = FirebaseStorage.instance.ref().child(storagePath);

  try {
    await storageRef.putData(bytes, SettableMetadata(contentType: contentType));
    final downloadUrl = await storageRef.getDownloadURL();

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'avatar': downloadUrl,
    });

    if (previousAvatarUrl != null &&
        previousAvatarUrl.isNotEmpty &&
        previousAvatarUrl != downloadUrl &&
        _isOwnProfileImageStoragePath(previousAvatarUrl, uid)) {
      try {
        await FirebaseStorage.instance.refFromURL(previousAvatarUrl).delete();
      } catch (e) {
        debugPrint('PROFILE_PHOTO_OLD_FILE_CLEANUP_ERROR uid=$uid: $e');
      }
    }

    return downloadUrl;
  } catch (e) {
    debugPrint('PROFILE_PHOTO_UPLOAD_ERROR uid=$uid: $e');
    rethrow;
  }
}

// Clears users/{uid}.avatar (FieldValue.delete() — UserModel.fromMap already
// treats a missing 'avatar' key as null) and only returns once that write is
// confirmed. Only after Firestore succeeds does this best-effort delete the
// Storage object it pointed to (if it safely resolves to this user's own
// folder) — a cleanup failure is logged and swallowed; the field stays
// cleared either way (no rollback, no re-linking the old URL).
Future<void> removeProfilePhoto({
  required String uid,
  required String? currentAvatarUrl,
}) async {
  try {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'avatar': FieldValue.delete(),
    });
  } catch (e) {
    debugPrint('PROFILE_PHOTO_REMOVE_ERROR uid=$uid: $e');
    rethrow;
  }

  if (currentAvatarUrl != null &&
      currentAvatarUrl.isNotEmpty &&
      _isOwnProfileImageStoragePath(currentAvatarUrl, uid)) {
    try {
      await FirebaseStorage.instance.refFromURL(currentAvatarUrl).delete();
    } catch (e) {
      debugPrint('PROFILE_PHOTO_REMOVE_CLEANUP_ERROR uid=$uid: $e');
    }
  }
}

// Streams the signed-in user's own Firestore document so profile screens see
// out-of-band updates (e.g. an Admin editing this user via Admin Users)
// without requiring a re-login. authProvider itself is a plain in-memory
// snapshot that's only mutated by this session's own actions (login,
// self-edit), so it goes stale the moment another actor changes the
// document. Callers should fall back to authProvider while this is loading,
// e.g. `ref.watch(liveCurrentUserProvider).valueOrNull ?? ref.watch(authProvider)`.
final liveCurrentUserProvider = StreamProvider<UserModel?>((ref) {
  final authUser = ref.watch(authProvider);
  if (authUser == null) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(authUser.id)
      .snapshots()
      .map((doc) => doc.exists && doc.data() != null
          ? UserModel.fromMap(doc.data()!, id: doc.id)
          : authUser);
});

// Reads any single user's Firestore document live by stable UID — used e.g.
// by Order Details (Professional/Contractor) to show the real Customer
// profile behind an order instead of just the name/area copied onto it.
// A malformed doc resolves to null (treated as "profile unavailable") rather
// than throwing, so one bad document can't crash the caller's UI.
final userByIdProvider = StreamProvider.family<UserModel?, String>((ref, uid) {
  if (uid.isEmpty) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) {
    if (!doc.exists || doc.data() == null) return null;
    try {
      return UserModel.fromMap(doc.data()!, id: doc.id);
    } catch (e, st) {
      debugPrint('BAD_USER_DOC [userByIdProvider] $uid: $e');
      debugPrint('BAD_USER_DOC_STACK [userByIdProvider]: $st');
      return null;
    }
  });
});

// ─── Providers List ───────────────────────────────────────────────────────────
final providersProvider =
    StateProvider<List<UserModel>>((ref) => DummyData.providers);

final filteredProvidersProvider =
    Provider.family<List<UserModel>, String>((ref, query) {
  final List<UserModel> all = ref.watch(providersProvider);
  if (query.isEmpty) return all;
  return all
      .where((UserModel p) =>
          p.fullName.toLowerCase().contains(query.toLowerCase()) ||
          (p.specialty?.toLowerCase().contains(query.toLowerCase()) ?? false))
      .toList();
});

final providersByCategoryProvider =
    Provider.family<List<UserModel>, String>((ref, categoryKey) {
  final List<UserModel> all = ref.watch(providersProvider);
  return all.where((UserModel p) => p.specialty == categoryKey).toList();
});

// Reads ALL users from Firestore and filters client-side.
// Avoids composite Firestore index requirements and permission issues.
// Param is (nameKey, categoryId) — both are matched against user.specialties (normalised).
final categoryProvidersStreamProvider =
    StreamProvider.family<List<UserModel>, (String, String)>((ref, param) {
  final (nameKey, categoryId) = param;
  final normName = nameKey.trim().toLowerCase();
  final normId = categoryId.trim().toLowerCase();

  return FirebaseFirestore.instance.collection('users').snapshots().map((snap) {
    final result = <UserModel>[];
    for (final doc in snap.docs) {
      UserModel u;
      try {
        u = UserModel.fromMap(doc.data(), id: doc.id);
      } catch (e) {
        debugPrint('[categoryProviders] parse error for ${doc.id}: $e');
        continue;
      }
      if (u.role != UserRole.professional && u.role != UserRole.contractor) {
        continue;
      }
      // A soft-deleted (deactivated) provider must not be discoverable for
      // new work — old orders/reviews/chats that already reference them are
      // untouched, this only excludes them from new-provider discovery.
      if (u.isDeleted) continue;
      // Check specialties list (normalised)
      final matched = u.specialties.any((s) {
        final ns = s.trim().toLowerCase();
        return ns == normName || (normId.isNotEmpty && ns == normId);
      });
      if (matched) {
        result.add(u);
        continue;
      }
      // Backward compat: legacy single specialty field when list is empty
      if (u.specialties.isEmpty && u.specialty != null) {
        final ns = u.specialty!.trim().toLowerCase();
        if (ns == normName || (normId.isNotEmpty && ns == normId)) {
          result.add(u);
        }
      }
    }
    return result;
  });
});

// Reads ALL users from Firestore and filters client-side to professionals and
// contractors only. Used for the customer Home "Featured Providers" section
// and the full Featured Providers screen.
final featuredProvidersProvider = StreamProvider<List<UserModel>>((ref) {
  return FirebaseFirestore.instance.collection('users').snapshots().map((snap) {
    final result = <UserModel>[];
    for (final doc in snap.docs) {
      UserModel u;
      try {
        u = UserModel.fromMap(doc.data(), id: doc.id);
      } catch (e) {
        debugPrint('[featuredProviders] parse error for ${doc.id}: $e');
        continue;
      }
      // Exclude soft-deleted (deactivated) providers from discovery — see
      // categoryProvidersStreamProvider above for the same reasoning.
      if ((u.role == UserRole.professional || u.role == UserRole.contractor) &&
          !u.isDeleted) {
        result.add(u);
      }
    }
    return result;
  });
});

// ─── Categories Provider ──────────────────────────────────────────────────────
// Reads from Firestore, filters inactive categories (isActive == false),
// and sorts by 'order' field ascending then alphabetically by nameKey.
final categoriesProvider = StreamProvider<List<CategoryModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('categories')
      .snapshots()
      .map((snap) {
    final cats = snap.docs
        .map((d) => CategoryModel.fromMap(d.data(), id: d.id))
        .where((c) => c.isActive)
        .toList();
    cats.sort((a, b) {
      if (a.order != null && b.order != null)
        return a.order!.compareTo(b.order!);
      if (a.order != null) return -1;
      if (b.order != null) return 1;
      return a.nameKey.compareTo(b.nameKey);
    });
    return cats;
  });
});

// ─── Customer Category Requests (Firestore) ───────────────────────────────────
// Requests submitted by the currently authenticated customer only, matched by
// the exact ownership field the request form writes (`requesterId` — see
// showCategoryRequestSheet in category_request_sheet.dart). Mirrors the same
// malformed-doc-safe pattern as customerFirestoreOrdersProvider: a bad
// document is skipped rather than allowed to crash the whole stream.
final customerCategoryRequestsProvider =
    StreamProvider<List<CategoryRequestModel>>((ref) {
  final user = ref.watch(authProvider);
  if (user == null) return Stream.value(const <CategoryRequestModel>[]);
  return FirebaseFirestore.instance
      .collection('category_requests')
      .where('requesterId', isEqualTo: user.id)
      .snapshots()
      .handleError((Object e, StackTrace st) {
    debugPrint('CATEGORY_REQUESTS_LOAD_ERROR [customer]: $e');
    debugPrint('CATEGORY_REQUESTS_LOAD_STACK [customer]: $st');
    throw e;
  }).map((snap) {
    final list = <CategoryRequestModel>[];
    for (final doc in snap.docs) {
      try {
        list.add(CategoryRequestModel.fromMap(doc.data(), id: doc.id));
      } catch (e, st) {
        debugPrint('BAD_CATEGORY_REQUEST_DOC [customer] ${doc.id}: $e');
        debugPrint('BAD_CATEGORY_REQUEST_DOC_STACK [customer]: $st');
        // Skip malformed doc — must not crash the whole requests list.
      }
    }
    try {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e, st) {
      debugPrint('CATEGORY_REQUESTS_SORT_ERROR [customer]: $e');
      debugPrint('CATEGORY_REQUESTS_SORT_STACK [customer]: $st');
    }
    return list;
  });
});

// Only the two customer-editable fields are touched; requesterId,
// requesterName, requesterRole, status and createdAt are left untouched.
Future<void> updateCategoryRequestInFirestore({
  required String requestId,
  required String requestedName,
  required String requestedDescription,
}) async {
  await FirebaseFirestore.instance
      .collection('category_requests')
      .doc(requestId)
      .update({
    'requestedName': requestedName,
    'requestedDescription': requestedDescription,
  });
}

// Real document delete (not a soft-delete flag), matching the requirement
// that a customer can only remove their own still-Pending request.
Future<void> deleteCategoryRequestInFirestore(String requestId) async {
  await FirebaseFirestore.instance
      .collection('category_requests')
      .doc(requestId)
      .delete();
}

// ─── Orders Provider ──────────────────────────────────────────────────────────
class OrdersNotifier extends StateNotifier<List<OrderModel>> {
  OrdersNotifier() : super(DummyData.orders);

  void addOrder(OrderModel order) => state = [...state, order];

  Future<void> createOrderInFirestore(OrderModel order) =>
      FirebaseFirestore.instance
          .collection('orders')
          .doc(order.id)
          .set(order.toMap());

  void updateStatus(String orderId, OrderStatus status) {
    state = state
        .map((OrderModel o) => o.id == orderId ? o.copyWith(status: status) : o)
        .toList();
  }

  void updateOrder(OrderModel updated) {
    state = state.map((o) => o.id == updated.id ? updated : o).toList();
  }

  void cancelOrder(String orderId, String reason) {
    state = state
        .map((o) => o.id == orderId
            ? o.copyWith(status: OrderStatus.cancelled, rejectReason: reason)
            : o)
        .toList();
  }

  void deleteOrder(String orderId) {
    state = state.where((o) => o.id != orderId).toList();
  }

  // Selected-service fields are only ever written when serviceSelectionChanged
  // is true (the Customer actively toggled a service in Edit Order's Selected
  // Services section) — otherwise they're simply omitted from this partial
  // .update() call, so an untouched (including unmatched-legacy) selection is
  // never overwritten just by editing other order fields. When touched:
  //  - selectedServices is written as full ServiceModel.toMap() snapshots, or
  //    deleted when the Customer removed every service.
  //  - selectedServiceName/selectedServicePrice are written/deleted together.
  //  - selectedServiceId is written only for exactly one selected service and
  //    explicitly deleted otherwise (0 or 2+ selected), so a stale single-id
  //    never survives a switch to a multi-service selection.
  Future<void> updateCustomerOrderInFirestore(
    OrderModel order, {
    bool serviceSelectionChanged = false,
    List<ServiceModel> selectedServices = const [],
    String? selectedServiceName,
    double? selectedServicePrice,
    String? selectedServiceId,
  }) {
    final now = DateTime.now();
    final data = <String, Object?>{
      'title': order.title,
      'description': order.description,
      'area': order.area,
      'serviceDate': order.serviceDate.toIso8601String(),
      'priority': order.priority == OrderPriority.urgent ? 'urgent' : 'normal',
      'updatedAt': now.toIso8601String(),
    };
    if (serviceSelectionChanged) {
      data['selectedServices'] = selectedServices.isNotEmpty
          ? selectedServices.map((s) => s.toMap()).toList()
          : FieldValue.delete();
      data['selectedServiceName'] =
          (selectedServiceName != null && selectedServiceName.isNotEmpty)
              ? selectedServiceName
              : FieldValue.delete();
      data['selectedServicePrice'] =
          selectedServicePrice ?? FieldValue.delete();
      data['selectedServiceId'] =
          (selectedServiceId != null && selectedServiceId.isNotEmpty)
              ? selectedServiceId
              : FieldValue.delete();
    }
    return FirebaseFirestore.instance
        .collection('orders')
        .doc(order.id)
        .update(data);
  }

  // Overwrites imageUrls with a single new image — used for both "no photo
  // yet" and "replace the current photo". The order's previous Storage
  // object (if any) is intentionally left in place: there is no existing
  // safe-delete helper for order images, and blindly deleting by a
  // reconstructed path risks removing a file that isn't actually orphaned.
  Future<void> replaceOrderImageInFirestore({
    required String orderId,
    required String imageUrl,
  }) {
    return FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'imageUrls': [imageUrl],
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  // Appends via arrayUnion (not a read-modify-write of the local imageUrls
  // list) so a concurrent update elsewhere can never be silently dropped.
  Future<void> appendOrderImageInFirestore({
    required String orderId,
    required String imageUrl,
  }) {
    return FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'imageUrls': FieldValue.arrayUnion([imageUrl]),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  // Removes exactly one URL via arrayRemove (not a read-modify-write of the
  // local imageUrls list) so a concurrent add/remove elsewhere can never be
  // silently clobbered, and only the exact matching URL is ever dropped.
  Future<void> removeOrderImageInFirestore({
    required String orderId,
    required String imageUrl,
  }) {
    return FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'imageUrls': FieldValue.arrayRemove([imageUrl]),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> cancelCustomerOrderInFirestore({
    required String orderId,
    String? reason,
  }) {
    final now = DateTime.now();
    return FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'status': 'cancelled',
      'updatedAt': now.toIso8601String(),
      'cancelledBy': 'customer',
      'cancelledAt': now.toIso8601String(),
      if (reason != null && reason.isNotEmpty) 'cancelReason': reason,
    });
  }

  Future<void> acceptProfessionalOrderInFirestore(String orderId) {
    final now = DateTime.now();
    return FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'status': 'inProgress',
      'updatedAt': now.toIso8601String(),
      'acceptedBy': 'professional',
      'acceptedAt': now.toIso8601String(),
    });
  }

  Future<void> completeProfessionalOrderInFirestore(String orderId) {
    final now = DateTime.now();
    return FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'status': 'completed',
      'updatedAt': now.toIso8601String(),
      'completedBy': 'professional',
      'completedAt': now.toIso8601String(),
    });
  }

  Future<void> rejectProfessionalOrderInFirestore({
    required String orderId,
    String? reason,
  }) {
    final now = DateTime.now();
    return FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'status': 'cancelled',
      'updatedAt': now.toIso8601String(),
      'cancelledBy': 'professional',
      'cancelledAt': now.toIso8601String(),
      if (reason != null && reason.isNotEmpty) 'rejectReason': reason,
      if (reason != null && reason.isNotEmpty) 'cancelReason': reason,
    });
  }

  Future<void> acceptContractorOrderInFirestore(String orderId) {
    final now = DateTime.now();
    return FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'status': 'inProgress',
      'updatedAt': now.toIso8601String(),
      'acceptedBy': 'contractor',
      'acceptedAt': now.toIso8601String(),
    });
  }

  Future<void> completeContractorOrderInFirestore(String orderId) {
    final now = DateTime.now();
    return FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'status': 'completed',
      'updatedAt': now.toIso8601String(),
      'completedBy': 'contractor',
      'completedAt': now.toIso8601String(),
    });
  }

  Future<void> rejectContractorOrderInFirestore({
    required String orderId,
    String? reason,
  }) {
    final now = DateTime.now();
    return FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'status': 'cancelled',
      'updatedAt': now.toIso8601String(),
      'cancelledBy': 'contractor',
      'cancelledAt': now.toIso8601String(),
      if (reason != null && reason.isNotEmpty) 'rejectReason': reason,
      if (reason != null && reason.isNotEmpty) 'cancelReason': reason,
    });
  }

  Future<void> approveAdminOrderInFirestore(String orderId) {
    final now = DateTime.now();
    return FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'status': 'inProgress',
      'updatedAt': now.toIso8601String(),
      'acceptedBy': 'admin',
      'acceptedAt': now.toIso8601String(),
    });
  }

  Future<void> completeAdminOrderInFirestore(String orderId) {
    final now = DateTime.now();
    return FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'status': 'completed',
      'updatedAt': now.toIso8601String(),
      'completedBy': 'admin',
      'completedAt': now.toIso8601String(),
    });
  }

  Future<void> cancelAdminOrderInFirestore({
    required String orderId,
    String? reason,
  }) {
    final now = DateTime.now();
    return FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'status': 'cancelled',
      'updatedAt': now.toIso8601String(),
      'cancelledBy': 'admin',
      'cancelledAt': now.toIso8601String(),
      if (reason != null && reason.isNotEmpty) 'cancelReason': reason,
      if (reason != null && reason.isNotEmpty) 'rejectReason': reason,
    });
  }

  Future<void> updateAdminOrderFieldsInFirestore({
    required String orderId,
    required String title,
    required String description,
    required String area,
    required DateTime serviceDate,
  }) {
    final now = DateTime.now();
    return FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'title': title,
      'description': description,
      'area': area,
      'serviceDate': serviceDate.toIso8601String(),
      'updatedAt': now.toIso8601String(),
      'editedBy': 'admin',
      'editedAt': now.toIso8601String(),
    });
  }

  Future<void> assignWorkerToContractorOrderInFirestore({
    required String orderId,
    required String workerId,
    required String workerName,
    String? workerPhone,
    String? workerSpecialty,
    String? workerEmail,
    required OrderStatus currentStatus,
  }) {
    final now = DateTime.now();
    final Map<String, dynamic> data = {
      'assignedWorkerId': workerId,
      'assignedWorkerName': workerName,
      'updatedAt': now.toIso8601String(),
      if (workerPhone != null && workerPhone.isNotEmpty)
        'assignedWorkerPhone': workerPhone,
      if (workerSpecialty != null && workerSpecialty.isNotEmpty)
        'assignedWorkerSpecialty': workerSpecialty,
      if (workerEmail != null && workerEmail.isNotEmpty)
        'assignedWorkerEmail': workerEmail,
    };
    if (currentStatus == OrderStatus.pending) {
      data['status'] = 'inProgress';
      data['acceptedBy'] = 'contractor';
      data['acceptedAt'] = now.toIso8601String();
    }
    return FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .update(data);
  }

  // Backward-compatible multi-worker assignment used by the Contractor
  // assignment flows (Contractor Home + Contractor Order Details). Writes
  // the full `assignedWorkers` snapshot list in selection order, and always
  // mirrors the first selected worker into the legacy assignedWorkerId/Name
  // fields so old single-worker consumers keep working unchanged. Passing
  // an empty `workers` list clears all three fields via FieldValue.delete()
  // instead of leaving stale data behind.
  Future<void> assignWorkersToContractorOrderInFirestore({
    required String orderId,
    required List<AssignedWorkerSnapshot> workers,
    required OrderStatus currentStatus,
  }) {
    final now = DateTime.now();
    final Map<String, dynamic> data = {
      'updatedAt': now.toIso8601String(),
    };
    if (workers.isEmpty) {
      data['assignedWorkers'] = FieldValue.delete();
      data['assignedWorkerId'] = FieldValue.delete();
      data['assignedWorkerName'] = FieldValue.delete();
    } else {
      data['assignedWorkers'] = workers.map((w) => w.toMap()).toList();
      data['assignedWorkerId'] = workers.first.id;
      data['assignedWorkerName'] = workers.first.name;
    }
    if (currentStatus == OrderStatus.pending && workers.isNotEmpty) {
      data['status'] = 'inProgress';
      data['acceptedBy'] = 'contractor';
      data['acceptedAt'] = now.toIso8601String();
    }
    return FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .update(data);
  }

  // Destructive contractor action for an In-Progress order: removes every
  // assigned worker and returns the order to Pending in one write, so the
  // contractor has to accept and assign it again. Deletes (never nulls) the
  // assignment/acceptance fields, matching the clearing convention already
  // used by assignWorkersToContractorOrderInFirestore above.
  Future<void> unassignAllWorkersAndReturnToPendingInFirestore(String orderId) {
    final now = DateTime.now();
    return FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'status': 'pending',
      'updatedAt': now.toIso8601String(),
      'assignedWorkers': FieldValue.delete(),
      'assignedWorkerId': FieldValue.delete(),
      'assignedWorkerName': FieldValue.delete(),
      'acceptedBy': FieldValue.delete(),
      'acceptedAt': FieldValue.delete(),
    });
  }

  Future<void> reassignWorkerByAdminInFirestore({
    required String orderId,
    required String workerId,
    required String workerName,
    String? workerPhone,
    String? workerSpecialty,
    String? workerEmail,
    required OrderStatus currentStatus,
  }) {
    final now = DateTime.now();
    final Map<String, dynamic> data = {
      'assignedWorkerId': workerId,
      'assignedWorkerName': workerName,
      'updatedAt': now.toIso8601String(),
      'editedBy': 'admin',
      'editedAt': now.toIso8601String(),
      if (workerPhone != null && workerPhone.isNotEmpty)
        'assignedWorkerPhone': workerPhone,
      if (workerSpecialty != null && workerSpecialty.isNotEmpty)
        'assignedWorkerSpecialty': workerSpecialty,
      if (workerEmail != null && workerEmail.isNotEmpty)
        'assignedWorkerEmail': workerEmail,
    };
    if (currentStatus == OrderStatus.pending) {
      data['status'] = 'inProgress';
      data['acceptedBy'] = 'admin';
      data['acceptedAt'] = now.toIso8601String();
    }
    return FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .update(data);
  }
}

final ordersProvider = StateNotifierProvider<OrdersNotifier, List<OrderModel>>(
  (ref) => OrdersNotifier(),
);

// ─── Customer Firestore Orders Provider ───────────────────────────────────────
final customerFirestoreOrdersProvider = StreamProvider<List<OrderModel>>((ref) {
  final user = ref.watch(authProvider);
  if (user == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('orders')
      .where('customerId', isEqualTo: user.id)
      .snapshots()
      .handleError((Object e, StackTrace st) {
    debugPrint('ORDERS_LOAD_ERROR [customerOrders]: $e');
    debugPrint('ORDERS_LOAD_STACK [customerOrders]: $st');
    throw e;
  }).map((snap) {
    final orders = <OrderModel>[];
    for (final doc in snap.docs) {
      try {
        orders.add(OrderModel.fromMap(doc.data(), id: doc.id));
      } catch (e, st) {
        debugPrint('BAD_ORDER_DOC [customerOrders] ${doc.id}: $e');
        debugPrint('BAD_ORDER_DOC_STACK [customerOrders]: $st');
        debugPrint(
            'BAD_ORDER_DOC_DATA [customerOrders] ${doc.id}: ${doc.data()}');
        // Skip malformed doc — must not crash the whole orders screen.
      }
    }
    try {
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e, st) {
      debugPrint('ORDERS_SORT_ERROR [customerOrders]: $e');
      debugPrint('ORDERS_SORT_STACK [customerOrders]: $st');
    }
    return orders;
  });
});

// ─── Customer Orders "unseen" badge ────────────────────────────────────────────
// Backing store: a single field on the Customer's own users/{id} document —
// not a new collection, not a per-order field. Chosen because no existing
// mechanism already represents "orders unseen since the Customer last opened
// the Orders page": OrderModel has no seen/read field, and the notification
// system (NotificationModel / userNotificationsProvider) only ever writes an
// order_update notification to the customer when a provider/admin changes an
// order's status (see createOrderNotification call sites) — never when the
// customer creates their own order — so it cannot represent "new order
// unseen by its own creator".
final customerOrdersLastSeenProvider = StreamProvider<DateTime?>((ref) {
  final user = ref.watch(authProvider);
  if (user == null) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.id)
      .snapshots()
      .map((doc) {
    final raw = doc.data()?['ordersLastSeenAt'];
    return raw is String ? DateTime.tryParse(raw) : null;
  });
});

// Unseen = orders whose createdAt is after the last-seen marker. If the
// marker has never been written (Customer has never had the Orders page
// mark them seen), every current order counts as unseen — this resolves to
// 0 the first time the Orders page loads and writes the marker, and never
// shows a stale/hardcoded number again.
final customerUnseenOrdersCountProvider = Provider<int>((ref) {
  final orders = ref.watch(customerFirestoreOrdersProvider).valueOrNull;
  if (orders == null || orders.isEmpty) return 0;
  final lastSeen = ref.watch(customerOrdersLastSeenProvider).valueOrNull;
  if (lastSeen == null) return orders.length;
  return orders.where((o) => o.createdAt.isAfter(lastSeen)).length;
});

Future<void> markCustomerOrdersSeenInFirestore(String customerId) {
  return FirebaseFirestore.instance.collection('users').doc(customerId).set(
    {'ordersLastSeenAt': DateTime.now().toIso8601String()},
    SetOptions(merge: true),
  );
}

// ─── Professional Firestore Orders Provider ───────────────────────────────────
final professionalFirestoreOrdersProvider =
    StreamProvider<List<OrderModel>>((ref) {
  final user = ref.watch(authProvider);
  if (user == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('orders')
      .where('providerId', isEqualTo: user.id)
      .snapshots()
      .handleError((Object e, StackTrace st) {
    debugPrint('ORDERS_LOAD_ERROR [professionalOrders]: $e');
    debugPrint('ORDERS_LOAD_STACK [professionalOrders]: $st');
    throw e;
  }).map((snap) {
    final orders = <OrderModel>[];
    for (final doc in snap.docs) {
      try {
        orders.add(OrderModel.fromMap(doc.data(), id: doc.id));
      } catch (e, st) {
        debugPrint('BAD_ORDER_DOC [professionalOrders] ${doc.id}: $e');
        debugPrint('BAD_ORDER_DOC_STACK [professionalOrders]: $st');
        debugPrint(
            'BAD_ORDER_DOC_DATA [professionalOrders] ${doc.id}: ${doc.data()}');
        // Skip malformed doc — must not crash the whole orders screen.
      }
    }
    try {
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e, st) {
      debugPrint('ORDERS_SORT_ERROR [professionalOrders]: $e');
      debugPrint('ORDERS_SORT_STACK [professionalOrders]: $st');
    }
    return orders;
  });
});

// ─── Contractor Firestore Orders Provider ─────────────────────────────────────
final contractorFirestoreOrdersProvider =
    StreamProvider<List<OrderModel>>((ref) {
  final user = ref.watch(authProvider);
  if (user == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('orders')
      .where('providerId', isEqualTo: user.id)
      .snapshots()
      .handleError((Object e, StackTrace st) {
    debugPrint('ORDERS_LOAD_ERROR [contractorOrders]: $e');
    debugPrint('ORDERS_LOAD_STACK [contractorOrders]: $st');
    throw e;
  }).map((snap) {
    final orders = <OrderModel>[];
    for (final doc in snap.docs) {
      try {
        orders.add(OrderModel.fromMap(doc.data(), id: doc.id));
      } catch (e, st) {
        debugPrint('BAD_ORDER_DOC [contractorOrders] ${doc.id}: $e');
        debugPrint('BAD_ORDER_DOC_STACK [contractorOrders]: $st');
        debugPrint(
            'BAD_ORDER_DOC_DATA [contractorOrders] ${doc.id}: ${doc.data()}');
        // Skip malformed doc — must not crash the whole orders screen.
      }
    }
    try {
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e, st) {
      debugPrint('ORDERS_SORT_ERROR [contractorOrders]: $e');
      debugPrint('ORDERS_SORT_STACK [contractorOrders]: $st');
    }
    return orders;
  });
});

// ─── Admin Firestore Orders Provider ─────────────────────────────────────────
final adminFirestoreOrdersProvider = StreamProvider<List<OrderModel>>((ref) {
  // Reactive guard: rebuilds once login() populates authProvider.
  final user = ref.watch(authProvider);
  // Actual guard: the Firestore SDK evaluates security rules against
  // FirebaseAuth's current user, not our app-level authProvider — querying
  // before this is non-null is what produced the permission-denied errors.
  final fbUid = FirebaseAuth.instance.currentUser?.uid;
  debugPrint('ADMIN_ORDERS_AUTH_UID: $fbUid');
  debugPrint('ADMIN_ORDERS_QUERY_PATH: orders');
  if (user == null || fbUid == null) {
    return Stream.value(<OrderModel>[]);
  }
  return FirebaseFirestore.instance
      .collection('orders')
      .snapshots()
      .handleError((Object e, StackTrace st) {
    // Real stream-level error (e.g. Firestore permission-denied) — this is
    // what surfaces as "Error loading orders" in the admin UI.
    debugPrint('ORDERS_LOAD_ERROR [adminOrders]: $e');
    debugPrint('ORDERS_LOAD_STACK [adminOrders]: $st');
    throw e;
  }).map((snap) {
    final orders = <OrderModel>[];
    for (final doc in snap.docs) {
      try {
        orders.add(OrderModel.fromMap(doc.data(), id: doc.id));
      } catch (e, st) {
        debugPrint('BAD_ORDER_DOC [adminOrders] ${doc.id}: $e');
        debugPrint('BAD_ORDER_DOC_STACK [adminOrders]: $st');
        debugPrint('BAD_ORDER_DOC_DATA [adminOrders] ${doc.id}: ${doc.data()}');
        // Skip malformed doc — must not crash the whole orders screen.
      }
    }
    try {
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e, st) {
      debugPrint('ORDERS_SORT_ERROR [adminOrders]: $e');
      debugPrint('ORDERS_SORT_STACK [adminOrders]: $st');
    }
    return orders;
  });
});

// ─── Admin Order Stats ────────────────────────────────────────────────────────
class AdminOrderStats {
  final int total;
  final int pending;
  final int inProgress;
  final int completed;
  final int cancelled;
  const AdminOrderStats({
    required this.total,
    required this.pending,
    required this.inProgress,
    required this.completed,
    required this.cancelled,
  });
  static const empty = AdminOrderStats(
      total: 0, pending: 0, inProgress: 0, completed: 0, cancelled: 0);
}

final adminOrderStatsProvider = Provider<AsyncValue<AdminOrderStats>>((ref) {
  final ordersAsync = ref.watch(adminFirestoreOrdersProvider);
  // Loading and error states pass through as-is (whenData is a no-op for
  // them) so the dashboard can safely fall back to zero counts — see
  // admin_dashboard_screen.dart's `statsAsync.valueOrNull ?? AdminOrderStats.empty`.
  if (ordersAsync.hasError) {
    debugPrint('ORDER_STATS_ERROR: ${ordersAsync.error}');
    debugPrint('ORDER_STATS_STACK: ${ordersAsync.stackTrace}');
  }
  return ordersAsync.whenData((orders) => AdminOrderStats(
        total: orders.length,
        pending: orders.where((o) => o.status == OrderStatus.pending).length,
        inProgress:
            orders.where((o) => o.status == OrderStatus.inProgress).length,
        completed:
            orders.where((o) => o.status == OrderStatus.completed).length,
        cancelled:
            orders.where((o) => o.status == OrderStatus.cancelled).length,
      ));
});

// ─── Conversations Provider ───────────────────────────────────────────────────
class ConversationsNotifier extends StateNotifier<List<ConversationModel>> {
  ConversationsNotifier() : super(DummyData.conversations);

  void sendMessage(String otherUserId, String text) {
    state = state.map((ConversationModel conv) {
      if (conv.otherUserId != otherUserId) return conv;
      final newMsg = MessageModel(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        senderId: 'current_user',
        receiverId: otherUserId,
        text: text,
        sentAt: DateTime.now(),
        isRead: false,
      );
      return conv.copyWith(
        lastMessage: text,
        lastMessageTime: DateTime.now(),
        messages: [...conv.messages, newMsg],
      );
    }).toList();
  }

  void sendMediaMessage(
    String otherUserId, {
    required MessageType type,
    required String text,
    String? mediaPath,
    int? voiceDurationSec,
    Uint8List? mediaBytes,
  }) {
    state = state.map((ConversationModel conv) {
      if (conv.otherUserId != otherUserId) return conv;
      final newMsg = MessageModel(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        senderId: 'current_user',
        receiverId: otherUserId,
        text: text,
        sentAt: DateTime.now(),
        isRead: false,
        type: type,
        mediaPath: mediaPath,
        voiceDurationSec: voiceDurationSec,
        mediaBytes: mediaBytes,
      );
      return conv.copyWith(
        lastMessage: text,
        lastMessageTime: DateTime.now(),
        messages: [...conv.messages, newMsg],
      );
    }).toList();
  }

  void editMessage(String otherUserId, String messageId, String newText) {
    state = state.map((conv) {
      if (conv.otherUserId != otherUserId) return conv;
      final updatedMessages = conv.messages.map((msg) {
        if (msg.id != messageId) return msg;
        return msg.copyWith(text: newText, isEdited: true);
      }).toList();
      return conv.copyWith(messages: updatedMessages);
    }).toList();
  }

  void deleteMessage(String otherUserId, String messageId) {
    state = state.map((conv) {
      if (conv.otherUserId != otherUserId) return conv;
      final updatedMessages = conv.messages.map((msg) {
        if (msg.id != messageId) return msg;
        return msg.copyWith(isDeleted: true, text: '__deleted__');
      }).toList();
      return conv.copyWith(messages: updatedMessages);
    }).toList();
  }

  void startConversation(UserModel provider) {
    final exists =
        state.any((ConversationModel c) => c.otherUserId == provider.id);
    if (!exists) {
      state = [
        ConversationModel(
          otherUserId: provider.id,
          otherUserName: provider.fullName,
          lastMessage: '',
          lastMessageTime: DateTime.now(),
          unreadCount: 0,
          messages: [],
        ),
        ...state,
      ];
    }
  }

  void deleteConversation(String otherUserId) {
    state = state.where((c) => c.otherUserId != otherUserId).toList();
  }

  void markAsRead(String otherUserId) {
    state = state.map((c) {
      if (c.otherUserId != otherUserId) return c;
      return c.copyWith(unreadCount: 0);
    }).toList();
  }

  void blockUser(String userId, {String userName = ''}) {
    final exists = state.any((c) => c.otherUserId == userId);
    if (!exists) {
      // Add conversation entry first so block is visible in BlockedUsersScreen
      state = [
        ...state,
        ConversationModel(
          otherUserId: userId,
          otherUserName: userName,
          lastMessage: '',
          lastMessageTime: DateTime.now(),
          unreadCount: 0,
          messages: [],
          isBlocked: true,
        ),
      ];
    } else {
      state = state
          .map((c) => c.otherUserId == userId ? c.copyWith(isBlocked: true) : c)
          .toList();
    }
  }

  void unblockUser(String userId) {
    state = state
        .map((c) => c.otherUserId == userId ? c.copyWith(isBlocked: false) : c)
        .toList();
  }

  bool isBlocked(String userId) =>
      state.any((c) => c.otherUserId == userId && c.isBlocked);

  int get totalUnread =>
      state.fold<int>(0, (int sum, ConversationModel c) => sum + c.unreadCount);
}

final conversationsProvider =
    StateNotifierProvider<ConversationsNotifier, List<ConversationModel>>(
  (ref) => ConversationsNotifier(),
);

// ─── Chat — Firestore (Phase 6A: text messages only) ──────────────────────────
// Deterministic id so the same pair of users always share one conversation
// document, regardless of who messages first.
String getConversationId(String userId1, String userId2) {
  final ids = [userId1, userId2]..sort();
  return '${ids[0]}_${ids[1]}';
}

final currentUserConversationsProvider =
    StreamProvider<List<ConversationModel>>((ref) {
  final user = ref.watch(authProvider);
  if (user == null) return Stream.value([]);

  // Actual guard: FirebaseAuth's own uid, watched reactively — not a
  // one-time read — so this provider is rebuilt (and resubscribes) the
  // moment auth becomes ready or recovers from a transient gap. See
  // firebaseAuthUidProvider for why a one-time currentUser check isn't
  // enough to survive a mid-session auth blip.
  final fbUid = ref.watch(firebaseAuthUidProvider).valueOrNull;
  debugPrint('CHAT_AUTH_FIREBASE_UID [currentUserConversations] uid=$fbUid');
  debugPrint('CHAT_AUTH_APP_USER_ID [currentUserConversations] ${user.id}');
  if (fbUid == null) {
    return const Stream.empty();
  }
  if (fbUid != user.id) {
    // Flag it loudly — a mismatch here is exactly what causes "other
    // participant" mix-ups.
    debugPrint(
        'CHAT_UID_MISMATCH authProviderId=${user.id} firebaseUid=$fbUid');
  }

  debugPrint(
      'CHAT_CONVERSATION_PATH conversations (participantIds contains ${user.id})');
  debugPrint('CHAT_STREAM_CREATED currentUserConversations uid=$fbUid');

  return FirebaseFirestore.instance
      .collection('conversations')
      .where('participantIds', arrayContains: user.id)
      .snapshots()
      .handleError((Object e, StackTrace st) {
    // Kept concise on purpose — this can fire repeatedly during
    // logout/login/account-switch races (stale listener briefly losing
    // permission), so a single line avoids flooding the console.
    debugPrint('CHAT_LOAD_ERROR conversations: $e');
    if (e is FirebaseException) {
      debugPrint('CHAT_STREAM_ERROR_CODE conversations: ${e.code}');
      debugPrint('CHAT_STREAM_ERROR_MESSAGE conversations: ${e.message}');
    }
    throw e;
  }).map((snap) {
    final list = <ConversationModel>[];
    for (final doc in snap.docs) {
      try {
        list.add(ConversationModel.fromMap(doc.data(), id: doc.id));
      } catch (e, st) {
        debugPrint('BAD_CONVERSATION_DOC ${doc.id}: $e');
        debugPrint('BAD_CONVERSATION_DOC_STACK: $st');
        // Skip malformed doc — must not crash the whole messages screen.
      }
    }
    try {
      list.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
    } catch (e, st) {
      debugPrint('CONVERSATIONS_SORT_ERROR: $e');
      debugPrint('CONVERSATIONS_SORT_STACK: $st');
    }
    return list;
  });
});

// Returns every NORMAL (text/image/voice) message in the conversation,
// regardless of sender/receiver — chat screens decide "isMine" per-message
// at render time. Do not add a `.where('receiverId', ...)` /
// `.where('senderId', ...)` clause here: that would hide the current user's
// own sent messages from their own chat view.
//
// Phase 4D2: filtered server-side to normal message types only
// (`where('type', whereIn: [...])`) instead of fetching every document
// unfiltered and hiding admin warnings client-side afterwards — Admin
// Warnings now live in a separate adminWarnings subcollection entirely (see
// adminWarningsForConversationProvider below and sendAdminWarningMessage),
// and any legacy type=='adminWarning' document still physically sitting in
// this subcollection from before this phase is excluded by this same query
// filter (Firestore Rules also independently deny reading it directly —
// see firestore.rules' isNormalMessageType()). This filtered query is what
// lets Firestore prove every document this stream could ever return is one
// this participant is allowed to read.
final messagesForConversationProvider =
    StreamProvider.family<List<MessageModel>, String>((ref, conversationId) {
  if (conversationId.isEmpty) return Stream.value([]);

  // Actual guard: do not open a Firestore listener until FirebaseAuth is
  // ready — see firebaseAuthUidProvider. Watching it (rather than a one-time
  // currentUser read) means this exact provider instance is torn down and
  // recreated — i.e. resubscribes — the moment auth becomes ready or
  // recovers from a transient gap, with no timers/polling involved.
  final fbUid = ref.watch(firebaseAuthUidProvider).valueOrNull;
  debugPrint(
      'CHAT_AUTH_FIREBASE_UID [messages] conv=$conversationId uid=$fbUid');
  if (fbUid == null) {
    // Stays in AsyncLoading (never emits/errors) until the dependency above
    // changes — this is the "existing loading state", not a fake empty list.
    return const Stream.empty();
  }

  final path = 'conversations/$conversationId/messages';
  debugPrint('CHAT_MESSAGES_PATH $path');
  debugPrint('CHAT_STREAM_CREATED messages[$conversationId] uid=$fbUid');

  return FirebaseFirestore.instance
      .collection('conversations')
      .doc(conversationId)
      .collection('messages')
      .where('type', whereIn: ['text', 'image', 'voice'])
      .snapshots()
      .handleError((Object e, StackTrace st) {
        // Kept concise on purpose — see the matching note on
        // currentUserConversationsProvider above.
        debugPrint('CHAT_LOAD_ERROR messages[$conversationId]: $e');
        if (e is FirebaseException) {
          debugPrint(
              'CHAT_STREAM_ERROR_CODE messages[$conversationId]: ${e.code}');
          debugPrint(
              'CHAT_STREAM_ERROR_MESSAGE messages[$conversationId]: ${e.message}');
        }
        throw e;
      })
      .map((snap) {
        final list = <MessageModel>[];
        for (final doc in snap.docs) {
          try {
            list.add(MessageModel.fromMap(doc.data(), id: doc.id));
          } catch (e, st) {
            debugPrint('BAD_MESSAGE_DOC ${doc.id}: $e');
            debugPrint('BAD_MESSAGE_DOC_STACK: $st');
            // Skip malformed doc — must not crash the whole chat screen.
          }
        }
        try {
          list.sort((a, b) => a.sentAt.compareTo(b.sentAt));
        } catch (e, st) {
          debugPrint('MESSAGES_SORT_ERROR [$conversationId]: $e');
          debugPrint('MESSAGES_SORT_STACK: $st');
        }
        return list;
      });
});

// New Admin Warnings targeted at the current user — Phase 4D2. Queried from
// the dedicated adminWarnings subcollection with a server-side
// `where('targetUserIds', arrayContains: uid)` filter, which is what lets
// Firestore Rules prove every document this stream could ever return names
// this uid as a target (see firestore.rules' adminWarnings match block) —
// an untargeted participant's equivalent query is denied outright by
// Firestore, not silently filtered. Same auth-readiness guard as
// messagesForConversationProvider. Not sorted here — chatTimelineForConversationProvider
// merges this with messagesForConversationProvider and sorts the combined list.
final adminWarningsForConversationProvider =
    StreamProvider.family<List<MessageModel>, String>((ref, conversationId) {
  if (conversationId.isEmpty) return Stream.value([]);

  final fbUid = ref.watch(firebaseAuthUidProvider).valueOrNull;
  debugPrint(
      'CHAT_AUTH_FIREBASE_UID [adminWarnings] conv=$conversationId uid=$fbUid');
  if (fbUid == null) {
    return const Stream.empty();
  }

  return FirebaseFirestore.instance
      .collection('conversations')
      .doc(conversationId)
      .collection('adminWarnings')
      .where('targetUserIds', arrayContains: fbUid)
      .snapshots()
      .handleError((Object e, StackTrace st) {
    debugPrint('CHAT_LOAD_ERROR adminWarnings[$conversationId]: $e');
    if (e is FirebaseException) {
      debugPrint(
          'CHAT_STREAM_ERROR_CODE adminWarnings[$conversationId]: ${e.code}');
      debugPrint(
          'CHAT_STREAM_ERROR_MESSAGE adminWarnings[$conversationId]: ${e.message}');
    }
    throw e;
  }).map((snap) {
    final list = <MessageModel>[];
    for (final doc in snap.docs) {
      try {
        list.add(MessageModel.fromMap(doc.data(), id: doc.id));
      } catch (e, st) {
        debugPrint('BAD_ADMIN_WARNING_DOC ${doc.id}: $e');
        debugPrint('BAD_ADMIN_WARNING_DOC_STACK: $st');
        // Skip malformed doc — must not crash the whole chat screen.
      }
    }
    return list;
  });
});

// Combined chronological chat timeline for Customer/Professional/Contractor
// chat screens — Phase 4D2. A plain computed provider (not a StreamProvider)
// that reactively recombines messagesForConversationProvider (normal
// messages) with adminWarningsForConversationProvider (this user's targeted
// warnings) whenever either re-emits, preserving each source's own
// loading/error AsyncValue instead of inventing new semantics. The two
// source collections are structurally distinct (different Firestore
// subcollections, independently auto-generated document ids), so a plain
// concatenation can never produce a duplicate entry.
final chatTimelineForConversationProvider =
    Provider.family<AsyncValue<List<MessageModel>>, String>(
        (ref, conversationId) {
  final messagesAsync =
      ref.watch(messagesForConversationProvider(conversationId));
  final warningsAsync =
      ref.watch(adminWarningsForConversationProvider(conversationId));

  if (messagesAsync.hasError) {
    return AsyncValue.error(
        messagesAsync.error!, messagesAsync.stackTrace ?? StackTrace.current);
  }
  if (warningsAsync.hasError) {
    return AsyncValue.error(
        warningsAsync.error!, warningsAsync.stackTrace ?? StackTrace.current);
  }

  final messages = messagesAsync.valueOrNull;
  final warnings = warningsAsync.valueOrNull;
  if (messages == null || warnings == null) {
    return const AsyncValue.loading();
  }

  final combined = [...messages, ...warnings];
  try {
    combined.sort((a, b) => a.sentAt.compareTo(b.sentAt));
  } catch (e, st) {
    debugPrint('CHAT_TIMELINE_SORT_ERROR [$conversationId]: $e');
    debugPrint('CHAT_TIMELINE_SORT_STACK: $st');
  }
  return AsyncValue.data(combined);
});

// Hotfix (chat-production-before): Rules-compatible existence check for a
// conversation the current user is (or would be) a participant in. A direct
// get()/snapshot() on conversations/{conversationId} when that document
// does not exist yet is denied outright by firestore.rules:
// isParticipant() reads resource.data.participantIds, which errors on a
// null resource, and isAdmin() alone is false for a normal participant —
// `error || false` evaluates to denied, i.e. permission-denied on a
// perfectly legitimate "does my new conversation exist yet" check.
// Querying the collection filtered by `participantIds arrayContains
// senderId` is the same proof shape already used by
// currentUserConversationsProvider, and is safe for a nonexistent
// conversation: it simply returns no matching document instead of being
// denied. Never call convRef.get() directly on a possibly-new conversation
// — use this instead.
Future<QueryDocumentSnapshot<Map<String, dynamic>>?>
    _findExistingConversationDoc({
  required String senderId,
  required String conversationId,
}) async {
  final snap = await FirebaseFirestore.instance
      .collection('conversations')
      .where('participantIds', arrayContains: senderId)
      .get();
  for (final doc in snap.docs) {
    if (doc.id == conversationId) return doc;
  }
  return null;
}

// Hotfix 2: firestore.rules' conversationCreateValid() requires
// participantRoles (when present) to exactly match each uid's *currently
// stored* users/{uid}.role — a stale role/name on the caller-supplied
// UserModel (e.g. a placeholder built inline from just an id/name at a
// navigation call site, or a role that changed after that object was
// built) would deny the entire conversation create. users/{uid} is
// publicly readable (`allow read: if true`), so this always resolves
// safely; falls back to the caller-supplied value only if the fresh read
// is unexpectedly missing that field.
Future<Map<String, String>> _freshParticipantIdentity(
    String uid, String fallbackName, String fallbackRole) async {
  try {
    final snap =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = snap.data();
    return {
      'name': (data?['fullName'] as String?) ?? fallbackName,
      'role': (data?['role'] as String?) ?? fallbackRole,
    };
  } catch (e) {
    debugPrint('CHAT_FRESH_IDENTITY_LOOKUP_ERROR uid=$uid: $e');
    return {'name': fallbackName, 'role': fallbackRole};
  }
}

// Writes a text message + updates/creates the parent conversation doc.
// No-ops on blank text (UI is responsible for showing a validation error).
// Returns false (and writes nothing) if the conversation already exists and
// is blocked — callers use this to show a "conversation is blocked" message.
//
// Phase 4E: the message document and its parent conversation document
// (create-or-merge) plus the receiver's unread-count bump are committed
// together in one atomic Firestore WriteBatch — never as separate
// sequential writes — so a brand-new conversation's first message can never
// exist as an orphan (a message with no parent conversation document at
// all), even if the app crashes or loses connectivity mid-send. See
// firestore.rules' normalMessageCreateAllowed(), which uses getAfter() on
// the conversation document to see this same-batch creation when
// authorizing the message write.
//
// Hotfix (chat-production-before): existence is now determined via
// _findExistingConversationDoc (never a direct convRef.get(), which
// firestore.rules denies for a conversation that doesn't exist yet — see
// that function's comment). For an EXISTING conversation, the batch write
// below only ever touches the real mutable fields (lastMessage/
// lastMessageTime/lastMessageSenderId/updatedAt + the receiver's unread
// count) — it no longer rewrites participantIds/participantNames/
// participantRoles/isBlocked/createdAt on every send. Rewriting those on
// every send was itself a production bug: firestore.rules'
// conversationIdentityUnchanged() requires participantIds to compare equal
// as an ordered list, but this function always wrote
// [senderId, receiverId] — the *other* participant's later reply would
// write that list in the opposite order to what's already stored, failing
// conversationIdentityUnchanged() and denying the entire update.
//
// Hotfix 2 (chat-production-before): convRef is now written EXACTLY ONCE
// per batch, not twice. The previous shape — batch.set(convRef, ...) (or
// batch.update for an existing conversation) followed by a SEPARATE
// batch.update(convRef, {'unreadCount...': increment(1)}) on the very same
// document in the same atomic commit — was proven via rules_tests to be
// denied outright by firestore.rules even though each half looked valid in
// isolation. For a brand-new conversation, the receiver's initial unread
// bump is now embedded directly in the single create payload
// ({senderId: 0, receiverId: 1}) — see firestore.rules'
// unreadCountSafeAtCreate() for the narrow rule branch this required. For
// an existing conversation, lastMessage* and the unreadCount increment are
// now written together in the single update() call — see
// lastMessageAndUnreadIncrementBranch().
Future<bool> sendTextMessageToUser({
  required String senderId,
  required String senderName,
  required String senderRole,
  required String receiverId,
  required String receiverName,
  required String receiverRole,
  required String text,
}) async {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return false;

  debugPrint(
      'CHAT_SEND_FIREBASE_UID ${FirebaseAuth.instance.currentUser?.uid}');
  debugPrint('CHAT_AUTH_APP_USER_ID $senderId');

  try {
    final conversationId = getConversationId(senderId, receiverId);
    final convRef = FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId);
    final msgRef = convRef.collection('messages').doc();
    final now = DateTime.now();

    final existingDoc = await _findExistingConversationDoc(
        senderId: senderId, conversationId: conversationId);
    final isNew = existingDoc == null;

    if (existingDoc != null &&
        (existingDoc.data()['isBlocked'] as bool? ?? false)) {
      return false;
    }

    final batch = FirebaseFirestore.instance.batch();

    batch.set(msgRef, {
      'id': msgRef.id,
      'conversationId': conversationId,
      'senderId': senderId,
      'receiverId': receiverId,
      'text': trimmed,
      'type': 'text',
      'sentAt': now.toIso8601String(),
      'isRead': false,
      'isEdited': false,
      'isDeleted': false,
    });

    if (isNew) {
      final freshSender =
          await _freshParticipantIdentity(senderId, senderName, senderRole);
      final freshReceiver = await _freshParticipantIdentity(
          receiverId, receiverName, receiverRole);
      batch.set(convRef, {
        'id': conversationId,
        'participantIds': [senderId, receiverId],
        'participantNames': {
          senderId: freshSender['name'],
          receiverId: freshReceiver['name'],
        },
        'participantRoles': {
          senderId: freshSender['role'],
          receiverId: freshReceiver['role'],
        },
        'lastMessage': trimmed,
        'lastMessageTime': now.toIso8601String(),
        'lastMessageSenderId': senderId,
        'isBlocked': false,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'unreadCount': {senderId: 0, receiverId: 1},
      });
    } else {
      batch.update(convRef, {
        'lastMessage': trimmed,
        'lastMessageTime': now.toIso8601String(),
        'lastMessageSenderId': senderId,
        'updatedAt': now.toIso8601String(),
        'unreadCount.$receiverId': FieldValue.increment(1),
      });
    }

    await batch.commit();

    return true;
  } catch (e) {
    debugPrint('CHAT_SEND_ERROR: $e');
    rethrow;
  }
}

// Admin moderation action: writes a MessageType.adminWarning document
// visible only to the UID(s) in targetUserIds. Phase 4D2: this now writes
// to the dedicated conversations/{conversationId}/adminWarnings
// subcollection instead of messages, so that target-only visibility is
// enforced by Firestore Rules themselves (see firestore.rules'
// adminWarnings match block) rather than by a client-side filter — a
// single unfiltered messages query could never simultaneously prove "every
// participant may read normal messages" and "only targetUserIds may read a
// warning". The document shape is otherwise unchanged (same fields
// MessageModel already knows how to parse), so existing rendering
// (_AdminWarningCard) needs no changes. Deliberately does NOT touch the
// parent conversation document at all — unlike sendTextMessageToUser/
// sendImageMessageToUser, it never writes lastMessage/lastMessageTime/
// unreadCount, so a one-participant warning's text can never leak into a
// shared conversation-list preview, and sending a warning cannot change the
// conversation's block status either way (also intentionally bypasses
// isBlocked — a warning may always be sent regardless of block state).
// Returns false (never throws) on failure so callers can show an
// inline/SnackBar error without crashing.
Future<bool> sendAdminWarningMessage({
  required String conversationId,
  required String adminId,
  required String text,
  required List<String> targetUserIds,
}) async {
  final trimmed = text.trim();
  if (trimmed.isEmpty || targetUserIds.isEmpty) return false;

  try {
    final warningRef = FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .collection('adminWarnings')
        .doc();
    final now = DateTime.now();

    await warningRef.set({
      'id': warningRef.id,
      'conversationId': conversationId,
      'senderId': adminId,
      'receiverId': '',
      'text': trimmed,
      'type': 'adminWarning',
      'targetUserIds': targetUserIds,
      'sentAt': now.toIso8601String(),
      'isRead': false,
      'isEdited': false,
      'isDeleted': false,
    });
    return true;
  } catch (e) {
    debugPrint('ADMIN_WARNING_SEND_ERROR: $e');
    return false;
  }
}

// Uploads an image to Firebase Storage and writes an image message + updates
// the parent conversation doc — mirrors sendTextMessageToUser's shape/return
// semantics (false = blocked/invalid, rethrow = unexpected error). No-ops on
// empty bytes. Never writes raw image bytes to Firestore — only the Storage
// download URL.
//
// Known limitation (pre-existing, not addressed in Phase 4E): the Storage
// upload happens before the Firestore batch. If the upload succeeds but the
// batch then fails (e.g. permission denial, network loss), the uploaded
// object remains in Storage with no Firestore document ever referencing it
// — an orphaned Storage upload. Phase 4E only makes the Firestore side
// (message + conversation + unread count) atomic with itself; it does not
// add Storage cleanup/rollback, which would need its own dedicated design
// (e.g. a scheduled Cloud Function sweeping unreferenced objects).
Future<bool> sendImageMessageToUser({
  required String senderId,
  required String senderName,
  required String senderRole,
  required String receiverId,
  required String receiverName,
  required String receiverRole,
  required Uint8List imageBytes,
  required String fileName,
  String? contentType,
}) async {
  if (imageBytes.isEmpty) return false;

  try {
    final conversationId = getConversationId(senderId, receiverId);
    final convRef = FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId);

    final existingDoc = await _findExistingConversationDoc(
        senderId: senderId, conversationId: conversationId);
    final isNew = existingDoc == null;

    if (existingDoc != null &&
        (existingDoc.data()['isBlocked'] as bool? ?? false)) {
      return false;
    }

    final msgRef = convRef.collection('messages').doc();
    final now = DateTime.now();

    final lowerName = fileName.toLowerCase();
    final resolvedContentType = contentType ??
        (lowerName.endsWith('.png')
            ? 'image/png'
            : lowerName.endsWith('.webp')
                ? 'image/webp'
                : lowerName.endsWith('.gif')
                    ? 'image/gif'
                    : 'image/jpeg');

    // Phase 6B2: path is scoped by real sender/receiver uid (proven by this
    // function's own senderId/receiverId params — not derived/parsed from
    // conversationId) so Storage Rules can authorize strictly by path
    // segment without any conversationId parsing. conversationId itself is
    // unchanged and still stored as a message field for querying.
    final storagePath =
        'chat_images/$senderId/$receiverId/${msgRef.id}/$fileName';
    final storageRef = FirebaseStorage.instance.ref().child(storagePath);

    // TEMP DIAGNOSTIC (Emergency Storage Hotfix) — remove once the exact
    // Production rejection is confirmed and fixed.
    debugPrint('CHAT_IMAGE_UPLOAD_DEBUG '
        'fbAuthUid=${FirebaseAuth.instance.currentUser?.uid} '
        'senderId=$senderId '
        'receiverId=$receiverId '
        'senderMatchesAuth=${senderId == FirebaseAuth.instance.currentUser?.uid} '
        'storagePath=$storagePath '
        'fileName=$fileName '
        'byteSize=${imageBytes.length} '
        'contentType=$resolvedContentType '
        'messageId=${msgRef.id}');

    // putData works on both Web and mobile (unlike putFile, which needs dart:io).
    // Phase 4E: Storage upload still happens before the Firestore batch —
    // if the batch below fails after a successful upload, the uploaded
    // object is orphaned in Storage with no Firestore document referencing
    // it (pre-existing risk, not newly introduced or redesigned here — see
    // the function-level note above sendImageMessageToUser's declaration).
    await storageRef.putData(
        imageBytes, SettableMetadata(contentType: resolvedContentType));
    final downloadUrl = await storageRef.getDownloadURL();

    // Phase 4E: the message document, its parent conversation document
    // (create-or-merge), and the receiver's unread-count bump are committed
    // together in one atomic WriteBatch — see sendTextMessageToUser's
    // matching note for why.
    final batch = FirebaseFirestore.instance.batch();

    batch.set(msgRef, {
      'id': msgRef.id,
      'conversationId': conversationId,
      'senderId': senderId,
      'receiverId': receiverId,
      'text': '',
      'type': 'image',
      'imageUrl': downloadUrl,
      'mediaUrl': downloadUrl,
      'storagePath': storagePath,
      'fileName': fileName,
      'sentAt': now.toIso8601String(),
      'isRead': false,
      'isEdited': false,
      'isDeleted': false,
    });

    if (isNew) {
      final freshSender =
          await _freshParticipantIdentity(senderId, senderName, senderRole);
      final freshReceiver = await _freshParticipantIdentity(
          receiverId, receiverName, receiverRole);
      batch.set(convRef, {
        'id': conversationId,
        'participantIds': [senderId, receiverId],
        'participantNames': {
          senderId: freshSender['name'],
          receiverId: freshReceiver['name'],
        },
        'participantRoles': {
          senderId: freshSender['role'],
          receiverId: freshReceiver['role'],
        },
        'lastMessage': '[Image]',
        'lastMessageTime': now.toIso8601String(),
        'lastMessageSenderId': senderId,
        'isBlocked': false,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'unreadCount': {senderId: 0, receiverId: 1},
      });
    } else {
      batch.update(convRef, {
        'lastMessage': '[Image]',
        'lastMessageTime': now.toIso8601String(),
        'lastMessageSenderId': senderId,
        'updatedAt': now.toIso8601String(),
        'unreadCount.$receiverId': FieldValue.increment(1),
      });
    }

    await batch.commit();

    return true;
  } catch (e) {
    debugPrint('CHAT_IMAGE_SEND_ERROR: $e');
    rethrow;
  }
}

// Uploads a voice recording to Firebase Storage and writes a voice message +
// updates the parent conversation doc — mirrors sendImageMessageToUser's
// shape/return semantics (null = blocked/invalid, rethrow = unexpected
// error). No-ops on empty bytes. Never writes raw audio bytes to Firestore —
// only the Storage download URL.
//
// Known limitation (pre-existing, not addressed in Phase 4E): same
// orphaned-Storage-upload risk documented on sendImageMessageToUser — the
// upload happens before the Firestore batch, so a successful upload
// followed by a failed batch leaves the uploaded audio object unreferenced
// in Storage.
//
// Returns the written MessageModel (not just a bool) so callers can render
// the voice bubble in the chat list immediately after send, instead of
// waiting for the messagesForConversationProvider stream to re-emit — the
// message list otherwise only picked it up on the next screen load/refresh.
Future<MessageModel?> sendVoiceMessageToUser({
  required String senderId,
  required String senderName,
  required String senderRole,
  required String receiverId,
  required String receiverName,
  required String receiverRole,
  required Uint8List audioBytes,
  required String fileName,
  required int durationSec,
  String? contentType,
}) async {
  if (audioBytes.isEmpty) return null;

  try {
    final conversationId = getConversationId(senderId, receiverId);
    final convRef = FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId);

    final existingDoc = await _findExistingConversationDoc(
        senderId: senderId, conversationId: conversationId);
    final isNew = existingDoc == null;

    if (existingDoc != null &&
        (existingDoc.data()['isBlocked'] as bool? ?? false)) {
      return null;
    }

    final msgRef = convRef.collection('messages').doc();
    final now = DateTime.now();

    final lowerName = fileName.toLowerCase();
    final resolvedContentType = contentType ??
        (lowerName.endsWith('.webm')
            ? 'audio/webm'
            : lowerName.endsWith('.m4a')
                ? 'audio/mp4'
                : lowerName.endsWith('.mp3')
                    ? 'audio/mpeg'
                    : 'audio/mpeg');

    // Phase 6B2: same real sender/receiver-uid path scoping as
    // sendImageMessageToUser — see its matching comment above.
    final storagePath =
        'chat_voice/$senderId/$receiverId/${msgRef.id}/$fileName';
    final storageRef = FirebaseStorage.instance.ref().child(storagePath);

    // TEMP DIAGNOSTIC (Emergency Storage Hotfix) — remove once the exact
    // Production rejection is confirmed and fixed.
    debugPrint('CHAT_VOICE_UPLOAD_DEBUG '
        'fbAuthUid=${FirebaseAuth.instance.currentUser?.uid} '
        'senderId=$senderId '
        'receiverId=$receiverId '
        'senderMatchesAuth=${senderId == FirebaseAuth.instance.currentUser?.uid} '
        'storagePath=$storagePath '
        'fileName=$fileName '
        'byteSize=${audioBytes.length} '
        'contentType=$resolvedContentType '
        'messageId=${msgRef.id}');

    // putData works on both Web and mobile (unlike putFile, which needs dart:io).
    await storageRef.putData(
        audioBytes, SettableMetadata(contentType: resolvedContentType));
    final downloadUrl = await storageRef.getDownloadURL();

    final messageData = {
      'id': msgRef.id,
      'conversationId': conversationId,
      'senderId': senderId,
      'receiverId': receiverId,
      'text': '',
      'type': 'voice',
      'voiceUrl': downloadUrl,
      'audioUrl': downloadUrl,
      'mediaUrl': downloadUrl,
      'storagePath': storagePath,
      'fileName': fileName,
      'voiceDurationSec': durationSec,
      'sentAt': now.toIso8601String(),
      'isRead': false,
      'isEdited': false,
      'isDeleted': false,
    };

    // Phase 4E: the message document, its parent conversation document
    // (create-or-merge), and the receiver's unread-count bump are committed
    // together in one atomic WriteBatch — see sendTextMessageToUser's
    // matching note for why.
    final batch = FirebaseFirestore.instance.batch();

    batch.set(msgRef, messageData);

    if (isNew) {
      final freshSender =
          await _freshParticipantIdentity(senderId, senderName, senderRole);
      final freshReceiver = await _freshParticipantIdentity(
          receiverId, receiverName, receiverRole);
      batch.set(convRef, {
        'id': conversationId,
        'participantIds': [senderId, receiverId],
        'participantNames': {
          senderId: freshSender['name'],
          receiverId: freshReceiver['name'],
        },
        'participantRoles': {
          senderId: freshSender['role'],
          receiverId: freshReceiver['role'],
        },
        'lastMessage': '[Voice]',
        'lastMessageTime': now.toIso8601String(),
        'lastMessageSenderId': senderId,
        'isBlocked': false,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'unreadCount': {senderId: 0, receiverId: 1},
      });
    } else {
      batch.update(convRef, {
        'lastMessage': '[Voice]',
        'lastMessageTime': now.toIso8601String(),
        'lastMessageSenderId': senderId,
        'updatedAt': now.toIso8601String(),
        'unreadCount.$receiverId': FieldValue.increment(1),
      });
    }

    await batch.commit();

    return MessageModel.fromMap(messageData, id: msgRef.id);
  } catch (e) {
    debugPrint('VOICE_MESSAGE_SEND_ERROR: $e');
    rethrow;
  }
}

// Edits a text message the current user sent. Returns false (no write) if
// the message doesn't exist, isn't owned by currentUserId, isn't a text
// message, is already deleted, or newText is blank after trimming. Rethrows
// on unexpected Firestore errors — callers should catch and show a failure
// SnackBar.
Future<bool> editTextMessageInFirestore({
  required String conversationId,
  required String messageId,
  required String currentUserId,
  required String newText,
}) async {
  final trimmed = newText.trim();
  if (trimmed.isEmpty || conversationId.isEmpty || messageId.isEmpty)
    return false;

  try {
    final convRef = FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId);
    final msgRef = convRef.collection('messages').doc(messageId);
    final msgSnap = await msgRef.get();
    if (!msgSnap.exists) return false;

    final data = msgSnap.data()!;
    if (data['senderId'] != currentUserId) return false;
    if ((data['type'] as String? ?? 'text') != 'text') return false;
    if (data['isDeleted'] == true) return false;

    final now = DateTime.now();
    await msgRef.update({
      'text': trimmed,
      'isEdited': true,
      'editedAt': now.toIso8601String(),
    });

    // Only touch the conversation's lastMessage if this message is still the
    // most recent one — compared via sentAt, which sendTextMessageToUser
    // writes identically (same DateTime.now() call) to both the message doc
    // and the conversation's lastMessageTime.
    final convSnap = await convRef.get();
    final convData = convSnap.data();
    final isLastMessage = convData != null &&
        data['sentAt'] != null &&
        data['sentAt'] == convData['lastMessageTime'];
    if (isLastMessage) {
      await convRef.update({
        'lastMessage': trimmed,
        'updatedAt': now.toIso8601String(),
      });
    }
    return true;
  } catch (e) {
    debugPrint('CHAT_EDIT_ERROR: $e');
    rethrow;
  }
}

// Soft-deletes a message the current user sent — the Firestore doc is never
// physically removed. Returns false (no write) if the message doesn't
// exist, isn't owned by currentUserId, or is already deleted. Rethrows on
// unexpected Firestore errors — callers should catch and show a failure
// SnackBar.
Future<bool> deleteMessageInFirestore({
  required String conversationId,
  required String messageId,
  required String currentUserId,
}) async {
  if (conversationId.isEmpty || messageId.isEmpty) return false;

  try {
    final convRef = FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId);
    final msgRef = convRef.collection('messages').doc(messageId);
    final msgSnap = await msgRef.get();
    if (!msgSnap.exists) return false;

    final data = msgSnap.data()!;
    if (data['senderId'] != currentUserId) return false;
    if (data['isDeleted'] == true) return false;

    final now = DateTime.now();
    await msgRef.update({
      'isDeleted': true,
      'text': '',
      'deletedBy': currentUserId,
      'deletedAt': now.toIso8601String(),
    });

    final convSnap = await convRef.get();
    final convData = convSnap.data();
    final isLastMessage = convData != null &&
        data['sentAt'] != null &&
        data['sentAt'] == convData['lastMessageTime'];
    if (isLastMessage) {
      await convRef.update({
        'lastMessage': 'This message was deleted',
        'updatedAt': now.toIso8601String(),
      });
    }
    return true;
  } catch (e) {
    debugPrint('CHAT_DELETE_ERROR: $e');
    rethrow;
  }
}

// Hotfix 2: pure decision extracted out of conversationByIdProvider's
// snapshot mapping so the pending-write gate itself is unit-testable
// without a live Firestore listener (see
// test/conversation_pending_gate_test.dart). A locally-pending write (this
// exact conversation document just created by this client, not yet
// acknowledged by the server) must not be treated as "the conversation
// exists" — chat screens use conversationByIdProvider's non-null result to
// decide whether to start the messages/adminWarnings listeners, and those
// are denied by firestore.rules for a conversation the server hasn't
// actually created yet.
bool conversationSnapshotIsServerConfirmed({
  required bool exists,
  required bool hasPendingWrites,
}) {
  return exists && !hasPendingWrites;
}

// Streams a single conversation document by id so chat screens can read the
// live block state (isBlocked/blockedBy) without depending on the legacy
// local conversationsProvider. Returns null while the doc doesn't exist yet
// (e.g. no message sent and nobody has blocked yet).
//
// Hotfix (chat-production-before): a direct .doc(conversationId).snapshots()
// used to be denied outright by firestore.rules for a participant opening a
// brand-new conversation (isParticipant() errors on a null resource for a
// doc that doesn't exist yet, and isAdmin() alone is false for a normal
// participant) — this is the exact "conversationById read fails
// permission-denied" production symptom for a new/nonexistent conversation.
// For a normal participant this now instead queries `conversations` filtered
// by `participantIds arrayContains myUid` (the same proof shape
// currentUserConversationsProvider already relies on) and picks out the
// matching id client-side — safe whether or not the document exists yet, and
// it starts reflecting the real document automatically the moment it's
// created, with no extra plumbing. Admin (isAdmin() is unconditionally true
// regardless of the target document, or of whether Admin is a participant at
// all — see admin_chat_screen.dart) keeps the original direct-document
// listener, since Admin is generally NOT in participantIds and the
// arrayContains query would otherwise never match anything for them.
final conversationByIdProvider =
    StreamProvider.family<ConversationModel?, String>((ref, conversationId) {
  if (conversationId.isEmpty) return Stream.value(null);

  // Same auth-readiness guard as messagesForConversationProvider — see
  // firebaseAuthUidProvider for why this must be a reactive watch, not a
  // one-time currentUser check.
  final fbUid = ref.watch(firebaseAuthUidProvider).valueOrNull;
  debugPrint(
      'CHAT_AUTH_FIREBASE_UID [conversationById] conv=$conversationId uid=$fbUid');
  if (fbUid == null) {
    return const Stream.empty();
  }

  final appUser = ref.watch(authProvider);
  final isAdminUser = appUser?.role == UserRole.admin;

  ConversationModel? parseDoc(String id, Map<String, dynamic> data) {
    try {
      return ConversationModel.fromMap(data, id: id);
    } catch (e, st) {
      debugPrint('BAD_CONVERSATION_DOC $id: $e');
      debugPrint('BAD_CONVERSATION_DOC_STACK: $st');
      return null;
    }
  }

  if (isAdminUser) {
    debugPrint('CHAT_CONVERSATION_PATH conversations/$conversationId');
    debugPrint(
        'CHAT_STREAM_CREATED conversationById[admin][$conversationId] uid=$fbUid');
    // includeMetadataChanges: true — required for the hasPendingWrites
    // check below to ever resolve. Without it, Firestore does not re-emit
    // a snapshot for a metadata-only change (pending -> server-confirmed,
    // same data), so a caller gating on hasPendingWrites would otherwise
    // get stuck on the first (pending) emission forever.
    return FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .snapshots(includeMetadataChanges: true)
        .handleError((Object e, StackTrace st) {
      debugPrint('CHAT_LOAD_ERROR conversation[$conversationId]: $e');
      if (e is FirebaseException) {
        debugPrint(
            'CHAT_STREAM_ERROR_CODE conversation[$conversationId]: ${e.code}');
        debugPrint(
            'CHAT_STREAM_ERROR_MESSAGE conversation[$conversationId]: ${e.message}');
      }
      throw e;
    }).map((snap) {
      // Hotfix 2: a locally-pending write (this exact conversation
      // document created moments ago by this client, not yet acknowledged
      // by the server) must not be treated as "exists" — chat screens use
      // this null to decide whether to start the messages/adminWarnings
      // listeners, and those are denied for a conversation the server
      // hasn't actually created yet. If the pending write is ultimately
      // rejected, this keeps resolving to null (no separate handling
      // needed) since the local cache rolls the optimistic write back.
      if (!conversationSnapshotIsServerConfirmed(
          exists: snap.exists,
          hasPendingWrites: snap.metadata.hasPendingWrites)) {
        return null;
      }
      return parseDoc(snap.id, snap.data()!);
    });
  }

  debugPrint(
      'CHAT_CONVERSATION_PATH conversations (participantIds contains $fbUid) -> $conversationId');
  debugPrint(
      'CHAT_STREAM_CREATED conversationById[$conversationId] uid=$fbUid');

  return FirebaseFirestore.instance
      .collection('conversations')
      .where('participantIds', arrayContains: fbUid)
      .snapshots(includeMetadataChanges: true)
      .handleError((Object e, StackTrace st) {
    debugPrint('CHAT_LOAD_ERROR conversation[$conversationId]: $e');
    if (e is FirebaseException) {
      debugPrint(
          'CHAT_STREAM_ERROR_CODE conversation[$conversationId]: ${e.code}');
      debugPrint(
          'CHAT_STREAM_ERROR_MESSAGE conversation[$conversationId]: ${e.message}');
    }
    throw e;
  }).map((snap) {
    for (final doc in snap.docs) {
      if (doc.id == conversationId) {
        // Same pending-write gate as the Admin branch above.
        if (!conversationSnapshotIsServerConfirmed(
            exists: true, hasPendingWrites: doc.metadata.hasPendingWrites)) {
          return null;
        }
        return parseDoc(doc.id, doc.data());
      }
    }
    return null;
  });
});

// Marks the conversation as blocked by [currentUserId]. Creates the
// conversation doc (via merge) if it doesn't exist yet — blocking can happen
// before any message has ever been sent.
Future<void> blockConversationInFirestore({
  required String conversationId,
  required String currentUserId,
}) async {
  if (conversationId.isEmpty || currentUserId.isEmpty) return;
  try {
    final convRef = FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId);
    final now = DateTime.now();
    await convRef.set({
      'isBlocked': true,
      'blockedBy': currentUserId,
      'blockedAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    }, SetOptions(merge: true));
  } catch (e) {
    debugPrint('CHAT_BLOCK_ERROR: $e');
    rethrow;
  }
}

// Lifts the block. blockedBy is intentionally left untouched (kept for
// audit/history) — UI decides who's allowed to unblock by comparing it
// against the current user before calling this.
Future<void> unblockConversationInFirestore({
  required String conversationId,
  required String currentUserId,
}) async {
  if (conversationId.isEmpty || currentUserId.isEmpty) return;
  try {
    final convRef = FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId);
    final now = DateTime.now();
    await convRef.set({
      'isBlocked': false,
      'unblockedBy': currentUserId,
      'unblockedAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    }, SetOptions(merge: true));
  } catch (e) {
    debugPrint('CHAT_UNBLOCK_ERROR: $e');
    rethrow;
  }
}

// Resets the current user's unread counter on a conversation and marks their
// unread received messages as read. Safe to call even if the conversation
// doesn't exist yet or has no unread messages — both cases are no-ops.
//
// Hotfix (chat-production-before): this is now non-fatal end-to-end — a
// failure resetting the unread count, or an individual malformed/legacy
// message failing its isRead update, is caught and logged rather than
// thrown, so opening/using the chat screen can never be broken by mark-read
// (see requirement that mark-read failures must not block chat loading or
// sending). Two concrete bugs this fixes:
//  1. Existence is now proven via _findExistingConversationDoc instead of a
//     direct convRef.get(), which firestore.rules denies for a conversation
//     that doesn't exist yet (see that function's comment) — mark-read is a
//     no-op for a conversation nobody has messaged into yet either way.
//  2. The messages subcollection is now read with the same
//     `where('type', whereIn: [...])` filter messagesForConversationProvider
//     uses. The previous unfiltered `.collection('messages').get()` could
//     never be proven by firestore.rules' isNormalMessageType() to return
//     only documents this participant may read (a legacy adminWarning-typed
//     message physically sitting in this subcollection would violate that),
//     so Firestore denied the entire query outright regardless of whether
//     such a document actually exists in a given conversation — this was the
//     exact "markConversationAsRead fails permission-denied" production
//     symptom on an existing conversation whose reads/messages otherwise
//     loaded fine.
Future<void> markConversationAsReadInFirestore({
  required String conversationId,
  required String currentUserId,
}) async {
  if (conversationId.isEmpty || currentUserId.isEmpty) return;

  final existingDoc = await _findExistingConversationDoc(
      senderId: currentUserId, conversationId: conversationId);
  if (existingDoc == null) return;

  final convRef = existingDoc.reference;

  try {
    await convRef.update({
      'unreadCount.$currentUserId': 0,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  } catch (e, st) {
    // Non-fatal: e.g. a legacy conversation whose unreadCount is not a
    // per-participant map. Resetting the unread badge must never block
    // loading/sending or the message isRead pass below.
    debugPrint('CHAT_MARK_READ_UNREAD_COUNT_ERROR: $e');
    debugPrint('CHAT_MARK_READ_UNREAD_COUNT_STACK: $st');
  }

  try {
    // Server-side type filter — see the function-level note above for why
    // an unfiltered get() here is denied outright, not just for legacy
    // shapes.
    final messagesSnap = await convRef
        .collection('messages')
        .where('type', whereIn: ['text', 'image', 'voice']).get();
    final unreadDocs = messagesSnap.docs.where((doc) {
      final data = doc.data();
      return data['receiverId'] == currentUserId && data['isRead'] != true;
    });

    // Individual updates (not one atomic batch) on purpose: a single
    // malformed/legacy message failing firestore.rules' receiverMarkReadBranch
    // (e.g. a non-boolean legacy isRead value) must only skip that message,
    // not fail the whole operation and leave every other unread message in
    // this conversation stuck unread.
    for (final doc in unreadDocs) {
      try {
        await doc.reference.update({'isRead': true});
      } catch (e, st) {
        debugPrint('CHAT_MARK_READ_MESSAGE_ERROR ${doc.id}: $e');
        debugPrint('CHAT_MARK_READ_MESSAGE_STACK: $st');
      }
    }
  } catch (e, st) {
    debugPrint('CHAT_MARK_READ_ERROR: $e');
    debugPrint('CHAT_MARK_READ_STACK: $st');
  }
}

// ─── Chat — Admin (Phase 6G: read-only chat management) ───────────────────────
// Streams every conversation document for admin oversight — unlike
// currentUserConversationsProvider this is NOT scoped to a single
// participant. Read-only: nothing in this phase writes through this provider.
final adminConversationsProvider =
    StreamProvider<List<ConversationModel>>((ref) {
  // Reactive guard: rebuilds (tearing down the old listener and creating a
  // fresh one) whenever login()/logout() changes authProvider — e.g. a
  // Customer login/logout in between two Admin sessions no longer leaves
  // this provider stuck on a stale permission-denied AsyncError from the
  // previous session.
  final user = ref.watch(authProvider);
  // Actual guard: the Firestore SDK evaluates security rules against
  // FirebaseAuth's current user, not our app-level authProvider — querying
  // before this is non-null is what produces permission-denied during the
  // auth-transition window (same pattern as adminFirestoreOrdersProvider).
  final fbUid = FirebaseAuth.instance.currentUser?.uid;
  if (user == null || fbUid == null) {
    return Stream.value(<ConversationModel>[]);
  }
  return FirebaseFirestore.instance
      .collection('conversations')
      .snapshots()
      .handleError((Object e, StackTrace st) {
    debugPrint('ADMIN_CHAT_LOAD_ERROR conversations: $e');
    throw e;
  }).map((snap) {
    final list = <ConversationModel>[];
    for (final doc in snap.docs) {
      try {
        list.add(ConversationModel.fromMap(doc.data(), id: doc.id));
      } catch (e, st) {
        debugPrint('ADMIN_BAD_CONVERSATION_DOC ${doc.id}: $e');
        debugPrint('ADMIN_BAD_CONVERSATION_DOC_STACK: $st');
        // Skip malformed doc — must not crash the whole admin screen.
      }
    }
    try {
      list.sort((a, b) {
        final at = a.updatedAt ?? a.lastMessageTime;
        final bt = b.updatedAt ?? b.lastMessageTime;
        return bt.compareTo(at);
      });
    } catch (e, st) {
      debugPrint('ADMIN_CONVERSATIONS_SORT_ERROR: $e');
      debugPrint('ADMIN_CONVERSATIONS_SORT_STACK: $st');
    }
    return list;
  });
});

// Streams every message in a conversation for admin read-only viewing. Does
// NOT call markConversationAsReadInFirestore anywhere — opening this must
// never affect a user's unread counts.
final adminMessagesForConversationProvider =
    StreamProvider.family<List<MessageModel>, String>((ref, conversationId) {
  if (conversationId.isEmpty) return Stream.value([]);
  // Same reactive + actual auth guard as adminConversationsProvider — avoids
  // subscribing to the nested messages subcollection while auth is null and
  // recreates the listener (per conversationId) after Admin login.
  final user = ref.watch(authProvider);
  final fbUid = FirebaseAuth.instance.currentUser?.uid;
  if (user == null || fbUid == null) {
    return Stream.value(<MessageModel>[]);
  }
  return FirebaseFirestore.instance
      .collection('conversations')
      .doc(conversationId)
      .collection('messages')
      .snapshots()
      .handleError((Object e, StackTrace st) {
    debugPrint('ADMIN_CHAT_LOAD_ERROR messages[$conversationId]: $e');
    throw e;
  }).map((snap) {
    final list = <MessageModel>[];
    for (final doc in snap.docs) {
      try {
        list.add(MessageModel.fromMap(doc.data(), id: doc.id));
      } catch (e, st) {
        debugPrint('ADMIN_BAD_MESSAGE_DOC ${doc.id}: $e');
        debugPrint('ADMIN_BAD_MESSAGE_DOC_STACK: $st');
        // Skip malformed doc — must not crash the whole admin screen.
      }
    }
    try {
      list.sort((a, b) => a.sentAt.compareTo(b.sentAt));
    } catch (e, st) {
      debugPrint('ADMIN_MESSAGES_SORT_ERROR [$conversationId]: $e');
      debugPrint('ADMIN_MESSAGES_SORT_STACK: $st');
    }
    return list;
  });
});

// Every new Admin Warning (adminWarnings subcollection) for a conversation,
// unfiltered — Phase 4D2. Mirrors adminMessagesForConversationProvider's
// read-only, unfiltered pattern: Admin sees every warning regardless of
// target.
final adminAdminWarningsForConversationProvider =
    StreamProvider.family<List<MessageModel>, String>((ref, conversationId) {
  if (conversationId.isEmpty) return Stream.value([]);
  final user = ref.watch(authProvider);
  final fbUid = FirebaseAuth.instance.currentUser?.uid;
  if (user == null || fbUid == null) {
    return Stream.value(<MessageModel>[]);
  }
  return FirebaseFirestore.instance
      .collection('conversations')
      .doc(conversationId)
      .collection('adminWarnings')
      .snapshots()
      .handleError((Object e, StackTrace st) {
    debugPrint('ADMIN_CHAT_LOAD_ERROR adminWarnings[$conversationId]: $e');
    throw e;
  }).map((snap) {
    final list = <MessageModel>[];
    for (final doc in snap.docs) {
      try {
        list.add(MessageModel.fromMap(doc.data(), id: doc.id));
      } catch (e, st) {
        debugPrint('ADMIN_BAD_ADMIN_WARNING_DOC ${doc.id}: $e');
        debugPrint('ADMIN_BAD_ADMIN_WARNING_DOC_STACK: $st');
        // Skip malformed doc — must not crash the whole admin screen.
      }
    }
    return list;
  });
});

// Distinguishes where an Admin monitor timeline entry actually lives —
// Phase 4D2. Legacy type=='adminWarning' documents may still be physically
// sitting inside messages (Phase 4D1 6b decision: intentionally left in
// place, no migration), while every NEW admin warning lives in
// adminWarnings; `type` alone cannot disambiguate the two (both are
// 'adminWarning'). This wrapper is local-only — never serialized to
// Firestore — and exists solely so the Admin "Hide" action can target the
// correct collection for a given entry.
enum AdminChatEntrySource { message, adminWarning }

class AdminChatTimelineEntry {
  final MessageModel message;
  final AdminChatEntrySource source;
  const AdminChatTimelineEntry({required this.message, required this.source});
}

// Combined chronological timeline for the Admin Chat Management monitor
// view — Phase 4D2. Merges adminMessagesForConversationProvider (messages,
// including any legacy adminWarning docs left in place per Phase 4D1's 6b
// decision) with adminAdminWarningsForConversationProvider (new
// adminWarnings), tagging each entry with its real source collection. A
// plain computed provider (not a StreamProvider) that reactively recombines
// whenever either underlying stream re-emits, preserving each source's own
// loading/error AsyncValue. The two source collections are structurally
// distinct (different subcollections, independently auto-generated ids), so
// a plain concatenation can never produce a duplicate entry.
final adminChatTimelineForConversationProvider =
    Provider.family<AsyncValue<List<AdminChatTimelineEntry>>, String>(
        (ref, conversationId) {
  final messagesAsync =
      ref.watch(adminMessagesForConversationProvider(conversationId));
  final warningsAsync =
      ref.watch(adminAdminWarningsForConversationProvider(conversationId));

  if (messagesAsync.hasError) {
    return AsyncValue.error(
        messagesAsync.error!, messagesAsync.stackTrace ?? StackTrace.current);
  }
  if (warningsAsync.hasError) {
    return AsyncValue.error(
        warningsAsync.error!, warningsAsync.stackTrace ?? StackTrace.current);
  }

  final messages = messagesAsync.valueOrNull;
  final warnings = warningsAsync.valueOrNull;
  if (messages == null || warnings == null) {
    return const AsyncValue.loading();
  }

  final combined = <AdminChatTimelineEntry>[
    for (final m in messages)
      AdminChatTimelineEntry(message: m, source: AdminChatEntrySource.message),
    for (final w in warnings)
      AdminChatTimelineEntry(
          message: w, source: AdminChatEntrySource.adminWarning),
  ];
  try {
    combined.sort((a, b) => a.message.sentAt.compareTo(b.message.sentAt));
  } catch (e, st) {
    debugPrint('ADMIN_CHAT_TIMELINE_SORT_ERROR [$conversationId]: $e');
    debugPrint('ADMIN_CHAT_TIMELINE_SORT_STACK: $st');
  }
  return AsyncValue.data(combined);
});

// ─── Chat — Admin Moderation (Phase 6J) ────────────────────────────────────────
// Soft-deletes a message on the admin's behalf. The Firestore doc is never
// physically removed and the admin never rewrites the user's text — it is
// simply cleared, matching the existing user-facing delete behavior.
Future<void> adminHideMessageInFirestore({
  required String conversationId,
  required String messageId,
  required String adminId,
  required String adminName,
}) async {
  if (conversationId.isEmpty || messageId.isEmpty) return;
  try {
    final msgRef = FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId);
    await msgRef.update({
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
      'deletedBy': adminId,
      'deletedByName': adminName,
      'deletedByRole': 'admin',
      'adminDeleted': true,
      'text': '',
    });
  } catch (e) {
    debugPrint('ADMIN_HIDE_MESSAGE_ERROR: $e');
    rethrow;
  }
}

// Soft-deletes a NEW Admin Warning (adminWarnings subcollection) on the
// admin's behalf — Phase 4D2. Mirrors adminHideMessageInFirestore exactly;
// kept as a separate function (rather than a shared helper with a
// collection-name parameter) so each call site stays simple and the two
// Firestore Rules-governed shapes stay independently auditable.
Future<void> adminHideAdminWarningInFirestore({
  required String conversationId,
  required String warningId,
  required String adminId,
  required String adminName,
}) async {
  if (conversationId.isEmpty || warningId.isEmpty) return;
  try {
    final warningRef = FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .collection('adminWarnings')
        .doc(warningId);
    await warningRef.update({
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
      'deletedBy': adminId,
      'deletedByName': adminName,
      'deletedByRole': 'admin',
      'adminDeleted': true,
      'text': '',
    });
  } catch (e) {
    debugPrint('ADMIN_HIDE_ADMIN_WARNING_ERROR: $e');
    rethrow;
  }
}

// Blocks a conversation on the admin's behalf. Only touches the conversation
// doc — message docs are left untouched.
Future<void> adminBlockConversationInFirestore({
  required String conversationId,
  required String adminId,
  required String adminName,
  String? reason,
}) async {
  if (conversationId.isEmpty) return;
  try {
    final convRef = FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId);
    await convRef.set({
      'isBlocked': true,
      'blockedBy': adminId,
      'blockedByName': adminName,
      'blockedByRole': 'admin',
      'blockedAt': FieldValue.serverTimestamp(),
      'blockReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  } catch (e) {
    debugPrint('ADMIN_BLOCK_CONVERSATION_ERROR: $e');
    rethrow;
  }
}

// Lifts an admin-issued (or user-issued) block on a conversation.
Future<void> adminUnblockConversationInFirestore({
  required String conversationId,
  required String adminId,
  required String adminName,
}) async {
  if (conversationId.isEmpty) return;
  try {
    final convRef = FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId);
    await convRef.set({
      'isBlocked': false,
      'unblockedBy': adminId,
      'unblockedByName': adminName,
      'unblockedByRole': 'admin',
      'unblockedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  } catch (e) {
    debugPrint('ADMIN_UNBLOCK_CONVERSATION_ERROR: $e');
    rethrow;
  }
}

// ─── Quick Replies — Firestore (Phase 6H) ──────────────────────────────────────
int _quickReplySort(QuickReplyModel a, QuickReplyModel b) {
  final at =
      a.updatedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  final bt =
      b.updatedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  return bt.compareTo(at);
}

// Active-only quick replies for use inside chat screens (all roles).
// Same auth-readiness guard as messagesForConversationProvider — this
// provider previously had NO auth gating at all (unlike its admin sibling
// below), so a listener opened before/around a Firebase Auth gap would die
// with permission-denied and never recover. See firebaseAuthUidProvider.
final quickRepliesProvider = StreamProvider<List<QuickReplyModel>>((ref) {
  final fbUid = ref.watch(firebaseAuthUidProvider).valueOrNull;
  debugPrint('CHAT_AUTH_FIREBASE_UID [quickReplies] uid=$fbUid');
  if (fbUid == null) {
    return const Stream.empty();
  }

  debugPrint('CHAT_QUICK_REPLIES_PATH quick_replies');
  debugPrint('CHAT_STREAM_CREATED quickReplies uid=$fbUid');

  return FirebaseFirestore.instance
      .collection('quick_replies')
      .snapshots()
      .handleError((Object e, StackTrace st) {
    debugPrint('QUICK_REPLIES_LOAD_ERROR: $e');
    if (e is FirebaseException) {
      debugPrint('CHAT_STREAM_ERROR_CODE quickReplies: ${e.code}');
      debugPrint('CHAT_STREAM_ERROR_MESSAGE quickReplies: ${e.message}');
    }
    throw e;
  }).map((snap) {
    final list = <QuickReplyModel>[];
    for (final doc in snap.docs) {
      try {
        final reply = QuickReplyModel.fromMap(doc.data(), id: doc.id);
        if (reply.isActive) list.add(reply);
      } catch (e, st) {
        debugPrint('BAD_QUICK_REPLY_DOC ${doc.id}: $e');
        debugPrint('BAD_QUICK_REPLY_DOC_STACK: $st');
        // Skip malformed doc — must not crash the whole chat screen.
      }
    }
    try {
      list.sort(_quickReplySort);
    } catch (e, st) {
      debugPrint('QUICK_REPLIES_SORT_ERROR: $e');
      debugPrint('QUICK_REPLIES_SORT_STACK: $st');
    }
    return list;
  });
});

// Admin variant — includes inactive replies so admin can see/reactivate them.
final adminQuickRepliesProvider = StreamProvider<List<QuickReplyModel>>((ref) {
  // Same reactive + actual auth guard as adminConversationsProvider.
  final user = ref.watch(authProvider);
  final fbUid = FirebaseAuth.instance.currentUser?.uid;
  if (user == null || fbUid == null) {
    return Stream.value(<QuickReplyModel>[]);
  }
  return FirebaseFirestore.instance
      .collection('quick_replies')
      .snapshots()
      .handleError((Object e, StackTrace st) {
    debugPrint('QUICK_REPLIES_LOAD_ERROR admin: $e');
    throw e;
  }).map((snap) {
    final list = <QuickReplyModel>[];
    for (final doc in snap.docs) {
      try {
        list.add(QuickReplyModel.fromMap(doc.data(), id: doc.id));
      } catch (e, st) {
        debugPrint('BAD_QUICK_REPLY_DOC ${doc.id}: $e');
        debugPrint('BAD_QUICK_REPLY_DOC_STACK: $st');
        // Skip malformed doc — must not crash the admin screen.
      }
    }
    try {
      list.sort(_quickReplySort);
    } catch (e, st) {
      debugPrint('QUICK_REPLIES_SORT_ERROR admin: $e');
      debugPrint('QUICK_REPLIES_SORT_STACK: $st');
    }
    return list;
  });
});

Future<void> createQuickReplyInFirestore({
  required String text,
  List<String> roles = const [],
  String? createdBy,
}) async {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return;
  try {
    final docRef = FirebaseFirestore.instance.collection('quick_replies').doc();
    final now = DateTime.now();
    await docRef.set({
      'id': docRef.id,
      'text': trimmed,
      'roles': roles,
      'isActive': true,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
      if (createdBy != null) 'createdBy': createdBy,
    });
  } catch (e) {
    debugPrint('QUICK_REPLY_CREATE_ERROR: $e');
    rethrow;
  }
}

// ─── Default Quick Replies (seeded once, never duplicated) ───────────────────
// The twelve general-purpose replies San3a ships with. Each entry has a
// *stable* document id: that id — not the text — is what makes seeding
// idempotent, so re-opening Admin → Chat Management → Quick Replies can never
// add a second copy of the same reply.
//
// Once a default document exists it is treated as fully owned by the admin:
// seeding never rewrites its text (an edited default keeps the edit) and never
// flips isActive back to true (a deleted default stays deleted — deletion here
// is the soft `isActive:false` used everywhere else in this collection, so the
// document still exists and is therefore still "already seeded").
//
// These are ordinary quick_replies documents with empty `roles`, so they are
// visible to every role and behave exactly like admin-created ones in the chat
// screens' quickRepliesProvider.
const List<({String id, String text})> kDefaultQuickReplies = [
  (
    id: 'default_greeting',
    text: "Hello! Thanks for contacting San3a — how can I help you today?"
  ),
  (
    id: 'default_thanks',
    text:
        'Thank you for reaching out. We really appreciate you letting us know.'
  ),
  (
    id: 'default_acknowledge',
    text: "Got it — thanks for the details. I'm looking into it now."
  ),
  (
    id: 'default_more_info',
    text: 'Could you share a few more details so I can help you properly?'
  ),
  (
    id: 'default_order_details',
    text: 'Could you send me the order number and the service you booked?'
  ),
  (
    id: 'default_location',
    text: 'Which city or area is the service needed in?'
  ),
  (
    id: 'default_preferred_time',
    text: 'What day and time would work best for you?'
  ),
  (
    id: 'default_under_review',
    text:
        "Your request is being reviewed by our team, and we'll get back to you shortly."
  ),
  (
    id: 'default_please_wait',
    text:
        "Thanks for your patience — I'm still checking this and will update you as soon as I know more."
  ),
  (
    id: 'default_resolved',
    text: 'Glad we could sort this out! Is everything working for you now?'
  ),
  (
    id: 'default_anything_else',
    text: 'Is there anything else I can help you with?'
  ),
  (
    id: 'default_closing',
    text: 'Thanks again for using San3a. Have a great day!'
  ),
];

// Set once the seed has been attempted in this app session, so repeatedly
// opening the Quick Replies tab doesn't re-read the collection every time.
// The per-document existence check below is the real duplicate guard — this
// flag is only an optimisation, and two admins seeding concurrently is still
// safe because each write targets a fixed document id (a second write is an
// idempotent overwrite of the same content, never an extra row).
bool _defaultQuickRepliesSeedAttempted = false;

/// Creates any of [kDefaultQuickReplies] that don't exist yet. Admin-only —
/// firestore.rules rejects quick_replies creates from every other role, so
/// this must only be called from an admin screen.
///
/// Existing documents (admin-created replies *and* already-seeded defaults,
/// including edited or soft-deleted ones) are never touched.
Future<void> ensureDefaultQuickRepliesSeeded({String? createdBy}) async {
  if (_defaultQuickRepliesSeedAttempted) return;
  _defaultQuickRepliesSeedAttempted = true;
  try {
    final collection = FirebaseFirestore.instance.collection('quick_replies');
    final snap = await collection.get();
    final existingIds = snap.docs.map((d) => d.id).toSet();
    final missing =
        kDefaultQuickReplies.where((r) => !existingIds.contains(r.id)).toList();
    if (missing.isEmpty) return;

    final now = DateTime.now().toIso8601String();
    final batch = FirebaseFirestore.instance.batch();
    for (final reply in missing) {
      batch.set(collection.doc(reply.id), {
        'id': reply.id,
        'text': reply.text,
        'roles': <String>[],
        'isActive': true,
        'createdAt': now,
        'updatedAt': now,
        if (createdBy != null) 'createdBy': createdBy,
      });
    }
    await batch.commit();
    debugPrint('QUICK_REPLY_SEED: created ${missing.length} default replies');
  } catch (e) {
    // Never block the Quick Replies screen on a failed seed — the admin can
    // still read, add, edit and delete replies. Allow a later retry.
    _defaultQuickRepliesSeedAttempted = false;
    debugPrint('QUICK_REPLY_SEED_ERROR: $e');
  }
}

Future<void> updateQuickReplyInFirestore({
  required String replyId,
  String? text,
  List<String>? roles,
  bool? isActive,
}) async {
  if (replyId.isEmpty) return;
  try {
    final data = <String, dynamic>{
      'updatedAt': DateTime.now().toIso8601String()
    };
    if (text != null) data['text'] = text.trim();
    if (roles != null) data['roles'] = roles;
    if (isActive != null) data['isActive'] = isActive;
    await FirebaseFirestore.instance
        .collection('quick_replies')
        .doc(replyId)
        .set(data, SetOptions(merge: true));
  } catch (e) {
    debugPrint('QUICK_REPLY_UPDATE_ERROR: $e');
    rethrow;
  }
}

// Soft delete — sets isActive:false rather than physically removing the doc,
// consistent with the block/unblock audit-preserving pattern used for chat.
Future<void> deleteQuickReplyInFirestore(String replyId) async {
  if (replyId.isEmpty) return;
  try {
    await FirebaseFirestore.instance
        .collection('quick_replies')
        .doc(replyId)
        .set({
      'isActive': false,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  } catch (e) {
    debugPrint('QUICK_REPLY_DELETE_ERROR: $e');
    rethrow;
  }
}

// ─── Chat Reports — Firestore (Phase 6I) ───────────────────────────────────────
// Backs the Admin → Manage Chats → Requests tab. Visible to admin only —
// user chat screens only ever write to this collection, never read from it.
final adminChatReportsProvider = StreamProvider<List<ChatReportModel>>((ref) {
  // Same reactive + actual auth guard as adminConversationsProvider.
  final user = ref.watch(authProvider);
  final fbUid = FirebaseAuth.instance.currentUser?.uid;
  if (user == null || fbUid == null) {
    return Stream.value(<ChatReportModel>[]);
  }
  return FirebaseFirestore.instance
      .collection('chat_reports')
      .snapshots()
      .handleError((Object e, StackTrace st) {
    debugPrint('CHAT_REPORTS_LOAD_ERROR admin: $e');
    throw e;
  }).map((snap) {
    final list = <ChatReportModel>[];
    for (final doc in snap.docs) {
      try {
        list.add(ChatReportModel.fromMap(doc.data(), id: doc.id));
      } catch (e, st) {
        debugPrint('BAD_CHAT_REPORT_DOC ${doc.id}: $e');
        debugPrint('BAD_CHAT_REPORT_DOC_STACK: $st');
        // Skip malformed doc — must not crash the admin screen.
      }
    }
    try {
      list.sort((a, b) {
        final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      });
    } catch (e, st) {
      debugPrint('CHAT_REPORTS_SORT_ERROR: $e');
      debugPrint('CHAT_REPORTS_SORT_STACK: $st');
    }
    return list;
  });
});

// Backs the user-side "My Chat Requests" page (Customer/Professional/
// Contractor) — same collection as adminChatReportsProvider above, scoped to
// only the current user's own reports via reporterId.
final myChatReportsProvider = StreamProvider<List<ChatReportModel>>((ref) {
  final user = ref.watch(authProvider);
  final fbUid = FirebaseAuth.instance.currentUser?.uid;
  if (user == null || fbUid == null) {
    return Stream.value(<ChatReportModel>[]);
  }
  return FirebaseFirestore.instance
      .collection('chat_reports')
      .where('reporterId', isEqualTo: user.id)
      .snapshots()
      .handleError((Object e, StackTrace st) {
    debugPrint('CHAT_REPORTS_LOAD_ERROR mine: $e');
    throw e;
  }).map((snap) {
    final list = <ChatReportModel>[];
    for (final doc in snap.docs) {
      try {
        list.add(ChatReportModel.fromMap(doc.data(), id: doc.id));
      } catch (e, st) {
        debugPrint('BAD_CHAT_REPORT_DOC ${doc.id}: $e');
        debugPrint('BAD_CHAT_REPORT_DOC_STACK: $st');
        // Skip malformed doc — must not crash the user's requests page.
      }
    }
    try {
      list.sort((a, b) {
        final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      });
    } catch (e, st) {
      debugPrint('MY_CHAT_REPORTS_SORT_ERROR: $e');
      debugPrint('MY_CHAT_REPORTS_SORT_STACK: $st');
    }
    return list;
  });
});

Future<void> createChatReportInFirestore({
  required String conversationId,
  required String reporterId,
  required String reporterName,
  required String reporterRole,
  String? reportedUserId,
  String? reportedUserName,
  String? reportedUserRole,
  String? messageId,
  required String reason,
  String? description,
  String priority = 'medium',
}) async {
  if (conversationId.isEmpty || reporterId.isEmpty || reason.trim().isEmpty)
    return;
  try {
    final docRef = FirebaseFirestore.instance.collection('chat_reports').doc();
    final now = DateTime.now();
    await docRef.set({
      'id': docRef.id,
      'conversationId': conversationId,
      'reporterId': reporterId,
      'reporterName': reporterName,
      'reporterRole': reporterRole,
      if (reportedUserId != null) 'reportedUserId': reportedUserId,
      if (reportedUserName != null) 'reportedUserName': reportedUserName,
      if (reportedUserRole != null) 'reportedUserRole': reportedUserRole,
      if (messageId != null) 'messageId': messageId,
      'reason': reason.trim(),
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      'status': 'open',
      'priority': priority,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
      'isSeenByAdmin': false,
    });
  } catch (e) {
    debugPrint('CHAT_REPORT_CREATE_ERROR: $e');
    rethrow;
  }
}

Future<void> updateChatReportStatusInFirestore({
  required String reportId,
  required String status,
  String? adminNote,
}) async {
  if (reportId.isEmpty) return;
  try {
    final data = <String, dynamic>{
      'status': status,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    if (adminNote != null) data['adminNote'] = adminNote;
    await FirebaseFirestore.instance
        .collection('chat_reports')
        .doc(reportId)
        .set(data, SetOptions(merge: true));
  } catch (e) {
    debugPrint('CHAT_REPORT_UPDATE_ERROR: $e');
    rethrow;
  }
}

// Lets the reporting user edit their own request while it is still in the
// initial 'open' status — UI is responsible for enforcing that status gate;
// this only ever touches reason/description/updatedAt, never status or any
// admin-owned field. Uses update() (not set/merge) so an edit can never
// silently recreate a deleted/missing document — it must fail loudly instead.
Future<void> updateChatReportRequestFieldsInFirestore({
  required String reportId,
  required String reason,
  String? description,
}) async {
  if (reportId.isEmpty || reason.trim().isEmpty) return;
  try {
    final data = <String, dynamic>{
      'reason': reason.trim(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
    if (description != null && description.trim().isNotEmpty) {
      data['description'] = description.trim();
    } else {
      data['description'] = FieldValue.delete();
    }
    await FirebaseFirestore.instance
        .collection('chat_reports')
        .doc(reportId)
        .update(data);
  } catch (e) {
    debugPrint('CHAT_REPORT_EDIT_ERROR: $e');
    rethrow;
  }
}

// Marks the given chat reports as seen by Admin (partial update only —
// does not touch status, priority, reporter/reported-user info, or notes).
Future<void> markChatReportsSeenByAdmin(List<String> reportIds) async {
  if (reportIds.isEmpty) return;
  try {
    final batch = FirebaseFirestore.instance.batch();
    for (final id in reportIds) {
      if (id.isEmpty) continue;
      batch.update(
        FirebaseFirestore.instance.collection('chat_reports').doc(id),
        {'isSeenByAdmin': true},
      );
    }
    await batch.commit();
  } catch (e) {
    debugPrint('CHAT_REPORTS_MARK_SEEN_ERROR: $e');
    rethrow;
  }
}

// ─── Favorites (Firestore) ─────────────────────────────────────────────────────
// Document id is '{customerId}_{providerId}' — prevents duplicate favorites
// for the same customer/provider pair.
String _favoriteDocId(String customerId, String providerId) =>
    '${customerId}_$providerId';

final customerFavoritesProvider =
    StreamProvider.family<List<FavoriteModel>, String>((ref, customerId) {
  if (customerId.isEmpty) return Stream.value(const <FavoriteModel>[]);
  return FirebaseFirestore.instance
      .collection('favorites')
      .where('customerId', isEqualTo: customerId)
      .snapshots()
      .map((snap) {
    final list = snap.docs
        .map((d) => FavoriteModel.fromFirestore(d.data(), id: d.id))
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  });
});

final isFavoriteProvider =
    StreamProvider.family<bool, (String customerId, String providerId)>(
        (ref, params) {
  final (customerId, providerId) = params;
  if (customerId.isEmpty || providerId.isEmpty) return Stream.value(false);
  return FirebaseFirestore.instance
      .collection('favorites')
      .doc(_favoriteDocId(customerId, providerId))
      .snapshots()
      .map((doc) => doc.exists);
});

Future<void> addFavoriteInFirestore({
  required String customerId,
  required UserModel provider,
}) async {
  if (customerId.isEmpty) return;
  await FirebaseFirestore.instance
      .collection('favorites')
      .doc(_favoriteDocId(customerId, provider.id))
      .set({
    'customerId': customerId,
    'providerId': provider.id,
    'providerName': provider.fullName,
    'providerRole':
        provider.role == UserRole.contractor ? 'contractor' : 'professional',
    'providerCategory': provider.specialty ??
        (provider.specialties.isNotEmpty ? provider.specialties.first : null),
    'providerImageUrl': provider.avatar,
    'createdAt': DateTime.now().toIso8601String(),
  });
}

Future<void> removeFavoriteInFirestore(
    String customerId, String providerId) async {
  if (customerId.isEmpty || providerId.isEmpty) return;
  await FirebaseFirestore.instance
      .collection('favorites')
      .doc(_favoriteDocId(customerId, providerId))
      .delete();
}

// Minimal, permanently-retained diagnostics for the favorite toggle path —
// this was previously the only unguarded Firestore call in the favorites
// flow, so a permission-denied here (e.g. from a rules regression) failed
// completely silently. Logs the operation, uid, doc path and outcome only;
// never logs tokens/secrets.
Future<void> toggleFavoriteInFirestore({
  required String customerId,
  required UserModel provider,
}) async {
  if (customerId.isEmpty) return;
  final docId = _favoriteDocId(customerId, provider.id);
  final path = 'favorites/$docId';
  final docRef = FirebaseFirestore.instance.collection('favorites').doc(docId);
  try {
    final doc = await docRef.get();
    if (doc.exists) {
      await docRef.delete();
      debugPrint('FAVORITE_TOGGLE: remove ok uid=$customerId path=$path');
    } else {
      await addFavoriteInFirestore(customerId: customerId, provider: provider);
      debugPrint('FAVORITE_TOGGLE: add ok uid=$customerId path=$path');
    }
  } on FirebaseException catch (e) {
    debugPrint('FAVORITE_TOGGLE_ERROR: uid=$customerId path=$path '
        'code=${e.code} message=${e.message}');
    rethrow;
  }
}

// ─── Complaints Provider ──────────────────────────────────────────────────────
class ComplaintsNotifier extends StateNotifier<List<ComplaintModel>> {
  ComplaintsNotifier() : super([]);

  void addComplaint(ComplaintModel complaint) {
    state = [...state, complaint];
  }

  void updateStatus(String id, ComplaintStatus status) {
    state =
        state.map((c) => c.id == id ? c.copyWith(status: status) : c).toList();
  }

  void removeComplaint(String id) {
    state = state.where((c) => c.id != id).toList();
  }

  void updateComplaint(ComplaintModel updated) {
    state = state.map((c) => c.id == updated.id ? updated : c).toList();
  }

  List<ComplaintModel> getByUser(String userId) =>
      state.where((c) => c.userId == userId).toList();
}

final complaintsProvider =
    StateNotifierProvider<ComplaintsNotifier, List<ComplaintModel>>(
  (ref) => ComplaintsNotifier(),
);

// ─── Complaints (Firestore) ───────────────────────────────────────────────────
// Complaints submitted by a specific user (My Complaints), newest first.
final userComplaintsProvider =
    StreamProvider.family<List<ComplaintModel>, String>((ref, userId) {
  if (userId.isEmpty) return Stream.value(const <ComplaintModel>[]);
  return FirebaseFirestore.instance
      .collection('complaints')
      .where('complainantId', isEqualTo: userId)
      .snapshots()
      .map((snap) {
    final list = snap.docs
        .map((d) => ComplaintModel.fromFirestore(d.data(), id: d.id))
        .where((c) => !c.isDeleted && c.status != ComplaintStatus.deleted)
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  });
});

// All non-deleted complaints, for Admin Complaints Center.
final allComplaintsProvider = StreamProvider<List<ComplaintModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('complaints')
      .snapshots()
      .map((snap) {
    final list = snap.docs
        .map((d) => ComplaintModel.fromFirestore(d.data(), id: d.id))
        .where((c) => !c.isDeleted && c.status != ComplaintStatus.deleted)
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  });
});

// Open + in-review complaints only, e.g. for admin badges/counters.
final openComplaintsProvider = Provider<List<ComplaintModel>>((ref) {
  final all =
      ref.watch(allComplaintsProvider).valueOrNull ?? const <ComplaintModel>[];
  return all
      .where((c) =>
          c.status == ComplaintStatus.open ||
          c.status == ComplaintStatus.inReview)
      .toList();
});

final complaintByIdProvider =
    StreamProvider.family<ComplaintModel?, String>((ref, complaintId) {
  if (complaintId.isEmpty) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection('complaints')
      .doc(complaintId)
      .snapshots()
      .map((doc) => doc.exists
          ? ComplaintModel.fromFirestore(doc.data()!, id: doc.id)
          : null);
});

Future<void> addComplaintInFirestore(ComplaintModel complaint) async {
  final ref = FirebaseFirestore.instance.collection('complaints').doc();
  final data = complaint.toMap();
  data['id'] = ref.id;
  await ref.set(data);

  if (complaint.type == ComplaintType.reviewReport) {
    createComplaintNotification(
      targetRole: 'admin',
      title: 'New Review Report',
      message: '${complaint.userName} reported a review.',
      complaintId: ref.id,
      relatedReviewId: complaint.relatedReviewId,
    );
  } else {
    createComplaintNotification(
      targetRole: 'admin',
      title: 'New Complaint',
      message: '${complaint.userName} submitted a complaint.',
      complaintId: ref.id,
    );
  }
}

Future<void> updateComplaintInFirestore(ComplaintModel updated) async {
  final data = updated.toMap();
  data['updatedAt'] = DateTime.now().toIso8601String();
  await FirebaseFirestore.instance
      .collection('complaints')
      .doc(updated.id)
      .set(data, SetOptions(merge: true));
}

Future<void> softDeleteComplaintInFirestore(String complaintId) async {
  await FirebaseFirestore.instance
      .collection('complaints')
      .doc(complaintId)
      .set({
    'status': 'deleted',
    'isDeleted': true,
    'updatedAt': DateTime.now().toIso8601String(),
  }, SetOptions(merge: true));
}

// Takes the full complaint (rather than just its id) so the complainant can
// be notified of the status change without an extra Firestore read.
// No-op (no write, no notification) if the status isn't actually changing.
Future<void> setComplaintStatusInFirestore(
  ComplaintModel complaint,
  ComplaintStatus status, {
  String? adminNote,
}) async {
  if (complaint.status == status) return;

  final now = DateTime.now().toIso8601String();
  await FirebaseFirestore.instance
      .collection('complaints')
      .doc(complaint.id)
      .set({
    'status': ComplaintModel.statusToString(status),
    'updatedAt': now,
    if (status == ComplaintStatus.resolved) 'resolvedAt': now,
    if (adminNote != null) 'adminNote': adminNote,
  }, SetOptions(merge: true));

  String? title;
  String? defaultMessage;
  switch (status) {
    case ComplaintStatus.inReview:
      title = 'Complaint In Review';
      defaultMessage =
          'Your complaint is now being reviewed by an administrator.';
      break;
    case ComplaintStatus.resolved:
      title = 'Complaint Resolved';
      defaultMessage = 'Your complaint has been resolved.';
      break;
    case ComplaintStatus.rejected:
      title = 'Complaint Rejected';
      defaultMessage = 'Your complaint has been rejected.';
      break;
    case ComplaintStatus.open:
    case ComplaintStatus.deleted:
      title = null;
      defaultMessage = null;
  }
  if (title != null) {
    final hasNote = adminNote != null && adminNote.trim().isNotEmpty;
    final message = hasNote ? adminNote.trim() : defaultMessage!;
    // Fire-and-forget (matches createOrderNotification/other auto-notification
    // call sites): a notification failure must not roll back or fail the
    // already-successful status write above (_createAutoNotification already
    // swallows/logs its own errors).
    createComplaintNotification(
      userId: complaint.userId,
      title: title,
      message: message,
      complaintId: complaint.id,
      createdByRole: 'admin',
    );
  }
}

Future<void> updateComplaintPriorityInFirestore(
  String complaintId,
  ComplaintPriority priority,
) async {
  await FirebaseFirestore.instance
      .collection('complaints')
      .doc(complaintId)
      .set({
    'priority': ComplaintModel.priorityToString(priority),
    'updatedAt': DateTime.now().toIso8601String(),
  }, SetOptions(merge: true));
}

Future<void> updateComplaintAdminNoteInFirestore(
    String complaintId, String adminNote) async {
  await FirebaseFirestore.instance
      .collection('complaints')
      .doc(complaintId)
      .set({
    'adminNote': adminNote,
    'updatedAt': DateTime.now().toIso8601String(),
  }, SetOptions(merge: true));
}

// ─── Reviews Provider ─────────────────────────────────────────────────────────
class ReviewsNotifier extends StateNotifier<List<ReviewModel>> {
  ReviewsNotifier() : super(DummyData.reviews);

  void addReview(ReviewModel review) {
    state = [...state, review];
  }

  void removeReview(String id) {
    state = state.where((r) => r.id != id).toList();
  }

  void updateReview(ReviewModel updated) {
    state = state.map((r) => r.id == updated.id ? updated : r).toList();
  }

  List<ReviewModel> getForProvider(String providerId) =>
      state.where((r) => r.providerId == providerId).toList();

  bool hasReviewedOrder(String orderId) =>
      state.any((r) => r.orderId == orderId);

  double avgSpeedForProvider(String providerId) {
    final reviews = getForProvider(providerId);
    if (reviews.isEmpty) return 0;
    return reviews.map((r) => r.speedRating).reduce((a, b) => a + b) /
        reviews.length;
  }

  double avgQualityForProvider(String providerId) {
    final reviews = getForProvider(providerId);
    if (reviews.isEmpty) return 0;
    return reviews.map((r) => r.qualityRating).reduce((a, b) => a + b) /
        reviews.length;
  }

  double avgCommunicationForProvider(String providerId) {
    final reviews = getForProvider(providerId);
    if (reviews.isEmpty) return 0;
    return reviews.map((r) => r.communicationRating).reduce((a, b) => a + b) /
        reviews.length;
  }
}

final reviewsProvider =
    StateNotifierProvider<ReviewsNotifier, List<ReviewModel>>(
  (ref) => ReviewsNotifier(),
);

// ─── Reviews (Firestore) ────────────────────────────────────────────────────────
// Recommended review doc id: '{customerId}_{providerId}_{orderId}' when an order
// is linked, or '{customerId}_{providerId}' for a general (order-less) review —
// this doubles as duplicate prevention for the order-less case.
String reviewDocId(
    {required String customerId, required String providerId, String? orderId}) {
  if (orderId != null && orderId.isNotEmpty)
    return '${customerId}_${providerId}_$orderId';
  return '${customerId}_$providerId';
}

// A single malformed review document must never break the whole stream for
// a provider (and therefore their rating/notifications), so parsing failures
// are swallowed here and that doc is skipped — mirrors _tryParseNotification.
ReviewModel? _tryParseReview(Map<String, dynamic> data, String id) {
  try {
    return ReviewModel.fromFirestore(data, id: id);
  } catch (e) {
    debugPrint('REVIEW_PARSE_FAILED doc=$id error=$e');
    return null;
  }
}

// A review counts as visible unless it has been explicitly hidden/deleted —
// missing/visible/active all read as visible so partially-written or legacy
// docs still show up instead of vanishing.
bool _isVisibleReview(ReviewModel r) {
  if (r.isHidden) return false;
  if (r.status == 'hidden' || r.status == 'deleted') return false;
  return true;
}

// Reads all reviews for a provider from Firestore and filters visible ones
// client-side (avoids composite-index requirements), newest first.
final providerReviewsProvider =
    StreamProvider.family<List<ReviewModel>, String>((ref, providerId) {
  if (providerId.isEmpty) return Stream.value(const <ReviewModel>[]);
  debugPrint('PROVIDER_REVIEWS_PROVIDER_ID: $providerId');
  return FirebaseFirestore.instance
      .collection('reviews')
      .where('providerId', isEqualTo: providerId)
      .snapshots()
      .map((snap) {
    final parsed = snap.docs
        .map((d) => _tryParseReview(d.data(), d.id))
        .whereType<ReviewModel>()
        .toList();
    debugPrint(
        'PROVIDER_REVIEWS_RAW_COUNT: providerId=$providerId count=${parsed.length}');
    final list = parsed.where(_isVisibleReview).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    debugPrint(
        'PROVIDER_REVIEWS_VISIBLE_COUNT: providerId=$providerId count=${list.length}');
    return list;
  });
});

// Streams a single review document by id — used for notification-tap
// deep-linking (a review notification carries a real relatedReviewId; see
// createReviewNotification) where the provider-scoped providerReviewsProvider
// isn't usable since the provider id isn't known up front. Deliberately does
// NOT filter through _isVisibleReview: a hidden review should still open for
// the notification recipient as long as Firestore access allows the read.
final reviewByIdProvider =
    StreamProvider.family<ReviewModel?, String>((ref, reviewId) {
  if (reviewId.isEmpty) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection('reviews')
      .doc(reviewId)
      .snapshots()
      .map((doc) => doc.exists ? _tryParseReview(doc.data()!, doc.id) : null);
});

// All reviews (any status), for Admin Review Management.
final allReviewsProvider = StreamProvider<List<ReviewModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('reviews')
      .snapshots()
      .map((snap) {
    final list = snap.docs
        .map((d) => _tryParseReview(d.data(), d.id))
        .whereType<ReviewModel>()
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  });
});

final providerAverageRatingProvider =
    Provider.family<({double average, int count}), String>((ref, providerId) {
  final reviews = ref.watch(providerReviewsProvider(providerId)).valueOrNull ??
      const <ReviewModel>[];
  debugPrint(
      'PROVIDER_AVG_PROVIDER_ID: $providerId PROVIDER_AVG_COUNT: ${reviews.length}');
  if (reviews.isEmpty) return (average: 0.0, count: 0);
  final avg =
      reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
  return (average: avg, count: reviews.length);
});

// Looks up the order-less "general" review a customer may already have left
// for a provider, so the Add Review flow can decide create-vs-update.
final customerReviewForProviderProvider =
    StreamProvider.family<ReviewModel?, (String customerId, String providerId)>(
        (ref, params) {
  final (customerId, providerId) = params;
  if (customerId.isEmpty || providerId.isEmpty) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection('reviews')
      .doc(reviewDocId(customerId: customerId, providerId: providerId))
      .snapshots()
      .map((doc) => doc.exists
          ? ReviewModel.fromFirestore(doc.data()!, id: doc.id)
          : null);
});

Future<bool> reviewExistsInFirestore({
  required String customerId,
  required String providerId,
  String? orderId,
}) async {
  final doc = await FirebaseFirestore.instance
      .collection('reviews')
      .doc(reviewDocId(
          customerId: customerId, providerId: providerId, orderId: orderId))
      .get();
  return doc.exists;
}

Future<void> addReviewInFirestore({
  required UserModel customer,
  required UserModel provider,
  String? orderId,
  String? relatedService,
  required double speedRating,
  required double qualityRating,
  required double communicationRating,
  Map<String, double>? criteriaRatings,
  required String comment,
}) async {
  final docId = reviewDocId(
      customerId: customer.id, providerId: provider.id, orderId: orderId);
  final reviewDoc = FirebaseFirestore.instance.collection('reviews').doc(docId);
  final existedBefore = await reviewDoc.get();
  final isNewReview = !existedBefore.exists;
  final now = DateTime.now();
  debugPrint('REVIEW_SAVE_CUSTOMER_ID: ${customer.id}');
  debugPrint('REVIEW_SAVE_PROVIDER_ID: ${provider.id}');
  debugPrint('REVIEW_SAVE_DOC_ID: $docId');
  debugPrint('REVIEW_SAVE_IS_NEW: $isNewReview');
  final review = ReviewModel(
    id: docId,
    orderId: orderId,
    customerId: customer.id,
    customerName: customer.fullName,
    providerId: provider.id,
    providerName: provider.fullName,
    providerRole:
        provider.role == UserRole.contractor ? 'contractor' : 'professional',
    speedRating: speedRating,
    qualityRating: qualityRating,
    communicationRating: communicationRating,
    criteriaRatings: criteriaRatings ?? const {},
    comment: comment,
    relatedService: relatedService,
    createdAt: isNewReview
        ? now
        : ReviewModel.fromFirestore(existedBefore.data()!, id: docId).createdAt,
    updatedAt: isNewReview ? null : now,
  );

  if (isNewReview) {
    // Create: the full document, exactly the field set the create rule's
    // keys().hasOnly([...]) allows (firestore.rules — reviews create).
    await reviewDoc.set(review.toMap());
  } else {
    // Re-submit of an existing review.
    //
    // This used to be the same full-document set(review.toMap()), which is
    // what produced [cloud_firestore/permission-denied]: set() without merge
    // rewrites *every* field from the ReviewModel constructor's defaults, so
    // it reset status -> 'visible', isHidden -> false, reportCount -> 0 and
    // dropped reportReason, and it also rewrote customerName/providerName/
    // providerRole/orderId. The reviews update rule's customer branch only
    // permits the keys listed below, so any of those extra fields landing in
    // diff().affectedKeys() denied the whole write — which is why re-submitting
    // a review that had been reported, hidden, or written when the customer's
    // display name differed always failed.
    //
    // Now only the customer-editable content fields are written, via update()
    // rather than set(), so every moderation/system field already stored in
    // Firestore is left untouched: status, isHidden, reportCount, reportReason,
    // customerId, providerId, providerRole, customerName, providerName,
    // orderId and createdAt.
    //
    // Keys below mirror firestore.rules exactly:
    //   ['comment', 'speedRating', 'qualityRating', 'communicationRating',
    //    'criteriaRatings', 'relatedService', 'rating', 'updatedAt']
    //
    // criteriaRatings/relatedService are written only when present, matching
    // ReviewModel.toMap()'s own conditional serialization — a null/empty value
    // leaves whatever is already stored alone instead of writing a null.
    await reviewDoc.update(<String, dynamic>{
      'comment': comment,
      'speedRating': speedRating,
      'qualityRating': qualityRating,
      'communicationRating': communicationRating,
      if (criteriaRatings != null && criteriaRatings.isNotEmpty)
        'criteriaRatings': criteriaRatings,
      if (relatedService != null) 'relatedService': relatedService,
      // Derived from criteriaRatings when present — same source of truth as
      // ReviewModel.toMap()'s 'rating', so create and edit stay consistent.
      'rating': review.overallRating,
      'updatedAt': now.toIso8601String(),
    });
  }

  // Only notify on a brand-new review — an edit to an existing one shouldn't
  // re-notify the provider. Wrapped in try/catch so a notification failure
  // never surfaces as a review-save failure to the customer.
  if (isNewReview) {
    debugPrint('REVIEW_NOTIFICATION_PROVIDER_ID: ${provider.id}');
    try {
      await createReviewNotification(
        userId: provider.id,
        title: 'New Rating',
        message: '${customer.fullName} left you a new review.',
        reviewId: docId,
        relatedUserId: customer.id,
      );
      debugPrint('REVIEW_NOTIFICATION_CREATED: true');
    } catch (e) {
      debugPrint('REVIEW_NOTIFICATION_CREATED: false error=$e');
    }
  }
}

Future<void> updateReviewInFirestore(ReviewModel updated) async {
  final data = updated.toMap();
  data['updatedAt'] = DateTime.now().toIso8601String();
  await FirebaseFirestore.instance
      .collection('reviews')
      .doc(updated.id)
      .set(data, SetOptions(merge: true));
}

// update() (not set/merge) — a stale or wrong reviewId must throw NOT_FOUND
// instead of silently creating a new partial "ghost" document. set(...,
// merge: true) never fails just because the target id doesn't exist, which
// previously let the admin see a false "Review hidden" success while the
// real review document stayed untouched.
Future<void> hideReviewInFirestore(String reviewId) async {
  debugPrint('REVIEW_HIDE_TARGET_DOC_ID: $reviewId');
  await FirebaseFirestore.instance.collection('reviews').doc(reviewId).update({
    'isHidden': true,
    'status': 'hidden',
    'updatedAt': DateTime.now().toIso8601String(),
  });
}

Future<void> unhideReviewInFirestore(String reviewId) async {
  debugPrint('REVIEW_UNHIDE_TARGET_DOC_ID: $reviewId');
  await FirebaseFirestore.instance.collection('reviews').doc(reviewId).update({
    'isHidden': false,
    'status': 'visible',
    'updatedAt': DateTime.now().toIso8601String(),
  });
}

// Soft delete only — never remove the document, per moderation policy.
Future<void> deleteReviewInFirestore(String reviewId) async {
  await FirebaseFirestore.instance.collection('reviews').doc(reviewId).set({
    'isHidden': true,
    'status': 'deleted',
    'updatedAt': DateTime.now().toIso8601String(),
  }, SetOptions(merge: true));
}

Future<void> markReviewSafeInFirestore(String reviewId) async {
  await FirebaseFirestore.instance.collection('reviews').doc(reviewId).set({
    'isHidden': false,
    'status': 'visible',
    'reportCount': 0,
    'reportReason': null,
    'updatedAt': DateTime.now().toIso8601String(),
  }, SetOptions(merge: true));
}

Future<void> reportReviewInFirestore(String reviewId, String reason) async {
  await FirebaseFirestore.instance.collection('reviews').doc(reviewId).set({
    'reportCount': FieldValue.increment(1),
    'reportReason': reason,
    'updatedAt': DateTime.now().toIso8601String(),
  }, SetOptions(merge: true));
}

// ─── Notifications (Firestore) ───────────────────────────────────────────────
// Phase 5C2: notifications/{id} content is immutable after creation (never
// carries this user's own isRead/isDeleted — those legacy shared fields are
// ignored for effective UI state, see mergeNotifications below). Per-user
// read/delete state lives independently at
// users/{uid}/notification_states/{notificationId} — see
// UserNotificationView / NotificationStateView (shared/models/models.dart).
// A single malformed content or state document must never break the
// notification list for everyone else, so parsing failures are swallowed
// here and that doc is skipped rather than allowed to throw inside a
// stream's .map().
NotificationModel? _tryParseNotification(Map<String, dynamic> data, String id) {
  try {
    return NotificationModel.fromFirestore(data, id: id);
  } catch (_) {
    return null;
  }
}

NotificationStateView? _tryParseNotificationState(Map<String, dynamic> data) {
  try {
    return NotificationStateView.fromFirestore(data);
  } catch (_) {
    return null;
  }
}

// Content stream A — notifications addressed directly to this user
// (where('userId', isEqualTo: uid) — Rules-compatible per Phase 5C2, unlike
// the old unfiltered collection listen it replaces).
final _personalNotificationContentProvider =
    StreamProvider.family<List<NotificationModel>, String>((ref, uid) {
  if (uid.isEmpty) return Stream.value(const <NotificationModel>[]);
  return FirebaseFirestore.instance
      .collection('notifications')
      .where('userId', isEqualTo: uid)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => _tryParseNotification(d.data(), d.id))
          .whereType<NotificationModel>()
          .toList());
});

// Content stream B — role-wide/broadcast notifications
// (where('targetRole', whereIn: [role, 'all']) — Rules-compatible per Phase
// 5C2).
final _roleNotificationContentProvider =
    StreamProvider.family<List<NotificationModel>, String>((ref, roleStr) {
  if (roleStr.isEmpty) return Stream.value(const <NotificationModel>[]);
  return FirebaseFirestore.instance
      .collection('notifications')
      .where('targetRole', whereIn: [roleStr, 'all'])
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => _tryParseNotification(d.data(), d.id))
          .whereType<NotificationModel>()
          .toList());
});

// This user's own per-notification read/delete state
// (users/{uid}/notification_states), keyed by notification document id.
final _notificationStatesProvider =
    StreamProvider.family<Map<String, NotificationStateView>, String>(
        (ref, uid) {
  if (uid.isEmpty) {
    return Stream.value(const <String, NotificationStateView>{});
  }
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('notification_states')
      .snapshots()
      .map((snap) {
    final map = <String, NotificationStateView>{};
    for (final d in snap.docs) {
      final st = _tryParseNotificationState(d.data());
      if (st != null) map[d.id] = st;
    }
    return map;
  });
});

// Merges the two content streams (deduplicated by document id — a
// malformed/legacy document could in principle match both queries at once)
// with this user's own state overlay. Legacy isRead/isDeleted on the shared
// content document are intentionally never read here (Phase 5C1B trade-off:
// no state doc means unread/not-deleted, always — see Phase 5C2 report §I).
List<UserNotificationView> mergeNotifications(
  List<NotificationModel> personal,
  List<NotificationModel> roleWide,
  Map<String, NotificationStateView> states,
) {
  final byId = <String, NotificationModel>{};
  for (final n in personal) {
    byId[n.id] = n;
  }
  for (final n in roleWide) {
    byId[n.id] = n;
  }
  final list = byId.values
      .map((n) {
        final st = states[n.id];
        return UserNotificationView(
          notification: n,
          isRead: st?.isRead ?? false,
          isDeleted: st?.isDeleted ?? false,
          readAt: st?.readAt,
        );
      })
      .where((v) => !v.isDeleted)
      .toList()
    ..sort(
        (a, b) => b.notification.createdAt.compareTo(a.notification.createdAt));
  return list;
}

// Merges the two constrained content streams with this user's own state
// subcollection into the effective per-user notification list. A plain
// Provider (not a StreamProvider) so it never opens its own Firestore
// listener — it only ref.watch()es the three underlying StreamProviders,
// which Riverpod caches per family key, so rebuilding this provider never
// duplicates a live listener.
final userNotificationsProvider = Provider.family<
    AsyncValue<List<UserNotificationView>>,
    ({String userId, UserRole role})>((ref, params) {
  if (params.userId.isEmpty) {
    return const AsyncValue.data(<UserNotificationView>[]);
  }
  final roleStr = NotificationModel.roleToString(params.role);
  final personal =
      ref.watch(_personalNotificationContentProvider(params.userId));
  final roleWide = ref.watch(_roleNotificationContentProvider(roleStr));
  final states = ref.watch(_notificationStatesProvider(params.userId));

  if (personal.hasValue && roleWide.hasValue && states.hasValue) {
    return AsyncValue.data(
        mergeNotifications(personal.value!, roleWide.value!, states.value!));
  }

  // Degrade gracefully instead of crashing/blanking the screen: if every
  // stream that hasn't (re)loaded yet still has a previously cached value
  // (e.g. one dropped a connection momentarily while the others are fine),
  // keep showing the merged cached view rather than surfacing loading/error.
  final personalCached = personal.valueOrNull;
  final roleCached = roleWide.valueOrNull;
  final statesCached = states.valueOrNull;
  if (personalCached != null || roleCached != null || statesCached != null) {
    return AsyncValue.data(mergeNotifications(
      personalCached ?? const <NotificationModel>[],
      roleCached ?? const <NotificationModel>[],
      statesCached ?? const <String, NotificationStateView>{},
    ));
  }

  // Nothing usable has ever loaded from any of the three streams yet:
  // surface a real error only if one of them actually failed, otherwise
  // this is still initial loading — never let an AsyncError propagate
  // uncaught into a widget build.
  if (personal.hasError) {
    return AsyncValue.error(
        personal.error!, personal.stackTrace ?? StackTrace.current);
  }
  if (roleWide.hasError) {
    return AsyncValue.error(
        roleWide.error!, roleWide.stackTrace ?? StackTrace.current);
  }
  if (states.hasError) {
    return AsyncValue.error(
        states.error!, states.stackTrace ?? StackTrace.current);
  }
  return const AsyncValue.loading();
});

final unreadNotificationsCountProvider =
    Provider.family<int, ({String userId, UserRole role})>((ref, params) {
  final list = ref.watch(userNotificationsProvider(params)).valueOrNull ??
      const <UserNotificationView>[];
  return list.where((v) => !v.isRead).length;
});

// Single-document content lookup by id — content only, no per-user state
// overlay. Callers needing effective read/delete state must go through
// userNotificationsProvider instead.
final notificationByIdProvider =
    StreamProvider.family<NotificationModel?, String>((ref, notificationId) {
  if (notificationId.isEmpty) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection('notifications')
      .doc(notificationId)
      .snapshots()
      .map((doc) =>
          doc.exists ? _tryParseNotification(doc.data()!, doc.id) : null);
});

Future<void> addNotificationInFirestore(NotificationModel notification) async {
  final ref = FirebaseFirestore.instance.collection('notifications').doc();
  final data = notification.toMap();
  data['id'] = ref.id;
  await ref.set(data);
}

DocumentReference<Map<String, dynamic>> _notificationStateRef(
        String uid, String notificationId) =>
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notification_states')
        .doc(notificationId);

// Marks a single notification read for exactly this user — writes only
// users/{uid}/notification_states/{notificationId} (merge/upsert), never
// notifications/{notificationId} itself (Phase 5C2: content is immutable
// after creation, so another recipient of the same role/all notification is
// never affected — see Phase 5C1B).
Future<void> markNotificationReadInFirestore(
    String uid, String notificationId) async {
  if (uid.isEmpty || notificationId.isEmpty) return;
  final now = DateTime.now().toIso8601String();
  await _notificationStateRef(uid, notificationId).set({
    'notificationId': notificationId,
    'userId': uid,
    'isRead': true,
    'readAt': now,
    'updatedAt': now,
  }, SetOptions(merge: true));
}

// Firestore caps a single batch at 500 write operations, but that is NOT the
// binding constraint here: the `notification_states` Security Rules create()
// branch (firestore.rules) calls both exists() and get() on
// notifications/{notifId} to verify visibility — 2 doc-access calls per
// brand-new state document. Firestore hard-caps get()/exists() calls at 20
// total per single batched write/transaction, independent of the 500-op
// ceiling. Proven via a rules_tests emulator probe (batch of 10 first-time
// mark-read creates succeeds; 11 is denied outright, "Service call error"
// on the exists() call for the 11th+ document) — this is exactly why a
// customer with 33 unread notifications had 100% of their "Mark all read"
// batch denied: 450 was never actually reachable before it. 8 leaves
// headroom under the proven 10-document/20-call ceiling.
const int _notificationReadBatchChunkSize = 8;

// Pure, Firestore-free — extracted so mark-all's "which notifications count
// as unread" logic can be unit tested directly (see
// test/notification_mark_all_test.dart) without a live Firestore instance.
// A notification is effectively unread/visible when it has no state doc yet,
// or a state doc that is neither deleted nor read. NotificationModel keys
// are always real Firestore document ids (never a legacy content 'id'
// field — see _tryParseNotification/NotificationModel.fromFirestore), so
// this is legacy-safe for old documents missing that field.
List<String> computeUnreadVisibleNotificationIds(
  Map<String, NotificationModel> byId,
  Map<String, NotificationStateView> stateById,
) {
  return byId.values
      .where((n) {
        final st = stateById[n.id];
        return !(st?.isDeleted ?? false) && !(st?.isRead ?? false);
      })
      .map((n) => n.id)
      .toList();
}

// Pure — splits a flat id list into fixed-size chunks, preserving order.
// Extracted so batching math (including >500-notification accounts) is unit
// testable without a live Firestore batch.
List<List<String>> chunkNotificationIds(List<String> ids, int chunkSize) {
  final chunks = <List<String>>[];
  for (var i = 0; i < ids.length; i += chunkSize) {
    chunks.add(ids.skip(i).take(chunkSize).toList());
  }
  return chunks;
}

// Marks every notification currently visible to this user/role as read, by
// writing only into this user's own state subcollection — never into
// notification content, and never into another user's state. Re-derives the
// visible set from the same two constrained content queries the live
// provider uses (rather than requiring a caller-supplied list) so this
// function stays self-contained. NotificationModel.id always comes from the
// real Firestore document id (see _tryParseNotification/fromFirestore),
// never a legacy content 'id' field, so old documents missing that field
// are still handled correctly.
Future<void> markAllNotificationsReadInFirestore(
    String userId, UserRole role) async {
  if (userId.isEmpty) return;
  final roleStr = NotificationModel.roleToString(role);
  final db = FirebaseFirestore.instance;

  // Best-effort only — used purely for diagnostics below, never for access
  // control (Rules re-check visibility server-side regardless).
  String storedRole = 'unknown';
  try {
    final userDoc = await db.collection('users').doc(userId).get();
    storedRole = userDoc.data()?['role'] as String? ?? 'missing';
  } catch (e) {
    storedRole = 'lookup_failed';
  }

  final contentSnaps = await Future.wait([
    db.collection('notifications').where('userId', isEqualTo: userId).get(),
    db
        .collection('notifications')
        .where('targetRole', whereIn: [roleStr, 'all']).get(),
  ]);
  final byId = <String, NotificationModel>{};
  for (final snap in contentSnaps) {
    for (final doc in snap.docs) {
      final n = _tryParseNotification(doc.data(), doc.id);
      if (n != null) byId[n.id] = n;
    }
  }

  final stateSnap = await db
      .collection('users')
      .doc(userId)
      .collection('notification_states')
      .get();
  final stateById = <String, NotificationStateView>{};
  for (final doc in stateSnap.docs) {
    final st = _tryParseNotificationState(doc.data());
    if (st != null) stateById[doc.id] = st;
  }

  final unreadVisibleIds = computeUnreadVisibleNotificationIds(byId, stateById);

  debugPrint('NOTIFICATION_MARK_ALL_DEBUG: uid=$userId role=$roleStr '
      'storedRole=$storedRole visibleCount=${byId.length} '
      'unreadCount=${unreadVisibleIds.length} '
      'firstIds=${unreadVisibleIds.take(5).toList()}');

  if (unreadVisibleIds.isEmpty) return;

  final now = DateTime.now().toIso8601String();
  var batchCount = 0;
  final chunks =
      chunkNotificationIds(unreadVisibleIds, _notificationReadBatchChunkSize);
  for (final chunk in chunks) {
    final batch = db.batch();
    for (final id in chunk) {
      batch.set(
        _notificationStateRef(userId, id),
        {
          'notificationId': id,
          'userId': userId,
          'isRead': true,
          'readAt': now,
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );
    }
    batchCount++;
    if (batchCount == 1) {
      debugPrint('NOTIFICATION_MARK_ALL_DEBUG: firstStatePath='
          'users/$userId/notification_states/${chunk.first} '
          'writesInFirstBatch=${chunk.length} '
          'chunkSize=$_notificationReadBatchChunkSize');
    }
    try {
      await batch.commit();
      debugPrint('NOTIFICATION_MARK_ALL_DEBUG: batch#$batchCount commit OK '
          '(${chunk.length} writes)');
    } catch (e) {
      final code = e is FirebaseException ? e.code : e.runtimeType.toString();
      debugPrint('NOTIFICATION_MARK_ALL_ERROR: batch#$batchCount commit '
          'FAILED code=$code error=$e');
      rethrow;
    }
  }
  debugPrint('NOTIFICATION_MARK_ALL_DEBUG: done totalBatches=$batchCount '
      'totalWritten=${unreadVisibleIds.length}');
}

// Soft-deletes (hides) a single notification for exactly this user — writes
// only users/{uid}/notification_states/{notificationId} (merge/upsert, so an
// existing isRead state survives the delete), never notification content.
// No UI wires this up yet (unchanged since Phase 5C1), kept secure and
// functional for when one does.
Future<void> softDeleteNotificationInFirestore(
    String uid, String notificationId) async {
  if (uid.isEmpty || notificationId.isEmpty) return;
  await _notificationStateRef(uid, notificationId).set({
    'notificationId': notificationId,
    'userId': uid,
    'isDeleted': true,
    'updatedAt': DateTime.now().toIso8601String(),
  }, SetOptions(merge: true));
}

// Broadcasts are targetRole-based only — never one document per user.
// targetRole must be one of: 'all', 'customer', 'professional', 'contractor'.
Future<void> sendBroadcastNotificationInFirestore({
  required String message,
  required String targetRole,
  String? createdById,
  String? createdByName,
}) async {
  final ref = FirebaseFirestore.instance.collection('notifications').doc();
  final notification = NotificationModel(
    id: ref.id,
    targetRole: targetRole,
    title: 'Broadcast Message',
    message: message,
    type: NotificationType.broadcast,
    createdAt: DateTime.now(),
    createdById: createdById,
    createdByName: createdByName,
    createdByRole: 'admin',
  );
  final data = notification.toMap();
  data['id'] = ref.id;
  await ref.set(data);
}

// Multi-audience broadcast: one notification document per distinct targetRole.
//
// This is the only shape firestore.rules accepts — broadcastCreateValid()
// requires targetRole to be a single string from
// ['all','customer','professional','contractor'] — and it is also what makes
// duplicate delivery impossible: a user has exactly one role, each role is
// written at most once, and 'all' is never combined with a specific role
// (callers normalize via broadcastTargetsToRoleStrings). Reuses
// sendBroadcastNotificationInFirestore per role rather than reimplementing
// the document shape, so single- and multi-audience sends stay identical.
//
// Roles are written sequentially and any failure propagates, so a partially
// delivered broadcast surfaces as an error instead of silently reporting
// success.
Future<void> sendBroadcastNotificationsInFirestore({
  required String message,
  required List<String> targetRoles,
  String? createdById,
  String? createdByName,
}) async {
  final roles = targetRoles.toSet().toList();
  if (roles.isEmpty) return;
  for (final role in roles) {
    await sendBroadcastNotificationInFirestore(
      message: message,
      targetRole: role,
      createdById: createdById,
      createdByName: createdByName,
    );
  }
}

// ─── Automatic Notifications (Phase 9A-2) ────────────────────────────────────
// Best-effort only: notification creation must never break the business
// action that triggered it, so every call site swallows its own errors here
// instead of letting them propagate back to the caller.
Future<void> _createAutoNotification(NotificationModel notification) async {
  try {
    await addNotificationInFirestore(notification);
  } catch (e) {
    debugPrint('AUTO_NOTIFICATION_FAILED: $e');
  }
}

Future<void> createOrderNotification({
  required String userId,
  required String title,
  required String message,
  required String orderId,
}) {
  if (userId.isEmpty) return Future.value();
  return _createAutoNotification(NotificationModel(
    id: '',
    userId: userId,
    title: title,
    message: message,
    type: NotificationType.orderUpdate,
    relatedOrderId: orderId,
    createdAt: DateTime.now(),
  ));
}

Future<void> createReviewNotification({
  required String userId,
  required String title,
  required String message,
  required String reviewId,
  String? relatedUserId,
}) {
  if (userId.isEmpty) return Future.value();
  return _createAutoNotification(NotificationModel(
    id: '',
    userId: userId,
    title: title,
    message: message,
    type: NotificationType.review,
    relatedReviewId: reviewId,
    relatedUserId: relatedUserId,
    createdAt: DateTime.now(),
  ));
}

Future<void> createComplaintNotification({
  String? userId,
  String? targetRole,
  required String title,
  required String message,
  required String complaintId,
  String? relatedReviewId,
  String? createdByRole,
}) {
  if ((userId == null || userId.isEmpty) &&
      (targetRole == null || targetRole.isEmpty)) {
    return Future.value();
  }
  return _createAutoNotification(NotificationModel(
    id: '',
    userId: userId,
    targetRole: targetRole,
    title: title,
    message: message,
    type: NotificationType.complaint,
    relatedComplaintId: complaintId,
    relatedReviewId: relatedReviewId,
    createdAt: DateTime.now(),
    createdByRole: createdByRole,
  ));
}

// Notifies a user that an Admin edited their profile (Admin Users → Edit
// User). Uses the existing generic 'system' notification type since there
// is no dedicated profile-update type, and 'system' is already handled by
// every role's notifications screen.
Future<void> createProfileUpdateNotification({
  required String userId,
  String? createdById,
  String? createdByName,
}) {
  if (userId.isEmpty) return Future.value();
  return _createAutoNotification(NotificationModel(
    id: '',
    userId: userId,
    title: 'Profile Updated',
    message: 'An administrator updated your profile information.',
    type: NotificationType.system,
    createdAt: DateTime.now(),
    createdById: createdById,
    createdByName: createdByName,
    createdByRole: 'admin',
  ));
}

// Notifies a contractor that an Admin edited one of their workers' profile
// information (Admin Users → Contractor details → Workers/Team → Edit
// Worker). Uses the same generic 'system' notification type as
// createProfileUpdateNotification since there is no dedicated worker-update
// type, and 'system' is already handled by the Contractor Notifications UI.
Future<void> createWorkerUpdateNotification({
  required String contractorId,
  required String workerName,
  String? createdById,
  String? createdByName,
}) {
  if (contractorId.isEmpty) return Future.value();
  return _createAutoNotification(NotificationModel(
    id: '',
    userId: contractorId,
    title: 'Worker Profile Updated',
    message:
        'An administrator updated the profile information for $workerName.',
    type: NotificationType.system,
    createdAt: DateTime.now(),
    createdById: createdById,
    createdByName: createdByName,
    createdByRole: 'admin',
  ));
}

// Sends a direct Admin warning to a specific user (Admin Users → Warn User).
// Unlike createProfileUpdateNotification/createWorkerUpdateNotification
// above, this writes to Firestore directly and lets failures propagate — the
// Warn User dialog needs a real success/failure result to show the Admin,
// not one silently swallowed by _createAutoNotification. Uses the existing
// generic 'system' notification type (no dedicated warning type exists) so
// it renders through the same Notifications UI as every other system
// notice, and is picked up live by userNotificationsProvider via the
// matching userId.
Future<void> sendUserWarningNotification({
  required String userId,
  required String message,
  String? createdById,
  String? createdByName,
}) async {
  final ref = FirebaseFirestore.instance.collection('notifications').doc();
  final notification = NotificationModel(
    id: ref.id,
    userId: userId,
    title: 'Account Warning',
    message: message,
    type: NotificationType.system,
    createdAt: DateTime.now(),
    createdById: createdById,
    createdByName: createdByName,
    createdByRole: 'admin',
  );
  final data = notification.toMap();
  data['id'] = ref.id;
  await ref.set(data);
}

// Phase 5C3: relatedCategoryRequestId is required for every call site (both
// requester->admin and Admin->requester) so Firestore Rules can always prove
// the notification corresponds to a real category_requests document — no
// producer may create a category_request notification without it.
Future<void> createCategoryRequestNotification({
  String? userId,
  String? targetRole,
  required String title,
  required String message,
  required String categoryRequestId,
}) {
  if (categoryRequestId.isEmpty) return Future.value();
  if ((userId == null || userId.isEmpty) &&
      (targetRole == null || targetRole.isEmpty)) {
    return Future.value();
  }
  return _createAutoNotification(NotificationModel(
    id: '',
    userId: userId,
    targetRole: targetRole,
    title: title,
    message: message,
    type: NotificationType.categoryRequest,
    relatedCategoryRequestId: categoryRequestId,
    createdAt: DateTime.now(),
  ));
}

// ─── Review Criteria (Firestore) ─────────────────────────────────────────────
Future<void> seedDefaultReviewCriteriaIfEmpty() async {
  final col = FirebaseFirestore.instance.collection('review_criteria');
  final snap = await col.limit(1).get();
  if (snap.docs.isNotEmpty) return;
  final now = DateTime.now().toIso8601String();
  final defaults = <Map<String, dynamic>>[
    {
      'title': 'Speed',
      'description': 'How fast was the work completed?',
      'icon': '⚡',
      'maxRating': 5,
      'isRequired': true,
      'isActive': true,
      'order': 0,
      'createdAt': now
    },
    {
      'title': 'Quality',
      'description': 'Quality of the finished work.',
      'icon': '🔧',
      'maxRating': 5,
      'isRequired': true,
      'isActive': true,
      'order': 1,
      'createdAt': now
    },
    {
      'title': 'Communication',
      'description': 'Ease of communication and clarity.',
      'icon': '💬',
      'maxRating': 5,
      'isRequired': true,
      'isActive': true,
      'order': 2,
      'createdAt': now
    },
  ];
  final batch = FirebaseFirestore.instance.batch();
  for (final d in defaults) {
    batch.set(col.doc(), d);
  }
  await batch.commit();
}

final reviewCriteriaStreamProvider =
    StreamProvider<List<ReviewCriteriaModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('review_criteria')
      .snapshots()
      .map((snap) {
    final list = snap.docs
        .map((d) => ReviewCriteriaModel.fromFirestore(d.data(), id: d.id))
        .toList();
    list.sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      if (byOrder != 0) return byOrder;
      final at = a.createdAt, bt = b.createdAt;
      if (at != null && bt != null) return at.compareTo(bt);
      return a.name.compareTo(b.name);
    });
    return list;
  });
});

Future<void> addReviewCriteriaInFirestore(ReviewCriteriaModel c) async {
  await FirebaseFirestore.instance.collection('review_criteria').add(c.toMap());
}

Future<void> updateReviewCriteriaInFirestore(ReviewCriteriaModel c) async {
  final data = c.toMap();
  data['updatedAt'] = DateTime.now().toIso8601String();
  await FirebaseFirestore.instance
      .collection('review_criteria')
      .doc(c.id)
      .set(data, SetOptions(merge: true));
}

Future<void> deleteReviewCriteriaInFirestore(String id) async {
  await FirebaseFirestore.instance
      .collection('review_criteria')
      .doc(id)
      .delete();
}

Future<void> toggleReviewCriteriaActiveInFirestore(
    String id, bool isActive) async {
  await FirebaseFirestore.instance.collection('review_criteria').doc(id).set({
    'isActive': isActive,
    'updatedAt': DateTime.now().toIso8601String(),
  }, SetOptions(merge: true));
}

Future<void> reorderReviewCriteriaInFirestore(
    List<ReviewCriteriaModel> orderedList) async {
  final batch = FirebaseFirestore.instance.batch();
  final col = FirebaseFirestore.instance.collection('review_criteria');
  for (var i = 0; i < orderedList.length; i++) {
    batch.set(
        col.doc(orderedList[i].id),
        {'order': i, 'updatedAt': DateTime.now().toIso8601String()},
        SetOptions(merge: true));
  }
  await batch.commit();
}

// Bridges the Firestore criteria stream into a StateNotifier so existing admin
// UI (add/edit/delete/reorder/toggle via `.notifier`) keeps working unchanged.
class ReviewCriteriaNotifier extends StateNotifier<List<ReviewCriteriaModel>> {
  ReviewCriteriaNotifier() : super(const []);
  bool _seeded = false;

  void setCriteria(List<ReviewCriteriaModel> list) {
    state = list;
    if (list.isEmpty && !_seeded) {
      _seeded = true;
      seedDefaultReviewCriteriaIfEmpty();
    }
  }

  Future<void> addCriteria(ReviewCriteriaModel c) =>
      addReviewCriteriaInFirestore(c);
  Future<void> updateCriteria(ReviewCriteriaModel c) =>
      updateReviewCriteriaInFirestore(c);
  Future<void> deleteCriteria(String id) => deleteReviewCriteriaInFirestore(id);

  Future<void> toggleActive(String id) {
    final c = state.firstWhereOrNull((x) => x.id == id);
    if (c == null) return Future.value();
    return toggleReviewCriteriaActiveInFirestore(id, !c.isActive);
  }

  Future<void> reorder(int oldIdx, int newIdx) {
    final list = [...state];
    final item = list.removeAt(oldIdx);
    list.insert(newIdx, item);
    return reorderReviewCriteriaInFirestore(list);
  }
}

final reviewCriteriaProvider =
    StateNotifierProvider<ReviewCriteriaNotifier, List<ReviewCriteriaModel>>(
        (ref) {
  final notifier = ReviewCriteriaNotifier();
  ref.listen<AsyncValue<List<ReviewCriteriaModel>>>(
      reviewCriteriaStreamProvider, (prev, next) {
    next.whenData(notifier.setCriteria);
  }, fireImmediately: true);
  return notifier;
});

// ─── Search Query ─────────────────────────────────────────────────────────────
final searchQueryProvider = StateProvider<String>((ref) => '');

// ─── Nav Index ────────────────────────────────────────────────────────────────
final navIndexProvider = StateProvider<int>((ref) => 0);

// ─── Workers Provider ─────────────────────────────────────────────────────────
class WorkersNotifier extends StateNotifier<List<WorkerModel>> {
  WorkersNotifier()
      : super(DummyData.providers
            .firstWhere((p) => p.role == UserRole.contractor)
            .team);

  void addWorker(WorkerModel worker) => state = [...state, worker];
  void removeWorker(String id) =>
      state = state.where((w) => w.id != id).toList();
  void updateWorker(WorkerModel updated) =>
      state = state.map((w) => w.id == updated.id ? updated : w).toList();
}

final workersProvider =
    StateNotifierProvider<WorkersNotifier, List<WorkerModel>>(
  (ref) => WorkersNotifier(),
);

// ─── Contractor Workers — Firestore-backed ────────────────────────────────────

class ContractorWorkersService {
  static final _col =
      FirebaseFirestore.instance.collection('contractor_workers');

  static Future<void> add(
    WorkerModel worker, {
    required String contractorId,
    required String contractorName,
  }) async {
    final docRef = worker.id.isEmpty ? _col.doc() : _col.doc(worker.id);
    await docRef.set({
      ...worker.toFirestoreMap(
          contractorId: contractorId, contractorName: contractorName),
      'id': docRef.id,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> update(
    WorkerModel worker, {
    required String contractorId,
    required String contractorName,
  }) async {
    await _col.doc(worker.id).update({
      ...worker.toFirestoreMap(
          contractorId: contractorId, contractorName: contractorName),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> delete(String workerId) async {
    await _col.doc(workerId).delete();
  }

  // Partial update used by Admin's Edit Worker flow: only writes the
  // fields that actually changed (diff built by the caller), never the
  // full worker document, and never touches contractorId.
  static Future<void> updateFields(
      String workerId, Map<String, dynamic> changes) async {
    if (changes.isEmpty) return;
    await _col.doc(workerId).update({
      ...changes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

final contractorWorkersStreamProvider =
    StreamProvider<List<WorkerModel>>((ref) {
  final user = ref.watch(authProvider);
  if (user == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('contractor_workers')
      .where('contractorId', isEqualTo: user.id)
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => WorkerModel.fromFirestore(doc.data(), id: doc.id))
          .toList());
});

// Read workers for any contractor by their id — used by customer-facing profile
final contractorWorkersByIdProvider =
    StreamProvider.family<List<WorkerModel>, String>((ref, contractorId) {
  if (contractorId.isEmpty) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('contractor_workers')
      .where('contractorId', isEqualTo: contractorId)
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => WorkerModel.fromFirestore(doc.data(), id: doc.id))
          .toList());
});

// ─── Order Assignments ────────────────────────────────────────────────────────
final orderAssignmentsProvider =
    StateProvider<Map<String, String>>((ref) => {});

// ─── Suppliers Provider (Contractor Workers + Manual Entries) ─────────────────
// Uses same WorkerModel so workers appear in both sheet and suppliers page.
// Extra fields stored as WorkerModel.specialty = category, phone via WorkerModel.phone
class SuppliersNotifier extends StateNotifier<List<WorkerModel>> {
  SuppliersNotifier(List<WorkerModel> initial) : super(initial);

  void add(WorkerModel worker) => state = [...state, worker];

  void remove(String id) => state = state.where((w) => w.id != id).toList();

  void update(WorkerModel updated) =>
      state = state.map((w) => w.id == updated.id ? updated : w).toList();
}

final suppliersProvider =
    StateNotifierProvider<SuppliersNotifier, List<WorkerModel>>((ref) {
  // Bootstrap from the same workers list so they're always in sync.
  final workers = ref.watch(workersProvider);
  return SuppliersNotifier(workers);
});

// ─── Theme Mode ───────────────────────────────────────────────────────────────
// Theme is locked to light mode — dark mode removed
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

// ─── Profile Photo Provider ────────────────────────────────────────────────────
// Stores image bytes (Uint8List) per userId — Web-safe, no File paths.
class ProfilePhotoNotifier extends StateNotifier<Map<String, Uint8List>> {
  ProfilePhotoNotifier() : super({});

  void setPhoto(String userId, Uint8List bytes) {
    state = {...state, userId: bytes};
  }

  Uint8List? getPhoto(String userId) => state[userId];
}

final profilePhotoProvider =
    StateNotifierProvider<ProfilePhotoNotifier, Map<String, Uint8List>>(
  (ref) => ProfilePhotoNotifier(),
);
