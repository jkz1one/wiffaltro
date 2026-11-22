#!/usr/bin/env python3
"""Stage only the exact generated picked CP303 pair in the official QA export."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

root, picked, born = (Path(arg).resolve(strict=True) for arg in sys.argv[1:])
assert root.name.startswith("wiffaltro-cp304-proof-") and root.parent == Path("/tmp")
def digest(raw):
    return hashlib.sha256(raw).hexdigest()
p, b = picked.read_bytes(), born.read_bytes()
assert digest(p) == "1f1c6ef8c34cd3a73153ea4c4b1e7e7bd6c8a793121f872ac3b8216a6e6651d2"
assert digest(b) == "a482f2f7874df269b55529d73d3785cf77cd0e19f7fc098bbad4637a44b2dede"


def run(case, primary, backup=None):
    home = root / case
    home.mkdir()
    env = {"PATH": os.environ["PATH"]}
    for key, leaf in (("HOME", "home"), ("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"),
                      ("XDG_CACHE_HOME", "cache")):
        d = home / leaf
        d.mkdir()
        env[key] = str(d)
    slot = home / "data/WiffaltroStarterBeta-v1/wiffaltro-common-career-v4.json"
    slot.parent.mkdir()
    slot.write_bytes(primary)
    bak = slot.with_suffix(".json.bak")
    if backup is not None:
        bak.write_bytes(backup)
    with (home / "proof.log").open("xb") as f:
        result = subprocess.run([str(root / "Wiffaltro.x86_64"), "--headless", "--audio-driver", "Dummy",
                                 "--fixed-fps", "60", "--", "cp304", case],
                                cwd=root, env=env, stdout=f, stderr=subprocess.STDOUT, timeout=1200)
    log = (home / "proof.log").read_text()
    assert result.returncode == 0 and "FAIL " not in log and "SCRIPT ERROR:" not in log and "\nERROR:" not in log, log
    assert not slot.with_suffix(".json.tmp").exists()
    print(case, log, flush=True)
    return slot, bak


hot, hot_bak = run("hot", p, b)
settled_path = hot.parent / "settled-exact.json"
settled = json.loads(settled_path.read_bytes())
final = hot.read_bytes()
witness = json.loads(final)
prior = json.loads(p)
assert witness["ordinary_state"]["archive"] == settled["ordinary_state"]["archive"] == prior["ordinary_state"]["archive"]
assert witness["common"] == settled["common"] == prior["common"]
assert not witness["common"]["aggregate"]["titles"]
assert witness["ordinary"]["state"]["results"] == settled["ordinary"]["state"]["results"]
assert witness["ordinary"]["physical"] == settled["ordinary"]["physical"]
r = {int(g["id"]): g for g in witness["ordinary"]["state"]["results"]}
assert sorted(r)==[0,1,2]
for i in range(6):
    def build(data):
        return data["ordinary"]["build"] if i == 0 else data["ordinary"]["opponents"]["clubs"][str(i)]["build"]
    def rewards(data):
        return [x for x in build(data)["bank"]["_events"] if x["op"] == "reward"]
    reward = rewards(witness)
    assert reward == rewards(settled) and len(reward)==1
    result = r[int(reward[0]["game"])]
    assert i in (result["home"], result["away"])
    winner = result["home"] if result["home_runs"] > result["away_runs"] else result["away"]
    assert reward[0]["win"] == (winner == i)
print("CP304 settlement", len(settled_path.read_bytes()), digest(settled_path.read_bytes()))
print("CP304 final", len(final), digest(final), "backup", digest(hot_bak.read_bytes()))
print("CP304 exact histories, Common, all six actual reward events and prior match evidence independently unchanged")
cold, cold_bak = run("cold", final)
assert "primary-only cold verifies" in (root/"cold/proof.log").read_text()
assert cold.read_bytes() == final and not cold_bak.exists()
assert picked.read_bytes() == p and born.read_bytes() == b
