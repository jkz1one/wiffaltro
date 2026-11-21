#!/usr/bin/env python3
"""Assemble audited successor sources into a NEW isolated project, never saves.

The original project's main scene remains unchanged. This is a source assembly,
not a verified distributable. Optional tests must be named explicitly.
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import subprocess

FAMILIES = (
    'successor-career-completion-v1', 'successor-career-assets-v1',
    'successor-owner-live-v1', 'successor-owner-general-v1',
    'successor-owner-terminal-v1', 'successor-league-v1',
    'successor-career-general-v1', 'successor-owner-continuation-v1',
    'successor-career-history-v1', 'successor-career-v1',
    'successor-league-general-v2', 'successor-v7', 'successor-owner-v1',
    'successor-owner-career-v1',
)
LAUNCHER = 'res://src/presentation/season/successor_owner_career_v1/launcher.tscn'
SELECTOR_FAMILY = 'successor-doubleheader-selector-v1'
PLAY_FAMILY = 'successor-live-play-v1'
PAIRED_HISTORY_FAMILIES = ('successor-paired-history-v1', 'successor-request-composition-v1',
                           'successor-team-composition-v1', 'successor-settled-workload-v1')
PLAY_LAUNCHER = 'res://src/presentation/season/successor_live_play_v1/launcher.tscn'
LIVE_FAMILY = 'successor-live-owner-v1'
LIVE_LAUNCHER = 'res://src/presentation/season/successor_live_owner_v1/launcher.tscn'
DYNASTY_FAMILY = 'successor-dynasty-owner-v1'
DYNASTY_LAUNCHER = 'res://src/presentation/season/successor_dynasty_owner_v1/launcher.tscn'
ORIGINAL_LAUNCHER = 'res://src/presentation/season/season_app.tscn'
# The unchanged raw configuration already used for the CP165 source review.
AUTHORED_PROJECT_SHA256 = '9650ccc2ce6957eda9f088663597bd754098dc05d42d0a00c9fa25c7085e35fd'

def safe(name):
    p = PurePosixPath(name)
    if p.is_absolute() or '..' in p.parts or str(p) != name:
        raise ValueError(f'Unsafe relative path: {name}')
    return name

def sha(data):
    return hashlib.sha256(data).hexdigest()

def assemble(repo, destination, tests=(), live_owner=False, live_play=False, dynasty_owner=False,
             preserve_authored_project=False):
    repo, destination = repo.resolve(), destination.resolve()
    if destination.exists():
        raise ValueError('Destination must not exist; no files or saves are overwritten')
    if preserve_authored_project and (not dynasty_owner or live_owner or live_play):
        raise ValueError('Authored-project mode requires only the private Common V4 launcher')
    payload = {}
    tracked = subprocess.check_output(['git', 'ls-files', '-z', '--', 'src', 'project.godot'], cwd=repo).decode().split('\0')
    for name in filter(None, tracked):
        path = repo / safe(name)
        if path.is_symlink() or not path.is_file():
            raise ValueError(f'Not an ordinary tracked source: {name}')
        payload[name] = path.read_bytes()
    requested = set(tests)
    found = set()
    families = (FAMILIES + ((LIVE_FAMILY,) if live_owner or live_play or dynasty_owner else ())
                + ((SELECTOR_FAMILY, PLAY_FAMILY) + PAIRED_HISTORY_FAMILIES if live_play or dynasty_owner else ())
                + ((DYNASTY_FAMILY,) if dynasty_owner else ()))
    launcher = DYNASTY_LAUNCHER if dynasty_owner else PLAY_LAUNCHER if live_play else LIVE_LAUNCHER if live_owner else LAUNCHER
    for family in families:
        manifest = json.loads((repo / 'drafts' / family / 'DRAFT_MANIFEST.json').read_text())
        for row in manifest.get('files', []) + manifest.get('additions', []):
            name = safe(row['restore_path'])
            if not name.startswith('src/') and name not in requested:
                continue
            source = repo / safe(row['backup_path'])
            if source.is_symlink():
                raise ValueError(f'Symlink source: {source}')
            data = source.read_bytes()
            if sha(data) != row['sha256'] or len(data) != row['bytes']:
                raise ValueError(f'Manifest mismatch: {row["backup_path"]}')
            if name in payload and payload[name] != data:
                raise ValueError(f'Conflicting assembly path: {name}')
            payload[name] = data
            if name in requested:
                found.add(name)
    if found != requested:
        raise ValueError(f'Tests not found in manifests: {sorted(requested-found)}')
    config = payload['project.godot'].decode()
    original = f'run/main_scene="{ORIGINAL_LAUNCHER}"'
    if config.count(original) != 1:
        raise ValueError('Unexpected original main scene')
    if preserve_authored_project:
        if sha(payload['project.godot']) != AUTHORED_PROJECT_SHA256:
            raise ValueError('Reviewed authored project bytes changed; no assembly written')
        if launcher.removeprefix('res://') not in payload:
            raise ValueError('Private Common V4 startup scene is missing')
    else:
        payload['project.godot'] = config.replace(original, f'run/main_scene="{launcher}"').encode()
    destination.mkdir(parents=True)
    for name, data in payload.items():
        target = destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    record = {'format': 'wiffaltro-source-assembly-v1', 'launcher': launcher,
              'files': {name: sha(data) for name, data in sorted(payload.items())}}
    if preserve_authored_project:
        record['startup'] = {'mode': 'explicit-private-scene-v1',
                             'default_scene': ORIGINAL_LAUNCHER,
                             'explicit_scene': launcher,
                             'required_environment': {'WIFFALTRO_DYNASTY_ENGINEERING': '1'}}
    (destination / 'ASSEMBLY.json').write_text(json.dumps(record, indent=2)+'\n')
    return record

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('destination', type=Path)
    parser.add_argument('--test', action='append', default=[])
    parser.add_argument('--live-owner', action='store_true', help='Select the additive materialized-owner launcher; old project and save slots remain unchanged')
    parser.add_argument('--live-play', action='store_true', help='Select materialized current-season gameplay with a separate save slot')
    parser.add_argument('--dynasty-owner', action='store_true', help='Select the private Dynasty engineering route; requires WIFFALTRO_DYNASTY_ENGINEERING=1 at launch, not a public unlock')
    parser.add_argument('--preserve-authored-project', action='store_true',
                        help='Keep the exact reviewed project; launch Common V4 with its explicit scene')
    args = parser.parse_args()
    result = assemble(Path(__file__).resolve().parents[1], args.destination, args.test,
                      args.live_owner, args.live_play, args.dynasty_owner, args.preserve_authored_project)
    print(f'Assembled {len(result["files"])} verified source files; no saves copied.')
