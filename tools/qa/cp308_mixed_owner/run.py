#!/usr/bin/env python3
"""Two official native phases, one owned writer and one separate primary-only App."""
import hashlib
from pathlib import Path
import shutil
import subprocess
import sys

MIB = 1024**2
FLOOR = 40 * MIB
CLOSED = "8549fcded318686355e1b0177f6186804f85438dbb832bbf0bda128d06c82dd5"
ELF = "2c78919325d7f29fa7607287c7c1eeac367ea4c94e7b8b6f5f4c6b20492f73d0"
SLOT = "data/WiffaltroStarterBeta-v1/wiffaltro-common-career-v4.json"


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def main():
    root, mode, input_path = sys.argv[1:]
    stage = Path(root).resolve(strict=True)
    source = Path(input_path).resolve(strict=True)
    assert stage.name.startswith("wiffaltro-cp308-proof-") and stage.parent == Path("/tmp")
    assert mode in {"hot", "cold"} and not (stage / "project").exists()
    game = stage / "Wiffaltro.x86_64"
    assert sha(game.read_bytes()) == ELF and (stage / "Wiffaltro.pck").is_file()
    if mode == "cold":
        assert source == stage / "hot" / SLOT
    raw = source.read_bytes()
    if mode == "hot":
        assert sha(raw) == CLOSED and len(raw) == 25182871
        # An exact writable starter and full .bak copy are simultaneously
        # needed before the rename, plus ~3 MiB candidate and metadata.
        assert shutil.disk_usage(stage).free >= FLOOR + 2 * len(raw) + 7 * MIB
    else:
        assert len(raw) < 4 * MIB
        assert sha(source.with_suffix(".json.bak").read_bytes()) == CLOSED
        assert shutil.disk_usage(stage).free >= FLOOR + 3 * len(raw) + 4 * MIB
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
                                 "--", "cp308", mode], env=iso, cwd=stage, stdout=f,
                                stderr=subprocess.STDOUT, timeout=540)
    text = log.read_text()
    print(text)
    assert result.returncode == 0 and not any(l.startswith(("FAIL ", "ERROR:", "SCRIPT ERROR:"))
                                              for l in text.splitlines())
    assert source.read_bytes() == raw and not dst.with_suffix(".json.tmp").exists()
    assert dst.with_suffix(".json.bak").read_bytes() == raw
    assert dst.read_bytes() != raw
    assert shutil.disk_usage(stage).free >= FLOOR
    print("exact retained native slot", sha(dst.read_bytes()), dst, flush=True)


if __name__ == "__main__":
    main()
