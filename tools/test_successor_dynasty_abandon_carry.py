#!/usr/bin/env python3
"""Exercise authentic abandoned Dynasty continuation with isolated generated evidence."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
import assemble_successor
from test_successor_dynasty_post_purchase import TEST as POST_PURCHASE, digest, evidence, install, read_slots
from test_successor_schedule_wiring import environment

TEST = 'successor_dynasty_abandon_carry'


def qualify(root, repo, godot, paid, pending):
    project = root / 'project'
    assemble_successor.assemble(repo, project, dynasty_owner=True)
    (project / 'tests').mkdir(exist_ok=True)
    for name in (TEST, POST_PURCHASE):
        (project / 'tests' / (name + '.gd')).write_bytes((repo / 'tests' / (name + '.gd.txt')).read_bytes())
    (project / 'tests' / (TEST + '.tscn')).write_text(
        '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/'
        + TEST + '.gd" id="1"]\n[node name="Proof" type="Node"]\nscript = ExtResource("1")\n')

    def run(home, arguments, label, budget):
        with (root / (label + '.log')).open('xb') as log:
            process = subprocess.run([godot, '--headless', '--path', str(project), *arguments],
                                     env=environment(home), stdout=log, stderr=subprocess.STDOUT,
                                     timeout=budget, check=False)
        output = (root / (label + '.log')).read_text()
        if label != 'import' or process.returncode:
            print(output, end='', flush=True)
        assert process.returncode == 0 and 'SCRIPT ERROR:' not in output and 'Parse Error:' not in output, label
        if label != 'import':
            assert 'DYNASTY_ABANDON_CARRY_PASS ' + label in output

    def stage(name, home=None):
        run(home or saved, ['res://tests/' + TEST + '.tscn', '--', name], name, 240)
        slots = read_slots(home or saved)
        print('STAGE', name, *(digest(x) if x is not None else 'no-backup' for x in slots), flush=True)
        return slots

    run(root / 'import', ['--editor', '--quit'], 'import', 240)
    blocked, saved = root / 'pending', root / 'career'
    install(blocked, pending)
    install(saved, paid, pending)
    assert stage('pending', blocked) == (pending, None)
    closed, backup = stage('abandon')
    assert backup == paid
    initial, abandon = json.loads(paid), json.loads(closed)
    for field in ('ordinary', 'ordinary_state', 'dynasty'):
        assert initial[field] == abandon[field], field
    proposed, backup = stage('propose')
    assert backup == closed
    preview = json.loads(proposed)
    assert {k: v for k, v in preview.items() if k != 'proposal'} == {
        k: v for k, v in abandon.items() if k != 'proposal'
    }
    continued, backup = stage('next')
    assert backup == proposed
    after = json.loads(continued)
    for field in ('ordinary', 'ordinary_state', 'common', 'ledger'):
        assert preview[field] == after[field], field
    start = after['last_transition']
    assert start['profiles_before'] == preview['last_close']['profiles'] and start['proposal'] == preview['proposal']
    assert stage('cold') == (continued, proposed)
    print('PASS: actual abandoned Dynasty carries into season two; original ordinary save retained; no games replayed')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence', type=Path, required=True, help='Previously archived generated evidence; opened read-only')
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--stage-dir', type=Path, help='Optional new empty local directory for generated evidence')
    args = parser.parse_args()
    godot = shutil.which(args.godot)
    if not godot:
        parser.error('Godot unavailable')
    repo = Path(__file__).resolve().parents[1]
    paid, pending = evidence(args.evidence)
    if args.stage_dir:
        stage_dir = args.stage_dir.resolve()
        stage_dir.mkdir(mode=0o700)
        qualify(stage_dir, repo, godot, paid, pending)
    else:
        with tempfile.TemporaryDirectory(prefix='wiffaltro-dynasty-abandon-carry-') as tmp:
            qualify(Path(tmp), repo, godot, paid, pending)


if __name__ == '__main__':
    main()
