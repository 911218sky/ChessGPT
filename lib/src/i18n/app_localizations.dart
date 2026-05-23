enum AppLocale {
  en,
  zhHant;

  String get label => switch (this) {
    AppLocale.en => 'English',
    AppLocale.zhHant => '繁體中文',
  };

  String localizedLabel(AppStrings strings) => switch (strings.locale) {
    AppLocale.en => label,
    AppLocale.zhHant => switch (this) {
      AppLocale.en => '英文',
      AppLocale.zhHant => '繁體中文',
    },
  };
}

class AppStrings {
  const AppStrings._(this.locale);

  final AppLocale locale;

  static AppStrings of(AppLocale locale) => AppStrings._(locale);

  String get playBots => switch (locale) {
    AppLocale.en => 'Play Bots',
    AppLocale.zhHant => 'AI 對戰',
  };

  String get bots => switch (locale) {
    AppLocale.en => 'Bots',
    AppLocale.zhHant => '對手',
  };

  String get match => switch (locale) {
    AppLocale.en => 'Match',
    AppLocale.zhHant => '對局',
  };

  String get coach => switch (locale) {
    AppLocale.en => 'Coach',
    AppLocale.zhHant => '教練',
  };

  String get llm => 'LLM';

  String get options => switch (locale) {
    AppLocale.en => 'Options',
    AppLocale.zhHant => '選項',
  };

  String get play => switch (locale) {
    AppLocale.en => 'Play',
    AppLocale.zhHant => '開始',
  };

  String get restart => switch (locale) {
    AppLocale.en => 'Restart',
    AppLocale.zhHant => '重新開始',
  };

  String get thinking => switch (locale) {
    AppLocale.en => 'Thinking...',
    AppLocale.zhHant => '思考中...',
  };

  String get matchSetup => switch (locale) {
    AppLocale.en => 'Match Setup',
    AppLocale.zhHant => '對局設定',
  };

  String get difficulty => switch (locale) {
    AppLocale.en => 'Difficulty',
    AppLocale.zhHant => '難度',
  };

  String get opponentStrength => switch (locale) {
    AppLocale.en => 'Opponent Strength',
    AppLocale.zhHant => '對手強度',
  };

  String get teacherStrength => switch (locale) {
    AppLocale.en => 'Teacher Depth',
    AppLocale.zhHant => '老師深度',
  };

  String get engineResources => switch (locale) {
    AppLocale.en => 'Engine Resources',
    AppLocale.zhHant => '引擎資源',
  };

  String get autoDetectHardware => switch (locale) {
    AppLocale.en => 'Auto detect CPU and memory',
    AppLocale.zhHant => '自動偵測 CPU 與記憶體',
  };

  String get detectedHardware => switch (locale) {
    AppLocale.en => 'Detected',
    AppLocale.zhHant => '偵測結果',
  };

  String get timeControl => switch (locale) {
    AppLocale.en => 'Time Control',
    AppLocale.zhHant => '棋鐘',
  };

  String get flagFall => switch (locale) {
    AppLocale.en => 'Time is up.',
    AppLocale.zhHant => '時間到。',
  };

  String get boardTheme => switch (locale) {
    AppLocale.en => 'Board Theme',
    AppLocale.zhHant => '棋盤主題',
  };

  String get featuredThemes => switch (locale) {
    AppLocale.en => 'Featured themes',
    AppLocale.zhHant => '精選主題',
  };

  String get allThemes => switch (locale) {
    AppLocale.en => 'All themes',
    AppLocale.zhHant => '全部主題',
  };

  String get backdropOnly => switch (locale) {
    AppLocale.en => 'Backdrop only',
    AppLocale.zhHant => '只有背景',
  };

  String get language => switch (locale) {
    AppLocale.en => 'Language',
    AppLocale.zhHant => '語言',
  };

  String get yourSide => switch (locale) {
    AppLocale.en => 'Your Side',
    AppLocale.zhHant => '你的棋色',
  };

  String get hints => switch (locale) {
    AppLocale.en => 'Hints',
    AppLocale.zhHant => '提示',
  };

  String get candidateLineCount => switch (locale) {
    AppLocale.en => 'Candidate Lines',
    AppLocale.zhHant => '候選路線數',
  };

  String get aiPanelSize => switch (locale) {
    AppLocale.en => 'Theme Settings',
    AppLocale.zhHant => '主題設定',
  };

  String get appTextSize => switch (locale) {
    AppLocale.en => 'App Text Size',
    AppLocale.zhHant => 'App 文字大小',
  };

  String appTextSizeValue(int percent) => switch (locale) {
    AppLocale.en => '$percent%',
    AppLocale.zhHant => '$percent%',
  };

  String get aiPanelExpanded => switch (locale) {
    AppLocale.en => 'Open enlarged AI panel',
    AppLocale.zhHant => '開啟放大 AI 視窗',
  };

  String candidateLineCountValue(int count) => switch (locale) {
    AppLocale.en => '$count lines',
    AppLocale.zhHant => '$count 條',
  };

  String get moveCount => switch (locale) {
    AppLocale.en => 'Move count',
    AppLocale.zhHant => '步數',
  };

  String get lastMove => switch (locale) {
    AppLocale.en => 'Last move',
    AppLocale.zhHant => '上一步',
  };

  String get status => switch (locale) {
    AppLocale.en => 'Status',
    AppLocale.zhHant => '狀態',
  };

  String get rematch => switch (locale) {
    AppLocale.en => 'Rematch',
    AppLocale.zhHant => '重開',
  };

  String get undoMove => switch (locale) {
    AppLocale.en => 'Undo turn',
    AppLocale.zhHant => '回退一步',
  };

  String get redoMove => switch (locale) {
    AppLocale.en => 'Redo turn',
    AppLocale.zhHant => '往前一步',
  };

  String get close => switch (locale) {
    AppLocale.en => 'Close',
    AppLocale.zhHant => '關閉',
  };

  String get guest => switch (locale) {
    AppLocale.en => 'Guest',
    AppLocale.zhHant => '玩家',
  };

  String get you => switch (locale) {
    AppLocale.en => 'You',
    AppLocale.zhHant => '你',
  };

  String get switchSide => switch (locale) {
    AppLocale.en => 'Switch side',
    AppLocale.zhHant => '切換棋色',
  };

  String get toggleHints => switch (locale) {
    AppLocale.en => 'Toggle hints',
    AppLocale.zhHant => '切換提示',
  };

  String get aiLabel => switch (locale) {
    AppLocale.en => 'AI',
    AppLocale.zhHant => 'AI',
  };

  String get style => switch (locale) {
    AppLocale.en => 'Style',
    AppLocale.zhHant => '風格',
  };

  String get specialty => switch (locale) {
    AppLocale.en => 'Specialty',
    AppLocale.zhHant => '擅長',
  };

  String botCount(int count) => switch (locale) {
    AppLocale.en => '$count bots',
    AppLocale.zhHant => '$count 位對手',
  };

  String get think => switch (locale) {
    AppLocale.en => 'Think',
    AppLocale.zhHant => '思考',
  };

  String get threads => switch (locale) {
    AppLocale.en => 'Threads',
    AppLocale.zhHant => '執行緒',
  };

  String get hash => switch (locale) {
    AppLocale.en => 'Hash',
    AppLocale.zhHant => '快取',
  };

  String get coachFeed => switch (locale) {
    AppLocale.en => 'Coach Feed',
    AppLocale.zhHant => '教練回饋',
  };

  String get liveReview => switch (locale) {
    AppLocale.en => 'Live Review',
    AppLocale.zhHant => '即時覆盤',
  };

  String get winChance => switch (locale) {
    AppLocale.en => 'Win chance',
    AppLocale.zhHant => '勝率',
  };

  String get white => switch (locale) {
    AppLocale.en => 'White',
    AppLocale.zhHant => '白方',
  };

  String get black => switch (locale) {
    AppLocale.en => 'Black',
    AppLocale.zhHant => '黑方',
  };

  String get playedMove => switch (locale) {
    AppLocale.en => 'Played',
    AppLocale.zhHant => '本步',
  };

  String get bestWas => switch (locale) {
    AppLocale.en => 'Best was',
    AppLocale.zhHant => '最佳原本是',
  };

  String get cpLoss => switch (locale) {
    AppLocale.en => 'CP loss',
    AppLocale.zhHant => '分數損失',
  };

  String get beforeAfter => switch (locale) {
    AppLocale.en => 'Before / after',
    AppLocale.zhHant => '前後評估',
  };

  String get waitingForMoveReview => switch (locale) {
    AppLocale.en => 'Make a move to see win chance and move quality.',
    AppLocale.zhHant => '走一步後會顯示勝率與本步品質。',
  };

  String get bestMove => switch (locale) {
    AppLocale.en => 'Best move',
    AppLocale.zhHant => '最佳步',
  };

  String get reviewedMoves => switch (locale) {
    AppLocale.en => 'Reviewed',
    AppLocale.zhHant => '已覆盤',
  };

  String get goodMoves => switch (locale) {
    AppLocale.en => 'Good moves',
    AppLocale.zhHant => '好棋',
  };

  String get problemMoves => switch (locale) {
    AppLocale.en => 'Problem moves',
    AppLocale.zhHant => '問題手',
  };

  String get mistakes => switch (locale) {
    AppLocale.en => 'Mistakes',
    AppLocale.zhHant => '失誤',
  };

  String get missedChances => switch (locale) {
    AppLocale.en => 'Missed chances',
    AppLocale.zhHant => '漏失機會',
  };

  String get criticalMistakes => switch (locale) {
    AppLocale.en => 'Critical mistakes',
    AppLocale.zhHant => '嚴重失誤',
  };

  String get averageCpLoss => switch (locale) {
    AppLocale.en => 'Avg CP',
    AppLocale.zhHant => '平均損失',
  };

  String get averagePace => switch (locale) {
    AppLocale.en => 'Avg pace',
    AppLocale.zhHant => '平均步速',
  };

  String get lastPace => switch (locale) {
    AppLocale.en => 'Last pace',
    AppLocale.zhHant => '上步時間',
  };

  String get cpUnit => switch (locale) {
    AppLocale.en => 'CP',
    AppLocale.zhHant => '分',
  };
  String get bestLine => switch (locale) {
    AppLocale.en => 'Best line',
    AppLocale.zhHant => '最佳路線',
  };

  String get nextBestLine => switch (locale) {
    AppLocale.en => 'Next best',
    AppLocale.zhHant => '次佳路線',
  };

  String candidateLineRank(int rank) => switch (locale) {
    AppLocale.en => 'Candidate #$rank',
    AppLocale.zhHant => '候選 #$rank',
  };

  String get evaluation => switch (locale) {
    AppLocale.en => 'Evaluation',
    AppLocale.zhHant => '局勢評估',
  };

  String get depth => switch (locale) {
    AppLocale.en => 'Depth',
    AppLocale.zhHant => '深度',
  };

  String get time => switch (locale) {
    AppLocale.en => 'Time',
    AppLocale.zhHant => '時間',
  };

  String get personality => switch (locale) {
    AppLocale.en => 'Personality',
    AppLocale.zhHant => '個性',
  };

  String get current => switch (locale) {
    AppLocale.en => 'Current',
    AppLocale.zhHant => '目前',
  };

  String get personalityDescription => switch (locale) {
    AppLocale.en =>
      'Pick an opponent mood that fits the character and changes the match vibe.',
    AppLocale.zhHant => '選擇和角色搭配的對手人格，讓整盤對局氣質更清楚。',
  };

  String get opponentAttitude => switch (locale) {
    AppLocale.en => 'Opponent Role',
    AppLocale.zhHant => '對手角色',
  };

  String get teacherVoice => switch (locale) {
    AppLocale.en => 'Teacher Role',
    AppLocale.zhHant => '老師角色',
  };

  String get tauntLevel => switch (locale) {
    AppLocale.en => 'Taunt Level',
    AppLocale.zhHant => '嘲諷強度',
  };

  String get llmRoles => switch (locale) {
    AppLocale.en => 'LLM Roles',
    AppLocale.zhHant => 'LLM 角色',
  };

  String get enableLlmVoices => switch (locale) {
    AppLocale.en => 'Enable LLM voices',
    AppLocale.zhHant => '啟用 LLM 對話',
  };

  String get llmVoicesDescription => switch (locale) {
    AppLocale.en => 'Opponent banter and teacher hints use separate roles.',
    AppLocale.zhHant => '對手嘴砲與老師提示會使用不同角色。',
  };

  String get provider => switch (locale) {
    AppLocale.en => 'Provider',
    AppLocale.zhHant => '服務商',
  };

  String get providerPreset => switch (locale) {
    AppLocale.en => 'Provider Preset',
    AppLocale.zhHant => '服務商預設',
  };

  String get providerName => switch (locale) {
    AppLocale.en => 'Provider Name',
    AppLocale.zhHant => '服務名稱',
  };

  String get providerSettingsDescription => switch (locale) {
    AppLocale.en =>
      'Choose a preset first, then adjust the base URL or model if needed.',
    AppLocale.zhHant => '先選服務商預設，再視需要調整 Base URL 或模型。',
  };

  String get baseUrl => switch (locale) {
    AppLocale.en => 'Base URL',
    AppLocale.zhHant => 'Base URL',
  };

  String get model => switch (locale) {
    AppLocale.en => 'Model',
    AppLocale.zhHant => '模型',
  };

  String get availableModels => switch (locale) {
    AppLocale.en => 'Available Models',
    AppLocale.zhHant => '可用模型',
  };

  String get apiKey => switch (locale) {
    AppLocale.en => 'API Key',
    AppLocale.zhHant => 'API Key',
  };

  String apiKeyHint(String envName) => switch (locale) {
    AppLocale.en => 'Common env var: $envName',
    AppLocale.zhHant => '常用環境變數：$envName',
  };

  String get test => switch (locale) {
    AppLocale.en => 'Test',
    AppLocale.zhHant => '測試',
  };

  String get fetchModels => switch (locale) {
    AppLocale.en => 'Fetch models',
    AppLocale.zhHant => '取得模型',
  };

  String get resetLlm => switch (locale) {
    AppLocale.en => 'Reset',
    AppLocale.zhHant => '還原',
  };

  String get resetPreferences => switch (locale) {
    AppLocale.en => 'Reset match settings',
    AppLocale.zhHant => '還原對局設定',
  };

  String get llmSettingsReset => switch (locale) {
    AppLocale.en => 'LLM settings restored to defaults.',
    AppLocale.zhHant => 'LLM 設定已還原為預設值。',
  };

  String get preferencesReset => switch (locale) {
    AppLocale.en => 'Match settings restored. LLM settings were kept.',
    AppLocale.zhHant => '對局設定已還原，LLM 設定會保留。',
  };

  String get fallback => switch (locale) {
    AppLocale.en => 'Fallback',
    AppLocale.zhHant => '備援',
  };

  String get llmUsageStats => switch (locale) {
    AppLocale.en => 'LLM Usage',
    AppLocale.zhHant => 'LLM 用量',
  };

  String get llmRequests => switch (locale) {
    AppLocale.en => 'Requests',
    AppLocale.zhHant => '請求',
  };

  String get llmTokens => switch (locale) {
    AppLocale.en => 'Tokens',
    AppLocale.zhHant => 'Token',
  };

  String get llmLatency => switch (locale) {
    AppLocale.en => 'Latency',
    AppLocale.zhHant => '延遲',
  };

  String get llmSuccessfulRequests => switch (locale) {
    AppLocale.en => 'Success',
    AppLocale.zhHant => '成功',
  };

  String get llmFailedRequests => switch (locale) {
    AppLocale.en => 'Failed',
    AppLocale.zhHant => '失敗',
  };

  String get llmTotalTokens => switch (locale) {
    AppLocale.en => 'Total',
    AppLocale.zhHant => '總量',
  };

  String get llmPromptTokens => switch (locale) {
    AppLocale.en => 'Prompt',
    AppLocale.zhHant => '提示',
  };

  String get llmOutputTokens => switch (locale) {
    AppLocale.en => 'Output',
    AppLocale.zhHant => '輸出',
  };

  String get llmLastResponse => switch (locale) {
    AppLocale.en => 'Last response',
    AppLocale.zhHant => '上次回應',
  };

  String get resetLlmUsageStats => switch (locale) {
    AppLocale.en => 'Reset LLM usage counters',
    AppLocale.zhHant => '重置 LLM 用量統計',
  };

  String get llmIdleBanter => switch (locale) {
    AppLocale.en => 'Idle Banter',
    AppLocale.zhHant => '閒置對話',
  };

  String get enableIdleBanter => switch (locale) {
    AppLocale.en => 'Random idle lines',
    AppLocale.zhHant => '隨機閒置發話',
  };

  String get idleBanterDescription => switch (locale) {
    AppLocale.en =>
      'When no move is happening, occasionally ask the opponent or teacher to speak.',
    AppLocale.zhHant => '沒有走棋時，偶爾讓對手或老師用 LLM 發話。',
  };

  String get minSeconds => switch (locale) {
    AppLocale.en => 'Min seconds',
    AppLocale.zhHant => '最短秒數',
  };

  String get maxSeconds => switch (locale) {
    AppLocale.en => 'Max seconds',
    AppLocale.zhHant => '最長秒數',
  };

  String get disabled => switch (locale) {
    AppLocale.en => 'Disabled',
    AppLocale.zhHant => '未啟用',
  };

  String get llmUsingLiveModel => switch (locale) {
    AppLocale.en => 'Using live model output.',
    AppLocale.zhHant => '目前使用即時模型輸出。',
  };

  String get llmDisabledNotice => switch (locale) {
    AppLocale.en => 'LLM voice is disabled in settings.',
    AppLocale.zhHant => 'LLM 對話目前在設定中已關閉。',
  };

  String llmSourceLabel(String speaker, String source) => switch (locale) {
    AppLocale.en => '$speaker · $source',
    AppLocale.zhHant => '$speaker・$source',
  };

  String llmFallbackReason(Object error) => switch (locale) {
    AppLocale.en => 'LLM fallback reason: $error',
    AppLocale.zhHant => 'LLM 已改用備援：$error',
  };

  String get llmOpeningFailed => switch (locale) {
    AppLocale.en => 'Opening voice fell back to local lines.',
    AppLocale.zhHant => '開局對話已改用本地備援台詞。',
  };

  String get llmCommentaryFailed => switch (locale) {
    AppLocale.en => 'Live commentary fell back to local lines.',
    AppLocale.zhHant => '即時對話已改用本地備援台詞。',
  };

  String get llmCoachFailed => switch (locale) {
    AppLocale.en => 'Teacher voice fell back to local hints.',
    AppLocale.zhHant => '老師對話已改用本地備援提示。',
  };

  String get fallbackDescription => switch (locale) {
    AppLocale.en =>
      'Gameplay stays local with Stockfish. If the text layer fails, banter and recap fall back to template lines so the match never stalls.',
    AppLocale.zhHant => '棋局仍由本機 Stockfish 執行。文字層失敗時會改用內建台詞，對局不會因此卡住。',
  };

  String get preparingMatch => switch (locale) {
    AppLocale.en => 'Preparing match...',
    AppLocale.zhHant => '正在準備對局...',
  };

  String get defaultOpponentMessage => switch (locale) {
    AppLocale.en => 'Let us play chess.',
    AppLocale.zhHant => '來下一盤西洋棋吧。',
  };

  String get defaultCoachMessage => switch (locale) {
    AppLocale.en => 'I will watch the board and point out useful ideas.',
    AppLocale.zhHant => '我會觀察棋盤，提醒你有用的思路。',
  };

  String get illegalMoveRejected => switch (locale) {
    AppLocale.en => 'Illegal move rejected.',
    AppLocale.zhHant => '非法走法已拒絕。',
  };

  String get aiThinking => switch (locale) {
    AppLocale.en => 'AI is thinking...',
    AppLocale.zhHant => 'AI 正在思考...',
  };

  String get coachThinking => switch (locale) {
    AppLocale.en => 'Teacher is analyzing...',
    AppLocale.zhHant => '老師正在分析...',
  };

  String get playerInCheck => switch (locale) {
    AppLocale.en => 'You are in check. Defend your king first.',
    AppLocale.zhHant => '你被將軍了，必須先解將。',
  };

  String get aiInCheck => switch (locale) {
    AppLocale.en => 'AI is in check.',
    AppLocale.zhHant => '對手被將軍。',
  };

  String get aiMoveFailed => switch (locale) {
    AppLocale.en => 'AI move failed.',
    AppLocale.zhHant => 'AI 走棋失敗。',
  };

  String get fallbackMoveUsed => switch (locale) {
    AppLocale.en => 'Stockfish unavailable, used fallback move.',
    AppLocale.zhHant => 'Stockfish 暫時不可用，已使用備援走法。',
  };

  String hintAnalysisFailed(Object error) => switch (locale) {
    AppLocale.en => 'Hint analysis failed: $error',
    AppLocale.zhHant => '提示分析失敗：$error',
  };

  String llmTestingConnection() => switch (locale) {
    AppLocale.en => 'Testing LLM connection...',
    AppLocale.zhHant => '正在測試 LLM 連線...',
  };

  String llmConnectionReady() => switch (locale) {
    AppLocale.en => 'LLM connection is ready.',
    AppLocale.zhHant => 'LLM 連線可用。',
  };

  String llmTestFailed(Object error) => switch (locale) {
    AppLocale.en => 'LLM test failed: $error',
    AppLocale.zhHant => 'LLM 測試失敗：$error',
  };

  String get fetchingModels => switch (locale) {
    AppLocale.en => 'Fetching models...',
    AppLocale.zhHant => '正在取得模型...',
  };

  String get noModelsReturned => switch (locale) {
    AppLocale.en => 'No models returned.',
    AppLocale.zhHant => '沒有取得任何模型。',
  };

  String loadedModels(int count) => switch (locale) {
    AppLocale.en => 'Loaded $count models.',
    AppLocale.zhHant => '已載入 $count 個模型。',
  };

  String fetchModelsFailed(Object error) => switch (locale) {
    AppLocale.en => 'Fetch models failed: $error',
    AppLocale.zhHant => '取得模型失敗：$error',
  };

  String get llmVoiceEnabled => switch (locale) {
    AppLocale.en => 'LLM voice enabled. I will make this board feel alive.',
    AppLocale.zhHant => 'LLM 對話已啟用。我會讓這盤棋更有臨場感。',
  };

  String get teacherChannelReady => switch (locale) {
    AppLocale.en =>
      'Teacher channel ready. I will separate advice from trash talk.',
    AppLocale.zhHant => '老師頻道已就緒。我會把建議和嘴砲分開。',
  };

  String get gameOverDraw => switch (locale) {
    AppLocale.en => 'Game over: draw.',
    AppLocale.zhHant => '對局結束：和棋。',
  };

  String get gameOverYouWin => switch (locale) {
    AppLocale.en => 'Game over: you win.',
    AppLocale.zhHant => '對局結束：你贏了。',
  };

  String get gameOverAiWins => switch (locale) {
    AppLocale.en => 'Game over: AI wins.',
    AppLocale.zhHant => '對局結束：AI 獲勝。',
  };

  String get resultWinTitle => switch (locale) {
    AppLocale.en => 'Victory',
    AppLocale.zhHant => '你贏了',
  };

  String get resultLoseTitle => switch (locale) {
    AppLocale.en => 'Defeat',
    AppLocale.zhHant => '你輸了',
  };

  String get resultLoseFlash => switch (locale) {
    AppLocale.en => 'DEFEAT',
    AppLocale.zhHant => '失敗',
  };

  String get resultDrawTitle => switch (locale) {
    AppLocale.en => 'Draw',
    AppLocale.zhHant => '和棋',
  };

  String get resultWinSubtitle => switch (locale) {
    AppLocale.en => 'You converted the position cleanly.',
    AppLocale.zhHant => '你順利把優勢轉成勝利。',
  };

  String get resultLoseSubtitle => switch (locale) {
    AppLocale.en => 'The opponent closed the game out first.',
    AppLocale.zhHant => '對手先把這盤收掉了。',
  };

  String get resultDrawSubtitle => switch (locale) {
    AppLocale.en => 'Neither side found a full breakthrough.',
    AppLocale.zhHant => '雙方都沒有找到最後的突破口。',
  };

  String get resultWinOnTimeSubtitle => switch (locale) {
    AppLocale.en => 'You won on time.',
    AppLocale.zhHant => '你靠時間獲勝。',
  };

  String get resultLoseOnTimeSubtitle => switch (locale) {
    AppLocale.en => 'You lost on time.',
    AppLocale.zhHant => '你超時落敗。',
  };

  String yourTurn(String side) => switch (locale) {
    AppLocale.en => 'Your turn ($side).',
    AppLocale.zhHant => '輪到你走（$side）。',
  };

  String aiToMove(String side) => switch (locale) {
    AppLocale.en => 'AI to move ($side).',
    AppLocale.zhHant => 'AI 走棋（$side）。',
  };

  String sideName(String side) => switch (locale) {
    AppLocale.en => side,
    AppLocale.zhHant => switch (side) {
      'white' => '白方',
      'black' => '黑方',
      _ => side,
    },
  };

  String get languageInstruction => switch (locale) {
    AppLocale.en => 'Reply in English.',
    AppLocale.zhHant => '請一律使用繁體中文回覆。',
  };
}
