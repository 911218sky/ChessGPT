import 'package:chess_ai_desktop/src/chess/chess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_ai_desktop/src/i18n/app_localizations.dart';
import 'package:chess_ai_desktop/src/models/bot_roster.dart';
import 'package:chess_ai_desktop/src/models/engine_models.dart';
import 'package:chess_ai_desktop/src/models/game_state.dart';
import 'package:chess_ai_desktop/src/models/session_config.dart';
import 'package:chess_ai_desktop/src/theme/board_theme.dart';
import 'package:chess_ai_desktop/src/widgets/control_panel.dart';

void main() {
  test('control panel view state ignores board-only updates', () {
    final state = _stateWithLlm(const LlmSettings());
    final viewState = ControlPanelViewState.fromGameState(state);
    final boardOnlyUpdate = ControlPanelViewState.fromGameState(
      state.copyWith(
        selectedSquare: Square.e2,
        legalTargets: {Square.e4},
        whiteClockMs: 59000,
        opponentAnalysis: const EngineAnalysis(
          bestMoveUci: 'e7e5',
          depth: 10,
          lines: [],
          elapsedMs: 30,
        ),
      ),
    );

    expect(boardOnlyUpdate, viewState);
  });

  testWidgets('syncs LLM text fields when settings change externally', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(520, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final customState = _stateWithLlm(
      const LlmSettings(
        enabled: true,
        providerKind: LlmProviderKind.customCompatible,
        provider: 'Custom Gateway',
        baseUrl: 'https://llm.example.test/v1',
        model: 'custom-model',
        apiKey: 'secret-token',
      ),
    );

    await _pumpControlPanel(tester, customState);
    await tester.tap(find.widgetWithText(Tab, 'LLM'));
    await tester.pumpAndSettle();

    expect(_llmTextField(tester, 0).controller?.text, 'Custom Gateway');
    expect(find.text('https://llm.example.test/v1'), findsOneWidget);
    expect(find.text('custom-model'), findsOneWidget);

    await _pumpControlPanel(tester, _stateWithLlm(const LlmSettings()));
    await tester.pumpAndSettle();

    expect(find.text('Custom Gateway'), findsNothing);
    expect(find.text('https://llm.example.test/v1'), findsNothing);
    expect(find.text('custom-model'), findsNothing);
    expect(_llmTextField(tester, 0).controller?.text, 'OpenAI Compatible');
    expect(find.text('https://api.openai.com/v1'), findsOneWidget);
    expect(find.text('GPT-5.4'), findsOneWidget);
    expect(_llmTextField(tester, 3).controller?.text, isEmpty);
  });

  testWidgets('preserves active LLM edits during unrelated parent rebuild', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(520, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = _stateWithLlm(const LlmSettings());

    await _pumpControlPanel(tester, state);
    await tester.tap(find.widgetWithText(Tab, 'LLM'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(1),
      'https://editing.test/v1',
    );
    await tester.pump();

    await _pumpControlPanel(tester, state.copyWith(aiThinking: true));
    await tester.pump();

    expect(
      _llmTextField(tester, 1).controller?.text,
      'https://editing.test/v1',
    );
  });

  testWidgets('syncs hidden LLM API key when settings change externally', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(520, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _pumpControlPanel(
      tester,
      _stateWithLlm(const LlmSettings(apiKey: 'first-secret')),
    );
    await tester.tap(find.widgetWithText(Tab, 'LLM'));
    await tester.pumpAndSettle();

    expect(_llmTextField(tester, 3).controller?.text, 'first-secret');

    await _pumpControlPanel(
      tester,
      _stateWithLlm(const LlmSettings(apiKey: 'second-secret')),
    );
    await tester.pumpAndSettle();

    expect(_llmTextField(tester, 3).controller?.text, 'second-secret');
  });

  testWidgets('theme previews render backdrop assets', (tester) async {
    tester.view.physicalSize = const Size(520, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final baseState = _stateWithLlm(const LlmSettings());
    final state = baseState.copyWith(
      config: baseState.config.copyWith(boardTheme: BoardThemeId.desertSun),
    );

    await _pumpControlPanel(tester, state);
    await tester.tap(find.widgetWithText(Tab, 'Match'));
    await tester.pumpAndSettle();

    final backdropAsset = boardThemeStyle(BoardThemeId.desertSun).backdropAsset;
    expect(backdropAsset, isNotNull);
    expect(_findAssetImage(backdropAsset!), findsWidgets);
  });

  testWidgets('shows LLM usage stats and idle banter controls', (tester) async {
    tester.view.physicalSize = const Size(520, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var resetStatsPressed = false;
    var idleEnabled = false;
    var minSeconds = 0;
    var maxSeconds = 0;
    final state =
        _stateWithLlm(
          const LlmSettings(
            enabled: true,
            idleBanterEnabled: true,
            idleBanterMinSeconds: 10,
            idleBanterMaxSeconds: 45,
          ),
        ).copyWith(
          llmStats: const LlmUsageStats(
            requestCount: 3,
            successCount: 2,
            failureCount: 1,
            promptTokens: 30,
            completionTokens: 12,
            totalTokens: 42,
            lastLatencyMs: 321,
          ),
        );

    await _pumpControlPanel(
      tester,
      state,
      onResetLlmStatsPressed: () {
        resetStatsPressed = true;
      },
      onLlmIdleBanterEnabledChanged: (value) {
        idleEnabled = value;
      },
      onLlmIdleBanterMinSecondsChanged: (value) {
        minSeconds = value;
      },
      onLlmIdleBanterMaxSecondsChanged: (value) {
        maxSeconds = value;
      },
    );
    await tester.tap(find.widgetWithText(Tab, 'LLM'));
    await tester.pumpAndSettle();

    expect(find.text('LLM Usage'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Success 2'), findsOneWidget);
    expect(find.text('Failed 1'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Prompt'), findsOneWidget);
    expect(find.text('Output'), findsOneWidget);
    expect(find.text('321 ms'), findsOneWidget);
    expect(find.text('Idle Banter'), findsOneWidget);

    final resetButton = find.byTooltip('Reset LLM usage counters');
    await tester.ensureVisible(resetButton);
    await tester.pumpAndSettle();
    await tester.tap(resetButton);
    await tester.pump();
    expect(resetStatsPressed, isTrue);

    final idleSwitch = find.widgetWithText(SwitchListTile, 'Random idle lines');
    await tester.ensureVisible(idleSwitch);
    await tester.pumpAndSettle();
    await tester.tap(idleSwitch);
    await tester.pump();
    expect(idleEnabled, isFalse);

    final minChip = find.widgetWithText(ChoiceChip, '10s').first;
    await tester.ensureVisible(minChip);
    await tester.pumpAndSettle();
    await tester.tap(minChip);
    await tester.pump();
    expect(minSeconds, 10);

    final maxChip = find.widgetWithText(ChoiceChip, '90s').first;
    await tester.ensureVisible(maxChip);
    await tester.pumpAndSettle();
    await tester.tap(maxChip);
    await tester.pump();
    expect(maxSeconds, 90);
  });

  testWidgets(
    'keeps personality and provider preset sections collapsed by default',
    (tester) async {
      tester.view.physicalSize = const Size(520, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await _pumpControlPanel(tester, _stateWithLlm(const LlmSettings()));

      expect(find.text('Royal Villain'), findsNothing);

      await tester.tap(find.widgetWithText(Tab, 'Coach'));
      await tester.pumpAndSettle();
      expect(find.text('Teacher Voice'), findsNothing);

      await tester.tap(find.widgetWithText(Tab, 'LLM'));
      await tester.pumpAndSettle();
      expect(find.text('Google Gemini'), findsNothing);
    },
  );

  testWidgets('expands collapsible personality and provider preset sections', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(520, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _pumpControlPanel(tester, _stateWithLlm(const LlmSettings()));

    await tester.tap(find.text('Personality').hitTestable().first);
    await tester.pumpAndSettle();
    expect(find.text('Royal Villain'), findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, 'LLM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Provider Preset').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Google Gemini'), findsOneWidget);
    expect(find.text('Kimi Code'), findsOneWidget);
  });

  testWidgets('selecting a collapsed bot category starts with that profile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(520, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    GameSessionConfig? requestedConfig;
    final baseState = _stateWithLlm(const LlmSettings());
    await _pumpControlPanel(
      tester,
      baseState,
      onNewGamePressed: ({config}) async {
        requestedConfig = config;
      },
    );

    await tester.ensureVisible(find.text('Beginner').last);
    await tester.tap(find.text('Beginner').last);
    await tester.pumpAndSettle();

    final expectedProfile = botRoster.firstWhere(
      (profile) => profile.category == 'Beginner',
    );
    expect(requestedConfig, isNotNull);
    expect(requestedConfig!.difficulty, expectedProfile.difficulty);
    expect(requestedConfig!.botProfileName, expectedProfile.name);
    expect(requestedConfig!.persona, baseState.config.persona);
    expect(requestedConfig!.tauntLevel, expectedProfile.tauntLevel);
  });

  testWidgets('selecting a personality does not change the bot role', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(520, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Persona? selectedPersona;
    GameSessionConfig? requestedConfig;
    final baseState = _stateWithLlm(const LlmSettings());
    await _pumpControlPanel(
      tester,
      baseState.copyWith(
        config: baseState.config.copyWith(botProfileName: 'Vanta'),
      ),
      onPersonaChanged: (persona) {
        selectedPersona = persona;
      },
      onNewGamePressed: ({config}) async {
        requestedConfig = config;
      },
    );

    await tester.tap(find.text('Personality').hitTestable().first);
    await tester.pumpAndSettle();
    final personalityCard = find.text('Cold Master').hitTestable().last;
    await tester.ensureVisible(personalityCard);
    await tester.tap(personalityCard);
    await tester.pumpAndSettle();

    expect(selectedPersona, Persona.coldMaster);
    expect(requestedConfig, isNull);
  });

  testWidgets(
    'personality section highlights config persona without role names',
    (tester) async {
      tester.view.physicalSize = const Size(520, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final baseState = _stateWithLlm(const LlmSettings());
      await _pumpControlPanel(
        tester,
        baseState.copyWith(
          config: baseState.config.copyWith(
            botProfileName: 'Vanta',
            persona: Persona.trashTalker,
          ),
        ),
      );

      expect(find.text('Trash Talker'), findsOneWidget);

      await tester.tap(find.text('Personality').hitTestable().first);
      await tester.pumpAndSettle();

      final selectedCard = find.byKey(
        const ValueKey('persona-card-trashTalker'),
      );
      expect(
        find.descendant(of: selectedCard, matching: find.text('Current')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('persona-current-coldMaster')),
        findsNothing,
      );
      expect(
        find.descendant(of: selectedCard, matching: find.text('Polly')),
        findsNothing,
      );
      expect(
        find.descendant(of: selectedCard, matching: find.text('Brass Hook')),
        findsNothing,
      );
    },
  );

  testWidgets('selecting player side in match tab invokes callback', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(520, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Side? selectedSide;
    await _pumpControlPanel(
      tester,
      _stateWithLlm(const LlmSettings()),
      onPlayerSideChanged: (side) {
        selectedSide = side;
      },
    );

    await tester.tap(find.widgetWithText(Tab, 'Match'));
    await tester.pumpAndSettle();
    final blackSideChip = find.widgetWithText(ChoiceChip, 'black');
    await tester.ensureVisible(blackSideChip);
    await tester.tap(blackSideChip);
    await tester.pumpAndSettle();

    expect(selectedSide, Side.black);
  });

  testWidgets('selecting taunt level in coach tab invokes callback', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(520, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    TauntLevel? selectedTauntLevel;
    await _pumpControlPanel(
      tester,
      _stateWithLlm(const LlmSettings()),
      onTauntLevelChanged: (level) {
        selectedTauntLevel = level;
      },
    );

    await tester.tap(find.widgetWithText(Tab, 'Coach'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personality'));
    await tester.pumpAndSettle();
    final fullTauntChip = find.widgetWithText(ChoiceChip, 'Full');
    await tester.ensureVisible(fullTauntChip);
    await tester.tap(fullTauntChip);
    await tester.pumpAndSettle();

    expect(selectedTauntLevel, TauntLevel.full);
  });

  testWidgets('coach tab does not duplicate live review content', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(520, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final review = _review(
      moveUci: 'e2e4',
      quality: MoveQuality.best,
      centipawnLoss: 0,
      elapsedMs: 1200,
    );
    final state = _stateWithLlm(
      const LlmSettings(),
    ).copyWith(latestReview: review, reviewHistory: [review]);

    await _pumpControlPanel(tester, state);
    await tester.tap(find.widgetWithText(Tab, 'Coach'));
    await tester.pumpAndSettle();

    expect(find.text('Coach Feed'), findsOneWidget);
    expect(find.text('Personality'), findsOneWidget);
    expect(find.text('Reviewed'), findsNothing);
    expect(find.text('Played'), findsNothing);
  });

  testWidgets('keeps review tab inaccessible until a review exists', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(520, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = _stateWithLlm(const LlmSettings());
    final strings = AppStrings.of(state.config.locale);

    await _pumpControlPanel(tester, state);
    await tester.tap(find.widgetWithText(Tab, strings.liveReview));
    await tester.pumpAndSettle();

    expect(find.text(strings.waitingForMoveReview), findsNothing);
    expect(find.text('Beginner'), findsOneWidget);
  });

  testWidgets('shows whole-game review stats in live review', (tester) async {
    tester.view.physicalSize = const Size(520, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final reviews = [
      _review(
        moveUci: 'e2e4',
        quality: MoveQuality.best,
        centipawnLoss: 0,
        elapsedMs: 1200,
      ),
      _review(
        moveUci: 'g1f3',
        quality: MoveQuality.mistake,
        centipawnLoss: 80,
        elapsedMs: 3400,
      ),
      _review(
        moveUci: 'f1c4',
        quality: MoveQuality.blunder,
        centipawnLoss: 260,
        elapsedMs: 5600,
      ),
    ];
    final state = _stateWithLlm(
      const LlmSettings(),
    ).copyWith(latestReview: reviews.last, reviewHistory: reviews);

    await _pumpControlPanel(tester, state);
    await tester.tap(find.widgetWithText(Tab, 'Live Review'));
    await tester.pumpAndSettle();

    final strings = AppStrings.of(state.config.locale);
    expect(find.text(MoveQuality.blunder.label(false)), findsOneWidget);
    _expectStatValue('review-summary-reviewed', strings.reviewedMoves, '3');
    _expectStatValue('review-summary-good', strings.goodMoves, '1');
    _expectStatValue('review-summary-problem', strings.problemMoves, '2');
    _expectStatValue('review-breakdown-mistakes', strings.mistakes, '1');
    _expectStatValue(
      'review-breakdown-missed-chances',
      strings.missedChances,
      '0',
    );
    _expectStatValue(
      'review-breakdown-critical-mistakes',
      strings.criticalMistakes,
      '1',
    );
    _expectStatValue('review-summary-average-cp', strings.averageCpLoss, '113');
    _expectStatValue(
      'review-summary-average-pace',
      strings.averagePace,
      '3.4s',
    );
    _expectStatValue('review-summary-last-pace', strings.lastPace, '5.6s');
  });

  testWidgets('shows live review labels in Traditional Chinese', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(520, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final review = _review(
      moveUci: 'f1c4',
      quality: MoveQuality.blunder,
      centipawnLoss: 260,
      elapsedMs: 5600,
    );
    final state = GameState.initial(
      config: GameSessionConfig.defaults().copyWith(locale: AppLocale.zhHant),
    ).copyWith(latestReview: review, reviewHistory: [review]);

    await _pumpControlPanel(tester, state);
    final strings = AppStrings.of(state.config.locale);

    await tester.tap(find.widgetWithText(Tab, strings.liveReview));
    await tester.pumpAndSettle();

    expect(find.text(MoveQuality.blunder.label(true)), findsOneWidget);
    _expectStatValue('review-summary-reviewed', strings.reviewedMoves, '1');
    _expectStatValue('review-summary-good', strings.goodMoves, '0');
    _expectStatValue('review-summary-problem', strings.problemMoves, '1');
    _expectStatValue(
      'review-breakdown-missed-chances',
      strings.missedChances,
      '0',
    );
    _expectStatValue(
      'review-breakdown-critical-mistakes',
      strings.criticalMistakes,
      '1',
    );
    _expectStatValue('review-summary-average-cp', strings.averageCpLoss, '260');
  });

  testWidgets('keeps active tab state during unrelated parent rebuild', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(520, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = _stateWithLlm(const LlmSettings());

    await _pumpControlPanel(tester, state);
    await tester.tap(find.widgetWithText(Tab, 'Coach'));
    await tester.pumpAndSettle();

    await _pumpControlPanel(tester, state.copyWith(aiThinking: true));
    await tester.pumpAndSettle();

    expect(find.text('Coach Feed'), findsOneWidget);
    expect(find.text('Personality'), findsOneWidget);
    expect(find.text('Match Setup'), findsNothing);
  });

  testWidgets('bottom action shows restart after initialization', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(520, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _pumpControlPanel(
      tester,
      _stateWithLlm(const LlmSettings()).copyWith(initialized: true),
    );

    expect(find.text('Restart'), findsOneWidget);
  });
}

TextFormField _llmTextField(WidgetTester tester, int index) {
  return tester.widget<TextFormField>(find.byType(TextFormField).at(index));
}

Finder _findAssetImage(String assetName) {
  return find.byWidgetPredicate((widget) {
    if (widget is! Image) {
      return false;
    }
    final provider = widget.image;
    if (provider is AssetImage) {
      return provider.assetName == assetName;
    }
    if (provider is ResizeImage && provider.imageProvider is AssetImage) {
      return (provider.imageProvider as AssetImage).assetName == assetName;
    }
    return false;
  });
}

void _expectStatValue(String key, String label, String value) {
  final stat = find.byKey(ValueKey(key));
  expect(stat, findsOneWidget);
  expect(find.descendant(of: stat, matching: find.text(label)), findsOneWidget);
  expect(find.descendant(of: stat, matching: find.text(value)), findsOneWidget);
}

GameState _stateWithLlm(LlmSettings llm) {
  return GameState.initial(
    config: GameSessionConfig.defaults().copyWith(llm: llm),
  );
}

MoveReview _review({
  required String moveUci,
  required MoveQuality quality,
  required int centipawnLoss,
  required int elapsedMs,
}) {
  return MoveReview(
    moveUci: moveUci,
    bestMoveUci: 'e2e4',
    quality: quality,
    expectedDrop: 0,
    centipawnLoss: centipawnLoss,
    whiteWinPercent: 45,
    drawPercent: 20,
    blackWinPercent: 35,
    beforeEvaluation: '+0.20',
    afterEvaluation: '-0.10',
    elapsedMs: elapsedMs,
  );
}

Future<void> _pumpControlPanel(
  WidgetTester tester,
  GameState state, {
  Future<void> Function({GameSessionConfig? config})? onNewGamePressed,
  ValueChanged<Side>? onPlayerSideChanged,
  ValueChanged<Persona>? onPersonaChanged,
  ValueChanged<TauntLevel>? onTauntLevelChanged,
  ValueChanged<bool>? onLlmIdleBanterEnabledChanged,
  ValueChanged<int>? onLlmIdleBanterMinSecondsChanged,
  ValueChanged<int>? onLlmIdleBanterMaxSecondsChanged,
  VoidCallback? onResetLlmStatsPressed,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 520,
          height: 900,
          child: ControlPanel(
            state: state,
            onDifficultyChanged: (_) {},
            onOpponentDepthChanged: (_) {},
            onTeacherDepthChanged: (_) {},
            onEngineResourcesChanged: (_) {},
            onTimeControlChanged: (_) {},
            onPlayerSideChanged: onPlayerSideChanged ?? (_) {},
            onHintModeChanged: (_) {},
            onCandidateLineCountChanged: (_) {},
            onAppTextScalePercentChanged: (_) {},
            onOpenAiPanelPressed: () {},
            onBoardThemeChanged: (_) {},
            onLocaleChanged: (_) {},
            onPersonaChanged: onPersonaChanged ?? (_) {},
            onCoachPersonaChanged: (_) {},
            onTauntLevelChanged: onTauntLevelChanged ?? (_) {},
            onUndoPressed: () {},
            onRedoPressed: () {},
            onNewGamePressed: onNewGamePressed ?? ({config}) async {},
            onRematchPressed: () async {},
            onLlmEnabledChanged: (_) {},
            onLlmProviderKindChanged: (_) {},
            onLlmProviderChanged: (_) {},
            onLlmBaseUrlChanged: (_) {},
            onLlmModelChanged: (_) {},
            onLlmCredentialModeChanged: (_) {},
            onLlmApiKeyChanged: (_) {},
            onLlmIdleBanterEnabledChanged:
                onLlmIdleBanterEnabledChanged ?? (_) {},
            onLlmIdleBanterMinSecondsChanged:
                onLlmIdleBanterMinSecondsChanged ?? (_) {},
            onLlmIdleBanterMaxSecondsChanged:
                onLlmIdleBanterMaxSecondsChanged ?? (_) {},
            onResetLlmStatsPressed: onResetLlmStatsPressed ?? () {},
            onTestLlmPressed: () async {},
            onFetchLlmModelsPressed: () async {},
            onResetLlmPressed: () async {},
            onResetPreferencesPressed: () async {},
          ),
        ),
      ),
    ),
  );
}
