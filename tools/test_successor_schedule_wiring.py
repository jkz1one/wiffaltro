#!/usr/bin/env python3
"""Qualify selector creation/codec wiring without admitting Doubleheader.

Real assembler live-play output, isolated HOME/XDG, generated birth saves only.
Standard and Dugout save via Store then reopen in a new process. Named
Sponsorship uses synthetic canonical JSON plus restore_common in separate
processes, NOT shared OwnerStore save qualification; standalone rejection stays. Pinned cp93 (default) or cp94 baseline builds run the same birth/cold contract and final
bytes must match. A separate real Dynasty assembly tests its shared menu's
Doubleheader exclusion. No archive fixtures, original saves, gameplay, playoffs,
reward, or Doubleheader career qualification. Only temporary synthetic data.
Run: python3 tools/test_successor_schedule_wiring.py [--godot godot]
"""
import argparse
import hashlib
import importlib.util
import io
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import sys

sys.dont_write_bytecode = True
BASELINE = "5deec1f5a7a423b247b4d5cc808452d6e076e96a"
BASELINES = {BASELINE: "cp93", "c5801675f9c1d55ea8d14e51846de66c8e771448": "cp94"}

MARKER = "SUCCESSOR_SCHEDULE_WIRING_PASS"
TEST = "tests/successor_schedule_wiring.gd"
SCENE = "res://tests/successor_schedule_wiring.tscn"
LEAGUES = ("standard", "dugout")


def assembler(repo, name):
    spec = importlib.util.spec_from_file_location(name, repo / "tools/assemble_successor.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def environment(stage, baseline=False):
    env = os.environ.copy()
    for variable, folder in (("HOME", "home"), ("XDG_DATA_HOME", "data"),
                             ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache")):
        path = stage / folder
        path.mkdir(parents=True, exist_ok=True)
        env[variable] = str(path)
    env["WIFFALTRO_ISOLATED_TEST"] = "1"
    env["WIFFALTRO_BASELINE"] = "1" if baseline else "0"
    env["WIFFALTRO_DYNASTY_ENGINEERING"] = "1"
    return env


def run(command, env, log, marker=False):
    print(f"Running {log.name}", flush=True)
    with log.open("xb") as output:
        result = subprocess.run(command, env=env, stdout=output,
                                stderr=subprocess.STDOUT, timeout=300)
    text = log.read_text()
    if result.returncode or "SCRIPT ERROR:" in text or "ERROR:" in text or (marker and MARKER not in text):
        print(text)
        raise RuntimeError(f"Failed {log.name}: exit {result.returncode}")
    if marker:
        print(next(line for line in text.splitlines() if MARKER in line), flush=True)


def stage_project(repo, stage, test_source, dynasty=False):
    project = stage / "project"
    record = assembler(repo, "assembly_" + stage.name).assemble(
        repo, project, live_play=True, dynasty_owner=dynasty)
    target = project / TEST
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(test_source)
    target.with_suffix(".tscn").write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://' + TEST + '" id="1"]\n[node name="ScheduleWiring" type="Node"]\nscript = ExtResource("1")\n')
    # Explicit test-only staging; production assembly source hashes remain intact.
    for name, digest in record["files"].items():
        if hashlib.sha256((project / name).read_bytes()).hexdigest() != digest:
            raise RuntimeError(f"Assembly changed: {name}")
    return project


def births(repo, stage, test_source, godot, baseline=False):
    project = stage_project(repo, stage, test_source)
    env = environment(stage / "import", baseline)
    run([godot, "--headless", "--path", str(project), "--editor", "--import", "--quit"],
        env, stage / "import.log")
    result = {}
    for league in LEAGUES:
        case = stage / league
        env = environment(case, baseline)
        for mode in ("fresh", "cold"):
            run([godot, "--headless", "--path", str(project), SCENE, "--", mode, league],
                env, stage / f"{league}-{mode}.log", marker=True)
        expected = list((case / "data").rglob("schedule-wiring-expected.json"))
        actual = list((case / "data").rglob("wiffaltro-materialized-play-v1.json"))
        if len(expected) != 1 or len(actual) != 1 or expected[0].read_bytes() != actual[0].read_bytes():
            raise RuntimeError(f"Missing or changed synthetic save: {league}")
        result[league] = actual[0].read_bytes()
        if league == "standard":
            named = list((case / "data").rglob("schedule-wiring-named-codec.json"))
            if len(named) != 1:
                raise RuntimeError("Missing named codec-only canonical fixture")
            result["sponsorship-codec-only"] = named[0].read_bytes()
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--baseline-ref", default=BASELINE, help="Pinned cp93 (default) or cp94 revision only")
    args = parser.parse_args()
    godot = shutil.which(args.godot)
    if not godot:
        parser.error("Godot executable not found")
    repo = Path(__file__).resolve().parents[1]
    revision = subprocess.check_output(["git", "rev-parse", "--verify", args.baseline_ref + "^{commit}"], cwd=repo, text=True).strip()
    if revision not in BASELINES:
        parser.error("Baseline must resolve to exact verified cp93 or cp94")
    baseline_label = BASELINES[revision]
    test_source = (repo / (TEST + ".txt")).read_bytes()
    with tempfile.TemporaryDirectory(prefix="wiffaltro-schedule-wiring-") as temp:
        stage = Path(temp)
        print(f"Temporary isolated stage: {stage}; baseline {baseline_label} {revision}", flush=True)
        baseline_repo = stage / "baseline-source"
        baseline_repo.mkdir()
        archive = subprocess.check_output(["git", "archive", "--format=tar", revision], cwd=repo)
        with tarfile.open(fileobj=io.BytesIO(archive), mode="r:") as tar:
            tar.extractall(baseline_repo, filter="data")
        subprocess.run(["git", "init", "-q", str(baseline_repo)], check=True)
        subprocess.run(["git", "add", "--", "src", "project.godot"], cwd=baseline_repo, check=True)
        current = births(repo, stage / "current", test_source, godot)
        baseline = births(baseline_repo, stage / "baseline", test_source, godot, True)
        for league in current:
            if current[league] != baseline[league]:
                raise RuntimeError(f"{baseline_label} serialized bytes changed for {league}")
            print(f"BYTE PARITY {league}: {hashlib.sha256(current[league]).hexdigest()}")
        menu_stage = stage / "menu"
        project = stage_project(repo, menu_stage, test_source, dynasty=True)
        env = environment(menu_stage)
        run([godot, "--headless", "--path", str(project), "--editor", "--import", "--quit"],
            env, menu_stage / "import.log")
        run([godot, "--headless", "--path", str(project), SCENE, "--", "menu"],
            env, menu_stage / "menu.log", marker=True)
    print(f"PASS: schedule wiring; real birth/save/cold; {baseline_label} byte parity; Doubleheader remains unadmitted")


if __name__ == "__main__":
    main()
