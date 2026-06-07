import 'dart:math' as math;

import 'package:chess_ai_desktop/src/chess/chess.dart';

import 'engine_models.dart';
import '../i18n/app_localizations.dart';
import '../theme/board_theme.dart';

enum DifficultyLevel {
  easy,
  normal,
  hard,
  master,
  chaos;

  String get label => switch (this) {
    DifficultyLevel.easy => 'Easy',
    DifficultyLevel.normal => 'Normal',
    DifficultyLevel.hard => 'Hard',
    DifficultyLevel.master => 'Master',
    DifficultyLevel.chaos => 'Chaos',
  };

  String localizedLabel(AppStrings strings) => switch (strings.locale) {
    AppLocale.en => label,
    AppLocale.zhHant => switch (this) {
      DifficultyLevel.easy => '簡單',
      DifficultyLevel.normal => '普通',
      DifficultyLevel.hard => '困難',
      DifficultyLevel.master => '大師',
      DifficultyLevel.chaos => '混沌',
    },
  };

  String get description => switch (this) {
    DifficultyLevel.easy => 'Quick replies and forgiving strength.',
    DifficultyLevel.normal => 'Good casual desktop play.',
    DifficultyLevel.hard => 'Longer calculation and stronger tactics.',
    DifficultyLevel.master => 'Competitive strength with deeper search.',
    DifficultyLevel.chaos => 'Maximum pressure for local play.',
  };

  String localizedDescription(AppStrings strings) => switch (strings.locale) {
    AppLocale.en => description,
    AppLocale.zhHant => switch (this) {
      DifficultyLevel.easy => '反應快速，強度寬容，適合暖身。',
      DifficultyLevel.normal => '適合日常桌面對戰的均衡強度。',
      DifficultyLevel.hard => '計算更久，戰術壓力更強。',
      DifficultyLevel.master => '更深層搜尋，接近競技強度。',
      DifficultyLevel.chaos => '本機對戰的最大壓力模式。',
    },
  };

  EngineSettings get engineSettings => switch (this) {
    DifficultyLevel.easy => const EngineSettings(
      moveTimeMs: 250,
      skillLevel: 4,
      limitStrength: true,
      elo: 1200,
      multiPv: 1,
      hashMb: 32,
      threads: 1,
    ),
    DifficultyLevel.normal => const EngineSettings(
      moveTimeMs: 600,
      skillLevel: 8,
      limitStrength: true,
      elo: 1600,
      multiPv: 1,
      hashMb: 64,
      threads: 1,
    ),
    DifficultyLevel.hard => const EngineSettings(
      moveTimeMs: 1200,
      skillLevel: 12,
      limitStrength: true,
      elo: 2100,
      multiPv: 1,
      hashMb: 128,
      threads: 2,
    ),
    DifficultyLevel.master => const EngineSettings(
      moveTimeMs: 2200,
      skillLevel: 16,
      limitStrength: true,
      elo: 2600,
      multiPv: 1,
      hashMb: 192,
      threads: 3,
    ),
    DifficultyLevel.chaos => const EngineSettings(
      moveTimeMs: 3200,
      skillLevel: 20,
      limitStrength: true,
      elo: 3200,
      multiPv: 1,
      hashMb: 256,
      threads: 4,
    ),
  };
}

enum SearchDepthLevel {
  quick,
  balanced,
  deep,
  tournament,
  maximum;

  String get label => switch (this) {
    SearchDepthLevel.quick => 'Quick',
    SearchDepthLevel.balanced => 'Balanced',
    SearchDepthLevel.deep => 'Deep',
    SearchDepthLevel.tournament => 'Tournament',
    SearchDepthLevel.maximum => 'Maximum',
  };

  String localizedLabel(AppStrings strings) => switch (strings.locale) {
    AppLocale.en => label,
    AppLocale.zhHant => switch (this) {
      SearchDepthLevel.quick => '快速',
      SearchDepthLevel.balanced => '均衡',
      SearchDepthLevel.deep => '深入',
      SearchDepthLevel.tournament => '競賽',
      SearchDepthLevel.maximum => '最大',
    },
  };

  String localizedDescription(AppStrings strings) => switch (strings.locale) {
    AppLocale.en => switch (this) {
      SearchDepthLevel.quick => 'Fast response, shallow search.',
      SearchDepthLevel.balanced => 'Good speed and tactical awareness.',
      SearchDepthLevel.deep => 'Stronger calculation for serious games.',
      SearchDepthLevel.tournament => 'Slow, stable, and demanding.',
      SearchDepthLevel.maximum => 'Very deep search for powerful machines.',
    },
    AppLocale.zhHant => switch (this) {
      SearchDepthLevel.quick => '反應快，搜尋較淺。',
      SearchDepthLevel.balanced => '速度與戰術判斷較均衡。',
      SearchDepthLevel.deep => '計算更強，適合認真對局。',
      SearchDepthLevel.tournament => '較慢但穩定，壓力更高。',
      SearchDepthLevel.maximum => '非常深，適合高效能電腦。',
    },
  };

  int get opponentDepth => switch (this) {
    SearchDepthLevel.quick => 8,
    SearchDepthLevel.balanced => 10,
    SearchDepthLevel.deep => 12,
    SearchDepthLevel.tournament => 14,
    SearchDepthLevel.maximum => 16,
  };

  int get teacherDepth => switch (this) {
    SearchDepthLevel.quick => 10,
    SearchDepthLevel.balanced => 14,
    SearchDepthLevel.deep => 18,
    SearchDepthLevel.tournament => 24,
    SearchDepthLevel.maximum => 28,
  };
}

class EngineResourceSettings {
  const EngineResourceSettings({
    required this.auto,
    required this.threads,
    required this.hashMb,
  });

  factory EngineResourceSettings.defaults() {
    return const EngineResourceSettings(auto: true, threads: 1, hashMb: 64);
  }

  final bool auto;
  final int threads;
  final int hashMb;

  EngineResourceSettings copyWith({bool? auto, int? threads, int? hashMb}) {
    return EngineResourceSettings(
      auto: auto ?? this.auto,
      threads: threads ?? this.threads,
      hashMb: hashMb ?? this.hashMb,
    );
  }

  factory EngineResourceSettings.fromJson(Map<String, Object?> json) {
    final defaults = EngineResourceSettings.defaults();
    return defaults.copyWith(
      auto: json['auto'] is bool ? json['auto'] as bool : defaults.auto,
      threads: _clampInt(json['threads'], defaults.threads, 1, 32),
      hashMb: _clampInt(json['hashMb'], defaults.hashMb, 16, 4096),
    );
  }

  Map<String, Object?> toJson() {
    return {'auto': auto, 'threads': threads, 'hashMb': hashMb};
  }
}

int _clampInt(Object? value, int fallback, int min, int max) {
  final parsed = switch (value) {
    final int number => number,
    final String text => int.tryParse(text),
    _ => null,
  };
  return (parsed ?? fallback).clamp(min, max);
}

int _intFromJson(Object? value, int fallback, {int? min, int? max}) {
  final parsed = switch (value) {
    final int number => number,
    final String text => int.tryParse(text),
    _ => null,
  };
  final resolved = parsed ?? fallback;
  if (min != null && resolved < min) {
    return min;
  }
  if (max != null && resolved > max) {
    return max;
  }
  return resolved;
}

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  if (name is! String) {
    return fallback;
  }
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return fallback;
}

enum HintMode {
  off,
  bestMove,
  candidateLines;

  String get label => switch (this) {
    HintMode.off => 'Off',
    HintMode.bestMove => 'Best Move',
    HintMode.candidateLines => 'Candidate Lines',
  };

  String localizedLabel(AppStrings strings) => switch (strings.locale) {
    AppLocale.en => label,
    AppLocale.zhHant => switch (this) {
      HintMode.off => '關閉',
      HintMode.bestMove => '最佳步',
      HintMode.candidateLines => '候選路線',
    },
  };
}

enum TimeControl {
  unlimited,
  bullet1,
  blitz3,
  blitz5,
  rapid10;

  int? get secondsPerSide => switch (this) {
    TimeControl.unlimited => null,
    TimeControl.bullet1 => 60,
    TimeControl.blitz3 => 180,
    TimeControl.blitz5 => 300,
    TimeControl.rapid10 => 600,
  };

  String localizedLabel(AppStrings strings) => switch (strings.locale) {
    AppLocale.en => switch (this) {
      TimeControl.unlimited => 'Unlimited',
      TimeControl.bullet1 => '1 minute',
      TimeControl.blitz3 => '3 minutes',
      TimeControl.blitz5 => '5 minutes',
      TimeControl.rapid10 => '10 minutes',
    },
    AppLocale.zhHant => switch (this) {
      TimeControl.unlimited => '不限時',
      TimeControl.bullet1 => '1 分鐘',
      TimeControl.blitz3 => '3 分鐘',
      TimeControl.blitz5 => '5 分鐘',
      TimeControl.rapid10 => '10 分鐘',
    },
  };
}

enum Persona {
  coldMaster,
  trashTalker,
  coach,
  gentleman,
  trickster,
  speedDemon,
  endgameGrinder,
  royalVillain;

  String get label => switch (this) {
    Persona.coldMaster => 'Cold Master',
    Persona.trashTalker => 'Trash Talker',
    Persona.coach => 'Coach',
    Persona.gentleman => 'Gentleman Rival',
    Persona.trickster => 'Trickster',
    Persona.speedDemon => 'Speed Demon',
    Persona.endgameGrinder => 'Endgame Grinder',
    Persona.royalVillain => 'Royal Villain',
  };

  String localizedLabel(AppStrings strings) => switch (strings.locale) {
    AppLocale.en => label,
    AppLocale.zhHant => switch (this) {
      Persona.coldMaster => '冷酷大師',
      Persona.trashTalker => '嘴砲對手',
      Persona.coach => '陪練教練',
      Persona.gentleman => '紳士勁敵',
      Persona.trickster => '陷阱魔術師',
      Persona.speedDemon => '快棋惡魔',
      Persona.endgameGrinder => '殘局磨王',
      Persona.royalVillain => '王室反派',
    },
  };

  String localizedDescription(AppStrings strings) => switch (strings.locale) {
    AppLocale.en => switch (this) {
      Persona.coldMaster =>
        'Precise pressure, clean threats, and almost no wasted words.',
      Persona.trashTalker =>
        'Playful banter, direct challenge, and lively table talk.',
      Persona.coach =>
        'Sparring-partner energy that hints at plans while still competing.',
      Persona.gentleman =>
        'Respectful, poised, and quietly confident match-room vibes.',
      Persona.trickster =>
        'Trap-setting, feints, and ambiguous pressure around the board.',
      Persona.speedDemon =>
        'Fast tempo, sharp pressure, and impatient attacking energy.',
      Persona.endgameGrinder =>
        'Small edges, technical squeeze, and relentless conversion pressure.',
      Persona.royalVillain =>
        'Grand, theatrical, elegant, and slightly intimidating presence.',
    },
    AppLocale.zhHant => switch (this) {
      Persona.coldMaster => '精準施壓、威脅乾淨、話少但壓迫感很重。',
      Persona.trashTalker => '會嘴砲、挑釁感強，對局氣氛更熱鬧。',
      Persona.coach => '像陪練一樣會點出計畫，但本質上仍是對手。',
      Persona.gentleman => '尊重對手、沉著自信，偏正式比賽感。',
      Persona.trickster => '喜歡陷阱、假動作與模糊威脅的風格。',
      Persona.speedDemon => '節奏很快、攻擊銳利，會逼你快做決定。',
      Persona.endgameGrinder => '擅長磨小優勢，用技術慢慢把你壓垮。',
      Persona.royalVillain => '戲劇化、優雅又有壓迫感，像 Boss 戰。',
    },
  };
}

enum CoachPersona {
  kirinKing,
  tacticalTeacher,
  calmMentor,
  openingArchivist,
  endgameSensei,
  blunderDetective,
  attackCommander;

  String get label => switch (this) {
    CoachPersona.kirinKing => 'Chess Spirit King',
    CoachPersona.tacticalTeacher => 'Tactical Teacher',
    CoachPersona.calmMentor => 'Calm Mentor',
    CoachPersona.openingArchivist => 'Opening Archivist',
    CoachPersona.endgameSensei => 'Endgame Sensei',
    CoachPersona.blunderDetective => 'Blunder Detective',
    CoachPersona.attackCommander => 'Attack Commander',
  };

  String localizedLabel(AppStrings strings) => switch (strings.locale) {
    AppLocale.en => label,
    AppLocale.zhHant => switch (this) {
      CoachPersona.kirinKing => '棋靈王',
      CoachPersona.tacticalTeacher => '戰術老師',
      CoachPersona.calmMentor => '沉穩導師',
      CoachPersona.openingArchivist => '開局檔案官',
      CoachPersona.endgameSensei => '殘局師範',
      CoachPersona.blunderDetective => '失誤偵探',
      CoachPersona.attackCommander => '攻擊指揮官',
    },
  };

  String get description => switch (this) {
    CoachPersona.kirinKing => 'Mystic, direct, and boss-like chess guidance.',
    CoachPersona.tacticalTeacher => 'Sharp move-by-move tactical coaching.',
    CoachPersona.calmMentor => 'Patient positional guidance for learning.',
    CoachPersona.openingArchivist =>
      'Opening principles, plans, and common traps.',
    CoachPersona.endgameSensei => 'Endgame technique and conversion advice.',
    CoachPersona.blunderDetective =>
      'Blunder prevention with tactical warning signs.',
    CoachPersona.attackCommander =>
      'Attacking plans, initiative, and king pressure.',
  };

  String localizedDescription(AppStrings strings) => switch (strings.locale) {
    AppLocale.en => description,
    AppLocale.zhHant => switch (this) {
      CoachPersona.kirinKing => '棋靈感、直接、有 Boss 感的提示。',
      CoachPersona.tacticalTeacher => '逐步指出戰術與威脅的銳利教練。',
      CoachPersona.calmMentor => '耐心講解局面、計畫與子力協調。',
      CoachPersona.openingArchivist => '講解開局原則、計畫與常見陷阱。',
      CoachPersona.endgameSensei => '專注殘局技術與優勢轉換。',
      CoachPersona.blunderDetective => '提醒失誤徵兆，幫你避開戰術漏洞。',
      CoachPersona.attackCommander => '指揮攻擊計畫、先手與王翼壓力。',
    },
  };
}

enum TauntLevel {
  off,
  light,
  full;

  String get label => switch (this) {
    TauntLevel.off => 'Off',
    TauntLevel.light => 'Light',
    TauntLevel.full => 'Full',
  };

  String localizedLabel(AppStrings strings) => switch (strings.locale) {
    AppLocale.en => label,
    AppLocale.zhHant => switch (this) {
      TauntLevel.off => '關閉',
      TauntLevel.light => '輕度',
      TauntLevel.full => '完整',
    },
  };
}

enum LlmProviderKind {
  openAiCompatible,
  googleGemini,
  kimiCode,
  anthropicClaude,
  customCompatible;

  String localizedLabel(AppStrings strings) => switch (strings.locale) {
    AppLocale.en => switch (this) {
      LlmProviderKind.openAiCompatible => 'OpenAI Compatible',
      LlmProviderKind.googleGemini => 'Google Gemini',
      LlmProviderKind.kimiCode => 'Kimi Code',
      LlmProviderKind.anthropicClaude => 'Anthropic Claude',
      LlmProviderKind.customCompatible => 'Custom Compatible',
    },
    AppLocale.zhHant => switch (this) {
      LlmProviderKind.openAiCompatible => 'OpenAI 相容',
      LlmProviderKind.googleGemini => 'Google Gemini',
      LlmProviderKind.kimiCode => 'Kimi Code',
      LlmProviderKind.anthropicClaude => 'Anthropic Claude',
      LlmProviderKind.customCompatible => '自訂相容服務',
    },
  };

  String localizedDescription(AppStrings strings) => switch (strings.locale) {
    AppLocale.en => switch (this) {
      LlmProviderKind.openAiCompatible =>
        'Use OpenAI-compatible chat and model endpoints.',
      LlmProviderKind.googleGemini =>
        'Gemini through Google\'s OpenAI-compatible endpoint preset.',
      LlmProviderKind.kimiCode =>
        'Kimi coding model through Moonshot AI\'s OpenAI-compatible endpoint.',
      LlmProviderKind.anthropicClaude =>
        'Claude through Anthropic\'s native models and messages APIs.',
      LlmProviderKind.customCompatible =>
        'Bring your own compatible gateway and custom base URL.',
    },
    AppLocale.zhHant => switch (this) {
      LlmProviderKind.openAiCompatible => '使用 OpenAI 相容的聊天與模型端點。',
      LlmProviderKind.googleGemini => '使用 Google 官方 Gemini OpenAI 相容端點預設。',
      LlmProviderKind.kimiCode => '使用 Moonshot AI Kimi Code 的 OpenAI 相容端點預設。',
      LlmProviderKind.anthropicClaude =>
        '使用 Anthropic 官方 Claude models 與 messages API。',
      LlmProviderKind.customCompatible => '自訂相容服務，可手動填寫服務名稱與 Base URL。',
    },
  };

  String get defaultProviderLabel => switch (this) {
    LlmProviderKind.openAiCompatible => 'OpenAI Compatible',
    LlmProviderKind.googleGemini => 'Google Gemini',
    LlmProviderKind.kimiCode => 'Kimi Code',
    LlmProviderKind.anthropicClaude => 'Anthropic Claude',
    LlmProviderKind.customCompatible => 'Custom Gateway',
  };

  String get defaultBaseUrl => switch (this) {
    LlmProviderKind.openAiCompatible => 'https://api.openai.com/v1',
    LlmProviderKind.googleGemini =>
      'https://generativelanguage.googleapis.com/v1beta/openai',
    LlmProviderKind.kimiCode => 'https://api.kimi.com/coding/v1',
    LlmProviderKind.anthropicClaude => 'https://api.anthropic.com/v1',
    LlmProviderKind.customCompatible => 'https://api.openai.com/v1',
  };

  String get defaultModel => switch (this) {
    LlmProviderKind.openAiCompatible => 'GPT-5.4',
    LlmProviderKind.googleGemini => 'gemini-2.5-flash',
    LlmProviderKind.kimiCode => 'kimi-for-coding',
    LlmProviderKind.anthropicClaude => 'claude-sonnet-4-0',
    LlmProviderKind.customCompatible => 'GPT-5.4',
  };

  String get apiKeyHint => switch (this) {
    LlmProviderKind.openAiCompatible => 'OPENAI_API_KEY',
    LlmProviderKind.googleGemini => 'GEMINI_API_KEY',
    LlmProviderKind.kimiCode => 'KIMI_API_KEY',
    LlmProviderKind.anthropicClaude => 'ANTHROPIC_API_KEY',
    LlmProviderKind.customCompatible => 'YOUR_PROVIDER_API_KEY',
  };

  bool get usesAnthropicApi => this == LlmProviderKind.anthropicClaude;

  static LlmProviderKind infer({
    required Object? savedKind,
    required Object? savedProvider,
    required Object? savedBaseUrl,
  }) {
    final explicit = _enumByName(
      LlmProviderKind.values,
      savedKind,
      LlmProviderKind.openAiCompatible,
    );
    if (savedKind is String) {
      return explicit;
    }

    final provider = savedProvider is String ? savedProvider.toLowerCase() : '';
    final baseUrl = savedBaseUrl is String ? savedBaseUrl.toLowerCase() : '';
    if (provider.contains('gemini') || baseUrl.contains('generativelanguage')) {
      return LlmProviderKind.googleGemini;
    }
    if (provider.contains('kimi') ||
        provider.contains('moonshot') ||
        baseUrl.contains('api.kimi.com') ||
        baseUrl.contains('moonshot')) {
      return LlmProviderKind.kimiCode;
    }
    if (provider.contains('claude') ||
        provider.contains('anthropic') ||
        baseUrl.contains('anthropic')) {
      return LlmProviderKind.anthropicClaude;
    }
    if (provider.contains('custom')) {
      return LlmProviderKind.customCompatible;
    }
    return LlmProviderKind.openAiCompatible;
  }
}

enum LlmCredentialMode {
  defaultProxy,
  customApiKey;

  String localizedLabel(AppStrings strings) => switch (strings.locale) {
    AppLocale.en => switch (this) {
      LlmCredentialMode.defaultProxy => 'Use default',
      LlmCredentialMode.customApiKey => 'Enter API key',
    },
    AppLocale.zhHant => switch (this) {
      LlmCredentialMode.defaultProxy => '使用預設',
      LlmCredentialMode.customApiKey => '自行輸入',
    },
  };
}

class LlmSettings {
  static const _defaultEnabled = bool.fromEnvironment(
    'CHESS_AI_DEFAULT_LLM_ENABLED',
  );
  static const _defaultBaseUrl = String.fromEnvironment(
    'CHESS_AI_WEB_LLM_PROXY_BASE_URL',
    defaultValue: 'https://api.openai.com/v1',
  );
  static const _defaultModel = String.fromEnvironment(
    'CHESS_AI_DEFAULT_LLM_MODEL',
    defaultValue: 'GPT-5.4',
  );

  const LlmSettings({
    this.providerKind = LlmProviderKind.openAiCompatible,
    this.enabled = _defaultEnabled,
    this.provider = 'OpenAI Compatible',
    this.baseUrl = _defaultBaseUrl,
    this.model = _defaultModel,
    this.credentialMode = LlmCredentialMode.defaultProxy,
    this.apiKey = '',
    this.idleBanterEnabled = true,
    this.idleBanterMinSeconds = 10,
    this.idleBanterMaxSeconds = 45,
  });

  final LlmProviderKind providerKind;
  final bool enabled;
  final String provider;
  final String baseUrl;
  final String model;
  final LlmCredentialMode credentialMode;
  final String apiKey;
  final bool idleBanterEnabled;
  final int idleBanterMinSeconds;
  final int idleBanterMaxSeconds;

  LlmSettings copyWith({
    LlmProviderKind? providerKind,
    bool? enabled,
    String? provider,
    String? baseUrl,
    String? model,
    LlmCredentialMode? credentialMode,
    String? apiKey,
    bool? idleBanterEnabled,
    int? idleBanterMinSeconds,
    int? idleBanterMaxSeconds,
  }) {
    final minSeconds = idleBanterMinSeconds ?? this.idleBanterMinSeconds;
    final maxSeconds = idleBanterMaxSeconds ?? this.idleBanterMaxSeconds;
    return LlmSettings(
      providerKind: providerKind ?? this.providerKind,
      enabled: enabled ?? this.enabled,
      provider: provider ?? this.provider,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      credentialMode: credentialMode ?? this.credentialMode,
      apiKey: apiKey ?? this.apiKey,
      idleBanterEnabled: idleBanterEnabled ?? this.idleBanterEnabled,
      idleBanterMinSeconds: minSeconds.clamp(5, 600).toInt(),
      idleBanterMaxSeconds: math
          .max(minSeconds, maxSeconds)
          .clamp(5, 900)
          .toInt(),
    );
  }

  factory LlmSettings.fromJson(Map<String, Object?> json) {
    final providerKind = LlmProviderKind.infer(
      savedKind: json['providerKind'],
      savedProvider: json['provider'],
      savedBaseUrl: json['baseUrl'],
    );
    final idleMinSeconds = _clampInt(
      json['idleBanterMinSeconds'],
      const LlmSettings().idleBanterMinSeconds,
      5,
      600,
    );
    final idleMaxSeconds = math.max(
      idleMinSeconds,
      _clampInt(
        json['idleBanterMaxSeconds'],
        const LlmSettings().idleBanterMaxSeconds,
        5,
        900,
      ),
    );
    return LlmSettings(
      providerKind: providerKind,
      enabled: json['enabled'] == true,
      provider: switch (json['provider']) {
        final String value when value.trim().isNotEmpty => value,
        _ => providerKind.defaultProviderLabel,
      },
      baseUrl: switch (json['baseUrl']) {
        final String value when value.trim().isNotEmpty => value,
        _ => providerKind.defaultBaseUrl,
      },
      model: switch (json['model']) {
        final String value when value.trim().isNotEmpty => value,
        _ => providerKind.defaultModel,
      },
      credentialMode: _enumByName(
        LlmCredentialMode.values,
        json['credentialMode'],
        LlmCredentialMode.defaultProxy,
      ),
      apiKey: switch (json['apiKey']) {
        final String value => value,
        _ => const LlmSettings().apiKey,
      },
      idleBanterEnabled: json['idleBanterEnabled'] is bool
          ? json['idleBanterEnabled'] as bool
          : const LlmSettings().idleBanterEnabled,
      idleBanterMinSeconds: idleMinSeconds,
      idleBanterMaxSeconds: idleMaxSeconds,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'providerKind': providerKind.name,
      'enabled': enabled,
      'provider': provider,
      'baseUrl': baseUrl,
      'model': model,
      'credentialMode': credentialMode.name,
      'apiKey': apiKey,
      'idleBanterEnabled': idleBanterEnabled,
      'idleBanterMinSeconds': idleBanterMinSeconds,
      'idleBanterMaxSeconds': idleBanterMaxSeconds,
    };
  }
}

class GameSessionConfig {
  const GameSessionConfig({
    required this.playerSide,
    required this.difficulty,
    required this.hintMode,
    required this.candidateLineCount,
    required this.appTextScalePercent,
    required this.timeControl,
    required this.boardTheme,
    required this.locale,
    required this.botProfileName,
    required this.persona,
    required this.coachPersona,
    required this.tauntLevel,
    required this.opponentDepth,
    required this.teacherDepth,
    required this.engineResources,
    required this.llm,
  });

  factory GameSessionConfig.defaults() {
    return const GameSessionConfig(
      playerSide: Side.white,
      difficulty: DifficultyLevel.normal,
      hintMode: HintMode.bestMove,
      candidateLineCount: 3,
      appTextScalePercent: 100,
      timeControl: TimeControl.unlimited,
      boardTheme: BoardThemeId.classicWood,
      locale: AppLocale.en,
      botProfileName: 'Vanta',
      persona: Persona.trashTalker,
      coachPersona: CoachPersona.kirinKing,
      tauntLevel: TauntLevel.light,
      opponentDepth: SearchDepthLevel.balanced,
      teacherDepth: SearchDepthLevel.deep,
      engineResources: EngineResourceSettings(
        auto: true,
        threads: 1,
        hashMb: 64,
      ),
      llm: LlmSettings(),
    );
  }

  final Side playerSide;
  final DifficultyLevel difficulty;
  final HintMode hintMode;
  final int candidateLineCount;
  final int appTextScalePercent;
  final TimeControl timeControl;
  final BoardThemeId boardTheme;
  final AppLocale locale;
  final String botProfileName;
  final Persona persona;
  final CoachPersona coachPersona;
  final TauntLevel tauntLevel;
  final SearchDepthLevel opponentDepth;
  final SearchDepthLevel teacherDepth;
  final EngineResourceSettings engineResources;
  final LlmSettings llm;

  GameSessionConfig copyWith({
    Side? playerSide,
    DifficultyLevel? difficulty,
    HintMode? hintMode,
    int? candidateLineCount,
    int? appTextScalePercent,
    TimeControl? timeControl,
    BoardThemeId? boardTheme,
    AppLocale? locale,
    String? botProfileName,
    Persona? persona,
    CoachPersona? coachPersona,
    TauntLevel? tauntLevel,
    SearchDepthLevel? opponentDepth,
    SearchDepthLevel? teacherDepth,
    EngineResourceSettings? engineResources,
    LlmSettings? llm,
  }) {
    return GameSessionConfig(
      playerSide: playerSide ?? this.playerSide,
      difficulty: difficulty ?? this.difficulty,
      hintMode: hintMode ?? this.hintMode,
      candidateLineCount: candidateLineCount ?? this.candidateLineCount,
      appTextScalePercent: appTextScalePercent ?? this.appTextScalePercent,
      timeControl: timeControl ?? this.timeControl,
      boardTheme: boardTheme ?? this.boardTheme,
      locale: locale ?? this.locale,
      botProfileName: botProfileName ?? this.botProfileName,
      persona: persona ?? this.persona,
      coachPersona: coachPersona ?? this.coachPersona,
      tauntLevel: tauntLevel ?? this.tauntLevel,
      opponentDepth: opponentDepth ?? this.opponentDepth,
      teacherDepth: teacherDepth ?? this.teacherDepth,
      engineResources: engineResources ?? this.engineResources,
      llm: llm ?? this.llm,
    );
  }

  factory GameSessionConfig.fromPreferencesJson(
    Map<String, Object?> json, {
    required LlmSettings llm,
  }) {
    final defaults = GameSessionConfig.defaults();
    return defaults.copyWith(
      playerSide: _enumByName(
        Side.values,
        json['playerSide'],
        defaults.playerSide,
      ),
      difficulty: _enumByName(
        DifficultyLevel.values,
        json['difficulty'],
        defaults.difficulty,
      ),
      hintMode: _enumByName(
        HintMode.values,
        json['hintMode'],
        defaults.hintMode,
      ),
      candidateLineCount: _intFromJson(
        json['candidateLineCount'],
        defaults.candidateLineCount,
        min: 2,
        max: 5,
      ),
      appTextScalePercent: _intFromJson(
        json['appTextScalePercent'],
        defaults.appTextScalePercent,
        min: 85,
        max: 120,
      ),
      timeControl: _enumByName(
        TimeControl.values,
        json['timeControl'],
        defaults.timeControl,
      ),
      boardTheme: _enumByName(
        BoardThemeId.values,
        json['boardTheme'],
        defaults.boardTheme,
      ),
      locale: _enumByName(AppLocale.values, json['locale'], defaults.locale),
      botProfileName: switch (json['botProfileName']) {
        final String value when value.trim().isNotEmpty => value,
        _ => defaults.botProfileName,
      },
      persona: _enumByName(Persona.values, json['persona'], defaults.persona),
      coachPersona: _enumByName(
        CoachPersona.values,
        json['coachPersona'],
        defaults.coachPersona,
      ),
      tauntLevel: _enumByName(
        TauntLevel.values,
        json['tauntLevel'],
        defaults.tauntLevel,
      ),
      opponentDepth: _enumByName(
        SearchDepthLevel.values,
        json['opponentDepth'],
        defaults.opponentDepth,
      ),
      teacherDepth: _enumByName(
        SearchDepthLevel.values,
        json['teacherDepth'],
        defaults.teacherDepth,
      ),
      engineResources: switch (json['engineResources']) {
        final Map<String, Object?> value => EngineResourceSettings.fromJson(
          value,
        ),
        _ => defaults.engineResources,
      },
      llm: llm,
    );
  }

  Map<String, Object?> toPreferencesJson() {
    return {
      'playerSide': playerSide.name,
      'difficulty': difficulty.name,
      'hintMode': hintMode.name,
      'candidateLineCount': candidateLineCount,
      'appTextScalePercent': appTextScalePercent,
      'timeControl': timeControl.name,
      'boardTheme': boardTheme.name,
      'locale': locale.name,
      'botProfileName': botProfileName,
      'persona': persona.name,
      'coachPersona': coachPersona.name,
      'tauntLevel': tauntLevel.name,
      'opponentDepth': opponentDepth.name,
      'teacherDepth': teacherDepth.name,
      'engineResources': engineResources.toJson(),
    };
  }
}
