#!/usr/bin/env python3
"""Settle the second private pair using exact cp120 complete pending, no games.

Use tools/test_successor_hidden_paired_next_return.py at cp120 to produce
--fixture-stage. Supply the cp114 paid-pair stage as --paid-stage for pinned
Standard. The assembled test copy adds logging only outside frozen files; it
counts settled-history collection separately from pending report resolution.
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
from test_successor_pair_history_context import execute
from test_successor_paired_resolver_context import install, once, slot_pair, verify_fixture
from test_successor_schedule_wiring import environment

TEST = 'successor_hidden_paired_next_return_settlement'
PENDING = ('2668aeb3002125d0c86236d2585d6f9d53648945cc020b0a8e16d275032d028f',
           'bb8cf51d8159480ca694eb79e4e59c6343af58e9c6302ce25c83def71f35a137')
HISTORY = 'src/gameplay/season/successor_settled_workload_v1/validator.gd'
STORE = 'src/gameplay/season/successor_dynasty_owner_v1/owner_store.gd'


def add_profile(project):
    path = project/HISTORY
    source = once(path.read_text(), 'var snapshots: Dictionary=Collector.collect(builds,targets)',
                  'var replay_before: int=Collector.replay_calls\n\tvar snapshots: Dictionary=Collector.collect(builds,targets)')
    line = '\tchecked_sides=2*checked.size()\n\treturn true'
    source = once(source, line, '''	checked_sides=2*checked.size()
	var size: int=0
	var commands: int=0
	for club: String in snapshots:
		commands+=builds[club]._events.size()
		for fixture: String in snapshots[club]:
			size+=snapshots[club][fixture].size()
	print("CP121_HISTORY ",JSON.stringify([season.round_index,Collector.replay_calls-replay_before,rows.size(),checked_sides,checked_reports,size,commands,collection_ms,workload_ms,report_ms]))
	return true''')
    path.write_text(source)
    path = project/STORE
    anchor = '\tvar result: bool = _write_data(_candidate_data,_expected)'
    path.write_text(once(path.read_text(),anchor,
                         '\tvar cp_write_start: int=Time.get_ticks_usec()\n'+anchor
                         +'\n\tprint("CP121_WRITE ",Time.get_ticks_usec()-cp_write_start," ",result)'))


def run(project,home,mode,godot):
    result = execute([godot,'--headless','--fixed-fps','60','--path',str(project),
                      'res://tests/'+TEST+'.tscn','--',mode],environment(home),480)
    assert 'HIDDEN_PAIRED_NEXT_RETURN_SETTLEMENT_PASS' in result
    sections = [json.loads(line.split(' ',1)[1]) for line in result.splitlines()
                if line.startswith('CP121_HISTORY ')]
    writes = [line for line in result.splitlines() if line.startswith('CP121_WRITE ')]
    if mode == 'settle':
        assert [row[:6] for row in sections] == [[3,6,9,18,6,36], [3,6,9,18,6,36], [4,6,12,24,8,48]]
        assert len(writes)==1 and writes[0].endswith(' true')
    elif mode == 'cold':
        assert [row[:6] for row in sections] == [[4,6,12,24,8,48]] and not writes
    else:
        assert not writes


def archives(payload):
    frame = payload.decode()
    found = {}
    for match in re.finditer(r'\{"fixture":(1|2|4|5|7|8|10|11)(?:\.0)?,"report":\{"dynasty_start"',frame):
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
    origin = args.fixture_stage.resolve()/'next-return'/draft.SLOT
    standard_path = args.paid_stage.resolve()/'ordinary'/draft.SLOT
    pending = verify_fixture(slot_pair(origin),PENDING)
    standard = verify_fixture(slot_pair(standard_path),STANDARD)
    repo = Path(__file__).resolve().parents[1]
    root = Path(tempfile.mkdtemp(prefix='wiffaltro-next-return-settlement-'))
    print('Retained disposable local stage:',root,flush=True)
    project = draft.stage(repo,root/'engine',(repo/'tests'/(draft.TEST+'.gd.txt')).read_bytes(),godot)
    add_profile(project)
    for name in (TEST,'successor_hidden_paired_next_return','successor_hidden_paired_next_first_settlement',
                 'successor_hidden_paired_next_first','successor_hidden_paired_return_settlement',
                 'successor_hidden_paired_return','successor_hidden_first_settlement'):
        (project/'tests'/(name+'.gd')).write_bytes((repo/'tests'/(name+'.gd.txt')).read_bytes())
    (project/'tests'/(TEST+'.tscn')).write_text(
        '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/'
        + TEST + '.gd" id="1"]\n[node name="Proof" type="Node"]\nscript = ExtResource("1")\n')
    home = root/'next-return-settlement'
    primary = install(home,pending)
    run(project,home,'settle',godot)
    durable = slot_pair(primary)
    assert durable[1] == pending[0]
    print('DURABLE FOURTH PAID ROUND SHA256=',hashlib.sha256(durable[0]).hexdigest(),flush=True)
    before, after = (json.loads(frame) for frame in (pending[0],durable[0]))
    assert {k:v for k,v in after.items() if k!='ordinary'} == {k:v for k,v in before.items() if k!='ordinary'}
    source, paid = before['ordinary'],after['ordinary']
    assert paid['state']['round_index']==4 and paid['physical']['pending']=={}
    assert paid['physical']['reports']==source['physical']['reports']+source['physical']['pending']['reports']
    archive = archives(durable[0])
    assert len(archive)==8 and archive==archives(pending[0])
    assert paid['state']['results'][:9]==source['state']['results']
    assert paid['state']['player_results'][:3]==source['state']['player_results']
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
        'new-return':once(text,requests[11],'0'*64),
        'reordered':once(text,archive[10]+','+archive[11],archive[11]+','+archive[10]),
        'future-round':once(text,'"round_index":4.0','"round_index":5.0'),
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
    print('PASS: exact private fourth paid round, one natural NPC sweep, independent cold/profile and Standard parity')


if __name__ == '__main__':
    main()
