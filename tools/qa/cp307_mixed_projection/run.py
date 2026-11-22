#!/usr/bin/env python3
"""Official read-only native projection under a hash-matched source overlay."""
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "tools"))
sys.dont_write_bytecode = True
from assemble_successor import (FAMILIES, LIVE_FAMILY, SELECTOR_FAMILY, PLAY_FAMILY,
                                PAIRED_HISTORY_FAMILIES, DYNASTY_FAMILY, AUTHORED_PROJECT_SHA256)

FLOOR = 40 * 1024**2
EDITOR = "f64d4ed19fc9df9440321653fcc80df8c6e365ba7b6de0a29e2cfa9fa71bfeb3"
INPUT = "8549fcded318686355e1b0177f6186804f85438dbb832bbf0bda128d06c82dd5"
CACHE = ("global_script_class_cache.cfg", "uid_cache.bin")


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def safe(name):
    relative = PurePosixPath(name)
    assert not relative.is_absolute() and ".." not in relative.parts and str(relative) == name
    return name


def sources():
    resolved = {}
    tracked = subprocess.check_output(["git", "ls-files", "-z", "src", "project.godot"], cwd=ROOT)
    for name in tracked.decode().split("\0"):
        if name:
            p = ROOT / safe(name)
            assert p.is_file() and not p.is_symlink()
            resolved[name] = p.read_bytes()
    for family in (*FAMILIES, LIVE_FAMILY, SELECTOR_FAMILY, PLAY_FAMILY, *PAIRED_HISTORY_FAMILIES, DYNASTY_FAMILY):
        m = json.loads((ROOT / "drafts" / family / "DRAFT_MANIFEST.json").read_bytes())
        for row in m.get("files", []) + m.get("additions", []):
            name = safe(row["restore_path"])
            if not name.startswith("src/"):
                continue
            p = ROOT / safe(row["backup_path"])
            assert not p.is_symlink()
            raw = p.read_bytes()
            assert len(raw) == row["bytes"] and digest(raw) == row["sha256"]
            assert name not in resolved or resolved[name] == raw
            resolved[name] = raw
    assert digest(resolved["project.godot"]) == AUTHORED_PROJECT_SHA256
    return resolved


def main():
    editor, raw_input, base = [Path(x).resolve(strict=True) for x in sys.argv[1:]]
    assert digest(editor.read_bytes()) == EDITOR and digest(raw_input.read_bytes()) == INPUT
    assert base.name == "project" and shutil.disk_usage("/tmp").free >= FLOOR + 16 * 1024**2
    ref_record = json.loads((base / "ASSEMBLY.json").read_bytes())["files"]
    stage = Path(tempfile.mkdtemp(prefix="wiffaltro-cp307-proof-", dir="/tmp"))
    project = stage / "project"
    print(stage, flush=True)
    payload = sources()
    links = {}
    copied = 0
    for name, data in payload.items():
        sha = digest(data)
        old = base / name
        target = project / name
        target.parent.mkdir(parents=True, exist_ok=True)
        # No config, .uid/.import metadata, or cache may share an inode.
        if name.startswith("src/") and old.suffix in {".gd", ".tscn", ".tres", ".json", ".svg"} \
                and ref_record.get(name) == sha and old.is_file() and not old.is_symlink() \
                and digest(old.read_bytes()) == sha:
            os.link(old, target)
            links[old] = sha
        else:
            copied += ((len(data)+4095)//4096)*4096
            assert copied <= 12 * 1024**2
            target.write_bytes(data)
    cache = project / ".godot"
    cache.mkdir()
    for name in CACHE:
        source = base / ".godot" / name
        assert source.is_file() and not source.is_symlink()
        shutil.copyfile(source, cache / name)
    for name in ("probe.gd", "probe.tscn"):
        (project / name).write_bytes((HERE / (name+".txt")).read_bytes())
    (stage / "inputs.sha256").write_text(
        "\n".join(f"{digest(raw)} {name}" for name, raw in sorted(payload.items()) if name.endswith(
            ("starter_mixed_custody.gd", "starter_mixed_projection.gd", "common_start.gd", "session_adapter.gd",
             "successor_live_play_v1/codec.gd", "successor_live_play_v1/runtime.gd")))+"\n"
    )
    env = {}
    for k, name in (("HOME","home"),("XDG_DATA_HOME","data"),("XDG_CONFIG_HOME","config"),("XDG_CACHE_HOME","cache")):
        p = stage / name
        p.mkdir()
        env[k] = str(p)
    assert shutil.disk_usage("/tmp").free >= FLOOR + 4 * 1024**2
    print("reference exact read-only links", len(links), "new source pages", copied, flush=True)
    cmd = [str(editor), "--headless", "--audio-driver", "Dummy", "--path", str(project),
           "res://probe.tscn", "--", str(raw_input)]
    for label, mode in (("native", []), ("negative", ["negative"])):
        log = stage / (label + ".log")
        with log.open("xb") as f:
            job = subprocess.run(cmd + mode, cwd=stage, env=env, stdout=f,
                                 stderr=subprocess.STDOUT, timeout=480)
        text = log.read_text()
        print(text, flush=True)
        assert job.returncode == 0 and not any(line.startswith(("FAIL ", "ERROR:", "SCRIPT ERROR:"))
                                              for line in text.splitlines())
    assert all(digest(p.read_bytes()) == sha for p, sha in links.items())
    assert all(digest((project / name).read_bytes()) == digest(raw) for name, raw in payload.items())
    assert digest(raw_input.read_bytes()) == INPUT and shutil.disk_usage("/tmp").free >= FLOOR
    assert not any(p.is_file() and p.name.startswith("wiffaltro-common") for p in (stage / "data").rglob("*"))
    print("PASS source and input immutable, no in-game slot created")


if __name__ == "__main__":
    main()
