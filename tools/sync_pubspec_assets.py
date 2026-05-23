from __future__ import annotations

import argparse
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
PUBSPEC_PATH = PROJECT_ROOT / "pubspec.yaml"

MANAGED_START = "    # BEGIN GENERATED ASSETS: run `rtk uv run python .\\tools\\sync_pubspec_assets.py`"
MANAGED_END = "    # END GENERATED ASSETS"

IGNORED_CHILD_DIRECTORIES = {"generated_sources"}


def collect_child_directories(root: Path) -> list[str]:
    entries = [
        path.relative_to(PROJECT_ROOT).as_posix() + "/"
        for path in sorted(root.iterdir(), key=lambda item: item.name)
        if path.is_dir() and path.name not in IGNORED_CHILD_DIRECTORIES
    ]
    return entries


def collect_asset_sections() -> list[tuple[str, list[str]]]:
    return [
        (
            "Theme previews.",
            [
                "assets/chess/themes/",
            ],
        ),
        (
            "Board texture sets.",
            collect_child_directories(PROJECT_ROOT / "assets" / "chess" / "board_textures"),
        ),
        (
            "Piece sets.",
            collect_child_directories(PROJECT_ROOT / "assets" / "chess" / "pieces"),
        ),
    ]


def render_managed_block() -> str:
    lines = [MANAGED_START]
    for section_title, entries in collect_asset_sections():
        lines.append(f"    # {section_title}")
        lines.extend(f"    - {entry}" for entry in entries)
        lines.append("")
    if lines[-1] == "":
        lines.pop()
    lines.append(MANAGED_END)
    return "\n".join(lines)


def replace_managed_block(pubspec_text: str, managed_block: str) -> str:
    start_index = pubspec_text.find(MANAGED_START)
    end_index = pubspec_text.find(MANAGED_END)
    if start_index == -1 or end_index == -1:
        raise RuntimeError("Managed asset block markers were not found in pubspec.yaml.")
    end_index += len(MANAGED_END)
    return pubspec_text[:start_index] + managed_block + pubspec_text[end_index:]


def sync_pubspec(pubspec_path: Path) -> bool:
    original_text = pubspec_path.read_text(encoding="utf-8")
    updated_text = replace_managed_block(original_text, render_managed_block())
    if updated_text == original_text:
        return False
    pubspec_path.write_text(updated_text + ("\n" if not updated_text.endswith("\n") else ""), encoding="utf-8")
    return True


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Sync the managed Flutter asset list in pubspec.yaml from the asset tree."
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Exit with a non-zero status if pubspec.yaml is out of sync.",
    )
    parser.add_argument(
        "--pubspec",
        type=Path,
        default=PUBSPEC_PATH,
        help="Optional pubspec.yaml path override.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    pubspec_path = args.pubspec.resolve()
    original_text = pubspec_path.read_text(encoding="utf-8")
    updated_text = replace_managed_block(original_text, render_managed_block())

    if args.check:
        if updated_text != original_text:
            print("[out-of-sync] pubspec.yaml managed assets block needs regeneration.")
            return 1
        print("[ok] pubspec.yaml managed assets block is in sync.")
        return 0

    changed = sync_pubspec(pubspec_path)
    if changed:
        print(f"[updated] {pubspec_path}")
    else:
        print(f"[unchanged] {pubspec_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
