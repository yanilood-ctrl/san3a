import 'package:flutter_test/flutter_test.dart';
import 'package:san3a/features/auth/presentation/providers/app_providers.dart';

// Pure unit tests for the shipped default quick replies. The duplicate-safety
// of seeding rests entirely on these ids being stable and unique — the seeder
// creates a default only when no document with that id exists — so that is
// what is asserted here. (The Firestore write path itself is covered by the
// rules specs under rules_tests/, not by this file.)
void main() {
  group('kDefaultQuickReplies', () {
    test('ships exactly twelve replies', () {
      expect(kDefaultQuickReplies, hasLength(12));
    });

    test('every id is unique', () {
      final ids = kDefaultQuickReplies.map((r) => r.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('every text is unique', () {
      // Two defaults with identical text would look like a duplicate in the
      // admin list even though their ids differ.
      final texts = kDefaultQuickReplies.map((r) => r.text).toList();
      expect(texts.toSet(), hasLength(texts.length));
    });

    test('ids are namespaced so they cannot collide with generated ones', () {
      // Admin-created replies use an auto-generated Firestore id; the
      // "default_" prefix keeps the seeded documents recognisable and out of
      // that space.
      for (final reply in kDefaultQuickReplies) {
        expect(reply.id, startsWith('default_'));
      }
    });

    test('every reply has non-empty, already-trimmed text', () {
      // firestore.rules requires text.size() > 0 on create.
      for (final reply in kDefaultQuickReplies) {
        expect(reply.text, isNotEmpty);
        expect(reply.text, reply.text.trim());
      }
    });

    test('replies are short enough to read as chat quick replies', () {
      for (final reply in kDefaultQuickReplies) {
        expect(reply.text.length, lessThanOrEqualTo(120),
            reason: '"${reply.id}" is too long for a quick reply');
      }
    });
  });
}
