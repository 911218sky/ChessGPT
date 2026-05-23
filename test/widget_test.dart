import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_ai_desktop/src/app.dart';
import 'package:chess_ai_desktop/src/widgets/chess_board.dart';

void main() {
  testWidgets('renders chess project shell', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(child: ChessAIDesktopApp(autoInitialize: false)),
    );

    expect(find.text('Play Bots'), findsOneWidget);
    expect(find.text('Guest'), findsOneWidget);
    expect(find.text('Bots'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
    expect(find.byIcon(Icons.timer_rounded), findsNWidgets(2));
  });

  testWidgets('board sidebar stays within a short wide viewport', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(900, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(child: ChessAIDesktopApp(autoInitialize: false)),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Play Bots'), findsOneWidget);
    expect(find.byIcon(Icons.timer_rounded), findsNWidgets(2));
  });

  testWidgets('expanded AI panel stays in sync with text size changes', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(child: ChessAIDesktopApp(autoInitialize: false)),
    );

    await tester.tap(find.byIcon(Icons.open_in_full_rounded).first);
    await tester.pumpAndSettle();

    final dialog = find.byType(Dialog);
    expect(dialog, findsOneWidget);

    await tester.tap(
      find.descendant(of: dialog, matching: find.widgetWithText(Tab, 'Match')),
    );
    await tester.pumpAndSettle();

    final dialog120Chip = find.descendant(
      of: dialog,
      matching: find.widgetWithText(ChoiceChip, '120%'),
    );
    await tester.ensureVisible(dialog120Chip);
    await tester.tap(dialog120Chip);
    await tester.pumpAndSettle();

    expect(
      tester
          .widgetList<ChoiceChip>(dialog120Chip)
          .every((chip) => chip.selected),
      isTrue,
    );
    expect(
      tester
          .widgetList<ChoiceChip>(
            find.descendant(
              of: dialog,
              matching: find.widgetWithText(ChoiceChip, '100%'),
            ),
          )
          .every((chip) => !chip.selected),
      isTrue,
    );
  });

  testWidgets('board stays playable on a smaller laptop viewport', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(child: ChessAIDesktopApp(autoInitialize: false)),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Play Bots'), findsOneWidget);

    final boardSize = tester.getSize(find.byType(ChessBoard));
    expect(boardSize.width, greaterThanOrEqualTo(300));
    expect(boardSize.height, greaterThanOrEqualTo(300));
  });
}
