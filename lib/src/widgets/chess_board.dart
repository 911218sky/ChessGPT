import 'dart:math' as math;

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../i18n/app_localizations.dart';
import '../models/engine_models.dart';
import '../models/game_state.dart';
import '../theme/board_theme.dart';

double _clampUnit(double value) => value.clamp(0.0, 1.0).toDouble();
const double pieceDragVisualScale = 0.80;

double pieceDragVisualSize(double squareSize) {
  return squareSize * pieceDragVisualScale;
}

Offset pieceDragFeedbackOffset(double squareSize) {
  final dragSize = pieceDragVisualSize(squareSize);
  return Offset(-dragSize / 2, -dragSize / 2);
}

class ChessBoard extends StatefulWidget {
  const ChessBoard({
    super.key,
    required this.position,
    required this.orientation,
    required this.selectedSquare,
    required this.legalTargets,
    required this.lastMove,
    required this.hintLines,
    required this.themeId,
    required this.resultKey,
    required this.resultDisplay,
    required this.losingSide,
    required this.onSquareTap,
    required this.onMoveDropped,
  });

  final Position position;
  final Side orientation;
  final Square? selectedSquare;
  final Set<Square> legalTargets;
  final LastMove? lastMove;
  final List<EngineLine> hintLines;
  final BoardThemeId themeId;
  final String? resultKey;
  final GameResultDisplay? resultDisplay;
  final Side? losingSide;
  final Future<void> Function(Square square) onSquareTap;
  final Future<void> Function(Square from, Square to) onMoveDropped;

  @override
  State<ChessBoard> createState() => _ChessBoardState();
}

class _ChessBoardState extends State<ChessBoard> {
  late String _positionSignature;
  late Map<Square, Set<Square>> _acceptedDragSources;
  late Set<Square> _actionableSquares;
  late Square? _losingKingSquare;
  late Square? _checkedKingSquare;
  String? _losingKingSignature;
  String? _checkedKingSignature;
  List<EngineLine>? _hintLinesIdentity;
  List<_HintOverlayMove> _hintMoves = const [];
  String _hintMovesSignature = '';

  @override
  void initState() {
    super.initState();
    _positionSignature = widget.position.fen;
    _syncLegalMoveCaches();
    _syncLosingKingSquare();
    _syncCheckedKingSquare();
    _syncHintMoves();
  }

  @override
  void didUpdateWidget(covariant ChessBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextPositionSignature = widget.position.fen;
    if (_positionSignature != nextPositionSignature) {
      _positionSignature = nextPositionSignature;
      _syncLegalMoveCaches();
      _losingKingSignature = null;
      _checkedKingSignature = null;
    }
    _syncLosingKingSquare();
    _syncCheckedKingSquare();
    _syncHintMoves();
  }

  @override
  Widget build(BuildContext context) {
    final theme = boardThemeStyle(widget.themeId);

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1180, maxHeight: 1180),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [theme.frameStart, theme.frameEnd],
          ),
          boxShadow: const [
            BoxShadow(
              blurRadius: 28,
              color: Color(0x44000000),
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: DecoratedBox(
            decoration: BoxDecoration(color: theme.darkSquare),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _BoardGridLayer(
                  position: widget.position,
                  orientation: widget.orientation,
                  selectedSquare: widget.selectedSquare,
                  legalTargets: widget.legalTargets,
                  lastMove: widget.lastMove,
                  resultKey: widget.resultKey,
                  resultDisplay: widget.resultDisplay,
                  losingSide: widget.losingSide,
                  losingKingSquare: _losingKingSquare,
                  checkedKingSquare: _checkedKingSquare,
                  actionableSquares: _actionableSquares,
                  acceptedDragSources: _acceptedDragSources,
                  theme: theme,
                  onSquareTap: widget.onSquareTap,
                  onMoveDropped: widget.onMoveDropped,
                ),
                if (_hintMoves.isNotEmpty)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: RepaintBoundary(
                        child: _HintLinesOverlay(
                          key: ValueKey('hint-lines-$_hintMovesSignature'),
                          moves: _hintMoves,
                          movesSignature: _hintMovesSignature,
                          orientation: widget.orientation,
                          theme: theme,
                        ),
                      ),
                    ),
                  ),
                if (widget.resultKey != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: _GameOverOverlay(
                        key: ValueKey('game-over-${widget.resultKey}'),
                        orientation: widget.orientation,
                        resultDisplay: widget.resultDisplay,
                        losingSide: widget.losingSide,
                        losingKingSquare: _losingKingSquare,
                        theme: theme,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _syncHintMoves() {
    if (identical(_hintLinesIdentity, widget.hintLines)) {
      return;
    }
    final moves = _hintMovesFromLines(widget.hintLines);
    final signature = _hintMovesSignatureFor(moves);
    if (_hintMovesSignature == signature) {
      _hintLinesIdentity = widget.hintLines;
      return;
    }
    _hintLinesIdentity = widget.hintLines;
    _hintMoves = moves;
    _hintMovesSignature = signature;
  }

  void _syncLosingKingSquare() {
    final signature = '$_positionSignature|${widget.losingSide?.name}';
    if (_losingKingSignature == signature) {
      return;
    }
    _losingKingSignature = signature;
    _losingKingSquare = _losingKingSquareFor(
      widget.position,
      widget.losingSide,
    );
  }

  void _syncCheckedKingSquare() {
    final signature =
        '$_positionSignature|${widget.position.turn.name}|${widget.position.isCheck}';
    if (_checkedKingSignature == signature) {
      return;
    }
    _checkedKingSignature = signature;
    _checkedKingSquare = _checkedKingSquareFor(widget.position);
  }

  List<_HintOverlayMove> _hintMovesFromLines(List<EngineLine> lines) {
    final moves = <_HintOverlayMove>[];
    for (final line in lines) {
      if (line.moveUci.length < 4) {
        continue;
      }
      final move = Move.parse(line.moveUci);
      switch (move) {
        case NormalMove(from: final from, to: final to):
          moves.add(
            _HintOverlayMove(rank: line.multipv, move: (from: from, to: to)),
          );
        case null:
        case _:
          break;
      }
    }
    moves.sort((a, b) => a.rank.compareTo(b.rank));
    return moves;
  }

  String _hintMovesSignatureFor(List<_HintOverlayMove> moves) {
    return moves
        .map(
          (move) => '${move.rank}-${move.move.from.name}-${move.move.to.name}',
        )
        .join('|');
  }

  void _syncLegalMoveCaches() {
    final sourcesByTarget = <Square, Set<Square>>{};
    final actionable = <Square>{};
    final legalMoves = makeLegalMoves(widget.position);
    for (final entry in legalMoves.entries) {
      if (entry.value.isEmpty) {
        continue;
      }
      actionable.add(entry.key);
      for (final target in entry.value) {
        (sourcesByTarget[target] ??= <Square>{}).add(entry.key);
      }
    }

    _acceptedDragSources = sourcesByTarget;
    _actionableSquares = actionable;
  }

  Square? _losingKingSquareFor(Position position, Side? losingSide) {
    if (losingSide == null) {
      return null;
    }
    return _kingSquareFor(position, losingSide);
  }

  Square? _checkedKingSquareFor(Position position) {
    if (!position.isCheck) {
      return null;
    }
    return _kingSquareFor(position, position.turn);
  }

  Square? _kingSquareFor(Position position, Side side) {
    final board = position.board;
    for (final square in Square.values) {
      final current = board.pieceAt(square);
      if (current?.color == side && current?.role == Role.king) {
        return square;
      }
    }
    return null;
  }
}

class _BoardGridLayer extends StatelessWidget {
  const _BoardGridLayer({
    required this.position,
    required this.orientation,
    required this.selectedSquare,
    required this.legalTargets,
    required this.lastMove,
    required this.resultKey,
    required this.resultDisplay,
    required this.losingSide,
    required this.losingKingSquare,
    required this.checkedKingSquare,
    required this.actionableSquares,
    required this.acceptedDragSources,
    required this.theme,
    required this.onSquareTap,
    required this.onMoveDropped,
  });

  final Position position;
  final Side orientation;
  final Square? selectedSquare;
  final Set<Square> legalTargets;
  final LastMove? lastMove;
  final String? resultKey;
  final GameResultDisplay? resultDisplay;
  final Side? losingSide;
  final Square? losingKingSquare;
  final Square? checkedKingSquare;
  final Set<Square> actionableSquares;
  final Map<Square, Set<Square>> acceptedDragSources;
  final BoardThemeStyle theme;
  final Future<void> Function(Square square) onSquareTap;
  final Future<void> Function(Square from, Square to) onMoveDropped;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
      ),
      itemCount: 64,
      itemBuilder: (context, index) {
        final row = index ~/ 8;
        final col = index % 8;
        final square = _displaySquare(row, col);
        final piece = position.board.pieceAt(square);
        final isSelected = selectedSquare == square;
        final isTarget = legalTargets.contains(square);
        final acceptedSources = acceptedDragSources[square] ?? const <Square>{};
        final isLastMove = square == lastMove?.from || square == lastMove?.to;
        final baseIsLight = (square.file + square.rank).isOdd;
        final canRespondToCheck =
            piece == null ||
            piece.color != position.turn ||
            !position.isCheck ||
            actionableSquares.contains(square);

        return _SquareButton(
          resultKey: resultKey,
          resultDisplay: resultDisplay,
          losingSide: losingSide,
          losingKingSquare: losingKingSquare,
          checkedKingSquare: checkedKingSquare,
          square: square,
          piece: piece,
          draggable:
              piece != null &&
              piece.color == position.turn &&
              canRespondToCheck,
          canRespondToCheck: canRespondToCheck,
          isLight: baseIsLight,
          isSelected: isSelected,
          isTarget: isTarget,
          acceptedSources: acceptedSources,
          isLastMove: isLastMove,
          showFileLabel: row == 7,
          showRankLabel: col == 0,
          theme: theme,
          onTap: () => onSquareTap(square),
          onDrop: (from) => onMoveDropped(from, square),
        );
      },
    );
  }

  Square _displaySquare(int row, int col) {
    final file = orientation == Side.white ? col : 7 - col;
    final rank = orientation == Side.white ? 7 - row : row;
    return Square.fromCoords(File(file), Rank(rank));
  }
}

class _HintOverlayMove {
  const _HintOverlayMove({required this.rank, required this.move});

  final int rank;
  final LastMove move;
}

class _HintLinesOverlay extends StatefulWidget {
  const _HintLinesOverlay({
    super.key,
    required this.moves,
    required this.movesSignature,
    required this.orientation,
    required this.theme,
  });

  final List<_HintOverlayMove> moves;
  final String movesSignature;
  final Side orientation;
  final BoardThemeStyle theme;

  @override
  State<_HintLinesOverlay> createState() => _HintLinesOverlayState();
}

class _HintLinesOverlayState extends State<_HintLinesOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant _HintLinesOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movesSignature != widget.movesSignature) {
      _controller
        ..reset()
        ..repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _HintLinesPainter(
            moves: widget.moves,
            movesSignature: widget.movesSignature,
            orientation: widget.orientation,
            theme: widget.theme,
            progress: _controller.value,
          ),
        );
      },
    );
  }
}

class _HintLinesPainter extends CustomPainter {
  const _HintLinesPainter({
    required this.moves,
    required this.movesSignature,
    required this.orientation,
    required this.theme,
    required this.progress,
  });

  final List<_HintOverlayMove> moves;
  final String movesSignature;
  final Side orientation;
  final BoardThemeStyle theme;
  final double progress;

  static const _palette = <Color>[
    Color(0xFF9BFF88),
    Color(0xFF57B7FF),
    Color(0xFFFFA94F),
    Color(0xFFE87BFF),
    Color(0xFFFF6B8A),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (moves.isEmpty) {
      return;
    }
    final cell = size.width / 8;
    final safeProgress = _clampUnit(progress);
    final pulse =
        0.5 +
        0.5 *
            Curves.easeInOut.transform(
              safeProgress < 0.5
                  ? _clampUnit(safeProgress * 2)
                  : _clampUnit((1 - safeProgress) * 2),
            );

    for (var index = moves.length - 1; index >= 0; index--) {
      final move = moves[index];
      final from = _centerFor(move.move.from, cell);
      final to = _centerFor(move.move.to, cell);
      final color = _palette[(move.rank - 1) % _palette.length];
      final emphasis = index == 0 ? 1.0 : (1 - (index * 0.12)).clamp(0.56, 0.9);

      _drawSquareGlow(
        canvas,
        from,
        cell,
        color,
        pulse * emphasis,
        isSource: true,
        alphaScale: emphasis,
      );
      _drawSquareGlow(
        canvas,
        to,
        cell,
        color,
        pulse * emphasis,
        isSource: false,
        alphaScale: emphasis,
      );
      _drawTravelingSpark(
        canvas,
        from,
        to,
        cell,
        color,
        _clampUnit((safeProgress + (index * 0.11)) % 1),
        emphasis,
      );
      _drawArrow(canvas, from, to, cell, color, pulse, emphasis);
      _drawRankBadge(canvas, to, cell, color, pulse, move.rank, index);
    }
  }

  void _drawSquareGlow(
    Canvas canvas,
    Offset center,
    double cell,
    Color color,
    double pulse, {
    required bool isSource,
    required double alphaScale,
  }) {
    final rect = Rect.fromCenter(
      center: center,
      width: cell * (isSource ? 0.84 : 0.92),
      height: cell * (isSource ? 0.84 : 0.92),
    );
    final radius = Radius.circular(cell * 0.18);
    final fill = Paint()
      ..color = color.withValues(alpha: (isSource ? 0.14 : 0.22) * alphaScale)
      ..style = PaintingStyle.fill;
    final ring = Paint()
      ..color = color.withValues(
        alpha: (0.36 + pulse * 0.24).clamp(0.0, 1.0) * alphaScale,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * (0.035 + pulse * 0.018);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), fill);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), ring);

    final halo = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.34 * pulse * alphaScale),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: cell * 0.72));
    canvas.drawCircle(center, cell * (0.46 + pulse * 0.22), halo);
  }

  void _drawArrow(
    Canvas canvas,
    Offset from,
    Offset to,
    double cell,
    Color color,
    double pulse,
    double emphasis,
  ) {
    final vector = to - from;
    final distance = vector.distance;
    if (distance == 0) {
      return;
    }
    final direction = vector / distance;
    final start = from + direction * cell * 0.28;
    final end = to - direction * cell * 0.34;
    final side = Offset(-direction.dy, direction.dx);

    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.22 * emphasis)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = cell * (0.14 + 0.03 * emphasis);
    canvas.drawLine(
      start + const Offset(0, 3),
      end + const Offset(0, 3),
      shadow,
    );

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0.28 + 0.18 * emphasis),
          color.withValues(alpha: 0.62 + 0.26 * emphasis),
        ],
      ).createShader(Rect.fromPoints(start, end))
      ..strokeCap = StrokeCap.round
      ..strokeWidth = cell * (0.08 + pulse * 0.015 + emphasis * 0.03);
    canvas.drawLine(start, end, paint);

    final headLength = cell * 0.28;
    final headWidth = cell * 0.18;
    final arrowHead = Path()
      ..moveTo(
        to.dx - direction.dx * cell * 0.18,
        to.dy - direction.dy * cell * 0.18,
      )
      ..lineTo(
        end.dx - direction.dx * headLength + side.dx * headWidth,
        end.dy - direction.dy * headLength + side.dy * headWidth,
      )
      ..lineTo(
        end.dx - direction.dx * headLength - side.dx * headWidth,
        end.dy - direction.dy * headLength - side.dy * headWidth,
      )
      ..close();
    canvas.drawPath(
      arrowHead.shift(const Offset(0, 3)),
      Paint()..color = Colors.black.withValues(alpha: 0.2 * emphasis),
    );
    canvas.drawPath(
      arrowHead,
      Paint()..color = color.withValues(alpha: 0.68 + 0.22 * emphasis),
    );
  }

  void _drawTravelingSpark(
    Canvas canvas,
    Offset from,
    Offset to,
    double cell,
    Color color,
    double progress,
    double emphasis,
  ) {
    final vector = to - from;
    final distance = vector.distance;
    if (distance == 0) {
      return;
    }
    final direction = vector / distance;
    final sparkProgress = Curves.easeInOutCubic.transform(_clampUnit(progress));
    final center = from + direction * distance * sparkProgress;
    final radius = cell * 0.105;
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: (0.36 + 0.28 * emphasis)),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 3.2));
    canvas.drawCircle(center, radius * 3.2, glow);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(
          0xFFFFF9D6,
        ).withValues(alpha: 0.54 + 0.28 * emphasis),
    );
  }

  void _drawRankBadge(
    Canvas canvas,
    Offset target,
    double cell,
    Color color,
    double pulse,
    int rank,
    int index,
  ) {
    final horizontal = index.isEven ? 0.28 : -0.28;
    final vertical = index.isEven ? -0.30 : 0.30;
    final badgeCenter = target + Offset(cell * horizontal, cell * vertical);
    final radius = cell * (0.17 + pulse * 0.02);
    canvas.drawCircle(
      badgeCenter + const Offset(0, 2),
      radius,
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );
    canvas.drawCircle(
      badgeCenter,
      radius,
      Paint()..color = const Color(0xFF1A1F22).withValues(alpha: 0.96),
    );
    canvas.drawCircle(
      badgeCenter,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.88)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.035,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: '$rank',
        style: TextStyle(
          color: color,
          fontSize: cell * 0.24,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      badgeCenter - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  Offset _centerFor(Square square, double cell) {
    final file = square.file.value;
    final rank = square.rank.value;
    final col = orientation == Side.white ? file : 7 - file;
    final row = orientation == Side.white ? 7 - rank : rank;
    return Offset((col + 0.5) * cell, (row + 0.5) * cell);
  }

  @override
  bool shouldRepaint(covariant _HintLinesPainter oldDelegate) {
    return oldDelegate.movesSignature != movesSignature ||
        oldDelegate.orientation != orientation ||
        oldDelegate.theme != theme ||
        oldDelegate.progress != progress;
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({
    required this.resultKey,
    required this.resultDisplay,
    required this.losingSide,
    required this.losingKingSquare,
    required this.checkedKingSquare,
    required this.square,
    required this.piece,
    required this.draggable,
    required this.canRespondToCheck,
    required this.isLight,
    required this.isSelected,
    required this.isTarget,
    required this.acceptedSources,
    required this.isLastMove,
    required this.showFileLabel,
    required this.showRankLabel,
    required this.theme,
    required this.onTap,
    required this.onDrop,
  });

  final String? resultKey;
  final GameResultDisplay? resultDisplay;
  final Side? losingSide;
  final Square? losingKingSquare;
  final Square? checkedKingSquare;
  final Square square;
  final Piece? piece;
  final bool draggable;
  final bool canRespondToCheck;
  final bool isLight;
  final bool isSelected;
  final bool isTarget;
  final Set<Square> acceptedSources;
  final bool isLastMove;
  final bool showFileLabel;
  final bool showRankLabel;
  final BoardThemeStyle theme;
  final VoidCallback onTap;
  final Future<void> Function(Square from) onDrop;

  @override
  Widget build(BuildContext context) {
    final baseColor = isLight ? theme.lightSquare : theme.darkSquare;
    final labelColor = isLight ? theme.labelOnLight : theme.labelOnDark;
    final isLosingKing = square == losingKingSquare;
    final isCheckedKing = !isLosingKing && square == checkedKingSquare;
    final losingOverlay = isLosingKing
        ? BoxDecoration(
            gradient: RadialGradient(
              colors: [
                const Color(0xFFE34444).withValues(alpha: 0.34),
                const Color(0xFF5A0E0E).withValues(alpha: 0.14),
                Colors.transparent,
              ],
            ),
            border: Border.all(
              color: const Color(0xFFFF6E6E).withValues(alpha: 0.72),
              width: 3,
            ),
          )
        : null;
    final checkedOverlay = isCheckedKing
        ? BoxDecoration(
            gradient: RadialGradient(
              colors: [
                const Color(0xFFFF6B6B).withValues(alpha: 0.28),
                const Color(0xFF7A1717).withValues(alpha: 0.12),
                Colors.transparent,
              ],
            ),
            border: Border.all(
              color: const Color(0xFFFF8E8E).withValues(alpha: 0.88),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 16,
                spreadRadius: 1,
                color: const Color(0xFFD52F2F).withValues(alpha: 0.20),
              ),
            ],
          )
        : null;
    final dimmedForCheck =
        piece != null && piece!.color == Side.white ||
            piece?.color == Side.black
        ? !canRespondToCheck
        : false;

    return DragTarget<Square>(
      onWillAcceptWithDetails: (details) =>
          acceptedSources.contains(details.data),
      onAcceptWithDetails: (details) => onDrop(details.data),
      builder: (context, candidateData, rejectedData) {
        final hovering = candidateData.isNotEmpty;
        return Material(
          color: baseColor,
          child: InkWell(
            onTap: dimmedForCheck ? null : onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(
                            alpha: isLight
                                ? theme.textureAlpha + 0.04
                                : theme.textureAlpha,
                          ),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SquareTexturePainter(
                      color: isLight
                          ? Colors.white.withValues(alpha: theme.textureAlpha)
                          : Colors.black.withValues(alpha: theme.textureAlpha),
                    ),
                  ),
                ),
                if (theme.boardTextureSet != null)
                  Positioned.fill(
                    child: Opacity(
                      opacity: theme.boardTextureOpacity,
                      child: Image.asset(
                        theme.boardTextureSet!.assetFor(isLight),
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                if (isLastMove)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.lastMove.withValues(alpha: 0.22),
                        border: Border.all(color: theme.lastMove, width: 3),
                      ),
                    ),
                  ),
                if (isSelected || hovering)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: hovering
                            ? theme.selected.withValues(alpha: 0.28)
                            : theme.selected,
                        border: Border.all(
                          color: theme.selectedBorder,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                if (losingOverlay != null)
                  Positioned.fill(
                    child: DecoratedBox(
                      key: ValueKey('losing-king-${square.name}'),
                      decoration: losingOverlay,
                    ),
                  ),
                if (checkedOverlay != null)
                  Positioned.fill(
                    child: DecoratedBox(
                      key: ValueKey('checked-king-${square.name}'),
                      decoration: checkedOverlay,
                    ),
                  ),
                if (showRankLabel)
                  Positioned(
                    left: 6,
                    top: 3,
                    child: Text(
                      square.rank.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: labelColor,
                      ),
                    ),
                  ),
                if (showFileLabel)
                  Positioned(
                    right: 6,
                    bottom: 3,
                    child: Text(
                      square.file.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: labelColor,
                      ),
                    ),
                  ),
                if (isTarget)
                  Center(
                    child: Container(
                      width: piece == null ? 18 : 56,
                      height: piece == null ? 18 : 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: piece == null
                            ? theme.target
                            : Colors.transparent,
                        border: piece == null
                            ? null
                            : Border.all(color: theme.captureRing, width: 4),
                      ),
                    ),
                  ),
                if (piece != null)
                  Center(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 160),
                      opacity: dimmedForCheck ? 0.34 : 1,
                      child: RepaintBoundary(
                        child: _AnimatedBoardPiece(
                          resultKey: resultKey,
                          piece: piece!,
                          resultDisplay: resultDisplay,
                          losingSide: losingSide,
                          isLosingKing: isLosingKing,
                          child: FractionallySizedBox(
                            widthFactor: 0.92,
                            heightFactor: 0.92,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final pieceSize = math.min(
                                  constraints.maxWidth,
                                  constraints.maxHeight,
                                );
                                final feedbackSize = pieceDragVisualSize(
                                  pieceSize,
                                );

                                return draggable
                                    ? Draggable<Square>(
                                        data: square,
                                        rootOverlay: true,
                                        dragAnchorStrategy:
                                            childDragAnchorStrategy,
                                        feedbackOffset: pieceDragFeedbackOffset(
                                          pieceSize,
                                        ),
                                        feedback: RepaintBoundary(
                                          child: SizedBox.square(
                                            dimension: feedbackSize,
                                            child: _ChessPieceAsset(
                                              piece: piece!,
                                              theme: theme,
                                            ),
                                          ),
                                        ),
                                        childWhenDragging:
                                            const SizedBox.shrink(),
                                        child: SizedBox.square(
                                          dimension: pieceSize,
                                          child: _ChessPieceAsset(
                                            piece: piece!,
                                            theme: theme,
                                          ),
                                        ),
                                      )
                                    : SizedBox.square(
                                        dimension: pieceSize,
                                        child: _ChessPieceAsset(
                                          piece: piece!,
                                          theme: theme,
                                        ),
                                      );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedBoardPiece extends StatefulWidget {
  const _AnimatedBoardPiece({
    required this.resultKey,
    required this.piece,
    required this.resultDisplay,
    required this.losingSide,
    required this.isLosingKing,
    required this.child,
  });

  final String? resultKey;
  final Piece piece;
  final GameResultDisplay? resultDisplay;
  final Side? losingSide;
  final bool isLosingKing;
  final Widget child;

  @override
  State<_AnimatedBoardPiece> createState() => _AnimatedBoardPieceState();
}

class _AnimatedBoardPieceState extends State<_AnimatedBoardPiece>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  String? _animatedResultKey;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 880),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _AnimatedBoardPiece oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    final shouldFall =
        widget.resultKey != null &&
        widget.resultDisplay == GameResultDisplay.lose &&
        widget.piece.color == widget.losingSide;
    if (!shouldFall) {
      _animatedResultKey = null;
      _controller.value = 0;
      return;
    }
    if (_animatedResultKey == widget.resultKey) {
      return;
    }
    _animatedResultKey = widget.resultKey;
    _controller
      ..value = 0
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shouldFall =
        widget.resultKey != null &&
        widget.resultDisplay == GameResultDisplay.lose &&
        widget.piece.color == widget.losingSide;
    if (!shouldFall) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final raw = Curves.easeInCubic.transform(_clampUnit(_controller.value));
        final drop = raw * raw;
        final rotation = (widget.isLosingKing ? -0.22 : 0.14) * raw;
        final redTint = widget.isLosingKing ? 0.36 : 0.22;

        return Opacity(
          opacity: (1 - drop * 0.92).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 220 * drop),
            child: Transform.rotate(
              angle: rotation,
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  const Color(0xFFD73B3B).withValues(alpha: redTint * raw),
                  BlendMode.modulate,
                ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GameOverOverlay extends StatefulWidget {
  const _GameOverOverlay({
    super.key,
    required this.orientation,
    required this.resultDisplay,
    required this.losingSide,
    required this.losingKingSquare,
    required this.theme,
  });

  final Side orientation;
  final GameResultDisplay? resultDisplay;
  final Side? losingSide;
  final Square? losingKingSquare;
  final BoardThemeStyle theme;

  @override
  State<_GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<_GameOverOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(
      Localizations.localeOf(context).languageCode == 'zh'
          ? AppLocale.zhHant
          : AppLocale.en,
    );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final animationValue = _clampUnit(_controller.value);
        final textOpacity = _lossTextOpacity(animationValue);
        final textScale = _lossTextScale(animationValue);
        final isDraw = widget.resultDisplay == GameResultDisplay.draw;
        final playerLost = widget.resultDisplay == GameResultDisplay.lose;
        final flashText = isDraw
            ? strings.resultDrawTitle
            : playerLost
            ? strings.resultLoseFlash
            : strings.resultWinTitle;
        final strokeColor = isDraw
            ? const Color(0xFF10243B)
            : playerLost
            ? const Color(0xFF3B0006)
            : const Color(0xFF15301A);
        final glowShadow = isDraw
            ? const Color(0xCC0B223F)
            : playerLost
            ? const Color(0xCC2A0005)
            : const Color(0xCC0E2C14);
        final fillGradient = isDraw
            ? const [Color(0xFFF1F7FF), Color(0xFF96C2FF), Color(0xFF5C8DFF)]
            : playerLost
            ? const [Color(0xFFFFF0F0), Color(0xFFFF8F8F), Color(0xFFFF4F5E)]
            : const [Color(0xFFF7FFE8), Color(0xFFA7F18A), Color(0xFF52D66F)];
        final accentShadow = isDraw
            ? const Color(0x9967A9FF)
            : playerLost
            ? const Color(0x99FF5A66)
            : const Color(0x9980FF94);
        final baseStyle = Theme.of(context).textTheme.displayMedium?.copyWith(
          fontWeight: FontWeight.w900,
          fontSize: 64,
          letterSpacing: 0,
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _GameOverPainter(
                orientation: widget.orientation,
                resultDisplay: widget.resultDisplay,
                losingSide: widget.losingSide,
                losingKingSquare: widget.losingKingSquare,
                theme: widget.theme,
                progress: animationValue,
              ),
            ),
            if (textOpacity > 0)
              Center(
                child: Opacity(
                  opacity: textOpacity,
                  child: Transform.scale(
                    scale: textScale,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          flashText,
                          style: baseStyle?.copyWith(
                            foreground: Paint()
                              ..style = PaintingStyle.stroke
                              ..strokeWidth = 7
                              ..color = strokeColor,
                            shadows: [
                              Shadow(
                                blurRadius: 30,
                                color: glowShadow,
                                offset: Offset(0, 12),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          flashText,
                          style: baseStyle?.copyWith(
                            foreground: Paint()
                              ..shader =
                                  LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: fillGradient,
                                  ).createShader(
                                    const Rect.fromLTWH(0, 0, 220, 96),
                                  ),
                            shadows: [
                              Shadow(
                                blurRadius: 24,
                                color: glowShadow.withValues(alpha: 0.9),
                                offset: Offset(0, 10),
                              ),
                              Shadow(blurRadius: 10, color: accentShadow),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  double _lossTextScale(double progress) {
    final t = _clampUnit(progress);
    if (t < 0.18) {
      return 1.36 - (0.22 * Curves.easeOutBack.transform(_clampUnit(t / 0.18)));
    }
    if (t < 0.5) {
      return 1.14 -
          (0.12 * Curves.easeOut.transform(_clampUnit((t - 0.18) / 0.32)));
    }
    if (t < 0.82) {
      return 1.02;
    }
    return 1.02 -
        (0.04 * Curves.easeIn.transform(_clampUnit((t - 0.82) / 0.18)));
  }

  double _lossTextOpacity(double progress) {
    final t = _clampUnit(progress);
    if (t < 0.1) {
      return Curves.easeOut.transform(_clampUnit(t / 0.1));
    }
    if (t < 0.58) {
      return 1;
    }
    if (t < 0.9) {
      return 1 - Curves.easeIn.transform(_clampUnit((t - 0.58) / 0.32));
    }
    return 0;
  }
}

class _GameOverPainter extends CustomPainter {
  const _GameOverPainter({
    required this.orientation,
    required this.resultDisplay,
    required this.losingSide,
    required this.losingKingSquare,
    required this.theme,
    required this.progress,
  });

  final Side orientation;
  final GameResultDisplay? resultDisplay;
  final Side? losingSide;
  final Square? losingKingSquare;
  final BoardThemeStyle theme;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayAlpha = Curves.easeOutCubic.transform(_clampUnit(progress));
    final tint = switch (resultDisplay) {
      GameResultDisplay.win => const Color(0xFF39C86E),
      GameResultDisplay.lose => const Color(0xFFB31224),
      GameResultDisplay.draw => const Color(0xFF73A7FF),
      null => const Color(0xFF73A7FF),
    };
    final isDraw = resultDisplay == GameResultDisplay.draw;
    final isWin = resultDisplay == GameResultDisplay.win;
    final isLose = resultDisplay == GameResultDisplay.lose;

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            tint.withValues(alpha: isDraw ? 0.06 : 0.08 * overlayAlpha),
            Colors.black.withValues(alpha: 0.10 * overlayAlpha),
            tint.withValues(alpha: isDraw ? 0.08 : 0.16 * overlayAlpha),
          ],
        ).createShader(Offset.zero & size),
    );

    final kingSquare = losingKingSquare;
    if (kingSquare == null) {
      return;
    }

    final cell = size.width / 8;
    final center = _centerFor(kingSquare, cell);
    final pulse = 0.6 + 0.4 * math.sin(progress * math.pi * 2.2);
    final radius = cell * (0.44 + 0.10 * overlayAlpha + 0.06 * pulse);
    final ringColor = isLose
        ? const Color(0xFFFF7777)
        : isWin
        ? const Color(0xFF76F0A0)
        : const Color(0xFF7FAFFF);
    final glowColors = isLose
        ? [
            const Color(0xFFFF5F5F).withValues(alpha: 0.24 * overlayAlpha),
            const Color(0xFF6D1119).withValues(alpha: 0.12 * overlayAlpha),
            Colors.transparent,
          ]
        : isWin
        ? [
            const Color(0xFF7FFFB0).withValues(alpha: 0.22 * overlayAlpha),
            const Color(0xFF155024).withValues(alpha: 0.12 * overlayAlpha),
            Colors.transparent,
          ]
        : [
            const Color(0xFF86B5FF).withValues(alpha: 0.22 * overlayAlpha),
            const Color(0xFF12315F).withValues(alpha: 0.12 * overlayAlpha),
            Colors.transparent,
          ];

    canvas.drawCircle(
      center,
      radius * 1.8,
      Paint()
        ..shader = RadialGradient(
          colors: glowColors,
        ).createShader(Rect.fromCircle(center: center, radius: radius * 1.8)),
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.06
        ..color = ringColor.withValues(alpha: 0.72 * overlayAlpha),
    );
  }

  Offset _centerFor(Square square, double cell) {
    final file = square.file.value;
    final rank = square.rank.value;
    final col = orientation == Side.white ? file : 7 - file;
    final row = orientation == Side.white ? 7 - rank : rank;
    return Offset((col + 0.5) * cell, (row + 0.5) * cell);
  }

  @override
  bool shouldRepaint(covariant _GameOverPainter oldDelegate) {
    return oldDelegate.orientation != orientation ||
        oldDelegate.resultDisplay != resultDisplay ||
        oldDelegate.losingSide != losingSide ||
        oldDelegate.losingKingSquare != losingKingSquare ||
        oldDelegate.theme != theme ||
        oldDelegate.progress != progress;
  }
}

class _ChessPieceAsset extends StatelessWidget {
  const _ChessPieceAsset({required this.piece, required this.theme});

  final Piece piece;
  final BoardThemeStyle theme;

  @override
  Widget build(BuildContext context) {
    final assetCode = switch ((piece.color, piece.role)) {
      (Side.white, Role.king) => 'lk',
      (Side.white, Role.queen) => 'lq',
      (Side.white, Role.rook) => 'lr',
      (Side.white, Role.bishop) => 'lb',
      (Side.white, Role.knight) => 'ln',
      (Side.white, Role.pawn) => 'lp',
      (Side.black, Role.king) => 'dk',
      (Side.black, Role.queen) => 'dq',
      (Side.black, Role.rook) => 'dr',
      (Side.black, Role.bishop) => 'db',
      (Side.black, Role.knight) => 'dn',
      (Side.black, Role.pawn) => 'dp',
    };

    return Image.asset(
      theme.pieceSet.assetFor(assetCode),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }
}

class _SquareTexturePainter extends CustomPainter {
  const _SquareTexturePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final step = size.width / 4;
    for (var i = 1; i < 4; i++) {
      final offset = step * i;
      canvas.drawLine(
        Offset(offset, 0),
        Offset(offset + size.width * 0.18, size.height),
        paint,
      );
      canvas.drawLine(
        Offset(0, offset),
        Offset(size.width, offset - size.height * 0.14),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SquareTexturePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
