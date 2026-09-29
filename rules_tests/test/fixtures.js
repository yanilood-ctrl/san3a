'use strict';

// Field shapes proven from the real app code in Rules Phase 1A investigation:
// - AuthNotifier.register() / UserModel.toMap()
//   (lib/features/auth/presentation/providers/app_providers.dart,
//    lib/shared/models/models.dart)

const nowIso = () => new Date().toISOString();

function customerData(uid, overrides = {}) {
  return {
    id: uid,
    fullName: 'Test Customer',
    email: `${uid}@test.san3a`,
    phone: '0500000001',
    city: 'Tel Aviv',
    streetNumber: '12',
    role: 'customer',
    specialties: [],
    rating: 0,
    totalJobs: 0,
    services: [],
    languages: [],
    warnings: [],
    workingDays: [],
    preferredContactHours: [],
    joinDate: nowIso(),
    favoriteServices: [],
    servicesList: [],
    isBlocked: false,
    isDeleted: false,
    ...overrides,
  };
}

function professionalData(uid, overrides = {}) {
  return {
    id: uid,
    fullName: 'Test Professional',
    email: `${uid}@test.san3a`,
    phone: '0500000002',
    city: 'north_country',
    streetNumber: '',
    role: 'professional',
    workArea: 'north_country',
    experienceYears: 5,
    specialty: 'plumbing',
    specialties: ['plumbing'],
    serviceDescription: 'Experienced plumber',
    rating: 0,
    totalJobs: 0,
    services: [],
    languages: [],
    warnings: [],
    workingDays: [],
    preferredContactHours: [],
    joinDate: nowIso(),
    favoriteServices: [],
    servicesList: [],
    isBlocked: false,
    isDeleted: false,
    ...overrides,
  };
}

function contractorData(uid, overrides = {}) {
  return professionalData(uid, {
    role: 'contractor',
    companyName: 'Test Contracting Co',
    ...overrides,
  });
}

// Admins are ordinary users/{uid} documents with role: 'admin' — isAdmin()
// in firestore.rules just checks this field via get().
function adminData(uid, overrides = {}) {
  return customerData(uid, {
    fullName: 'Test Admin',
    role: 'admin',
    ...overrides,
  });
}

// Field shapes proven from Rules Phase 2A investigation:
// - category_request_sheet.dart (Customer), professional_home_screen.dart
//   (Professional), contractor_profile_screen.dart (Contractor) — all three
//   `.collection('category_requests').add(CategoryRequestModel(...).toMap())`
// - CategoryRequestModel.toMap() (lib/shared/models/models.dart)
function categoryRequestData(requesterId, requesterRole, overrides = {}) {
  return {
    requesterId,
    requesterName: 'Test Requester',
    requesterRole,
    requestedName: 'Carpentry',
    requestedDescription: 'Wood work services',
    status: 'pending',
    createdAt: nowIso(),
    ...overrides,
  };
}

// Deterministic doc id and field shape proven from Rules Phase 2B
// investigation — addFavoriteInFirestore() / _favoriteDocId()
// (lib/features/auth/presentation/providers/app_providers.dart). Note this
// is a hand-built inline map, NOT FavoriteModel.toMap() — providerCategory
// and providerImageUrl are always present as keys (value may be null),
// never conditionally omitted.
function favoriteDocId(customerId, providerId) {
  return `${customerId}_${providerId}`;
}

function favoriteData(customerId, providerId, providerRole, overrides = {}) {
  return {
    customerId,
    providerId,
    providerName: 'Test Provider',
    providerRole,
    providerCategory: 'plumbing',
    providerImageUrl: null,
    createdAt: nowIso(),
    ...overrides,
  };
}

// Deterministic doc id and field shape proven from Rules Phase 2C1
// investigation — reviewDocId() / addReviewInFirestore() / ReviewModel.toMap()
// (lib/features/auth/presentation/providers/app_providers.dart,
//  lib/shared/models/models.dart). Full create-time key set (17 possible
// keys, 4 conditional: orderId, criteriaRatings, relatedService, updatedAt —
// updatedAt is never present on a genuine create, only added on edit).
function reviewDocId(customerId, providerId, orderId) {
  return orderId
    ? `${customerId}_${providerId}_${orderId}`
    : `${customerId}_${providerId}`;
}

function reviewData(customerId, providerId, providerRole, overrides = {}) {
  return {
    customerId,
    customerName: 'Test Customer',
    providerId,
    providerName: 'Test Provider',
    providerRole,
    speedRating: 4,
    qualityRating: 5,
    communicationRating: 4,
    rating: 4.33,
    comment: 'Great work, on time.',
    createdAt: nowIso(),
    status: 'visible',
    isHidden: false,
    reportCount: 0,
    ...overrides,
  };
}

// Field shape proven from Rules Phase 2C2 investigation —
// ReviewCriteriaModel.toMap() / addReviewCriteriaInFirestore() /
// seedDefaultReviewCriteriaIfEmpty() (app_providers.dart, models.dart).
// Note the Firestore field is 'title' (Dart-side name is 'name') and 'order'
// (Dart-side name is 'sortOrder') — real doc IDs are Firestore
// auto-generated (col.doc()/col.add()), never deterministic.
function reviewCriteriaData(overrides = {}) {
  return {
    title: 'Speed',
    description: 'How fast was the work completed?',
    icon: '⚡',
    maxRating: 5,
    isRequired: true,
    isActive: true,
    order: 0,
    createdAt: nowIso(),
    ...overrides,
  };
}

// Field shape proven from Rules Phase 3A investigation —
// WorkerModel.toFirestoreMap() / ContractorWorkersService.add()
// (lib/shared/models/models.dart,
//  lib/features/auth/presentation/providers/app_providers.dart). Real doc
// IDs are Firestore auto-generated (col.doc()/col.doc(worker.id) where
// worker.id is always '' on create), never deterministic — 'id' is always
// written equal to the real document id. workStartTime/workEndTime/
// description are conditionally present in the real app; included here by
// default since they're always safe to validate as strings.
function workerData(contractorId, docId, overrides = {}) {
  return {
    id: docId,
    contractorId,
    contractorName: 'Test Contracting Co',
    fullName: 'Test Worker',
    specialty: 'plumbing',
    specialties: ['plumbing'],
    phone: '0500000099',
    email: 'worker@test.san3a',
    city: 'Tel Aviv',
    workArea: 'Tel Aviv',
    languages: ['ar'],
    experienceYears: 3,
    workHours: '08:00 – 18:00',
    workStartTime: '08:00',
    workEndTime: '18:00',
    status: 'available',
    rating: 0,
    completedJobs: 0,
    skills: ['tiling'],
    description: 'Reliable worker',
    createdAt: nowIso(),
    updatedAt: nowIso(),
    ...overrides,
  };
}

// Field shape proven from Rules Phase 3B1 investigation —
// OrderModel.toMap() / OrdersNotifier.createOrderInFirestore() /
// new_order_screen.dart's real Create Order (and Custom Request, same call,
// just without the selectedService* fields) flow (app_providers.dart,
// models.dart). Doc IDs are client-generated and deterministic
// ('order_${millisecondsSinceEpoch}'), always equal to data.id — never a
// Firestore auto-id. serviceDate/createdAt/updatedAt are ISO-8601 strings,
// never Firestore Timestamp objects.
function orderDocId() {
  return `order_${Date.now()}_${Math.floor(Math.random() * 1e6)}`;
}

function orderData(customerId, providerId, providerRole, docId, overrides = {}) {
  return {
    id: docId,
    customerId,
    customerName: 'Test Customer',
    customerPhone: '0500000001',
    providerId,
    providerName: 'Test Provider',
    providerPhone: '0500000002',
    providerRole,
    title: 'Fix the sink',
    description: 'The kitchen sink is leaking.',
    area: 'Tel Aviv',
    selectedServiceId: 'svc_1',
    selectedServiceName: 'Plumbing Repair',
    selectedServicePrice: 150,
    selectedServices: [
      { id: 'svc_1', name: 'Plumbing Repair', description: 'Fix leaks', price: 150, categoryId: 'plumbing' },
    ],
    serviceDate: nowIso(),
    status: 'pending',
    priority: 'normal',
    createdAt: nowIso(),
    updatedAt: nowIso(),
    categoryId: 'plumbing',
    categoryNameKey: 'plumbing',
    imageUrls: [],
    ...overrides,
  };
}

// Field shapes proven from Rules Phase 4A investigation —
// getConversationId() / sendTextMessageToUser() / sendImageMessageToUser() /
// sendVoiceMessageToUser() / sendAdminWarningMessage() /
// ConversationModel.toMap() (lib/features/auth/presentation/providers/
// app_providers.dart, lib/shared/models/models.dart). Conversation doc id is
// deterministic — the two participant uids sorted lexicographically then
// joined with '_' — never a Firestore auto-id. Message doc ids are always
// Firestore auto-generated; callers must set the real generated id into the
// `id` field before writing, mirroring msgRef.id in the real app.
function conversationDocId(uidA, uidB) {
  return [uidA, uidB].sort().join('_');
}

function conversationData(customerId, providerId, providerRole, overrides = {}) {
  return {
    id: conversationDocId(customerId, providerId),
    participantIds: [customerId, providerId],
    participantNames: { [customerId]: 'Test Customer', [providerId]: 'Test Provider' },
    participantRoles: { [customerId]: 'customer', [providerId]: providerRole },
    lastMessage: 'Hello',
    lastMessageTime: nowIso(),
    lastMessageSenderId: customerId,
    isBlocked: false,
    createdAt: nowIso(),
    updatedAt: nowIso(),
    ...overrides,
  };
}

function textMessageData(conversationId, senderId, receiverId, overrides = {}) {
  return {
    conversationId,
    senderId,
    receiverId,
    text: 'Hello there',
    type: 'text',
    sentAt: nowIso(),
    isRead: false,
    isEdited: false,
    isDeleted: false,
    ...overrides,
  };
}

function imageMessageData(conversationId, senderId, receiverId, overrides = {}) {
  return {
    conversationId,
    senderId,
    receiverId,
    text: '',
    type: 'image',
    imageUrl: 'https://storage.test/chat_images/img.jpg',
    mediaUrl: 'https://storage.test/chat_images/img.jpg',
    storagePath: `chat_images/${conversationId}/photo.jpg`,
    fileName: 'photo.jpg',
    sentAt: nowIso(),
    isRead: false,
    isEdited: false,
    isDeleted: false,
    ...overrides,
  };
}

function voiceMessageData(conversationId, senderId, receiverId, overrides = {}) {
  return {
    conversationId,
    senderId,
    receiverId,
    text: '',
    type: 'voice',
    voiceUrl: 'https://storage.test/chat_voice/clip.m4a',
    audioUrl: 'https://storage.test/chat_voice/clip.m4a',
    mediaUrl: 'https://storage.test/chat_voice/clip.m4a',
    storagePath: `chat_voice/${conversationId}/clip.m4a`,
    fileName: 'clip.m4a',
    voiceDurationSec: 12,
    sentAt: nowIso(),
    isRead: false,
    isEdited: false,
    isDeleted: false,
    ...overrides,
  };
}

function adminWarningMessageData(conversationId, adminId, targetUserIds, overrides = {}) {
  return {
    conversationId,
    senderId: adminId,
    receiverId: '',
    text: 'Please follow community guidelines.',
    type: 'adminWarning',
    targetUserIds,
    sentAt: nowIso(),
    isRead: false,
    isEdited: false,
    isDeleted: false,
    ...overrides,
  };
}

// Field shape proven from Rules Phase 4C1 investigation —
// createQuickReplyInFirestore() / updateQuickReplyInFirestore() /
// deleteQuickReplyInFirestore() / QuickReplyModel.toMap()
// (lib/features/auth/presentation/providers/app_providers.dart,
//  lib/shared/models/models.dart). Real doc ids are Firestore
// auto-generated (col.doc()), never deterministic — 'id' is always written
// equal to the real document id. 'roles' is always present at create
// (defaults to []) even though the only real Admin UI call site never
// passes it; 'createdBy' is the only conditionally-omitted field.
function quickReplyData(overrides = {}) {
  return {
    text: 'Thank you for reaching out!',
    roles: [],
    isActive: true,
    createdAt: nowIso(),
    updatedAt: nowIso(),
    ...overrides,
  };
}

// Field shape proven from Rules Phase 4C2 investigation —
// createChatReportInFirestore() / ChatReportModel.toMap()
// (lib/features/auth/presentation/providers/app_providers.dart,
//  lib/shared/models/models.dart). Real doc ids are Firestore
// auto-generated (col.doc()), never deterministic — 'id' is always written
// equal to the real document id. reason is always one of exactly 4 fixed
// strings in the real UI (_AdminChatRequestSheetState's _types /
// my_chat_requests_screen.dart's _editTypes); priority is always 'medium'
// (the only real create call site never overrides it and no update path
// ever touches it); reportedUserId/reportedUserName/reportedUserRole are
// always present together in the real flow (the other conversation
// participant) but messageId is never set by the one real create call site
// even though the function signature supports it.
function chatReportData(conversationId, reporterId, reporterRole, overrides = {}) {
  return {
    conversationId,
    reporterId,
    reporterName: 'Test Reporter',
    reporterRole,
    reason: 'Inappropriate Messages',
    status: 'open',
    priority: 'medium',
    createdAt: nowIso(),
    updatedAt: nowIso(),
    isSeenByAdmin: false,
    ...overrides,
  };
}

// Field shapes proven from Rules Phase 5A investigation —
// addComplaintInFirestore() / ComplaintModel.toMap()
// (lib/features/auth/presentation/providers/app_providers.dart,
//  lib/shared/models/models.dart). Real doc ids are Firestore
// auto-generated (col.doc()), never deterministic — 'id' is always written
// equal to the real document id by the caller (toMap() itself never
// includes 'id'). Only 4 of the 6 defined ComplaintType values have any
// real create call site: order_problem, provider_report, review_report,
// general_complaint. priority is always 'medium' and status is always
// 'open' at every real create call site; 'title' always mirrors 'reason'.
function orderComplaintData(complainantId, complainantRole, relatedOrderId, overrides = {}) {
  return {
    complainantId,
    complainantName: 'Test User',
    complainantRole,
    type: 'order_problem',
    targetId: relatedOrderId,
    title: 'Order issue',
    reason: 'Order issue',
    description: 'Something went wrong with the order.',
    status: 'open',
    priority: 'medium',
    relatedOrderId,
    sourceContext: 'order_details',
    createdAt: nowIso(),
    isDeleted: false,
    ...overrides,
  };
}

function providerReportData(complainantId, targetUserId, overrides = {}) {
  return {
    complainantId,
    complainantName: 'Test Customer',
    complainantRole: 'customer',
    type: 'provider_report',
    targetId: targetUserId,
    targetUserId,
    title: 'Provider issue',
    reason: 'Provider issue',
    description: 'This provider was unprofessional.',
    status: 'open',
    priority: 'medium',
    sourceContext: 'provider_profile',
    createdAt: nowIso(),
    isDeleted: false,
    ...overrides,
  };
}

function reviewReportComplaintData(
  complainantId, complainantRole, relatedReviewId, targetUserId, overrides = {}
) {
  return {
    complainantId,
    complainantName: 'Test Provider',
    complainantRole,
    type: 'review_report',
    targetId: relatedReviewId,
    targetUserId,
    title: 'Unfair review',
    reason: 'Unfair review',
    description: 'This review is unfair.',
    status: 'open',
    priority: 'medium',
    relatedReviewId,
    sourceContext: 'review_report',
    createdAt: nowIso(),
    isDeleted: false,
    ...overrides,
  };
}

function generalComplaintData(complainantId, complainantRole, overrides = {}) {
  return {
    complainantId,
    complainantName: 'Test User',
    complainantRole,
    type: 'general_complaint',
    targetId: 'general',
    title: 'Bug report',
    reason: 'Bug report',
    description: 'Something is broken.',
    status: 'open',
    priority: 'medium',
    sourceContext: 'my_complaints',
    createdAt: nowIso(),
    isDeleted: false,
    ...overrides,
  };
}

// Field shapes proven from Rules Phase 5C1/5C2 investigation —
// NotificationModel.toMap() / addNotificationInFirestore() /
// sendBroadcastNotificationInFirestore() / sendUserWarningNotification()
// (lib/features/auth/presentation/providers/app_providers.dart,
//  lib/shared/models/models.dart). Real doc ids are Firestore
// auto-generated (col.doc()) — 'id' is always written equal to the real
// document id by every real create call site (toMap() itself never includes
// 'id' — mirrors the complaints fixture convention: callers spread
// `{ id: notifId, ...xNotificationData(...) }` when writing). isRead/
// isDeleted are always false and readAt is always absent at create time —
// real per-user read/delete state is a separate document under
// users/{uid}/notification_states/{notificationId} (see
// notificationStateData below), never on this document.
function orderUpdateNotificationData(targetUserId, relatedOrderId, overrides = {}) {
  return {
    userId: targetUserId,
    title: 'Order Accepted',
    message: 'Your order was accepted.',
    type: 'order_update',
    relatedOrderId,
    isRead: false,
    createdAt: nowIso(),
    isDeleted: false,
    ...overrides,
  };
}

function reviewNotificationData(targetUserId, relatedReviewId, overrides = {}) {
  return {
    userId: targetUserId,
    title: 'New Rating',
    message: 'You received a new review.',
    type: 'review',
    relatedReviewId,
    isRead: false,
    createdAt: nowIso(),
    isDeleted: false,
    ...overrides,
  };
}

// Requester -> admin shape (addComplaintInFirestore's auto-notify branch).
function complaintRequesterNotificationData(relatedComplaintId, overrides = {}) {
  return {
    targetRole: 'admin',
    title: 'New Complaint',
    message: 'A user submitted a complaint.',
    type: 'complaint',
    relatedComplaintId,
    isRead: false,
    createdAt: nowIso(),
    isDeleted: false,
    ...overrides,
  };
}

// Admin -> complainant shape (setComplaintStatusInFirestore's notify branch).
function complaintAdminNotificationData(targetUserId, relatedComplaintId, overrides = {}) {
  return {
    userId: targetUserId,
    title: 'Complaint Resolved',
    message: 'Your complaint has been resolved.',
    type: 'complaint',
    relatedComplaintId,
    createdByRole: 'admin',
    isRead: false,
    createdAt: nowIso(),
    isDeleted: false,
    ...overrides,
  };
}

// Requester -> admin shape. Phase 5C3: the real producer
// (createCategoryRequestNotification called from category_request_sheet.dart
// / professional_home_screen.dart / contractor_profile_screen.dart) now
// always captures the real category_requests document id returned by
// .add() and passes it as relatedCategoryRequestId — this fixture matches
// that current shape (prior to Phase 5C3 this field was absent).
function categoryRequestRequesterNotificationData(relatedCategoryRequestId, overrides = {}) {
  return {
    targetRole: 'admin',
    title: 'New Category Request',
    message: 'A user requested a new category.',
    type: 'category_request',
    relatedCategoryRequestId,
    isRead: false,
    createdAt: nowIso(),
    isDeleted: false,
    ...overrides,
  };
}

// Admin -> requester shape (admin_screens.dart approve/reject).
function categoryRequestAdminNotificationData(targetUserId, relatedCategoryRequestId, overrides = {}) {
  return {
    userId: targetUserId,
    title: 'Category Request Approved',
    message: 'Your request was approved.',
    type: 'category_request',
    relatedCategoryRequestId,
    isRead: false,
    createdAt: nowIso(),
    isDeleted: false,
    ...overrides,
  };
}

function systemNotificationData(targetUserId, overrides = {}) {
  return {
    userId: targetUserId,
    title: 'Account Warning',
    message: 'An administrator sent you a message.',
    type: 'system',
    createdByRole: 'admin',
    isRead: false,
    createdAt: nowIso(),
    isDeleted: false,
    ...overrides,
  };
}

function broadcastNotificationData(targetRole, overrides = {}) {
  return {
    title: 'Broadcast Message',
    message: 'Important update for everyone.',
    type: 'broadcast',
    targetRole,
    createdByRole: 'admin',
    isRead: false,
    createdAt: nowIso(),
    isDeleted: false,
    ...overrides,
  };
}

// Field shape proven from Rules Phase 5C1B/5C2 investigation —
// markNotificationReadInFirestore() / markAllNotificationsReadInFirestore() /
// softDeleteNotificationInFirestore() (app_providers.dart). Deterministic doc
// id == notificationId, under users/{uid}/notification_states/.
function notificationStateData(notificationId, userId, overrides = {}) {
  return {
    notificationId,
    userId,
    isRead: true,
    readAt: nowIso(),
    updatedAt: nowIso(),
    ...overrides,
  };
}

module.exports = {
  nowIso,
  customerData,
  professionalData,
  contractorData,
  adminData,
  categoryRequestData,
  favoriteDocId,
  favoriteData,
  reviewDocId,
  reviewData,
  orderDocId,
  orderData,
  reviewCriteriaData,
  workerData,
  conversationDocId,
  conversationData,
  textMessageData,
  imageMessageData,
  voiceMessageData,
  chatReportData,
  adminWarningMessageData,
  quickReplyData,
  orderComplaintData,
  providerReportData,
  reviewReportComplaintData,
  generalComplaintData,
  orderUpdateNotificationData,
  reviewNotificationData,
  complaintRequesterNotificationData,
  complaintAdminNotificationData,
  categoryRequestRequesterNotificationData,
  categoryRequestAdminNotificationData,
  systemNotificationData,
  broadcastNotificationData,
  notificationStateData,
};
