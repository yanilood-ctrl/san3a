import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:san3a/core/localization/app_localizations.dart';
import 'package:san3a/shared/widgets/provider_service_translate_action.dart';

// Regression test for the "RenderFlex overflowed by 64 pixels on the right"
// bug in the provider service card's language selector row
// (_ServiceLanguageChoiceRow): "Translate to" plus the three language chips
// did not fit on one line at the narrow widths a service card gives them.
//
// Widths below are chosen to stay above what the *compact* "Translate
// service" entry button itself needs to render on one line (a separate,
// pre-existing Row in the same file that is not part of this bug and is out
// of scope here) — this isolates the assertion to the language choice row's
// own wrap-vs-overflow behavior once it's open.
//
// A RenderFlex overflow surfaces through FlutterError.onError during
// layout/paint, which flutter_test turns into a failing test — so pumping
// the widget at a narrow width and finding all four elements is the
// assertion; no explicit overflow check is required.
Widget _harness(double cardWidth) => ProviderScope(
      child: MaterialApp(
        localizationsDelegates: const [AppLocalizationsDelegate()],
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: cardWidth),
              child: const ProviderServiceTranslateAction(
                sourceDocId: 'provider-1',
                serviceId: 'service-1',
                currentServiceName: 'Plumbing repair',
                currentServiceDescription: 'Fix leaking pipes and faucets',
              ),
            ),
          ),
        ),
      ),
    );

Future<void> _openLanguageChoices(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.text('Translate service'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'language choice row fits a narrow service card without overflowing',
      (tester) async {
    await tester.pumpWidget(_harness(260));
    await _openLanguageChoices(tester);

    expect(find.text('Translate to'), findsOneWidget);
    expect(find.text('Arabic'), findsOneWidget);
    expect(find.text('Hebrew'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('language choice row fits a typical service card',
      (tester) async {
    await tester.pumpWidget(_harness(320));
    await _openLanguageChoices(tester);

    expect(find.text('Translate to'), findsOneWidget);
    expect(find.text('Arabic'), findsOneWidget);
    expect(find.text('Hebrew'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('language choice row fits a wide service card', (tester) async {
    await tester.pumpWidget(_harness(450));
    await _openLanguageChoices(tester);

    expect(find.text('Translate to'), findsOneWidget);
    expect(find.text('Arabic'), findsOneWidget);
    expect(find.text('Hebrew'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });
}
