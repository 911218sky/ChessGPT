from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def remove_dark_background(image: Image.Image, threshold: int) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    width, height = rgba.size
    visited = set()
    stack: list[tuple[int, int]] = []

    def maybe_enqueue(x: int, y: int) -> None:
        if not (0 <= x < width and 0 <= y < height):
            return
        if (x, y) in visited:
            return
        r, g, b, a = pixels[x, y]
        if a == 0:
            visited.add((x, y))
            return
        if r > threshold or g > threshold or b > threshold:
            return
        visited.add((x, y))
        stack.append((x, y))

    for x in range(width):
        maybe_enqueue(x, 0)
        maybe_enqueue(x, height - 1)
    for y in range(height):
        maybe_enqueue(0, y)
        maybe_enqueue(width - 1, y)

    while stack:
        x, y = stack.pop()
        r, g, b, _ = pixels[x, y]
        pixels[x, y] = (r, g, b, 0)
        for nx, ny in (
            (x - 1, y),
            (x + 1, y),
            (x, y - 1),
            (x, y + 1),
            (x - 1, y - 1),
            (x + 1, y - 1),
            (x - 1, y + 1),
            (x + 1, y + 1),
        ):
            maybe_enqueue(nx, ny)
    return rgba


def crop_transparent_border(image: Image.Image, padding: int) -> Image.Image:
    bbox = image.getbbox()
    if bbox is None:
        return image
    left, top, right, bottom = bbox
    left = max(0, left - padding)
    top = max(0, top - padding)
    right = min(image.width, right + padding)
    bottom = min(image.height, bottom + padding)
    return image.crop((left, top, right, bottom))


def keep_largest_alpha_component(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    width, height = rgba.size
    pixels = rgba.load()
    visited = set()
    largest_component: list[tuple[int, int]] = []

    for y in range(height):
        for x in range(width):
            if (x, y) in visited or pixels[x, y][3] == 0:
                continue
            stack = [(x, y)]
            component: list[tuple[int, int]] = []
            visited.add((x, y))
            while stack:
                cx, cy = stack.pop()
                component.append((cx, cy))
                for nx, ny in (
                    (cx - 1, cy),
                    (cx + 1, cy),
                    (cx, cy - 1),
                    (cx, cy + 1),
                ):
                    if not (0 <= nx < width and 0 <= ny < height):
                        continue
                    if (nx, ny) in visited:
                        continue
                    if pixels[nx, ny][3] == 0:
                        continue
                    visited.add((nx, ny))
                    stack.append((nx, ny))
            if len(component) > len(largest_component):
                largest_component = component

    if not largest_component:
        return rgba

    keep = set(largest_component)
    for y in range(height):
        for x in range(width):
            if pixels[x, y][3] == 0:
                continue
            if (x, y) not in keep:
                r, g, b, _ = pixels[x, y]
                pixels[x, y] = (r, g, b, 0)
    return rgba


def split_sheet(
    image: Image.Image,
    output_dir: Path,
    stem: str,
    cols: int,
    rows: int,
    crop_padding: int,
) -> list[Path]:
    ensure_dir(output_dir)
    tile_width = image.width // cols
    tile_height = image.height // rows
    outputs: list[Path] = []
    index = 1
    for row in range(rows):
        for col in range(cols):
            tile = image.crop(
                (
                    col * tile_width,
                    row * tile_height,
                    (col + 1) * tile_width,
                    (row + 1) * tile_height,
                )
            )
            tile = keep_largest_alpha_component(tile)
            tile = crop_transparent_border(tile, crop_padding)
            out_path = output_dir / f"{stem}-{index:02d}.png"
            tile.save(out_path)
            outputs.append(out_path)
            index += 1
    return outputs


def extract_board_texture_halves(image: Image.Image, output_dir: Path) -> list[Path]:
    ensure_dir(output_dir)
    mid_x = image.width // 2
    light = image.crop((0, 0, mid_x, image.height))
    dark = image.crop((mid_x, 0, image.width, image.height))
    light_path = output_dir / "light.png"
    dark_path = output_dir / "dark.png"
    light.save(light_path)
    dark.save(dark_path)
    return [light_path, dark_path]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Post-process generated chess assets: remove dark backgrounds, crop, and split sheets."
    )
    parser.add_argument("input", type=Path, help="Input PNG file.")
    parser.add_argument("--output", type=Path, default=None, help="Optional output PNG path.")
    parser.add_argument(
        "--remove-dark-bg",
        action="store_true",
        help="Convert near-black pixels to transparency.",
    )
    parser.add_argument(
        "--dark-threshold",
        type=int,
        default=16,
        help="RGB threshold used by --remove-dark-bg.",
    )
    parser.add_argument("--crop", action="store_true", help="Crop transparent border.")
    parser.add_argument(
        "--crop-padding",
        type=int,
        default=8,
        help="Padding kept around the cropped content.",
    )
    parser.add_argument("--split-cols", type=int, default=None, help="Columns for sheet split.")
    parser.add_argument("--split-rows", type=int, default=None, help="Rows for sheet split.")
    parser.add_argument(
        "--split-output-dir",
        type=Path,
        default=None,
        help="Directory for split tiles. Required when splitting.",
    )
    parser.add_argument(
        "--extract-board-halves",
        action="store_true",
        help="Split a two-half board texture sheet into light.png and dark.png.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    image = Image.open(args.input)

    if args.remove_dark_bg:
        image = remove_dark_background(image, args.dark_threshold)

    if args.crop:
        image = crop_transparent_border(image, args.crop_padding)

    output_path = args.output or args.input.with_name(f"{args.input.stem}-processed.png")
    ensure_dir(output_path.parent)
    image.save(output_path)
    print(f"[saved] {output_path}")

    if (args.split_cols is None) ^ (args.split_rows is None):
        raise RuntimeError("--split-cols and --split-rows must be provided together.")

    if args.split_cols is not None and args.split_rows is not None:
        if args.split_output_dir is None:
            raise RuntimeError("--split-output-dir is required when splitting.")
        outputs = split_sheet(
            image=image,
            output_dir=args.split_output_dir,
            stem=output_path.stem,
            cols=args.split_cols,
            rows=args.split_rows,
            crop_padding=args.crop_padding,
        )
        print(f"[split] wrote {len(outputs)} tiles to {args.split_output_dir}")

    if args.extract_board_halves:
        if args.split_output_dir is None:
            raise RuntimeError("--split-output-dir is required for --extract-board-halves.")
        outputs = extract_board_texture_halves(image=image, output_dir=args.split_output_dir)
        print(f"[board-halves] wrote {len(outputs)} files to {args.split_output_dir}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
