# chess_ai_desktop Agent Guide

This file is the entry point for the `chess_ai_desktop` subproject.
Read this first, then open the task-relevant docs and source files.

## Read First

1. `../AGENTS.md`
   - Workspace-wide rules and the three-phase workflow
2. `docs/design-guide.md`
   - UI direction, theme rules, and theme asset guidance
3. `docs/image-assets.md`
   - Image generation and post-processing workflow

## Common Source Entry Points

- `lib/src/app.dart`
  - Main layout, backdrop scene, board workspace, and player/opponent info
- `lib/src/theme/board_theme.dart`
  - Board theme catalog and theme asset registration
- `lib/src/widgets/chess_board.dart`
  - Board squares, pieces, move hints, and selection state
- `lib/src/widgets/control_panel.dart`
  - Right-side control panel and theme picker UI
- `lib/src/controllers/game_controller.dart`
  - Game state and interaction flow
- `lib/src/models/session_config.dart`
  - Match configuration, including `boardTheme`

## Theme And Asset Rules

- Store scene backdrops in `assets/chess/themes/`
- Store piece assets in `assets/chess/pieces/`
- Keep generated theme images 16:9, English-free, watermark-free, and low
  distraction in the center
- When adding a new theme, update:
  - `BoardThemeId`
  - `BoardThemeId.label`
  - `BoardThemeId.localizedLabel`
  - `boardThemeStyles`
  - `docs/design-guide.md`

## Workflow Requirements

- For medium or large tasks, start with `【分析問題】`
- Before changing UI, check `docs/design-guide.md`
- Before changing theme assets, check `docs/design-guide.md` and
  `docs/image-assets.md`
- After implementation, run at least:
  - `dart format <changed dart files>`
  - `flutter analyze`
  - `flutter test`
- Do not run `git commit` or `git push` unless explicitly asked
- Do not start a development server unless explicitly asked
