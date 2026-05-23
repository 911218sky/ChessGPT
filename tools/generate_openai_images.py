from __future__ import annotations

import argparse
import base64
import json
import os
import re
import sys
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any

from dotenv import load_dotenv
from openai import OpenAI


PROJECT_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_BATCH_FILE = PROJECT_ROOT / "tools" / "image_batches" / "chess_theme_assets.json"
DEFAULT_OUTPUT_ROOT = PROJECT_ROOT / "generated_images"


def slugify(value: str) -> str:
    value = value.strip().lower()
    value = re.sub(r"[^a-z0-9]+", "-", value)
    value = re.sub(r"-{2,}", "-", value)
    return value.strip("-") or "image"


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


@dataclass
class ImageJob:
    slug: str
    prompt: str
    category: str = "misc"
    filename_prefix: str | None = None
    model: str | None = None
    size: str | None = None
    quality: str | None = None
    background: str | None = None
    n: int | None = None

    @classmethod
    def from_dict(cls, data: dict[str, Any], defaults: dict[str, Any]) -> "ImageJob":
        merged = {**defaults, **data}
        return cls(
            slug=slugify(str(merged["slug"])),
            prompt=str(merged["prompt"]).strip(),
            category=slugify(str(merged.get("category", "misc"))),
            filename_prefix=slugify(str(merged.get("filename_prefix") or merged["slug"])),
            model=merged.get("model"),
            size=merged.get("size"),
            quality=merged.get("quality"),
            background=merged.get("background"),
            n=int(merged.get("n", 1)),
        )


def read_env() -> dict[str, str]:
    load_dotenv(PROJECT_ROOT / ".env")
    api_key = os.getenv("OPENAI_API_KEY", "").strip()
    base_url = os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1").strip()
    image_model = os.getenv("OPENAI_IMAGE_MODEL", "gpt-image-2").strip()
    return {
        "api_key": api_key,
        "base_url": base_url,
        "image_model": image_model,
    }


def build_client(env: dict[str, str]) -> OpenAI:
    if not env["api_key"]:
        raise RuntimeError(
            "OPENAI_API_KEY is missing. Fill chess_ai_desktop/.env before running."
        )
    return OpenAI(api_key=env["api_key"], base_url=env["base_url"])


def response_item_to_png_bytes(item: Any) -> bytes:
    b64_json = getattr(item, "b64_json", None)
    if b64_json:
        return base64.b64decode(b64_json)

    url = getattr(item, "url", None)
    if url:
        with urllib.request.urlopen(url) as response:
            return response.read()

    raise RuntimeError("Image response did not contain b64_json or url data.")


def generate_job(
    client: OpenAI | None,
    job: ImageJob,
    output_dir: Path,
    env: dict[str, str],
    size_override: str | None,
    quality_override: str | None,
    dry_run: bool,
) -> dict[str, Any]:
    category_dir = output_dir / job.category
    ensure_dir(category_dir)

    payload: dict[str, Any] = {
        "model": job.model or env["image_model"],
        "prompt": job.prompt,
        "background": job.background or "opaque",
        "n": job.n or 1,
    }

    resolved_size = size_override if size_override is not None else job.size
    resolved_quality = quality_override if quality_override is not None else job.quality
    if resolved_size:
        payload["size"] = resolved_size
    if resolved_quality:
        payload["quality"] = resolved_quality

    print(f"[generate] {job.slug} -> {job.category} ({payload['model']}, n={payload['n']})")

    if dry_run:
        return {
            "slug": job.slug,
            "category": job.category,
            "payload": payload,
            "files": [],
            "dry_run": True,
        }

    expected_files = []
    for index in range(1, (job.n or 1) + 1):
        suffix = f"-{index:02d}" if (job.n or 1) > 1 else ""
        expected_files.append(category_dir / f"{job.filename_prefix}{suffix}.png")
    if all(path.exists() for path in expected_files):
        return {
            "slug": job.slug,
            "category": job.category,
            "payload": payload,
            "files": [str(path.relative_to(PROJECT_ROOT)) for path in expected_files],
            "skipped": True,
        }

    if client is None:
        client = build_client(env)

    response = None
    for attempt in range(1, 4):
        try:
            response = client.images.generate(**payload)
            break
        except Exception:
            if attempt == 3:
                raise
            time.sleep(60)
    if response is None:
        raise RuntimeError(f"Image generation failed for {job.slug}")

    files: list[str] = []
    for index, item in enumerate(response.data, start=1):
        suffix = f"-{index:02d}" if len(response.data) > 1 else ""
        filename = f"{job.filename_prefix}{suffix}.png"
        file_path = category_dir / filename
        file_path.write_bytes(response_item_to_png_bytes(item))
        files.append(str(file_path.relative_to(PROJECT_ROOT)))

    return {
        "slug": job.slug,
        "category": job.category,
        "payload": payload,
        "files": files,
    }


def load_jobs(batch_path: Path) -> list[ImageJob]:
    batch_data = load_json(batch_path)
    defaults = batch_data.get("defaults", {})
    jobs = batch_data.get("jobs", [])
    if not jobs:
        raise RuntimeError(f"No jobs found in batch file: {batch_path}")
    return [ImageJob.from_dict(job, defaults) for job in jobs]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Batch generate chess theme assets with OpenAI-compatible image APIs."
    )
    parser.add_argument(
        "--batch",
        type=Path,
        default=DEFAULT_BATCH_FILE,
        help="Path to a JSON batch definition file.",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=None,
        help="Output directory. Defaults to generated_images/<timestamp>.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="Only run the first N jobs from the batch file.",
    )
    parser.add_argument(
        "--only",
        nargs="*",
        default=None,
        help="Only run jobs with these slugs.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the resolved jobs without calling the API.",
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=1,
        help="Number of jobs to run in parallel.",
    )
    parser.add_argument(
        "--size",
        default=None,
        help="Optional size override for all jobs. Default: omit and let the model decide.",
    )
    parser.add_argument(
        "--quality",
        default=None,
        help="Optional quality override for all jobs. Default: omit and let the model decide.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    env = read_env()
    jobs = load_jobs(args.batch)

    selected_slugs = {slugify(item) for item in args.only or []}
    if selected_slugs:
        jobs = [job for job in jobs if job.slug in selected_slugs]

    if args.limit is not None:
        jobs = jobs[: args.limit]

    if not jobs:
        raise RuntimeError("No jobs matched the current filters.")

    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    output_dir = (args.output_dir or (DEFAULT_OUTPUT_ROOT / timestamp)).resolve()
    ensure_dir(output_dir)

    if args.workers < 1:
        raise RuntimeError("--workers must be at least 1.")

    client = build_client(env) if not args.dry_run and args.workers == 1 else None
    manifest: dict[str, Any] = {
        "created_at": datetime.now().isoformat(timespec="seconds"),
        "batch_file": str(args.batch.relative_to(PROJECT_ROOT)),
        "output_dir": str(output_dir.relative_to(PROJECT_ROOT)),
        "jobs": [],
    }

    if args.workers == 1 or args.dry_run:
        for job in jobs:
            result = generate_job(
                client=client,
                job=job,
                output_dir=output_dir,
                env=env,
                size_override=args.size,
                quality_override=args.quality,
                dry_run=args.dry_run,
            )
            manifest["jobs"].append(result)
    else:
        with ThreadPoolExecutor(max_workers=args.workers) as executor:
            future_map = {
                executor.submit(
                    generate_job,
                    None,
                    job,
                    output_dir,
                    env,
                    args.size,
                    args.quality,
                    False,
                ): job.slug
                for job in jobs
            }
            for future in as_completed(future_map):
                manifest["jobs"].append(future.result())

        manifest["jobs"].sort(key=lambda item: item["slug"])

    manifest_path = output_dir / "manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    print(f"[done] wrote manifest: {manifest_path}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"[error] {exc}", file=sys.stderr)
        raise SystemExit(1)
