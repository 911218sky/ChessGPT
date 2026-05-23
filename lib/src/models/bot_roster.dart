import 'session_config.dart';
import '../i18n/app_localizations.dart';

class BotProfile {
  const BotProfile({
    required this.name,
    required this.rating,
    required this.category,
    required this.title,
    required this.introLine,
    required this.specialty,
    required this.persona,
    required this.difficulty,
    required this.tauntLevel,
  });

  final String name;
  final int rating;
  final String category;
  final String title;
  final String introLine;
  final String specialty;
  final Persona persona;
  final DifficultyLevel difficulty;
  final TauntLevel tauntLevel;

  String localizedName(AppStrings strings) => switch (strings.locale) {
    AppLocale.en => name,
    AppLocale.zhHant => switch (name) {
      'Polly' => '波莉',
      'Vanta' => '范塔',
      'Brass Hook' => '銅鉤',
      'Harbor Sage' => '港灣賢者',
      'Bishop Ray' => '主教雷',
      'Sir Rowan' => '羅文爵士',
      'Nightglass' => '夜玻璃',
      'Storm Crown' => '風暴王冠',
      'Mira Mirage' => '幻影米拉',
      'Blitz Nova' => '閃擊諾瓦',
      'Stone Ledger' => '石頁帳官',
      'Queen Malva' => '瑪爾瓦女王',
      _ => name,
    },
  };

  String localizedCategory(AppStrings strings) => switch (strings.locale) {
    AppLocale.en => category,
    AppLocale.zhHant => switch (category) {
      'Pirates' => '海盜',
      'Beginner' => '新手',
      'Intermediate' => '中階',
      'Advanced' => '進階',
      _ => category,
    },
  };

  String localizedTitle(AppStrings strings) => switch (strings.locale) {
    AppLocale.en => title,
    AppLocale.zhHant => switch (name) {
      'Polly' => '吵鬧甲板老大',
      'Vanta' => '沉默的開線掠奪者',
      'Brass Hook' => '戰術型鬥士',
      'Harbor Sage' => '耐心教乾淨開局的老師',
      'Bishop Ray' => '懲罰懶散出子的教練',
      'Sir Rowan' => '技術乾淨的古典勁敵',
      'Nightglass' => '殘局機器',
      'Storm Crown' => '高壓 Boss 戰',
      'Mira Mirage' => '喜歡陷阱的幻術型對手',
      'Blitz Nova' => '節奏極快的快棋壓迫者',
      'Stone Ledger' => '耐心累積小優勢的殘局專家',
      'Queen Malva' => '華麗又危險的王室反派',
      _ => title,
    },
  };

  String localizedIntroLine(AppStrings strings) => switch (strings.locale) {
    AppLocale.en => introLine,
    AppLocale.zhHant => switch (name) {
      'Polly' => '來下棋吧。我會盯著每個鬆動的棋子。',
      'Vanta' => '棋盤已載入。準確度會決定這盤。',
      'Brass Hook' => '想換子就換吧。我更喜歡進攻。',
      'Harbor Sage' => '先控制中心，然後保護好你的王。',
      'Bishop Ray' => '我準備好了。我們可以一起懲罰鬆散結構。',
      'Sir Rowan' => '一副好棋盤，一場好對局。開始吧？',
      'Nightglass' => '一步不精準就夠了。',
      'Storm Crown' => '我不需要很多失誤。一個就夠。',
      'Mira Mirage' => '這盤棋有很多影子。別追錯那個。',
      'Blitz Nova' => '快一點。猶豫會把格子讓給我。',
      'Stone Ledger' => '我會記下每個小弱點，最後一起收帳。',
      'Queen Malva' => '跪不跪都可以。棋盤會替我說話。',
      _ => introLine,
    },
  };

  String localizedSpecialty(AppStrings strings) => switch (strings.locale) {
    AppLocale.en => specialty,
    AppLocale.zhHant => switch (specialty) {
      'Loose pieces' => '鬆動棋子',
      'Open files' => '開線',
      'Tactics' => '戰術',
      'Opening basics' => '開局基礎',
      'Development' => '出子',
      'Technique' => '技術',
      'Endgames' => '殘局',
      'Pressure' => '壓迫',
      'Traps' => '陷阱',
      'Tempo' => '節奏',
      'Conversion' => '轉換勝勢',
      'Domination' => '支配',
      _ => specialty,
    },
  };

  String promptRole(AppStrings strings) => switch (strings.locale) {
    AppLocale.en =>
      'Opponent role: $name, $title. Chess specialty: $specialty. Rating persona target: $rating.',
    AppLocale.zhHant =>
      '對手角色：${localizedName(strings)}，${localizedTitle(strings)}。棋風專長：${localizedSpecialty(strings)}。棋力定位：$rating。',
  };
}

const botRoster = <BotProfile>[
  BotProfile(
    name: 'Polly',
    rating: 199,
    category: 'Pirates',
    title: 'Deck boss with a loud beak',
    introLine: 'Let us play chess. I track every loose piece.',
    specialty: 'Loose pieces',
    persona: Persona.trashTalker,
    difficulty: DifficultyLevel.easy,
    tauntLevel: TauntLevel.full,
  ),
  BotProfile(
    name: 'Vanta',
    rating: 835,
    category: 'Pirates',
    title: 'Silent raider of open files',
    introLine: 'Board loaded. Accuracy will decide this one.',
    specialty: 'Open files',
    persona: Persona.coldMaster,
    difficulty: DifficultyLevel.normal,
    tauntLevel: TauntLevel.light,
  ),
  BotProfile(
    name: 'Brass Hook',
    rating: 1120,
    category: 'Pirates',
    title: 'Tactical brawler',
    introLine: 'Trade if you must. I prefer to attack.',
    specialty: 'Tactics',
    persona: Persona.trashTalker,
    difficulty: DifficultyLevel.hard,
    tauntLevel: TauntLevel.full,
  ),
  BotProfile(
    name: 'Harbor Sage',
    rating: 1285,
    category: 'Beginner',
    title: 'Patient teacher of clean openings',
    introLine: 'Start with the center and keep your king safe.',
    specialty: 'Opening basics',
    persona: Persona.coach,
    difficulty: DifficultyLevel.easy,
    tauntLevel: TauntLevel.off,
  ),
  BotProfile(
    name: 'Bishop Ray',
    rating: 1540,
    category: 'Intermediate',
    title: 'Coach who punishes lazy development',
    introLine: 'Ready when you are. We can punish loose structure together.',
    specialty: 'Development',
    persona: Persona.coach,
    difficulty: DifficultyLevel.normal,
    tauntLevel: TauntLevel.light,
  ),
  BotProfile(
    name: 'Sir Rowan',
    rating: 1710,
    category: 'Intermediate',
    title: 'Classical rival with clean technique',
    introLine: 'A proper board and a proper match. Shall we begin?',
    specialty: 'Technique',
    persona: Persona.gentleman,
    difficulty: DifficultyLevel.hard,
    tauntLevel: TauntLevel.off,
  ),
  BotProfile(
    name: 'Nightglass',
    rating: 1960,
    category: 'Advanced',
    title: 'Endgame machine',
    introLine: 'One imprecise move is enough.',
    specialty: 'Endgames',
    persona: Persona.coldMaster,
    difficulty: DifficultyLevel.master,
    tauntLevel: TauntLevel.light,
  ),
  BotProfile(
    name: 'Storm Crown',
    rating: 2215,
    category: 'Advanced',
    title: 'High-pressure boss encounter',
    introLine: 'I do not need many mistakes. One is fine.',
    specialty: 'Pressure',
    persona: Persona.trashTalker,
    difficulty: DifficultyLevel.chaos,
    tauntLevel: TauntLevel.full,
  ),
  BotProfile(
    name: 'Mira Mirage',
    rating: 1460,
    category: 'Intermediate',
    title: 'Trickster who hides traps in quiet moves',
    introLine: 'This board has shadows. Do not chase the wrong one.',
    specialty: 'Traps',
    persona: Persona.trickster,
    difficulty: DifficultyLevel.normal,
    tauntLevel: TauntLevel.light,
  ),
  BotProfile(
    name: 'Blitz Nova',
    rating: 1675,
    category: 'Intermediate',
    title: 'Fast-paced pressure player',
    introLine: 'Move quickly. Hesitation gives me squares.',
    specialty: 'Tempo',
    persona: Persona.speedDemon,
    difficulty: DifficultyLevel.hard,
    tauntLevel: TauntLevel.full,
  ),
  BotProfile(
    name: 'Stone Ledger',
    rating: 2050,
    category: 'Advanced',
    title: 'Endgame accountant of tiny weaknesses',
    introLine: 'I will record every small weakness and collect later.',
    specialty: 'Conversion',
    persona: Persona.endgameGrinder,
    difficulty: DifficultyLevel.master,
    tauntLevel: TauntLevel.light,
  ),
  BotProfile(
    name: 'Queen Malva',
    rating: 2380,
    category: 'Advanced',
    title: 'Elegant royal villain',
    introLine: 'Kneel or do not. The board will speak for me.',
    specialty: 'Domination',
    persona: Persona.royalVillain,
    difficulty: DifficultyLevel.chaos,
    tauntLevel: TauntLevel.full,
  ),
];

BotProfile profileForConfig(GameSessionConfig config) {
  final namedProfile = profileByName(config.botProfileName);
  if (namedProfile != null) {
    return namedProfile;
  }

  for (final profile in botRoster) {
    if (profile.persona == config.persona &&
        profile.difficulty == config.difficulty) {
      return profile;
    }
  }

  for (final profile in botRoster) {
    if (profile.persona == config.persona) {
      return profile;
    }
  }

  return botRoster.first;
}

BotProfile? profileByName(String name) {
  for (final profile in botRoster) {
    if (profile.name == name) {
      return profile;
    }
  }
  return null;
}

List<BotProfile> profilesForPersona(Persona persona) {
  return [
    for (final profile in botRoster)
      if (profile.persona == persona) profile,
  ];
}

BotProfile bestProfileForPersona(
  Persona persona, {
  DifficultyLevel? preferredDifficulty,
}) {
  final matches = profilesForPersona(persona);
  if (matches.isEmpty) {
    return botRoster.first;
  }
  if (preferredDifficulty != null) {
    for (final profile in matches) {
      if (profile.difficulty == preferredDifficulty) {
        return profile;
      }
    }
  }
  return matches.first;
}
