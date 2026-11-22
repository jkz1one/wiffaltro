#!/usr/bin/env python3
"""Two official native phases, one owned writer and one separate primary-only App."""
import hashlib
from pathlib import Path
import shutil
import subprocess
import sys

MIB = 1024**2
FLOOR = 40 * MIB
PICK = "954661fe7b1ed5f1dee43097781d0a61ce0427e2dfd6884520525792eacb618b"
EARNED_BROWSE = "451d09f0c8fe7d03d8681611feb2386124da0e656bf3a50ed337e7c3aca36e6f"
ELF = "2c78919325d7f29fa7607287c7c1eeac367ea4c94e7b8b6f5f4c6b20492f73d0"
SLOT = "data/WiffaltroStarterBeta-v1/wiffaltro-common-career-v4.json"


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def main():
    root, mode, input_path = sys.argv[1:]
    stage = Path(root).resolve(strict=True)
    source = Path(input_path).resolve(strict=True)
    assert stage.name.startswith("wiffaltro-cp309-proof-") and stage.parent == Path("/tmp")
    assert mode in {"hot", "cold"} and not (stage / "project").exists()
    game = stage / "Wiffaltro.x86_64"
    assert sha(game.read_bytes()) == ELF and (stage / "Wiffaltro.pck").is_file()
    raw = source.read_bytes()
    if mode == "hot":
        assert sha(raw) == PICK and len(raw) == 2742168
        # Isolated rolling primary/.bak/.tmp plus at most five compact-script
        # pinned phases and small native witnesses.
        assert shutil.disk_usage(stage).free >= FLOOR + 42 * MIB
    else:
        assert source.name == "shop-open.json" and sha(raw) == EARNED_BROWSE and len(raw) == 3478687
        assert shutil.disk_usage(stage).free >= FLOOR + len(raw) + 4 * MIB
    run = stage / mode
    run.mkdir()
    iso = {}
    for n, rel in (("HOME","home"),("XDG_DATA_HOME","data"),("XDG_CACHE_HOME","cache"),("XDG_CONFIG_HOME","config")):
        sub = run / rel
        sub.mkdir()
        iso[n] = str(sub)
    dst = run / SLOT
    dst.parent.mkdir(parents=True)
    dst.write_bytes(raw)
    log = run / "native.log"
    with log.open("xb") as f:
        result = subprocess.run([str(game), "--headless", "--audio-driver", "Dummy", "--fixed-fps", "60",
                                 "--", "cp309", mode], env=iso, cwd=stage, stdout=f,
                                stderr=subprocess.STDOUT, timeout=1200)
    text = log.read_text()
    print(text)
    assert result.returncode == 0 and not any(l.startswith(("FAIL ", "ERROR:", "SCRIPT ERROR:"))
                                              for l in text.splitlines())
    assert source.read_bytes() == raw and not dst.with_suffix(".json.tmp").exists()
    if mode == "cold":
        assert dst.read_bytes() == raw and not dst.with_suffix(".json.bak").exists()
    else:
        assert dst.read_bytes() != raw
        paid = dst.parent / "cp309-pins/settle-3.json"
        terminal = dst.parent / "cp309-pins/npc-2.json"
        assert paid.is_file() and terminal.is_file()
        assert dst.with_suffix(".json.bak").read_bytes() == paid.read_bytes()
    assert shutil.disk_usage(stage).free >= FLOOR
    print("exact retained native slot", sha(dst.read_bytes()), dst, flush=True)


if __name__ == "__main__":
    main()
