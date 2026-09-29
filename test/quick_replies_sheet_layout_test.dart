import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Regression test for the "RenderFlex overflowed by 847 pixels on the
// bottom" bug in CustomerChatScreen._showQuickReplies(). The bottom sheet's
// content used a bare, non-scrollable Column, so a quick-replies list long
// enough to exceed the viewport (e.g. 375x667) overflowed instead of
// scrolling.
//
// _showQuickReplies() is a private method on a stateful screen with heavy
// Firebase-backed dependencies (auth, conversation, message streams), so it
// isn't practical to pump the full CustomerChatScreen in a widget test
// without adding a mocking package. This test instead reconstructs the
// fixed sheet's actual widget-tree shape — ConstrainedBox(maxHeight) >
// Container > SafeArea > Column(handle, header, banner, Flexible(ListView),
// Close button) — the same structure now in
// lib/features/customer/presentation/screens/customer_chat_screen.dart, and
// asserts it renders a long reply list at a narrow viewport without a
// RenderFlex overflow, with every item reachable by scrolling and the
// Close button still present.
//
// A RenderFlex overflow surfaces through FlutterError.onError during
// layout/paint, which flutter_test turns into a failing test.
Widget _sheetHarness(List<String> replies) => MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: Builder(
              builder: (dCtx) {
                final mq = MediaQuery.of(dCtx);
                final maxSheetHeight =
                    mq.size.height - mq.padding.top - mq.viewInsets.bottom - 24;
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                        maxHeight: maxSheetHeight > 0
                            ? maxSheetHeight
                            : mq.size.height * 0.6),
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Quick Replies'),
                            const SizedBox(height: 16),
                            const Text('Select a quick reply below.'),
                            const SizedBox(height: 18),
                            Flexible(
                              child: ListView(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                children: replies
                                    .map((r) => Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 10),
                                          child: Text(r),
                                        ))
                                    .toList(),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text('Close'),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets(
      'quick replies sheet does not overflow a 375x667 viewport with a long list',
      (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final replies =
        List.generate(40, (i) => 'Quick reply number $i with some text');

    await tester.pumpWidget(_sheetHarness(replies));
    await tester.pumpAndSettle();

    // No RenderFlex overflow was thrown during layout/paint above.
    expect(find.text('Quick Replies'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);

    // The first item is visible without scrolling...
    expect(find.text(replies.first), findsOneWidget);
    // ...but a late item is off-screen until scrolled into view.
    expect(find.text(replies.last), findsNothing);

    await tester.scrollUntilVisible(
      find.text(replies.last),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text(replies.last), findsOneWidget);

    // Header and Close stay put while only the list scrolled.
    expect(find.text('Quick Replies'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('quick replies sheet stays compact with a short list',
      (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_sheetHarness(['Thanks!', 'On my way']));
    await tester.pumpAndSettle();

    expect(find.text('Thanks!'), findsOneWidget);
    expect(find.text('On my way'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });
}
