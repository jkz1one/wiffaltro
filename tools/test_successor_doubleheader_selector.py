#!/usr/bin/env python3
"""Reproduce pure selector checks in two isolated Godot processes.

Run: python3 tools/test_successor_doubleheader_selector.py [--godot godot]
Copies only the selector, test, and four unchanged authentic pure dependencies.
No source project/autoloads, player saves, fixture archives, or external evidence
are read. Temporary engine caches are isolated and removed. Only source belongs
in the checkpoint. This is NOT live career/Dynasty, playoff, reward or save proof.
"""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

DEPENDENCIES = (
    "season_doubleheader_rules.gd",
    "league_rules.gd",
    "club_asset_journal.gd",
    "club_value_contract.gd",
)
MARKER = "SUCCESSOR_DOUBLEHEADER_SELECTOR_PASS"


def run(command, env):
    result = subprocess.run(command, env=env, text=True, capture_output=True, timeout=90)
    output = result.stdout + result.stderr
    print(output, end="")
    if result.returncode or any(token in output for token in ("SCRIPT ERROR:", "ERROR:")):
        raise RuntimeError(f"Godot check failed (exit {result.returncode})")
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    args = parser.parse_args()
    godot = shutil.which(args.godot)
    if godot is None:
        parser.error("Godot executable not found")
    root = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="wiffaltro-selector-") as temp:
        stage = Path(temp)
        project = stage / "project"
        sources = project / "src/gameplay/season"
        sources.mkdir(parents=True)
        for name in DEPENDENCIES:
            shutil.copyfile(root / "src/gameplay/season" / name, sources / name)
        shutil.copyfile(root / "drafts/successor-doubleheader-selector-v1/schedule_selector.gd.txt", project / "selector.gd")
        shutil.copyfile(root / "tests/successor_doubleheader_selector.gd.txt", project / "test.gd")
        (project / "project.godot").write_text('config_version=5\n[application]\nconfig/name="SelectorUnitOnly"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        env = os.environ.copy()
        for variable, directory in (("HOME", "home"), ("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache")):
            isolated = stage / directory
            isolated.mkdir()
            env[variable] = str(isolated)
        env["GODOT_SILENCE_ROOT_WARNING"] = "1"
        run([godot, "--headless", "--path", str(project), "--editor", "--quit"], env)
        for _ in range(2):
            output = run([godot, "--headless", "--path", str(project), "--script", "test.gd"], env)
            if MARKER not in output:
                raise RuntimeError("Missing positive test receipt")
    print("PASS: two fresh processes; no save or evidence archive input")


if __name__ == "__main__":
    main()
