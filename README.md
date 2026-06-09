# ChessGPT

A Flutter chess app with desktop and web builds, a local Stockfish engine on desktop, optional LLM commentary, coach hints, and themeable boards.

## What This Project Does

- Play chess against a local AI engine on desktop
- Show coach-style hints and move feedback
- Add optional opponent banter and post-move commentary through an LLM
- Let the player switch board themes, AI personality, coach personality, and engine settings
- Save local preferences in `settings.json`
- Run as a desktop app or as a local Docker web service

The board should stay central, the right panel should stay practical, and the app should feel like a polished chess product rather than a demo tool.

## Project Status

Current repo state:

- Flutter desktop app is working
- Flutter web target is enabled
- Windows desktop target is enabled
- Stockfish integration is wired in
- LLM provider settings are configurable
- Local Docker web service packaging is included
- Packaging and CI workflows are included

Web note: browser builds run in the user's browser and use Stockfish.js 17.1 lite single-thread WASM for chess AI. Desktop keeps the local Stockfish process and local settings file flow.

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

### 4. Run the desktop app

```powershell
rtk flutter run -d windows
```

### 5. Run the web app locally without Docker

```bash
. /home/sbplab/sky/setup_env.sh
flutter run -d web-server --web-port 5432
```

Open:

```text
http://localhost:5432
```

## Docker Web Service

The recommended web flow is Docker Compose. By default it pulls the remote GHCR
image, serves the Flutter web app on port `5432`, and proxies `/v1/*` through
nginx so the LLM provider key stays on the local machine instead of being
embedded in browser assets.

Create a local `.env` file from the example:

```bash
cp .env.example .env
```

Then edit `.env` and set:

```text
NGINX_LLM_PROXY_AUTHORIZATION=Bearer <provider-api-key>
```

Start the service:

```bash
docker compose up
```

Open:

```text
http://localhost:5432
```

Stop the service:

```bash
docker compose down
```

The container exposes `/healthz` for health checks:

```bash
curl http://localhost:5432/healthz
```

The Docker image serves static Flutter web files through nginx. It does not run Stockfish on the server; the chess engine runs as Stockfish 17.1 WASM inside each user's browser.

Docker Compose uses `/v1` as the default LLM base URL. The nginx container proxies `/v1/*` to `https://www.inroi.shop/v1/*` and can inject the provider authorization header server-side:

```bash
NGINX_LLM_PROXY_AUTHORIZATION='Bearer <provider-api-key>' docker compose up
```

Do not put the real provider key in Dockerfile build args or Flutter `--dart-define` values. Build-time Flutter web values are visible in browser assets.

If you need to test a local Dockerfile change, build and run it manually:

```bash
docker build -t chessgpt-web:local .
```

```bash
docker run --rm -p 5432:80 chessgpt-web:local
```

Optional Docker LLM environment values:

```text
WEB_LLM_DEFAULT_MODEL=GPT-5.4
NGINX_LLM_PROXY_TARGET=https://www.inroi.shop/v1/
NGINX_LLM_PROXY_AUTHORIZATION=Bearer <provider-api-key>
```

### Remote Docker Image

GitHub Actions automatically builds and pushes the Docker image to GHCR on
pushes to `main`, `web-support`, and version tags:

```text
ghcr.io/911218sky/chessgpt:web-support
```

Run the remote image locally on port `5432`:

```bash
docker run --rm \
  -p 5432:80 \
  -e NGINX_LLM_PROXY_AUTHORIZATION='Bearer <provider-api-key>' \
  ghcr.io/911218sky/chessgpt:web-support
```

## LLM Secrets

The LLM panel has a Credentials selector:

- `Use default`: the app uses configured defaults. In the Docker web service,
  this means the browser calls same-origin `/v1`, nginx forwards the request,
  and nginx injects `NGINX_LLM_PROXY_AUTHORIZATION`. On desktop, the app reads
  `CHESS_AI_LLM_API_KEY` first, then the provider-specific environment variable
  such as `OPENAI_API_KEY`, `GEMINI_API_KEY`, `KIMI_API_KEY`, or
  `ANTHROPIC_API_KEY`.
- `Enter API key`: the app sends only the API key typed by the user.

The proxy should expose OpenAI-compatible endpoints:

```text
GET  /v1/models
POST /v1/chat/completions
```

Because the Docker web app calls same-origin `/v1`, browser CORS is not needed
for local use. nginx handles the provider request from inside the container.

## Web ChessGPT

The web build bundles Stockfish.js 17.1 lite single-thread WASM in:

```text
web/stockfish/
```

This is a real Stockfish chess engine running through a browser Web Worker, not an LLM move guesser and not a legal-move fallback. The lite single-thread build is used because it works without cross-origin isolation headers.

LLM features are separate from move selection. The LLM can provide commentary or coach-style text, while Stockfish chooses and evaluates chess moves.

Stockfish.js is GPLv3 licensed. The bundled license and authors files are included in `web/stockfish/Copying.txt` and `web/stockfish/AUTHORS`.

## Common Commands

```powershell
rtk flutter analyze
rtk flutter test
rtk flutter build windows --release
rtk flutter build web --release
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

Windows release build:

```powershell
rtk powershell -ExecutionPolicy Bypass -File .\tools\download_stockfish.ps1
rtk flutter build windows --release
```

Web container build:

```bash
docker build -t chessgpt-web .
docker run --rm -p 5432:80 chessgpt-web
docker compose up -d
```

Packaging-related files:

- `packaging/windows/chessgpt.iss`
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
- `.github/workflows/docker.yml`
  - Builds the Flutter web Docker image
  - Pushes images to GitHub Container Registry on branch and tag pushes
- `.github/workflows/release.yml`
  - Builds tagged Windows releases and release artifacts

## Notes

- This repo supports Windows desktop and Flutter web
- Android warnings from `flutter doctor` are not relevant for the current target
- When asset folders under `assets/chess/pieces/` change, rerun:

```powershell
rtk uv run python .\tools\sync_pubspec_assets.py
```
