#!/usr/bin/env python3
"""Bounded round with parsed native witnesses and verified persistent barriers."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import zipfile

ELF = "2c78919325d7f29fa7607287c7c1eeac367ea4c94e7b8b6f5f4c6b20492f73d0"

def sha(b):
    return hashlib.sha256(b).hexdigest()

def witness(label, raw, previous, base, unpaid, first, labels):
    o = json.loads(raw)["ordinary"]
    b = json.loads(base)
    j = json.loads(raw)
    assert j["common"] == b["common"] and j["ordinary_state"] == b["ordinary_state"]
    p = o["physical"]; results = o["state"]["results"]; original = b["ordinary"]["state"]["results"]
    assert results[:first] == original
    pending = p["pending"]
    if label != labels[-1]:
        count = labels.index(label)
        assert len(results) == first and len(pending["reports"]) == count
        assert pending["human"][0] == first and [r["fixture"] for r in pending["reports"]] == list(range(first + 1, first + 1 + count))
        assert o["build"] == b["ordinary"]["build"]
        native = {"human": pending["human"][:3], "npc": [{"id": r["fixture"], "report_sha": sha(json.dumps(r,sort_keys=True).encode())} for r in pending["reports"]]}
    else:
        expected = json.loads(unpaid)["ordinary"]["physical"]["pending"]
        assert not pending and len(results) == first + 3 and [r["id"] for r in results[first:]] == list(range(first, first + 3))
        assert p["reports"][-2:] == expected["reports"]
        assert [results[first][k] for k in ("id","away_runs","home_runs")] == expected["human"][:3]
        assert p["reports"][:-2] == b["ordinary"]["physical"]["reports"]
        pack = lambda x: [event for event in x["build"]["build"]["_events"] if event.get("op") == "pack_pick"]
        assert pack(o) == pack(b["ordinary"]) and len(pack(o)) == 1
        assert pack(o)[0]["player"] == "player.kit_rowan" and pack(o)[0]["item"] == "development.fielding"
        stat = lambda x: x["build"]["book"]["_players"]["player.kit_rowan"]["stats"]["fielding"]
        assert stat(o) >= stat(b["ordinary"]) == 4
        banks = lambda x: [x["build"]["bank"]] + [x["opponents"]["clubs"][str(i)]["build"]["bank"] for i in range(1, 6)]
        rewards = lambda x: [event for event in x["_events"] if event.get("op") == "reward"]
        for team, (after, before) in enumerate(zip(banks(o),banks(b["ordinary"]),strict=True)):
            prev,new = rewards(before),rewards(after)
            assert new[:-1] == prev
            relevant = [r for r in results[first:] if team in (r["home"],r["away"])]
            assert len(relevant) == 1
            r = relevant[0]
            assert new[-1]["game"] == r["id"] and new[-1]["win"] == (team == (r["away"] if r["away_runs"] > r["home_runs"] else r["home"]))
        native = {"cash_before": b["ordinary"]["build"]["bank"]["_state"]["cash"], "cash_after": o["build"]["bank"]["_state"]["cash"], "verified_rewards": 6, "kit_fielding": stat(o), "scores": [[r["id"],r["away_runs"],r["home_runs"]] for r in results[first:]],
                  "results": len(results), "round_index": o["state"]["round_index"]}
    return dict(label=label, sha256=sha(raw), backup_sha256=sha(previous), size=len(raw), native=native)

def capture(custody, label, raw, prior, base, unpaid, first, labels):
    summary = witness(label, raw, prior, base, unpaid, first, labels)
    short = (json.dumps(summary,sort_keys=True)+"\n").encode()
    dest = custody / (label+".zip")
    with zipfile.ZipFile(dest,"x",compression=zipfile.ZIP_DEFLATED) as z:
        z.writestr("owner.json",raw)
        z.writestr("witness.json",short)
    assert sum(p.stat().st_size for p in custody.iterdir() if p.is_file()) < 24*1024**2
    with zipfile.ZipFile(dest) as z:
        assert z.testzip() is None and z.read("owner.json")==raw and z.read("witness.json")==short
    print("CUSTODY",sha(dest.read_bytes()),short.decode().strip(),flush=True)

def run(stage, custody, source, previous, mode, base_round, labels):
    profile = Path(tempfile.mkdtemp(prefix="cp314-"+mode+".",dir=stage))
    env = {}
    for key, name in (("HOME","home"),("XDG_CONFIG_HOME","config"),("XDG_DATA_HOME","data"),("XDG_CACHE_HOME","cache")):
        p=profile/name; p.mkdir(); env[key]=str(p)
    slot=profile/"data/WiffaltroStarterBeta-v1/wiffaltro-common-career-v4.json"
    slot.parent.mkdir()
    slot.write_bytes(source)
    bak=slot.with_suffix(".json.bak")
    if previous: bak.write_bytes(previous)
    signals=slot.parent/"cp314-boundaries"; signals.mkdir()
    args=[str(stage/"Wiffaltro.x86_64"),"--headless","--audio-driver","Dummy","--log-file",str(profile/"engine.log"),"--","cp314",mode,str(base_round),sha(source)]
    log=custody/(mode+"-native.log")
    captures=[]
    with log.open("xb") as out:
        proc=subprocess.Popen(args,cwd=stage,env=env,stdout=out,stderr=subprocess.STDOUT,start_new_session=True)
        print("APP_PID",mode,proc.pid,profile,flush=True)
        deadline=time.monotonic()+(1200 if mode=="round" else 250)
        try:
            while proc.poll() is None:
                if time.monotonic()>deadline: raise TimeoutError(mode)
                if mode=="round" and len(captures)<len(labels):
                    label=labels[len(captures)]
                    marker=signals/(label+".ready")
                    if marker.exists() and marker.stat().st_size == 64:
                        raw=slot.read_bytes()
                        prior=captures[-1] if captures else source
                        assert marker.read_text()==sha(raw) and bak.read_bytes()==prior
                        capture(custody,label,raw,prior,source,prior if label==labels[-1] else None,base_round*3,labels)
                        capsig=signals/(label+".ack-tmp")
                        capsig.write_text(sha(raw)); capsig.rename(signals/(label+".ack"))
                        captures.append(raw)
                time.sleep(0.10)
        finally:
            if proc.poll() is None:
                proc.terminate()
                try: proc.wait(timeout=10)
                except subprocess.TimeoutExpired: proc.kill(); proc.wait()
            print("APP_EXIT",mode,proc.returncode,flush=True)
    lines=log.read_text().splitlines()
    assert proc.returncode==0 and not any(x.startswith(("FAIL ","ERROR:","SCRIPT ERROR:")) for x in lines),lines[-15:]
    assert not slot.with_suffix(".json.tmp").exists()
    if mode=="cold":
        assert slot.read_bytes()==source and bak.read_bytes()==previous
    else:
        assert len(captures)==4 and slot.read_bytes()==captures[-1] and bak.read_bytes()==captures[-2]
    return captures

def main():
    root, primary, backup, output, source_pin, backup_pin, round_index = sys.argv[1:]
    stage, fixture, previous, custody=(Path(p).resolve(strict=True) for p in (root, primary, backup, output))
    assert stage.name.startswith("wiffaltro-cp314-proof-") and custody.name.startswith("wiffaltro-cp314-custody.")
    assert not list(custody.iterdir()) and shutil.disk_usage(custody).free>32*1024**2
    assert sha((stage/"Wiffaltro.x86_64").read_bytes())==ELF
    base_round = int(round_index)
    assert str(base_round)==round_index and 2 <= base_round <= 8
    first = base_round*3
    labels = (f"human-{first}",f"npc-{first+1}",f"npc-{first+2}",f"settle-{first+3}")
    source, prior = fixture.read_bytes(), previous.read_bytes()
    assert sha(source)==source_pin and sha(prior)==backup_pin
    owner=json.loads(source); o=owner["ordinary"]; b=json.loads(prior)
    assert owner["common"]==b["common"] and owner["ordinary_state"]==b["ordinary_state"]
    assert o["state"]["round_index"]==base_round and len(o["state"]["results"])==first and not o["physical"]["pending"]
    rows=sorted((r for r in o["state"]["schedule"] if r["round"]==base_round),key=lambda r:r["id"])
    assert [r["id"] for r in rows]==list(range(first,first+3))
    assert 0 in (rows[0]["home"],rows[0]["away"]) and all(0 not in (r["home"],r["away"]) for r in rows[1:])
    stages=run(stage,custody,source,prior,"round",base_round,labels)
    run(stage,custody,stages[-1],stages[-2],"cold",base_round,labels)
    assert fixture.read_bytes()==source and previous.read_bytes()==prior
    print(f"CP314 exact cold reopen; Round {base_round+1} only.",flush=True)

if __name__=="__main__":
    main()
