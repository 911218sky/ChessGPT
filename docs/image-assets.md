# Image Assets Workflow

Use this document for local generation and cleanup of chess theme images.

Primary workflow:

- Generate theme backdrops
- Generate board texture sheets
- Import selected assets into the Flutter asset tree
- Regenerate the managed `pubspec.yaml` asset block

## Prerequisites

- Python 3.12
- `uv`
- A local `.env` file

Example:

```text
OPENAI_API_KEY=...
OPENAI_BASE_URL=https://api.openai.com/v1
OPENAI_IMAGE_MODEL=gpt-image-2
```

Install dependencies:

```powershell
rtk uv sync
```

## Generate Images

Default batch file:

```text
tools\image_batches\chess_theme_assets.json
```

Preview the batch:

```powershell
rtk uv run python .\tools\generate_openai_images.py --dry-run
```

Run a small batch:

```powershell
rtk uv run python .\tools\generate_openai_images.py --limit 3 --workers 3
```

Run selected jobs:

```powershell
rtk uv run python .\tools\generate_openai_images.py --only autumn-academy-background sky-citadel-board-texture-sheet
```

Set size or quality only when needed:

```powershell
rtk uv run python .\tools\generate_openai_images.py --size 1536x1024 --quality high
```

Output:

```text
generated_images\<timestamp>\
generated_images\<timestamp>\manifest.json
```

## Post-Process Images

Use `tools\process_generated_images.py`.

Board texture sheets can be split into light and dark square textures during import. For one-off processing, run:

```powershell
rtk uv run python .\tools\process_generated_images.py `
  .\generated_images\20260505-181517\board-textures\autumn-academy-board-texture-sheet.png `
  --extract-board-textures `
  --output-dir .\assets\chess\board_textures\autumn_academy
```

## Import Into Flutter Assets

Use the plan-driven importer:

```powershell
rtk uv run python .\tools\import_generated_assets.py
```

Run selected import jobs only:

```powershell
rtk uv run python .\tools\import_generated_assets.py --only theme-autumn-academy board-autumn-academy
```

Default import plan:

```text
tools\image_batches\chess_theme_asset_imports.json
```

## Recommended Flow

1. Generate raw images into `generated_images`
2. Keep only usable outputs
3. Import selected backdrops and board textures with `import_generated_assets.py`
4. Regenerate the managed `pubspec.yaml` asset block with `sync_pubspec_assets.py`
5. Wire theme references into Flutter and run validation

Sync command:

```powershell
rtk uv run python .\tools\sync_pubspec_assets.py
```
