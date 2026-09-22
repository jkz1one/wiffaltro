#!/usr/bin/env python3
"""Run the isolated field-scale research fixture; never import the root checkout."""
import datetime
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    engine = (ROOT / "builds/tooling/godot-path.txt").read_text().strip()
    version = subprocess.check_output([engine, "--version"], text=True).strip()
    if not version.startswith("4.7.2.stable."):
        raise SystemExit(f"Expected pinned Godot 4.7.2, got {version}")
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    output = ROOT / "builds" / "field-scale-audit" / stamp
    output.mkdir(parents=True)
    with tempfile.TemporaryDirectory(prefix="wiffaltro-scale-audit-") as temp:
        stage = Path(temp)
        shutil.copy2(ROOT / "project.godot", stage)
        for folder in ("src", "assets"):
            if (ROOT / folder).exists():
                shutil.copytree(ROOT / folder, stage / folder)
        shutil.copy2(ROOT / "tools/audits/field_scale_audit.gd", stage / "audit.gd")
        (stage / "audit.tscn").write_text(
            '[gd_scene load_steps=2 format=3]\n'
            '[ext_resource type="Script" path="res://audit.gd" id="1"]\n'
            '[node name="Audit" type="Node"]\nscript = ExtResource("1")\n'
        )
        base = [engine, "--headless", "--path", str(stage)]
        commands = [
            ("import", [*base, "--editor", "--quit"]),
            ("audit", [*base, "--fixed-fps", "60", "res://audit.tscn",
                       "--", str(output / "results.json")]),
        ]
        for name, command in commands:
            result = subprocess.run(command, capture_output=True, text=True, timeout=180)
            log = result.stdout + result.stderr
            (output / f"{name}.log").write_text(log)
            if result.returncode or re.search(r"(?m)^\s*(?:SCRIPT ERROR:|ERROR:)", log):
                raise SystemExit(log)
        data = json.loads((output / "results.json").read_text())
        assert len(data["rows"]) == 432
        assert all(len(row["outcomes"]) == 4 for row in data["rows"])
        data["source_commit"] = subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
        (output / "results.json").write_text(json.dumps(data, indent=2) + "\n")
    print(f"432 Jolt trajectories completed. Evidence: {output}")


if __name__ == "__main__":
    main()
