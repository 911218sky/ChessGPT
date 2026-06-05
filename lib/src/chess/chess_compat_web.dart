import 'package:dartchess_webok/dartchess_webok.dart';

const List<String> _fileNames = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
const List<String> _rankNames = ['1', '2', '3', '4', '5', '6', '7', '8'];

final List<Square> allSquares = List.unmodifiable(
  List<Square>.generate(64, (index) => index),
);

Square squareFromCoords(int file, int rank) => file + 8 * rank;

int squareFileIndex(Square square) => squareFile(square);

int squareRankIndex(Square square) => squareRank(square);

String squareName(Square square) => toAlgebraic(square);

String squareFileName(Square square) => _fileNames[squareFileIndex(square)];

String squareRankName(Square square) => _rankNames[squareRankIndex(square)];

bool isPromotionRank(Square square) {
  final rank = squareRankIndex(square);
  return rank == 0 || rank == 7;
}

NormalMove moveWithPromotion(NormalMove move, Role role) =>
    NormalMove(from: move.from, to: move.to, promotion: role);

Move? parseUciMove(String uci) => Move.fromUci(uci);
