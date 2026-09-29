import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:san3a/core/localization/app_localizations.dart';
import 'package:san3a/shared/widgets/chat_message_translate_action.dart';

// Regression test for the chat bubble's "RIGHT OVERFLOWED BY N PIXELS" error.
//
// ChatMessageTranslateAction renders inside a chat bubble constrained to ~70%
// of the screen width, and its Translate to / Arabic / Hebrew / English row did
// not fit on one line on narrower phones. Only the widget's local UI state is
// exercised here: opening the language choices is a pure setState, and no
// language is selected, so no translation controller is read and nothing
// touches Firestore or Cloud Functions.
//
// A RenderFlex overflow is reported through FlutterError.onError during
// paint/layout, which flutter_test records as a test failure — so simply
// pumping the widget at a narrow width and finding all three chips is the
// assertion.
Widget _harness(double bubbleWidth) => ProviderScope(
      child: MaterialApp(
        localizationsDelegates: const [AppLocalizationsDelegate()],
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: bubbleWidth),
              child: const Padding(
                // Same horizontal padding the chat bubble applies around its
                // content.
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: ChatMessageTranslateAction(
                  conversationId: 'conv-1',
                  messageId: 'msg-1',
                  sourceText: 'Hello there',
                ),
              ),
            ),
          ),
        ),
      ),
    );

Future<void> _openLanguageChoices(WidgetTester tester) async {
  // AppLocalizationsDelegate.load is async, so the first frame after
  // pumpWidget has no localizations yet and the entry button isn't built.
  await tester.pumpAndSettle();
  await tester.tap(find.text('Translate message'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('language choices fit a very narrow bubble without overflowing',
      (tester) async {
    // 0.70 * 320dp screen minus the avatar column — narrower than any real
    // phone bubble, and the case that used to overflow.
    await tester.pumpWidget(_harness(190));
    await _openLanguageChoices(tester);

    expect(find.text('Translate to'), findsOneWidget);
    expect(find.text('Arabic'), findsOneWidget);
    expect(find.text('Hebrew'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('language choices fit a typical phone bubble', (tester) async {
    await tester.pumpWidget(_harness(252)); // 0.70 * 360dp
    await _openLanguageChoices(tester);

    expect(find.text('Arabic'), findsOneWidget);
    expect(find.text('Hebrew'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('language choices fit a wide bubble', (tester) async {
    await tester.pumpWidget(_harness(400));
    await _openLanguageChoices(tester);

    expect(find.text('Arabic'), findsOneWidget);
    expect(find.text('Hebrew'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('the compact entry button fits a narrow bubble', (tester) async {
    await tester.pumpWidget(_harness(120));
    await tester.pumpAndSettle();

    expect(find.text('Translate message'), findsOneWidget);
  });

  testWidgets('nothing is rendered for whitespace-only text', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: const [AppLocalizationsDelegate()],
          home: const Scaffold(
            body: ChatMessageTranslateAction(
              conversationId: 'conv-1',
              messageId: 'msg-1',
              sourceText: '   ',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Translate message'), findsNothing);
  });
}
