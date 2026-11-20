#!/usr/bin/env python3
"""Bounded Build-only genuine grant proof from the cp96 authentic pair.

No generator/seed hunt. Supply the retained isolated seed1001 pair stage from
cp96's runner. Its exact final fixture is pinned; input is copied read-only to
a fresh audited assembly, and native General replay validates it again.
Controlled paid shopping is NOT NPC policy or granted-match qualification.
Only source belongs in Git; generated journals/logs stay disposable.
"""
import argparse
import hashlib
from pathlib import Path
import shutil
import sys
import tempfile
sys.dont_write_bytecode = True
import assemble_successor
import test_successor_schedule_wiring as support
from test_successor_pair_history_context import execute

DIGEST = '17f7e34cbfef9f1e4e58afa6e3d1a5664b7660ed4e32479e374793fe1a178294'
SAVE = 'data/godot/app_userdata/Wiffaltro/successor-general-build-v7-r2.json'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixture-stage', required=True, type=Path)
    parser.add_argument('--godot', default='godot')
    args = parser.parse_args()
    source = args.fixture_stage.resolve()
    if not source.name.startswith('wiffaltro-signature-'):
        parser.error('Only the isolated original General runner stage is accepted')
    data = (source / SAVE).read_bytes()
    if hashlib.sha256(data).hexdigest() != DIGEST:
        parser.error('Not the exact completed authentic cp96 seed1001 pair fixture')
    godot = shutil.which(args.godot)
    if not godot:
        parser.error('Godot unavailable')
    repo = Path(__file__).resolve().parents[1]
    stage = Path(tempfile.mkdtemp(prefix='wiffaltro-genuine-grant-'))
    project = stage / 'project'
    record = assemble_successor.assemble(repo, project)
    for name, digest in record['files'].items():
        assert hashlib.sha256((project / name).read_bytes()).hexdigest() == digest
    for name in ('successor_pair_history_context', 'successor_genuine_grant'):
        target = project / 'tests' / (name + '.gd')
        target.parent.mkdir(exist_ok=True)
        target.write_bytes((repo / 'tests' / (name + '.gd.txt')).read_bytes())
    scene = project / 'tests/successor_genuine_grant.tscn'
    scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/successor_genuine_grant.gd" id="1"]\n[node name="Grant" type="Node"]\nscript = ExtResource("1")\n')
    target = stage / SAVE
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
    env = support.environment(stage)
    print('Disposable grant evidence:', stage, flush=True)
    execute([godot, '--headless', '--editor', '--path', str(project), '--quit'], env, 180)
    for mode in ('birth', 'cold'):
        output = execute([godot, '--headless', '--path', str(project),
                          'res://tests/successor_genuine_grant.tscn', '--', mode], env, 180)
        if 'GENUINE_GRANT_HISTORY_PASS' not in output:
            raise RuntimeError('Missing positive ' + mode + ' grant proof')
    assert (source / SAVE).read_bytes() == data == target.read_bytes()
    print('PASS: genuine grant Build history birth/cold; no granted-match qualification')


if __name__ == '__main__':
    main()
