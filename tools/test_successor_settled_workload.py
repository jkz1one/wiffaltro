#!/usr/bin/env python3
"""Settled workload/payment checks on the retained exact authentic pair only."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
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
    stage = Path(tempfile.mkdtemp(prefix='wiffaltro-settled-workload-'))
    project = stage / 'project'
    record = assemble_successor.assemble(repo, project, live_play=True)
    for name, digest in record['files'].items():
        assert hashlib.sha256((project / name).read_bytes()).hexdigest() == digest
    frozen_path = 'drafts/successor-league-general-v2/src/gameplay/season/successor_league_general_v2/doubleheader.gd.txt'
    baseline = subprocess.check_output(['git', 'show', '4f8c5739e7aa99ccbb55b0eabe7e3219bdcd104f:' + frozen_path], cwd=repo)
    assert (repo / frozen_path).read_bytes() == baseline
    frozen = baseline.decode()
    a = frozen.index('\tvar players: Array[PlayerDefinition] = []', frozen.index('static func _historical_team'))
    b = frozen.index('\tif not apply', a)
    c = frozen.index('\tfor player: PlayerMatchState in team.roster:', b)
    d = frozen.index('\treturn true', c)
    candidate = (repo / 'drafts/successor-settled-workload-v1/validator.gd.txt').read_text()
    derived = frozen[a:b].replace('prefix.', 'start.') + '\tteam.league_pair = pair.duplicate(true)\n' + frozen[c:d].replace('float(debt.get', 'float(pair.debt.get')
    assert candidate[candidate.index('\tvar players: Array[PlayerDefinition] = []'):candidate.index('\treturn {"team":')] == derived
    for family in ('successor-paired-history-v1', 'successor-settled-workload-v1'):
        manifest = json.loads((repo / 'drafts' / family / 'DRAFT_MANIFEST.json').read_text())
        for row in manifest['files']:
            content = (repo / row['backup_path']).read_bytes()
            assert len(content) == row['bytes'] and hashlib.sha256(content).hexdigest() == row['sha256']
            destination = project / row['restore_path']
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(content)
    print('PASS: exact pinned frozen source and mechanically derived body', flush=True)
    for name in ('successor_pair_history_context', 'successor_settled_workload'):
        target = project / 'tests' / (name + '.gd')
        target.parent.mkdir(exist_ok=True)
        target.write_bytes((repo / 'tests' / (name + '.gd.txt')).read_bytes())
    scene = project / 'tests/successor_settled_workload.tscn'
    scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/successor_settled_workload.gd" id="1"]\n[node name="Grant" type="Node"]\nscript = ExtResource("1")\n')
    target = stage / SAVE
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
    env = support.environment(stage)
    print('Disposable settled evidence:', stage, flush=True)
    execute([godot, '--headless', '--editor', '--path', str(project), '--quit'], env, 180)
    for mode in ('first', 'independent-cold'):
        output = execute([godot, '--headless', '--path', str(project),
                          'res://tests/successor_settled_workload.tscn', '--', mode], env, 300)
        if 'SETTLED_WORKLOAD_PASS' not in output:
            raise RuntimeError('Missing positive ' + mode + ' request proof')
    assert (source / SAVE).read_bytes() == data == target.read_bytes()
    print('PASS: settled workload and paid receipts; no Report or codec qualification')


if __name__ == '__main__':
    main()
