#!/usr/bin/env python3
"""Buy one authentic between-leg pack upgrade from the paid cp110 save.

If absent, regenerate from cp110 with
tools/test_successor_hidden_first_settlement.py --fixture-stage <cp109-stage>
then pass that runner's printed stage here. Its docstring links earlier source
reproducers. No match runs or raw evidence transfers take place here."""
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

BASE = 'f2bdf5feab11891351819f4cf9c92d7b35a2f286'
DIGEST = 'bf7a233d75a42b9a34f1d02fc73afa6f2f627a0fef9b6cbfa36baf8933a84109'
BACKUP = 'b546e49c8fec95223ffaf3093f97d44ae27809a3ff42ff9dda2b432784c10bdb'
TEST = 'successor_hidden_earned_paired_shop'



def run(project, home, mode, godot):
    output = execute([godot, '--headless', '--fixed-fps', '60', '--path', str(project),
                      'res://tests/' + TEST + '.tscn', '--', mode], environment(home), 420)
    if 'HIDDEN_EARNED_PAIRED_SHOP_PASS' not in output:
        raise RuntimeError('Missing earned paired shop qualification: ' + mode)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixture-stage', required=True, type=Path)
    parser.add_argument('--godot', default='godot')
    args = parser.parse_args()
    origin = args.fixture_stage.resolve() / 'settlement' / draft.SLOT
    primary = origin.read_bytes()
    old_backup = Path(str(origin) + '.bak').read_bytes()
    if (hashlib.sha256(primary).hexdigest() != DIGEST
            or hashlib.sha256(old_backup).hexdigest() != BACKUP):
        parser.error('Requires the exact retained cp110 primary and backup')
    godot = shutil.which(args.godot)
    if not godot:
        parser.error('Godot unavailable')
    repo = Path(__file__).resolve().parents[1]
    root = Path(tempfile.mkdtemp(prefix='wiffaltro-earned-paired-shop-'))
    print('Retained disposable local stage:', root, flush=True)
    source = (repo / 'tests' / (draft.TEST + '.gd.txt')).read_bytes()
    project = draft.stage(repo, root / 'current', source, godot)
    for name in [TEST, 'successor_hidden_first_settlement']:
        (project / 'tests' / (name + '.gd')).write_bytes((repo / 'tests' / (name + '.gd.txt')).read_bytes())
    (project / 'tests' / (TEST + '.tscn')).write_text(
        '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/'
        + TEST + '.gd" id="1"]\n[node name="Proof" type="Node"]\nscript = ExtResource("1")\n')
    dst = root / 'shop' / draft.SLOT
    dst.parent.mkdir(parents=True)
    dst.write_bytes(primary)
    backup_path = Path(str(dst) + '.bak')
    backup_path.write_bytes(old_backup)
    start = json.loads(primary)
    before = primary
    for index, stage in enumerate(('open', 'pay', 'pick')):
        run(project, root / 'shop', stage, godot)
        durable = dst.read_bytes()
        assert durable != before and backup_path.read_bytes() == before
        print('DURABLE', stage, 'SHA256=', hashlib.sha256(durable).hexdigest(), flush=True)
        value = json.loads(durable)
        leaf = value['ordinary']
        original = start['ordinary']
        assert {k: v for k, v in value.items() if k != 'ordinary'} == {
            k: v for k, v in start.items() if k != 'ordinary'}
        for key in ['state', 'physical', 'opponents', 'ownership']:
            assert leaf[key] == original[key]
        build, old_build = leaf['build'], original['build']
        events = build['build']['_events']
        assert events[:2] == old_build['build']['_events']
        assert build['bank']['_events'][0] == old_build['bank']['_events'][0]
        assert [e['op'] for e in events[2:]] == ['open', 'pack_open', 'pack_pick'][:index + 1]
        assert build['bank']['_state']['cash'] == (18 if index == 0 else 10)
        if index < 2:
            before = durable
    run(project, root / 'shop', 'cold', godot)
    assert dst.read_bytes() == durable and backup_path.read_bytes() == before
    pick = value['ordinary']['build']['build']['_events'][-1]
    print('AUTHORED UPGRADE:', pick['item'], pick['player'], flush=True)
    target = root / 'tamper' / draft.SLOT
    target.parent.mkdir(parents=True)
    Path(str(target) + '.bak').write_bytes(before)
    for fault in ['charge', 'pick', 'extra-op']:
        corrupt = copy.deepcopy(value)
        build = corrupt['ordinary']['build']
        if fault == 'charge':
            build['bank']['_events'][1]['amount'] -= 1
        elif fault == 'pick':
            build['build']['_events'][-1]['player'] = 'player.unavailable'
        else:
            build['build']['_events'].append(copy.deepcopy(build['build']['_events'][-1]))
        invalid = json.dumps(corrupt, sort_keys=True, separators=(',', ':')).encode()
        target.write_bytes(invalid)
        run(project, root / 'tamper', 'tamper-' + fault, godot)
        assert target.read_bytes() == invalid and Path(str(target) + '.bak').read_bytes() == before
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
    print('PASS: actual earned paired pack upgrade, exact retries and cold; Standard cp110 byte parity')


if __name__ == '__main__':
    main()
