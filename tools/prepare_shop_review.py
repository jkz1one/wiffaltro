#!/usr/bin/env python3
"""Prepare an isolated, ordinary playable project for human shop review."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import uuid


ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def prepare(output):
    for folder in ("src", "assets", ".git"):
        if output.is_relative_to(ROOT / folder):
            raise ValueError("Review directory must be outside source and repository metadata")
    # Never overwrite a previous review, project, or save.
    output.mkdir(parents=True, exist_ok=False)
    profile = "WiffaltroReviews/" + uuid.uuid4().hex
    hashes = {}
    for folder in ("src", "assets"):
        if not (ROOT / folder).exists():
            continue
        shutil.copytree(ROOT / folder, output / folder)
        for path in sorted((output / folder).rglob("*")):
            if path.is_file():
                hashes[path.relative_to(output).as_posix()] = digest(path)
    project = (ROOT / "project.godot").read_text()
    section = re.search(r"(?ms)^\[application\]\n(.*?)(?=^\[|\Z)", project)
    if section is None:
        raise ValueError("Project has no application section")
    application = re.sub(
        r"(?m)^config/(?:name|use_custom_user_dir|custom_user_dir_name)(?:\.[^=\n]+)?=.*\n?",
        "",
        section.group(1),
    )
    application = application.rstrip() + (
        '\nconfig/name="Wiffaltro Shop Review"\n'
        'config/use_custom_user_dir=true\n'
        f'config/custom_user_dir_name="{profile}"\n\n'
    )
    project = project[:section.start(1)] + application + project[section.end(1):]
    (output / "project.godot").write_text(project)
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    dirty = bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT))
    manifest = {
        "source_commit": commit,
        "source_working_tree_dirty": dirty,
        "godot_version": "4.7.2",
        "save_profile": profile,
        "original_project_sha256": digest(ROOT / "project.godot"),
        "review_project_sha256": digest(output / "project.godot"),
        "runtime_sha256": hashes,
    }
    (output / "review-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return output / "project.godot"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="New directory; existing directories are refused")
    args = parser.parse_args()
    output = args.output or ROOT / "builds" / "reviews" / ("shop-" + uuid.uuid4().hex)
    try:
        project = prepare(output.resolve())
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"Could not prepare review: {error}\n")
    print(f"Import {project} in Godot 4.7.2, then press F5.")
    print("Fresh save/settings profile. Start New Working Season and follow docs/SHOP_ACCEPTANCE.md.")


if __name__ == "__main__":
    main()
