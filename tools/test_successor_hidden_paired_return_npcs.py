#!/usr/bin/env python3
"""Run only actual return NPC4 and NPC5 from the genuine cp112 human boundary.

If absent, regenerate from cp112 with
tools/test_successor_hidden_paired_return.py --fixture-stage <cp111-stage>
then pass its printed stage here. It documents earlier inputs.
The first leg and human return are not replayed here. --completed-stage
rechecks exact retained outputs without replaying either NPC."""
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

BASE = '1a3b5dd426e1530928b4eb470cbc68f61261acfe'
DIGEST = 'db39d33cd182e8e98bf61b7bf6863d8ce95b155fdbd3d939893c9e29e1752dc2'
BACKUP = '7f544c926d547ef0372e7cf1810ff2f2557f27f79818b17ed4d8cbb1189a2ba9'
TEST = 'successor_hidden_paired_return_npcs'
COMPLETE = '781b4392e33d95ed8ac44d1eabf4920fd56e0e633e99ec7f249f52378f6947e9'
PARTIAL = 'dd4ed382ea0b3c13b5ad0ba34fe6e6d7eeffb288d8892e10de073036d75462a8'



def run(project, home, mode, godot):
    output = execute([godot, '--headless', '--fixed-fps', '60', '--path', str(project),
                      'res://tests/' + TEST + '.tscn', '--', mode], environment(home), 420)
    if 'HIDDEN_PAIRED_RETURN_NPCS_PASS' not in output:
        raise RuntimeError('Missing private paired return NPC qualification: ' + mode)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixture-stage', required=True, type=Path)
    parser.add_argument('--completed-stage', type=Path)
    parser.add_argument('--godot', default='godot')
    args = parser.parse_args()
    origin = args.fixture_stage.resolve() / 'return-human' / draft.SLOT
    primary = origin.read_bytes()
    old_backup = Path(str(origin) + '.bak').read_bytes()
    if (hashlib.sha256(primary).hexdigest() != DIGEST
            or hashlib.sha256(old_backup).hexdigest() != BACKUP):
        parser.error('Requires the exact retained cp112 primary and backup')
    godot = shutil.which(args.godot)
    if not godot:
        parser.error('Godot unavailable')
    repo = Path(__file__).resolve().parents[1]
    root = Path(tempfile.mkdtemp(prefix='wiffaltro-paired-return-npcs-'))
    print('Retained disposable local stage:', root, flush=True)
    source = (repo / 'tests' / (draft.TEST + '.gd.txt')).read_bytes()
    project = draft.stage(repo, root / 'current', source, godot)
    for name in [TEST, 'successor_hidden_paired_return', 'successor_hidden_first_settlement']:
        (project / 'tests' / (name + '.gd')).write_bytes((repo / 'tests' / (name + '.gd.txt')).read_bytes())
    (project / 'tests' / (TEST + '.tscn')).write_text(
        '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/'
        + TEST + '.gd" id="1"]\n[node name="Proof" type="Node"]\nscript = ExtResource("1")\n')
    dst = root / 'return-npcs' / draft.SLOT
    dst.parent.mkdir(parents=True)
    backup_path = Path(str(dst) + '.bak')
    if args.completed_stage:
        original_completed = args.completed_stage.resolve() / 'return-npcs' / draft.SLOT
        durable = original_completed.read_bytes()
        before = Path(str(original_completed) + '.bak').read_bytes()
        assert hashlib.sha256(durable).hexdigest() == COMPLETE
        assert hashlib.sha256(before).hexdigest() == PARTIAL
        dst.write_bytes(durable)
        backup_path.write_bytes(before)
    else:
        dst.write_bytes(primary)
        backup_path.write_bytes(old_backup)
        run(project, root / 'return-npcs', 'npc4', godot)
        before = dst.read_bytes()
        assert backup_path.read_bytes() == primary
        print('DURABLE npc4 SHA256=', hashlib.sha256(before).hexdigest(), flush=True)
        run(project, root / 'return-npcs', 'npc5', godot)
        durable = dst.read_bytes()
        assert backup_path.read_bytes() == before
        print('DURABLE npc5 SHA256=', hashlib.sha256(durable).hexdigest(), flush=True)
    start = json.loads(primary)
    history = start['ordinary']['physical']['pending']
    prior_reports = []
    for data, order in [(before, [4]), (durable, [4, 5])]:
        restored = json.loads(data)
        physical = restored['ordinary']['physical']
        pending = physical['pending']
        assert {**pending, 'reports': []} == history
        assert [r['fixture'] for r in pending['reports']] == order
        assert pending['reports'][:-1] == prior_reports
        prior_reports = pending['reports']
        physical['pending'] = history
        assert restored == start  # Every historical and non-pending field.
    run(project, root / 'return-npcs', 'cold', godot)
    assert dst.read_bytes() == durable and backup_path.read_bytes() == before
    value = json.loads(durable)
    target = root / 'tamper' / draft.SLOT
    target.parent.mkdir(parents=True)
    Path(str(target) + '.bak').write_bytes(before)
    for fault in ['terminal-request', 'terminal-debt', 'reordered', 'duplicate', 'historic-request']:
        corrupt = copy.deepcopy(value)
        physical = corrupt['ordinary']['physical']
        reports = physical['pending']['reports']
        if fault == 'terminal-request':
            reports[1]['request'] = '0' * 64
        elif fault == 'terminal-debt':
            debt = reports[1]['report']['pair'][0]['debt']
            key = next(k for k, v in debt.items() if v > 0)
            debt[key] += 1
        elif fault == 'reordered':
            reports.reverse()
        elif fault == 'duplicate':
            reports[1] = copy.deepcopy(reports[0])
        else:
            physical['reports'][0]['request'] = '0' * 64
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
    if args.completed_stage:
        assert original_completed.read_bytes() == durable and Path(str(original_completed) + '.bak').read_bytes() == before
    print('PASS: actual both private return NPCs and complete unpaid pending cold; Standard cp112 byte parity')


if __name__ == '__main__':
    main()
