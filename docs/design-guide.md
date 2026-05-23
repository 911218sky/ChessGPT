# Chess AI Desktop Design Guide

This is the main design document for `chess_ai_desktop`.
Keep UI, board themes, and generated assets aligned with this file.

## Product Direction

The app should feel like a polished desktop chess game, not a developer tool.

Target feel:

- Game-like
- Focused
- Premium
- Fast to scan
- Character-driven

Avoid:

- SaaS dashboard styling
- Dense engine-analysis layouts
- Marketing page patterns
- Generic Material demo UI

## Layout Rules

- Keep the chess board as the largest visual element
- Keep the right panel as the main control area
- On wide windows, use a two-column layout
- On narrow windows, stack board first and controls second
- Keep the main `Play` action large and obvious

## Visual Rules

- Keep the app dark and warm
- Use green as the main action color
- Reuse `AppColors`, `AppRadii`, and existing panel helpers before adding new
  styling
- Keep labels short and readable
- Keep the board playable on every theme

## Chess Board Rules

- Preserve `AspectRatio(1)`
- Keep coordinates and move highlights readable
- Do not let decoration reduce board size
- Do not let overlays block move targets or selected-square feedback

## Theme Asset Rules

- Store backdrops in `assets/chess/themes/`
- Keep background images in 16:9 landscape
- Keep detail near the edges and the center calm
- Do not include text, logos, watermarks, people, animals, or chess pieces in
  backdrops
- Theme visuals should support the board, not compete with it

## Theme Prompt Formula

Use a short prompt structure instead of a long custom prompt for every theme:

```text
Create a 16:9 stylized background for a Flutter desktop chess app.
Scene: <theme environment>.
Style: polished digital illustration, premium strategy game mood.
Composition: calm low-contrast center for the chess board and right panel,
detail pushed toward the edges.
Include: subtle chess-board geometry in the environment.
Do not include: text, logos, watermark, people, animals, UI mockups, or chess pieces.
Palette: <theme palette>.
Lighting: <theme mood>.
```

## Current Theme Directions

- `classicWood`
  - Warm chess club, wood paneling, amber light
- `tournamentGreen`
  - Quiet tournament hall, green felt accents, restrained lighting
- `oceanSlate`
  - Cool coastal stone terrace, mist and slate textures
- `walnut`
  - Dark study, walnut panels, evening lamp light
- `midnight`
  - Observatory mood, moonlight, deep navy tones
- `jungleCanopy`
  - Lush clearing, filtered sunlight, mossy stone
- `coralReef`
  - Underwater-inspired stone hall, blue glow, coral silhouettes
- `desertSun`
  - Sandstone courtyard, sunset light, distant dunes
- `frostTemple`
  - Ice temple, pale cyan glow, snowy distance
- `lavaForge`
  - Basalt forge, molten edges, dark center
- `sakuraGarden`
  - Garden terrace, lantern silhouettes, soft blossom tones
- `neonCity`
  - Rainy rooftop, neon edge light, futuristic skyline shapes
- `royalMarble`
  - Marble palace, gold trim, refined daylight
- `autumnAcademy`
  - Old courtyard, autumn leaves, warm academic mood
- `crystalCavern`
  - Luminous cavern, crystal edges, cool glow
- `skyCitadel`
  - Floating stone platform, cloudscape, sunrise light

## New Theme Checklist

1. Add the image under `assets/chess/themes/<theme-slug>.png`
2. Update `BoardThemeId`
3. Add English and Traditional Chinese labels
4. Add the `BoardThemeStyle` entry
5. Update this guide with the theme direction
6. Run:

```bash
dart format lib/src/theme/board_theme.dart
flutter analyze
flutter test
```

## UI Change Checklist

Before finalizing UI work, check:

- Is the board still dominant?
- Is the right panel still the main interaction hub?
- Is the `Play` action still obvious?
- Are controls grouped sensibly?
- Are existing theme tokens reused?
- Is new user-facing copy concise in English and Traditional Chinese?
