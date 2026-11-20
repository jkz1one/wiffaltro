#!/usr/bin/env python3
"""Settle the exact native cp113 completed return pending; no games rerun.

If absent, regenerate with cp113's tools/test_successor_hidden_paired_return_npcs.py
--fixture-stage <cp112-stage> and pass its printed stage. Its source documents
earlier fixture input provenance. Private artifacts remain local."""
import argparse
import copy
import hashlib
import io
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile

sys.dont_write_bytecode = True
import test_successor_hidden_paired_draft as draft
from test_successor_schedule_wiring import environment
from test_successor_pair_history_context import execute

BASE = '7197cdf8d7973c97c0c7ea2ab6e348d1ea8c4a99'
DIGEST = '781b4392e33d95ed8ac44d1eabf4920fd56e0e633e99ec7f249f52378f6947e9'
BACKUP = 'dd4ed382ea0b3c13b5ad0ba34fe6e6d7eeffb288d8892e10de073036d75462a8'
TEST = 'successor_hidden_paired_return_settlement'



def run(project, home, mode, godot):
    output = execute([godot, '--headless', '--fixed-fps', '60', '--path', str(project),
                      'res://tests/' + TEST + '.tscn', '--', mode], environment(home), 420)
    if 'HIDDEN_PAIRED_RETURN_SETTLEMENT_PASS' not in output:
        raise RuntimeError('Missing private paired return settlement qualification: ' + mode)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixture-stage', required=True, type=Path)
    parser.add_argument('--godot', default='godot')
    args = parser.parse_args()
    origin = args.fixture_stage.resolve() / 'return-npcs' / draft.SLOT
    primary = origin.read_bytes()
    old_backup = Path(str(origin) + '.bak').read_bytes()
    if (hashlib.sha256(primary).hexdigest() != DIGEST
            or hashlib.sha256(old_backup).hexdigest() != BACKUP):
        parser.error('Requires the exact retained cp113 primary and backup')
    godot = shutil.which(args.godot)
    if not godot:
        parser.error('Godot unavailable')
    repo = Path(__file__).resolve().parents[1]
    root = Path(tempfile.mkdtemp(prefix='wiffaltro-pair-settlement-'))
    print('Retained disposable local stage:', root, flush=True)
    source = (repo / 'tests' / (draft.TEST + '.gd.txt')).read_bytes()
    project = draft.stage(repo, root / 'current', source, godot)
    for name in [TEST, 'successor_hidden_paired_return', 'successor_hidden_first_settlement']:
        (project / 'tests' / (name + '.gd')).write_bytes((repo / 'tests' / (name + '.gd.txt')).read_bytes())
    (project / 'tests' / (TEST + '.tscn')).write_text(
        '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/'
        + TEST + '.gd" id="1"]\n[node name="Proof" type="Node"]\nscript = ExtResource("1")\n')
    dst = root / 'settlement' / draft.SLOT
    dst.parent.mkdir(parents=True)
    dst.write_bytes(primary)
    backup_path = Path(str(dst) + '.bak')
    backup_path.write_bytes(old_backup)
    run(project, root / 'settlement', 'settle', godot)
    durable = dst.read_bytes()
    print('DURABLE PAID PAIR SHA256=', hashlib.sha256(durable).hexdigest(), flush=True)
    assert backup_path.read_bytes() == primary
    start = json.loads(primary)
    value = json.loads(durable)
    assert {k: v for k, v in value.items() if k != 'ordinary'} == {
        k: v for k, v in start.items() if k != 'ordinary'}
    old, leaf = (frame['ordinary'] for frame in [start, value])
    assert leaf['physical']['pending'] == {}
    assert leaf['physical']['reports'] == old['physical']['reports'] + old['physical']['pending']['reports']
    assert leaf['state']['results'][:3] == old['state']['results']
    assert leaf['state']['player_results'][:1] == old['state']['player_results']
    for club in range(6):
        earlier, current = (row['build'] if club == 0 else row['opponents']['clubs'][str(club)]['build']
                            for row in [old, leaf])
        for key in ['build', 'bank', 'book']:
            prefix = earlier[key]['_events']
            assert current[key]['_events'][:len(prefix)] == prefix
    run(project, root / 'settlement', 'cold', godot)
    assert dst.read_bytes() == durable and backup_path.read_bytes() == primary
    target = root / 'tamper' / draft.SLOT
    target.parent.mkdir(parents=True)
    Path(str(target) + '.bak').write_bytes(primary)
    for fault in ['terminal-request', 'human-result-debt', 'reordered', 'duplicate-receipt', 'future-round']:
        corrupt = copy.deepcopy(value)
        frame = corrupt['ordinary']
        if fault == 'terminal-request':
            frame['physical']['reports'][-1]['request'] = '0' * 64
        elif fault == 'human-result-debt':
            for row in [frame['state']['results'][3], frame['state']['player_results'][1]]:
                debt = row['doubleheader_evidence'][0]['pair']['debt']
                key = next(k for k, v in debt.items() if v > 0)
                debt[key] += 1
        elif fault == 'reordered':
            reports = frame['physical']['reports']
            reports[-1], reports[-2] = reports[-2], reports[-1]
        elif fault == 'duplicate-receipt':
            events = frame['build']['bank']['_events']
            events.append(copy.deepcopy(events[-1]))
        else:
            frame['state']['round_index'] = 3
        invalid = json.dumps(corrupt, sort_keys=True, separators=(',', ':')).encode()
        target.write_bytes(invalid)
        run(project, root / 'tamper', 'tamper-' + fault, godot)
        assert target.read_bytes() == invalid and Path(str(target) + '.bak').read_bytes() == primary
    current = draft.proof(project, root / 'ordinary', 'standard', godot)
    base = root / 'baseline-source'
    base.mkdir()
    archive = subprocess.check_output(['git', 'archive', '--format=tar', BASE], cwd=repo)
    with tarfile.open(fileobj=io.BytesIO(archive), mode='r:') as tar:
        tar.extractall(base, filter='data')
    subprocess.run(['git', 'init', '-q', str(base)], check=True)
    subprocess.run(['git', 'add', '--', 'src', 'project.godot'], cwd=base, check=True)
    prior = draft.stage(base, root / 'baseline', source, godot)
    assert current == draft.proof(prior, root / 'baseline-ordinary', 'standard', godot)
    assert origin.read_bytes() == primary and Path(str(origin) + '.bak').read_bytes() == old_backup
    print('PASS: actual paid private pair, native sweep and independent cold; Standard cp113 byte parity')


if __name__ == '__main__':
    main()
