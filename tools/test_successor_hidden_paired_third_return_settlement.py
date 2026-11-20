#!/usr/bin/env python3
"""Settle exact cp128 fixture15–17 evidence once; never rerun a game.

Generate the pinned --fixture-stage with the cp128 private NPC17 reproducer,
and supply cp121 --paid-stage for Standard. Each native boundary has a
separate elapsed budget. Frozen source is untouched; scratch stays local.
Use --completed-stage on already verified retained bytes to repeat only cold
checks, never settlement or games.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import sys
import tempfile

sys.dont_write_bytecode = True
import test_successor_hidden_paired_draft as draft
from test_successor_hidden_paired_next_first import STANDARD
from test_successor_hidden_paired_next_return_settlement import add_profile,STORE
from test_successor_hidden_paired_third_return_first_npc import NPC17, native
from test_successor_pair_history_context import execute
from test_successor_paired_resolver_context import install, once, slot_pair, verify_fixture
from test_successor_schedule_wiring import environment

TEST = 'successor_hidden_paired_third_return_settlement'
PENDING = NPC17
PAID = ('816b467b022c05137f66168cc3271a26567f76d322daeaa869b79e72c8cc4010', PENDING[0])
BUDGET = {'startup':30, 'cold':220, 'candidate':230, 'paid':210, 'retry':45}


def run(project,home,mode,godot):
    stages=['cold','candidate','paid','retry'] if mode=='settle' else ['cold']
    native(project,home,mode,godot,scene=TEST,budgets=BUDGET,outer=800,stages=stages)


def trace_admission(project):
    path=project/STORE
    anchor='\tpaired_candidate_ms=Time.get_ticks_msec()-started'
    path.write_text(once(path.read_text(),anchor,anchor+
                         '\n\tif leg==5 and current!=null: print("CP127_STAGE paid")'))


def raw_rows(text, keys):
    """Read list items by exact JSON object path, preserving serialized bytes."""
    decoder=json.JSONDecoder()
    pos=0
    for part in keys:
        assert text[pos]=='{'
        pos+=1
        while text[pos]!='}':
            key,end=decoder.raw_decode(text,pos)
            assert text[end]==':'
            if key==part:
                pos=end+1
                break
            _, end=decoder.raw_decode(text,end+1)
            pos=end+1 if text[end]==',' else end
        else:
            raise KeyError(keys)
    assert text[pos]=='['
    pos+=1
    rows=[]
    while text[pos]!=']':
        _,end=decoder.raw_decode(text,pos)
        rows.append(text[pos:end])
        pos=end+1 if text[end]==',' else end
    return rows


def archives(payload):
    frame = payload.decode()
    found = {}
    for match in re.finditer(r'\{"fixture":(1|2|4|5|7|8|10|11|13|14|16|17)(?:\.0)?,"report":\{"dynasty_start"',frame):
        fixture = int(match[1])
        _, end = json.JSONDecoder().raw_decode(frame,match.start())
        assert fixture not in found
        found[fixture] = frame[match.start():end]
    return found


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixture-stage',required=True,type=Path)
    parser.add_argument('--paid-stage',required=True,type=Path)
    parser.add_argument('--completed-stage',type=Path)
    parser.add_argument('--godot',default='godot')
    args = parser.parse_args()
    godot = shutil.which(args.godot)
    if godot is None:
        parser.error('Godot unavailable')
    origin = args.fixture_stage.resolve()/'third-return-npc17'/draft.SLOT
    standard_path = args.paid_stage.resolve()/'standard'/draft.SLOT
    pending = verify_fixture(slot_pair(origin),PENDING)
    standard = verify_fixture(slot_pair(standard_path),STANDARD)
    repo = Path(__file__).resolve().parents[1]
    root = Path(tempfile.mkdtemp(prefix='wiffaltro-third-return-settlement-'))
    print('Retained disposable local stage:',root,flush=True)
    project = draft.stage(repo,root/'engine',(repo/'tests'/(draft.TEST+'.gd.txt')).read_bytes(),godot)
    add_profile(project)
    trace_admission(project)
    for name in (TEST,'successor_hidden_paired_third_return','successor_hidden_paired_third_first_settlement',
                 'successor_hidden_paired_third_first','successor_hidden_paired_next_return_settlement',
                 'successor_hidden_paired_next_return','successor_hidden_paired_next_first_settlement',
                 'successor_hidden_paired_next_first','successor_hidden_paired_return_settlement',
                 'successor_hidden_paired_return','successor_hidden_first_settlement'):
        (project/'tests'/(name+'.gd')).write_bytes((repo/'tests'/(name+'.gd.txt')).read_bytes())
    (project/'tests'/(TEST+'.tscn')).write_text(
        '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/'
        + TEST + '.gd" id="1"]\n[node name="Proof" type="Node"]\nscript = ExtResource("1")\n')
    home = root/'third-return-settlement'
    completed = args.completed_stage.resolve()/'third-return-settlement'/draft.SLOT if args.completed_stage else None
    primary = install(home, verify_fixture(slot_pair(completed),PAID) if completed else pending)
    if not completed:
        run(project,home,'settle',godot)
    durable = slot_pair(primary)
    assert durable[1] == pending[0]
    print('DURABLE SIXTH PAID ROUND SHA256=',hashlib.sha256(durable[0]).hexdigest(),flush=True)
    before, after = (json.loads(frame) for frame in (pending[0],durable[0]))
    assert {k:v for k,v in after.items() if k!='ordinary'} == {k:v for k,v in before.items() if k!='ordinary'}
    source, paid = before['ordinary'],after['ordinary']
    assert paid['state']['round_index']==6 and paid['physical']['pending']=={}
    assert paid['physical']['reports']==source['physical']['reports']+source['physical']['pending']['reports']
    archive = archives(durable[0])
    assert len(archive)==12 and archive==archives(pending[0])
    assert paid['state']['results'][:15]==source['state']['results']
    assert paid['state']['player_results'][:5]==source['state']['player_results']
    old_text, new_text = (frame.decode() for frame in (pending[0],durable[0]))
    for path in (['ordinary','state','results'], ['ordinary','state','player_results']):
        prefix=raw_rows(old_text,path)
        assert raw_rows(new_text,path)[:len(prefix)]==prefix
    for club in range(6):
        path=['ordinary','build'] if club==0 else ['ordinary','opponents','clubs',str(club),'build']
        for section in ('build','book','bank'):
            key=path+[section,'_events']
            prefix=raw_rows(old_text,key)
            assert raw_rows(new_text,key)[:len(prefix)]==prefix
    run(project,home,'cold',godot)
    assert slot_pair(primary)==durable
    requests = {row['fixture']:row['request'] for row in paid['physical']['reports']}
    text = durable[0].decode()
    faults = {
        'new-npc-request':once(text,requests[17],'0'*64),
        'reordered':once(text,archive[16]+','+archive[17],archive[17]+','+archive[16]),
        'rewind-paid':once(text,'"round_index":6.0','"round_index":5.0'),
        'missing-report':once(text,','+archive[17],''),

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
    if completed:
        assert slot_pair(completed)==durable
    print('PASS: exact private sixth paid round, natural club1 sweep, closed visit6, independent cold and Standard exact')


if __name__ == '__main__':
    main()
