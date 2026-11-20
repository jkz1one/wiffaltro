#!/usr/bin/env python3
"""Settle exact cp124 fixture12–14 evidence, no gameplay replay.

Produce --fixture-stage using tools/test_successor_hidden_paired_third_first_npcs.py
at cp124. Supply the cp121 paid stage as --paid-stage for its admitted Standard.
The staged project profiles ordinary-owner writes and authenticated history; no
frozen source changes and no input checkpoint mutation.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile

sys.dont_write_bytecode = True
import test_successor_hidden_paired_draft as draft
from test_successor_hidden_paired_next_first import STANDARD
from test_successor_hidden_paired_next_return_settlement import add_profile
from test_successor_hidden_paired_third_first_npcs import COMPLETE14_SHA, PARTIAL13
from test_successor_pair_history_context import execute
from test_successor_paired_resolver_context import install, once, slot_pair, verify_fixture
from test_successor_schedule_wiring import environment

TEST = 'successor_hidden_paired_third_first_settlement'
PENDING = (COMPLETE14_SHA,PARTIAL13[0])


def run(project,home,mode,godot):
    result = execute([godot,'--headless','--fixed-fps','60','--path',str(project),
                      'res://tests/'+TEST+'.tscn','--',mode],environment(home),480)
    assert 'HIDDEN_PAIRED_THIRD_FIRST_SETTLEMENT_PASS' in result
    sections = [json.loads(line.split(' ',1)[1]) for line in result.splitlines()
                if line.startswith('CP121_HISTORY ')]
    writes = [line for line in result.splitlines() if line.startswith('CP121_WRITE ')]
    if mode == 'settle':
        assert [row[:6] for row in sections] == [[4,6,12,24,8,48], [4,6,12,24,8,48], [5,6,15,30,10,60]]
        assert len(writes)==1 and writes[0].endswith(' true')
    elif mode == 'cold':
        assert [row[:6] for row in sections] == [[5,6,15,30,10,60]] and not writes
    else:
        assert not writes


def archives(payload):
    frame = payload.decode()
    found = {}
    for match in re.finditer(r'\{"fixture":(1|2|4|5|7|8|10|11|13|14)(?:\.0)?,"report":\{"dynasty_start"',frame):
        fixture = int(match[1])
        _, end = json.JSONDecoder().raw_decode(frame,match.start())
        assert fixture not in found
        found[fixture] = frame[match.start():end]
    return found


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixture-stage',required=True,type=Path)
    parser.add_argument('--paid-stage',required=True,type=Path)
    parser.add_argument('--godot',default='godot')
    args = parser.parse_args()
    godot = shutil.which(args.godot)
    if godot is None:
        parser.error('Godot unavailable')
    if hasattr(os,'sched_getaffinity'):
        cpus = os.sched_getaffinity(0)
        pinned = 1 if 1 in cpus else min(cpus)
        os.sched_setaffinity(0,{pinned})
        print('Pinned Linux CPU:',pinned,flush=True)
    origin = args.fixture_stage.resolve()/'third-first-npcs'/draft.SLOT
    standard_path = args.paid_stage.resolve()/'standard'/draft.SLOT
    pending = verify_fixture(slot_pair(origin),PENDING)
    standard = verify_fixture(slot_pair(standard_path),STANDARD)
    repo = Path(__file__).resolve().parents[1]
    root = Path(tempfile.mkdtemp(prefix='wiffaltro-third-first-settlement-'))
    print('Retained disposable local stage:',root,flush=True)
    project = draft.stage(repo,root/'engine',(repo/'tests'/(draft.TEST+'.gd.txt')).read_bytes(),godot)
    add_profile(project)
    for name in (TEST,'successor_hidden_paired_third_first','successor_hidden_paired_next_return_settlement',
                 'successor_hidden_paired_next_return','successor_hidden_paired_next_first_settlement',
                 'successor_hidden_paired_next_first','successor_hidden_paired_return_settlement',
                 'successor_hidden_paired_return','successor_hidden_first_settlement'):
        (project/'tests'/(name+'.gd')).write_bytes((repo/'tests'/(name+'.gd.txt')).read_bytes())
    (project/'tests'/(TEST+'.tscn')).write_text(
        '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/'
        + TEST + '.gd" id="1"]\n[node name="Proof" type="Node"]\nscript = ExtResource("1")\n')
    home = root/'third-first-settlement'
    primary = install(home,pending)
    run(project,home,'settle',godot)
    durable = slot_pair(primary)
    assert durable[1] == pending[0]
    print('DURABLE FIFTH PAID ROUND SHA256=',hashlib.sha256(durable[0]).hexdigest(),flush=True)
    before, after = (json.loads(frame) for frame in (pending[0],durable[0]))
    assert {k:v for k,v in after.items() if k!='ordinary'} == {k:v for k,v in before.items() if k!='ordinary'}
    source, paid = before['ordinary'],after['ordinary']
    assert paid['state']['round_index']==5 and paid['physical']['pending']=={}
    assert paid['physical']['reports']==source['physical']['reports']+source['physical']['pending']['reports']
    archive = archives(durable[0])
    assert len(archive)==10 and archive==archives(pending[0])
    assert paid['state']['results'][:12]==source['state']['results']
    assert paid['state']['player_results'][:4]==source['state']['player_results']
    for club in range(6):
        earlier,current = (row['build'] if club==0 else row['opponents']['clubs'][str(club)]['build']
                           for row in (source,paid))
        for section in ('build','book','bank'):
            prefix = earlier[section]['_events']
            assert current[section]['_events'][:len(prefix)]==prefix
    run(project,home,'cold',godot)
    assert slot_pair(primary)==durable
    requests = {row['fixture']:row['request'] for row in paid['physical']['reports']}
    text = durable[0].decode()
    faults = {
        'older-return':once(text,requests[5],'0'*64),
        'new-npc-request':once(text,requests[14],'0'*64),
        'reordered':once(text,archive[13]+','+archive[14],archive[14]+','+archive[13]),
        'future-round':once(text,'"round_index":5.0','"round_index":6.0'),
        'rewind-paid':once(text,'"round_index":5.0','"round_index":4.0'),
        'missing-report':once(text,','+archive[14],''),

    }
    for fault, corrupt in faults.items():
        case = root/('tamper-'+fault)
        pair = corrupt.encode(),durable[1]
        path = install(case,pair)
        run(project,case,'tamper-'+fault,godot)
        assert slot_pair(path)==pair
    ordinary = root/'standard'
    ordinary_copy = install(ordinary,standard)
    out = execute([godot,'--headless','--path',str(project),'res://tests/'+draft.TEST+'.tscn',
                   '--','cold','standard'],environment(ordinary),180)
    assert 'HIDDEN_DRAFT_PASS' in out and 'GATES=0' in out and 'CP121_HISTORY' not in out
    assert slot_pair(ordinary_copy)==standard
    assert slot_pair(origin)==pending and slot_pair(standard_path)==standard
    print('PASS: exact private fifth paid round, no new sweep, independent cold/profile and Standard parity')


if __name__ == '__main__':
    main()
