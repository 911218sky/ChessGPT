import 'package:flutter/material.dart';

import '../i18n/app_localizations.dart';

enum BoardThemeId {
  classicWood,
  tournamentGreen,
  oceanSlate,
  walnut,
  midnight,
  jungleCanopy,
  coralReef,
  desertSun,
  frostTemple,
  lavaForge,
  sakuraGarden,
  neonCity,
  royalMarble,
  autumnAcademy,
  crystalCavern,
  skyCitadel;

  String get label => switch (this) {
    BoardThemeId.classicWood => 'Classic Wood',
    BoardThemeId.tournamentGreen => 'Tournament Green',
    BoardThemeId.oceanSlate => 'Ocean Slate',
    BoardThemeId.walnut => 'Walnut',
    BoardThemeId.midnight => 'Midnight',
    BoardThemeId.jungleCanopy => 'Jungle Canopy',
    BoardThemeId.coralReef => 'Coral Reef',
    BoardThemeId.desertSun => 'Desert Sun',
    BoardThemeId.frostTemple => 'Frost Temple',
    BoardThemeId.lavaForge => 'Lava Forge',
    BoardThemeId.sakuraGarden => 'Sakura Garden',
    BoardThemeId.neonCity => 'Neon City',
    BoardThemeId.royalMarble => 'Royal Marble',
    BoardThemeId.autumnAcademy => 'Autumn Academy',
    BoardThemeId.crystalCavern => 'Crystal Cavern',
    BoardThemeId.skyCitadel => 'Sky Citadel',
  };

  String localizedLabel(AppStrings strings) => switch (strings.locale) {
    AppLocale.en => label,
    AppLocale.zhHant => switch (this) {
      BoardThemeId.classicWood => '經典木紋',
      BoardThemeId.tournamentGreen => '錦標賽綠',
      BoardThemeId.oceanSlate => '海洋板岩',
      BoardThemeId.walnut => '胡桃木',
      BoardThemeId.midnight => '午夜',
      BoardThemeId.jungleCanopy => '叢林樹冠',
      BoardThemeId.coralReef => '珊瑚礁',
      BoardThemeId.desertSun => '沙漠夕陽',
      BoardThemeId.frostTemple => '冰霜神殿',
      BoardThemeId.lavaForge => '熔岩鍛坊',
      BoardThemeId.sakuraGarden => '櫻花庭園',
      BoardThemeId.neonCity => '霓虹城市',
      BoardThemeId.royalMarble => '皇家大理石',
      BoardThemeId.autumnAcademy => '秋日學院',
      BoardThemeId.crystalCavern => '水晶洞窟',
      BoardThemeId.skyCitadel => '天空城塞',
    },
  };
}

class BoardThemeStyle {
  const BoardThemeStyle({
    required this.id,
    required this.pieceSet,
    required this.lightSquare,
    required this.darkSquare,
    required this.frameStart,
    required this.frameEnd,
    required this.labelOnLight,
    required this.labelOnDark,
    required this.whitePiece,
    required this.blackPiece,
    required this.selected,
    required this.selectedBorder,
    required this.lastMove,
    required this.target,
    required this.captureRing,
    required this.textureAlpha,
    required this.backdropTop,
    required this.backdropBottom,
    required this.backdropAccent,
    required this.backdropShadow,
    required this.panelTint,
    this.leftBannerAsset,
    this.rightBannerAsset,
    this.bannerOpacity = 0.88,
    this.backdropSpec = const BoardThemeBackdropSpec(),
    this.backdropAsset,
    this.boardTextureSet,
    this.boardTextureOpacity = 0.34,
  });

  final BoardThemeId id;
  final ChessPieceSet pieceSet;
  final Color lightSquare;
  final Color darkSquare;
  final Color frameStart;
  final Color frameEnd;
  final Color labelOnLight;
  final Color labelOnDark;
  final Color whitePiece;
  final Color blackPiece;
  final Color selected;
  final Color selectedBorder;
  final Color lastMove;
  final Color target;
  final Color captureRing;
  final double textureAlpha;
  final Color backdropTop;
  final Color backdropBottom;
  final Color backdropAccent;
  final Color backdropShadow;
  final Color panelTint;
  final String? leftBannerAsset;
  final String? rightBannerAsset;
  final double bannerOpacity;
  final BoardThemeBackdropSpec backdropSpec;
  final String? backdropAsset;
  final BoardTextureSet? boardTextureSet;
  final double boardTextureOpacity;
}

class ChessPieceSet {
  const ChessPieceSet({
    required this.id,
    required this.label,
    required this.basePath,
    required this.extension,
  });

  final String id;
  final String label;
  final String basePath;
  final String extension;

  String assetFor(String code) => '$basePath/$code.$extension';
}

class BoardTextureSet {
  const BoardTextureSet({
    required this.id,
    required this.label,
    required this.basePath,
  });

  final String id;
  final String label;
  final String basePath;

  String assetFor(bool isLight) =>
      '$basePath/${isLight ? 'light' : 'dark'}.webp';
}

enum BoardThemeBackdropOrnamentKind {
  banner,
  pillar,
  plume,
  sigil,
  arch,
  crystal,
  lantern,
}

class BoardThemeBackdropOrnament {
  const BoardThemeBackdropOrnament({
    required this.kind,
    required this.alignment,
    required this.size,
    required this.color,
    this.opacity = 1,
    this.rotation = 0,
  });

  final BoardThemeBackdropOrnamentKind kind;
  final Alignment alignment;
  final Size size;
  final Color color;
  final double opacity;
  final double rotation;
}

class BoardThemeBackdropSpec {
  const BoardThemeBackdropSpec({
    this.edgeGlowColor,
    this.edgeGlowOpacity = 0.18,
    this.mistColor,
    this.mistOpacity = 0.10,
    this.vignetteOpacity = 0.42,
    this.ornaments = const [],
  });

  final Color? edgeGlowColor;
  final double edgeGlowOpacity;
  final Color? mistColor;
  final double mistOpacity;
  final double vignetteOpacity;
  final List<BoardThemeBackdropOrnament> ornaments;
}

const cburnettPieceSet = ChessPieceSet(
  id: 'cburnett',
  label: 'Cburnett',
  basePath: 'assets/chess/pieces/cburnett_png',
  extension: 'png',
);

const autumnAcademyBoardTextureSet = BoardTextureSet(
  id: 'autumn_academy',
  label: 'Autumn Academy',
  basePath: 'assets/chess/board_textures/autumn_academy',
);

const classicWoodBoardTextureSet = BoardTextureSet(
  id: 'classic_wood',
  label: 'Classic Wood',
  basePath: 'assets/chess/board_textures/classic_wood',
);

const coralReefBoardTextureSet = BoardTextureSet(
  id: 'coral_reef',
  label: 'Coral Reef',
  basePath: 'assets/chess/board_textures/coral_reef',
);

const crystalCavernBoardTextureSet = BoardTextureSet(
  id: 'crystal_cavern',
  label: 'Crystal Cavern',
  basePath: 'assets/chess/board_textures/crystal_cavern',
);

const desertSunBoardTextureSet = BoardTextureSet(
  id: 'desert_sun',
  label: 'Desert Sun',
  basePath: 'assets/chess/board_textures/desert_sun',
);

const frostTempleBoardTextureSet = BoardTextureSet(
  id: 'frost_temple',
  label: 'Frost Temple',
  basePath: 'assets/chess/board_textures/frost_temple',
);

const jungleCanopyBoardTextureSet = BoardTextureSet(
  id: 'jungle_canopy',
  label: 'Jungle Canopy',
  basePath: 'assets/chess/board_textures/jungle_canopy',
);

const lavaForgeBoardTextureSet = BoardTextureSet(
  id: 'lava_forge',
  label: 'Lava Forge',
  basePath: 'assets/chess/board_textures/lava_forge',
);

const midnightBoardTextureSet = BoardTextureSet(
  id: 'midnight_observatory',
  label: 'Midnight Observatory',
  basePath: 'assets/chess/board_textures/midnight_observatory',
);

const neonCityBoardTextureSet = BoardTextureSet(
  id: 'neon_city',
  label: 'Neon City',
  basePath: 'assets/chess/board_textures/neon_city',
);

const oceanSlateBoardTextureSet = BoardTextureSet(
  id: 'ocean_slate',
  label: 'Ocean Slate',
  basePath: 'assets/chess/board_textures/ocean_slate',
);

const royalMarbleBoardTextureSet = BoardTextureSet(
  id: 'royal_marble',
  label: 'Royal Marble',
  basePath: 'assets/chess/board_textures/royal_marble',
);

const sakuraGardenBoardTextureSet = BoardTextureSet(
  id: 'sakura_garden',
  label: 'Sakura Garden',
  basePath: 'assets/chess/board_textures/sakura_garden',
);

const skyCitadelBoardTextureSet = BoardTextureSet(
  id: 'sky_citadel',
  label: 'Sky Citadel',
  basePath: 'assets/chess/board_textures/sky_citadel',
);

const tournamentGreenBoardTextureSet = BoardTextureSet(
  id: 'tournament_green',
  label: 'Tournament Green',
  basePath: 'assets/chess/board_textures/tournament_green',
);

const walnutBoardTextureSet = BoardTextureSet(
  id: 'walnut_study',
  label: 'Walnut Study',
  basePath: 'assets/chess/board_textures/walnut_study',
);

const boardThemeStyles = <BoardThemeId, BoardThemeStyle>{
  BoardThemeId.classicWood: BoardThemeStyle(
    id: BoardThemeId.classicWood,
    pieceSet: cburnettPieceSet,
    lightSquare: Color(0xFFF3C885),
    darkSquare: Color(0xFFB36E3E),
    frameStart: Color(0xFF6D4424),
    frameEnd: Color(0xFF52331A),
    labelOnLight: Color(0xFF925B30),
    labelOnDark: Color(0xFFFBE8C2),
    whitePiece: Color(0xFFFFF6EE),
    blackPiece: Color(0xFF505480),
    selected: Color(0x662F80ED),
    selectedBorder: Color(0xAA9AC7FF),
    lastMove: Color(0xD0F6C33C),
    target: Color(0x6A302015),
    captureRing: Color(0x8A2F1A10),
    textureAlpha: 0.11,
    backdropTop: Color(0xFF2C241B),
    backdropBottom: Color(0xFF16120E),
    backdropAccent: Color(0xFFC88943),
    backdropShadow: Color(0xFF2D1710),
    panelTint: Color(0xFF382719),
    backdropAsset: 'assets/chess/themes/classic-wood-club.webp',
    boardTextureSet: classicWoodBoardTextureSet,
  ),
  BoardThemeId.tournamentGreen: BoardThemeStyle(
    id: BoardThemeId.tournamentGreen,
    pieceSet: cburnettPieceSet,
    lightSquare: Color(0xFFEEEED2),
    darkSquare: Color(0xFF769656),
    frameStart: Color(0xFF38422F),
    frameEnd: Color(0xFF20271C),
    labelOnLight: Color(0xFF6B7F46),
    labelOnDark: Color(0xFFEAF1CF),
    whitePiece: Color(0xFFFFFAEF),
    blackPiece: Color(0xFF303735),
    selected: Color(0x5EF7D04A),
    selectedBorder: Color(0xFFE4C53B),
    lastMove: Color(0xCCF6D962),
    target: Color(0x66404C32),
    captureRing: Color(0x98404C32),
    textureAlpha: 0.04,
    backdropTop: Color(0xFF20291F),
    backdropBottom: Color(0xFF111611),
    backdropAccent: Color(0xFF8DB05F),
    backdropShadow: Color(0xFF172214),
    panelTint: Color(0xFF263120),
    backdropAsset: 'assets/chess/themes/tournament-green-hall.webp',
    boardTextureSet: tournamentGreenBoardTextureSet,
  ),
  BoardThemeId.oceanSlate: BoardThemeStyle(
    id: BoardThemeId.oceanSlate,
    pieceSet: cburnettPieceSet,
    lightSquare: Color(0xFFD8E3E8),
    darkSquare: Color(0xFF5E8391),
    frameStart: Color(0xFF2D4953),
    frameEnd: Color(0xFF16282F),
    labelOnLight: Color(0xFF4B7584),
    labelOnDark: Color(0xFFE4F2F6),
    whitePiece: Color(0xFFFFFBF3),
    blackPiece: Color(0xFF223044),
    selected: Color(0x663AA5FF),
    selectedBorder: Color(0xCC9BD7FF),
    lastMove: Color(0xCCF4D35E),
    target: Color(0x66233946),
    captureRing: Color(0x99233946),
    textureAlpha: 0.05,
    backdropTop: Color(0xFF18323D),
    backdropBottom: Color(0xFF0B171C),
    backdropAccent: Color(0xFF6CC7D8),
    backdropShadow: Color(0xFF10212A),
    panelTint: Color(0xFF1D313A),
    backdropAsset: 'assets/chess/themes/ocean-slate-terrace.webp',
    boardTextureSet: oceanSlateBoardTextureSet,
  ),
  BoardThemeId.walnut: BoardThemeStyle(
    id: BoardThemeId.walnut,
    pieceSet: cburnettPieceSet,
    lightSquare: Color(0xFFE7B77A),
    darkSquare: Color(0xFF7B4B2F),
    frameStart: Color(0xFF4C2E1F),
    frameEnd: Color(0xFF2B1A13),
    labelOnLight: Color(0xFF724326),
    labelOnDark: Color(0xFFF0D1A9),
    whitePiece: Color(0xFFFFF0DD),
    blackPiece: Color(0xFF423243),
    selected: Color(0x665EA7FF),
    selectedBorder: Color(0xCCB8D8FF),
    lastMove: Color(0xD0F8D05B),
    target: Color(0x66331E14),
    captureRing: Color(0x98331E14),
    textureAlpha: 0.15,
    backdropTop: Color(0xFF2A1B14),
    backdropBottom: Color(0xFF120C09),
    backdropAccent: Color(0xFFA96938),
    backdropShadow: Color(0xFF22110B),
    panelTint: Color(0xFF2C1F18),
    backdropAsset: 'assets/chess/themes/walnut-study.webp',
    boardTextureSet: walnutBoardTextureSet,
  ),
  BoardThemeId.midnight: BoardThemeStyle(
    id: BoardThemeId.midnight,
    pieceSet: cburnettPieceSet,
    lightSquare: Color(0xFFB7BBC8),
    darkSquare: Color(0xFF3E465B),
    frameStart: Color(0xFF242B3A),
    frameEnd: Color(0xFF121722),
    labelOnLight: Color(0xFF4B5268),
    labelOnDark: Color(0xFFE1E5F1),
    whitePiece: Color(0xFFFFFAF1),
    blackPiece: Color(0xFF151A28),
    selected: Color(0x6656A8FF),
    selectedBorder: Color(0xCC9FD0FF),
    lastMove: Color(0xD0F7C948),
    target: Color(0x66151A28),
    captureRing: Color(0x99151A28),
    textureAlpha: 0.03,
    backdropTop: Color(0xFF171D2B),
    backdropBottom: Color(0xFF090D15),
    backdropAccent: Color(0xFF769BFF),
    backdropShadow: Color(0xFF070912),
    panelTint: Color(0xFF1B2030),
    backdropAsset: 'assets/chess/themes/midnight-observatory.webp',
    boardTextureSet: midnightBoardTextureSet,
  ),
  BoardThemeId.jungleCanopy: BoardThemeStyle(
    id: BoardThemeId.jungleCanopy,
    pieceSet: cburnettPieceSet,
    lightSquare: Color(0xFFE4D7A6),
    darkSquare: Color(0xFF3F7A45),
    frameStart: Color(0xFF314F28),
    frameEnd: Color(0xFF172715),
    labelOnLight: Color(0xFF496633),
    labelOnDark: Color(0xFFEAF4C9),
    whitePiece: Color(0xFFFFF7DD),
    blackPiece: Color(0xFF1E3025),
    selected: Color(0x6657B86F),
    selectedBorder: Color(0xCCBCEB77),
    lastMove: Color(0xD0F0C95B),
    target: Color(0x66305225),
    captureRing: Color(0x99305225),
    textureAlpha: 0.09,
    backdropTop: Color(0xFF173B25),
    backdropBottom: Color(0xFF07150C),
    backdropAccent: Color(0xFF7BC56A),
    backdropShadow: Color(0xFF0B2413),
    panelTint: Color(0xFF172A1E),
    backdropAsset: 'assets/chess/themes/jungle-arena.webp',
    boardTextureSet: jungleCanopyBoardTextureSet,
  ),
  BoardThemeId.coralReef: BoardThemeStyle(
    id: BoardThemeId.coralReef,
    pieceSet: cburnettPieceSet,
    lightSquare: Color(0xFFD9F0F0),
    darkSquare: Color(0xFF317F9C),
    frameStart: Color(0xFF285B6C),
    frameEnd: Color(0xFF0D2732),
    labelOnLight: Color(0xFF317485),
    labelOnDark: Color(0xFFE7FAF8),
    whitePiece: Color(0xFFFFF7E8),
    blackPiece: Color(0xFF17283E),
    selected: Color(0x665DD7E8),
    selectedBorder: Color(0xCCB9F4FF),
    lastMove: Color(0xD0F7B678),
    target: Color(0x66274452),
    captureRing: Color(0x99274452),
    textureAlpha: 0.07,
    backdropTop: Color(0xFF08324B),
    backdropBottom: Color(0xFF06131F),
    backdropAccent: Color(0xFF4FD7D8),
    backdropShadow: Color(0xFF061D2B),
    panelTint: Color(0xFF142F3C),
    backdropAsset: 'assets/chess/themes/ocean-arena.webp',
    boardTextureSet: coralReefBoardTextureSet,
  ),
  BoardThemeId.desertSun: BoardThemeStyle(
    id: BoardThemeId.desertSun,
    pieceSet: cburnettPieceSet,
    lightSquare: Color(0xFFF4D49C),
    darkSquare: Color(0xFFC07A3D),
    frameStart: Color(0xFF8A4E27),
    frameEnd: Color(0xFF3F2416),
    labelOnLight: Color(0xFF986236),
    labelOnDark: Color(0xFFFFE7B7),
    whitePiece: Color(0xFFFFF3D8),
    blackPiece: Color(0xFF46332E),
    selected: Color(0x66FFB454),
    selectedBorder: Color(0xFFFFD27C),
    lastMove: Color(0xD0FFD15E),
    target: Color(0x664B2D19),
    captureRing: Color(0x994B2D19),
    textureAlpha: 0.10,
    backdropTop: Color(0xFF5A341F),
    backdropBottom: Color(0xFF21120B),
    backdropAccent: Color(0xFFE29A48),
    backdropShadow: Color(0xFF32190D),
    panelTint: Color(0xFF342217),
    backdropAsset: 'assets/chess/themes/desert-arena.webp',
    boardTextureSet: desertSunBoardTextureSet,
  ),
  BoardThemeId.frostTemple: BoardThemeStyle(
    id: BoardThemeId.frostTemple,
    pieceSet: cburnettPieceSet,
    lightSquare: Color(0xFFE3EDF4),
    darkSquare: Color(0xFF7EA4BD),
    frameStart: Color(0xFF4B6574),
    frameEnd: Color(0xFF1E303A),
    labelOnLight: Color(0xFF5C7A8C),
    labelOnDark: Color(0xFFF1F9FF),
    whitePiece: Color(0xFFFFFFFF),
    blackPiece: Color(0xFF263241),
    selected: Color(0x667FCBFF),
    selectedBorder: Color(0xFFD0F0FF),
    lastMove: Color(0xD0E7F27A),
    target: Color(0x66304452),
    captureRing: Color(0x99304452),
    textureAlpha: 0.06,
    backdropTop: Color(0xFF203849),
    backdropBottom: Color(0xFF0C141C),
    backdropAccent: Color(0xFF9EDCF2),
    backdropShadow: Color(0xFF142433),
    panelTint: Color(0xFF1B2A34),
    backdropSpec: BoardThemeBackdropSpec(
      edgeGlowColor: Color(0xFF9EDCF2),
      edgeGlowOpacity: 0.26,
      mistColor: Color(0xFFBEEBFB),
      mistOpacity: 0.15,
      vignetteOpacity: 0.50,
      ornaments: [
        BoardThemeBackdropOrnament(
          kind: BoardThemeBackdropOrnamentKind.crystal,
          alignment: Alignment.topLeft,
          size: Size(260, 240),
          color: Color(0xFFD4F6FF),
          opacity: 0.20,
          rotation: -0.14,
        ),
        BoardThemeBackdropOrnament(
          kind: BoardThemeBackdropOrnamentKind.crystal,
          alignment: Alignment.topRight,
          size: Size(300, 280),
          color: Color(0xFFB6EDF7),
          opacity: 0.22,
          rotation: 0.08,
        ),
        BoardThemeBackdropOrnament(
          kind: BoardThemeBackdropOrnamentKind.plume,
          alignment: Alignment.bottomLeft,
          size: Size(360, 200),
          color: Color(0xFF9EDCF2),
          opacity: 0.18,
          rotation: -0.10,
        ),
        BoardThemeBackdropOrnament(
          kind: BoardThemeBackdropOrnamentKind.banner,
          alignment: Alignment.bottomRight,
          size: Size(250, 150),
          color: Color(0xFFA5DFF4),
          opacity: 0.15,
          rotation: 0.10,
        ),
      ],
    ),
    backdropAsset: 'assets/chess/themes/frost-temple.webp',
    boardTextureSet: frostTempleBoardTextureSet,
  ),
  BoardThemeId.lavaForge: BoardThemeStyle(
    id: BoardThemeId.lavaForge,
    pieceSet: cburnettPieceSet,
    lightSquare: Color(0xFFD8A06A),
    darkSquare: Color(0xFF653735),
    frameStart: Color(0xFF5E2721),
    frameEnd: Color(0xFF1B0E0D),
    labelOnLight: Color(0xFF6F3427),
    labelOnDark: Color(0xFFFFD8A8),
    whitePiece: Color(0xFFFFEAD0),
    blackPiece: Color(0xFF251B1F),
    selected: Color(0x66FF6E40),
    selectedBorder: Color(0xFFFFB25B),
    lastMove: Color(0xD0FFBC4A),
    target: Color(0x66351B18),
    captureRing: Color(0x99351B18),
    textureAlpha: 0.13,
    backdropTop: Color(0xFF341512),
    backdropBottom: Color(0xFF0D0808),
    backdropAccent: Color(0xFFFF7043),
    backdropShadow: Color(0xFF220B09),
    panelTint: Color(0xFF2B1715),
    backdropSpec: BoardThemeBackdropSpec(
      edgeGlowColor: Color(0xFFFF7043),
      edgeGlowOpacity: 0.30,
      mistColor: Color(0xFFFF8A65),
      mistOpacity: 0.14,
      vignetteOpacity: 0.56,
      ornaments: [
        BoardThemeBackdropOrnament(
          kind: BoardThemeBackdropOrnamentKind.pillar,
          alignment: Alignment.topLeft,
          size: Size(300, 280),
          color: Color(0xFF8D2C24),
          opacity: 0.20,
          rotation: -0.06,
        ),
        BoardThemeBackdropOrnament(
          kind: BoardThemeBackdropOrnamentKind.pillar,
          alignment: Alignment.topRight,
          size: Size(240, 220),
          color: Color(0xFFB13A24),
          opacity: 0.15,
          rotation: 0.04,
        ),
        BoardThemeBackdropOrnament(
          kind: BoardThemeBackdropOrnamentKind.plume,
          alignment: Alignment.bottomRight,
          size: Size(340, 220),
          color: Color(0xFFFF6F45),
          opacity: 0.20,
          rotation: 0.10,
        ),
        BoardThemeBackdropOrnament(
          kind: BoardThemeBackdropOrnamentKind.banner,
          alignment: Alignment.bottomLeft,
          size: Size(260, 150),
          color: Color(0xFFFFA26A),
          opacity: 0.15,
          rotation: -0.08,
        ),
      ],
    ),
    backdropAsset: 'assets/chess/themes/lava-forge.webp',
    boardTextureSet: lavaForgeBoardTextureSet,
  ),
  BoardThemeId.sakuraGarden: BoardThemeStyle(
    id: BoardThemeId.sakuraGarden,
    pieceSet: cburnettPieceSet,
    lightSquare: Color(0xFFF5DAD8),
    darkSquare: Color(0xFFB86E8B),
    frameStart: Color(0xFF744A5C),
    frameEnd: Color(0xFF30212B),
    labelOnLight: Color(0xFF9B6079),
    labelOnDark: Color(0xFFFFEBEF),
    whitePiece: Color(0xFFFFF5EE),
    blackPiece: Color(0xFF37283B),
    selected: Color(0x66F08DB4),
    selectedBorder: Color(0xFFFFC1D6),
    lastMove: Color(0xD0F5D56A),
    target: Color(0x66432B37),
    captureRing: Color(0x99432B37),
    textureAlpha: 0.08,
    backdropTop: Color(0xFF3B2634),
    backdropBottom: Color(0xFF171018),
    backdropAccent: Color(0xFFF09DBC),
    backdropShadow: Color(0xFF241420),
    panelTint: Color(0xFF2F202B),
    backdropSpec: BoardThemeBackdropSpec(
      edgeGlowColor: Color(0xFFF09DBC),
      edgeGlowOpacity: 0.24,
      mistColor: Color(0xFFFFD9E8),
      mistOpacity: 0.16,
      vignetteOpacity: 0.48,
      ornaments: [
        BoardThemeBackdropOrnament(
          kind: BoardThemeBackdropOrnamentKind.lantern,
          alignment: Alignment.topLeft,
          size: Size(240, 200),
          color: Color(0xFFF0A3C0),
          opacity: 0.18,
          rotation: -0.08,
        ),
        BoardThemeBackdropOrnament(
          kind: BoardThemeBackdropOrnamentKind.lantern,
          alignment: Alignment.topRight,
          size: Size(210, 180),
          color: Color(0xFFFFB4D0),
          opacity: 0.15,
          rotation: 0.06,
        ),
        BoardThemeBackdropOrnament(
          kind: BoardThemeBackdropOrnamentKind.plume,
          alignment: Alignment.bottomRight,
          size: Size(360, 220),
          color: Color(0xFFEFA0B8),
          opacity: 0.18,
          rotation: 0.08,
        ),
        BoardThemeBackdropOrnament(
          kind: BoardThemeBackdropOrnamentKind.banner,
          alignment: Alignment.bottomLeft,
          size: Size(260, 140),
          color: Color(0xFFFFC3DA),
          opacity: 0.14,
          rotation: -0.06,
        ),
      ],
    ),
    backdropAsset: 'assets/chess/themes/sakura-garden.webp',
    boardTextureSet: sakuraGardenBoardTextureSet,
  ),
  BoardThemeId.neonCity: BoardThemeStyle(
    id: BoardThemeId.neonCity,
    pieceSet: cburnettPieceSet,
    lightSquare: Color(0xFFB8E5E8),
    darkSquare: Color(0xFF54336F),
    frameStart: Color(0xFF153C4B),
    frameEnd: Color(0xFF160D22),
    labelOnLight: Color(0xFF39707B),
    labelOnDark: Color(0xFFF3D9FF),
    whitePiece: Color(0xFFFFF5EC),
    blackPiece: Color(0xFF161225),
    selected: Color(0x6659E8FF),
    selectedBorder: Color(0xFFFF62D4),
    lastMove: Color(0xD0FFE95C),
    target: Color(0x66221A36),
    captureRing: Color(0x99221A36),
    textureAlpha: 0.06,
    backdropTop: Color(0xFF102334),
    backdropBottom: Color(0xFF080913),
    backdropAccent: Color(0xFF47DFF0),
    backdropShadow: Color(0xFF090718),
    panelTint: Color(0xFF171A2B),
    backdropSpec: BoardThemeBackdropSpec(
      edgeGlowColor: Color(0xFF47DFF0),
      edgeGlowOpacity: 0.32,
      mistColor: Color(0xFF7E7AFF),
      mistOpacity: 0.12,
      vignetteOpacity: 0.54,
      ornaments: [
        BoardThemeBackdropOrnament(
          kind: BoardThemeBackdropOrnamentKind.sigil,
          alignment: Alignment.topLeft,
          size: Size(260, 260),
          color: Color(0xFF59E2F5),
          opacity: 0.22,
          rotation: -0.06,
        ),
        BoardThemeBackdropOrnament(
          kind: BoardThemeBackdropOrnamentKind.sigil,
          alignment: Alignment.topRight,
          size: Size(220, 220),
          color: Color(0xFFFF5FD2),
          opacity: 0.14,
          rotation: 0.04,
        ),
        BoardThemeBackdropOrnament(
          kind: BoardThemeBackdropOrnamentKind.banner,
          alignment: Alignment.bottomRight,
          size: Size(320, 160),
          color: Color(0xFFFF62D4),
          opacity: 0.18,
          rotation: 0.06,
        ),
        BoardThemeBackdropOrnament(
          kind: BoardThemeBackdropOrnamentKind.banner,
          alignment: Alignment.bottomLeft,
          size: Size(260, 130),
          color: Color(0xFF4EEBFF),
          opacity: 0.14,
          rotation: -0.08,
        ),
      ],
    ),
    backdropAsset: 'assets/chess/themes/neon-city.webp',
    boardTextureSet: neonCityBoardTextureSet,
  ),
  BoardThemeId.royalMarble: BoardThemeStyle(
    id: BoardThemeId.royalMarble,
    pieceSet: cburnettPieceSet,
    lightSquare: Color(0xFFF1E6D1),
    darkSquare: Color(0xFF8B6A4A),
    frameStart: Color(0xFF6D563E),
    frameEnd: Color(0xFF221B18),
    labelOnLight: Color(0xFF756046),
    labelOnDark: Color(0xFFFFF0D4),
    whitePiece: Color(0xFFFFF9EA),
    blackPiece: Color(0xFF292332),
    selected: Color(0x66D6B35E),
    selectedBorder: Color(0xFFFFD678),
    lastMove: Color(0xD0FFE182),
    target: Color(0x663B3025),
    captureRing: Color(0x993B3025),
    textureAlpha: 0.07,
    backdropTop: Color(0xFF3A332E),
    backdropBottom: Color(0xFF111014),
    backdropAccent: Color(0xFFD6B35E),
    backdropShadow: Color(0xFF20171A),
    panelTint: Color(0xFF2B2424),
    backdropSpec: BoardThemeBackdropSpec(
      edgeGlowColor: Color(0xFFD6B35E),
      edgeGlowOpacity: 0.25,
      mistColor: Color(0xFFF0D39B),
      mistOpacity: 0.10,
      vignetteOpacity: 0.50,
      ornaments: [
        BoardThemeBackdropOrnament(
          kind: BoardThemeBackdropOrnamentKind.arch,
          alignment: Alignment.topLeft,
          size: Size(260, 180),
          color: Color(0xFFF0D39B),
          opacity: 0.16,
          rotation: -0.05,
        ),
        BoardThemeBackdropOrnament(
          kind: BoardThemeBackdropOrnamentKind.arch,
          alignment: Alignment.topRight,
          size: Size(320, 220),
          color: Color(0xFFDAC18A),
          opacity: 0.20,
          rotation: 0.06,
        ),
        BoardThemeBackdropOrnament(
          kind: BoardThemeBackdropOrnamentKind.pillar,
          alignment: Alignment.bottomLeft,
          size: Size(280, 250),
          color: Color(0xFF8E7258),
          opacity: 0.18,
          rotation: -0.08,
        ),
        BoardThemeBackdropOrnament(
          kind: BoardThemeBackdropOrnamentKind.banner,
          alignment: Alignment.bottomRight,
          size: Size(270, 150),
          color: Color(0xFFE3C06D),
          opacity: 0.16,
          rotation: 0.08,
        ),
      ],
    ),
    backdropAsset: 'assets/chess/themes/royal-marble.webp',
    boardTextureSet: royalMarbleBoardTextureSet,
  ),
  BoardThemeId.autumnAcademy: BoardThemeStyle(
    id: BoardThemeId.autumnAcademy,
    pieceSet: cburnettPieceSet,
    lightSquare: Color(0xFFE8C98C),
    darkSquare: Color(0xFF9B5035),
    frameStart: Color(0xFF633827),
    frameEnd: Color(0xFF24140F),
    labelOnLight: Color(0xFF825131),
    labelOnDark: Color(0xFFFFE6AD),
    whitePiece: Color(0xFFFFF1DA),
    blackPiece: Color(0xFF342D24),
    selected: Color(0x66D89942),
    selectedBorder: Color(0xFFFFC961),
    lastMove: Color(0xD0F4D05A),
    target: Color(0x66371F16),
    captureRing: Color(0x99371F16),
    textureAlpha: 0.10,
    backdropTop: Color(0xFF412719),
    backdropBottom: Color(0xFF150D09),
    backdropAccent: Color(0xFFD9863A),
    backdropShadow: Color(0xFF211008),
    panelTint: Color(0xFF302018),
    backdropAsset: 'assets/chess/themes/autumn-academy.webp',
    boardTextureSet: autumnAcademyBoardTextureSet,
  ),
  BoardThemeId.crystalCavern: BoardThemeStyle(
    id: BoardThemeId.crystalCavern,
    pieceSet: cburnettPieceSet,
    lightSquare: Color(0xFFD8F0F2),
    darkSquare: Color(0xFF61539A),
    frameStart: Color(0xFF304D64),
    frameEnd: Color(0xFF17132B),
    labelOnLight: Color(0xFF4D6F83),
    labelOnDark: Color(0xFFE7E0FF),
    whitePiece: Color(0xFFFFFFFF),
    blackPiece: Color(0xFF202139),
    selected: Color(0x6677E0D8),
    selectedBorder: Color(0xFFCBB7FF),
    lastMove: Color(0xD0E5F26B),
    target: Color(0x662B254A),
    captureRing: Color(0x992B254A),
    textureAlpha: 0.06,
    backdropTop: Color(0xFF172D3E),
    backdropBottom: Color(0xFF0A0817),
    backdropAccent: Color(0xFF7FE5DA),
    backdropShadow: Color(0xFF100B24),
    panelTint: Color(0xFF1B2134),
    backdropAsset: 'assets/chess/themes/crystal-cavern.webp',
    boardTextureSet: crystalCavernBoardTextureSet,
  ),
  BoardThemeId.skyCitadel: BoardThemeStyle(
    id: BoardThemeId.skyCitadel,
    pieceSet: cburnettPieceSet,
    lightSquare: Color(0xFFE8ECF2),
    darkSquare: Color(0xFF6F92C0),
    frameStart: Color(0xFF526E8E),
    frameEnd: Color(0xFF1D2D42),
    labelOnLight: Color(0xFF657895),
    labelOnDark: Color(0xFFF7F3E3),
    whitePiece: Color(0xFFFFFAEF),
    blackPiece: Color(0xFF26324C),
    selected: Color(0x668DC8FF),
    selectedBorder: Color(0xFFFFD47A),
    lastMove: Color(0xD0FFE28A),
    target: Color(0x662C405D),
    captureRing: Color(0x992C405D),
    textureAlpha: 0.05,
    backdropTop: Color(0xFF2E5171),
    backdropBottom: Color(0xFF0F1C2D),
    backdropAccent: Color(0xFFFFD47A),
    backdropShadow: Color(0xFF122038),
    panelTint: Color(0xFF1D2C3E),
    backdropAsset: 'assets/chess/themes/sky-citadel.webp',
    boardTextureSet: skyCitadelBoardTextureSet,
  ),
};

BoardThemeStyle boardThemeStyle(BoardThemeId id) {
  return boardThemeStyles[id] ?? boardThemeStyles[BoardThemeId.classicWood]!;
}
