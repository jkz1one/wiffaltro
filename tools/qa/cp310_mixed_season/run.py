#!/usr/bin/env python3
"""Open exact synthetic recovery fixtures without touching any original user slot."""
import hashlib
from pathlib import Path
import shutil
import subprocess
import sys

MIB = 1024**2
SLOT = "data/WiffaltroStarterBeta-v1/wiffaltro-common-career-v4.json"
ELF = "2c78919325d7f29fa7607287c7c1eeac367ea4c94e7b8b6f5f4c6b20492f73d0"
PACK = "6cff977a06ce5271bb245ef3747bb4ce26d9d2d3d0cf00d5914112072d7392da"
PAID = "3271bb28f1e63d1836c981b9996da9ff192aded0e8f7750f63a18eaf159e141c"
UNPAID = "ef3d4e3ea1d8bc899d7c16eb60d45345a9b6019fb03cc3d698d0847bde47b72e"
CASES = {"pack": (PACK, 3478930), "paid": (PAID, 4089430), "settle": (UNPAID, 3793878)}


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def main():
    root, mode, source = sys.argv[1:]
    stage = Path(root).resolve(strict=True)
    source = Path(source).resolve(strict=True)
    assert stage.name.startswith("wiffaltro-cp310-proof-") and not (stage / "project").exists()
    exe = stage / "Wiffaltro.x86_64"
    assert sha(exe.read_bytes()) == ELF and (stage / "Wiffaltro.pck").is_file()
    raw = source.read_bytes()
    digest, size = CASES[mode]
    assert len(raw) == size and sha(raw) == digest
    assert shutil.disk_usage(stage).free >= 56 * MIB
    run = stage / mode
    run.mkdir()
    env = {}
    for key, value in (("HOME", "home"), ("XDG_DATA_HOME", "data"),
                       ("XDG_CACHE_HOME", "cache"), ("XDG_CONFIG_HOME", "config")):
        folder = run / value
        folder.mkdir()
        env[key] = str(folder)
    dest = run / SLOT
    dest.parent.mkdir(parents=True)
    dest.write_bytes(raw)
    out = run / "native.log"
    with out.open("xb") as file:
        proc = subprocess.run([str(exe), "--headless", "--audio-driver", "Dummy", "--fixed-fps", "60",
                               "--log-file", str(run / "engine.log"), "--", "cp310", mode, digest],
                              stdout=file, stderr=subprocess.STDOUT, cwd=stage, env=env, timeout=420)
    log = out.read_text()
    print(log, flush=True)
    assert proc.returncode == 0
    assert not any(line.startswith(("FAIL ", "ERROR:", "SCRIPT ERROR:")) for line in log.splitlines())
    bak, tmp = (dest.with_suffix(".json." + x) for x in ("bak", "tmp"))
    assert source.read_bytes() == raw and not tmp.exists()
    if mode == "settle":
        assert sha(dest.read_bytes()) == PAID and bak.read_bytes() == raw
    else:
        assert dest.read_bytes() == raw and not bak.exists()
    assert shutil.disk_usage(stage).free >= 40 * MIB
    print("Exact independently checked proof", mode, sha(dest.read_bytes()), flush=True)


if __name__ == "__main__":
    main()
