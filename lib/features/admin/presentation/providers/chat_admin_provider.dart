import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/models.dart';

// ─── Admin Chat Request ───────────────────────────────────────────────────────
enum AdminChatRequestStatus { pending, approved, rejected }

class AdminChatRequest {
  final String id;
  final String userId;
  final String userName;
  final UserRole userRole;
  final String? message;
  final DateTime createdAt;
  AdminChatRequestStatus status;
  bool isRead;

  AdminChatRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userRole,
    this.message,
    required this.createdAt,
    this.status = AdminChatRequestStatus.pending,
    this.isRead = false,
  });
}

class AdminChatRequestsNotifier extends StateNotifier<List<AdminChatRequest>> {
  AdminChatRequestsNotifier() : super([
    AdminChatRequest(
      id: 'acr1',
      userId: 'current_user',
      userName: 'Sami Arab',
      userRole: UserRole.customer,
      message: 'I have an issue with my order and need admin help.',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    AdminChatRequest(
      id: 'acr2',
      userId: 'p2',
      userName: 'Mohammed Hasan',
      userRole: UserRole.professional,
      message: 'I need clarification about payment.',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      isRead: true,
    ),
  ]);

  void addRequest(AdminChatRequest req) => state = [req, ...state];

  void approve(String id) =>
      state = state.map((r) => r.id == id ? (r..status = AdminChatRequestStatus.approved) : r).toList();

  void reject(String id) =>
      state = state.map((r) => r.id == id ? (r..status = AdminChatRequestStatus.rejected) : r).toList();

  void markRead(String id) =>
      state = state.map((r) => r.id == id ? (r..isRead = true) : r).toList();

  void markAllRead() =>
      state = state.map((r) => r..isRead = true).toList();

  int get unreadCount =>
      state.where((r) => !r.isRead && r.status == AdminChatRequestStatus.pending).length;
}

final adminChatRequestsProvider =
StateNotifierProvider<AdminChatRequestsNotifier, List<AdminChatRequest>>(
      (ref) => AdminChatRequestsNotifier(),
);

// ─── Admin Conversation Monitor ───────────────────────────────────────────────
class AdminConvEntry {
  final String userId;
  final String userName;
  final UserRole role;
  final String lastMessage;
  final DateTime lastTime;
  final int messageCount;
  bool isBlocked;

  AdminConvEntry({
    required this.userId,
    required this.userName,
    required this.role,
    required this.lastMessage,
    required this.lastTime,
    required this.messageCount,
    this.isBlocked = false,
  });
}

class AdminConvsNotifier extends StateNotifier<List<AdminConvEntry>> {
  AdminConvsNotifier() : super([
    AdminConvEntry(
      userId: 'p1', userName: 'Ahmad Karimi', role: UserRole.professional,
      lastMessage: 'The work is completed', lastTime: DateTime.now().subtract(const Duration(hours: 1)),
      messageCount: 12,
    ),
    AdminConvEntry(
      userId: 'current_user', userName: 'Sami Arab', role: UserRole.customer,
      lastMessage: 'Can you send more details?', lastTime: DateTime.now().subtract(const Duration(hours: 3)),
      messageCount: 7,
    ),
    AdminConvEntry(
      userId: 'p5', userName: 'United Construction Co.', role: UserRole.contractor,
      lastMessage: 'I will arrive tomorrow', lastTime: DateTime.now().subtract(const Duration(days: 1)),
      messageCount: 4,
    ),
    AdminConvEntry(
      userId: 'p2', userName: 'Mohammed Hasan', role: UserRole.professional,
      lastMessage: 'Thank you', lastTime: DateTime.now().subtract(const Duration(days: 2)),
      messageCount: 18,
    ),
  ]);

  void addFromRequest(AdminChatRequest request) {
    // Check if conversation already exists
    final exists = state.any((e) => e.userId == request.userId);
    if (!exists) {
      state = [
        AdminConvEntry(
          userId: request.userId,
          userName: request.userName,
          role: request.userRole,
          lastMessage: request.message ?? '',
          lastTime: DateTime.now(),
          messageCount: 0,
        ),
        ...state,
      ];
    }
  }

  void blockUser(String userId) =>
      state = state.map((e) => e.userId == userId ? (e..isBlocked = true) : e).toList();

  void unblockUser(String userId) =>
      state = state.map((e) => e.userId == userId ? (e..isBlocked = false) : e).toList();

  void deleteConv(String userId) =>
      state = state.where((e) => e.userId != userId).toList();
}

final adminConvsProvider =
StateNotifierProvider<AdminConvsNotifier, List<AdminConvEntry>>(
      (ref) => AdminConvsNotifier(),
);
