# Chess AI Desktop

A Windows-first Flutter desktop chess app with a local Stockfish engine, optional LLM commentary, coach hints, and themeable boards.

## What This Project Does

- Play chess against a local AI engine
- Show coach-style hints and move feedback
- Add optional opponent banter and post-move commentary through an LLM
- Let the player switch board themes, AI personality, coach personality, and engine settings
- Save local preferences in `settings.json`

This is a desktop game project first. The board should stay central, the right panel should stay practical, and the app should feel like a polished chess product rather than a demo tool.

## Project Status

Current repo state:

- Flutter desktop app is working
- Windows desktop target is enabled
- Stockfish integration is wired in
- LLM provider settings are configurable
- Packaging and CI workflows are included

## Quick Start

### 1. Install prerequisites

- Flutter
- Dart
- Python 3.12
- `uv`

### 2. Install dependencies

```powershell
rtk flutter pub get
rtk uv sync
```

### 3. Download Stockfish for Windows

```powershell
rtk powershell -ExecutionPolicy Bypass -File .\tools\download_stockfish.ps1
```

Expected output path:

```text
third_party\stockfish\windows\stockfish.exe
```

If the bundled binary is missing, the app can still fall back to a `stockfish` executable found on `PATH`.

### 4. Run the app

```powershell
rtk flutter run -d windows
```

## Common Commands

```powershell
rtk flutter analyze
rtk flutter test
rtk flutter build windows --release
rtk uv run python .\tools\sync_pubspec_assets.py
```

## Key Docs

- [docs/design-guide.md](docs/design-guide.md)
  - UI direction, layout rules, and theme constraints
- [docs/image-assets.md](docs/image-assets.md)
  - Image generation, import, and asset sync workflow
- [AGENTS.md](AGENTS.md)
  - Project-specific working rules for agents and collaborators

## Main Source Entry Points

- [lib/src/app.dart](lib/src/app.dart)
  - Main app shell, board workspace, backdrop, and layout
- [lib/src/controllers/game_controller.dart](lib/src/controllers/game_controller.dart)
  - Match flow, AI turns, hints, commentary, and state updates
- [lib/src/widgets/control_panel.dart](lib/src/widgets/control_panel.dart)
  - Right-side control panel
- [lib/src/widgets/chess_board.dart](lib/src/widgets/chess_board.dart)
  - Board rendering and interaction
- [lib/src/models/session_config.dart](lib/src/models/session_config.dart)
  - Match settings and persisted user preferences
- [lib/src/theme/board_theme.dart](lib/src/theme/board_theme.dart)
  - Theme catalog and visual registration

## Asset Workflow

Use the Python tools when you add or refresh board images.

### Generate images

```powershell
rtk uv run python .\tools\generate_openai_images.py --dry-run
rtk uv run python .\tools\generate_openai_images.py
```

### Import images into Flutter assets

```powershell
rtk uv run python .\tools\import_generated_assets.py
rtk uv run python .\tools\sync_pubspec_assets.py
```

Default batch file:

```text
tools\image_batches\chess_theme_assets.json
```

Generated output:

```text
generated_images\<timestamp>\
```

Before changing theme visuals, read:

- [docs/design-guide.md](docs/design-guide.md)
- [docs/image-assets.md](docs/image-assets.md)

## LLM Image Setup

Create `.env` from the example:

```powershell
Copy-Item .env.example .env
```

Set at least:

```text
OPENAI_API_KEY=...
OPENAI_BASE_URL=https://api.openai.com/v1
OPENAI_IMAGE_MODEL=gpt-image-2
```

## Packaging

Release build:

```powershell
rtk powershell -ExecutionPolicy Bypass -File .\tools\download_stockfish.ps1
rtk flutter build windows --release
```

Packaging-related files:

- `packaging/windows/chess_ai_desktop.iss`
- `windows/runner/resources/app_icon.ico`
- `windows/runner/Runner.rc`

## Local Files Not Tracked In Git

These are expected to stay local:

- `build/`
- `.dart_tool/`
- `artifacts/`
- `generated_images/`
- `windows/flutter/ephemeral/`
- `settings.json`
- `third_party/stockfish/windows/stockfish.exe`

## CI

- `.github/workflows/ci.yml`
  - Runs formatting, analysis, and tests
- `.github/workflows/release.yml`
  - Builds tagged Windows releases and release artifacts

## Notes

- This repo is Windows-first
- Android warnings from `flutter doctor` are not relevant for the current target
- When asset folders under `assets/chess/pieces/` change, rerun:

```powershell
rtk uv run python .\tools\sync_pubspec_assets.py
```
