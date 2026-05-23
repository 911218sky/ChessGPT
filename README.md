# Chess AI Desktop

Windows-first Flutter desktop app for playing chess against a local Stockfish
engine, with optional LLM banter, hints, and post-game recap text.

## Docs

- [docs/design-guide.md](docs/design-guide.md)
  - UI direction, theme rules, and theme asset guidance
- [docs/image-assets.md](docs/image-assets.md)
  - Image generation and post-processing workflow

## Status

- Flutter desktop scaffold is in place
- Windows desktop is enabled
- Local `settings.json` persistence is supported
- Windows packaging and GitHub Actions are included

## Common Commands

```bash
rtk uv run python .\tools\sync_pubspec_assets.py
rtk dart format --set-exit-if-changed .
rtk flutter analyze
rtk flutter test
rtk flutter run -d windows
rtk flutter build windows --release
```

## Image Generation Setup

This repo includes a local Python 3.12 workflow for generating board
backgrounds and theme overlays.

The preferred asset path is transparent PNG generation for theme overlays
where needed. Black-background cleanup remains available for older assets, but
it is no longer the primary workflow.

1. Create a local env file:

```powershell
Copy-Item .env.example .env
```

2. Fill in:

```text
OPENAI_API_KEY=...
OPENAI_BASE_URL=https://api.openai.com/v1
OPENAI_IMAGE_MODEL=gpt-image-2
```

3. Install dependencies:

```powershell
rtk uv sync
```

4. Preview the batch:

```powershell
rtk uv run python .\tools\generate_openai_images.py --dry-run
```

5. Run the batch:

```powershell
rtk uv run python .\tools\generate_openai_images.py
```

6. Import generated assets into Flutter:

```powershell
rtk uv run python .\tools\import_generated_assets.py
rtk uv run python .\tools\sync_pubspec_assets.py
```

Useful variants:

```powershell
rtk uv run python .\tools\generate_openai_images.py --limit 3
rtk uv run python .\tools\generate_openai_images.py --only autumn-academy-overlay crystal-cavern-overlay
rtk uv run python .\tools\generate_openai_images.py --output-dir .\generated_images\manual-run
rtk uv run python .\tools\generate_openai_images.py --size 1536x1024 --quality high
```

Default batch file:

```text
tools\image_batches\chess_theme_assets.json
```

Generated output:

```text
generated_images\<timestamp>\
```

For the full workflow, see
[docs/image-assets.md](docs/image-assets.md).

When you add, remove, or rename asset subdirectories under
`assets/chess/pieces/`, re-run:

```powershell
rtk uv run python .\tools\sync_pubspec_assets.py
```

## Files Not Tracked In Git

These stay local:

- `build/`
- `.dart_tool/`
- `artifacts/`
- `windows/flutter/ephemeral/`
- `settings.json`
- `third_party/stockfish/windows/stockfish.exe`

## Stockfish Download

The bundled Windows `stockfish.exe` is not committed because it is too large
for GitHub.

Download it when needed:

```powershell
rtk powershell -ExecutionPolicy Bypass -File .\tools\download_stockfish.ps1
```

Destination:

```text
third_party\stockfish\windows\stockfish.exe
```

If the bundled binary is missing, development can still fall back to a
`stockfish` executable on `PATH`.

Environment overrides:

- `CHESS_AI_DESKTOP_STOCKFISH_RELEASE_TAG`
- `CHESS_AI_DESKTOP_STOCKFISH_ASSET_NAME`
- `CHESS_AI_DESKTOP_STOCKFISH_DESTINATION_PATH`
- `CHESS_AI_DESKTOP_APP_PUBLISHER`

## Packaging

- App icon source: `windows/runner/resources/app_icon.ico`
- Executable icon wiring: `windows/runner/Runner.rc`
- Runtime settings path: `settings.json` beside the packaged `.exe`
- Installer script: `packaging/windows/chess_ai_desktop.iss`

Local release build:

```powershell
rtk powershell -ExecutionPolicy Bypass -File .\tools\download_stockfish.ps1
rtk flutter build windows --release
```

## GitHub Actions

- `.github/workflows/ci.yml`
  - Runs formatting, `flutter analyze`, and `flutter test`
- `.github/workflows/release.yml`
  - Builds tagged Windows releases
  - Downloads Stockfish during CI
  - Produces a portable zip and installer
  - Publishes artifacts to GitHub Releases

## Clean Removal

To fully remove local app data and build output:

1. Close the app.
2. Delete local settings:

```powershell
Remove-Item ".\settings.json" -Force
```

3. Delete build output:

```powershell
Remove-Item ".\build" -Recurse -Force
```

4. Optionally clear Flutter-generated metadata:

```powershell
rtk flutter clean
```

## Notes

- Android warnings from `flutter doctor` are irrelevant for this Windows-first
  phase
- Keep the bundled asset license notice when packaging
