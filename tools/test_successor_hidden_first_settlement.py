#!/usr/bin/env python3
"""Settle exact cp109 complete pending. No human or NPC simulation runs.

If absent, regenerate from the cp109 source with
tools/test_successor_hidden_second_npc.py --fixture-stage <cp108-stage>
and pass its printed stage to this command. That runner documents how to
rebuild the earlier source inputs. No raw artifacts leave local stages."""
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

BASE = '163a11d1cf54851431a22351d66635ebaf17efd3'
DIGEST = 'b546e49c8fec95223ffaf3093f97d44ae27809a3ff42ff9dda2b432784c10bdb'
BACKUP = '3ebce134efa44cd9f5765abfee9c274c6ed6e873d8fc870cbb227351a66aca56'
TEST = 'successor_hidden_first_settlement'



def run(project, home, mode, godot):
    output = execute([godot, '--headless', '--fixed-fps', '60', '--path', str(project),
                      'res://tests/' + TEST + '.tscn', '--', mode], environment(home), 420)
    if 'HIDDEN_FIRST_SETTLEMENT_PASS' not in output:
        raise RuntimeError('Missing first settlement qualification: ' + mode)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixture-stage', required=True, type=Path)
    parser.add_argument('--godot', default='godot')
    args = parser.parse_args()
    origin = args.fixture_stage.resolve() / 'npc' / draft.SLOT
    primary = origin.read_bytes()
    old_backup = Path(str(origin) + '.bak').read_bytes()
    if (hashlib.sha256(primary).hexdigest() != DIGEST
            or hashlib.sha256(old_backup).hexdigest() != BACKUP):
        parser.error('Requires the exact retained cp109 primary and backup')
    godot = shutil.which(args.godot)
    if not godot:
        parser.error('Godot unavailable')
    repo = Path(__file__).resolve().parents[1]
    root = Path(tempfile.mkdtemp(prefix='wiffaltro-first-settlement-'))
    print('Retained disposable local stage:', root, flush=True)
    source = (repo / 'tests' / (draft.TEST + '.gd.txt')).read_bytes()
    project = draft.stage(repo, root / 'current', source, godot)
    (project / 'tests' / (TEST + '.gd')).write_bytes((repo / 'tests' / (TEST + '.gd.txt')).read_bytes())
    (project / 'tests' / (TEST + '.tscn')).write_text(
        '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/'
        + TEST + '.gd" id="1"]\n[node name="Proof" type="Node"]\nscript = ExtResource("1")\n')
    dst = root / 'settlement' / draft.SLOT
    dst.parent.mkdir(parents=True)
    dst.write_bytes(primary)
    Path(str(dst) + '.bak').write_bytes(old_backup)
    run(project, root / 'settlement', 'settle', godot)
    durable = dst.read_bytes()
    print('DURABLE FIRST SETTLEMENT SHA256=', hashlib.sha256(durable).hexdigest(), flush=True)
    run(project, root / 'settlement', 'cold', godot)
    assert dst.read_bytes() == durable and Path(str(dst) + '.bak').read_bytes() == primary
    value = json.loads(durable)
    ordinary = value['ordinary']
    pending = json.loads(primary)['ordinary']['physical']['pending']
    assert ordinary['physical']['pending'] == {}
    assert ordinary['physical']['reports'] == pending['reports']
    assert [row['id'] for row in ordinary['state']['results']] == [0, 1, 2]
    assert ordinary['state']['player_results'] == ordinary['state']['results'][:1]
    assert value['common'] == json.loads(primary)['common']
    target = root / 'tamper' / draft.SLOT
    target.parent.mkdir(parents=True)
    Path(str(target) + '.bak').write_bytes(primary)
    for fault in ['request', 'omitted-report', 'reordered', 'forged-receipt', 'human-score', 'future-round']:
        corrupt = copy.deepcopy(value)
        leaf = corrupt['ordinary']
        physical = leaf['physical']
        if fault == 'request':
            physical['reports'][1]['request'] = '0' * 64
        elif fault == 'omitted-report':
            physical['reports'].pop()
            physical['cursor'] -= 1
        elif fault == 'reordered':
            physical['reports'].reverse()
        elif fault == 'forged-receipt':
            event = leaf['build']['bank']['_events'][0]
            event['win'] = not event['win']
        elif fault == 'human-score':
            # Same winner, but its exact final score is no longer the real score.
            a, b = (leaf['state'][field][0] for field in ['results', 'player_results'])
            score = 'away_runs' if a['away_runs'] > a['home_runs'] else 'home_runs'
            a[score] += 1
            b[score] += 1
            leaf['career']['runs'][0]['proof']['scores'][0][3 if score == 'away_runs' else 4] += 1
        else:
            leaf['state']['round_index'] = 2
        invalid = json.dumps(corrupt, sort_keys=True, separators=(',', ':')).encode()
        target.write_bytes(invalid)
        run(project, root / 'tamper', 'tamper-' + fault, godot)
        assert target.read_bytes() == invalid
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
    print('PASS: actual first-leg settlement, save retry and fresh cold; Standard cp109 byte parity')


if __name__ == '__main__':
    main()
