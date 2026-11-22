#!/usr/bin/env python3
"""Exercise the actual official no-env Starter APIs in the CP303 QA package."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

root, closed, terminal = (Path(arg).resolve(strict=True) for arg in sys.argv[1:])
assert root.name.startswith("wiffaltro-cp303-proof-") and root.parent == Path("/tmp")
sha = lambda b: hashlib.sha256(b).hexdigest()
closed_bytes, terminal_bytes = closed.read_bytes(), terminal.read_bytes()
assert sha(closed_bytes) == "3f34084c98b630b4f5fa9d5023fb325ef426c7d41defb3283aa07547a18bc36d"
assert sha(terminal_bytes) == "5592b694feb28909905b97bd4efa19c8bab9b77d0c8ab69cba3d05f4dd2213a6"


def run(case, method, primary, backup=None):
    home = root / case
    home.mkdir()
    env = {"PATH": os.environ["PATH"]}
    for key, leaf in (("HOME", "home"), ("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"),
                      ("XDG_CACHE_HOME", "cache")):
        p = home / leaf
        p.mkdir()
        env[key] = str(p)
    slot = home / "data/WiffaltroStarterBeta-v1/wiffaltro-common-career-v4.json"
    slot.parent.mkdir()
    slot.write_bytes(primary)
    bak = slot.with_suffix(".json.bak")
    if backup is not None:
        bak.write_bytes(backup)
    with (home / "proof.log").open("xb") as f:
        result = subprocess.run([str(root / "Wiffaltro.x86_64"), "--headless", "--audio-driver", "Dummy",
                                 "--", "cp303", method], cwd=root, env=env, stdout=f, stderr=subprocess.STDOUT,
                                timeout=240)
    log = (home / "proof.log").read_text()
    assert result.returncode == 0 and "CP303 FAIL" not in log and "SCRIPT ERROR:" not in log and "\nERROR:" not in log, log
    assert not slot.with_suffix(".json.tmp").exists()
    print(case, log, flush=True)
    return slot, bak


born, old = run("hot", "hot", closed_bytes, terminal_bytes)
assert old.read_bytes() == closed_bytes
draft = born.read_bytes()
draft_value = json.loads(draft)
previous = json.loads(closed_bytes)
chain = draft_value["ordinary_state"]["archive"]
first, second = chain["entries"]
heads = json.dumps(first["source"], ensure_ascii=False, separators=(",", ":")).encode()
assert closed_bytes.count(heads) == 1
assert second["prefix"].encode() + heads + second["suffix"].encode() == closed_bytes
assert first == previous["ordinary_state"]["archive"]
assert draft_value["common"] == previous["common"]
assert not draft_value["common"]["aggregate"]["titles"]
assert len(draft) <= 20 * 1024 * 1024
print("CP303 BORN independently verified", len(draft), sha(draft), "headroom, 20 MiB", 20 * 1024 * 1024 - len(draft))

picked, bak = run("cold", "cold", draft)
picked_bytes = picked.read_bytes()
assert bak.read_bytes() == draft
assert json.loads(picked_bytes)["ordinary_state"]["archive"] == chain
print("CP303 PICK", len(picked_bytes), sha(picked_bytes))

for case in ("changed-fragment", "swapped"):
    tampered = json.loads(draft)
    rows = tampered["ordinary_state"]["archive"]["entries"]
    if case == "swapped":
        rows.reverse()
    else:
        rows[1]["suffix"] += " "
    proposed = json.dumps(tampered, separators=(",", ":")).encode()
    slot, bak = run(case, "refuse", proposed)
    assert slot.read_bytes() == proposed and not bak.exists()
assert closed.read_bytes()==closed_bytes and terminal.read_bytes()==terminal_bytes
