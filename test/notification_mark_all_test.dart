import 'package:flutter_test/flutter_test.dart';
import 'package:san3a/features/auth/presentation/providers/app_providers.dart';
import 'package:san3a/shared/models/models.dart';

// Regression coverage for the Customer "Mark all read" production bug: a
// customer with 33 unread notifications pressed "Mark all read" and nothing
// changed. Proven root cause (rules_tests emulator probe): the
// notification_states create() rule spends 2 get()/exists() calls per
// brand-new state document, and Firestore hard-caps a single batched write
// at 20 such calls total — so any mark-all batch with more than 10 unread
// notifications was denied outright, regardless of the (unrelated) 500
// write-operation batch ceiling. These tests cover the pure logic
// (computeUnreadVisibleNotificationIds / chunkNotificationIds) extracted
// from markAllNotificationsReadInFirestore; the actual Firestore
// permission-denied boundary is proven separately against the emulator in
// rules_tests/test/notificationStates.test.js.
void main() {
  group('computeUnreadVisibleNotificationIds', () {
    NotificationModel notif(String id, {String? userId}) => NotificationModel(
          id: id,
          userId: userId,
          title: 't',
          message: 'm',
          createdAt: DateTime(2026, 1, 1),
        );

    test('a notification with no state doc at all counts as unread', () {
      final byId = {'n1': notif('n1')};
      final result = computeUnreadVisibleNotificationIds(byId, {});
      expect(result, ['n1']);
    });

    test('already-read notifications are skipped', () {
      final byId = {'n1': notif('n1')};
      final states = {'n1': const NotificationStateView(isRead: true)};
      expect(computeUnreadVisibleNotificationIds(byId, states), isEmpty);
    });

    test('deleted notifications are skipped even if unread', () {
      final byId = {'n1': notif('n1')};
      final states = {'n1': const NotificationStateView(isDeleted: true)};
      expect(computeUnreadVisibleNotificationIds(byId, states), isEmpty);
    });

    test('mixed set only returns the genuinely unread, non-deleted ids', () {
      final byId = {
        'unread': notif('unread'),
        'read': notif('read'),
        'deleted': notif('deleted'),
      };
      final states = {
        'read': const NotificationStateView(isRead: true),
        'deleted': const NotificationStateView(isDeleted: true),
      };
      expect(computeUnreadVisibleNotificationIds(byId, states), ['unread']);
    });

    test(
        'legacy content missing an internal id field still keys off the '
        'real Firestore document id', () {
      // Simulates an old production notifications/{docId} document that
      // predates addNotificationInFirestore stamping data['id'] — no 'id'
      // key in the map at all. fromFirestore must still use the doc id
      // passed in explicitly (mirroring _tryParseNotification(doc.data(),
      // doc.id) in app_providers.dart), never a missing/legacy map field.
      final legacyMap = <String, dynamic>{
        'title': 'Old notice',
        'message': 'From before ids were stamped',
        'type': 'system',
        'createdAt': DateTime(2020, 1, 1).toIso8601String(),
        // Deliberately no 'id' key.
      };
      final parsed =
          NotificationModel.fromFirestore(legacyMap, id: 'real_doc_id_123');
      expect(parsed.id, 'real_doc_id_123');

      final byId = {parsed.id: parsed};
      // The state doc for this notification is keyed by the same real doc
      // id — mark-all must resolve it as unread despite the missing legacy
      // content field.
      expect(
        computeUnreadVisibleNotificationIds(byId, {}),
        ['real_doc_id_123'],
      );
    });
  });

  group('chunkNotificationIds', () {
    test('empty input produces no chunks', () {
      expect(chunkNotificationIds(<String>[], 8), isEmpty);
    });

    test('fewer ids than chunk size produces a single chunk', () {
      final ids = List.generate(5, (i) => 'n$i');
      expect(chunkNotificationIds(ids, 8), [ids]);
    });

    test('33 unread notifications (the reported production case) split into '
        'safe chunks of 8', () {
      final ids = List.generate(33, (i) => 'n$i');
      final chunks = chunkNotificationIds(ids, 8);
      expect(chunks.map((c) => c.length).toList(), [8, 8, 8, 8, 1]);
      expect(chunks.expand((c) => c).toList(), ids);
    });

    test('more than 500 notifications are split into many safe chunks, '
        'none exceeding the proven-safe chunk size', () {
      final ids = List.generate(1000, (i) => 'n$i');
      final chunks = chunkNotificationIds(ids, 8);
      expect(chunks.length, 125);
      for (final c in chunks) {
        expect(c.length, lessThanOrEqualTo(8));
      }
      expect(chunks.expand((c) => c).toList(), ids);
    });

    test('chunk boundaries preserve original order', () {
      final ids = List.generate(20, (i) => 'n$i');
      final chunks = chunkNotificationIds(ids, 8);
      expect(chunks, [
        List.generate(8, (i) => 'n$i'),
        List.generate(8, (i) => 'n${i + 8}'),
        ['n16', 'n17', 'n18', 'n19'],
      ]);
    });
  });

  group('mergeNotifications (effective per-user state overlay)', () {
    NotificationModel notif(String id) => NotificationModel(
          id: id,
          title: 't',
          message: 'm',
          createdAt: DateTime(2026, 1, 1),
        );

    test('a state update flips the merged view to read (UI/provider '
        'recomputation source)', () {
      final before = mergeNotifications([notif('n1')], [], {});
      expect(before.single.isRead, isFalse);

      final after = mergeNotifications(
        [notif('n1')],
        [],
        {'n1': const NotificationStateView(isRead: true)},
      );
      expect(after.single.isRead, isTrue);
    });

    test('a deleted state removes the notification from the effective list',
        () {
      final result = mergeNotifications(
        [notif('n1')],
        [],
        {'n1': const NotificationStateView(isDeleted: true)},
      );
      expect(result, isEmpty);
    });
  });
}
