import 'dart:async';
import 'dart:math' as math;

import 'package:chessgpt/src/chess/chess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n/app_localizations.dart';
import '../models/bot_roster.dart';
import '../models/engine_models.dart';
import '../models/game_state.dart';
import '../models/session_config.dart';
import '../services/llm_commentary_service.dart';
import '../services/local_settings_store.dart';
import '../services/stockfish_service.dart';
import '../theme/board_theme.dart';
import '../utils/text_sanitizer.dart';

final gameControllerProvider = NotifierProvider<GameController, GameState>(
  GameController.new,
);

class GameController extends Notifier<GameState> {
  GameController({
    StockfishService? stockfish,
    LlmCommentaryService? llm,
    LocalSettingsStore? settingsStore,
  }) : _stockfish = stockfish ?? StockfishService(),
       _llm = llm ?? LlmCommentaryService(),
       _settingsStore = settingsStore ?? LocalSettingsStore();

  final StockfishService _stockfish;
  final LlmCommentaryService _llm;
  final LocalSettingsStore _settingsStore;
  bool _didInitialize = false;
  EngineHardwareProfile? _hardwareProfile;
  Timer? _clockTimer;
  Timer? _idleBanterTimer;
  final math.Random _random = math.Random();
  final List<_GameTimelineSnapshot> _timeline = [];
  int _timelineIndex = -1;
  int _sessionId = 0;
  int _hintRequestId = 0;
  int _reviewRequestId = 0;
  int _llmTestRequestId = 0;
  int _llmVoiceRequestId = 0;
  int _llmModelRequestId = 0;

  @override
  GameState build() {
    ref.onDispose(() {
      _clockTimer?.cancel();
      _idleBanterTimer?.cancel();
      _stockfish.dispose();
      _llm.dispose();
    });
    return GameState.initial();
  }

  Future<void> initialize() async {
    if (_didInitialize) {
      return;
    }
    _didInitialize = true;
    await startNewGame();
  }

  Future<void> startNewGame({GameSessionConfig? config}) async {
    final sessionId = ++_sessionId;
    if (_hardwareProfile == null) {
      final hardwareProfile = await _stockfish.detectHardwareProfile();
      if (!_isCurrentSession(sessionId)) {
        return;
      }
      _hardwareProfile ??= hardwareProfile;
    }
    final sessionConfig = _normalizeConfigForHardware(
      config ?? await _loadStoredConfig(),
    );
    if (!_isCurrentSession(sessionId)) {
      return;
    }
    final openingLine = _openingLine(sessionConfig);
    final coachOpeningLine = _coachOpeningLine(sessionConfig);
    state = GameState.initial(config: sessionConfig).copyWith(
      initialized: true,
      hardwareProfile: _hardwareProfile,
      statusText: _statusFor(
        position: Position.initialPosition(Rule.chess),
        config: sessionConfig,
        aiThinking: false,
        coachThinking: false,
      ),
      opponentMessage: openingLine,
      coachMessage: coachOpeningLine,
      opponentMessageSource: sessionConfig.llm.enabled
          ? DialogueMessageSource.fallback
          : DialogueMessageSource.disabled,
      coachMessageSource: sessionConfig.llm.enabled
          ? DialogueMessageSource.fallback
          : DialogueMessageSource.disabled,
      eventLog: [openingLine],
      timeoutWinner: null,
      opponentAnalysis: null,
      errorMessage: null,
      lastLlmError: null,
      coachThinking: false,
      canUndo: false,
      canRedo: false,
    );
    _restartClockTimer();
    _scheduleIdleBanter(sessionId: sessionId);

    if (state.playerTurn) {
      unawaited(_refreshHint(sessionId: sessionId));
    } else {
      await _runAiTurn(sessionId: sessionId);
    }
    if (!_isCurrentSession(sessionId)) {
      return;
    }
    _recordStableSnapshot(reset: true);
    unawaited(_settingsStore.savePreferences(sessionConfig));
    unawaited(
      _refreshOpeningLlmVoices(config: sessionConfig, sessionId: sessionId),
    );
  }

  Future<void> rematch() => startNewGame();

  void updateDifficulty(DifficultyLevel difficulty) {
    unawaited(
      startNewGame(config: state.config.copyWith(difficulty: difficulty)),
    );
  }

  void updateOpponentDepth(SearchDepthLevel depth) {
    unawaited(
      startNewGame(config: state.config.copyWith(opponentDepth: depth)),
    );
  }

  void updateTeacherDepth(SearchDepthLevel depth) {
    final config = state.config.copyWith(teacherDepth: depth);
    state = state.copyWith(
      config: config,
      hint: null,
      opponentAnalysis: null,
      errorMessage: null,
    );
    unawaited(_settingsStore.savePreferences(config));
    unawaited(_refreshHint(sessionId: _sessionId));
  }

  void updateEngineResources(EngineResourceSettings resources) {
    final config = _normalizeConfigForHardware(
      state.config.copyWith(engineResources: resources),
    );
    state = state.copyWith(
      config: config,
      hint: null,
      opponentAnalysis: null,
      errorMessage: null,
    );
    unawaited(_settingsStore.savePreferences(config));
    unawaited(_refreshHint(sessionId: _sessionId));
  }

  void updatePlayerSide(Side side) {
    unawaited(startNewGame(config: state.config.copyWith(playerSide: side)));
  }

  void updateHintMode(HintMode hintMode) {
    state = state.copyWith(
      config: state.config.copyWith(hintMode: hintMode),
      hint: null,
      opponentAnalysis: null,
      errorMessage: null,
    );
    unawaited(_settingsStore.savePreferences(state.config));
    unawaited(_refreshHint(sessionId: _sessionId));
  }

  void updateCandidateLineCount(int count) {
    final config = state.config.copyWith(candidateLineCount: count);
    state = state.copyWith(
      config: config,
      hint: null,
      opponentAnalysis: null,
      errorMessage: null,
    );
    unawaited(_settingsStore.savePreferences(config));
    unawaited(_refreshHint(sessionId: _sessionId));
  }

  void updateAppTextScalePercent(int percent) {
    final config = state.config.copyWith(appTextScalePercent: percent);
    state = state.copyWith(config: config, errorMessage: null);
    unawaited(_settingsStore.savePreferences(config));
  }

  void updateTimeControl(TimeControl timeControl) {
    unawaited(
      startNewGame(config: state.config.copyWith(timeControl: timeControl)),
    );
  }

  void updateBoardTheme(BoardThemeId boardTheme) {
    state = state.copyWith(
      config: state.config.copyWith(boardTheme: boardTheme),
      errorMessage: null,
    );
    unawaited(_settingsStore.savePreferences(state.config));
  }

  void updateLocale(AppLocale locale) {
    final config = state.config.copyWith(locale: locale);
    state = state.copyWith(
      config: config,
      statusText: _statusFor(
        position: state.position,
        config: config,
        aiThinking: state.aiThinking,
        coachThinking: state.coachThinking,
      ),
      opponentMessage: _openingLine(config),
      coachMessage: _coachLine(state.hint, config: config),
      opponentAnalysis: null,
      opponentMessageSource: config.llm.enabled
          ? DialogueMessageSource.fallback
          : DialogueMessageSource.disabled,
      coachMessageSource: config.llm.enabled
          ? DialogueMessageSource.fallback
          : DialogueMessageSource.disabled,
      errorMessage: null,
    );
    unawaited(_settingsStore.savePreferences(config));
  }

  void updatePersona(Persona persona) {
    final config = state.config.copyWith(persona: persona);
    state = state.copyWith(
      config: config,
      opponentMessage: _openingLine(config),
      opponentAnalysis: null,
      opponentMessageSource: config.llm.enabled
          ? DialogueMessageSource.fallback
          : DialogueMessageSource.disabled,
    );
    unawaited(_settingsStore.savePreferences(config));
  }

  void updateCoachPersona(CoachPersona coachPersona) {
    final config = state.config.copyWith(coachPersona: coachPersona);
    state = state.copyWith(
      config: config,
      coachMessage: _coachOpeningLine(config),
      opponentAnalysis: null,
      coachMessageSource: config.llm.enabled
          ? DialogueMessageSource.fallback
          : DialogueMessageSource.disabled,
    );
    unawaited(_settingsStore.savePreferences(config));
  }

  void updateTauntLevel(TauntLevel tauntLevel) {
    final config = state.config.copyWith(tauntLevel: tauntLevel);
    state = state.copyWith(config: config, opponentAnalysis: null);
    _syncCurrentSnapshot();
    unawaited(_settingsStore.savePreferences(config));
  }

  Future<void> resetPreferences() async {
    final config = GameSessionConfig.defaults().copyWith(llm: state.config.llm);
    final resetMessage = AppStrings.of(config.locale).preferencesReset;
    await _settingsStore.resetPreferences();
    await startNewGame(config: config);
    state = state.copyWith(llmStatusMessage: resetMessage);
  }

  void updateLlmEnabled(bool enabled) {
    final llm = state.config.llm.copyWith(enabled: enabled);
    state = state.copyWith(
      config: state.config.copyWith(llm: llm),
      opponentMessage: enabled
          ? AppStrings.of(state.config.locale).llmVoiceEnabled
          : _aiCommentary(state.position, null) ?? _openingLine(state.config),
      coachMessage: enabled
          ? AppStrings.of(state.config.locale).teacherChannelReady
          : _coachLine(state.hint),
      opponentMessageSource: enabled
          ? DialogueMessageSource.fallback
          : DialogueMessageSource.disabled,
      coachMessageSource: enabled
          ? DialogueMessageSource.fallback
          : DialogueMessageSource.disabled,
      lastLlmError: null,
    );
    unawaited(_settingsStore.saveLlmSettings(llm));
    _scheduleIdleBanter(sessionId: _sessionId);
  }

  void updateLlmProviderKind(LlmProviderKind providerKind) {
    final current = state.config.llm;
    final llm = current.copyWith(
      providerKind: providerKind,
      provider: providerKind.defaultProviderLabel,
      baseUrl: providerKind.defaultBaseUrl,
      model: providerKind.defaultModel,
    );
    state = state.copyWith(
      config: state.config.copyWith(llm: llm),
      availableLlmModels: const [],
      llmStatusMessage: null,
      lastLlmError: null,
    );
    unawaited(_settingsStore.saveLlmSettings(llm));
  }

  void updateLlmProvider(String provider) {
    final llm = state.config.llm.copyWith(
      providerKind: LlmProviderKind.customCompatible,
      provider: provider,
    );
    state = state.copyWith(config: state.config.copyWith(llm: llm));
    unawaited(_settingsStore.saveLlmSettings(llm));
  }

  void updateLlmBaseUrl(String baseUrl) {
    final llm = state.config.llm.copyWith(baseUrl: baseUrl);
    state = state.copyWith(config: state.config.copyWith(llm: llm));
    unawaited(_settingsStore.saveLlmSettings(llm));
  }

  void updateLlmModel(String model) {
    final llm = state.config.llm.copyWith(model: model);
    state = state.copyWith(config: state.config.copyWith(llm: llm));
    unawaited(_settingsStore.saveLlmSettings(llm));
  }

  void updateLlmCredentialMode(LlmCredentialMode credentialMode) {
    final llm = state.config.llm.copyWith(credentialMode: credentialMode);
    state = state.copyWith(config: state.config.copyWith(llm: llm));
    unawaited(_settingsStore.saveLlmSettings(llm));
  }

  void updateLlmApiKey(String apiKey) {
    final llm = state.config.llm.copyWith(apiKey: apiKey);
    state = state.copyWith(config: state.config.copyWith(llm: llm));
    unawaited(_settingsStore.saveLlmSettings(llm));
  }

  void updateLlmIdleBanterEnabled(bool enabled) {
    final llm = state.config.llm.copyWith(idleBanterEnabled: enabled);
    state = state.copyWith(config: state.config.copyWith(llm: llm));
    unawaited(_settingsStore.saveLlmSettings(llm));
    _scheduleIdleBanter(sessionId: _sessionId);
  }

  void updateLlmIdleBanterMinSeconds(int seconds) {
    final llm = state.config.llm.copyWith(idleBanterMinSeconds: seconds);
    state = state.copyWith(config: state.config.copyWith(llm: llm));
    unawaited(_settingsStore.saveLlmSettings(llm));
    _scheduleIdleBanter(sessionId: _sessionId);
  }

  void updateLlmIdleBanterMaxSeconds(int seconds) {
    final llm = state.config.llm.copyWith(idleBanterMaxSeconds: seconds);
    state = state.copyWith(config: state.config.copyWith(llm: llm));
    unawaited(_settingsStore.saveLlmSettings(llm));
    _scheduleIdleBanter(sessionId: _sessionId);
  }

  void resetLlmUsageStats() {
    state = state.copyWith(llmStats: const LlmUsageStats());
  }

  void undoTurn() {
    if (state.aiThinking || _timelineIndex <= 0) {
      return;
    }
    _restoreTimelineSnapshot(_timelineIndex - 1);
  }

  void redoTurn() {
    if (state.aiThinking || _timelineIndex >= _timeline.length - 1) {
      return;
    }
    _restoreTimelineSnapshot(_timelineIndex + 1);
  }

  bool _isCurrentSession(int sessionId) => sessionId == _sessionId;

  bool _isCurrentPositionRequest({
    required int sessionId,
    required String fen,
    GameSessionConfig? config,
  }) {
    return _isCurrentSession(sessionId) &&
        state.position.fen == fen &&
        (config == null || state.config == config);
  }

  void _recordStableSnapshot({required bool reset}) {
    if (!state.initialized || (!state.playerTurn && !state.isGameOver)) {
      return;
    }

    final snapshot = _GameTimelineSnapshot.fromState(state);
    if (reset) {
      _timeline
        ..clear()
        ..add(snapshot);
      _timelineIndex = 0;
      _syncTimelineAvailability();
      return;
    }

    if (_timelineIndex >= 0 &&
        _timelineIndex < _timeline.length &&
        _timeline[_timelineIndex].position.fen == snapshot.position.fen &&
        _timeline[_timelineIndex].moveHistory.length ==
            snapshot.moveHistory.length) {
      _timeline[_timelineIndex] = snapshot;
      _syncTimelineAvailability();
      return;
    }

    if (_timelineIndex < _timeline.length - 1) {
      _timeline.removeRange(_timelineIndex + 1, _timeline.length);
    }
    _timeline.add(snapshot);
    _timelineIndex = _timeline.length - 1;
    _syncTimelineAvailability();
  }

  void _syncCurrentSnapshot() {
    if (_timelineIndex < 0 || _timelineIndex >= _timeline.length) {
      return;
    }
    _timeline[_timelineIndex] = _GameTimelineSnapshot.fromState(state);
    _syncTimelineAvailability();
  }

  void _syncTimelineAvailability() {
    state = state.copyWith(
      canUndo: _timelineIndex > 0,
      canRedo: _timelineIndex >= 0 && _timelineIndex < _timeline.length - 1,
    );
  }

  void _restoreTimelineSnapshot(int targetIndex) {
    if (targetIndex < 0 || targetIndex >= _timeline.length) {
      return;
    }

    final snapshot = _timeline[targetIndex];
    final config = state.config;
    final sessionId = ++_sessionId;
    _hintRequestId++;
    _reviewRequestId++;
    _llmVoiceRequestId++;
    _idleBanterTimer?.cancel();

    state = state.copyWith(
      position: snapshot.position,
      aiThinking: false,
      coachThinking: false,
      selectedSquare: null,
      legalTargets: const {},
      hint: null,
      opponentAnalysis: null,
      latestReview: snapshot.latestReview,
      reviewHistory: snapshot.reviewHistory,
      whiteClockMs: snapshot.whiteClockMs,
      blackClockMs: snapshot.blackClockMs,
      lastClockStartedAt:
          snapshot.position.isGameOver || snapshot.timeoutWinner != null
          ? null
          : DateTime.now(),
      timeoutWinner: snapshot.timeoutWinner,
      statusText: _statusFor(
        position: snapshot.position,
        config: config,
        aiThinking: false,
        coachThinking: false,
        timeoutWinner: snapshot.timeoutWinner,
      ),
      opponentMessage: snapshot.opponentMessage,
      coachMessage: snapshot.coachMessage,
      opponentMessageSource: snapshot.opponentMessageSource,
      coachMessageSource: snapshot.coachMessageSource,
      eventLog: snapshot.eventLog,
      moveHistory: snapshot.moveHistory,
      lastMove: snapshot.lastMove,
      errorMessage: null,
      lastLlmError: null,
      llmStatusMessage: null,
    );
    _timelineIndex = targetIndex;
    _syncTimelineAvailability();
    _restartClockTimer();
    _scheduleIdleBanter(sessionId: sessionId);
    if (state.playerTurn && !state.isGameOver) {
      unawaited(_refreshHint(sessionId: sessionId));
    }
  }

  Future<void> resetLlmSettings() async {
    const llm = LlmSettings();
    await _settingsStore.resetLlmSettings();
    _idleBanterTimer?.cancel();
    state = state.copyWith(
      config: state.config.copyWith(llm: llm),
      availableLlmModels: const [],
      llmStatusMessage: AppStrings.of(state.config.locale).llmSettingsReset,
      errorMessage: null,
      lastLlmError: null,
    );
  }

  Future<void> testLlmConnection() async {
    final requestId = ++_llmTestRequestId;
    final settings = state.config.llm;
    state = state.copyWith(
      llmTesting: true,
      llmStatusMessage: AppStrings.of(
        state.config.locale,
      ).llmTestingConnection(),
      errorMessage: null,
    );
    try {
      await _llm.testConnection(settings);
      if (requestId != _llmTestRequestId) {
        return;
      }
      if (state.config.llm != settings) {
        state = state.copyWith(llmTesting: false);
        return;
      }
      state = state.copyWith(
        llmTesting: false,
        llmStatusMessage: AppStrings.of(
          state.config.locale,
        ).llmConnectionReady(),
      );
    } catch (error) {
      if (requestId != _llmTestRequestId) {
        return;
      }
      if (state.config.llm != settings) {
        state = state.copyWith(llmTesting: false);
        return;
      }
      state = state.copyWith(
        llmTesting: false,
        llmStatusMessage: AppStrings.of(
          state.config.locale,
        ).llmTestFailed(error),
      );
    }
  }

  Future<void> fetchLlmModels() async {
    final requestId = ++_llmModelRequestId;
    final settings = state.config.llm;
    state = state.copyWith(
      llmFetchingModels: true,
      llmStatusMessage: AppStrings.of(state.config.locale).fetchingModels,
      errorMessage: null,
    );
    try {
      final models = await _llm.fetchModels(settings);
      if (requestId != _llmModelRequestId || state.config.llm != settings) {
        if (requestId == _llmModelRequestId) {
          state = state.copyWith(llmFetchingModels: false);
        }
        return;
      }
      final selected = models.contains(settings.model)
          ? settings.model
          : models.firstOrNull;
      state = state.copyWith(
        config: selected == null
            ? state.config
            : state.config.copyWith(llm: settings.copyWith(model: selected)),
        availableLlmModels: models,
        llmFetchingModels: false,
        llmStatusMessage: models.isEmpty
            ? AppStrings.of(state.config.locale).noModelsReturned
            : AppStrings.of(state.config.locale).loadedModels(models.length),
      );
      if (selected != null) {
        unawaited(
          _settingsStore.saveLlmSettings(settings.copyWith(model: selected)),
        );
      }
    } catch (error) {
      if (requestId != _llmModelRequestId || state.config.llm != settings) {
        if (requestId == _llmModelRequestId) {
          state = state.copyWith(llmFetchingModels: false);
        }
        return;
      }
      state = state.copyWith(
        llmFetchingModels: false,
        llmStatusMessage: AppStrings.of(
          state.config.locale,
        ).fetchModelsFailed(error),
      );
    }
  }

  Future<GameSessionConfig> _loadStoredConfig() async {
    if (state.initialized) {
      return state.config;
    }
    try {
      final llm = await _settingsStore.loadLlmSettings() ?? state.config.llm;
      final preferences = await _settingsStore.loadPreferences(llm: llm);
      return preferences ?? state.config.copyWith(llm: llm);
    } catch (_) {
      return state.config;
    }
  }

  GameSessionConfig _normalizeConfigForHardware(GameSessionConfig config) {
    final profile = _hardwareProfile;
    if (profile == null || !config.engineResources.auto) {
      return config;
    }
    return config.copyWith(
      engineResources: config.engineResources.copyWith(
        threads: profile.recommendedThreads,
        hashMb: profile.recommendedHashMb,
      ),
    );
  }

  EngineSettings _opponentEngineSettings(GameSessionConfig config) {
    final resources = config.engineResources;
    return config.difficulty.engineSettings.copyWith(
      depth: config.opponentDepth.opponentDepth.clamp(1, 14).toInt(),
      threads: resources.threads,
      hashMb: resources.hashMb,
      multiPv: 1,
    );
  }

  EngineSettings _teacherEngineSettings(
    GameSessionConfig config, {
    required int multiPv,
  }) {
    final resources = config.engineResources;
    return const EngineSettings(
      moveTimeMs: 3200,
      limitStrength: false,
      multiPv: 1,
      hashMb: 256,
      threads: 4,
    ).copyWith(
      depth: config.teacherDepth.teacherDepth.clamp(1, 28).toInt(),
      threads: resources.threads,
      hashMb: resources.hashMb,
      multiPv: multiPv,
      skillLevel: null,
      elo: null,
    );
  }

  Future<void> tapSquare(Square square) async {
    if (!state.initialized ||
        state.aiThinking ||
        !state.playerTurn ||
        state.isGameOver) {
      return;
    }

    final legalMap = state.position.legalMoves;
    final selectedSquare = state.selectedSquare;

    if (selectedSquare != null && state.legalTargets.contains(square)) {
      await _playHumanMove(selectedSquare, square);
      return;
    }

    final piece = state.position.board.pieceAt(square);
    if (piece == null || piece.color != state.position.turn) {
      state = state.copyWith(selectedSquare: null, legalTargets: const {});
      return;
    }

    state = state.copyWith(
      selectedSquare: square,
      legalTargets: legalMap[square]?.squares.toSet() ?? const {},
      errorMessage: null,
    );
  }

  Future<void> dropMove(Square from, Square to) async {
    if (!state.initialized ||
        state.aiThinking ||
        !state.playerTurn ||
        state.isGameOver) {
      return;
    }
    await _playHumanMove(from, to);
  }

  Future<void> _playHumanMove(Square from, Square to) async {
    final piece = state.position.board.pieceAt(from);
    if (piece == null) {
      return;
    }

    var move = NormalMove(from: from, to: to);
    if (piece.role == Role.pawn && isPromotionRank(to)) {
      move = moveWithPromotion(move, Role.queen);
    }

    if (!state.position.isLegal(move)) {
      state = state.copyWith(
        selectedSquare: null,
        legalTargets: const {},
        errorMessage: AppStrings.of(state.config.locale).illegalMoveRejected,
      );
      return;
    }

    final previousPosition = state.position;
    final nextPosition = previousPosition.play(move);
    final previousAnalysis = state.hint;
    final moveElapsedMs = _elapsedMsForCurrentTurn();
    final sessionId = _sessionId;
    final reviewRequestId = ++_reviewRequestId;
    _applyMove(position: nextPosition, move: move, byPlayer: true);
    unawaited(
      _reviewHumanMoveInBackground(
        sessionId: sessionId,
        requestId: reviewRequestId,
        move: move,
        mover: previousPosition.turn,
        previousFen: previousPosition.fen,
        nextFen: nextPosition.fen,
        previousAnalysis: previousAnalysis,
        elapsedMs: moveElapsedMs,
      ),
    );

    if (nextPosition.isGameOver) {
      return;
    }

    await _runAiTurn(sessionId: sessionId);
  }

  Future<void> _reviewHumanMoveInBackground({
    required int sessionId,
    required int requestId,
    required Move move,
    required Side mover,
    required String previousFen,
    required String nextFen,
    required EngineAnalysis? previousAnalysis,
    required int elapsedMs,
  }) async {
    final config = state.config;
    final reviewSettings = _teacherEngineSettings(config, multiPv: 3);
    EngineAnalysis? before = previousAnalysis;
    before ??= await _analyzeQuietly(previousFen, reviewSettings);
    if (!_isCurrentSession(sessionId) ||
        requestId != _reviewRequestId ||
        state.config != config) {
      return;
    }
    final after = await _analyzeQuietly(nextFen, reviewSettings);
    if (!_isCurrentSession(sessionId) ||
        requestId != _reviewRequestId ||
        state.config != config) {
      return;
    }
    final review = _reviewMove(
      move: move,
      mover: mover,
      previousAnalysis: before,
      currentAnalysis: after,
      elapsedMs: elapsedMs,
    );
    if (review == null ||
        requestId != _reviewRequestId ||
        !state.moveHistory.contains(move.uci)) {
      return;
    }
    state = state.copyWith(
      latestReview: review,
      reviewHistory: [...state.reviewHistory, review],
    );
    _syncCurrentSnapshot();
  }

  Future<EngineAnalysis?> _analyzeQuietly(
    String fen,
    EngineSettings settings,
  ) async {
    try {
      return await _stockfish.analyze(fen: fen, settings: settings);
    } catch (_) {
      return null;
    }
  }

  Future<void> _runAiTurn({required int sessionId}) async {
    if (state.isGameOver || state.position.turn == state.config.playerSide) {
      return;
    }

    final fen = state.position.fen;
    final config = state.config;
    final settings = _opponentEngineSettings(config);
    state = state.copyWith(
      aiThinking: true,
      coachThinking: false,
      selectedSquare: null,
      legalTargets: const {},
      hint: null,
      opponentAnalysis: null,
      statusText: AppStrings.of(state.config.locale).aiThinking,
      errorMessage: null,
    );

    try {
      final analysis = await _stockfish.analyze(fen: fen, settings: settings);

      if (!_isCurrentPositionRequest(
        sessionId: sessionId,
        fen: fen,
        config: config,
      )) {
        return;
      }

      final move = parseUciMove(analysis.bestMoveUci);
      if (move == null || !state.position.isLegal(move)) {
        throw Exception(
          'Engine produced an illegal move: ${analysis.bestMoveUci}',
        );
      }

      final nextPosition = state.position.play(move);
      _applyMove(
        position: nextPosition,
        move: move,
        byPlayer: false,
        analysis: analysis,
      );

      if (!nextPosition.isGameOver) {
        await _refreshHint(sessionId: sessionId);
      }
      _scheduleIdleBanter(sessionId: sessionId);
    } catch (error) {
      if (!_isCurrentPositionRequest(
        sessionId: sessionId,
        fen: fen,
        config: config,
      )) {
        return;
      }
      final fallback = _fallbackMove(state.position);
      if (fallback == null) {
        state = state.copyWith(
          aiThinking: false,
          statusText: AppStrings.of(state.config.locale).aiMoveFailed,
          errorMessage: '$error',
        );
        return;
      }

      final nextPosition = state.position.play(fallback);
      _applyMove(position: nextPosition, move: fallback, byPlayer: false);
      state = state.copyWith(
        errorMessage: AppStrings.of(state.config.locale).fallbackMoveUsed,
      );
      if (!nextPosition.isGameOver) {
        await _refreshHint(sessionId: sessionId);
      }
      _scheduleIdleBanter(sessionId: sessionId);
    }
  }

  Future<void> _refreshHint({required int sessionId}) async {
    final requestId = ++_hintRequestId;
    if (!state.initialized ||
        state.aiThinking ||
        state.isGameOver ||
        !state.playerTurn ||
        state.config.hintMode == HintMode.off) {
      if (!_isCurrentSession(sessionId)) {
        return;
      }
      state = state.copyWith(
        hint: null,
        opponentAnalysis: null,
        coachThinking: false,
        statusText: _statusFor(
          position: state.position,
          config: state.config,
          aiThinking: state.aiThinking,
          coachThinking: false,
        ),
      );
      return;
    }

    final fen = state.position.fen;
    final config = state.config;
    final requestedMultiPv = state.config.hintMode == HintMode.candidateLines
        ? state.config.candidateLineCount
        : 1;
    final settings = _teacherEngineSettings(config, multiPv: requestedMultiPv);
    state = state.copyWith(
      coachThinking: true,
      coachMessage: AppStrings.of(config.locale).coachThinking,
      coachMessageSource: config.llm.enabled
          ? DialogueMessageSource.fallback
          : DialogueMessageSource.disabled,
      errorMessage: null,
    );

    try {
      final analysis = await _stockfish.analyze(fen: fen, settings: settings);
      if (requestId != _hintRequestId ||
          !_isCurrentPositionRequest(
            sessionId: sessionId,
            fen: fen,
            config: config,
          ) ||
          !state.playerTurn ||
          state.aiThinking) {
        return;
      }
      state = state.copyWith(
        hint: analysis,
        opponentAnalysis: null,
        coachThinking: false,
        coachMessage: _coachLine(analysis),
        coachMessageSource: state.config.llm.enabled
            ? DialogueMessageSource.fallback
            : DialogueMessageSource.disabled,
        statusText: _statusFor(
          position: state.position,
          config: state.config,
          aiThinking: false,
          coachThinking: false,
        ),
        errorMessage: null,
      );
      _syncCurrentSnapshot();
      unawaited(
        _refreshCoachVoice(
          analysis: analysis,
          sessionId: sessionId,
          fen: fen,
          config: config,
        ),
      );
    } catch (error) {
      if (requestId != _hintRequestId ||
          !_isCurrentPositionRequest(
            sessionId: sessionId,
            fen: fen,
            config: config,
          )) {
        return;
      }
      state = state.copyWith(
        hint: null,
        opponentAnalysis: null,
        coachThinking: false,
        errorMessage: AppStrings.of(
          state.config.locale,
        ).hintAnalysisFailed(error),
      );
    }
  }

  void _applyMove({
    required Position position,
    required Move move,
    required bool byPlayer,
    EngineAnalysis? analysis,
    MoveReview? review,
  }) {
    final updatedHistory = [...state.moveHistory, move.uci];
    final updatedEvents = [
      ...state.eventLog,
      _moveEvent(move, byPlayer, analysis),
    ];
    if (!byPlayer) {
      final taunt = _aiCommentary(position, analysis);
      if (taunt != null) {
        updatedEvents.add(taunt);
      }
    }

    final outcomeLine = _outcomeLine(position);
    if (outcomeLine != null) {
      updatedEvents.add(outcomeLine);
    }

    final lastMove = switch (move) {
      NormalMove(from: final from, to: final to) => (from: from, to: to),
      DropMove() => null,
    };

    final useLlmVoice = _isLlmConfigured(state.config);
    final fallbackOpponent = useLlmVoice
        ? _llmVoicePendingLine(forCoach: false)
        : byPlayer
        ? _playerMoveReaction(move)
        : _aiCommentary(position, analysis) ?? state.opponentMessage;
    final fallbackCoach = useLlmVoice
        ? _llmVoicePendingLine(forCoach: true)
        : _coachLine(analysis);
    final clocks = _updatedClocksBeforeMove();

    state = state.copyWith(
      position: position,
      aiThinking: false,
      coachThinking: false,
      selectedSquare: null,
      legalTargets: const {},
      hint: null,
      opponentAnalysis: byPlayer ? state.opponentAnalysis : analysis,
      latestReview: review ?? state.latestReview,
      whiteClockMs: clocks.white,
      blackClockMs: clocks.black,
      lastClockStartedAt: position.isGameOver ? null : DateTime.now(),
      timeoutWinner: null,
      moveHistory: updatedHistory,
      eventLog: updatedEvents,
      opponentMessage: fallbackOpponent,
      coachMessage: fallbackCoach,
      opponentMessageSource: state.config.llm.enabled
          ? DialogueMessageSource.fallback
          : DialogueMessageSource.disabled,
      coachMessageSource: state.config.llm.enabled
          ? DialogueMessageSource.fallback
          : DialogueMessageSource.disabled,
      lastMove: lastMove,
      statusText: _statusFor(
        position: position,
        config: state.config,
        aiThinking: false,
        coachThinking: false,
      ),
      errorMessage: null,
      lastLlmError: null,
    );

    if (state.playerTurn || state.isGameOver) {
      _recordStableSnapshot(reset: false);
    }

    final sessionId = _sessionId;
    final fen = state.position.fen;
    final config = state.config;
    unawaited(
      _refreshLlmVoices(
        sessionId: sessionId,
        fen: fen,
        config: config,
        move: move,
        byPlayer: byPlayer,
        analysis: analysis,
      ),
    );
  }

  ({int? white, int? black}) _updatedClocksBeforeMove() {
    final startedAt = state.lastClockStartedAt;
    if (startedAt == null ||
        state.whiteClockMs == null ||
        state.blackClockMs == null) {
      return (white: state.whiteClockMs, black: state.blackClockMs);
    }

    final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
    final spentSide = state.position.turn;
    final white = spentSide == Side.white
        ? math.max(0, state.whiteClockMs! - elapsed)
        : state.whiteClockMs;
    final black = spentSide == Side.black
        ? math.max(0, state.blackClockMs! - elapsed)
        : state.blackClockMs;
    return (white: white, black: black);
  }

  int _elapsedMsForCurrentTurn() {
    final startedAt = state.lastClockStartedAt;
    if (startedAt == null) {
      return 0;
    }
    return math.max(0, DateTime.now().difference(startedAt).inMilliseconds);
  }

  void _restartClockTimer() {
    _clockTimer?.cancel();
    if (state.config.timeControl == TimeControl.unlimited) {
      return;
    }
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _tickClock();
    });
  }

  void _tickClock() {
    if (!state.initialized ||
        state.isGameOver ||
        state.lastClockStartedAt == null ||
        state.whiteClockMs == null ||
        state.blackClockMs == null) {
      return;
    }
    final clocks = _updatedClocksBeforeMove();
    final timedOut = clocks.white == 0 || clocks.black == 0;
    final timeoutWinner = !timedOut
        ? null
        : clocks.white == 0
        ? Side.black
        : Side.white;
    state = state.copyWith(
      whiteClockMs: clocks.white,
      blackClockMs: clocks.black,
      lastClockStartedAt: timedOut ? null : DateTime.now(),
      timeoutWinner: timeoutWinner,
      statusText: timedOut
          ? _statusFor(
              position: state.position,
              config: state.config,
              aiThinking: false,
              coachThinking: false,
              timeoutWinner: timeoutWinner,
            )
          : state.statusText,
      errorMessage: timedOut
          ? AppStrings.of(state.config.locale).flagFall
          : state.errorMessage,
    );
    if (timedOut) {
      _clockTimer?.cancel();
    }
  }

  Future<void> _refreshLlmVoices({
    required int sessionId,
    required String fen,
    required GameSessionConfig config,
    required Move move,
    required bool byPlayer,
    required EngineAnalysis? analysis,
  }) async {
    final requestId = ++_llmVoiceRequestId;
    if (!config.llm.enabled) {
      if (!_isCurrentPositionRequest(
        sessionId: sessionId,
        fen: fen,
        config: config,
      )) {
        return;
      }
      state = state.copyWith(
        opponentMessageSource: DialogueMessageSource.disabled,
        coachMessageSource: DialogueMessageSource.disabled,
        llmStatusMessage: AppStrings.of(config.locale).llmDisabledNotice,
        lastLlmError: null,
      );
      return;
    }
    if (!_isLlmConfigured(config)) {
      if (!_isCurrentPositionRequest(
        sessionId: sessionId,
        fen: fen,
        config: config,
      )) {
        return;
      }
      state = state.copyWith(
        opponentMessageSource: DialogueMessageSource.fallback,
        coachMessageSource: DialogueMessageSource.fallback,
        llmStatusMessage: AppStrings.of(
          config.locale,
        ).llmFallbackReason('Model is empty.'),
        lastLlmError: 'Model is empty.',
      );
      return;
    }

    final strings = AppStrings.of(config.locale);
    final prompt = _liveCommentaryPrompt(
      strings: strings,
      move: move,
      byPlayer: byPlayer,
      analysis: analysis,
      review: state.latestReview,
    );

    final opponentFuture = _completeLlm(
      settings: config.llm,
      systemPrompt: _opponentSystemPrompt(config),
      userPrompt: prompt,
      onPartial: (partialText) {
        final safePartial = sanitizeDisplayText(partialText);
        if (safePartial.isEmpty ||
            requestId != _llmVoiceRequestId ||
            !_isCurrentPositionRequest(
              sessionId: sessionId,
              fen: fen,
              config: config,
            )) {
          return;
        }
        state = state.copyWith(
          opponentMessage: safePartial,
          opponentMessageSource: DialogueMessageSource.llm,
          llmStatusMessage: null,
          lastLlmError: null,
        );
      },
    );
    final coachFuture = _completeLlm(
      settings: config.llm,
      systemPrompt: _coachSystemPrompt(config),
      userPrompt: prompt,
      onPartial: (partialText) {
        final safePartial = sanitizeDisplayText(partialText);
        if (safePartial.isEmpty ||
            requestId != _llmVoiceRequestId ||
            !_isCurrentPositionRequest(
              sessionId: sessionId,
              fen: fen,
              config: config,
            )) {
          return;
        }
        state = state.copyWith(
          coachMessage: safePartial,
          coachMessageSource: DialogueMessageSource.llm,
          llmStatusMessage: null,
          lastLlmError: null,
        );
      },
    );

    await Future.wait([
      opponentFuture
          .then((opponent) {
            final safeOpponent = sanitizeDisplayText(opponent.text);
            if (requestId == _llmVoiceRequestId &&
                _isCurrentPositionRequest(
                  sessionId: sessionId,
                  fen: fen,
                  config: config,
                )) {
              if (safeOpponent.isNotEmpty) {
                state = state.copyWith(
                  opponentMessage: safeOpponent,
                  opponentMessageSource: DialogueMessageSource.llm,
                  llmStatusMessage: null,
                  lastLlmError: null,
                );
              } else {
                state = state.copyWith(
                  opponentMessage: _llmVoiceFailedLine(forCoach: false),
                  opponentMessageSource: DialogueMessageSource.fallback,
                  llmStatusMessage: null,
                  lastLlmError: 'Opponent response was empty.',
                  eventLog: [...state.eventLog, strings.llmCommentaryFailed],
                );
              }
            }
          })
          .catchError((Object error) {
            if (requestId == _llmVoiceRequestId &&
                _isCurrentPositionRequest(
                  sessionId: sessionId,
                  fen: fen,
                  config: config,
                )) {
              state = state.copyWith(
                opponentMessage: _llmVoiceFailedLine(forCoach: false),
                opponentMessageSource: DialogueMessageSource.fallback,
                llmStatusMessage: null,
                lastLlmError: '$error',
                eventLog: [...state.eventLog, strings.llmCommentaryFailed],
              );
            }
          }),
      coachFuture
          .then((coach) {
            final safeCoach = sanitizeDisplayText(coach.text);
            if (requestId == _llmVoiceRequestId &&
                _isCurrentPositionRequest(
                  sessionId: sessionId,
                  fen: fen,
                  config: config,
                )) {
              if (safeCoach.isNotEmpty) {
                state = state.copyWith(
                  coachMessage: safeCoach,
                  coachMessageSource: DialogueMessageSource.llm,
                  llmStatusMessage: null,
                  lastLlmError: null,
                );
              } else {
                state = state.copyWith(
                  coachMessage: _llmVoiceFailedLine(forCoach: true),
                  coachMessageSource: DialogueMessageSource.fallback,
                  llmStatusMessage: null,
                  lastLlmError: 'Coach response was empty.',
                  eventLog: [...state.eventLog, strings.llmCoachFailed],
                );
              }
            }
          })
          .catchError((Object error) {
            if (requestId == _llmVoiceRequestId &&
                _isCurrentPositionRequest(
                  sessionId: sessionId,
                  fen: fen,
                  config: config,
                )) {
              state = state.copyWith(
                coachMessage: _llmVoiceFailedLine(forCoach: true),
                coachMessageSource: DialogueMessageSource.fallback,
                llmStatusMessage: null,
                lastLlmError: '$error',
                eventLog: [...state.eventLog, strings.llmCoachFailed],
              );
            }
          }),
    ]);
  }

  Future<LlmCompletionResult> _completeLlm({
    required LlmSettings settings,
    required String systemPrompt,
    required String userPrompt,
    void Function(String partialText)? onPartial,
  }) async {
    try {
      final result = await _llm.complete(
        settings: settings,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        onPartial: onPartial,
      );
      final usage = result.usage;
      state = state.copyWith(
        llmStats: state.llmStats.recordSuccess(
          promptTokens: usage?.promptTokens ?? 0,
          completionTokens: usage?.completionTokens ?? 0,
          totalTokens: usage?.totalTokens ?? 0,
          latencyMs: result.latencyMs,
        ),
      );
      return result;
    } catch (_) {
      state = state.copyWith(llmStats: state.llmStats.recordFailure());
      rethrow;
    }
  }

  MoveReview? _reviewMove({
    required Move move,
    required Side mover,
    required EngineAnalysis? previousAnalysis,
    required EngineAnalysis? currentAnalysis,
    required int elapsedMs,
  }) {
    final previousLine = previousAnalysis?.bestLine;
    final currentLine = currentAnalysis?.bestLine;
    if (previousAnalysis == null || previousLine == null) {
      return null;
    }

    final normalizedMove = _normalizeUci(move.uci);
    final previousPlayedLine = previousAnalysis.lines
        .where((line) => _normalizeUci(line.moveUci) == normalizedMove)
        .firstOrNull;
    final playedLine = previousPlayedLine ?? currentLine ?? previousLine;
    final playedActiveSide = previousPlayedLine == null
        ? _oppositeSide(mover)
        : mover;
    final bestExpected = _expectedScoreForSide(
      previousLine,
      activeSide: mover,
      side: mover,
    );
    final playedExpected = _expectedScoreForSide(
      playedLine,
      activeSide: playedActiveSide,
      side: mover,
    );
    final expectedDrop = math.max(0.0, bestExpected - playedExpected);
    final bestCp = _centipawnsForSide(
      previousLine,
      activeSide: mover,
      side: mover,
    );
    final playedCp = _centipawnsForSide(
      playedLine,
      activeSide: playedActiveSide,
      side: mover,
    );
    final centipawnLoss = math.max(0, bestCp - playedCp).round();
    final secondLine = previousAnalysis.lines.elementAtOrNull(1);
    final secondBestDrop = secondLine == null
        ? 0.0
        : math.max(
            0.0,
            bestExpected -
                _expectedScoreForSide(
                  secondLine,
                  activeSide: mover,
                  side: mover,
                ),
          );
    final isBestMove =
        normalizedMove == _normalizeUci(previousAnalysis.bestMoveUci);
    final quality = _classifyMoveQuality(
      isBestMove: isBestMove,
      expectedDrop: expectedDrop,
      previousWinChance: bestExpected,
      secondBestDrop: secondBestDrop,
    );
    final chances = _winningChances(
      currentLine ?? playedLine,
      _oppositeSide(mover),
    );

    return MoveReview(
      moveUci: move.uci,
      bestMoveUci: previousAnalysis.bestMoveUci,
      quality: quality,
      expectedDrop: expectedDrop,
      centipawnLoss: centipawnLoss,
      whiteWinPercent: chances.white.round(),
      drawPercent: chances.draw.round(),
      blackWinPercent: chances.black.round(),
      beforeEvaluation: previousAnalysis.evaluationLabel,
      afterEvaluation:
          currentAnalysis?.evaluationLabel ?? playedLine.scoreLabel,
      elapsedMs: elapsedMs,
    );
  }

  MoveQuality _classifyMoveQuality({
    required bool isBestMove,
    required double expectedDrop,
    required double previousWinChance,
    required double secondBestDrop,
  }) {
    if (isBestMove && secondBestDrop >= 0.14) {
      return MoveQuality.brilliant;
    }
    if (isBestMove && secondBestDrop >= 0.08) {
      return MoveQuality.great;
    }
    if (isBestMove || expectedDrop <= 0.03) {
      return MoveQuality.best;
    }
    if (previousWinChance >= 0.75 && expectedDrop >= 0.20) {
      return MoveQuality.miss;
    }
    if (expectedDrop >= 0.35) {
      return MoveQuality.blunder;
    }
    return MoveQuality.mistake;
  }

  ({double white, double draw, double black}) _winningChances(
    EngineLine? line,
    Side activeSide,
  ) {
    if (line == null) {
      return (white: 50, draw: 0, black: 50);
    }
    final white =
        100 / (1 + math.exp(-_whiteCentipawns(line, activeSide) / 250));
    return (white: white, draw: 0, black: 100 - white);
  }

  double _expectedScoreForSide(
    EngineLine line, {
    required Side activeSide,
    required Side side,
  }) {
    final chances = _winningChances(line, activeSide);
    final expectedWhite = (chances.white + chances.draw * 0.5) / 100;
    return side == Side.white ? expectedWhite : 1 - expectedWhite;
  }

  int _centipawnsForSide(
    EngineLine line, {
    required Side activeSide,
    required Side side,
  }) {
    final whiteCp = _whiteCentipawns(line, activeSide);
    return side == Side.white ? whiteCp : -whiteCp;
  }

  int _whiteCentipawns(EngineLine line, Side activeSide) {
    if (line.score == null || line.scoreType == null) {
      return 0;
    }
    if (line.scoreType == 'mate') {
      final mateForWhite = activeSide == Side.white
          ? line.score!
          : -line.score!;
      final direction = mateForWhite >= 0 ? 1 : -1;
      return direction * (100000 - math.min(mateForWhite.abs(), 99) * 1000);
    }
    return activeSide == Side.white ? line.score! : -line.score!;
  }

  bool _isLlmConfigured(GameSessionConfig config) =>
      config.llm.enabled && config.llm.model.trim().isNotEmpty;

  Side _oppositeSide(Side side) => side == Side.white ? Side.black : Side.white;

  String _normalizeUci(String move) {
    final trimmed = move.trim().toLowerCase();
    if (trimmed.length <= 4) {
      return trimmed;
    }
    return '${trimmed.substring(0, 4)}${trimmed[4]}';
  }

  String _positionSummary(Position position, AppStrings strings) {
    final pieces = _pieceCounts(position);
    final recentMoves = state.moveHistory
        .skip(math.max(0, state.moveHistory.length - 6))
        .join(' ');
    final checkText = position.isCheck
        ? switch (strings.locale) {
            AppLocale.en => 'Side to move is in check.',
            AppLocale.zhHant => '輪到走棋的一方正被將軍。',
          }
        : switch (strings.locale) {
            AppLocale.en => 'No check on the board.',
            AppLocale.zhHant => '目前沒有將軍。',
          };
    final turn = strings.sideName(position.turn.name);
    final material = switch (strings.locale) {
      AppLocale.en =>
        'Material: White Q${pieces.whiteQueens} R${pieces.whiteRooks} B${pieces.whiteBishops} N${pieces.whiteKnights} P${pieces.whitePawns}; Black Q${pieces.blackQueens} R${pieces.blackRooks} B${pieces.blackBishops} N${pieces.blackKnights} P${pieces.blackPawns}.',
      AppLocale.zhHant =>
        '子力：白后${pieces.whiteQueens} 車${pieces.whiteRooks} 象${pieces.whiteBishops} 馬${pieces.whiteKnights} 兵${pieces.whitePawns}；黑后${pieces.blackQueens} 車${pieces.blackRooks} 象${pieces.blackBishops} 馬${pieces.blackKnights} 兵${pieces.blackPawns}。',
    };
    final recent = recentMoves.isEmpty
        ? switch (strings.locale) {
            AppLocale.en => 'Recent moves: none.',
            AppLocale.zhHant => '最近走法：尚無。',
          }
        : switch (strings.locale) {
            AppLocale.en => 'Recent moves: $recentMoves.',
            AppLocale.zhHant => '最近走法：$recentMoves。',
          };

    return switch (strings.locale) {
      AppLocale.en =>
        'FEN: ${position.fen}\nTurn: $turn. $checkText\n$material\n$recent',
      AppLocale.zhHant =>
        'FEN：${position.fen}\n輪到：$turn。$checkText\n$material\n$recent',
    };
  }

  String? _reviewSummary(MoveReview? review, AppStrings strings) {
    if (review == null) {
      return null;
    }
    final zhHant = strings.locale == AppLocale.zhHant;
    return switch (strings.locale) {
      AppLocale.en =>
        'Private move review, do not quote directly: ${review.moveUci} was ${review.quality.label(zhHant)} (${review.quality.icon}); engine preferred ${review.bestMoveUci}; practical chances White ${review.whiteWinPercent}% Black ${review.blackWinPercent}%.',
      AppLocale.zhHant =>
        '內部走法覆盤，請勿直接照抄：${review.moveUci} 是${review.quality.label(zhHant)}（${review.quality.icon}）；引擎偏好 ${review.bestMoveUci}；實戰機會白方 ${review.whiteWinPercent}% 黑方 ${review.blackWinPercent}%。',
    };
  }

  ({
    int whiteQueens,
    int whiteRooks,
    int whiteBishops,
    int whiteKnights,
    int whitePawns,
    int blackQueens,
    int blackRooks,
    int blackBishops,
    int blackKnights,
    int blackPawns,
  })
  _pieceCounts(Position position) {
    var whiteQueens = 0;
    var whiteRooks = 0;
    var whiteBishops = 0;
    var whiteKnights = 0;
    var whitePawns = 0;
    var blackQueens = 0;
    var blackRooks = 0;
    var blackBishops = 0;
    var blackKnights = 0;
    var blackPawns = 0;

    for (final square in allSquares) {
      final piece = position.board.pieceAt(square);
      if (piece == null || piece.role == Role.king) {
        continue;
      }
      switch ((piece.color, piece.role)) {
        case (Side.white, Role.queen):
          whiteQueens++;
        case (Side.white, Role.rook):
          whiteRooks++;
        case (Side.white, Role.bishop):
          whiteBishops++;
        case (Side.white, Role.knight):
          whiteKnights++;
        case (Side.white, Role.pawn):
          whitePawns++;
        case (Side.black, Role.queen):
          blackQueens++;
        case (Side.black, Role.rook):
          blackRooks++;
        case (Side.black, Role.bishop):
          blackBishops++;
        case (Side.black, Role.knight):
          blackKnights++;
        case (Side.black, Role.pawn):
          blackPawns++;
        case (_, Role.king):
          break;
      }
    }

    return (
      whiteQueens: whiteQueens,
      whiteRooks: whiteRooks,
      whiteBishops: whiteBishops,
      whiteKnights: whiteKnights,
      whitePawns: whitePawns,
      blackQueens: blackQueens,
      blackRooks: blackRooks,
      blackBishops: blackBishops,
      blackKnights: blackKnights,
      blackPawns: blackPawns,
    );
  }

  Future<void> _refreshOpeningLlmVoices({
    required GameSessionConfig config,
    required int sessionId,
  }) async {
    final requestId = ++_llmVoiceRequestId;
    final fen = state.position.fen;
    if (!config.llm.enabled) {
      if (!_isCurrentPositionRequest(
        sessionId: sessionId,
        fen: fen,
        config: config,
      )) {
        return;
      }
      state = state.copyWith(
        opponentMessageSource: DialogueMessageSource.disabled,
        coachMessageSource: DialogueMessageSource.disabled,
        llmStatusMessage: AppStrings.of(config.locale).llmDisabledNotice,
        lastLlmError: null,
      );
      return;
    }
    if (!_isLlmConfigured(config)) {
      if (!_isCurrentPositionRequest(
        sessionId: sessionId,
        fen: fen,
        config: config,
      )) {
        return;
      }
      state = state.copyWith(
        llmStatusMessage: AppStrings.of(
          config.locale,
        ).llmFallbackReason('Model is empty.'),
        lastLlmError: 'Model is empty.',
      );
      return;
    }

    final strings = AppStrings.of(config.locale);
    final prompt = _openingCommentaryPrompt(strings, config);

    try {
      final opponent = await _completeLlm(
        settings: config.llm,
        systemPrompt: _opponentSystemPrompt(config),
        userPrompt: prompt,
        onPartial: (partialText) {
          final safePartial = sanitizeDisplayText(partialText);
          if (safePartial.isEmpty ||
              requestId != _llmVoiceRequestId ||
              !_isCurrentPositionRequest(
                sessionId: sessionId,
                fen: fen,
                config: config,
              )) {
            return;
          }
          state = state.copyWith(
            opponentMessage: safePartial,
            opponentMessageSource: DialogueMessageSource.llm,
            llmStatusMessage: null,
            lastLlmError: null,
          );
        },
      );
      final safeOpponent = sanitizeDisplayText(opponent.text);
      if (requestId == _llmVoiceRequestId &&
          _isCurrentPositionRequest(
            sessionId: sessionId,
            fen: fen,
            config: config,
          )) {
        state = state.copyWith(
          opponentMessage: safeOpponent.isEmpty
              ? state.opponentMessage
              : safeOpponent,
          opponentMessageSource: DialogueMessageSource.llm,
          llmStatusMessage: null,
          lastLlmError: null,
        );
      }
    } catch (error) {
      if (requestId == _llmVoiceRequestId &&
          _isCurrentPositionRequest(
            sessionId: sessionId,
            fen: fen,
            config: config,
          )) {
        state = state.copyWith(
          opponentMessageSource: DialogueMessageSource.fallback,
          llmStatusMessage: null,
          lastLlmError: '$error',
          eventLog: [...state.eventLog, strings.llmOpeningFailed],
        );
      }
    }

    try {
      final coach = await _completeLlm(
        settings: config.llm,
        systemPrompt: _coachSystemPrompt(config),
        userPrompt:
            '$prompt\nGive one concise teacher-style opening focus based on the board and game plan.',
        onPartial: (partialText) {
          final safePartial = sanitizeDisplayText(partialText);
          if (safePartial.isEmpty ||
              requestId != _llmVoiceRequestId ||
              !_isCurrentPositionRequest(
                sessionId: sessionId,
                fen: fen,
                config: config,
              )) {
            return;
          }
          state = state.copyWith(
            coachMessage: safePartial,
            coachMessageSource: DialogueMessageSource.llm,
            llmStatusMessage: null,
            lastLlmError: null,
          );
        },
      );
      final safeCoach = sanitizeDisplayText(coach.text);
      if (requestId == _llmVoiceRequestId &&
          _isCurrentPositionRequest(
            sessionId: sessionId,
            fen: fen,
            config: config,
          )) {
        state = state.copyWith(
          coachMessage: safeCoach.isEmpty ? state.coachMessage : safeCoach,
          coachMessageSource: DialogueMessageSource.llm,
          llmStatusMessage: null,
          lastLlmError: null,
        );
      }
    } catch (error) {
      if (requestId == _llmVoiceRequestId &&
          _isCurrentPositionRequest(
            sessionId: sessionId,
            fen: fen,
            config: config,
          )) {
        state = state.copyWith(
          coachMessageSource: DialogueMessageSource.fallback,
          llmStatusMessage: null,
          lastLlmError: '$error',
          eventLog: [...state.eventLog, strings.llmCoachFailed],
        );
      }
    }
  }

  Future<void> _refreshCoachVoice({
    required EngineAnalysis analysis,
    required int sessionId,
    required String fen,
    required GameSessionConfig config,
  }) async {
    final requestId = _llmVoiceRequestId;
    if (!config.llm.enabled) {
      if (!_isCurrentPositionRequest(
        sessionId: sessionId,
        fen: fen,
        config: config,
      )) {
        return;
      }
      state = state.copyWith(
        coachMessageSource: DialogueMessageSource.disabled,
        llmStatusMessage: AppStrings.of(config.locale).llmDisabledNotice,
        lastLlmError: null,
      );
      return;
    }
    if (!_isLlmConfigured(config)) {
      if (!_isCurrentPositionRequest(
        sessionId: sessionId,
        fen: fen,
        config: config,
      )) {
        return;
      }
      state = state.copyWith(
        coachMessageSource: DialogueMessageSource.fallback,
        llmStatusMessage: AppStrings.of(
          config.locale,
        ).llmFallbackReason('Model is empty.'),
        lastLlmError: 'Model is empty.',
      );
      return;
    }
    final strings = AppStrings.of(config.locale);
    try {
      final coach = await _completeLlm(
        settings: config.llm,
        systemPrompt: _coachSystemPrompt(config),
        userPrompt: _coachHintPrompt(
          strings: strings,
          analysis: analysis,
          review: state.latestReview,
        ),
        onPartial: (partialText) {
          final safePartial = sanitizeDisplayText(partialText);
          if (safePartial.isEmpty ||
              requestId != _llmVoiceRequestId ||
              !_isCurrentPositionRequest(
                sessionId: sessionId,
                fen: fen,
                config: config,
              ) ||
              !state.playerTurn) {
            return;
          }
          state = state.copyWith(
            coachMessage: safePartial,
            coachMessageSource: DialogueMessageSource.llm,
            llmStatusMessage: null,
            lastLlmError: null,
          );
        },
      );
      final safeCoach = sanitizeDisplayText(coach.text);
      if (requestId == _llmVoiceRequestId &&
          _isCurrentPositionRequest(
            sessionId: sessionId,
            fen: fen,
            config: config,
          ) &&
          state.playerTurn) {
        if (safeCoach.isNotEmpty) {
          state = state.copyWith(
            coachMessage: safeCoach,
            coachMessageSource: DialogueMessageSource.llm,
            llmStatusMessage: null,
            lastLlmError: null,
          );
        } else {
          state = state.copyWith(
            llmStatusMessage: null,
            lastLlmError: 'Coach response was empty.',
            eventLog: [...state.eventLog, strings.llmCoachFailed],
          );
        }
      }
    } catch (error) {
      if (requestId == _llmVoiceRequestId &&
          _isCurrentPositionRequest(
            sessionId: sessionId,
            fen: fen,
            config: config,
          ) &&
          state.playerTurn) {
        state = state.copyWith(
          llmStatusMessage: null,
          lastLlmError: '$error',
          eventLog: [...state.eventLog, strings.llmCoachFailed],
        );
      }
    }
  }

  void _scheduleIdleBanter({required int sessionId}) {
    _idleBanterTimer?.cancel();
    final settings = state.config.llm;
    if (!state.initialized ||
        state.isGameOver ||
        !settings.enabled ||
        !settings.idleBanterEnabled ||
        !_isLlmConfigured(state.config)) {
      return;
    }
    final minSeconds = settings.idleBanterMinSeconds;
    final maxSeconds = math.max(minSeconds, settings.idleBanterMaxSeconds);
    final span = maxSeconds - minSeconds;
    final delay = Duration(
      seconds: minSeconds + (span == 0 ? 0 : _random.nextInt(span + 1)),
    );
    _idleBanterTimer = Timer(delay, () {
      unawaited(_runIdleBanter(sessionId: sessionId));
    });
  }

  Future<void> _runIdleBanter({required int sessionId}) async {
    if (!_isCurrentSession(sessionId) ||
        !state.initialized ||
        state.isGameOver ||
        state.aiThinking ||
        !_isLlmConfigured(state.config) ||
        !state.config.llm.idleBanterEnabled) {
      _scheduleIdleBanter(sessionId: sessionId);
      return;
    }
    final config = state.config;
    final fen = state.position.fen;
    final requestId = _llmVoiceRequestId;
    final strings = AppStrings.of(config.locale);
    final speakAsCoach = _random.nextBool();
    final prompt = _idleBanterPrompt(
      strings: strings,
      speakAsCoach: speakAsCoach,
    );
    try {
      final result = await _completeLlm(
        settings: config.llm,
        systemPrompt: speakAsCoach
            ? _coachSystemPrompt(config)
            : _opponentSystemPrompt(config),
        userPrompt: prompt,
        onPartial: (partialText) {
          final safePartial = sanitizeDisplayText(partialText);
          if (safePartial.isEmpty ||
              requestId != _llmVoiceRequestId ||
              !_isCurrentPositionRequest(
                sessionId: sessionId,
                fen: fen,
                config: config,
              )) {
            return;
          }
          state = speakAsCoach
              ? state.copyWith(
                  coachMessage: safePartial,
                  coachMessageSource: DialogueMessageSource.llm,
                  llmStatusMessage: null,
                  lastLlmError: null,
                )
              : state.copyWith(
                  opponentMessage: safePartial,
                  opponentMessageSource: DialogueMessageSource.llm,
                  llmStatusMessage: null,
                  lastLlmError: null,
                );
        },
      );
      final safeText = sanitizeDisplayText(result.text);
      if (safeText.isNotEmpty &&
          requestId == _llmVoiceRequestId &&
          _isCurrentPositionRequest(
            sessionId: sessionId,
            fen: fen,
            config: config,
          )) {
        state = speakAsCoach
            ? state.copyWith(
                coachMessage: safeText,
                coachMessageSource: DialogueMessageSource.llm,
                llmStatusMessage: null,
                lastLlmError: null,
              )
            : state.copyWith(
                opponentMessage: safeText,
                opponentMessageSource: DialogueMessageSource.llm,
                llmStatusMessage: null,
                lastLlmError: null,
              );
      }
    } catch (error) {
      if (requestId == _llmVoiceRequestId &&
          _isCurrentPositionRequest(
            sessionId: sessionId,
            fen: fen,
            config: config,
          )) {
        state = state.copyWith(lastLlmError: '$error');
      }
    } finally {
      if (_isCurrentSession(sessionId)) {
        _scheduleIdleBanter(sessionId: sessionId);
      }
    }
  }

  Move? _fallbackMove(Position position) {
    final legalMap = position.legalMoves;
    for (final entry in legalMap.entries) {
      for (final target in entry.value.squares) {
        var move = NormalMove(from: entry.key, to: target);
        final piece = position.board.pieceAt(entry.key);
        if (piece?.role == Role.pawn && isPromotionRank(target)) {
          move = moveWithPromotion(move, Role.queen);
        }
        if (position.isLegal(move)) {
          return move;
        }
      }
    }
    return null;
  }

  String _statusFor({
    required Position position,
    required GameSessionConfig config,
    required bool aiThinking,
    required bool coachThinking,
    Side? timeoutWinner,
  }) {
    final strings = AppStrings.of(config.locale);
    final resolvedTimeoutWinner = timeoutWinner ?? state.timeoutWinner;
    if (resolvedTimeoutWinner != null) {
      return resolvedTimeoutWinner == config.playerSide
          ? strings.gameOverYouWin
          : strings.gameOverAiWins;
    }
    final outcome = position.outcome;
    if (outcome != null) {
      if (outcome.winner == null) {
        return strings.gameOverDraw;
      }
      return outcome.winner == config.playerSide
          ? strings.gameOverYouWin
          : strings.gameOverAiWins;
    }
    if (aiThinking) {
      return strings.aiThinking;
    }
    if (coachThinking) {
      return strings.coachThinking;
    }
    if (position.isCheck) {
      return position.turn == config.playerSide
          ? strings.playerInCheck
          : strings.aiInCheck;
    }
    return position.turn == config.playerSide
        ? strings.yourTurn(strings.sideName(config.playerSide.name))
        : strings.aiToMove(strings.sideName(position.turn.name));
  }

  String _openingLine(GameSessionConfig config) {
    final strings = AppStrings.of(config.locale);
    return switch (strings.locale) {
      AppLocale.en => switch (config.persona) {
        Persona.coldMaster => 'Opening protocol set. Precision expected.',
        Persona.trashTalker =>
          'Board is ready. Try not to hang a piece on move three.',
        Persona.coach =>
          'Game on. Develop cleanly and watch your center control.',
        Persona.gentleman => 'A fresh board awaits. Let us have a proper game.',
        Persona.trickster =>
          'I left a few doors open. Choose carefully which one is real.',
        Persona.speedDemon => 'Clock is loud. I move fast and ask questions.',
        Persona.endgameGrinder =>
          'Trade if you want. Small edges are where I live.',
        Persona.royalVillain =>
          'Welcome to my court. Every square has a price.',
      },
      AppLocale.zhHant => switch (config.persona) {
        Persona.coldMaster => '開局程序已設定。請保持精準。',
        Persona.trashTalker => '棋盤準備好了。第三步前別先送子。',
        Persona.coach => '對局開始。乾淨出子，注意中心控制。',
        Persona.gentleman => '新棋盤已就緒。讓我們好好下一盤。',
        Persona.trickster => '我留了幾道門。小心選，只有一道是真的。',
        Persona.speedDemon => '時間在催。我會快快出手，連續問你問題。',
        Persona.endgameGrinder => '想換子就換吧。微小優勢正是我的地盤。',
        Persona.royalVillain => '歡迎來到我的棋庭。每個格子都有代價。',
      },
    };
  }

  String _coachOpeningLine(GameSessionConfig config) {
    final strings = AppStrings.of(config.locale);
    return switch (strings.locale) {
      AppLocale.en => switch (config.coachPersona) {
        CoachPersona.kirinKing =>
          'I watch the whole board. Ask for hints before the attack lands.',
        CoachPersona.tacticalTeacher =>
          'I will call out tactics, threats, and candidate moves.',
        CoachPersona.calmMentor =>
          'I will guide the position quietly: center, king safety, and plans.',
        CoachPersona.openingArchivist =>
          'I will keep the opening honest: principles, plans, and traps.',
        CoachPersona.endgameSensei =>
          'I will help you convert endings with clean technique.',
        CoachPersona.blunderDetective =>
          'I will flag loose pieces and tactical warning signs early.',
        CoachPersona.attackCommander =>
          'I will coordinate your initiative before the attack fades.',
      },
      AppLocale.zhHant => switch (config.coachPersona) {
        CoachPersona.kirinKing => '我會看完整盤棋。攻擊落下前，先問提示。',
        CoachPersona.tacticalTeacher => '我會指出戰術、威脅與候選步。',
        CoachPersona.calmMentor => '我會安靜帶你看局面：中心、王安全與計畫。',
        CoachPersona.openingArchivist => '我會讓開局保持正確：原則、計畫與陷阱。',
        CoachPersona.endgameSensei => '我會用乾淨技術幫你把殘局轉成勝勢。',
        CoachPersona.blunderDetective => '我會提早標出鬆動棋子與戰術警訊。',
        CoachPersona.attackCommander => '我會在攻勢消失前幫你組織先手。',
      },
    };
  }

  String _moveEvent(Move move, bool byPlayer, EngineAnalysis? analysis) {
    final strings = AppStrings.of(state.config.locale);
    final actor = byPlayer ? strings.you : strings.aiLabel;
    final suffix = !byPlayer && analysis != null
        ? ' (${analysis.evaluationLabel}, ${strings.depth} ${analysis.depth})'
        : '';
    return switch (strings.locale) {
      AppLocale.en => '$actor played ${move.uci}$suffix.',
      AppLocale.zhHant => '$actor 走了 ${move.uci}$suffix。',
    };
  }

  String? _aiCommentary(Position position, EngineAnalysis? analysis) {
    final tauntLevel = state.config.tauntLevel;
    if (tauntLevel == TauntLevel.off) {
      return null;
    }

    final strings = AppStrings.of(state.config.locale);
    final bestMove =
        analysis?.bestMoveUci ?? state.moveHistory.lastOrNull ?? '--';
    final checkSuffix = position.isCheck
        ? switch (strings.locale) {
            AppLocale.en => ' Check on the board.',
            AppLocale.zhHant => ' 棋盤上將軍了。',
          }
        : '';
    return switch (strings.locale) {
      AppLocale.en => switch (state.config.persona) {
        Persona.coldMaster =>
          'Pressure settles around $bestMove.$checkSuffix'.trim(),
        Persona.trashTalker =>
          tauntLevel == TauntLevel.full
              ? 'I chose $bestMove. You may want a better plan.$checkSuffix'
                    .trim()
              : 'AI found $bestMove.$checkSuffix'.trim(),
        Persona.coach =>
          'Notice the pressure after $bestMove.$checkSuffix'.trim(),
        Persona.gentleman => 'My reply is $bestMove.$checkSuffix'.trim(),
        Persona.trickster =>
          'I chose $bestMove. The obvious answer may be bait.$checkSuffix'
              .trim(),
        Persona.speedDemon => '$bestMove, fast and direct.$checkSuffix'.trim(),
        Persona.endgameGrinder =>
          '$bestMove. I will squeeze the small details.$checkSuffix'.trim(),
        Persona.royalVillain =>
          'By royal decree: $bestMove.$checkSuffix'.trim(),
      },
      AppLocale.zhHant => switch (state.config.persona) {
        Persona.coldMaster => '壓力集中到 $bestMove。$checkSuffix'.trim(),
        Persona.trashTalker =>
          tauntLevel == TauntLevel.full
              ? '我選了 $bestMove。你可能需要更好的計畫。$checkSuffix'.trim()
              : 'AI 找到 $bestMove。$checkSuffix'.trim(),
        Persona.coach => '注意 $bestMove 之後的壓力。$checkSuffix'.trim(),
        Persona.gentleman => '我的回應是 $bestMove。$checkSuffix'.trim(),
        Persona.trickster => '我走 $bestMove。最明顯的回應可能是誘餌。$checkSuffix'.trim(),
        Persona.speedDemon => '$bestMove，快速直接。$checkSuffix'.trim(),
        Persona.endgameGrinder => '$bestMove。我會慢慢磨乾細節。$checkSuffix'.trim(),
        Persona.royalVillain => '王令已下：$bestMove。$checkSuffix'.trim(),
      },
    };
  }

  String _playerMoveReaction(Move move) {
    final strings = AppStrings.of(state.config.locale);
    return switch (strings.locale) {
      AppLocale.en => switch (state.config.persona) {
        Persona.coldMaster => 'You played ${move.uci}. I will test it.',
        Persona.trashTalker => '${move.uci}? Bold. Let us see if it holds.',
        Persona.coach =>
          'Good, ${move.uci} changes the structure. I will respond.',
        Persona.gentleman => '${move.uci}. A fair move. My reply is coming.',
        Persona.trickster =>
          '${move.uci}. Interesting. Now tell me which threat is real.',
        Persona.speedDemon => '${move.uci}. No time to admire it.',
        Persona.endgameGrinder => '${move.uci}. Every trade now matters more.',
        Persona.royalVillain =>
          '${move.uci}. The court accepts your challenge.',
      },
      AppLocale.zhHant => switch (state.config.persona) {
        Persona.coldMaster => '你走了 ${move.uci}。我會檢驗它。',
        Persona.trashTalker => '${move.uci}？很敢。看看站不站得住。',
        Persona.coach => '不錯，${move.uci} 改變了結構。我來回應。',
        Persona.gentleman => '${move.uci}。合理的一步。我的回應要來了。',
        Persona.trickster => '${move.uci}。有意思。現在猜猜哪個威脅是真的。',
        Persona.speedDemon => '${move.uci}。沒時間欣賞它。',
        Persona.endgameGrinder => '${move.uci}。接下來每次交換都更重要。',
        Persona.royalVillain => '${move.uci}。棋庭接受你的挑戰。',
      },
    };
  }

  String _llmVoicePendingLine({required bool forCoach}) {
    final strings = AppStrings.of(state.config.locale);
    return switch (strings.locale) {
      AppLocale.en =>
        forCoach ? 'Reading the position...' : 'Finding the right words...',
      AppLocale.zhHant => forCoach ? '正在讀局面...' : '正在組織語氣...',
    };
  }

  String _llmVoiceFailedLine({required bool forCoach}) {
    final strings = AppStrings.of(state.config.locale);
    return switch (strings.locale) {
      AppLocale.en =>
        forCoach
            ? 'Teacher voice is briefly unavailable.'
            : 'Live voice is briefly unavailable.',
      AppLocale.zhHant => forCoach ? '老師語音暫時不可用。' : '即時對話暫時不可用。',
    };
  }

  String _coachLine(EngineAnalysis? analysis, {GameSessionConfig? config}) {
    final activeConfig = config ?? state.config;
    final strings = AppStrings.of(activeConfig.locale);
    if (activeConfig.hintMode == HintMode.off) {
      return switch (strings.locale) {
        AppLocale.en =>
          'Hints are off. Turn them on when you want the teacher voice.',
        AppLocale.zhHant => '提示已關閉。想聽老師建議時再把它打開。',
      };
    }
    if (analysis == null) {
      return _coachOpeningLine(activeConfig);
    }
    final bestMove = analysis.bestMoveUci;
    final continuation = _principalVariationText(analysis);
    final continuationText = continuation == null
        ? switch (strings.locale) {
            AppLocale.en => 'Then re-check threats and loose pieces.',
            AppLocale.zhHant => '接著重查威脅與鬆動棋子。',
          }
        : switch (strings.locale) {
            AppLocale.en => 'Line: $continuation.',
            AppLocale.zhHant => '續著：$continuation。',
          };
    return switch (strings.locale) {
      AppLocale.en => switch (activeConfig.coachPersona) {
        CoachPersona.kirinKing =>
          'Try $bestMove. $continuationText Watch the next threat.',
        CoachPersona.tacticalTeacher =>
          'Try $bestMove. $continuationText Check loose pieces and forcing replies.',
        CoachPersona.calmMentor =>
          'Try $bestMove. $continuationText Improve activity before chasing tactics.',
        CoachPersona.openingArchivist =>
          'Try $bestMove. $continuationText It keeps development and center control coherent.',
        CoachPersona.endgameSensei =>
          'Try $bestMove. $continuationText Keep control before converting.',
        CoachPersona.blunderDetective =>
          'Try $bestMove. $continuationText Verify captures and pins before moving.',
        CoachPersona.attackCommander =>
          'Try $bestMove. $continuationText Keep initiative and bring one more piece in.',
      },
      AppLocale.zhHant => switch (activeConfig.coachPersona) {
        CoachPersona.kirinKing => '建議走 $bestMove。$continuationText 先看下一個威脅。',
        CoachPersona.tacticalTeacher =>
          '建議走 $bestMove。$continuationText 先查鬆動棋子與強制回應。',
        CoachPersona.calmMentor => '建議走 $bestMove。$continuationText 先改善子力活性。',
        CoachPersona.openingArchivist =>
          '建議走 $bestMove。$continuationText 出子與中心會更連貫。',
        CoachPersona.endgameSensei =>
          '建議走 $bestMove。$continuationText 先保持控制再轉換。',
        CoachPersona.blunderDetective =>
          '建議走 $bestMove。$continuationText 走前核對吃子與牽制。',
        CoachPersona.attackCommander =>
          '建議走 $bestMove。$continuationText 保持先手，再調子加入。',
      },
    };
  }

  String? _principalVariationText(EngineAnalysis analysis) {
    final pv = analysis.bestLine?.pv;
    if (pv == null || pv.isEmpty) {
      return null;
    }
    final line = pv.take(4).join(' ');
    return line.isEmpty ? null : line;
  }

  String _liveCommentaryPrompt({
    required AppStrings strings,
    required Move move,
    required bool byPlayer,
    required EngineAnalysis? analysis,
    required MoveReview? review,
  }) {
    final reviewSummary = _reviewSummary(review, strings);
    final reviewLine = reviewSummary == null ? '' : '$reviewSummary\n';
    return '${strings.languageInstruction}\n'
        'Task: write one short in-character live chess line.\n'
        'Latest move: ${move.uci}\n'
        'Played by: ${byPlayer ? 'human player' : 'AI opponent'}\n'
        '${_positionSummary(state.position, strings)}\n'
        'Engine candidate for the side to move: ${analysis?.bestMoveUci ?? 'unknown'}\n'
        'Candidate continuation: ${analysis == null ? 'unknown' : _principalVariationText(analysis) ?? analysis.bestMoveUci}\n'
        'Position signal: ${analysis?.evaluationLabel ?? 'unknown'}\n'
        '$reviewLine'
        'The line must mention at least one concrete board theme such as king safety, center control, loose pieces, open file, pawn structure, initiative, attack, defense, or endgame conversion.\n'
        'Keep it very compact: one short sentence, or at most two very short bullet points.\n'
        'Target under 18 English words or under 22 Chinese characters.\n'
        'You may use light markdown such as **bold** or a tiny bullet list when it improves readability.\n'
        'Output only the spoken line. Do not start with a speaker name, role label, colon prefix, or field label.\n'
        'Do not repeat template phrases such as "points to", "evaluation", "score", "depth", "best move", "指向", "評估", "分數", "深度", or "最佳步".\n'
        'Opponent voice rule: never mention engine analysis, evaluation labels, best-move wording, depth, win rate, or exact UCI notation.\n'
        'Coach voice rule: give practical guidance tied to the current position. You may name the engine candidate exactly if it helps the player know what to try.';
  }

  String _openingCommentaryPrompt(
    AppStrings strings,
    GameSessionConfig config,
  ) {
    return '${strings.languageInstruction}\n'
        'A new chess match has started.\n'
        'Opponent persona: ${config.persona.localizedLabel(strings)}\n'
        'Coach persona: ${config.coachPersona.localizedLabel(strings)}\n'
        'Difficulty: ${config.difficulty.localizedLabel(strings)}\n'
        '${_positionSummary(state.position, strings)}\n'
        'Write one in-character opening line that hints at the coming plan or mood of the game.\n'
        'Reference a real board idea such as center control, development, king safety, tempo, pawn structure, or initiative.\n'
        'Keep it to one short sentence only. Light markdown is allowed if it improves readability.\n'
        'Output only the spoken line. Do not start with a speaker name, role label, colon prefix, or field label.';
  }

  String _coachHintPrompt({
    required AppStrings strings,
    required EngineAnalysis analysis,
    required MoveReview? review,
  }) {
    final reviewSummary = _reviewSummary(review, strings);
    final reviewLine = reviewSummary == null ? '' : '$reviewSummary\n';
    return '${strings.languageInstruction}\n'
        'It is the human player turn.\n'
        '${_positionSummary(state.position, strings)}\n'
        'Recommended move for the human player: ${analysis.bestMoveUci}\n'
        'Candidate continuation: ${_principalVariationText(analysis) ?? analysis.bestMoveUci}\n'
        'Position signal: ${analysis.evaluationLabel}\n'
        '$reviewLine'
        'Give a useful teacher-style hint tied to the current position.\n'
        'Tell the player what move to consider, why it helps, and what to check after it.\n'
        'Use one compact sentence or two tiny bullets. You may name the recommended UCI move exactly.\n'
        'Target under 32 English words or under 42 Chinese characters. Light markdown is allowed when it makes the hint clearer.\n'
        'Output only the spoken hint. Do not start with a speaker name, role label, colon prefix, or field label.\n'
        'Do not repeat template phrases such as "points to", "evaluation", "score", "depth", "best move", "指向", "評估", "分數", "深度", or "最佳步".';
  }

  String _idleBanterPrompt({
    required AppStrings strings,
    required bool speakAsCoach,
  }) {
    final roleTask = speakAsCoach
        ? 'Task: write one short teacher aside while the board is idle.'
        : 'Task: write one short opponent aside while the board is idle.';
    return '${strings.languageInstruction}\n'
        '$roleTask\n'
        '${_positionSummary(state.position, strings)}\n'
        'Do not invent a new move. Do not say a move was played.\n'
        'React to the current tension, plan, piece activity, king safety, structure, or initiative.\n'
        'Keep it under 18 English words or under 24 Chinese characters.\n'
        'Output only the spoken line. No speaker name, no colon prefix.';
  }

  String _opponentSystemPrompt(GameSessionConfig config) {
    final strings = AppStrings.of(config.locale);
    final role = profileForConfig(config).promptRole(strings);
    final personality = switch (strings.locale) {
      AppLocale.en => switch (config.persona) {
        Persona.coldMaster =>
          'Personality: cold, precise, controlled, intimidating.',
        Persona.trashTalker =>
          'Personality: playful table talk, sharp challenge, never hateful.',
        Persona.coach =>
          'Personality: sparring partner energy, explains pressure while competing.',
        Persona.gentleman =>
          'Personality: respectful, poised, confident match-room tone.',
        Persona.trickster =>
          'Personality: tricky, trap-setting, playful misdirection.',
        Persona.speedDemon => 'Personality: fast, sharp, urgent, energetic.',
        Persona.endgameGrinder =>
          'Personality: patient, technical, loves small advantages and conversion pressure.',
        Persona.royalVillain =>
          'Personality: theatrical, grand, elegant, slightly intimidating.',
      },
      AppLocale.zhHant => switch (config.persona) {
        Persona.coldMaster => '個性：冷酷、精準、克制、有壓迫感。',
        Persona.trashTalker => '個性：會嘴砲、挑戰感強，但不要仇恨或冒犯。',
        Persona.coach => '個性：陪練感，競爭時也會點出壓力來源。',
        Persona.gentleman => '個性：尊重對手、沉著、自信，有正式比賽感。',
        Persona.trickster => '個性：喜歡陷阱、假動作與玩笑式誤導。',
        Persona.speedDemon => '個性：快速、銳利、有急迫感。',
        Persona.endgameGrinder => '個性：耐心、技術型，喜歡磨小優勢。',
        Persona.royalVillain => '個性：戲劇化、華麗、優雅且略有壓迫感。',
      },
    };
    final taunt = switch (strings.locale) {
      AppLocale.en => switch (config.tauntLevel) {
        TauntLevel.off => 'Do not taunt.',
        TauntLevel.light => 'Use light banter only.',
        TauntLevel.full => 'Use stronger game-like banter, still friendly.',
      },
      AppLocale.zhHant => switch (config.tauntLevel) {
        TauntLevel.off => '不要嘲諷。',
        TauntLevel.light => '只使用輕度玩笑。',
        TauntLevel.full => '可以使用更有遊戲感的嘴砲，但仍保持友善。',
      },
    };
    final rule = switch (strings.locale) {
      AppLocale.en =>
        'Keep replies under 18 words. React to at least one concrete board clue such as king safety, central tension, loose pieces, open files, pawn structure, initiative, or move quality. Output only the line itself, with no speaker name or colon prefix. Never mention exact engine output and never use slurs or threats. Light markdown is allowed. Reply in English.',
      AppLocale.zhHant =>
        '回覆少於 22 個中文字。必須回應至少一個具體局面線索，例如王安全、中心張力、鬆動棋子、開放線、兵結構、先手或走法品質。只輸出對話本體，不要角色名或冒號前綴。不要提引擎原始輸出，也不要使用歧視或威脅。可使用簡潔 markdown。請一律使用繁體中文。',
    };
    return '$role $personality $taunt $rule';
  }

  String _coachSystemPrompt(GameSessionConfig config) {
    final strings = AppStrings.of(config.locale);
    final persona = switch (strings.locale) {
      AppLocale.en => switch (config.coachPersona) {
        CoachPersona.kirinKing =>
          'You are Chess Spirit King, a mystic chess teacher. Sound regal, direct, and memorable.',
        CoachPersona.tacticalTeacher =>
          'You are a tactical chess teacher. Focus on threats, candidate moves, and concrete ideas.',
        CoachPersona.calmMentor =>
          'You are a calm chess mentor. Focus on plans, piece activity, and king safety.',
        CoachPersona.openingArchivist =>
          'You are an opening archivist. Focus on principles, plans, move-order traps, and development.',
        CoachPersona.endgameSensei =>
          'You are an endgame sensei. Focus on technique, king activity, pawn races, and conversion.',
        CoachPersona.blunderDetective =>
          'You are a blunder detective. Focus on loose pieces, forks, pins, discovered attacks, and danger signs.',
        CoachPersona.attackCommander =>
          'You are an attack commander. Focus on initiative, king pressure, piece coordination, and timing.',
      },
      AppLocale.zhHant => switch (config.coachPersona) {
        CoachPersona.kirinKing => '你是棋靈王，帶有棋靈感的西洋棋老師。語氣威嚴、直接、好記。',
        CoachPersona.tacticalTeacher => '你是戰術型西洋棋老師。專注威脅、候選步與具體想法。',
        CoachPersona.calmMentor => '你是沉穩的西洋棋導師。專注計畫、子力活性與王的安全。',
        CoachPersona.openingArchivist => '你是開局檔案官。專注開局原則、計畫、走法順序陷阱與出子。',
        CoachPersona.endgameSensei => '你是殘局師範。專注技術、王的活性、兵競速與優勢轉換。',
        CoachPersona.blunderDetective => '你是失誤偵探。專注鬆動棋子、叉攻、牽制、閃擊與危險徵兆。',
        CoachPersona.attackCommander => '你是攻擊指揮官。專注先手、王翼壓力、子力協調與時機。',
      },
    };
    final rule = switch (strings.locale) {
      AppLocale.en =>
        'Keep replies under 32 words. Be useful to a chess learner: name the move to consider, one concrete board clue, and the next check after the move. Output only the hint itself, with no speaker name or colon prefix. Light markdown is allowed. Reply in English.',
      AppLocale.zhHant =>
        '回覆少於 42 個中文字。要對學棋者有幫助：說出可考慮的走法、一個具體局面線索，以及走後要檢查什麼。只輸出提示本體，不要角色名或冒號前綴。可使用簡潔 markdown。請一律使用繁體中文。',
    };
    return '$persona $rule';
  }

  String? _outcomeLine(Position position) {
    final outcome = position.outcome;
    if (outcome == null) {
      return null;
    }
    final strings = AppStrings.of(state.config.locale);

    if (outcome.winner == null) {
      return switch (strings.locale) {
        AppLocale.en => 'Result: draw.',
        AppLocale.zhHant => '結果：和棋。',
      };
    }

    if (outcome.winner == state.config.playerSide) {
      return switch (strings.locale) {
        AppLocale.en => 'Result: you won the game.',
        AppLocale.zhHant => '結果：你贏了這盤。',
      };
    }
    return switch (strings.locale) {
      AppLocale.en => 'Result: the AI took the point.',
      AppLocale.zhHant => '結果：AI 拿下這一分。',
    };
  }
}

class _GameTimelineSnapshot {
  const _GameTimelineSnapshot({
    required this.position,
    required this.latestReview,
    required this.reviewHistory,
    required this.whiteClockMs,
    required this.blackClockMs,
    required this.timeoutWinner,
    required this.opponentMessage,
    required this.coachMessage,
    required this.opponentMessageSource,
    required this.coachMessageSource,
    required this.eventLog,
    required this.moveHistory,
    required this.lastMove,
  });

  factory _GameTimelineSnapshot.fromState(GameState state) {
    return _GameTimelineSnapshot(
      position: state.position,
      latestReview: state.latestReview,
      reviewHistory: state.reviewHistory,
      whiteClockMs: state.whiteClockMs,
      blackClockMs: state.blackClockMs,
      timeoutWinner: state.timeoutWinner,
      opponentMessage: state.opponentMessage,
      coachMessage: state.coachMessage,
      opponentMessageSource: state.opponentMessageSource,
      coachMessageSource: state.coachMessageSource,
      eventLog: state.eventLog,
      moveHistory: state.moveHistory,
      lastMove: state.lastMove,
    );
  }

  final Position position;
  final MoveReview? latestReview;
  final List<MoveReview> reviewHistory;
  final int? whiteClockMs;
  final int? blackClockMs;
  final Side? timeoutWinner;
  final String opponentMessage;
  final String coachMessage;
  final DialogueMessageSource opponentMessageSource;
  final DialogueMessageSource coachMessageSource;
  final List<String> eventLog;
  final List<String> moveHistory;
  final LastMove? lastMove;
}
