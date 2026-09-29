import 'package:flutter_test/flutter_test.dart';
import 'package:san3a/shared/widgets/profile_field_selectors.dart';

// Pure unit tests for the Preferred Contact Hours selection rule shared by the
// Customer profile edit sheet and Admin's Customer edit form — same
// standalone-pure-function pattern as conversation_pending_gate_test.dart.
// No Firestore/Riverpod/widget wiring involved.
void main() {
  group('kPreferredContactHourOptions', () {
    test('offers the four periods plus Any Time, in that order', () {
      expect(kPreferredContactHourOptions,
          ['Morning', 'Afternoon', 'Evening', 'Night', 'Any Time']);
      expect(kPreferredContactHoursAnyTime, 'Any Time');
    });
  });

  group('togglePreferredContactHour', () {
    test('selects a period when nothing is selected', () {
      expect(togglePreferredContactHour(const [], 'Morning'), ['Morning']);
    });

    test('keeps multi-select for the specific periods', () {
      final afterFirst = togglePreferredContactHour(const [], 'Morning');
      final afterSecond = togglePreferredContactHour(afterFirst, 'Evening');
      expect(afterSecond, ['Morning', 'Evening']);
    });

    test('deselects an already-selected period', () {
      expect(
          togglePreferredContactHour(const ['Morning', 'Evening'], 'Morning'),
          ['Evening']);
    });

    test('deselecting the only period leaves no preference', () {
      expect(togglePreferredContactHour(const ['Night'], 'Night'), isEmpty);
    });

    test('picking Any Time clears every specific period', () {
      expect(
        togglePreferredContactHour(
            const ['Morning', 'Afternoon', 'Night'], 'Any Time'),
        ['Any Time'],
      );
    });

    test('picking a specific period clears Any Time', () {
      expect(togglePreferredContactHour(const ['Any Time'], 'Evening'),
          ['Evening']);
    });

    test('Any Time is never stored alongside a specific period', () {
      // Whatever the user taps, the two kinds of value can't coexist — that is
      // what makes "Any Time" mean unrestricted availability rather than an
      // extra, conflicting window.
      for (final option in kPreferredContactHourOptions) {
        for (final start in <List<String>>[
          const [],
          const ['Any Time'],
          const ['Morning'],
          const ['Morning', 'Afternoon', 'Evening', 'Night'],
        ]) {
          final result = togglePreferredContactHour(start, option);
          final hasAnyTime = result.contains(kPreferredContactHoursAnyTime);
          final hasSpecific =
              result.any((h) => h != kPreferredContactHoursAnyTime);
          expect(hasAnyTime && hasSpecific, isFalse,
              reason: 'toggling "$option" on $start produced $result');
        }
      }
    });

    test('tapping Any Time twice clears the selection', () {
      final selected = togglePreferredContactHour(const [], 'Any Time');
      expect(togglePreferredContactHour(selected, 'Any Time'), isEmpty);
    });

    test('records saved before Any Time existed still round-trip', () {
      // A legacy stored value is a plain list of old options; loading it and
      // toggling an unrelated period must not disturb the other entries.
      const legacy = ['Afternoon', 'Night'];
      expect(togglePreferredContactHour(legacy, 'Morning'),
          ['Afternoon', 'Night', 'Morning']);
    });

    test('does not mutate the list it is given', () {
      final original = ['Morning'];
      togglePreferredContactHour(original, 'Any Time');
      expect(original, ['Morning']);
    });
  });
}
