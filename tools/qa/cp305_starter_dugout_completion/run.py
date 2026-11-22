#!/usr/bin/env python3
"""One resumable native stage; only touches this run's synthetic rolling and QA files."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
from zipfile import ZipFile, ZIP_DEFLATED

MIB = 1024**2
FLOOR = 40 * MIB
OWNER_MAX = 26 * MIB  # QA space budget only; not a product cap.
ZIP_MAX = 26 * MIB
OPENER = "9b2990aad5dc5629d237f578329e40ce940319c1170bfcb12abeb4dad3d51155"
NAME = "wiffaltro-common-career-v4.json"


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def free(path, extra=0):
    assert shutil.disk_usage(path).free >= FLOOR + extra, "STOP: custody space floor"


def slot_path(stage):
    d = stage / "data/WiffaltroStarterBeta-v1"
    d.mkdir(parents=True, exist_ok=True)
    assert d.resolve() == d
    slot = d / NAME
    assert not slot.is_symlink() and not slot.with_suffix(".json.bak").is_symlink()
    return slot


def retain(root, raw, label):
    directory = root / "phases"
    directory.mkdir(exist_ok=True)
    safe = directory / f"{label}-{sha(raw)}.zip"
    assert not safe.exists() and directory.resolve() == directory
    used = sum(f.stat().st_size for f in directory.glob("*.zip"))
    free(root, 3 * MIB)
    with ZipFile(safe, "x", ZIP_DEFLATED, compresslevel=6) as out:
        out.writestr("owner.json", raw)
    with ZipFile(safe) as reread:
        assert reread.namelist() == ["owner.json"]
        assert reread.getinfo("owner.json").file_size == len(raw)
        assert sha(reread.read("owner.json")) == sha(raw)
    print("CP305 independently verified ZIP", safe.name, "raw", len(raw), "zip", safe.stat().st_size, flush=True)
    assert used + safe.stat().st_size <= ZIP_MAX, "STOP: compact phase budget"


def main():
    root = Path(sys.argv[1]).resolve(strict=True)
    assert root.name.startswith("wiffaltro-cp305-proof-") and root.parent == Path("/tmp")
    assert (root / "Wiffaltro.x86_64").is_file() and (root / "Wiffaltro.pck").is_file()
    mode, want = sys.argv[2:4]
    rolling = slot_path(root / "rolling")
    if mode == "init":
        assert want == OPENER and not rolling.exists()
        source = Path(sys.argv[4]).resolve(strict=True)
        raw = source.read_bytes()
        assert sha(raw) == want
        free(root, OWNER_MAX * 3 + 3 * MIB)
        with rolling.open("xb") as out:
            out.write(raw)
        return
    assert mode in {"round", "close", "cold", "negative"}
    previous = rolling.read_bytes()
    assert len(previous) <= OWNER_MAX and sha(previous) == want
    stage = root / "rolling"
    chosen = previous
    if mode in {"cold", "negative"}:
        stage = root / mode
        # Only one extra raw primary; no backup or writer; do not overlap
        # this stage with another fresh stage or a progressing native run.
        free(root, OWNER_MAX)
        if mode == "negative":
            assert not (root / "cold/data/WiffaltroStarterBeta-v1" / NAME).exists()
            suspect = json.loads(previous)
            assert suspect["ordinary_state"]["status"] == "closed"
            receipt = suspect["ordinary_state"]["last_close"]["receipt"]
            assert receipt == suspect["common"]["last_fold"]["receipt"]
            literal = json.dumps(receipt, separators=(",", ":"), sort_keys=True).encode()
            assert previous.count(literal) == 2  # only the two outer receipts, never nested source
            receipt["total"] += 25
            changed = json.dumps(receipt, separators=(",", ":"), sort_keys=True).encode()
            chosen = previous.replace(literal, changed)
            control = json.loads(chosen)
            suspect["common"]["last_fold"]["receipt"]["total"] += 25
            assert control == suspect
        with slot_path(stage).open("xb") as out:
            out.write(chosen)
    else:
        backup = rolling.with_suffix(".json.bak")
        # Old primary + backup already occupy space; reserve remaining growth
        # to their cap plus a complete in-flight candidate and next ZIP.
        used = len(previous) + (backup.stat().st_size if backup.is_file() else 0)
        free(root, OWNER_MAX * 3 - used + 3 * MIB)
    xdg = {}
    for key, name in (("HOME", "home"), ("XDG_DATA_HOME", "data"), ("XDG_CACHE_HOME", "cache"),
                      ("XDG_CONFIG_HOME", "config")):
        d = stage / name
        d.mkdir(exist_ok=True)
        xdg[key] = str(d)
    actual = sha(chosen)
    log = stage / f"{mode}-{actual}.log"
    with log.open("xb") as out:
        proc = subprocess.run(
            [str(root / "Wiffaltro.x86_64"), "--headless", "--audio-driver", "Dummy",
             "--fixed-fps", "60", "--", "cp305", mode, actual],
            cwd=root, env=xdg, stdout=out, stderr=subprocess.STDOUT, timeout=1200,
        )
    text = log.read_text()
    assert proc.returncode == 0 and not any(
        line.startswith(("FAIL ", "ERROR:", "SCRIPT ERROR:")) for line in text.splitlines()
    ), text[-3000:]
    print(text[-3500:], flush=True)
    if mode == "negative":
        negative = slot_path(stage)
        assert negative.read_bytes() == chosen and sha(rolling.read_bytes()) == want
        # Dispose only of this run's verified rejected synthetic copy, since
        # the source, exact deterministic mutation, hash and log can recreate it.
        negative.unlink()
    elif mode in {"round", "close"}:
        raw = rolling.read_bytes()
        assert len(raw) <= OWNER_MAX and sha(raw) != want
        assert not rolling.with_suffix(".json.tmp").exists()
        payload = json.loads(raw)
        state = payload["ordinary"]["state"]
        label = "closed" if mode == "close" else f"phase-{int(state['phase'])}-round-{int(state['round_index'])}"
        retain(root, raw, label)
        print("CP305 NEXT PIN", sha(raw), flush=True)
    free(root)


if __name__ == "__main__":
    main()
