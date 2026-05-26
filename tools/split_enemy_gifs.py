#!/usr/bin/env python3
"""Split enemy GIF animations into PNG frames in-place.

Usage:
    python tools/split_enemy_gifs.py             # process every subfolder of assets/enemies/
    python tools/split_enemy_gifs.py skeleton    # process only assets/enemies/skeleton/

For each enemy folder it looks for:
  * one *(death).gif        -> writes death_00.png, death_01.png, ...
  * one other *.gif         -> writes walk_00.png, walk_01.png, ...

Any prior walk_*.png / death_*.png in the folder are removed first so re-runs
cleanly replace previous extractions. The source .gif files are left in place.
"""
import sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1] / "assets" / "enemies"


def split_gif(gif_path: Path, prefix: str, out_dir: Path) -> int:
    # wipe prior frames so re-running doesn't leave stale tail frames behind
    for old in out_dir.glob(f"{prefix}_*.png"):
        old.unlink()
    img = Image.open(gif_path)
    count = 0
    try:
        while True:
            # convert each frame to RGBA so disposal/transparency is handled
            frame = img.convert("RGBA")
            frame.save(out_dir / f"{prefix}_{count:02d}.png")
            count += 1
            img.seek(img.tell() + 1)
    except EOFError:
        pass
    return count


def process_folder(folder: Path) -> None:
    gifs = sorted(folder.glob("*.gif"))
    if not gifs:
        print(f"  (no gifs in {folder.name})")
        return
    death = [g for g in gifs if "(death)" in g.stem.lower() or g.stem.lower().endswith("_death")]
    walk = [g for g in gifs if g not in death]
    if walk:
        n = split_gif(walk[0], "walk", folder)
        print(f"  {folder.name}/walk: {walk[0].name} -> {n} frames")
    if death:
        n = split_gif(death[0], "death", folder)
        print(f"  {folder.name}/death: {death[0].name} -> {n} frames")


def main():
    if not ROOT.exists():
        print(f"missing {ROOT}")
        return
    targets = sys.argv[1:] or sorted(p.name for p in ROOT.iterdir() if p.is_dir())
    for name in targets:
        folder = ROOT / name
        if not folder.is_dir():
            print(f"skip: {folder} not a directory")
            continue
        print(f"-> {name}")
        process_folder(folder)


if __name__ == "__main__":
    main()
