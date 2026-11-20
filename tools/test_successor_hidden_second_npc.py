#!/usr/bin/env python3
"""Replay only NPC2 from the genuine cp108 V4 human+NPC1 boundary.

If absent, from cp107 (de1d004) run tools/test_successor_hidden_paired_pending.py.
From cp108 run tools/test_successor_hidden_first_npc.py --fixture-stage with
the printed cp107 stage, then pass that printed cp108 stage to this command.
No raw artifacts leave the isolated local stages."""
import argparse
import hashlib
import io
import json
import re
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

BASE = '3fb88686803f645956a7d04a45a6734defc18bad'
DIGEST = '3ebce134efa44cd9f5765abfee9c274c6ed6e873d8fc870cbb227351a66aca56'
BACKUP = '8f0177cd510ff6b2e7c5a49485750f322da5aa9d6e41ab1db3ac7b4c5f2e655e'
TEST = 'successor_hidden_second_npc'


def run(project, home, mode, godot):
    output = execute([godot, '--headless', '--fixed-fps', '60', '--path', str(project),
                      'res://tests/' + TEST + '.tscn', '--', mode], environment(home), 420)
    if 'HIDDEN_SECOND_NPC_PASS' not in output:
        raise RuntimeError('Missing second NPC qualification: ' + mode)


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
        parser.error('Requires the exact retained cp108 primary and backup')
    godot = shutil.which(args.godot)
    if not godot:
        parser.error('Godot unavailable')
    repo = Path(__file__).resolve().parents[1]
    root = Path(tempfile.mkdtemp(prefix='wiffaltro-second-npc-'))
    print('Retained disposable local stage:', root, flush=True)
    source = (repo / 'tests' / (draft.TEST + '.gd.txt')).read_bytes()
    project = draft.stage(repo, root / 'current', source, godot)
    (project / 'tests' / (TEST + '.gd')).write_bytes((repo / 'tests' / (TEST + '.gd.txt')).read_bytes())
    (project / 'tests' / (TEST + '.tscn')).write_text(
        '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/'
        + TEST + '.gd" id="1"]\n[node name="Proof" type="Node"]\nscript = ExtResource("1")\n')
    dst = root / 'npc' / draft.SLOT
    dst.parent.mkdir(parents=True)
    dst.write_bytes(primary)
    Path(str(dst) + '.bak').write_bytes(old_backup)
    run(project, root / 'npc', 'play', godot)
    durable = dst.read_bytes()
    print('DURABLE COMPLETE PENDING SHA256=', hashlib.sha256(durable).hexdigest(), flush=True)
    run(project, root / 'npc', 'cold', godot)
    assert dst.read_bytes() == durable and Path(str(dst) + '.bak').read_bytes() == primary
    value = json.loads(durable)
    pending = value['ordinary']['physical']['pending']
    original_pending = json.loads(primary)['ordinary']['physical']['pending']
    assert {**pending, 'reports': pending['reports'][:1]} == original_pending
    proof = pending['reports'][1]
    tag = ('"request":"' + proof['request'] + '"').encode()
    assert durable.count(tag) == 1
    target = root / 'tamper' / draft.SLOT
    target.parent.mkdir(parents=True)
    target.write_bytes(durable.replace(tag, ('"request":"' + '0' * 64 + '"').encode(), 1))
    Path(str(target) + '.bak').write_bytes(primary)
    run(project, root / 'tamper', 'tamper-request', godot)
    # Change only NPC2's saved score lexeme, preserving the rest of the envelope.
    scores = list(re.finditer(rb'"physical":\{"away_runs":(\d+)(?:\.0)?,', durable))
    assert len(scores) == 2
    score = proof['report']['physical']['away_runs']
    assert int(scores[1][1]) == score
    start, end = scores[1].span(1)
    target.write_bytes(durable[:start] + str(score + 1).encode() + durable[end:])
    run(project, root / 'tamper', 'tamper-report', godot)
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
    print('PASS: actual NPC2 complete unpaid pending and fresh App cold; Standard cp108 byte parity')


if __name__ == '__main__':
    main()
