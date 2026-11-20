#!/usr/bin/env python3
"""Qualify private fixture 6 from the exact cp114 paid-pair starter.

Generate --fixture-stage at cp114 with
python3 tools/test_successor_hidden_paired_return_settlement.py --fixture-stage <cp113-stage>.
This runner actually plays only fixture 6. All gameplay artifacts stay in its
new disposable local stage; verify the two original slot files never change.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import sys
import tempfile

sys.dont_write_bytecode = True
import test_successor_hidden_paired_draft as draft
from test_successor_pair_history_context import execute
from test_successor_paired_resolver_context import install, slot_pair, verify_fixture
from test_successor_schedule_wiring import environment

TEST = 'successor_hidden_paired_next_first'
PAID = ('df33238b26a8fe17136b5f9ace57e175a0ac2bd7db09ea8fffa997bed6ff014d',
        '781b4392e33d95ed8ac44d1eabf4920fd56e0e633e99ec7f249f52378f6947e9')
STANDARD = ('d93a1df232c150e34752db3f598095bee230051e527ae9ed5292690b25fdb2d4',
            '9c4361ddd6d613bfb03e7415f2e90317f49416f5388db74655c76f5122031985')


def run(project, home, mode, godot):
    out = execute([godot, '--headless', '--fixed-fps', '60', '--path', str(project),
                   'res://tests/'+TEST+'.tscn', '--', mode], environment(home), 420)
    assert 'HIDDEN_PAIRED_NEXT_FIRST_PASS' in out


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixture-stage', required=True, type=Path)
    parser.add_argument('--godot', default='godot')
    args = parser.parse_args()
    godot = shutil.which(args.godot)
    if godot is None:
        parser.error('Godot unavailable')
    starter = args.fixture_stage.resolve()
    paid_path, standard_path = (starter / case / draft.SLOT for case in ('settlement', 'ordinary'))
    paid = verify_fixture(slot_pair(paid_path), PAID)
    standard = verify_fixture(slot_pair(standard_path), STANDARD)
    repo = Path(__file__).resolve().parents[1]
    root = Path(tempfile.mkdtemp(prefix='wiffaltro-paired-next-first-'))
    print('Retained disposable local stage:', root, flush=True)
    project = draft.stage(repo,root/'engine',(repo/'tests'/(draft.TEST+'.gd.txt')).read_bytes(),godot)
    for name in (TEST, 'successor_hidden_paired_return_settlement',
                 'successor_hidden_paired_return','successor_hidden_first_settlement'):
        (project/'tests'/(name+'.gd')).write_bytes((repo/'tests'/(name+'.gd.txt')).read_bytes())
    (project/'tests'/(TEST+'.tscn')).write_text(
        '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/'
        + TEST + '.gd" id="1"]\n[node name="Proof" type="Node"]\nscript = ExtResource("1")\n')
    primary = install(root/'next-human', paid)
    run(project,root/'next-human','play',godot)
    durable = slot_pair(primary)
    assert durable[1] == paid[0]
    print('DURABLE UNPAID NEXT HUMAN SHA256=',hashlib.sha256(durable[0]).hexdigest(),flush=True)
    new = json.loads(durable[0])
    pending = new['ordinary']['physical']['pending']
    assert pending['human'][0] == 6 and pending['reports'] == [] and pending['binding']['version'] == 1
    new['ordinary']['physical']['pending'] = {}
    # No result, reward, report, receipt, career metadata, or prior journal changed.
    assert new == json.loads(paid[0])
    text = durable[0].decode()
    marker = '"pending":'
    start = text.index(marker+'{"binding":') + len(marker)
    _, end = json.JSONDecoder().raw_decode(text, start)
    assert (text[:start]+'{}'+text[end:]).encode() == paid[0]
    run(project,root/'next-human','cold',godot)
    assert slot_pair(primary) == durable
    for fault, key in [('request',pending['binding']['request']),
                       ('old-archive',new['ordinary']['physical']['reports'][-1]['request'])]:
        needle = ('"request":"'+key+'"').encode()
        assert durable[0].count(needle)==1
        bad = (durable[0].replace(needle,b'"request":"'+b'0'*64+b'"'),durable[1])
        corrupted = install(root/('tamper-'+fault),bad)
        run(project,root/('tamper-'+fault),'tamper-'+fault,godot)
        assert slot_pair(corrupted) == bad
    home = root/'standard'
    standard_copy = install(home,standard)
    output = execute([godot,'--headless','--path',str(project),'res://tests/'+draft.TEST+'.tscn',
                      '--','cold','standard'],environment(home),180)
    assert 'HIDDEN_DRAFT_PASS' in output and 'GATES=0' in output and slot_pair(standard_copy)==standard
    assert slot_pair(paid_path)==paid and slot_pair(standard_path)==standard
    print('PASS: actual fixture 6, both fresh stamina budgets, exact original upgraded paid prefix; no new payout')


if __name__ == '__main__':
    main()
