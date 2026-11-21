#!/usr/bin/env python3
"""Make a local two-slot synthetic Dynasty archive; does not upload anything."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import zipfile

NAMES = ("owner.json", "owner.json.bak")
MAX_BYTES = 64 * 1024 * 1024
UNSAFE = re.compile(
    rb"-----BEGIN [^-]+PRIVATE KEY-----|github_pat_|gh[pousr]_[A-Za-z0-9_]{24,}|"
    rb"AKIA[A-Z0-9]{16}|sk-[A-Za-z0-9_-]{24,}|/workspace/|/home/agent/|"
    rb"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}",
    re.IGNORECASE,
)


def digest(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def archive(source: Path, output: Path, commit: str) -> None:
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError("An exact verified source commit is required")
    if source.is_symlink() or not source.is_dir():
        raise ValueError("The source must be a local checkpoint directory")
    if output.suffix != ".zip" or output.exists() or output.is_symlink():
        raise ValueError("Use a new .zip output; existing files are never overwritten")
    match = re.fullmatch(r"(human-\d+|npc-\d+|settle-\d+|close|paid-chair|next)-([0-9a-f]{64})", source.name)
    if match is None:
        raise ValueError("Expected a hash-pinned local synthetic test step")
    names = sorted(p.name for p in source.iterdir())
    if names != sorted(NAMES):
        raise ValueError("A test checkpoint may contain only its two exact slots")
    manifest = {
        "format": "wiffaltro-synthetic-dynasty-native-checkpoint-v1",
        "source_commit": commit, "stage": match[1], "files": {},
    }
    items = {}
    for name in NAMES:
        file = source / name
        if file.is_symlink() or not file.is_file() or not 0 < file.stat().st_size <= MAX_BYTES:
            raise ValueError("Unexpected checkpoint member")
        raw = file.read_bytes()
        if UNSAFE.search(raw):
            raise ValueError("Privacy audit match in synthetic checkpoint")
        payload = json.loads(raw)
        if (payload.get("format") != "wiffaltro-common-career-v4"
                or payload.get("active") != "dynasty" or not payload.get("dynasty")):
            raise ValueError("This is not an active-side Dynasty checkpoint")
        target = "wiffaltro-common-career-v4.json" + (".bak" if name.endswith(".bak") else "")
        manifest["files"][target] = {"bytes": len(raw), "sha256": digest(raw)}
        items[target] = raw
    if next(iter(manifest["files"].values()))["sha256"] != match[2]:
        raise ValueError("Primary SHA disagrees with the admitted step")
    if len({meta["sha256"] for meta in manifest["files"].values()}) != 2:
        raise ValueError("A written step and its predecessor must differ")
    with zipfile.ZipFile(output, "x", zipfile.ZIP_DEFLATED) as packed:
        for name, raw in items.items():
            packed.writestr(name, raw)
        packed.writestr("MANIFEST.json", json.dumps(manifest, indent=2) + "\n")
    with zipfile.ZipFile(output) as packed:
        if sorted(packed.namelist()) != sorted([*items, "MANIFEST.json"]) or packed.testzip():
            raise ValueError("ZIP readback failed")
        for name, raw in items.items():
            if packed.read(name) != raw:
                raise ValueError("Exact ZIP content readback failed")
    print(f"{output.name}: {output.stat().st_size} bytes, SHA-256 {digest(output.read_bytes())}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--synthetic-test-only", action="store_true", required=True)
    args = parser.parse_args()
    archive(args.source, args.output, args.commit)
