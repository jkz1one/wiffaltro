#!/usr/bin/env python3
"""Native repeatable QA for distinct future catalogue identity. Never launches an installed profile."""
import argparse
from hashlib import sha256
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(REPO / "tools"))
import assemble_successor
from shadow import apply, INPUTS

GODOT_SHA = "f64d4ed19fc9df9440321653fcc80df8c6e365ba7b6de0a29e2cfa9fa71bfeb3"
PAGE_SHA = "f0e1e064f71e27798927db1a0e582a8742cb8dddbecd70224963f5a63edd6ba5"
CLOSED_SHA = "0e4ad0b98c9963a362a363cf7d3fa088959c81ccab475b10760e445ce253b301"
PROFILE = "WiffaltroForwardCatalogQA-v1"
MARKER = re.compile(r"^FRESH ROUND PASS semantic_sha=([0-9a-f]{64}) context=([0-9a-f]{64}) "
                    r"cash=([0-9]+) games=(\[[0-9,\[\]]+\]) us=([0-9]+)$", re.M)


def pinned(path, length, digest):
    if path.is_symlink() or not stat.S_ISREG(path.stat().st_mode) or path.stat().st_size != length:
        raise ValueError(f"Expected regular pinned {length}-byte input")
    blob = path.read_bytes()
    if sha256(blob).hexdigest() != digest:
        raise ValueError("Exact pinned synthetic input did not match")
    return blob


def native(exe, work, project, switches, env, log, timeout):
    with log.open("xb") as out:
        p = subprocess.run(
            [str(exe), "--headless", "--audio-driver", "Dummy", "--path", str(project), *switches],
            cwd=work, env=env, stdout=out, stderr=subprocess.STDOUT, timeout=timeout, check=False,
        )
    text = log.read_text()
    if p.returncode or re.search(r"(^| )(SCRIPT ERROR|USER ERROR|ERROR):", text, re.M):
        raise RuntimeError(f"Native qualifier failed; see {log.name}")
    return text


def qualify(exe, work, page, close):
    os.umask(0o077)
    raw_page = pinned(page, 908166, PAGE_SHA)
    raw_close = pinned(close, 6703416, CLOSED_SHA)
    prefix, layer = raw_close.split(b"\n", 1)
    if prefix != b"WIFFALTRO-BASE-ARCHIVE-V1":
        raise ValueError("Wrong pinned source envelope")
    h = json.loads(layer)["head"]
    root = json.dumps({key: h[key] for key in ["league", "root", "seed"]}, sort_keys=True).encode()
    if not stat.S_ISREG(exe.stat().st_mode) or sha256(exe.read_bytes()).hexdigest() != GODOT_SHA:
        raise ValueError("Only the pinned vendor Godot engine is accepted for this Linux test")
    work = work.resolve()
    if work.is_relative_to(REPO) or REPO.is_relative_to(work):
        raise ValueError("A new separate scratch directory is required")
    work.mkdir(mode=0o700)
    outcomes = {}
    for label in ("stock", "shadow"):
        project = work / label
        record = assemble_successor.assemble(REPO, project, dynasty_owner=True, preserve_authored_project=True)
        if any(record["files"].get(path) != digest for path, digest in INPUTS.items()):
            raise ValueError("Expected frozen catalogue sources were not assembled")
        profile = work / f"{label}-private"
        folder = profile / "data" / PROFILE
        folder.mkdir(parents=True, mode=0o700)
        for name in ("config", "home", "cache"):
            (profile / name).mkdir(mode=0o700)
        local_inputs = {"first-archive-page.json": raw_page, "root.json": root}
        for name, value in local_inputs.items():
            (folder / name).write_bytes(value)
        entries = project / "forward_catalog_qa"
        entries.mkdir(mode=0o700)
        for name in ("round.gd", "round.tscn"):
            (entries / name).write_bytes((HERE / (name + ".txt")).read_bytes())
        config = project / "project.godot"
        text = config.read_text()
        old = 'run/main_scene="res://src/presentation/season/season_app.tscn"'
        name = 'config/name="Wiffaltro"'
        if text.count(old) != 1 or text.count(name) != 1 or "custom_user_dir" in text:
            raise ValueError("Unexpected authored project configuration")
        config.write_text(text.replace(old, 'run/main_scene="res://forward_catalog_qa/round.tscn"')
                          .replace(name, 'config/name="Wiffaltro Forward Catalog QA"\n'
                                   'config/use_custom_user_dir=true\n'
                                   f'config/custom_user_dir_name="{PROFILE}"'))
        if label == "shadow":
            apply(project)
        env = {
            "PATH": "/usr/bin:/bin",
            "HOME": str(profile / "home"),
            "XDG_CONFIG_HOME": str(profile / "config"),
            "XDG_CACHE_HOME": str(profile / "cache"),
            "XDG_DATA_HOME": str(profile / "data"),
            "WIFFALTRO_ISOLATED_TEST": "1",
        }
        native(exe, work, project, ["--editor", "--import"], env, work / f"{label}-import.log", 250)
        run = native(exe, work, project, ["--fixed-fps", "60"], env, work / f"{label}-round.log", 950)
        matches = MARKER.findall(run)
        if len(matches) != 1 or any((folder / name).read_bytes() != data for name, data in local_inputs.items()):
            raise RuntimeError("Expected exact sensor verdict and byte-inert synthetic inputs")
        if any(path.is_file() and path.name not in {*local_inputs, "godot.log"}
               for path in (profile / "data").rglob("*")):
            raise RuntimeError("Unexpected file in isolated profile")
        semantic, catalog, cash, games, micros = matches[0]
        outcomes[label] = {"semantics": semantic, "catalog": catalog, "cash": int(cash),
                           "games": json.loads(games), "native_us": int(micros)}
    stock, forward = (outcomes[label] for label in ("stock", "shadow"))
    if (stock["catalog"] == forward["catalog"] or stock["semantics"] != forward["semantics"]
            or stock["cash"] != forward["cash"] or stock["games"] != forward["games"]):
        raise RuntimeError("Distinct catalogue identities must produce identical gameplay and paid result")
    if PAGE_SHA != sha256(page.read_bytes()).hexdigest() or CLOSED_SHA != sha256(close.read_bytes()).hexdigest():
        raise RuntimeError("Original synthetic fixture streams changed")
    out = {"scope": "QA only, no installed release or migration", "results": outcomes}
    (work / "result.json").write_text(json.dumps(out, indent=2) + "\n")
    print(json.dumps(out))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--work", required=True, type=Path)
    parser.add_argument("--synthetic-page", required=True, type=Path)
    parser.add_argument("--synthetic-closed", required=True, type=Path)
    args = parser.parse_args()
    if not sys.platform.startswith("linux"):
        parser.error("This fixed qualification is for the pinned Linux editor.")
    qualify(args.godot.resolve(), args.work, args.synthetic_page, args.synthetic_closed)


if __name__ == "__main__":
    main()
