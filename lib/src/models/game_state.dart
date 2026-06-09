import 'package:chessgpt/src/chess/chess.dart';

import 'engine_models.dart';
import 'session_config.dart';
import '../i18n/app_localizations.dart';

const _unset = Object();

typedef LastMove = ({Square from, Square to});

enum DialogueMessageSource { llm, fallback, disabled }

enum GameResultDisplay { win, lose, draw }

class GameState {
  GameState({
    required this.position,
    required this.config,
    required this.initialized,
    required this.aiThinking,
    required this.coachThinking,
    required this.selectedSquare,
    required Set<Square> legalTargets,
    required this.hint,
    required this.opponentAnalysis,
    required this.latestReview,
    required List<MoveReview> reviewHistory,
    required this.hardwareProfile,
    required this.whiteClockMs,
    required this.blackClockMs,
    required this.lastClockStartedAt,
    required this.timeoutWinner,
    required this.statusText,
    required this.opponentMessage,
    required this.coachMessage,
    required this.opponentMessageSource,
    required this.coachMessageSource,
    required List<String> availableLlmModels,
    required this.llmTesting,
    required this.llmFetchingModels,
    required this.llmStatusMessage,
    required this.lastLlmError,
    required this.llmStats,
    required List<String> eventLog,
    required List<String> moveHistory,
    required this.canUndo,
    required this.canRedo,
    required this.lastMove,
    required this.errorMessage,
  }) : legalTargets = Set.unmodifiable(legalTargets),
       availableLlmModels = List.unmodifiable(availableLlmModels),
       reviewHistory = List.unmodifiable(reviewHistory),
       eventLog = List.unmodifiable(eventLog),
       moveHistory = List.unmodifiable(moveHistory);

  factory GameState.initial({GameSessionConfig? config}) {
    final session = config ?? GameSessionConfig.defaults();
    final strings = AppStrings.of(session.locale);
    return GameState(
      position: Position.initialPosition(Rule.chess),
      config: session,
      initialized: false,
      aiThinking: false,
      coachThinking: false,
      selectedSquare: null,
      legalTargets: const {},
      hint: null,
      opponentAnalysis: null,
      latestReview: null,
      reviewHistory: const [],
      hardwareProfile: null,
      whiteClockMs: session.timeControl.secondsPerSide == null
          ? null
          : session.timeControl.secondsPerSide! * 1000,
      blackClockMs: session.timeControl.secondsPerSide == null
          ? null
          : session.timeControl.secondsPerSide! * 1000,
      lastClockStartedAt: session.timeControl.secondsPerSide == null
          ? null
          : DateTime.now(),
      timeoutWinner: null,
      statusText: strings.preparingMatch,
      opponentMessage: strings.defaultOpponentMessage,
      coachMessage: strings.defaultCoachMessage,
      opponentMessageSource: DialogueMessageSource.fallback,
      coachMessageSource: DialogueMessageSource.fallback,
      availableLlmModels: const [],
      llmTesting: false,
      llmFetchingModels: false,
      llmStatusMessage: null,
      lastLlmError: null,
      llmStats: const LlmUsageStats(),
      eventLog: const [],
      moveHistory: const [],
      canUndo: false,
      canRedo: false,
      lastMove: null,
      errorMessage: null,
    );
  }

  final Position position;
  final GameSessionConfig config;
  final bool initialized;
  final bool aiThinking;
  final bool coachThinking;
  final Square? selectedSquare;
  final Set<Square> legalTargets;
  final EngineAnalysis? hint;
  final EngineAnalysis? opponentAnalysis;
  final MoveReview? latestReview;
  final List<MoveReview> reviewHistory;
  final EngineHardwareProfile? hardwareProfile;
  final int? whiteClockMs;
  final int? blackClockMs;
  final DateTime? lastClockStartedAt;
  final Side? timeoutWinner;
  final String statusText;
  final String opponentMessage;
  final String coachMessage;
  final DialogueMessageSource opponentMessageSource;
  final DialogueMessageSource coachMessageSource;
  final List<String> availableLlmModels;
  final bool llmTesting;
  final bool llmFetchingModels;
  final String? llmStatusMessage;
  final String? lastLlmError;
  final LlmUsageStats llmStats;
  final List<String> eventLog;
  final List<String> moveHistory;
  final bool canUndo;
  final bool canRedo;
  final LastMove? lastMove;
  final String? errorMessage;

  bool get isGameOver => position.isGameOver || timeoutWinner != null;

  bool get playerTurn => position.turn == config.playerSide;

  Outcome? get outcome => position.outcome;

  bool get hasMoveReview => latestReview != null;

  MoveReviewSummary get reviewSummary =>
      MoveReviewSummary(reviews: reviewHistory);

  GameState copyWith({
    Position? position,
    GameSessionConfig? config,
    bool? initialized,
    bool? aiThinking,
    bool? coachThinking,
    Object? selectedSquare = _unset,
    Set<Square>? legalTargets,
    Object? hint = _unset,
    Object? opponentAnalysis = _unset,
    Object? latestReview = _unset,
    List<MoveReview>? reviewHistory,
    Object? hardwareProfile = _unset,
    Object? whiteClockMs = _unset,
    Object? blackClockMs = _unset,
    Object? lastClockStartedAt = _unset,
    Object? timeoutWinner = _unset,
    String? statusText,
    String? opponentMessage,
    String? coachMessage,
    DialogueMessageSource? opponentMessageSource,
    DialogueMessageSource? coachMessageSource,
    List<String>? availableLlmModels,
    bool? llmTesting,
    bool? llmFetchingModels,
    Object? llmStatusMessage = _unset,
    Object? lastLlmError = _unset,
    LlmUsageStats? llmStats,
    List<String>? eventLog,
    List<String>? moveHistory,
    bool? canUndo,
    bool? canRedo,
    Object? lastMove = _unset,
    Object? errorMessage = _unset,
  }) {
    return GameState(
      position: position ?? this.position,
      config: config ?? this.config,
      initialized: initialized ?? this.initialized,
      aiThinking: aiThinking ?? this.aiThinking,
      coachThinking: coachThinking ?? this.coachThinking,
      selectedSquare: identical(selectedSquare, _unset)
          ? this.selectedSquare
          : selectedSquare as Square?,
      legalTargets: legalTargets ?? this.legalTargets,
      hint: identical(hint, _unset) ? this.hint : hint as EngineAnalysis?,
      opponentAnalysis: identical(opponentAnalysis, _unset)
          ? this.opponentAnalysis
          : opponentAnalysis as EngineAnalysis?,
      latestReview: identical(latestReview, _unset)
          ? this.latestReview
          : latestReview as MoveReview?,
      reviewHistory: reviewHistory ?? this.reviewHistory,
      hardwareProfile: identical(hardwareProfile, _unset)
          ? this.hardwareProfile
          : hardwareProfile as EngineHardwareProfile?,
      whiteClockMs: identical(whiteClockMs, _unset)
          ? this.whiteClockMs
          : whiteClockMs as int?,
      blackClockMs: identical(blackClockMs, _unset)
          ? this.blackClockMs
          : blackClockMs as int?,
      lastClockStartedAt: identical(lastClockStartedAt, _unset)
          ? this.lastClockStartedAt
          : lastClockStartedAt as DateTime?,
      timeoutWinner: identical(timeoutWinner, _unset)
          ? this.timeoutWinner
          : timeoutWinner as Side?,
      statusText: statusText ?? this.statusText,
      opponentMessage: opponentMessage ?? this.opponentMessage,
      coachMessage: coachMessage ?? this.coachMessage,
      opponentMessageSource:
          opponentMessageSource ?? this.opponentMessageSource,
      coachMessageSource: coachMessageSource ?? this.coachMessageSource,
      availableLlmModels: availableLlmModels ?? this.availableLlmModels,
      llmTesting: llmTesting ?? this.llmTesting,
      llmFetchingModels: llmFetchingModels ?? this.llmFetchingModels,
      llmStatusMessage: identical(llmStatusMessage, _unset)
          ? this.llmStatusMessage
          : llmStatusMessage as String?,
      lastLlmError: identical(lastLlmError, _unset)
          ? this.lastLlmError
          : lastLlmError as String?,
      llmStats: llmStats ?? this.llmStats,
      eventLog: eventLog ?? this.eventLog,
      moveHistory: moveHistory ?? this.moveHistory,
      canUndo: canUndo ?? this.canUndo,
      canRedo: canRedo ?? this.canRedo,
      lastMove: identical(lastMove, _unset)
          ? this.lastMove
          : lastMove as LastMove?,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class LlmUsageStats {
  const LlmUsageStats({
    this.requestCount = 0,
    this.successCount = 0,
    this.failureCount = 0,
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.totalTokens = 0,
    this.lastLatencyMs,
  });

  final int requestCount;
  final int successCount;
  final int failureCount;
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final int? lastLatencyMs;

  LlmUsageStats recordSuccess({
    required int promptTokens,
    required int completionTokens,
    required int totalTokens,
    required int latencyMs,
  }) {
    return LlmUsageStats(
      requestCount: requestCount + 1,
      successCount: successCount + 1,
      failureCount: failureCount,
      promptTokens: this.promptTokens + promptTokens,
      completionTokens: this.completionTokens + completionTokens,
      totalTokens: this.totalTokens + totalTokens,
      lastLatencyMs: latencyMs,
    );
  }

  LlmUsageStats recordFailure() {
    return LlmUsageStats(
      requestCount: requestCount + 1,
      successCount: successCount,
      failureCount: failureCount + 1,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: totalTokens,
      lastLatencyMs: lastLatencyMs,
    );
  }
}
