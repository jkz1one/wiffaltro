#!/usr/bin/env python3
"""Resume the exact generated open shop to buy and complete the natural pack."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

package, opened, settled = (Path(x).resolve(strict=True) for x in sys.argv[1:])
root = package.parent if package.name == "pack-qa" else package
assert root.parent == Path("/tmp") and root.name.startswith("wiffaltro-cp304-proof-")
sig = lambda b: hashlib.sha256(b).hexdigest()
before, prior = opened.read_bytes(), settled.read_bytes()
assert sig(before) == "12656514faabb02c1796062fbaba0e0c72f05f19c08f67b9e7cbf1c510005714"
assert sig(prior) == "155bcc30ed8e3556ddd8a9a14ba035a524ec458cb73496bed6ebab4fb6029dc4"


def execute(mode, raw, backup=None):
    work = root / ("authorized-" + mode)
    work.mkdir()
    env = {"PATH": os.environ["PATH"]}
    for key, name in (("HOME", "home"), ("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"),
                      ("XDG_CACHE_HOME", "cache")):
        d = work / name
        d.mkdir()
        env[key] = str(d)
    slot = work / "data/WiffaltroStarterBeta-v1/wiffaltro-common-career-v4.json"
    slot.parent.mkdir()
    slot.write_bytes(raw)
    bak = slot.with_suffix(".json.bak")
    if backup is not None:
        bak.write_bytes(backup)
    log = work / "proof.log"
    with log.open("xb") as f:
        p = subprocess.run([str(package / "Wiffaltro.x86_64"), "--headless", "--audio-driver", "Dummy",
                            "--fixed-fps", "60", "--", "cp304", mode], cwd=work, env=env,
                           stdout=f, stderr=subprocess.STDOUT, timeout=150)
    t = log.read_text()
    assert p.returncode==0 and "FAIL " not in t and "SCRIPT ERROR" not in t and "\nERROR:" not in t, t
    assert not slot.with_suffix(".json.tmp").exists()
    print(t, flush=True)
    return slot, bak

p, paid = execute("pack", before, prior)
raw, paid_bytes = p.read_bytes(), paid.read_bytes()
original = json.loads(before)
for tag, snap, status in (("paid", paid_bytes, "open"),("chosen",raw,"used")):
    value = json.loads(snap)
    assert value["common"] == original["common"] and value["ordinary_state"] == original["ordinary_state"]
    assert value["ordinary"]["state"]["results"] == original["ordinary"]["state"]["results"]
    assert value["ordinary"]["physical"] == original["ordinary"]["physical"]
    build = value["ordinary"]["build"]
    common_original = original["ordinary"]["build"]
    assert build["bank"]["_state"]["cash"] == 4
    assert build["build"]["_visit"]["pack_status"] == status
    assert [e for e in build["bank"]["_events"] if e["op"] == "reward"] == [
        e for e in common_original["bank"]["_events"] if e["op"] == "reward"]
    assert value["ordinary"]["opponents"] == original["ordinary"]["opponents"]
    print(tag, len(snap), sig(snap), flush=True)
c, no_bak = execute("paid-cold", raw)
assert c.read_bytes() == raw and not no_bak.exists()
assert opened.read_bytes()==before and settled.read_bytes()==prior
