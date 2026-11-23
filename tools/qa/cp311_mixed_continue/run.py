#!/usr/bin/env python3
"""Verify the Linux Starter menu/worker with one exact generated pack."""
import hashlib
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

FIXTURE = "6cff977a06ce5271bb245ef3747bb4ce26d9d2d3d0cf00d5914112072d7392da"
CHOICE = "00f180ededc6be402aee91494da1d89dad02e308097074073f56a6b1ac46ecf2"
ELF = "2c78919325d7f29fa7607287c7c1eeac367ea4c94e7b8b6f5f4c6b20492f73d0"

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    stage, source = (Path(arg).resolve(strict=True) for arg in sys.argv[1:])
    assert stage.name.startswith("wiffaltro-cp311-proof-")
    app = stage / "Wiffaltro.x86_64"
    assert sha(app) == ELF and (stage / "Wiffaltro.pck").is_file()
    assert sha(source) == FIXTURE and shutil.disk_usage(stage).free >= 64 * 1024**2
    profile = Path(tempfile.mkdtemp(prefix="cp311-run.", dir=stage))
    env = {}
    for key, name in (("HOME", "home"), ("XDG_CONFIG_HOME", "config"),
                      ("XDG_DATA_HOME", "data"), ("XDG_CACHE_HOME", "cache")):
        folder = profile / name
        folder.mkdir()
        env[key] = str(folder)
    slot = profile / "data/WiffaltroStarterBeta-v1/wiffaltro-common-career-v4.json"
    slot.parent.mkdir()
    shutil.copyfile(source, slot)
    print(profile, flush=True)
    command = [str(app), "--headless", "--audio-driver", "Dummy",
               "--log-file", str(profile / "engine.log"), "--", "cp311", "continue"]
    with (profile / "native.log").open("xb") as log:
        child = subprocess.Popen(command, cwd=stage, env=env, stdout=log,
                                 stderr=subprocess.STDOUT, start_new_session=True)
        print("APP_PID", child.pid, flush=True)
        try:
            result = child.wait(timeout=400)
        except subprocess.TimeoutExpired:
            child.terminate()
            child.wait(timeout=10)
            raise
        print("APP_EXIT", result, flush=True)
    output = (profile / "native.log").read_text()
    print(output, flush=True)
    assert result == 0 and not any(line.startswith(("FAIL ", "ERROR:", "SCRIPT ERROR:"))
                                   for line in output.splitlines())
    assert "PASS legitimate resolution exactly matches previous paid choice" in output
    assert sha(slot) == CHOICE and sha(slot.with_suffix(".json.bak")) == FIXTURE
    assert sha(source) == FIXTURE and not slot.with_suffix(".json.tmp").exists()
    print("Verified unchanged input, exact paid-choice output and backup.", flush=True)

if __name__ == "__main__":
    main()
