import 'package:dartchess/dartchess.dart';

const List<Square> allSquares = Square.values;

Square squareFromCoords(int file, int rank) =>
    Square.fromCoords(File(file), Rank(rank));

int squareFileIndex(Square square) => square.file.value;

int squareRankIndex(Square square) => square.rank.value;

String squareName(Square square) => square.name;

String squareFileName(Square square) => square.file.name;

String squareRankName(Square square) => square.rank.name;

bool isPromotionRank(Square square) =>
    square.rank == Rank.first || square.rank == Rank.eighth;

NormalMove moveWithPromotion(NormalMove move, Role role) =>
    move.withPromotion(role);

Move? parseUciMove(String uci) => Move.parse(uci);
