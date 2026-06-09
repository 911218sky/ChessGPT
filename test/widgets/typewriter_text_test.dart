import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chessgpt/src/widgets/typewriter_text.dart';

void main() {
  testWidgets('sanitizes display text before typing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TypewriterText(
          text: '  Read [docs](https://example.com) \u0000www.hidden.test  ',
          characterDelay: Duration(milliseconds: 10),
          charactersPerTick: 1,
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('Read docs'), findsOneWidget);
    expect(find.textContaining('https://'), findsNothing);
    expect(find.textContaining('hidden'), findsNothing);
  });

  testWidgets('advances by grapheme and resets when text changes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TypewriterText(
          text: 'A👨‍👩‍👧‍👦B',
          characterDelay: Duration(milliseconds: 10),
          charactersPerTick: 1,
        ),
      ),
    );

    expect(find.text(''), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text('A'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text('A👨‍👩‍👧‍👦'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: TypewriterText(
          text: 'C',
          characterDelay: Duration(milliseconds: 10),
          charactersPerTick: 1,
        ),
      ),
    );
    expect(find.text(''), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text('C'), findsOneWidget);
    expect(find.textContaining('A'), findsNothing);
  });

  testWidgets('calls onCompleted once for an unchanged text value', (
    tester,
  ) async {
    var completed = 0;

    Widget build({Color? color}) {
      return MaterialApp(
        home: TypewriterText(
          text: 'Done',
          style: TextStyle(color: color),
          characterDelay: const Duration(milliseconds: 10),
          charactersPerTick: 1,
          onCompleted: () => completed += 1,
        ),
      );
    }

    await tester.pumpWidget(build());
    await tester.pump(const Duration(milliseconds: 100));
    expect(completed, 1);

    await tester.pumpWidget(build(color: Colors.red));
    await tester.pump(const Duration(milliseconds: 100));
    expect(completed, 1);
  });

  testWidgets('can reveal multiple graphemes per frame', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TypewriterText(
          text: 'ABCD',
          characterDelay: Duration(milliseconds: 10),
          charactersPerTick: 2,
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text('AB'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text('ABCD'), findsOneWidget);
  });
}
