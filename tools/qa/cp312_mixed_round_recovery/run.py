#!/usr/bin/env python3
"""Verify actual CP312 native source evidence without running any physical games."""
import hashlib
from pathlib import Path
import shutil
import subprocess
import sys

BOOT = ("2c78919325d7f29fa7607287c7c1eeac367ea4c94e7b8b6f5f4c6b20492f73d0")
PENDING_1 = "184e593b9d85bfa1d577b5e45b845656241273d339b44b740a6939e95b2aec71"
PENDING_2 = "7483fac70bd35fba8c0a005c165af448d3a23ea592dc18b94fe3a8d97becf841"
PAID = "bb8df3bf660fbcdf4b519277c951e6230f60841178d07eb2b40a0f0eaae61372"
REQUEST = b"4909866aa3bda28c506550e1619122451ff92ac092ede1fdd1bafc3efc5418c9"
SLOT = "data/WiffaltroStarterBeta-v1/wiffaltro-common-career-v4.json"
FLOOR = 40 * 1024**2


def digest(b):
    return hashlib.sha256(b).hexdigest()


def main():
    root, mode, current, previous = sys.argv[1:]
    stage, src, orig = (Path(x).resolve(strict=True) for x in (root, current, previous))
    assert mode in {"worker", "pending", "corrupt"} and stage.name.startswith("wiffaltro-cp312-proof-")
    assert not (stage / "project").exists()
    exe = stage / "Wiffaltro.x86_64"
    assert digest(exe.read_bytes()) == BOOT and (stage / "Wiffaltro.pck").is_file()
    raw, old = src.read_bytes(), orig.read_bytes()
    assert (digest(raw), digest(old)) == ((PAID, PENDING_2) if mode == "worker" else (PENDING_2, PENDING_1))
    assert shutil.disk_usage(stage).free >= FLOOR + 3 * max(len(raw), len(old))
    isolated = stage / mode
    isolated.mkdir()
    env = {}
    for key, dirname in (("HOME", "home"), ("XDG_DATA_HOME", "data"),
                         ("XDG_CACHE_HOME", "cache"), ("XDG_CONFIG_HOME", "config")):
        p = isolated / dirname
        p.mkdir()
        env[key] = str(p)
    installed = raw
    if mode == "corrupt":
        assert raw.count(REQUEST) == 1 and (b"f" * 64) not in raw
        installed = raw.replace(REQUEST, b"f" * 64, 1)
    dest = isolated / SLOT
    dest.parent.mkdir(parents=True)
    backup = dest.with_suffix(".json.bak")
    dest.write_bytes(installed)
    backup.write_bytes(old)
    log = isolated / "native.log"
    cmd = [str(exe), "--headless", "--audio-driver", "Dummy", "--fixed-fps", "60",
           "--log-file", str(isolated / "engine.log"), "--", "cp312", mode]
    with log.open("xb") as output, subprocess.Popen(cmd, cwd=stage, env=env,
                                                   stdout=output, stderr=subprocess.STDOUT) as process:
        print("Native process started", mode, process.pid, flush=True)
        try:
            code = process.wait(timeout=300)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
            raise
    print("Native process exited", mode, code, flush=True)
    line = log.read_text()
    print(line, flush=True)
    assert code == 0 and not any(s.startswith(("FAIL ", "ERROR:", "SCRIPT ERROR:")) for s in line.splitlines())
    assert src.read_bytes() == raw and orig.read_bytes() == old and not dest.with_suffix(".json.tmp").exists()
    if mode == "pending":
        assert digest(dest.read_bytes()) == PAID and backup.read_bytes() == raw
    else:
        assert dest.read_bytes() == installed and backup.read_bytes() == old
    assert shutil.disk_usage(stage).free >= FLOOR
    print("Exact readback passed", mode, digest(dest.read_bytes()), digest(backup.read_bytes()), flush=True)


if __name__ == "__main__":
    main()
