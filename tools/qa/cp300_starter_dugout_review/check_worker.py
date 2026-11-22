"""Direct, no-environment Linux Starter worker smoke on the generated CP170 close."""
import base64
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

REV = "1a226548fad8932770868dcb286d1466a30976d571c2238ed78964fefb02b082"
PROPOSAL = "8894317a3e9b862b41714a6e69eca4948702f7c7da5c272b715501da03f45cdb"
DRAFT = "3252c4df9f4f16b26d0470db14624df09f58bd4770924b552cba12c46d38801f"
PREFIX = "WIFFALTRO_STARTER_DUGOUT_REVIEW_V1 "
ARG = "--starter-dugout-review-v1="
exe, source = (Path(arg).resolve(strict=True) for arg in sys.argv[1:])
work = Path(tempfile.mkdtemp(prefix="wiffaltro-cp300-worker-"))
print(work, flush=True)
env = {k: v for k, v in os.environ.items() if not k.startswith("WIFFALTRO_")}
env.update(HOME=str(work / "home"), XDG_DATA_HOME=str(work / "data"),
           XDG_CONFIG_HOME=str(work / "config"), XDG_CACHE_HOME=str(work / "cache"))
Path(env["HOME"]).mkdir()
slot = work / "data/WiffaltroStarterBeta-v1/wiffaltro-common-career-v4.json"
slot.parent.mkdir(parents=True)
assert hashlib.sha256(source.read_bytes()).hexdigest() == REV
shutil.copyfile(source, slot)
job = dict(revision=REV, nonce=os.urandom(32).hex())


def encoded(value):
    raw = json.dumps(value, sort_keys=True, separators=(",", ":"))
    return ARG + base64.b64encode(raw.encode()).decode()


def run(*args, code=3):
    r = subprocess.run([str(exe), "--headless", "--audio-driver", "Dummy", "--", *args],
                       env=env, cwd=work, capture_output=True, timeout=120)
    assert r.returncode == code, (r.returncode, r.stdout[-500:], r.stderr[-500:])
    return [x.removeprefix(PREFIX) for x in r.stdout.decode().splitlines() if x.startswith(PREFIX)]


def unchanged():
    assert not slot.is_symlink()
    assert hashlib.sha256(slot.read_bytes()).hexdigest() == REV
    assert not Path(str(slot) + ".tmp").exists() and not Path(str(slot) + ".bak").exists()


for label, args in (
    ("invalid encoding", (ARG + "x",)),
    ("extra argument", (encoded(job), "--scene=res://not-allowed.tscn")),
    ("caller path", (encoded({**job, "path": "user://elsewhere.json"}),)),
    ("stale", (encoded({**job, "revision": "c" * 64}),)),
):
    assert not run(*args)
    unchanged()
    print("PASS", label, flush=True)
# Training fixture here is a generated close; never link the native test at
# personal data. A deliberately wrong link to that same approved fixture is
# rejected before opening the slot.
slot.rename(slot.with_suffix(".held"))
slot.symlink_to(slot.with_suffix(".held"))
assert not run(encoded(job))
slot.unlink()
slot.with_suffix(".held").rename(slot)
unchanged()
print("PASS linked slot refused", flush=True)

result = run(encoded(job), code=0)
assert len(result) == 1
assert json.loads(result[0]) == {"job": job, "proposal": PROPOSAL, "draft": DRAFT}
unchanged()
print("PASS exact no-env native preview, source and backup state unchanged", flush=True)
