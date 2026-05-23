from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from PIL import Image

from process_generated_images import ensure_dir, extract_board_texture_halves


PROJECT_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_PLAN = (
    PROJECT_ROOT / "tools" / "image_batches" / "chess_theme_asset_imports.json"
)


def load_plan(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def project_path(value: str) -> Path:
    return (PROJECT_ROOT / value).resolve()


def import_board_texture_sheet(job: dict[str, Any]) -> list[Path]:
    input_path = project_path(job["input"])
    output_dir = project_path(job["output_dir"])
    image = Image.open(input_path)
    return extract_board_texture_halves(image=image, output_dir=output_dir)


def import_copy(job: dict[str, Any]) -> list[Path]:
    input_path = project_path(job["input"])
    output_path = project_path(job["output"])
    ensure_dir(output_path.parent)
    output_path.write_bytes(input_path.read_bytes())
    return [output_path]


def run_job(job: dict[str, Any]) -> list[Path]:
    kind = job["kind"]
    if kind == "board_texture_sheet":
        return import_board_texture_sheet(job)
    if kind == "copy":
        return import_copy(job)
    raise RuntimeError(f"Unsupported import kind: {kind}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Import generated image assets into the Flutter assets tree."
    )
    parser.add_argument(
        "--plan",
        type=Path,
        default=DEFAULT_PLAN,
        help="Path to the import plan JSON file.",
    )
    parser.add_argument(
        "--only",
        nargs="*",
        default=None,
        help="Optional list of job ids to run.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    plan = load_plan(args.plan)
    jobs: list[dict[str, Any]] = plan.get("jobs", [])
    if args.only:
        selected = set(args.only)
        jobs = [job for job in jobs if job["id"] in selected]

    if not jobs:
        raise RuntimeError("No import jobs matched the current filters.")

    for job in jobs:
        outputs = run_job(job)
        print(f"[imported] {job['id']} -> {len(outputs)} file(s)")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
