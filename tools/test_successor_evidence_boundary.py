#!/usr/bin/env python3
"""Shape-only evidence dispatch tests plus exact-cp94 save/cold regressions.

Synthetic payload skeletons are NOT actual played reports, workload proof or
Doubleheader admission. Uses the real assembler and an isolated Node scene.
Then reuses the schedule regression runner: real Standard/Dugout Store saves,
independent cold processes, named Sponsorship codec-only hydration, exact cp94
byte parity and hidden/rejected Doubleheader UI. No player saves or fixture
archives are read; only generated temporary test data and pinned Git source.
"""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
import test_successor_schedule_wiring as regression

BASELINE = "c5801675f9c1d55ea8d14e51846de66c8e771448"
TEST = "tests/successor_evidence_boundary.gd"
MARKER = "SUCCESSOR_EVIDENCE_BOUNDARY_PASS"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    args = parser.parse_args()
    godot = shutil.which(args.godot)
    if not godot:
        parser.error("Godot executable not found")
    repo = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="wiffaltro-evidence-boundary-") as temp:
        stage = Path(temp)
        project = stage / "project"
        record = regression.assembler(repo, "evidence_assembly").assemble(repo, project, live_play=True)
        target = project / TEST
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes((repo / (TEST + ".txt")).read_bytes())
        target.with_suffix(".tscn").write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://' + TEST + '" id="1"]\n[node name="EvidenceBoundary" type="Node"]\nscript = ExtResource("1")\n')
        for name, digest in record["files"].items():
            if regression.hashlib.sha256((project / name).read_bytes()).hexdigest() != digest:
                raise RuntimeError(f"Assembly changed: {name}")
        env = regression.environment(stage)
        regression.run([godot, "--headless", "--path", str(project), "--editor", "--import", "--quit"], env, stage / "import.log")
        for number in range(2):
            log = stage / f"boundary-{number}.log"
            regression.run([godot, "--headless", "--path", str(project), "res://" + TEST.replace(".gd", ".tscn")], env, log)
            text = log.read_text()
            if MARKER not in text:
                raise RuntimeError("Missing positive shape test receipt")
            print(next(line for line in text.splitlines() if MARKER in line), flush=True)
    subprocess.run([sys.executable, str(repo / "tools/test_successor_schedule_wiring.py"),
                    "--godot", godot, "--baseline-ref", BASELINE], check=True, env=os.environ.copy())
    print("PASS: evidence shapes and cp94 regressions; no Doubleheader admission or played-evidence claim")


if __name__ == "__main__":
    main()
