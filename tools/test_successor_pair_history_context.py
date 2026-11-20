#!/usr/bin/env python3
"""Source-only General pair history context reproducer; no owner admission.

Generate a real seed-1001 standalone General pair using the existing audited
runner, then probe historical context in a separate process. Optional resume
accepts only that runner's isolated stage and repeats its exact-source checks.
Actual saves/logs remain local and are never checkpoint payload. This does not
qualify the materialized shared-owner path or install a production validator.
The test reports actual grant coverage; zero grants cannot qualify grant timing.
Generation is capped at 37 minutes; the context probe at 12 minutes.
"""
import argparse
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys

sys.dont_write_bytecode = True
import test_successor_schedule_wiring as support

TEST = "tests/successor_pair_history_context.gd"
MARKER = "SUCCESSOR_PAIR_HISTORY_CONTEXT_PASS"


def execute(command, env, timeout):
    # Only this subprocess group is stopped on timeout; no unrelated engine jobs.
    process = subprocess.Popen(command, env=env, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, text=True, start_new_session=True)
    try:
        output, _ = process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGTERM)
        try:
            output, _ = process.communicate(timeout=10)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            output, _ = process.communicate()
        print(output)
        raise RuntimeError("Bounded reproducer timed out; no qualification claimed")
    print(output, end="", flush=True)
    if process.returncode or "SCRIPT ERROR:" in output or "ERROR:" in output:
        raise RuntimeError(f"Reproducer failed: exit {process.returncode}")
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--resume-stage", type=Path)
    args = parser.parse_args()
    godot = shutil.which(args.godot)
    if not godot:
        parser.error("Godot executable not found")
    repo = Path(__file__).resolve().parents[1]
    command = [sys.executable, str(repo / "tools/test_successor_signature.py"),
               "--godot", godot, "--doubleheader-round"]
    if args.resume_stage:
        stage = args.resume_stage.resolve()
        if not stage.is_dir() or not stage.name.startswith("wiffaltro-signature-"):
            parser.error("Resume requires an existing isolated General runner stage")
        command += ["--doubleheader-resume-stage", str(stage)]
    output = execute(command, os.environ.copy(), 2220)
    receipts = [line.split(": ", 1)[1] for line in output.splitlines()
                if line.startswith("Isolated test evidence: ")]
    if len(receipts) != 1 or "doubleheader-cold-complete:" not in output:
        raise RuntimeError("Missing completed pair/cold generation receipt")
    stage = Path(receipts[0]).resolve()
    if args.resume_stage and stage != args.resume_stage.resolve():
        raise RuntimeError("Unexpected evidence stage")
    project = stage / "project"
    target = project / TEST
    target.write_bytes((repo / (TEST + ".txt")).read_bytes())
    scene = target.with_suffix(".tscn")
    scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://' + TEST + '" id="1"]\n[node name="HistoryContext" type="Node"]\nscript = ExtResource("1")\n')
    env = support.environment(stage)
    result = execute([godot, "--headless", "--path", str(project),
                      "res://" + TEST.replace(".gd", ".tscn")], env, 720)
    if MARKER not in result:
        raise RuntimeError("Missing positive historical context proof receipt")
    print("PASS: standalone General source-only context proof; no shared-owner qualification")


if __name__ == "__main__":
    main()
