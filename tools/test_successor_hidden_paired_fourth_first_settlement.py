#!/usr/bin/env python3
"""Settle the actual signed cp134 fixtures18–20 once, with no match simulation.

Use the cp134 --fixture-stage and cp121 --paid-stage Standard control.
--completed-stage reuses exact paid bytes for cold and negative checks only.
All native artifacts and synthetic slots remain in disposable local folders.
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
from test_successor_hidden_paired_fourth_first import TEST as HUMAN_TEST, run as human_run
from test_successor_hidden_paired_fourth_first_npcs import NPC20, TEST as NPC_TEST
from test_successor_hidden_paired_next_first import STANDARD
from test_successor_hidden_paired_next_return_settlement import STORE, add_profile
from test_successor_hidden_paired_third_return_first_npc import native
from test_successor_hidden_paired_third_return_settlement import raw_rows
from test_successor_hidden_paired_visit6_sign import OPEN, edit_span, old_human_roster_tamper, span
from test_successor_pair_history_context import execute
from test_successor_paired_resolver_context import install, once, slot_pair, verify_fixture
from test_successor_schedule_wiring import environment

TEST='successor_hidden_paired_fourth_first_settlement'
PAID7=('c46a029b9f95ac6fa3615301233d57e59caf783b61b3c86ce9df8961618942e4',NPC20[0])
BUDGET={'startup':30,'cold':235,'candidate':245,'paid':220,'retry':45}


def run(project,home,mode,godot):
    stages=['cold','candidate','paid','retry'] if mode=='settle' else ['cold']
    native(project,home,mode,godot,scene=TEST,budgets=BUDGET,outer=810,stages=stages)


def verify_preserved(pending,durable):
    assert durable[1]==pending[0]
    print('DURABLE PAID GAME7',hashlib.sha256(durable[0]).hexdigest(),flush=True)
    before,after=(json.loads(frame) for frame in (pending[0],durable[0]))
    assert {k:v for k,v in after.items() if k!='ordinary'}=={k:v for k,v in before.items() if k!='ordinary'}
    source,paid=before['ordinary'],after['ordinary']
    assert paid['state']['round_index']==7 and paid['physical']['pending']=={}
    assert paid['build']['build']['_visit']['number']==7 and paid['build']['build']['_visit']['open'] is False
    assert 'recruit' not in paid['build']['build']['_visit']
    assert paid['build']['bank']['_state']['cash']==80 and source['build']['bank']['_state']['cash']==62
    assert source['build']['build']['_contracts']==paid['build']['build']['_contracts']
    old,new=(frame.decode() for frame in (pending[0],durable[0]))
    archive=['ordinary','physical','reports']
    assert raw_rows(new,archive)==raw_rows(old,archive)+raw_rows(old,['ordinary','physical','pending','reports'])
    for name in ('results','player_results'):
        path=['ordinary','state',name]
        rows=raw_rows(old,path)
        assert raw_rows(new,path)[:len(rows)]==rows
    for club in range(6):
        path=['ordinary','build'] if club==0 else ['ordinary','opponents','clubs',str(club),'build']
        for section in ('build','book','bank'):
            key=path+[section,'_events']
            rows=raw_rows(old,key)
            assert raw_rows(new,key)[:len(rows)]==rows
    unchanged=[
        ['ordinary','build','book','_players'],
        ['ordinary','build','build','_recruits'],
        ['ordinary','build','build','_contracts'],
    ]
    unchanged.extend(['ordinary','build','build','_game_rosters',key]
                     for key in source['build']['build']['_game_rosters'])
    for key in unchanged:
        a,b=span(old,key)
        c,d=span(new,key)
        assert old[a:b]==new[c:d]
    assert paid['build']['build']['_game_rosters']['18']==paid['build']['build']['_roster']
    assert source['physical']['pending']['human'][3]==paid['state']['player_results'][-1]['performance']
    return paid


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixture-stage',required=True,type=Path)
    parser.add_argument('--unsigned-stage',required=True,type=Path)
    parser.add_argument('--paid-stage',required=True,type=Path)
    parser.add_argument('--completed-stage',type=Path)
    parser.add_argument('--godot',default='godot')
    args=parser.parse_args()
    godot=shutil.which(args.godot)
    if not godot:
        parser.error('Godot unavailable')
    origin=args.fixture_stage.resolve()/'fourth-first-npc20'/draft.SLOT
    control_path=args.paid_stage.resolve()/'standard'/draft.SLOT
    unsigned_path=args.unsigned_stage.resolve()/'visit6-open'/draft.SLOT
    pending=verify_fixture(slot_pair(origin),NPC20)
    control=verify_fixture(slot_pair(control_path),STANDARD)
    unsigned=verify_fixture(slot_pair(unsigned_path),OPEN)
    repo=Path(__file__).resolve().parents[1]
    root=Path(tempfile.mkdtemp(prefix='wiffaltro-fourth-first-settlement-'))
    print('Retained disposable local stage:',root,flush=True)
    project=draft.stage(repo,root/'engine',(repo/'tests'/(draft.TEST+'.gd.txt')).read_bytes(),godot)
    add_profile(project)
    store=project/STORE
    marker='\tpaired_candidate_ms=Time.get_ticks_msec()-started'
    store.write_text(once(store.read_text(),marker,marker+
        '\n\tif leg==6 and current!=null: print("CP127_STAGE paid")'))
    dependencies=(TEST,NPC_TEST,HUMAN_TEST,'successor_hidden_paired_visit6_sign','successor_hidden_paired_visit6_open',
                  'successor_hidden_paired_third_return_settlement','successor_hidden_paired_third_return',
                  'successor_hidden_paired_third_first_settlement','successor_hidden_paired_third_first',
                  'successor_hidden_paired_next_return_settlement','successor_hidden_paired_next_return',
                  'successor_hidden_paired_next_first_settlement','successor_hidden_paired_next_first',
                  'successor_hidden_paired_return_settlement','successor_hidden_paired_return',
                  'successor_hidden_first_settlement')
    for name in dependencies:
        (project/'tests'/(name+'.gd')).write_bytes((repo/'tests'/(name+'.gd.txt')).read_bytes())
    for name in (TEST,HUMAN_TEST):
        (project/'tests'/(name+'.tscn')).write_text(
            '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/'
            + name + '.gd" id="1"]\n[node name="Proof" type="Node"]\nscript = ExtResource("1")\n')
    home=root/'fourth-first-settlement'
    completed=args.completed_stage.resolve()/'fourth-first-settlement'/draft.SLOT if args.completed_stage else None
    primary=install(home,verify_fixture(slot_pair(completed),PAID7) if completed else pending)
    if not completed:
        run(project,home,'settle',godot)
    durable=slot_pair(primary)
    paid=verify_preserved(pending,durable)
    cold=root/'cold'
    cold_path=install(cold,durable)
    run(project,cold,'cold',godot)
    assert slot_pair(cold_path)==durable
    text=durable[0].decode()
    archive=['ordinary','physical','reports']
    reports=raw_rows(text,archive)
    faults={
        'new-report-request':once(text,paid['physical']['reports'][-1]['request'],'0'*64),
        'missing-report':edit_span(text,archive,'['+','.join(reports[:-1])+']'),
        'rewind':edit_span(text,['ordinary','state','round_index'],'6.0'),
        'old-Val-attribution':old_human_roster_tamper(text),
    }
    for name,changed in faults.items():
        case=root/('tamper-'+name)
        pair=changed.encode(),durable[1]
        failed=install(case,pair)
        run(project,case,'tamper-'+name,godot)
        assert slot_pair(failed)==pair
    ordinary=root/'standard'
    standard=install(ordinary,control)
    out=execute([godot,'--headless','--path',str(project),'res://tests/'+draft.TEST+'.tscn',
                 '--','cold','standard'],environment(ordinary),180)
    assert 'HIDDEN_DRAFT_PASS' in out and 'GATES=0' in out and 'CP121_HISTORY' not in out and slot_pair(standard)==control
    case=root/'unsigned'
    unsigned_copy=install(case,unsigned)
    human_run(project,case,'unsigned',godot)
    assert slot_pair(unsigned_copy)==unsigned
    assert slot_pair(origin)==pending and slot_pair(control_path)==control and slot_pair(unsigned_path)==unsigned
    assert slot_pair(primary)==durable
    if completed:
        assert slot_pair(completed)==durable
    print('PASS: actual signed Game7 settlement, exact prior history, six native receipts, visit7 still closed')


if __name__=='__main__':
    main()
