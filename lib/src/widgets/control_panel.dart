import 'dart:math' as math;

import 'package:chess_ai_desktop/src/chess/chess.dart';
import 'package:flutter/material.dart';

import '../i18n/app_localizations.dart';
import '../models/bot_roster.dart';
import '../models/engine_models.dart';
import '../models/game_state.dart';
import '../models/session_config.dart';
import '../theme/app_theme.dart';
import '../theme/board_theme.dart';
import 'control_panel/bots_tab.dart';
import 'control_panel/coach_tab.dart';
import 'control_panel/llm_tab.dart';
import 'control_panel/match_tab.dart';
import 'control_panel/primitives.dart';
import 'control_panel/review_tab.dart';

class ControlPanel extends StatefulWidget {
  const ControlPanel({
    super.key,
    required this.state,
    required this.onDifficultyChanged,
    required this.onOpponentDepthChanged,
    required this.onTeacherDepthChanged,
    required this.onEngineResourcesChanged,
    required this.onTimeControlChanged,
    required this.onPlayerSideChanged,
    required this.onHintModeChanged,
    required this.onCandidateLineCountChanged,
    required this.onAppTextScalePercentChanged,
    required this.onOpenAiPanelPressed,
    required this.onBoardThemeChanged,
    required this.onLocaleChanged,
    required this.onPersonaChanged,
    required this.onCoachPersonaChanged,
    required this.onTauntLevelChanged,
    required this.onUndoPressed,
    required this.onRedoPressed,
    required this.onNewGamePressed,
    required this.onRematchPressed,
    required this.onLlmEnabledChanged,
    required this.onLlmProviderKindChanged,
    required this.onLlmProviderChanged,
    required this.onLlmBaseUrlChanged,
    required this.onLlmModelChanged,
    required this.onLlmCredentialModeChanged,
    required this.onLlmApiKeyChanged,
    required this.onLlmIdleBanterEnabledChanged,
    required this.onLlmIdleBanterMinSecondsChanged,
    required this.onLlmIdleBanterMaxSecondsChanged,
    required this.onResetLlmStatsPressed,
    required this.onTestLlmPressed,
    required this.onFetchLlmModelsPressed,
    required this.onResetLlmPressed,
    required this.onResetPreferencesPressed,
  });

  final GameState state;
  final ValueChanged<DifficultyLevel> onDifficultyChanged;
  final ValueChanged<SearchDepthLevel> onOpponentDepthChanged;
  final ValueChanged<SearchDepthLevel> onTeacherDepthChanged;
  final ValueChanged<EngineResourceSettings> onEngineResourcesChanged;
  final ValueChanged<TimeControl> onTimeControlChanged;
  final ValueChanged<Side> onPlayerSideChanged;
  final ValueChanged<HintMode> onHintModeChanged;
  final ValueChanged<int> onCandidateLineCountChanged;
  final ValueChanged<int> onAppTextScalePercentChanged;
  final VoidCallback onOpenAiPanelPressed;
  final ValueChanged<BoardThemeId> onBoardThemeChanged;
  final ValueChanged<AppLocale> onLocaleChanged;
  final ValueChanged<Persona> onPersonaChanged;
  final ValueChanged<CoachPersona> onCoachPersonaChanged;
  final ValueChanged<TauntLevel> onTauntLevelChanged;
  final VoidCallback onUndoPressed;
  final VoidCallback onRedoPressed;
  final Future<void> Function({GameSessionConfig? config}) onNewGamePressed;
  final Future<void> Function() onRematchPressed;
  final ValueChanged<bool> onLlmEnabledChanged;
  final ValueChanged<LlmProviderKind> onLlmProviderKindChanged;
  final ValueChanged<String> onLlmProviderChanged;
  final ValueChanged<String> onLlmBaseUrlChanged;
  final ValueChanged<String> onLlmModelChanged;
  final ValueChanged<LlmCredentialMode> onLlmCredentialModeChanged;
  final ValueChanged<String> onLlmApiKeyChanged;
  final ValueChanged<bool> onLlmIdleBanterEnabledChanged;
  final ValueChanged<int> onLlmIdleBanterMinSecondsChanged;
  final ValueChanged<int> onLlmIdleBanterMaxSecondsChanged;
  final VoidCallback onResetLlmStatsPressed;
  final Future<void> Function() onTestLlmPressed;
  final Future<void> Function() onFetchLlmModelsPressed;
  final Future<void> Function() onResetLlmPressed;
  final Future<void> Function() onResetPreferencesPressed;

  @override
  State<ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends State<ControlPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_keepReviewLockedUntilReady);
  }

  @override
  void didUpdateWidget(ControlPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.state.hasMoveReview && widget.state.hasMoveReview) {
      _tabController.animateTo(2);
    }
    if (oldWidget.state.moveHistory.isNotEmpty &&
        widget.state.moveHistory.isEmpty) {
      if (_tabController.index == 2) {
        _tabController.animateTo(0);
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_keepReviewLockedUntilReady);
    _tabController.dispose();
    super.dispose();
  }

  void _keepReviewLockedUntilReady() {
    if (_isReviewTabLocked) {
      _tabController.animateTo(_tabController.previousIndex);
    }
  }

  bool get _isReviewTabLocked =>
      !widget.state.hasMoveReview && _tabController.index == 2;

  @override
  Widget build(BuildContext context) {
    final currentProfile = profileForConfig(widget.state.config);
    final strings = AppStrings.of(widget.state.config.locale);

    return ScrollConfiguration(
      behavior: const _NoScrollbarBehavior(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const minPanelHeight = 360.0;
          final compactHeight = constraints.maxHeight < 430;
          final footerButtons = Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: LayoutBuilder(
              builder: (context, footerConstraints) {
                final actionButtons = [
                  SquareIconAction(
                    icon: widget.state.config.playerSide == Side.white
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    active: true,
                    tooltip: strings.switchSide,
                    onTap: () {
                      final next = widget.state.config.playerSide == Side.white
                          ? Side.black
                          : Side.white;
                      widget.onPlayerSideChanged(next);
                    },
                  ),
                  SquareIconAction(
                    icon: Icons.psychology_alt_rounded,
                    active: widget.state.config.hintMode != HintMode.off,
                    tooltip: strings.toggleHints,
                    onTap: () {
                      final next = widget.state.config.hintMode == HintMode.off
                          ? HintMode.bestMove
                          : HintMode.off;
                      widget.onHintModeChanged(next);
                    },
                  ),
                  SquareIconAction(
                    icon: Icons.undo_rounded,
                    active: widget.state.canUndo,
                    tooltip: strings.undoMove,
                    onTap: widget.state.canUndo ? widget.onUndoPressed : null,
                  ),
                  SquareIconAction(
                    icon: Icons.redo_rounded,
                    active: widget.state.canRedo,
                    tooltip: strings.redoMove,
                    onTap: widget.state.canRedo ? widget.onRedoPressed : null,
                  ),
                  SquareIconAction(
                    icon: Icons.refresh_rounded,
                    active: false,
                    tooltip: strings.rematch,
                    onTap: widget.state.aiThinking
                        ? null
                        : widget.onRematchPressed,
                  ),
                ];

                final optionsSelect = _FooterSelect(
                  icon: Icons.tune_rounded,
                  label: strings.options,
                  value:
                      '${widget.state.config.boardTheme.localizedLabel(strings)} / ${widget.state.config.locale.label}',
                  onTap: () => _tabController.animateTo(1),
                );

                if (footerConstraints.maxWidth < 470) {
                  return Column(
                    children: [
                      optionsSelect,
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: actionButtons,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: optionsSelect),
                    const SizedBox(width: 12),
                    for (
                      var index = 0;
                      index < actionButtons.length;
                      index++
                    ) ...[
                      if (index > 0) const SizedBox(width: 8),
                      actionButtons[index],
                    ],
                  ],
                );
              },
            ),
          );
          final newGameButton = Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
            child: SizedBox(
              width: double.infinity,
              height: compactHeight ? 54 : 70,
              child: FilledButton(
                onPressed: widget.state.aiThinking
                    ? null
                    : () => widget.onNewGamePressed(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: const Color(0xFFF6FFF1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                child: Text(
                  widget.state.aiThinking
                      ? strings.thinking
                      : (widget.state.initialized
                            ? strings.restart
                            : strings.play),
                ),
              ),
            ),
          );

          final panel = Container(
            decoration: panelDecoration(),
            child: SizedBox(
              height: math.max(constraints.maxHeight, minPanelHeight),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0x1FFFFFFF)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.smart_toy_rounded,
                            color: Color(0xFFD9DEE2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          strings.playBots,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        SquareIconAction(
                          icon: Icons.open_in_full_rounded,
                          active: true,
                          tooltip: strings.aiPanelExpanded,
                          onTap: widget.onOpenAiPanelPressed,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                    child: _PanelTabs(
                      strings: strings,
                      controller: _tabController,
                      reviewEnabled: widget.state.hasMoveReview,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                      child: TabBarView(
                        controller: _tabController,
                        children: List.generate(5, (index) {
                          return _ControlPanelTabPage(
                            index: index,
                            state: widget.state,
                            currentProfile: currentProfile,
                            onDifficultyChanged: widget.onDifficultyChanged,
                            onOpponentDepthChanged:
                                widget.onOpponentDepthChanged,
                            onTeacherDepthChanged: widget.onTeacherDepthChanged,
                            onEngineResourcesChanged:
                                widget.onEngineResourcesChanged,
                            onTimeControlChanged: widget.onTimeControlChanged,
                            onPlayerSideChanged: widget.onPlayerSideChanged,
                            onHintModeChanged: widget.onHintModeChanged,
                            onCandidateLineCountChanged:
                                widget.onCandidateLineCountChanged,
                            onAppTextScalePercentChanged:
                                widget.onAppTextScalePercentChanged,
                            onOpenAiPanelPressed: widget.onOpenAiPanelPressed,
                            onBoardThemeChanged: widget.onBoardThemeChanged,
                            onLocaleChanged: widget.onLocaleChanged,
                            onPersonaChanged: widget.onPersonaChanged,
                            onCoachPersonaChanged: widget.onCoachPersonaChanged,
                            onTauntLevelChanged: widget.onTauntLevelChanged,
                            onUndoPressed: widget.onUndoPressed,
                            onRedoPressed: widget.onRedoPressed,
                            onNewGamePressed: widget.onNewGamePressed,
                            onRematchPressed: widget.onRematchPressed,
                            onLlmEnabledChanged: widget.onLlmEnabledChanged,
                            onLlmProviderKindChanged:
                                widget.onLlmProviderKindChanged,
                            onLlmProviderChanged: widget.onLlmProviderChanged,
                            onLlmBaseUrlChanged: widget.onLlmBaseUrlChanged,
                            onLlmModelChanged: widget.onLlmModelChanged,
                            onLlmCredentialModeChanged:
                                widget.onLlmCredentialModeChanged,
                            onLlmApiKeyChanged: widget.onLlmApiKeyChanged,
                            onLlmIdleBanterEnabledChanged:
                                widget.onLlmIdleBanterEnabledChanged,
                            onLlmIdleBanterMinSecondsChanged:
                                widget.onLlmIdleBanterMinSecondsChanged,
                            onLlmIdleBanterMaxSecondsChanged:
                                widget.onLlmIdleBanterMaxSecondsChanged,
                            onResetLlmStatsPressed:
                                widget.onResetLlmStatsPressed,
                            onTestLlmPressed: widget.onTestLlmPressed,
                            onFetchLlmModelsPressed:
                                widget.onFetchLlmModelsPressed,
                            onResetLlmPressed: widget.onResetLlmPressed,
                            onResetPreferencesPressed:
                                widget.onResetPreferencesPressed,
                          );
                        }),
                      ),
                    ),
                  ),
                  if (!compactHeight) footerButtons,
                  newGameButton,
                ],
              ),
            ),
          );
          if (constraints.maxHeight < minPanelHeight) {
            return SingleChildScrollView(child: panel);
          }
          return panel;
        },
      ),
    );
  }
}

class ControlPanelViewState {
  const ControlPanelViewState({
    required this.config,
    required this.initialized,
    required this.aiThinking,
    required this.hint,
    required this.latestReview,
    required this.reviewHistory,
    required this.hardwareProfile,
    required this.opponentMessage,
    required this.coachMessage,
    required this.availableLlmModels,
    required this.llmTesting,
    required this.llmFetchingModels,
    required this.llmStatusMessage,
    required this.llmStats,
    required this.moveHistory,
    required this.canUndo,
    required this.canRedo,
  });

  factory ControlPanelViewState.fromGameState(GameState state) {
    return ControlPanelViewState(
      config: state.config,
      initialized: state.initialized,
      aiThinking: state.aiThinking,
      hint: state.hint,
      latestReview: state.latestReview,
      reviewHistory: state.reviewHistory,
      hardwareProfile: state.hardwareProfile,
      opponentMessage: state.opponentMessage,
      coachMessage: state.coachMessage,
      availableLlmModels: state.availableLlmModels,
      llmTesting: state.llmTesting,
      llmFetchingModels: state.llmFetchingModels,
      llmStatusMessage: state.llmStatusMessage,
      llmStats: state.llmStats,
      moveHistory: state.moveHistory,
      canUndo: state.canUndo,
      canRedo: state.canRedo,
    );
  }

  final GameSessionConfig config;
  final bool initialized;
  final bool aiThinking;
  final EngineAnalysis? hint;
  final MoveReview? latestReview;
  final List<MoveReview> reviewHistory;
  final EngineHardwareProfile? hardwareProfile;
  final String opponentMessage;
  final String coachMessage;
  final List<String> availableLlmModels;
  final bool llmTesting;
  final bool llmFetchingModels;
  final String? llmStatusMessage;
  final LlmUsageStats llmStats;
  final List<String> moveHistory;
  final bool canUndo;
  final bool canRedo;

  bool get hasMoveReview => latestReview != null;

  MoveReviewSummary get reviewSummary =>
      MoveReviewSummary(reviews: reviewHistory);

  GameState toGameState() {
    return GameState.initial(config: config).copyWith(
      initialized: initialized,
      aiThinking: aiThinking,
      hint: hint,
      latestReview: latestReview,
      reviewHistory: reviewHistory,
      hardwareProfile: hardwareProfile,
      opponentMessage: opponentMessage,
      coachMessage: coachMessage,
      availableLlmModels: availableLlmModels,
      llmTesting: llmTesting,
      llmFetchingModels: llmFetchingModels,
      llmStatusMessage: llmStatusMessage,
      llmStats: llmStats,
      moveHistory: moveHistory,
      canUndo: canUndo,
      canRedo: canRedo,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ControlPanelViewState &&
        other.config == config &&
        other.initialized == initialized &&
        other.aiThinking == aiThinking &&
        other.hint == hint &&
        other.latestReview == latestReview &&
        _sameMoveReviews(other.reviewHistory, reviewHistory) &&
        _sameHardwareProfile(other.hardwareProfile, hardwareProfile) &&
        other.opponentMessage == opponentMessage &&
        other.coachMessage == coachMessage &&
        _sameStrings(other.availableLlmModels, availableLlmModels) &&
        other.llmTesting == llmTesting &&
        other.llmFetchingModels == llmFetchingModels &&
        other.llmStatusMessage == llmStatusMessage &&
        _sameLlmUsageStats(other.llmStats, llmStats) &&
        _sameStrings(other.moveHistory, moveHistory) &&
        other.canUndo == canUndo &&
        other.canRedo == canRedo;
  }

  @override
  int get hashCode => Object.hash(
    config,
    initialized,
    aiThinking,
    hint,
    latestReview,
    Object.hashAll(reviewHistory),
    _hardwareProfileHash(hardwareProfile),
    opponentMessage,
    coachMessage,
    Object.hashAll(availableLlmModels),
    llmTesting,
    llmFetchingModels,
    llmStatusMessage,
    _llmUsageStatsHash(llmStats),
    Object.hashAll(moveHistory),
    canUndo,
    canRedo,
  );
}

bool _sameMoveReviews(List<MoveReview> a, List<MoveReview> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) {
      return false;
    }
  }
  return true;
}

bool _sameStrings(List<String> a, List<String> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) {
      return false;
    }
  }
  return true;
}

bool _sameHardwareProfile(EngineHardwareProfile? a, EngineHardwareProfile? b) {
  return a?.runtime == b?.runtime &&
      a?.cpuThreads == b?.cpuThreads &&
      a?.memoryMb == b?.memoryMb &&
      a?.recommendedThreads == b?.recommendedThreads &&
      a?.recommendedHashMb == b?.recommendedHashMb;
}

int _hardwareProfileHash(EngineHardwareProfile? profile) {
  return Object.hash(
    profile?.runtime,
    profile?.cpuThreads,
    profile?.memoryMb,
    profile?.recommendedThreads,
    profile?.recommendedHashMb,
  );
}

bool _sameLlmUsageStats(LlmUsageStats a, LlmUsageStats b) {
  return a.requestCount == b.requestCount &&
      a.successCount == b.successCount &&
      a.failureCount == b.failureCount &&
      a.promptTokens == b.promptTokens &&
      a.completionTokens == b.completionTokens &&
      a.totalTokens == b.totalTokens &&
      a.lastLatencyMs == b.lastLatencyMs;
}

int _llmUsageStatsHash(LlmUsageStats stats) {
  return Object.hash(
    stats.requestCount,
    stats.successCount,
    stats.failureCount,
    stats.promptTokens,
    stats.completionTokens,
    stats.totalTokens,
    stats.lastLatencyMs,
  );
}

class _ControlPanelTabPage extends StatelessWidget {
  const _ControlPanelTabPage({
    required this.index,
    required this.state,
    required this.currentProfile,
    required this.onDifficultyChanged,
    required this.onOpponentDepthChanged,
    required this.onTeacherDepthChanged,
    required this.onEngineResourcesChanged,
    required this.onTimeControlChanged,
    required this.onPlayerSideChanged,
    required this.onHintModeChanged,
    required this.onCandidateLineCountChanged,
    required this.onAppTextScalePercentChanged,
    required this.onOpenAiPanelPressed,
    required this.onBoardThemeChanged,
    required this.onLocaleChanged,
    required this.onPersonaChanged,
    required this.onCoachPersonaChanged,
    required this.onTauntLevelChanged,
    required this.onUndoPressed,
    required this.onRedoPressed,
    required this.onNewGamePressed,
    required this.onRematchPressed,
    required this.onLlmEnabledChanged,
    required this.onLlmProviderKindChanged,
    required this.onLlmProviderChanged,
    required this.onLlmBaseUrlChanged,
    required this.onLlmModelChanged,
    required this.onLlmCredentialModeChanged,
    required this.onLlmApiKeyChanged,
    required this.onLlmIdleBanterEnabledChanged,
    required this.onLlmIdleBanterMinSecondsChanged,
    required this.onLlmIdleBanterMaxSecondsChanged,
    required this.onResetLlmStatsPressed,
    required this.onTestLlmPressed,
    required this.onFetchLlmModelsPressed,
    required this.onResetLlmPressed,
    required this.onResetPreferencesPressed,
  });

  final int index;
  final GameState state;
  final BotProfile currentProfile;
  final ValueChanged<DifficultyLevel> onDifficultyChanged;
  final ValueChanged<SearchDepthLevel> onOpponentDepthChanged;
  final ValueChanged<SearchDepthLevel> onTeacherDepthChanged;
  final ValueChanged<EngineResourceSettings> onEngineResourcesChanged;
  final ValueChanged<TimeControl> onTimeControlChanged;
  final ValueChanged<Side> onPlayerSideChanged;
  final ValueChanged<HintMode> onHintModeChanged;
  final ValueChanged<int> onCandidateLineCountChanged;
  final ValueChanged<int> onAppTextScalePercentChanged;
  final VoidCallback onOpenAiPanelPressed;
  final ValueChanged<BoardThemeId> onBoardThemeChanged;
  final ValueChanged<AppLocale> onLocaleChanged;
  final ValueChanged<Persona> onPersonaChanged;
  final ValueChanged<CoachPersona> onCoachPersonaChanged;
  final ValueChanged<TauntLevel> onTauntLevelChanged;
  final VoidCallback onUndoPressed;
  final VoidCallback onRedoPressed;
  final Future<void> Function({GameSessionConfig? config}) onNewGamePressed;
  final Future<void> Function() onRematchPressed;
  final ValueChanged<bool> onLlmEnabledChanged;
  final ValueChanged<LlmProviderKind> onLlmProviderKindChanged;
  final ValueChanged<String> onLlmProviderChanged;
  final ValueChanged<String> onLlmBaseUrlChanged;
  final ValueChanged<String> onLlmModelChanged;
  final ValueChanged<LlmCredentialMode> onLlmCredentialModeChanged;
  final ValueChanged<String> onLlmApiKeyChanged;
  final ValueChanged<bool> onLlmIdleBanterEnabledChanged;
  final ValueChanged<int> onLlmIdleBanterMinSecondsChanged;
  final ValueChanged<int> onLlmIdleBanterMaxSecondsChanged;
  final VoidCallback onResetLlmStatsPressed;
  final Future<void> Function() onTestLlmPressed;
  final Future<void> Function() onFetchLlmModelsPressed;
  final Future<void> Function() onResetLlmPressed;
  final Future<void> Function() onResetPreferencesPressed;

  @override
  Widget build(BuildContext context) {
    switch (index) {
      case 0:
        return BotsTab(
          state: state,
          currentProfile: currentProfile,
          onPersonaChanged: onPersonaChanged,
          onProfileSelected: _applyProfile,
        );
      case 1:
        return MatchTab(
          state: state,
          onDifficultyChanged: onDifficultyChanged,
          onOpponentDepthChanged: onOpponentDepthChanged,
          onTeacherDepthChanged: onTeacherDepthChanged,
          onEngineResourcesChanged: onEngineResourcesChanged,
          onTimeControlChanged: onTimeControlChanged,
          onPlayerSideChanged: onPlayerSideChanged,
          onHintModeChanged: onHintModeChanged,
          onCandidateLineCountChanged: onCandidateLineCountChanged,
          onAppTextScalePercentChanged: onAppTextScalePercentChanged,
          onOpenAiPanelPressed: onOpenAiPanelPressed,
          onBoardThemeChanged: onBoardThemeChanged,
          onLocaleChanged: onLocaleChanged,
          onRematchPressed: onRematchPressed,
          onResetPreferencesPressed: onResetPreferencesPressed,
        );
      case 2:
        return ReviewTab(state: state);
      case 3:
        return CoachTab(
          state: state,
          onPersonaChanged: onPersonaChanged,
          onCoachPersonaChanged: onCoachPersonaChanged,
          onTauntLevelChanged: onTauntLevelChanged,
        );
      case 4:
        return LlmTab(
          state: state,
          onLlmEnabledChanged: onLlmEnabledChanged,
          onLlmProviderKindChanged: onLlmProviderKindChanged,
          onPersonaChanged: onPersonaChanged,
          onCoachPersonaChanged: onCoachPersonaChanged,
          onLlmProviderChanged: onLlmProviderChanged,
          onLlmBaseUrlChanged: onLlmBaseUrlChanged,
          onLlmModelChanged: onLlmModelChanged,
          onLlmCredentialModeChanged: onLlmCredentialModeChanged,
          onLlmApiKeyChanged: onLlmApiKeyChanged,
          onLlmIdleBanterEnabledChanged: onLlmIdleBanterEnabledChanged,
          onLlmIdleBanterMinSecondsChanged: onLlmIdleBanterMinSecondsChanged,
          onLlmIdleBanterMaxSecondsChanged: onLlmIdleBanterMaxSecondsChanged,
          onResetLlmStatsPressed: onResetLlmStatsPressed,
          onTestLlmPressed: onTestLlmPressed,
          onFetchLlmModelsPressed: onFetchLlmModelsPressed,
          onResetLlmPressed: onResetLlmPressed,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _applyProfile(BotProfile profile) {
    final config = state.config.copyWith(
      difficulty: profile.difficulty,
      botProfileName: profile.name,
      tauntLevel: profile.tauntLevel,
    );
    return onNewGamePressed(config: config);
  }
}

class _PanelTabs extends StatelessWidget {
  const _PanelTabs({
    required this.strings,
    required this.controller,
    required this.reviewEnabled,
  });

  final AppStrings strings;
  final TabController controller;
  final bool reviewEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 44,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF252A29),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: TabBar(
        controller: controller,
        dividerColor: Colors.transparent,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(4),
        indicator: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        labelStyle: theme.textTheme.labelLarge?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelColor: Colors.white54,
        tabs: [
          Tab(child: _TabLabel(strings.bots)),
          Tab(child: _TabLabel(strings.match)),
          Tab(
            child: _TabLabel(
              strings.liveReview,
              color: reviewEnabled ? null : Colors.white30,
            ),
          ),
          Tab(child: _TabLabel(strings.coach)),
          Tab(child: _TabLabel(strings.llm)),
        ],
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel(this.text, {this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: TextStyle(color: color),
      ),
    );
  }
}

class _NoScrollbarBehavior extends MaterialScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class _FooterSelect extends StatelessWidget {
  const _FooterSelect({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white70),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.white54),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.expand_more_rounded, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}
