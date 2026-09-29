import 'package:flutter_test/flutter_test.dart';
import 'package:san3a/features/admin/presentation/providers/admin_providers.dart';

// Pure unit tests for the Admin "Send Broadcast Message" multi-select audience
// rules. What matters here is that no user can ever receive the same broadcast
// twice: a broadcast is written as one notification document per targetRole,
// a user has exactly one role, so the guarantee reduces to "each role appears
// at most once in the emitted role list, and 'all' is never mixed with a
// specific role".
void main() {
  group('normalizeBroadcastTargets', () {
    test('keeps a single specific group as-is', () {
      expect(normalizeBroadcastTargets({BroadcastTarget.customers}),
          {BroadcastTarget.customers});
    });

    test('keeps a two-group combination', () {
      expect(
        normalizeBroadcastTargets(
            {BroadcastTarget.customers, BroadcastTarget.professionals}),
        {BroadcastTarget.customers, BroadcastTarget.professionals},
      );
    });

    test('All Users absorbs any individual groups selected with it', () {
      expect(
        normalizeBroadcastTargets(
            {BroadcastTarget.all, BroadcastTarget.contractors}),
        {BroadcastTarget.all},
      );
    });

    test('selecting all three individual groups collapses to All Users', () {
      expect(
        normalizeBroadcastTargets({
          BroadcastTarget.customers,
          BroadcastTarget.professionals,
          BroadcastTarget.contractors,
        }),
        {BroadcastTarget.all},
      );
    });

    test('an empty selection stays empty', () {
      expect(normalizeBroadcastTargets({}), isEmpty);
    });
  });

  group('broadcastTargetsToRoleStrings', () {
    test('maps a single audience to the legacy single-role output', () {
      // The pre-multi-select behaviour must keep working unchanged.
      expect(broadcastTargetsToRoleStrings({BroadcastTarget.all}), ['all']);
      expect(broadcastTargetsToRoleStrings({BroadcastTarget.customers}),
          ['customer']);
      expect(broadcastTargetsToRoleStrings({BroadcastTarget.professionals}),
          ['professional']);
      expect(broadcastTargetsToRoleStrings({BroadcastTarget.contractors}),
          ['contractor']);
    });

    test('maps a multi-audience selection to one role each', () {
      final roles = broadcastTargetsToRoleStrings(
          {BroadcastTarget.professionals, BroadcastTarget.contractors});
      expect(roles.toSet(), {'professional', 'contractor'});
      expect(roles, hasLength(2));
    });

    test('never emits a duplicate role', () {
      for (final selection in <Set<BroadcastTarget>>[
        {BroadcastTarget.all},
        {BroadcastTarget.all, BroadcastTarget.customers},
        {BroadcastTarget.customers, BroadcastTarget.professionals},
        {
          BroadcastTarget.customers,
          BroadcastTarget.professionals,
          BroadcastTarget.contractors
        },
        {
          BroadcastTarget.all,
          BroadcastTarget.customers,
          BroadcastTarget.professionals,
          BroadcastTarget.contractors
        },
      ]) {
        final roles = broadcastTargetsToRoleStrings(selection);
        expect(roles.length, roles.toSet().length,
            reason: 'duplicate role emitted for $selection -> $roles');
        // 'all' already covers everyone, so pairing it with a specific role
        // would deliver twice to that role's users.
        if (roles.contains('all')) expect(roles, ['all']);
      }
    });

    test('only emits roles firestore.rules accepts', () {
      // broadcastCreateValid() requires targetRole in this exact set.
      const allowed = {'all', 'customer', 'professional', 'contractor'};
      for (final t in BroadcastTarget.values) {
        expect(allowed, contains(broadcastTargetToRoleString(t)));
      }
    });

    test('an empty selection sends nothing', () {
      expect(broadcastTargetsToRoleStrings({}), isEmpty);
    });
  });

  group('BroadcastMessage', () {
    test('normalizes the audiences recorded in local history', () {
      final notifier = BroadcastNotifier();
      notifier.send('hello', {BroadcastTarget.all, BroadcastTarget.customers});
      expect(notifier.state.single.targets, {BroadcastTarget.all});
    });

    test('exposes a back-compat single target', () {
      final notifier = BroadcastNotifier();
      notifier.send('hi', {BroadcastTarget.contractors});
      expect(notifier.state.single.target, BroadcastTarget.contractors);
    });
  });
}
