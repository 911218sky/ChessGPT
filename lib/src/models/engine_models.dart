class EngineSettings {
  const EngineSettings({
    required this.moveTimeMs,
    this.depth,
    this.skillLevel,
    this.limitStrength = false,
    this.elo,
    required this.multiPv,
    required this.hashMb,
    required this.threads,
  });

  final int moveTimeMs;
  final int? depth;
  final int? skillLevel;
  final bool limitStrength;
  final int? elo;
  final int multiPv;
  final int hashMb;
  final int threads;

  EngineSettings copyWith({
    int? moveTimeMs,
    Object? depth = _unset,
    Object? skillLevel = _unset,
    bool? limitStrength,
    Object? elo = _unset,
    int? multiPv,
    int? hashMb,
    int? threads,
  }) {
    return EngineSettings(
      moveTimeMs: moveTimeMs ?? this.moveTimeMs,
      depth: identical(depth, _unset) ? this.depth : depth as int?,
      skillLevel: identical(skillLevel, _unset)
          ? this.skillLevel
          : skillLevel as int?,
      limitStrength: limitStrength ?? this.limitStrength,
      elo: identical(elo, _unset) ? this.elo : elo as int?,
      multiPv: multiPv ?? this.multiPv,
      hashMb: hashMb ?? this.hashMb,
      threads: threads ?? this.threads,
    );
  }
}

const Object _unset = Object();

class EngineHardwareProfile {
  const EngineHardwareProfile({
    this.runtime = EngineRuntime.nativeProcess,
    required this.cpuThreads,
    required this.memoryMb,
    required this.recommendedThreads,
    required this.recommendedHashMb,
  });

  final EngineRuntime runtime;
  final int cpuThreads;
  final int? memoryMb;
  final int recommendedThreads;
  final int recommendedHashMb;
}

enum EngineRuntime { nativeProcess, browserWorkerWasm }

class EngineLine {
  const EngineLine({
    required this.multipv,
    required this.moveUci,
    required this.pv,
    required this.depth,
    this.scoreType,
    this.score,
  });

  final int multipv;
  final String moveUci;
  final List<String> pv;
  final int depth;
  final String? scoreType;
  final int? score;

  String get scoreLabel {
    if (score == null || scoreType == null) {
      return '--';
    }
    if (scoreType == 'mate') {
      return 'M$score';
    }
    final pawns = score! / 100;
    return '${pawns >= 0 ? '+' : ''}${pawns.toStringAsFixed(2)}';
  }
}

enum MoveQuality {
  brilliant,
  great,
  best,
  mistake,
  miss,
  blunder;

  String label(bool zhHant) => switch (this) {
    MoveQuality.brilliant => zhHant ? '妙手' : 'Brilliant',
    MoveQuality.great => zhHant ? '好棋' : 'Great',
    MoveQuality.best => zhHant ? '最佳' : 'Best',
    MoveQuality.mistake => zhHant ? '失誤' : 'Mistake',
    MoveQuality.miss => zhHant ? '錯失機會' : 'Miss',
    MoveQuality.blunder => zhHant ? '大失誤' : 'Blunder',
  };

  String get icon => switch (this) {
    MoveQuality.brilliant => '!!',
    MoveQuality.great => '!',
    MoveQuality.best => '*',
    MoveQuality.mistake => '?',
    MoveQuality.miss => 'X',
    MoveQuality.blunder => '??',
  };
}

class MoveReview {
  const MoveReview({
    required this.moveUci,
    required this.bestMoveUci,
    required this.quality,
    required this.expectedDrop,
    required this.centipawnLoss,
    required this.whiteWinPercent,
    required this.drawPercent,
    required this.blackWinPercent,
    required this.beforeEvaluation,
    required this.afterEvaluation,
    required this.elapsedMs,
  });

  final String moveUci;
  final String bestMoveUci;
  final MoveQuality quality;
  final double expectedDrop;
  final int centipawnLoss;
  final int whiteWinPercent;
  final int drawPercent;
  final int blackWinPercent;
  final String beforeEvaluation;
  final String afterEvaluation;
  final int elapsedMs;
}

class MoveReviewSummary {
  const MoveReviewSummary({required this.reviews});

  final List<MoveReview> reviews;

  int get reviewedMoves => reviews.length;

  int get brilliantCount =>
      reviews.where((review) => review.quality == MoveQuality.brilliant).length;

  int get greatCount =>
      reviews.where((review) => review.quality == MoveQuality.great).length;

  int get bestCount =>
      reviews.where((review) => review.quality == MoveQuality.best).length;

  int get goodMoveCount => brilliantCount + greatCount + bestCount;

  int get mistakeCount =>
      reviews.where((review) => review.quality == MoveQuality.mistake).length;

  int get missCount =>
      reviews.where((review) => review.quality == MoveQuality.miss).length;

  int get blunderCount =>
      reviews.where((review) => review.quality == MoveQuality.blunder).length;

  int get problemMoveCount => mistakeCount + missCount + blunderCount;

  int get averageCentipawnLoss {
    if (reviews.isEmpty) {
      return 0;
    }
    final total = reviews.fold<int>(
      0,
      (sum, review) => sum + review.centipawnLoss,
    );
    return (total / reviews.length).round();
  }

  int get averageMoveMs {
    if (reviews.isEmpty) {
      return 0;
    }
    final total = reviews.fold<int>(0, (sum, review) => sum + review.elapsedMs);
    return (total / reviews.length).round();
  }

  int get lastMoveMs => reviews.isEmpty ? 0 : reviews.last.elapsedMs;
}

class EngineAnalysis {
  const EngineAnalysis({
    required this.bestMoveUci,
    required this.depth,
    required this.lines,
    required this.elapsedMs,
  });

  final String bestMoveUci;
  final int depth;
  final List<EngineLine> lines;
  final int elapsedMs;

  EngineLine? get bestLine => lines.isEmpty ? null : lines.first;

  String get evaluationLabel => bestLine?.scoreLabel ?? '--';
}
