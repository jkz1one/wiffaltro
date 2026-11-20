#!/usr/bin/env python3
"""Request serialization parity against exact cp98 on retained real pair/grant.
No new gameplay, admission, result validation or historical team composer.
The original request factory still owns context construction and guards.
"""
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
    parser.add_argument('--grant-stage', required=True, type=Path)
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
    grant_source = args.grant_stage.resolve()
    if not grant_source.name.startswith('wiffaltro-genuine-grant-'):
        parser.error('Requires cp97 disposable grant stage')
    grant_path = grant_source / SAVE.replace('successor-general-build-v7-r2.json', 'genuine-grant.json')
    grant_data = grant_path.read_bytes()
    if hashlib.sha256(grant_data).hexdigest() != "9171332a254fdeaba81ecb8d6e7e8258f619847cc00d087d1dcc4c153ec57809":
        parser.error("Not the exact genuine cp97 grant fixture")
    stage = Path(tempfile.mkdtemp(prefix='wiffaltro-request-composition-'))
    project = stage / 'project'
    record = assemble_successor.assemble(repo, project, live_play=True)
    for name, digest in record['files'].items():
        assert hashlib.sha256((project / name).read_bytes()).hexdigest() == digest
    frozen_path = 'drafts/successor-league-general-v2/src/gameplay/season/successor_league_general_v2/physical_fixtures.gd.txt'
    baseline = subprocess.check_output(['git', 'show', '27e21756b8a9309ddcb16992578ed34a9bdeed3f:' + frozen_path], cwd=repo)
    assert (repo / frozen_path).read_bytes() == baseline
    frozen = baseline.decode()
    begin = frozen.index('\tvar rows: Array = []', frozen.index('static func request_key('))
    end = frozen.index('\n\nfunc resolve(', begin)
    derived = frozen[begin:end].replace('_resource(player.definition,', 'Frozen._resource(player.definition,').replace('seed_for(season, fixture)', 'Frozen.seed_for(season, fixture)')
    candidate = (repo / 'drafts/successor-request-composition-v1/request_key.gd.txt').read_text()
    assert candidate[candidate.index('\tvar rows: Array = []'):].rstrip() == derived.rstrip()
    for family in ('successor-paired-history-v1', 'successor-request-composition-v1'):
        manifest = json.loads((repo / 'drafts' / family / 'DRAFT_MANIFEST.json').read_text())
        for row in manifest['files']:
            content = (repo / row['backup_path']).read_bytes()
            assert len(content) == row['bytes'] and hashlib.sha256(content).hexdigest() == row['sha256']
            destination = project / row['restore_path']
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(content)
    print('PASS: exact pinned frozen source and mechanically derived body', flush=True)
    for name in ('successor_pair_history_context', 'successor_request_composition'):
        target = project / 'tests' / (name + '.gd')
        target.parent.mkdir(exist_ok=True)
        target.write_bytes((repo / 'tests' / (name + '.gd.txt')).read_bytes())
    scene = project / 'tests/successor_request_composition.tscn'
    scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/successor_request_composition.gd" id="1"]\n[node name="Grant" type="Node"]\nscript = ExtResource("1")\n')
    target = stage / SAVE
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
    (stage / SAVE.replace("successor-general-build-v7-r2.json", "genuine-grant.json")).write_bytes(grant_data)
    env = support.environment(stage)
    print('Disposable request evidence:', stage, flush=True)
    execute([godot, '--headless', '--editor', '--path', str(project), '--quit'], env, 180)
    for mode in ('first', 'independent-cold'):
        output = execute([godot, '--headless', '--path', str(project),
                          'res://tests/successor_request_composition.tscn', '--', mode], env, 300)
        if 'REQUEST_COMPOSITION_PASS' not in output:
            raise RuntimeError('Missing positive ' + mode + ' request proof')
    assert (source / SAVE).read_bytes() == data == target.read_bytes()
    assert grant_path.read_bytes() == grant_data
    print('PASS: exact request composition parity; no full history validation')


if __name__ == '__main__':
    main()
