import 'dart:async';

import 'package:chessgpt/src/chess/chess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chessgpt/src/controllers/game_controller.dart';
import 'package:chessgpt/src/i18n/app_localizations.dart';
import 'package:chessgpt/src/models/engine_models.dart';
import 'package:chessgpt/src/models/game_state.dart';
import 'package:chessgpt/src/models/session_config.dart';
import 'package:chessgpt/src/services/llm_commentary_service.dart';
import 'package:chessgpt/src/services/local_settings_store.dart';
import 'package:chessgpt/src/services/stockfish_service.dart';
import 'package:chessgpt/src/theme/board_theme.dart';

void main() {
  test(
    'stale new-game initialization cannot overwrite a newer session',
    () async {
      final stockfish = _FakeStockfishService();
      final container = _container(stockfish: stockfish);
      addTearDown(container.dispose);

      final controller = container.read(gameControllerProvider.notifier);
      final oldConfig = GameSessionConfig.defaults().copyWith(
        hintMode: HintMode.off,
        boardTheme: BoardThemeId.classicWood,
      );
      final newConfig = GameSessionConfig.defaults().copyWith(
        hintMode: HintMode.off,
        boardTheme: BoardThemeId.midnight,
      );

      final oldGame = controller.startNewGame(config: oldConfig);
      await Future<void>.delayed(Duration.zero);
      final newGame = controller.startNewGame(config: newConfig);
      await Future<void>.delayed(Duration.zero);

      expect(stockfish.hardwareRequests, hasLength(2));
      stockfish.hardwareRequests[1].complete(_hardwareProfile(threads: 4));
      await newGame;
      expect(
        container.read(gameControllerProvider).config.boardTheme,
        BoardThemeId.midnight,
      );

      stockfish.hardwareRequests[0].complete(_hardwareProfile(threads: 1));
      await oldGame;
      expect(
        container.read(gameControllerProvider).config.boardTheme,
        BoardThemeId.midnight,
      );
    },
  );

  test('stale hint analysis cannot write after a new game starts', () async {
    final stockfish = _FakeStockfishService();
    final container = _container(stockfish: stockfish);
    addTearDown(container.dispose);

    final controller = container.read(gameControllerProvider.notifier);
    stockfish.completeNextHardware(_hardwareProfile());
    await controller.startNewGame(
      config: GameSessionConfig.defaults().copyWith(
        hintMode: HintMode.bestMove,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(stockfish.analysisRequests, hasLength(1));
    await controller.startNewGame(
      config: GameSessionConfig.defaults().copyWith(hintMode: HintMode.off),
    );

    stockfish.analysisRequests.single.complete(_analysis('e2e4'));
    await Future<void>.delayed(Duration.zero);

    final state = container.read(gameControllerProvider);
    expect(state.config.hintMode, HintMode.off);
    expect(state.hint, isNull);
  });

  test('stale AI turn success cannot move in a newer game', () async {
    final stockfish = _FakeStockfishService();
    final container = _container(stockfish: stockfish);
    addTearDown(container.dispose);

    final controller = container.read(gameControllerProvider.notifier);
    stockfish.completeNextHardware(_hardwareProfile());
    final oldGame = controller.startNewGame(
      config: GameSessionConfig.defaults().copyWith(
        playerSide: Side.black,
        hintMode: HintMode.off,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(stockfish.analysisRequests, hasLength(1));
    await controller.startNewGame(
      config: GameSessionConfig.defaults().copyWith(
        playerSide: Side.white,
        hintMode: HintMode.off,
      ),
    );

    stockfish.analysisRequests.single.complete(_analysis('e2e4'));
    await oldGame;

    final state = container.read(gameControllerProvider);
    expect(state.config.playerSide, Side.white);
    expect(state.moveHistory, isEmpty);
    expect(state.position.fen, Position.initialPosition(Rule.chess).fen);
  });

  test('stale AI turn fallback cannot move in a newer game', () async {
    final stockfish = _FakeStockfishService();
    final container = _container(stockfish: stockfish);
    addTearDown(container.dispose);

    final controller = container.read(gameControllerProvider.notifier);
    stockfish.completeNextHardware(_hardwareProfile());
    final oldGame = controller.startNewGame(
      config: GameSessionConfig.defaults().copyWith(
        playerSide: Side.black,
        hintMode: HintMode.off,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(stockfish.analysisRequests, hasLength(1));
    await controller.startNewGame(
      config: GameSessionConfig.defaults().copyWith(
        playerSide: Side.white,
        hintMode: HintMode.off,
      ),
    );

    stockfish.analysisRequests.single.completeError(Exception('old failure'));
    await oldGame;

    final state = container.read(gameControllerProvider);
    expect(state.config.playerSide, Side.white);
    expect(state.moveHistory, isEmpty);
    expect(state.position.fen, Position.initialPosition(Rule.chess).fen);
  });

  test('stale human move review cannot overwrite a newer review', () async {
    final stockfish = _FakeStockfishService();
    final container = _container(stockfish: stockfish);
    addTearDown(container.dispose);

    final controller = container.read(gameControllerProvider.notifier);
    stockfish.completeNextHardware(_hardwareProfile());
    await controller.startNewGame(
      config: GameSessionConfig.defaults().copyWith(hintMode: HintMode.off),
    );

    final firstMove = _tapMove(controller, _square(4, 1), _square(4, 3));
    await Future<void>.delayed(Duration.zero);
    stockfish.completeNextAnalysis(multiPv: 1, bestMove: 'e7e5');
    await firstMove;

    final humanMove = _firstLegalMove(container.read(gameControllerProvider));
    final secondMove = _tapMove(controller, humanMove.from, humanMove.to);
    await Future<void>.delayed(Duration.zero);
    stockfish.completeNextAnalysis(multiPv: 1, bestMove: 'b8c6');
    stockfish.completeLastAnalysis(multiPv: 3, bestMove: humanMove.uci);
    await Future<void>.delayed(Duration.zero);
    stockfish.completeLastAnalysis(multiPv: 3, bestMove: humanMove.uci);
    await secondMove;
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(gameControllerProvider).latestReview?.moveUci,
      humanMove.uci,
    );

    stockfish.completeNextAnalysis(multiPv: 3, bestMove: 'e2e4');
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(gameControllerProvider).latestReview?.moveUci,
      humanMove.uci,
    );
  });

  test(
    'stale model fetch does not restore old LLM settings or stay loading',
    () async {
      final llm = _FakeLlmCommentaryService();
      final container = ProviderContainer(
        overrides: [
          gameControllerProvider.overrideWith(
            () =>
                GameController(llm: llm, settingsStore: _memorySettingsStore()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(gameControllerProvider.notifier);
      controller.updateLlmModel('old-model');

      final fetchFuture = controller.fetchLlmModels();
      controller.updateLlmModel('new-model');
      llm.modelsCompleter.complete(['old-model', 'replacement-model']);
      await fetchFuture;

      final state = container.read(gameControllerProvider);
      expect(state.llmFetchingModels, isFalse);
      expect(state.config.llm.model, 'new-model');
      expect(state.availableLlmModels, isEmpty);
    },
  );

  test(
    'stale connection test clears loading without writing old status',
    () async {
      final llm = _FakeLlmCommentaryService();
      final container = ProviderContainer(
        overrides: [
          gameControllerProvider.overrideWith(
            () =>
                GameController(llm: llm, settingsStore: _memorySettingsStore()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(gameControllerProvider.notifier);
      controller.updateLlmModel('old-model');

      final testFuture = controller.testLlmConnection();
      controller.updateLlmModel('new-model');
      llm.testCompleter.complete();
      await testFuture;

      final state = container.read(gameControllerProvider);
      expect(state.llmTesting, isFalse);
      expect(state.config.llm.model, 'new-model');
      expect(state.llmStatusMessage, isNot(contains('ready')));
    },
  );

  test('opponent depth levels are capped at a weaker search depth', () {
    expect(SearchDepthLevel.quick.opponentDepth, 8);
    expect(SearchDepthLevel.balanced.opponentDepth, 10);
    expect(SearchDepthLevel.deep.opponentDepth, 12);
    expect(SearchDepthLevel.tournament.opponentDepth, 14);
    expect(SearchDepthLevel.maximum.opponentDepth, 16);
  });

  test('teacher depth levels stay stronger than opponent depth levels', () {
    expect(SearchDepthLevel.quick.teacherDepth, 10);
    expect(SearchDepthLevel.balanced.teacherDepth, 14);
    expect(SearchDepthLevel.deep.teacherDepth, 18);
    expect(SearchDepthLevel.tournament.teacherDepth, 24);
    expect(SearchDepthLevel.maximum.teacherDepth, 28);
  });

  test('controller passes the capped opponent depth to Stockfish', () async {
    final stockfish = _FakeStockfishService();
    final container = _container(stockfish: stockfish);
    addTearDown(container.dispose);

    final controller = container.read(gameControllerProvider.notifier);
    stockfish.completeNextHardware(_hardwareProfile());
    final game = controller.startNewGame(
      config: GameSessionConfig.defaults().copyWith(
        playerSide: Side.black,
        hintMode: HintMode.off,
        difficulty: DifficultyLevel.easy,
        opponentDepth: SearchDepthLevel.quick,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(stockfish.analysisRequests, hasLength(1));
    expect(stockfish.analysisRequests.single.settings.depth, 8);
    expect(stockfish.analysisRequests.single.settings.limitStrength, isTrue);
    expect(stockfish.analysisRequests.single.settings.elo, 1200);
    stockfish.completeNextAnalysis(multiPv: 1, bestMove: 'e2e4');
    await game;
  });

  test('controller passes the deeper teacher depth to Stockfish', () async {
    final stockfish = _FakeStockfishService();
    final container = _container(stockfish: stockfish);
    addTearDown(container.dispose);

    final controller = container.read(gameControllerProvider.notifier);
    stockfish.completeNextHardware(_hardwareProfile());
    await controller.startNewGame(
      config: GameSessionConfig.defaults().copyWith(
        playerSide: Side.white,
        difficulty: DifficultyLevel.easy,
        hintMode: HintMode.bestMove,
        teacherDepth: SearchDepthLevel.maximum,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(stockfish.analysisRequests, hasLength(1));
    expect(stockfish.analysisRequests.single.settings.depth, 28);
    expect(stockfish.analysisRequests.single.settings.limitStrength, isFalse);
    expect(stockfish.analysisRequests.single.settings.elo, isNull);
  });

  test('coach fallback gives a concrete move and continuation', () async {
    final stockfish = _FakeStockfishService();
    final container = _container(stockfish: stockfish);
    addTearDown(container.dispose);

    final controller = container.read(gameControllerProvider.notifier);
    stockfish.completeNextHardware(_hardwareProfile());
    await controller.startNewGame(
      config: GameSessionConfig.defaults().copyWith(
        playerSide: Side.white,
        hintMode: HintMode.bestMove,
        llm: const LlmSettings(enabled: false),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(stockfish.analysisRequests, hasLength(1));
    stockfish.analysisRequests.single.complete(
      _analysis('e2e4', pv: const ['e2e4', 'e7e5', 'g1f3', 'b8c6']),
    );
    await Future<void>.delayed(Duration.zero);

    final state = container.read(gameControllerProvider);
    expect(state.coachMessage, contains('e2e4'));
    expect(state.coachMessage, contains('e7e5'));
    expect(state.coachMessage, contains('g1f3'));
    expect(state.coachMessage, contains('b8c6'));
    expect(state.coachMessage, anyOf(contains('Check'), contains('Watch')));
  });

  test('direct dropped human move uses the normal move flow', () async {
    final stockfish = _FakeStockfishService();
    final container = _container(stockfish: stockfish);
    addTearDown(container.dispose);

    final controller = container.read(gameControllerProvider.notifier);
    stockfish.completeNextHardware(_hardwareProfile());
    await controller.startNewGame(
      config: GameSessionConfig.defaults().copyWith(hintMode: HintMode.off),
    );

    final move = controller.dropMove(Square.e2, Square.e4);
    await Future<void>.delayed(Duration.zero);

    expect(stockfish.analysisRequests, hasLength(2));
    stockfish.completeNextAnalysis(multiPv: 1, bestMove: 'e7e5');
    await move;

    final state = container.read(gameControllerProvider);
    expect(state.moveHistory.take(2), ['e2e4', 'e7e5']);
    expect(state.selectedSquare, isNull);
    expect(state.legalTargets, isEmpty);
  });

  test('completed human reviews accumulate whole-game review stats', () async {
    final stockfish = _FakeStockfishService();
    final container = _container(stockfish: stockfish);
    addTearDown(container.dispose);

    final controller = container.read(gameControllerProvider.notifier);
    stockfish.completeNextHardware(_hardwareProfile());
    await controller.startNewGame(
      config: GameSessionConfig.defaults().copyWith(hintMode: HintMode.off),
    );

    final move = controller.dropMove(Square.e2, Square.e4);
    await Future<void>.delayed(Duration.zero);
    stockfish.completeNextAnalysis(multiPv: 1, bestMove: 'e7e5');
    await move;

    await Future<void>.delayed(Duration.zero);
    stockfish.completeNextAnalysis(multiPv: 3, bestMove: 'd2d4');
    await Future<void>.delayed(Duration.zero);
    stockfish.completeNextAnalysis(multiPv: 3, bestMove: 'b1c3');
    await Future<void>.delayed(Duration.zero);

    final state = container.read(gameControllerProvider);
    expect(state.reviewHistory, hasLength(1));
    expect(state.latestReview?.moveUci, 'e2e4');
    expect(state.reviewSummary.reviewedMoves, 1);
    expect(state.reviewSummary.problemMoveCount, 1);
    expect(state.reviewSummary.averageCentipawnLoss, greaterThan(0));
  });

  test(
    'configured LLM voices hide move-template fallback and track usage',
    () async {
      final stockfish = _FakeStockfishService();
      final llm = _FakeLlmCommentaryService();
      final container = _container(stockfish: stockfish, llm: llm);
      addTearDown(container.dispose);

      final controller = container.read(gameControllerProvider.notifier);
      stockfish.completeNextHardware(_hardwareProfile());
      await controller.startNewGame(
        config: GameSessionConfig.defaults().copyWith(
          botProfileName: 'Queen Malva',
          persona: Persona.gentleman,
          hintMode: HintMode.off,
          llm: const LlmSettings(enabled: false, model: 'test-model'),
        ),
      );
      controller.updateLlmEnabled(true);

      final move = controller.dropMove(Square.e2, Square.e4);
      await Future<void>.delayed(Duration.zero);
      stockfish.completeNextAnalysis(multiPv: 1, bestMove: 'e7e5');
      await move;
      await Future<void>.delayed(Duration.zero);

      final pendingState = container.read(gameControllerProvider);
      expect(pendingState.opponentMessage, isNot(contains('e7e5')));
      expect(llm.completionRequests.length, greaterThanOrEqualTo(4));
      final preMoveStats = pendingState.llmStats;
      expect(llm.inFlightCompletionCount, greaterThanOrEqualTo(2));
      expect(
        llm.completionRequests
            .map((request) => request.systemPrompt)
            .where((prompt) => prompt.contains('Opponent role: Queen Malva')),
        isNotEmpty,
      );
      expect(
        llm.completionRequests
            .map((request) => request.systemPrompt)
            .where((prompt) => prompt.contains('Personality: respectful')),
        isNotEmpty,
      );

      llm.completeLatestCompletions([
        'Opponent sees central pressure.',
        'Teacher watches king safety.',
      ]);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(gameControllerProvider);
      expect(state.opponentMessage, 'Opponent sees central pressure.');
      expect(state.coachMessage, 'Teacher watches king safety.');
      expect(state.llmStats.requestCount, preMoveStats.requestCount + 2);
      expect(state.llmStats.successCount, preMoveStats.successCount + 2);
      expect(state.llmStats.totalTokens, preMoveStats.totalTokens + 40);

      controller.resetLlmUsageStats();
      expect(container.read(gameControllerProvider).llmStats.requestCount, 0);
    },
  );

  test('LLM partial responses update commentary before completion', () async {
    final stockfish = _FakeStockfishService();
    final llm = _FakeLlmCommentaryService();
    final container = _container(stockfish: stockfish, llm: llm);
    addTearDown(container.dispose);

    final controller = container.read(gameControllerProvider.notifier);
    stockfish.completeNextHardware(_hardwareProfile());
    await controller.startNewGame(
      config: GameSessionConfig.defaults().copyWith(
        hintMode: HintMode.off,
        llm: const LlmSettings(enabled: true, model: 'test-model'),
      ),
    );

    final move = controller.dropMove(Square.e2, Square.e4);
    await Future<void>.delayed(Duration.zero);
    stockfish.completeNextAnalysis(multiPv: 1, bestMove: 'e7e5');
    await move;
    await Future<void>.delayed(Duration.zero);

    llm.emitLatestPendingPartial('Streaming opponent line', indexFromEnd: 1);
    await Future<void>.delayed(Duration.zero);

    final partialState = container.read(gameControllerProvider);
    expect(partialState.opponentMessage, 'Streaming opponent line');
    expect(partialState.llmStats.requestCount, 0);

    llm.completeLatestCompletions([
      'Streaming opponent line done.',
      'Teacher final line.',
    ]);
    await Future<void>.delayed(Duration.zero);

    final finalState = container.read(gameControllerProvider);
    expect(finalState.opponentMessage, 'Streaming opponent line done.');
    expect(finalState.llmStats.requestCount, greaterThanOrEqualTo(2));
  });

  test('Traditional Chinese LLM pending lines are readable', () async {
    final stockfish = _FakeStockfishService();
    final llm = _FakeLlmCommentaryService();
    final container = _container(stockfish: stockfish, llm: llm);
    addTearDown(container.dispose);

    final controller = container.read(gameControllerProvider.notifier);
    stockfish.completeNextHardware(_hardwareProfile());
    await controller.startNewGame(
      config: GameSessionConfig.defaults().copyWith(
        locale: AppLocale.zhHant,
        hintMode: HintMode.off,
        llm: const LlmSettings(enabled: true, model: 'test-model'),
      ),
    );

    final move = controller.dropMove(Square.e2, Square.e4);
    await Future<void>.delayed(Duration.zero);
    stockfish.completeNextAnalysis(multiPv: 1, bestMove: 'e7e5');
    await move;
    await Future<void>.delayed(Duration.zero);

    final state = container.read(gameControllerProvider);
    expect(state.opponentMessage, '正在組織語氣...');
    expect(state.coachMessage, '正在讀局面...');
  });

  test(
    'idle banter settings update LLM config without starting a new game',
    () {
      final container = _container(stockfish: _FakeStockfishService());
      addTearDown(container.dispose);

      final controller = container.read(gameControllerProvider.notifier);
      final initialFen = container.read(gameControllerProvider).position.fen;

      controller.updateLlmIdleBanterEnabled(true);
      controller.updateLlmIdleBanterMinSeconds(30);
      controller.updateLlmIdleBanterMaxSeconds(90);

      final state = container.read(gameControllerProvider);
      expect(state.position.fen, initialFen);
      expect(state.config.llm.idleBanterEnabled, isTrue);
      expect(state.config.llm.idleBanterMinSeconds, 30);
      expect(state.config.llm.idleBanterMaxSeconds, 90);
    },
  );

  test('stored LLM settings without idle fields use idle banter defaults', () {
    final settings = LlmSettings.fromJson({
      'enabled': true,
      'provider': 'Custom Gateway',
      'baseUrl': 'https://llm.example.test/v1',
      'model': 'custom-model',
      'apiKey': 'secret-token',
    });

    expect(settings.idleBanterEnabled, isTrue);
    expect(settings.idleBanterMinSeconds, 10);
    expect(settings.idleBanterMaxSeconds, 45);
    expect(settings.credentialMode, LlmCredentialMode.defaultProxy);
  });

  test('LLM credential mode can switch to a typed API key', () {
    final container = _container();
    addTearDown(container.dispose);

    final controller = container.read(gameControllerProvider.notifier);
    controller.updateLlmCredentialMode(LlmCredentialMode.customApiKey);
    controller.updateLlmApiKey('typed-key');

    final llm = container.read(gameControllerProvider).config.llm;
    expect(llm.credentialMode, LlmCredentialMode.customApiKey);
    expect(llm.apiKey, 'typed-key');
  });

  test('Kimi Code provider preset applies coding endpoint defaults', () {
    final container = _container();
    addTearDown(container.dispose);

    final controller = container.read(gameControllerProvider.notifier);
    controller.updateLlmProviderKind(LlmProviderKind.kimiCode);

    final llm = container.read(gameControllerProvider).config.llm;
    expect(llm.providerKind, LlmProviderKind.kimiCode);
    expect(llm.provider, 'Kimi Code');
    expect(llm.baseUrl, 'https://api.kimi.com/coding/v1');
    expect(llm.model, 'kimi-for-coding');
    expect(llm.providerKind.apiKeyHint, 'KIMI_API_KEY');
  });

  test('stored Kimi-compatible settings infer the Kimi Code preset', () {
    final settings = LlmSettings.fromJson({
      'enabled': true,
      'provider': 'Moonshot Kimi',
      'baseUrl': 'https://api.kimi.com/coding/v1',
      'model': 'kimi-for-coding',
      'apiKey': 'secret-token',
    });

    expect(settings.providerKind, LlmProviderKind.kimiCode);
  });

  test('status text warns when player is in check', () async {
    final stockfish = _FakeStockfishService();
    final container = _container(stockfish: stockfish);
    addTearDown(container.dispose);

    final controller = container.read(gameControllerProvider.notifier);
    stockfish.completeNextHardware(_hardwareProfile());
    await controller.startNewGame(
      config: GameSessionConfig.defaults().copyWith(hintMode: HintMode.off),
    );

    final checkPosition = Position.setupPosition(
      Rule.chess,
      Setup.parseFen('4k3/8/8/8/8/8/4r3/4K3 w - - 0 1'),
    );

    final current = container.read(gameControllerProvider);
    controller.state = current.copyWith(position: checkPosition);
    controller.updateLocale(current.config.locale);

    expect(
      container.read(gameControllerProvider).statusText,
      AppStrings.of(current.config.locale).playerInCheck,
    );
  });

  test('undo and redo restore stable player-turn snapshots', () async {
    final stockfish = _FakeStockfishService();
    final container = _container(stockfish: stockfish);
    addTearDown(container.dispose);

    final controller = container.read(gameControllerProvider.notifier);
    stockfish.completeNextHardware(_hardwareProfile());
    await controller.startNewGame(
      config: GameSessionConfig.defaults().copyWith(hintMode: HintMode.off),
    );

    final move = controller.dropMove(Square.e2, Square.e4);
    await Future<void>.delayed(Duration.zero);
    stockfish.completeNextAnalysis(multiPv: 1, bestMove: 'e7e5');
    await move;
    await Future<void>.delayed(Duration.zero);

    final afterPair = container.read(gameControllerProvider);
    expect(afterPair.moveHistory.take(2), ['e2e4', 'e7e5']);
    expect(afterPair.canUndo, isTrue);
    expect(afterPair.canRedo, isFalse);

    controller.undoTurn();
    await Future<void>.delayed(Duration.zero);

    final undone = container.read(gameControllerProvider);
    expect(undone.moveHistory, isEmpty);
    expect(undone.playerTurn, isTrue);
    expect(undone.canRedo, isTrue);

    controller.redoTurn();
    await Future<void>.delayed(Duration.zero);

    final redone = container.read(gameControllerProvider);
    expect(redone.moveHistory.take(2), ['e2e4', 'e7e5']);
    expect(redone.canUndo, isTrue);
    expect(redone.canRedo, isFalse);
  });

  test('playing after undo clears redo branch', () async {
    final stockfish = _FakeStockfishService();
    final container = _container(stockfish: stockfish);
    addTearDown(container.dispose);

    final controller = container.read(gameControllerProvider.notifier);
    stockfish.completeNextHardware(_hardwareProfile());
    await controller.startNewGame(
      config: GameSessionConfig.defaults().copyWith(hintMode: HintMode.off),
    );

    final firstMove = controller.dropMove(Square.e2, Square.e4);
    await Future<void>.delayed(Duration.zero);
    stockfish.completeNextAnalysis(multiPv: 1, bestMove: 'e7e5');
    await firstMove;
    await Future<void>.delayed(Duration.zero);

    controller.undoTurn();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(gameControllerProvider).canRedo, isTrue);

    final branchMove = controller.dropMove(Square.d2, Square.d4);
    await Future<void>.delayed(Duration.zero);
    stockfish.completeNextAnalysis(multiPv: 1, bestMove: 'd7d5');
    await branchMove;
    await Future<void>.delayed(Duration.zero);

    final branched = container.read(gameControllerProvider);
    expect(branched.moveHistory.take(2), ['d2d4', 'd7d5']);
    expect(branched.moveHistory, isNot(contains('e7e5')));
    expect(branched.canRedo, isFalse);
  });
}

Future<void> _tapMove(GameController controller, Square from, Square to) async {
  await controller.tapSquare(from);
  await controller.tapSquare(to);
}

Square _square(int file, int rank) => squareFromCoords(file, rank);

({Square from, Square to, String uci}) _firstLegalMove(GameState state) {
  final legalMoves = state.position.legalMoves;
  for (final entry in legalMoves.entries) {
    if (entry.value.isNotEmpty) {
      final to = entry.value.squares.first;
      return (
        from: entry.key,
        to: to,
        uci: NormalMove(from: entry.key, to: to).uci,
      );
    }
  }
  throw StateError('Expected at least one legal move.');
}

ProviderContainer _container({
  _FakeStockfishService? stockfish,
  _FakeLlmCommentaryService? llm,
}) {
  return ProviderContainer(
    overrides: [
      gameControllerProvider.overrideWith(
        () => GameController(
          stockfish: stockfish,
          llm: llm ?? _FakeLlmCommentaryService(),
          settingsStore: _memorySettingsStore(),
        ),
      ),
    ],
  );
}

LocalSettingsStore _memorySettingsStore() {
  Map<String, Object?> persisted = <String, Object?>{};
  return LocalSettingsStore(
    readSettingsJson: () async => Map<String, Object?>.from(persisted),
    writeSettingsJson: (json) async {
      persisted = Map<String, Object?>.from(json);
    },
  );
}

EngineHardwareProfile _hardwareProfile({int threads = 2}) {
  return EngineHardwareProfile(
    cpuThreads: threads,
    memoryMb: 4096,
    recommendedThreads: threads,
    recommendedHashMb: 128,
  );
}

EngineAnalysis _analysis(String bestMove, {List<String>? pv}) {
  final principalVariation = pv ?? [bestMove];
  return EngineAnalysis(
    bestMoveUci: bestMove,
    depth: 1,
    elapsedMs: 1,
    lines: [
      EngineLine(
        multipv: 1,
        moveUci: bestMove,
        pv: principalVariation,
        depth: 1,
        scoreType: 'cp',
        score: 20,
      ),
    ],
  );
}

class _FakeLlmCommentaryService extends LlmCommentaryService {
  final Completer<List<String>> modelsCompleter = Completer<List<String>>();
  final Completer<void> testCompleter = Completer<void>();
  final List<_CompletionRequest> completionRequests = [];

  int get inFlightCompletionCount => completionRequests
      .where((request) => !request.completer.isCompleted)
      .length;

  @override
  Future<List<String>> fetchModels(LlmSettings settings) {
    return modelsCompleter.future;
  }

  @override
  Future<void> testConnection(LlmSettings settings) {
    return testCompleter.future;
  }

  @override
  Future<LlmCompletionResult> complete({
    required LlmSettings settings,
    required String systemPrompt,
    required String userPrompt,
    void Function(String partialText)? onPartial,
  }) {
    final request = _CompletionRequest(
      settings: settings,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      onPartial: onPartial,
    );
    completionRequests.add(request);
    return request.completer.future;
  }

  void emitLatestPendingPartial(String text, {int indexFromEnd = 0}) {
    final pending = completionRequests
        .where((request) => !request.completer.isCompleted)
        .toList(growable: false);
    final request = pending[pending.length - 1 - indexFromEnd];
    request.onPartial?.call(text);
  }

  void completeNextCompletion(String text) {
    final request = completionRequests.firstWhere(
      (request) => !request.completer.isCompleted,
    );
    request.completer.complete(
      LlmCompletionResult(
        text: text,
        usage: const LlmTokenUsage(
          promptTokens: 12,
          completionTokens: 8,
          totalTokens: 20,
        ),
        latencyMs: 25,
      ),
    );
  }

  void completeLatestCompletions(List<String> texts) {
    final pending = completionRequests
        .where((request) => !request.completer.isCompleted)
        .toList(growable: false);
    final selected = pending.skip(pending.length - texts.length).toList();
    for (var index = 0; index < selected.length; index++) {
      selected[index].completer.complete(
        LlmCompletionResult(
          text: texts[index],
          usage: const LlmTokenUsage(
            promptTokens: 12,
            completionTokens: 8,
            totalTokens: 20,
          ),
          latencyMs: 25,
        ),
      );
    }
  }

  void completeAllPending({required String prefix}) {
    var index = 0;
    for (final request in completionRequests) {
      if (!request.completer.isCompleted) {
        request.completer.complete(
          LlmCompletionResult(
            text: '$prefix ${index++}',
            usage: const LlmTokenUsage(
              promptTokens: 12,
              completionTokens: 8,
              totalTokens: 20,
            ),
            latencyMs: 25,
          ),
        );
      }
    }
  }
}

class _CompletionRequest {
  _CompletionRequest({
    required this.settings,
    required this.systemPrompt,
    required this.userPrompt,
    required this.onPartial,
  });

  final LlmSettings settings;
  final String systemPrompt;
  final String userPrompt;
  final void Function(String partialText)? onPartial;
  final Completer<LlmCompletionResult> completer =
      Completer<LlmCompletionResult>();
}

class _FakeStockfishService extends StockfishService {
  final List<EngineHardwareProfile> queuedHardwareProfiles = [];
  final List<Completer<EngineHardwareProfile>> hardwareRequests = [];
  final List<_AnalysisRequest> analysisRequests = [];

  void completeNextHardware(EngineHardwareProfile profile) {
    queuedHardwareProfiles.add(profile);
  }

  @override
  Future<EngineHardwareProfile> detectHardwareProfile() {
    if (queuedHardwareProfiles.isNotEmpty) {
      return Future.value(queuedHardwareProfiles.removeAt(0));
    }
    final request = Completer<EngineHardwareProfile>();
    hardwareRequests.add(request);
    return request.future;
  }

  @override
  Future<EngineAnalysis> analyze({
    required String fen,
    required EngineSettings settings,
  }) {
    final request = _AnalysisRequest(fen: fen, settings: settings);
    analysisRequests.add(request);
    return request.future;
  }

  void completeNextAnalysis({required int multiPv, required String bestMove}) {
    final request = analysisRequests.firstWhere(
      (request) => !request.isCompleted && request.settings.multiPv == multiPv,
    );
    request.complete(_analysis(bestMove));
  }

  void completeLastAnalysis({required int multiPv, required String bestMove}) {
    final request = analysisRequests.lastWhere(
      (request) => !request.isCompleted && request.settings.multiPv == multiPv,
    );
    request.complete(_analysis(bestMove));
  }

  @override
  Future<void> dispose() async {}
}

class _AnalysisRequest {
  _AnalysisRequest({required this.fen, required this.settings});

  final String fen;
  final EngineSettings settings;
  final Completer<EngineAnalysis> _completer = Completer<EngineAnalysis>();

  bool get isCompleted => _completer.isCompleted;

  Future<EngineAnalysis> get future => _completer.future;

  void complete(EngineAnalysis analysis) => _completer.complete(analysis);

  void completeError(Object error) => _completer.completeError(error);
}
