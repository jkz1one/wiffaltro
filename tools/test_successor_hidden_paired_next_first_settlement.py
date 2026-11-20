#!/usr/bin/env python3
"""Settle private fixture 6/7/8 from the exact cp118 complete pending.

Use tools/test_successor_hidden_paired_next_first_npcs.py at cp118 to produce
--fixture-stage. Supply the cp114 paid-pair stage as --paid-stage for its
pinned Standard control. This performs no game simulation or external writes.
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
from test_successor_hidden_paired_next_first import STANDARD
from test_successor_hidden_paired_next_first_npcs import COMPLETE
from test_successor_pair_history_context import execute
from test_successor_paired_resolver_context import install, once, slot_pair, verify_fixture
from test_successor_schedule_wiring import environment

TEST = 'successor_hidden_paired_next_first_settlement'


def run(project, home, mode, godot):
    out = execute([godot,'--headless','--fixed-fps','60','--path',str(project),
                   'res://tests/'+TEST+'.tscn','--',mode],environment(home),420)
    assert 'HIDDEN_PAIRED_NEXT_FIRST_SETTLEMENT_PASS' in out


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixture-stage',required=True,type=Path)
    parser.add_argument('--paid-stage',required=True,type=Path)
    parser.add_argument('--godot',default='godot')
    args = parser.parse_args()
    godot = shutil.which(args.godot)
    if godot is None:
        parser.error('Godot unavailable')
    origin = args.fixture_stage.resolve()/'next-first-npcs'/draft.SLOT
    standard_path = args.paid_stage.resolve()/'ordinary'/draft.SLOT
    pending = verify_fixture(slot_pair(origin),COMPLETE)
    standard = verify_fixture(slot_pair(standard_path),STANDARD)
    repo = Path(__file__).resolve().parents[1]
    root = Path(tempfile.mkdtemp(prefix='wiffaltro-next-first-settlement-'))
    print('Retained disposable local stage:',root,flush=True)
    project = draft.stage(repo,root/'engine',(repo/'tests'/(draft.TEST+'.gd.txt')).read_bytes(),godot)
    for name in (TEST,'successor_hidden_paired_next_first','successor_hidden_paired_return_settlement',
                 'successor_hidden_paired_return','successor_hidden_first_settlement'):
        (project/'tests'/(name+'.gd')).write_bytes((repo/'tests'/(name+'.gd.txt')).read_bytes())
    (project/'tests'/(TEST+'.tscn')).write_text(
        '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/'
        + TEST + '.gd" id="1"]\n[node name="Proof" type="Node"]\nscript = ExtResource("1")\n')
    home = root/'next-first-settlement'
    primary = install(home,pending)
    run(project,home,'settle',godot)
    durable = slot_pair(primary)
    assert durable[1] == pending[0]
    print('DURABLE THIRD PAID ROUND SHA256=',hashlib.sha256(durable[0]).hexdigest(),flush=True)
    prior_frame, frame = (json.loads(frame) for frame in (pending[0],durable[0]))
    assert {k:v for k,v in frame.items() if k!='ordinary'} == {k:v for k,v in prior_frame.items() if k!='ordinary'}
    source, paid = prior_frame['ordinary'],frame['ordinary']
    assert paid['state']['round_index'] == 3 and paid['physical']['pending'] == {}
    assert paid['physical']['reports'] == source['physical']['reports'] + source['physical']['pending']['reports']
    assert paid['state']['results'][:6] == source['state']['results']
    assert paid['state']['player_results'][:2] == source['state']['player_results']
    for club in range(6):
        earlier, current = (row['build'] if club==0 else row['opponents']['clubs'][str(club)]['build']
                            for row in (source,paid))
        for section in ('build','book','bank'):
            prefix = earlier[section]['_events']
            assert current[section]['_events'][:len(prefix)] == prefix
    run(project,home,'cold',godot)
    assert slot_pair(primary) == durable
    requests = {row['fixture']:row['request'] for row in paid['physical']['reports']}
    text = durable[0].decode()
    faults = {
        'older-v4-return':once(text,requests[5],'0'*64),
        'new-v4-first':once(text,requests[8],'0'*64),
        'future-round':once(text,'"round_index":3.0','"round_index":4.0'),
    }
    for fault, corrupt in faults.items():
        case = root/('tamper-'+fault)
        pair = corrupt.encode(),durable[1]
        path = install(case,pair)
        run(project,case,'tamper-'+fault,godot)
        assert slot_pair(path) == pair
    ordinary = root/'standard'
    ordinary_copy = install(ordinary,standard)
    out = execute([godot,'--headless','--path',str(project),'res://tests/'+draft.TEST+'.tscn',
                   '--','cold','standard'],environment(ordinary),180)
    assert 'HIDDEN_DRAFT_PASS' in out and 'GATES=0' in out and slot_pair(ordinary_copy) == standard
    assert slot_pair(origin)==pending and slot_pair(standard_path)==standard
    print('PASS: exact private third paid round, six new receipts, no added sweep, independent cold and Standard parity')


if __name__ == '__main__':
    main()
