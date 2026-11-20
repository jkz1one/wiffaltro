#!/usr/bin/env python3
"""Play one genuine private return human from the upgraded cp111 owner.

If absent, regenerate from cp111 with
tools/test_successor_hidden_earned_paired_shop.py --fixture-stage <cp110-stage>
then pass that runner's printed stage here. Its source links earlier inputs.
This runs one return human, not any first-leg or NPC rerun."""
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

BASE = '2a6966dc04b2d47cc97ab50570a079679e2d9eda'
DIGEST = '7f544c926d547ef0372e7cf1810ff2f2557f27f79818b17ed4d8cbb1189a2ba9'
BACKUP = '7de90337da34a3779d7f568d4f41396e0c955a6cf70cd3fb2ec616de88e999f8'
TEST = 'successor_hidden_paired_return'



def run(project, home, mode, godot):
    output = execute([godot, '--headless', '--fixed-fps', '60', '--path', str(project),
                      'res://tests/' + TEST + '.tscn', '--', mode], environment(home), 420)
    if 'HIDDEN_PAIRED_RETURN_PASS' not in output:
        raise RuntimeError('Missing private paired return qualification: ' + mode)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixture-stage', required=True, type=Path)
    parser.add_argument('--godot', default='godot')
    args = parser.parse_args()
    origin = args.fixture_stage.resolve() / 'shop' / draft.SLOT
    primary = origin.read_bytes()
    old_backup = Path(str(origin) + '.bak').read_bytes()
    if (hashlib.sha256(primary).hexdigest() != DIGEST
            or hashlib.sha256(old_backup).hexdigest() != BACKUP):
        parser.error('Requires the exact retained cp111 primary and backup')
    godot = shutil.which(args.godot)
    if not godot:
        parser.error('Godot unavailable')
    repo = Path(__file__).resolve().parents[1]
    root = Path(tempfile.mkdtemp(prefix='wiffaltro-paired-return-'))
    print('Retained disposable local stage:', root, flush=True)
    source = (repo / 'tests' / (draft.TEST + '.gd.txt')).read_bytes()
    project = draft.stage(repo, root / 'current', source, godot)
    for name in [TEST, 'successor_hidden_first_settlement']:
        (project / 'tests' / (name + '.gd')).write_bytes((repo / 'tests' / (name + '.gd.txt')).read_bytes())
    (project / 'tests' / (TEST + '.tscn')).write_text(
        '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/'
        + TEST + '.gd" id="1"]\n[node name="Proof" type="Node"]\nscript = ExtResource("1")\n')
    dst = root / 'return-human' / draft.SLOT
    dst.parent.mkdir(parents=True)
    dst.write_bytes(primary)
    backup_path = Path(str(dst) + '.bak')
    backup_path.write_bytes(old_backup)
    run(project, root / 'return-human', 'play', godot)
    durable = dst.read_bytes()
    print('DURABLE RETURN HUMAN SHA256=', hashlib.sha256(durable).hexdigest(), flush=True)
    assert backup_path.read_bytes() == primary
    start = json.loads(primary)
    value = json.loads(durable)
    restored = copy.deepcopy(value)
    pending = restored['ordinary']['physical']['pending']
    assert pending['human'][0] == 3 and pending['reports'] == []
    restored['ordinary']['physical']['pending'] = {}
    assert restored == start  # Every historical and non-pending saved field.
    run(project, root / 'return-human', 'cold', godot)
    assert dst.read_bytes() == durable and backup_path.read_bytes() == primary
    target = root / 'tamper' / draft.SLOT
    target.parent.mkdir(parents=True)
    Path(str(target) + '.bak').write_bytes(primary)
    for fault in ['binding', 'paired-debt', 'historic-archive']:
        corrupt = copy.deepcopy(value)
        physical = corrupt['ordinary']['physical']
        if fault == 'binding':
            physical['pending']['binding']['request'] = '0' * 64
        elif fault == 'paired-debt':
            debt = physical['pending']['human'][13][0]['pair']['debt']
            key = next(k for k, v in debt.items() if v > 0)
            debt[key] += 1
        else:
            physical['reports'][0]['request'] = '0' * 64
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
    print('PASS: actual upgraded private return human pending and cold; Standard cp111 byte parity')


if __name__ == '__main__':
    main()
