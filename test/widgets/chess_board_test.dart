import 'package:chess_ai_desktop/src/chess/chess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_ai_desktop/src/models/engine_models.dart';
import 'package:chess_ai_desktop/src/models/game_state.dart';
import 'package:chess_ai_desktop/src/theme/board_theme.dart';
import 'package:chess_ai_desktop/src/widgets/chess_board.dart';

void main() {
  testWidgets('renders hint lines and accepts an equivalent replacement list', (
    tester,
  ) async {
    await _pumpBoard(tester, hintLines: _hintLines());
    expect(tester.takeException(), isNull);
    expect(find.byType(ChessBoard), findsOneWidget);
    expect(
      find.byKey(const ValueKey('hint-lines-1-e2-e4|2-g1-f3')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 120));
    await _pumpBoard(tester, hintLines: List<EngineLine>.of(_hintLines()));
    await tester.pump(const Duration(milliseconds: 120));

    expect(tester.takeException(), isNull);
    expect(find.byType(ChessBoard), findsOneWidget);
    expect(
      find.byKey(const ValueKey('hint-lines-1-e2-e4|2-g1-f3')),
      findsOneWidget,
    );
  });

  testWidgets('maps taps for both player orientations', (tester) async {
    final whiteTaps = <Square>[];
    await _pumpBoard(
      tester,
      orientation: Side.white,
      onSquareTap: (square) async => whiteTaps.add(square),
    );

    await tester.tapAt(
      tester.getBottomLeft(find.byType(ChessBoard)) + const Offset(24, -24),
    );
    expect(whiteTaps.single, _square(0, 0));

    final blackTaps = <Square>[];
    await _pumpBoard(
      tester,
      orientation: Side.black,
      onSquareTap: (square) async => blackTaps.add(square),
    );

    await tester.tapAt(
      tester.getBottomLeft(find.byType(ChessBoard)) + const Offset(24, -24),
    );
    expect(blackTaps.single, _square(7, 7));
  });

  testWidgets('accepts a directly dragged legal move without preselection', (
    tester,
  ) async {
    final droppedMoves = <({Square from, Square to})>[];
    await _pumpBoard(
      tester,
      onMoveDropped: (from, to) async {
        droppedMoves.add((from: from, to: to));
      },
    );

    final board = find.byType(ChessBoard);
    final cell = tester.getSize(board).width / 8;
    final a2Center = tester.getTopLeft(board) + Offset(cell * 0.5, cell * 6.5);
    await tester.dragFrom(a2Center, Offset(0, -cell * 2));
    await tester.pumpAndSettle();

    expect(droppedMoves, hasLength(1));
    expect(droppedMoves.single.from, Square.a2);
    expect(droppedMoves.single.to, Square.a4);
  });

  testWidgets('rejects a directly dragged illegal move', (tester) async {
    final droppedMoves = <({Square from, Square to})>[];
    await _pumpBoard(
      tester,
      onMoveDropped: (from, to) async {
        droppedMoves.add((from: from, to: to));
      },
    );

    final board = find.byType(ChessBoard);
    final cell = tester.getSize(board).width / 8;
    final a2Center = tester.getTopLeft(board) + Offset(cell * 0.5, cell * 6.5);
    await tester.dragFrom(a2Center, Offset(cell, -cell));
    await tester.pumpAndSettle();

    expect(droppedMoves, isEmpty);
  });

  testWidgets('renders game-over overlay with the losing king highlighted', (
    tester,
  ) async {
    await _pumpBoard(
      tester,
      resultKey: 'white-checkmated',
      resultDisplay: GameResultDisplay.lose,
      losingSide: Side.white,
    );

    await tester.pump(const Duration(milliseconds: 700));

    expect(tester.takeException(), isNull);
    expect(find.text('DEFEAT'), findsWidgets);
    expect(find.byKey(const ValueKey('losing-king-e1')), findsOneWidget);
  });

  testWidgets('renders the victory overlay for a player win', (tester) async {
    await _pumpBoard(
      tester,
      resultKey: 'black-checkmated',
      resultDisplay: GameResultDisplay.win,
      losingSide: Side.black,
    );

    await tester.pump(const Duration(milliseconds: 700));

    expect(tester.takeException(), isNull);
    expect(find.text('Victory'), findsWidgets);
  });

  testWidgets('renders the draw overlay for a drawn game', (tester) async {
    await _pumpBoard(
      tester,
      resultKey: 'drawn-game',
      resultDisplay: GameResultDisplay.draw,
      losingSide: null,
    );

    await tester.pump(const Duration(milliseconds: 700));

    expect(tester.takeException(), isNull);
    expect(find.text('Draw'), findsWidgets);
  });

  testWidgets('does not overflow at high text scale in a narrower viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _pumpBoard(
      tester,
      resultKey: 'black-checkmated',
      losingSide: Side.black,
      textScaleFactor: 1.6,
      boardSize: 420,
      hintLines: _hintLines(),
    );
    await tester.pump(const Duration(milliseconds: 700));

    expect(tester.takeException(), isNull);
  });

  testWidgets('renders check highlight for the side to move', (tester) async {
    final checkPosition = Position.setupPosition(
      Rule.chess,
      Setup.parseFen('4k3/8/8/8/8/8/4r3/4K3 w - - 0 1'),
    );

    await _pumpBoard(tester, position: checkPosition);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(ChessBoard), findsOneWidget);
    expect(find.byKey(const ValueKey('checked-king-e1')), findsOneWidget);
  });

  testWidgets('only legal response pieces stay draggable while in check', (
    tester,
  ) async {
    final checkPosition = Position.setupPosition(
      Rule.chess,
      Setup.parseFen('4k3/8/8/8/8/8/P3r3/4K3 w - - 0 1'),
    );

    await _pumpBoard(tester, position: checkPosition);
    await tester.pump();

    expect(find.byType(Draggable<Square>), findsOneWidget);
  });

  test('uses the dragged piece size as the feedback anchor', () {
    expect(pieceDragVisualSize(100), 80);
    expect(pieceDragFeedbackOffset(100), const Offset(-40, -40));
    expect(pieceDragFeedbackOffset(62.5), const Offset(-25, -25));
  });
}

Future<void> _pumpBoard(
  WidgetTester tester, {
  Side orientation = Side.white,
  List<EngineLine> hintLines = const [],
  String? resultKey,
  GameResultDisplay? resultDisplay,
  Side? losingSide,
  Position? position,
  double textScaleFactor = 1,
  double boardSize = 520,
  Future<void> Function(Square square)? onSquareTap,
  Future<void> Function(Square from, Square to)? onMoveDropped,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScaleFactor)),
        child: Scaffold(
          body: Center(
            child: SizedBox.square(
              dimension: boardSize,
              child: ChessBoard(
                position: position ?? Position.initialPosition(Rule.chess),
                orientation: orientation,
                selectedSquare: null,
                legalTargets: const {},
                lastMove: const (from: Square.e2, to: Square.e4),
                hintLines: hintLines,
                themeId: BoardThemeId.classicWood,
                resultKey: resultKey,
                resultDisplay: resultDisplay,
                losingSide: losingSide,
                onSquareTap: onSquareTap ?? (_) async {},
                onMoveDropped: onMoveDropped ?? (_, _) async {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

List<EngineLine> _hintLines() {
  return const [
    EngineLine(multipv: 1, moveUci: 'e2e4', pv: ['e2e4'], depth: 12),
    EngineLine(multipv: 2, moveUci: 'g1f3', pv: ['g1f3'], depth: 12),
  ];
}

Square _square(int file, int rank) => squareFromCoords(file, rank);
