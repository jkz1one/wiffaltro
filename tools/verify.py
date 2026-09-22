#!/usr/bin/env python3
"""Verify a disposable source copy, preserving user files and engine caches."""
import argparse
import datetime
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = "4.7.2"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN"))
    parser.add_argument("--timeout", type=int, default=180)
    args = parser.parse_args()
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    output = ROOT / "builds" / "verification" / stamp
    output.mkdir(parents=True)
    summary = {"status": "failed", "steps": [], "logs": str(output)}

    def run(name, command, cwd=ROOT, marker=None):
        print(f"Checking {name}...", flush=True)
        with (output / f"{name}.log").open("w") as log:
            try:
                result = subprocess.run(command, cwd=cwd, stdout=log,
                                        stderr=subprocess.STDOUT, timeout=args.timeout)
            except subprocess.TimeoutExpired:
                summary["steps"].append({"name": name, "passed": False, "timeout": True})
                raise RuntimeError(f"{name}: timed out after {args.timeout}s") from None
        text = (output / f"{name}.log").read_text(errors="replace")
        bad = re.search(r"(?m)^\s*(?:SCRIPT ERROR:|ERROR:|Parse Error:)", text)
        passed = result.returncode == 0 and not bad and (marker is None or marker in text)
        summary["steps"].append({"name": name, "passed": passed,
                                 "exit_code": result.returncode})
        if not passed:
            print(text[-6000:])
            raise RuntimeError(f"{name} failed; see {output / (name + '.log')}")
        return text.strip()

    try:
        summary["commit"] = run("revision", ["git", "rev-parse", "HEAD"])
        summary["working_tree"] = run("working-tree", ["git", "status", "--short"])
        run("diff-check", ["git", "diff", "--check"])
        gd_files = sorted(str(p) for p in (ROOT / "src").rglob("*.gd"))
        for tool in ("gdparse", "gdlint"):
            installed = ROOT / "builds" / "tooling" / "python" / "bin" / tool
            executable = str(installed) if installed.is_file() else shutil.which(tool)
            if not executable:
                raise RuntimeError("Install gdtoolkit==4.3.4 in your Python environment")
            run(tool, [executable, *gd_files])
        godot = args.godot
        configured = ROOT / "builds" / "tooling" / "godot-path.txt"
        if not godot and configured.is_file():
            godot = configured.read_text().strip()
        godot = godot or shutil.which("godot") or shutil.which("godot4")
        mac = Path("/Applications/Godot.app/Contents/MacOS/Godot")
        if not godot and mac.is_file():
            godot = str(mac)
        if not godot:
            raise RuntimeError("Godot missing. Set GODOT_BIN or pass --godot /path/to/Godot")
        version = run("engine-version", [godot, "--version"])
        if not version.startswith(VERSION + ".stable."):
            raise RuntimeError(f"Expected Godot {VERSION} stable, got {version}")
        summary["engine"] = version
        with tempfile.TemporaryDirectory(prefix="wiffaltro-verify-") as temp:
            stage = Path(temp)
            shutil.copy2(ROOT / "project.godot", stage)
            for folder in ("src", "assets"):
                if (ROOT / folder).exists():
                    shutil.copytree(ROOT / folder, stage / folder)
            base = [godot, "--headless", "--path", str(stage)]
            run("import", [*base, "--editor", "--quit"])
            failures = []
            checks = [
                ("switch-hitter", [*base, "--fixed-fps", "60",
                                   "res://src/tests/switch_hitter_test.tscn"],
                 "Wiffaltro switch hitter checks passed."),
                ("pitch-handedness", [*base, "--fixed-fps", "60",
                                      "res://src/tests/pitch_handedness_test.tscn"],
                 "Wiffaltro pitch handedness checks passed:"),
                ("venue-stats", [*base, "--fixed-fps", "60",
                                 "res://src/tests/venue_stats_test.tscn"],
                 "Wiffaltro venue and pause stats checks passed."),
                ("pitch-routing", [*base, "--fixed-fps", "60",
                                   "res://src/tests/pitch_routing_test.tscn"],
                 "Wiffaltro pitch routing checks passed:"),
                ("season-flow", [*base, "--fixed-fps", "60",
                                 "res://src/tests/season_flow_test.tscn"],
                 "Wiffaltro season flow checks passed:"),
                ("season-enrichment", [*base, "--fixed-fps", "60",
                                       "res://src/tests/season_enrichment_test.tscn"],
                 "Wiffaltro season enrichment checks passed."),
                ("season-shell", [*base, "--fixed-fps", "60",
                                  "res://src/tests/season_shell_test.tscn"],
                 "Wiffaltro season shell checks passed:"),
                ("camera-audit", [*base, "res://src/tests/camera_audit_test.tscn"],
                 "Wiffaltro camera audit passed."),
                ("presentation-polish", [*base, "--fixed-fps", "60",
                                         "res://src/tests/presentation_polish_test.tscn"],
                 "Wiffaltro presentation polish checks passed."),
                ("pitch-quality", [*base, "res://src/tests/pitch_quality_test.tscn"],
                 "Wiffaltro pitch quality checks passed."),
                ("playtest-followup", [*base, "--fixed-fps", "60",
                                       "res://src/tests/playtest_followup_test.tscn"],
                 "Wiffaltro playtest followup checks passed."),
                ("playtest-feedback", [*base, "--fixed-fps", "60",
                                       "res://src/tests/playtest_feedback_test.tscn"],
                 "Wiffaltro playtest feedback checks passed."),
                ("player-flow", [*base, "--fixed-fps", "60", "res://src/tests/player_flow_test.tscn"],
                 "Wiffaltro player flow checks passed."),
                ("live-match", [*base, "--fixed-fps", "60", "res://src/tests/live_match_test.tscn"],
                 "Wiffaltro live match checks passed:"),
                ("match-soak", [*base, "res://src/tests/match_soak_test.tscn"],
                 "Wiffaltro match soak passed:"),
                ("physical-ball", [*base, "--fixed-fps", "60", "res://src/tests/physical_ball_test.tscn"],
                 "Wiffaltro physical ball checks passed."),
                ("regressions", [*base, "res://src/tests/core_regression_test.tscn"],
                 "Wiffaltro core regression checks passed."),
                ("qc-export", [*base, "res://src/tests/qc_export_test.tscn"],
                 "Wiffaltro QC export checks passed."),
                ("main-scene", [*base, "--quit-after", "120"], None),
            ]
            for name, command, marker in checks:
                try:
                    run(name, command, marker=marker)
                except RuntimeError as error:
                    failures.append(str(error))
            if failures:
                raise RuntimeError("; ".join(failures))
        summary["status"] = "passed"
        print("Verification passed.")
    except (RuntimeError, OSError) as error:
        summary["error"] = str(error)
        print(f"Verification failed: {error}", file=sys.stderr)
    finally:
        (output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
        print(f"Logs: {output}")
    return 0 if summary["status"] == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
