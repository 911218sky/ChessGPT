# chess_ai_desktop Agent Guide

Use this file as the project-level entry point when working inside `chess_ai_desktop`.

Start here, then open the task-relevant docs and source files.

## Read In This Order

1. `../AGENTS.md`
   - Workspace-wide rules
   - The required three-phase workflow
   - `rtk` command expectations
2. `docs/design-guide.md`
   - UI direction
   - Layout and theme rules
   - What a change must preserve
3. `docs/image-assets.md`
   - Theme image generation
   - Import and asset sync workflow

## What This Project Is

This is a Windows-first Flutter desktop chess app.

Core product areas:

- Local Stockfish play
- Coach hints and board analysis
- Optional LLM commentary and banter
- Board themes and board textures
- Match settings and local preference persistence

When in doubt, optimize for the actual play experience:

- Keep the board dominant
- Keep the right panel useful
- Keep the app feeling like a chess game, not a settings dashboard

## Main Code Map

Open these first for most tasks:

- `lib/src/app.dart`
  - Main layout, backdrop, board area, and control panel wiring
- `lib/src/controllers/game_controller.dart`
  - Match lifecycle, AI turns, hints, commentary, and persisted settings flow
- `lib/src/widgets/control_panel.dart`
  - Right-side panel container
- `lib/src/widgets/control_panel/bots_tab.dart`
  - Opponent role, personality, coach, and related selection UI
- `lib/src/widgets/chess_board.dart`
  - Board rendering, interaction, move targets, and selection feedback
- `lib/src/models/session_config.dart`
  - Match configuration and persisted user preferences
- `lib/src/theme/board_theme.dart`
  - Theme registry, labels, and asset mapping
- `lib/src/services/stockfish_service.dart`
  - Engine process setup and hardware/resource defaults

## Task Routing

### UI changes

Read first:

- `docs/design-guide.md`
- `lib/src/app.dart`
- `lib/src/widgets/control_panel.dart`
- `lib/src/widgets/chess_board.dart`

Check before finishing:

- Board is still the largest visual element
- Right panel is still the main interaction area
- New copy stays short in English and Traditional Chinese
- New decoration does not reduce board readability

### Theme or image changes

Read first:

- `docs/design-guide.md`
- `docs/image-assets.md`
- `lib/src/theme/board_theme.dart`

Rules:

- Backdrops live in `assets/chess/themes/`
- Piece assets live in `assets/chess/pieces/`
- Generated theme backgrounds stay 16:9
- Keep the center calm enough for the board and panel
- Do not add text, logos, watermarks, people, animals, or chess pieces into backdrops

When adding a new theme, update:

- `BoardThemeId`
- `BoardThemeId.label`
- `BoardThemeId.localizedLabel`
- `boardThemeStyles`
- `docs/design-guide.md`

### Gameplay, AI, or commentary changes

Read first:

- `lib/src/controllers/game_controller.dart`
- `lib/src/models/session_config.dart`
- `lib/src/services/stockfish_service.dart`
- related tests under `test/controllers/`, `test/services/`, and `test/widgets/`

Check for:

- unnecessary re-analysis
- incorrect reset behavior when settings change
- role/personality separation
- English and Traditional Chinese copy quality
- accidental mojibake or encoding damage

## Required Workflow

For medium or large tasks:

1. Start with `【分析問題】`
2. Then `【制定方案】`
3. Then `【執行方案】`

Do not skip straight to implementation unless the task is truly small and low risk.

## Required Validation

After implementation, run at least:

```powershell
rtk dart format <changed dart files>
rtk flutter analyze
rtk flutter test
```

Notes:

- If you only changed docs or non-Dart files, skip meaningless formatting commands, but still run the relevant project validation unless the user says otherwise
- Prefer focused tests during iteration, then run the full suite before finishing

## Things You Must Not Do

- Do not `git commit`
- Do not `git push`
- Do not start a development server unless the user explicitly asks
- Do not invent a new UI style without checking the design guide
- Do not change theme asset conventions without updating the docs that define them
- Do not overwrite unrelated dirty worktree changes

## Practical Reminders

- Use `rtk` for shell commands
- Prefer existing theme tokens, helpers, and UI patterns over new abstractions
- Keep user-facing copy concise
- Preserve Traditional Chinese readability when editing localized strings
- When touching assets under `assets/chess/pieces/`, rerun:

```powershell
rtk uv run python .\tools\sync_pubspec_assets.py
```
